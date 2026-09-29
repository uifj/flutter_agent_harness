// The recorded before-images of files the agent overwrote (ADR-0014).
//
// `<support>/checkpoints/index.json` + `<support>/checkpoints/blobs/<fp>.bin`.
//
// Three shape decisions, all load-bearing:
//   * **Before-images, content-addressed.** Restoring needs only what the file
//     used to be, so that is what is stored; the after side is kept as a
//     fingerprint for the conflict guard. Two writes of the same bytes share one
//     blob, which is why a file edited twenty times does not cost twenty copies.
//   * **Keyed by workspace root.** A rewind that spans two folders would delete
//     and restore across both, and a path means nothing outside the folder it
//     was resolved in. Same reasoning as `ApprovalRuleStore`.
//   * **App-level storage.** The blobs hold file contents in Application Support
//     rather than beside the project, so a cloned repository cannot arrive with
//     someone else's undo history — and no write into the user's workspace is
//     needed to keep one.
//
// The pruning rule is the one simplification with a corner it cuts: past the
// total budget, whole entries go from the oldest end, so the range that can be
// rewound shrinks. That degrades coverage, never correctness — a missing image
// is reported at rewind time rather than guessed around.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/checkpoint.dart';
import '../model/fs_revision.dart';
import '../model/workspace.dart';

/// Whether a rewind covers one conversation's changes or the whole folder's.
enum RewindScope { conversation, workspace }

enum RewindSkipReason {
  /// The file is not what the last recorded write left there, so restoring over
  /// it would discard somebody else's work.
  changedOutsideAgent,

  /// The entry is in range but its before-image is gone — pruned past the
  /// budget, or the file was over the per-file cap when it was written. Also
  /// the label for the rarer case where the image was there and the filesystem
  /// refused the write or the delete: either way the promise cannot be kept.
  imageUnavailable,
}

class RewindSkip {
  const RewindSkip(this.path, this.reason);

  final String path;
  final RewindSkipReason reason;
}

/// One file a rewind would touch, as the confirmation shows it.
class RewindFile {
  const RewindFile({required this.path, required this.deletes, this.blockedBy});

  final String path;

  /// True when the rewind removes the file, because the range records it as
  /// created by the agent.
  final bool deletes;

  /// Why the rewind leaves this one alone — a later edit outside the agent, or
  /// an image that is no longer stored — or null when it does touch it. The
  /// reason travels rather than a bare flag: a confirmation that says "this one
  /// is not going back" without saying why is one the user cannot judge.
  final RewindSkipReason? blockedBy;

  bool get blocked => blockedBy != null;
}

class RewindReport {
  const RewindReport({
    required this.restored,
    required this.deleted,
    required this.skipped,
  });

  static const empty = RewindReport(restored: [], deleted: [], skipped: []);

  /// Paths written back to their recorded before-image.
  final List<String> restored;

  /// Paths removed because the entry in range recorded them as created.
  final List<String> deleted;
  final List<RewindSkip> skipped;

  bool get didNothing => restored.isEmpty && deleted.isEmpty && skipped.isEmpty;
}

/// A rewind's per-file decision, computed once and used by both the preview
/// and the action so the two can never disagree.
class _RewindTarget {
  const _RewindTarget(this.goal, {this.imagePath, this.blocked});

  /// The entry whose before-image is the target state.
  final FileCheckpoint goal;

  /// Where that image lives, when there is one to restore.
  final String? imagePath;
  final RewindSkipReason? blocked;
}

class CheckpointStore extends ChangeNotifier implements CheckpointSink {
  CheckpointStore._(
    this._indexFile,
    this._blobDir,
    this._byWorkspace,
    this.totalBudget,
  ) {
    // Ids continue past whatever the file already holds, so a restart cannot
    // mint an id that names a different entry than the one the UI just showed.
    for (final entries in _byWorkspace.values) {
      for (final entry in entries) {
        final ordinal = int.tryParse(
          entry.id.length > 1 ? entry.id.substring(1) : '',
        );
        if (ordinal != null && ordinal >= _nextOrdinal) {
          _nextOrdinal = ordinal + 1;
        }
      }
    }
  }

  static const _dirName = 'checkpoints';
  static const _indexName = 'index.json';

