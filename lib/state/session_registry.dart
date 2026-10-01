// The app's half of every conversation: a sidecar, not a second store
// (ADR-0039 D1).
//
// `<support>/sessions/sessions.json` — `{ "<sessionId>": { workspaceRoot,
// pinnedAt, deletedAt, title } }`. genkit writes the snapshots beside it and
// never reads this file, and `AgentRuntime.listSessions` scans only
// `.pointers/`, so one more document at the root of the sessions folder does
// not put app metadata in the runtime's way.
//
// Why four fields justify a file: a snapshot cannot answer which folder a run
// happened in, whether the user pinned it, whether the user deleted it, or what
// the user chose to call it. Everything else about a session already has a
// truth in the snapshot — above all the title, which is why `title` here is an
// *override* that `SessionIndex` resolves, never a second copy to keep equal.
//
// Deletion is a tombstone, matching the reference implementation's
// `{taskId}.deleted.json` (`_archive_project/ZCode-main/packages/services/src/paths.ts:217-224`):
// the row leaves the list, the bytes stay recoverable, and no user history is
// destroyed by a click that looked like a filter.
//
// Writes are synchronous tmp+rename. The document is small and every change is
// user-initiated (pin, rename, delete) or happens once per conversation
// (workspace). An async write would put the widget tests back in the FakeAsync
// trap ADR-0007 recorded, where a pending tmp+rename never completes and the
// test hangs with no failure and no stack.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/session_meta.dart';

/// Owns the live metadata map and the file the half lives in.
class SessionRegistry extends ChangeNotifier {
  SessionRegistry._(this._file, this._byId);

  static const fileName = 'sessions.json';

  /// Reads the sidecar in [sessionsRoot]. A document that cannot be parsed is
  /// treated as absent — the call `SettingsStore` makes: a corrupt metadata
  /// file must not brick the app, and must not be half-trusted.
  static SessionRegistry open(Directory sessionsRoot) {
    final file = File('${sessionsRoot.path}/$fileName');
    final byId = <String, SessionMeta>{};
    try {
      if (file.existsSync()) {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final value = entry.value;
            if (value is! Map) continue;
            try {
              byId[entry.key] = SessionMeta.fromJson(
                value.cast<String, dynamic>(),
              );
            } on FormatException {
              // One unreadable row drops; the rest of the file still counts.
            }
          }
        }
      }
    } on FileSystemException {
      // Unreadable: start from nothing.
    } on FormatException {
      // Not JSON: same.
    }
    return SessionRegistry._(file, byId);
  }

  final File _file;
  final Map<String, SessionMeta> _byId;
  String? _error;

  /// Set when the last write failed. The live map still answers, so the list is
  /// right until relaunch — which is exactly the kind of gap a user should be
  /// told about rather than discover later; `ui/primitives/feedback.dart` is the
  /// surface that reads this.
  String? get errorMessage => _error;

  SessionMeta metaOf(String sessionId) =>
      _byId[sessionId] ?? const SessionMeta();

  bool isDeleted(String sessionId) => metaOf(sessionId).isDeleted;

  /// The user's rename, if any. Null means "use the derived title".
  String? titleOf(String sessionId) => metaOf(sessionId).title;

  DateTime? pinnedAt(String sessionId) => metaOf(sessionId).pinnedAt;

  /// Every folder any session was started in. This half answers "where did
  /// history happen"; `AppSettings.recentWorkspaces` answers "what has the user
  /// opened", and the caller unions the two.
  Set<String> get knownWorkspaces => {
    for (final meta in _byId.values)
      if (meta.workspaceRoot != null) meta.workspaceRoot!,
  };

  /// Records which folder [sessionId] belongs to. First write wins: a
  /// conversation started in one folder does not move because the user switched
  /// workspaces while it was still on disk.
  void noteWorkspace(String sessionId, String? workspaceRoot) {
    if (workspaceRoot == null || workspaceRoot.isEmpty) return;
    final current = metaOf(sessionId);
    if (current.workspaceRoot != null) return;
    _put(
      sessionId,
      SessionMeta(
        workspaceRoot: workspaceRoot,
        pinnedAt: current.pinnedAt,
        deletedAt: current.deletedAt,
        title: current.title,
      ),
    );
  }

  void setPinned(String sessionId, bool pinned, {required DateTime now}) {
    final current = metaOf(sessionId);
    final next = pinned ? (current.pinnedAt ?? now) : null;
    if (current.pinnedAt == next) return;
    _put(
      sessionId,
      SessionMeta(
        workspaceRoot: current.workspaceRoot,
        pinnedAt: next,
        deletedAt: current.deletedAt,
        title: current.title,
      ),
    );
  }

  /// An empty title is not a rename: it would render a blank row and hide the
  /// derived title that was there before.
  void rename(String sessionId, String title) {
    final trimmed = title.trim();
    final current = metaOf(sessionId);
    if (trimmed.isEmpty || current.title == trimmed) return;
    _put(
      sessionId,
      SessionMeta(
        workspaceRoot: current.workspaceRoot,
        pinnedAt: current.pinnedAt,
        deletedAt: current.deletedAt,
        title: trimmed,
      ),
    );
  }

  /// A tombstone. Nothing on disk is removed — not the snapshot, not the saved
  /// workbench layout (ADR-0039 D4).
  void markDeleted(String sessionId, {required DateTime now}) {
    final current = metaOf(sessionId);
    if (current.isDeleted) return;
    _put(sessionId, current.copyWith(deletedAt: now));
  }

  void _put(String sessionId, SessionMeta meta) {
    if (meta.toJson().isEmpty) {
      _byId.remove(sessionId);
    } else {
      _byId[sessionId] = meta;
    }
    _persist();
    notifyListeners();
  }

  void _persist() {
    final temp = File('${_file.path}.tmp');
    try {
      temp.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          for (final entry in _byId.entries) entry.key: entry.value.toJson(),
        }),
        flush: true,
      );
      temp.renameSync(_file.path);
      _error = null;
    } on FileSystemException catch (error) {
      _error = error.message;
    }
  }
}
