// A recorded before-image of a file the agent overwrote, and the change
// detector that makes a rewind safe (ADR-0014).
//
// Two things live here and both are framework-free by necessity: the value is
// written to disk by `lib/state/` and produced by a tool in `lib/genkit/`, so it
// can belong to neither of those layers.
//
// The shape is deliberate: a **before-image**, not a patch, and not a shadow
// repository. Restoring needs only what the file used to be; the after side is
// kept as a fingerprint so a rewind can tell whether anything else has touched
// the file since — which is the difference between an undo and a clobber.

import 'dart:typed_data';

/// What the agent did to the file, as far as this record can tell.
///
/// There is no `deleted`: the agent has no delete tool (`write` and `edit` are
/// the only file mutations this app can intercept — ADR-0014's background).
enum CheckpointChange { created, modified }

/// A change detector for bytes, not a security hash.
///
/// FNV-1a over the content, rendered as the raw 8 bytes in hex, suffixed with
/// the length. Its only job is to answer "is this the same file the tool
/// wrote?", so it is small, dependency-free and stable; it is not collision
/// resistant and is never used for anything that would care.
String contentFingerprint(List<int> bytes) {
  const offset = -3750768443400849715; // 0xcbf29ce484222325, as a signed 64-bit
  const prime = 1099511628211; // 0x100000001b3
  var hash = offset;
  for (final byte in bytes) {
    hash ^= byte & 0xff;
    // Dart's int is 64-bit two's complement on the VM, so this wraps exactly
    // the way FNV-1a says it should.
    hash = hash * prime;
  }
  final buffer = ByteData(8)..setInt64(0, hash);
  final hex = StringBuffer();
  for (var i = 0; i < 8; i++) {
    hex.write(buffer.getUint8(i).toRadixString(16).padLeft(2, '0'));
  }
  return '$hex-${bytes.length}';
}

class FileCheckpoint {
  FileCheckpoint({
    required this.id,
    required this.conversation,
    required this.path,
    required this.change,
    required this.captured,
    required this.afterFingerprint,
    required this.afterBytes,
    required this.at,
    this.beforeFingerprint,
    this.beforeBytes,
  });

  /// Minted by the store. The tool's output carries it so the card that shows
  /// the change can point at the record without guessing by path — two writes
  /// to one file make a path lookup ambiguous, and a wrong guess rewinds the
  /// wrong thing.
  final String id;

  /// Which conversation made the change. The store mints it from its own
  /// counter for a conversation that has no id yet, and renames it to the
  /// persisted session id as soon as one exists — one field, because two that
  /// must agree would be one more way to be wrong.
  String conversation;

  /// Workspace-relative, exactly as the approval panel showed it. A rewind that
  /// reported a different string than the one the user approved would be the
  /// same divergence ADR-0012 forbids between a rule's subject and a prompt.
  final String path;

  final CheckpointChange change;

  /// False when the before-image was not stored — the file was over the size
  /// cap — which means this entry can be *named* in a report but cannot be
  /// undone. Never pretend otherwise.
  final bool captured;

  final String? beforeFingerprint;
  final String afterFingerprint;
  final int? beforeBytes;
  final int afterBytes;
  final DateTime at;

  bool get wasCreated => change == CheckpointChange.created;

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversation': conversation,
    'path': path,
    'change': change.name,
    'captured': captured,
    if (beforeFingerprint != null) 'before': beforeFingerprint,
    'after': afterFingerprint,
    if (beforeBytes != null) 'beforeBytes': beforeBytes,
    'afterBytes': afterBytes,
    'at': at.toIso8601String(),
  };

  /// Strict: an entry whose shape is not understood is dropped by the caller
  /// rather than guessed at. A half-read checkpoint index would offer a rewind
  /// against the wrong file, and that is the one mistake this feature cannot
  /// make.
  factory FileCheckpoint.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final conversation = json['conversation'];
    final path = json['path'];
    final change = json['change'];
    final after = json['after'];
    final afterBytes = json['afterBytes'];
    final at = json['at'];
    if (id is! String ||
        conversation is! String ||
        path is! String ||
        after is! String ||
        afterBytes is! int ||
        at is! String) {
      throw const FormatException('A checkpoint row is missing its identity.');
    }
    final changeName = change is String ? change : '';
    return FileCheckpoint(
      id: id,
      conversation: conversation,
      path: path,
      change: CheckpointChange.values.firstWhere(
        (value) => value.name == changeName,
        orElse: () => throw ArgumentError.value(
          change,
          'change',
          'Unknown checkpoint change kind.',
        ),
      ),
      captured: json['captured'] == true,
      beforeFingerprint: json['before'] is String
          ? json['before'] as String
          : null,
      afterFingerprint: after,
      beforeBytes: json['beforeBytes'] is int
          ? json['beforeBytes'] as int
          : null,
      afterBytes: afterBytes,
      at: DateTime.parse(at),
    );
  }
}

/// The only surface a tool needs to record a change.
///
/// It is an interface in `lib/model/` because the producer lives in
/// `lib/genkit/` (which may not import `lib/state/`) and the implementation
/// lives there (which may not be imported by genkit). A null sink — the shape
/// tests and previews use — leaves the tools exactly as they were.
abstract interface class CheckpointSink {
  /// The conversation the *next* recorded change belongs to. The composition
  /// root names it when the app opens, switches or starts a session; the store
  /// stamps the real session id onto those entries once the first turn reports
  /// one. A null is the unowned state: changes are recorded with no conversation
  /// rather than dropped, because losing the before-image is the worse failure.
  String? get conversation;
  set conversation(String? value);

  /// Records one overwrite of [path]. [before] is the bytes that were there
  /// (null when the file did not exist), [after] the bytes now on disk. Returns
  /// the record, or null when nothing was stored at all.
  FileCheckpoint? record({
    required String path,
    required List<int> after,
    List<int>? before,
  });
}