  /// A before-image bigger than this is named but not stored.
  static const maxStoredFileBytes = 2 * 1024 * 1024;

  /// Total bytes of stored images before the oldest entries start going.
  static const maxStoredTotalBytes = 64 * 1024 * 1024;

  /// Overridable only so the pruning rule can be tested against a real budget
  /// without writing 64 MiB of files.
  final int totalBudget;

  /// Reads the index out of [support]. A document that cannot be parsed is
  /// treated as absent: an unreadable undo history must not brick the app, and
  /// must not be half-trusted into a partial rewind.
  static CheckpointStore open(
    Directory support, {
    int maxTotalBytes = maxStoredTotalBytes,
  }) {
    final dir = Directory('${support.path}/$_dirName');
    final indexFile = File('${dir.path}/$_indexName');
    final byWorkspace = <String, List<FileCheckpoint>>{};
    try {
      if (indexFile.existsSync()) {
        final decoded = jsonDecode(indexFile.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          for (final group in decoded.entries) {
            final rows = group.value;
            if (rows is! List) continue;
            final parsed = <FileCheckpoint>[];
            for (final row in rows) {
              if (row is! Map) continue;
              try {
                parsed.add(
                  FileCheckpoint.fromJson(row.cast<String, dynamic>()),
                );
              } on FormatException {
                // One unreadable row drops; the rest of the folder still counts.
              } on ArgumentError {
                // An unknown change kind drops too: guessing whether the file
                // was created would decide whether rewind deletes it.
              }
            }
            byWorkspace[group.key] = parsed;
          }
        }
      }
    } on FileSystemException {
      // Unreadable: start from nothing.
    } on FormatException {
      // Not JSON: same.
    }
    return CheckpointStore._(
      indexFile,
      Directory('${dir.path}/blobs'),
      byWorkspace,
      maxTotalBytes,
    );
  }

  final File _indexFile;
  final Directory _blobDir;
  final Map<String, List<FileCheckpoint>> _byWorkspace;
  String _key = '';
  String? _conversation;
  int _nextOrdinal = 0;

  @override
  String? get conversation => _conversation;

  @override
  set conversation(String? value) => _conversation = value;

  /// Points the store at [workspaceRoot]'s history. Replaces rather than
  /// merges, for the same reason `ApprovalRuleStore` does it: a folder's undo
  /// history is not another folder's.
  void useWorkspace(String? workspaceRoot) {
    _key = workspaceRoot ?? '';
    notifyListeners();
  }

  /// The recorded changes for [workspaceRoot], oldest first.
  List<FileCheckpoint> savedFor(String? workspaceRoot) =>
      List.unmodifiable(_byWorkspace[workspaceRoot ?? ''] ?? const []);

  /// Records one overwrite. Called by the tools at the instant they are about to
  /// replace a file — [before] must be the bytes actually on disk right then,
  /// and [after] the bytes about to be written.
  @override
  FileCheckpoint? record({
    required String path,
    required List<int> after,
    List<int>? before,
  }) {
    String? beforeFingerprint;
    var captured = true;
    if (before != null) {
      if (before.length > maxStoredFileBytes) {
        captured = false;
      } else {
        beforeFingerprint = _storeBlob(before);
      }
    }
    final entry = FileCheckpoint(
      id: 'c${_nextOrdinal++}',
      conversation: _conversation ?? '',
      path: path,
      change: before == null
          ? CheckpointChange.created
          : CheckpointChange.modified,
      // A creation needs no image: undoing it is a delete.
      captured: captured,
      beforeFingerprint: beforeFingerprint,
      afterFingerprint: contentFingerprint(after),
      beforeBytes: before?.length,
      afterBytes: after.length,
      at: DateTime.now(),
    );
    (_byWorkspace[_key] ??= <FileCheckpoint>[]).add(entry);
    _prune();
    _write();
    notifyListeners();
    return entry;
  }

  /// Renames the entries recorded under [fromToken] to the session id the first
  /// persisted turn finally reported.
  ///
  /// A conversation has no id until that turn lands, and a file written before
  /// it needs an owner all the same; this is where the placeholder becomes the
  /// real name, so a later `scope: conversation` rewind still finds its own
  /// entries and the session list can show which conversation changed a file.
  void adoptConversation(String fromToken, String sessionId) {
    final entries = _byWorkspace[_key];
    if (entries == null) return;
    var changed = false;
    for (final entry in entries) {
      if (entry.conversation != fromToken) continue;
      entry.conversation = sessionId;
      changed = true;
    }
    if (!changed) return;
    _write();
    notifyListeners();
  }

  /// What a rewind to [id] would do, file by file, without doing it.
  ///
  /// The confirmation needs this before anything is touched: a rewind whose
  /// every file is blocked by a later edit outside the agent is worth
  /// declining, and the user deserves to learn that before their files change
  /// rather than after.
  List<RewindFile> previewRewind({
    required String id,
    required Workspace workspace,
    RewindScope scope = RewindScope.conversation,
    String? conversation,
  }) => [
    for (final target in _targets(
      id: id,
      workspace: workspace,
      scope: scope,
      conversation: conversation,
    ))
      RewindFile(
        path: target.goal.path,
        deletes: target.goal.wasCreated,
        blockedBy: target.blocked,
      ),
  ];

  /// Undoes everything in [scope] back to just before the entry with [id].
  RewindReport rewindTo({
    required String id,
    required Workspace workspace,
    RewindScope scope = RewindScope.conversation,
    String? conversation,
  }) {
    final restored = <String>[];
    final deleted = <String>[];
    final skipped = <RewindSkip>[];
    for (final target in _targets(
      id: id,
      workspace: workspace,
      scope: scope,
      conversation: conversation,
    )) {
      final path = target.goal.path;
      if (target.blocked != null) {
        skipped.add(RewindSkip(path, target.blocked!));
        continue;
      }
      final file = File(workspace.resolve(path));
      final goal = target.goal;
      if (goal.wasCreated) {
        // The undo of a creation is a delete. A file that is already absent is
        // already in the state this rewind promises, so it is reported as
        // neither touched nor skipped: naming a delete that did not happen
        // would be the same lie as naming one that was blocked.
        if (file.existsSync()) {
          try {
            file.deleteSync();
            deleted.add(path);
          } on FileSystemException {
            skipped.add(RewindSkip(path, RewindSkipReason.imageUnavailable));
          }
        }
        continue;
      }
      try {
        // The image's existence was already checked; reading it can still fail
        // (permissions, a disk that went away), and that is a skip, not a crash.
        final bytes = File(target.imagePath!).readAsBytesSync();
        final temp = File('${file.path}.tmp')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(bytes, flush: true);
        temp.renameSync(file.path);
        restored.add(path);
      } on FileSystemException {
        skipped.add(RewindSkip(path, RewindSkipReason.imageUnavailable));
      }
    }
    if (restored.isNotEmpty || deleted.isNotEmpty) {
      // The tree shows these files; a rewind is exactly the change it cannot
      // see for itself, and so it announces itself like a tool write does.
      bumpFsRevision();
      _write();
      notifyListeners();
    }
    return RewindReport(restored: restored, deleted: deleted, skipped: skipped);
  }

  /// The decisions a rewind is made of: for every file the range touches, the
  /// entry holding the image to go back to, the entry the file must still match,
  /// and what (if anything) blocks it.
  ///
  /// Two different entries matter for one file, and conflating them is how a
  /// rewind goes too far or not far enough:
  ///   * the **newest** entry in scope answers "is this file still what the
  ///     agent left there?" — if not, somebody edited it afterwards, and
  ///     overwriting them is not an undo;
  ///   * the **oldest** entry at or after the target holds the image, because
  ///     the user asked for the state before *that* write, not before the last
  ///     one.
  List<_RewindTarget> _targets({
    required String id,
    required Workspace workspace,
    required RewindScope scope,
    String? conversation,
  }) {
    final eligible = [
      for (final entry in _byWorkspace[_key] ?? const <FileCheckpoint>[])
        if (scope == RewindScope.workspace ||
            (conversation != null && entry.conversation == conversation))
          entry,
    ];
    final target = eligible.indexWhere((entry) => entry.id == id);
    if (target < 0) return const [];

    final newest = <String, FileCheckpoint>{};
    final from = <String, FileCheckpoint>{};
    for (var i = 0; i < eligible.length; i++) {
      final entry = eligible[i];
      newest[entry.path] = entry;
      if (i >= target) from.putIfAbsent(entry.path, () => entry);
    }

    final paths = from.keys.toList()..sort();
    return [
      for (final path in paths)
        _resolve(goal: from[path]!, last: newest[path]!, workspace: workspace),
    ];
  }

  _RewindTarget _resolve({
    required FileCheckpoint goal,
    required FileCheckpoint last,
    required Workspace workspace,
  }) {
    if (!_stillAsLeft(last, File(workspace.resolve(last.path)))) {
      return _RewindTarget(goal, blocked: RewindSkipReason.changedOutsideAgent);
    }
    if (goal.wasCreated) return _RewindTarget(goal);
    final image = goal.beforeFingerprint == null
        ? null
        : '${_blobDir.path}/${goal.beforeFingerprint}.bin';
    if (!goal.captured || image == null || !File(image).existsSync()) {
      return _RewindTarget(goal, blocked: RewindSkipReason.imageUnavailable);
    }
    return _RewindTarget(goal, imagePath: image);
  }

  /// True when [file] still holds what the agent's last recorded write left
  /// there. Existence is part of the question, both ways: absent is consistent
  /// (a creation undone, or a file someone else removed — either way there are no
  /// bytes here to clobber), and present must match what was written, whether the
  /// entry called itself a creation or an edit.
  bool _stillAsLeft(FileCheckpoint last, File file) {
    if (!file.existsSync()) return true;
    try {
      return contentFingerprint(file.readAsBytesSync()) ==
          last.afterFingerprint;
    } on FileSystemException {
      return false;
    }
  }

  String _storeBlob(List<int> bytes) {
    final fingerprint = contentFingerprint(bytes);
    final file = File('${_blobDir.path}/$fingerprint.bin');
    if (file.existsSync()) return fingerprint;
    try {
      _blobDir.createSync(recursive: true);
      final temp = File('${file.path}.tmp')
        ..writeAsBytesSync(bytes, flush: true);
      temp.renameSync(file.path);
    } on FileSystemException {
      // Nothing was stored; the entry records itself as uncapturable and the
      // rewind says so instead of pretending the image exists.
      return fingerprint;
    }
    return fingerprint;
  }

  /// Drops whole entries from the oldest end until the stored images fit, then
  /// deletes the blobs no remaining entry names.
  void _prune() {
    final all = [for (final entries in _byWorkspace.values) ...entries]
      ..sort((a, b) => a.at.compareTo(b.at));
    var total = _storedBytes(all);
    final dropped = <FileCheckpoint>[];
    for (final entry in all) {
      if (total <= totalBudget) break;
      dropped.add(entry);
      total -= entry.beforeBytes ?? 0;
    }
    if (dropped.isEmpty) return;
    for (final entries in _byWorkspace.values) {
      entries.removeWhere(dropped.contains);
    }
    final kept = [for (final entries in _byWorkspace.values) ...entries];
    final referenced = {
      for (final entry in kept)
        if (entry.beforeFingerprint != null) entry.beforeFingerprint!,
    };
    try {
      for (final blob in _blobDir.listSync()) {
        if (blob is! File) continue;
        final name = blob.path.split('/').last;
        final fingerprint = name.substring(0, name.length - '.bin'.length);
        if (!referenced.contains(fingerprint)) blob.deleteSync();
      }
    } on FileSystemException {
      // A leftover blob is disk, not a wrong answer.
    }
  }

  int _storedBytes(List<FileCheckpoint> entries) {
    var total = 0;
    for (final entry in entries) {
      if (entry.beforeFingerprint == null) continue;
      total += entry.beforeBytes ?? 0;
    }
    return total;
  }

  void _write() {
    try {
      _indexFile.parent.createSync(recursive: true);
      final temp = File('${_indexFile.path}.tmp');
      temp.writeAsStringSync(
        jsonEncode({
          for (final group in _byWorkspace.entries)
            if (group.value.isNotEmpty)
              group.key: [for (final entry in group.value) entry.toJson()],
        }),
        flush: true,
      );
      temp.renameSync(_indexFile.path);
    } on FileSystemException {
      // The history stops being durable; the tools keep working, because an
      // agent that cannot be undone is a worse failure than an agent that
      // cannot write its undo file.
    }
  }
}
