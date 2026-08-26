// Where a session's workbench layout lives between launches.
//
// One file per session under `<support>/workbench/`, not one document holding
// them all: sessions are opened one at a time and deleted independently, and a
// single file would make every layout change rewrite every session's layout.
//
// Writes are debounced. A split drag emits a state per frame, and each one is a
// whole-file write; better-sidebar debounces the same edge at 200ms
// (`src/store.ts`) and this matches it rather than inventing a second number.
// The debounce is per session, so binding away from a session cannot let its
// pending write land under the next one's name.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../model/sidebar_state.dart';

/// Reads and writes per-session layouts.
class WorkbenchStore {
  WorkbenchStore(this.directory);

  /// Opens the store under [support], creating its directory.
  static WorkbenchStore open(Directory support) {
    final directory = Directory('${support.path}/workbench');
    directory.createSync(recursive: true);
    return WorkbenchStore(directory);
  }

  /// How long a change waits for the next one before hitting the disk.
  static const debounce = Duration(milliseconds: 200);

  final Directory directory;

  final _pending = <String, Timer>{};
  final _latest = <String, SidebarState>{};

  /// The layout stored for [sessionId], or null when there is none to restore.
  ///
  /// A corrupt file reads as absent: a lost layout is a fresh workbench, while
  /// throwing here would take the session down with it.
  SidebarState? load(String sessionId) {
    final file = _fileFor(sessionId);
    try {
      if (!file.existsSync()) return null;
      final decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map) return null;
      return SidebarState.fromJson(decoded);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Schedules [state] to be written for [sessionId].
  ///
  /// The last state within one debounce window wins; the intermediate ones are
  /// dropped rather than queued, which is the point — they were frames of a drag.
  void save(String sessionId, SidebarState state) {
    _latest[sessionId] = state;
    _pending[sessionId]?.cancel();
    _pending[sessionId] = Timer(debounce, () => _write(sessionId));
  }

  /// Writes every pending layout now.
  ///
  /// Called on quit and when the controller binds away from a session: a
  /// debounce that outlives the reason to write is a lost layout.
  Future<void> flush() async {
    final ids = _pending.keys.toList();
    for (final id in ids) {
      _pending.remove(id)?.cancel();
      await _write(id);
    }
  }

  /// Forgets a session's layout, for when the session itself is gone.
  void delete(String sessionId) {
    _pending.remove(sessionId)?.cancel();
    _latest.remove(sessionId);
    try {
      final file = _fileFor(sessionId);
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // Already gone, or not ours to remove. Either way there is nothing to do.
    }
  }

  /// Cancels pending writes without performing them. For tests and teardown;
  /// [flush] is what a caller that wants the bytes wants.
  void dispose() {
    for (final timer in _pending.values) {
      timer.cancel();
    }
    _pending.clear();
    _latest.clear();
  }

  Future<void> _write(String sessionId) async {
    final state = _latest[sessionId];
    if (state == null) return;
    final file = _fileFor(sessionId);
    try {
      // Written to a sibling and renamed, as `SettingsStore.save` does: an
      // interrupted write must not leave a truncated file for the next launch to
      // discard, because discarding it is discarding the layout.
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(jsonEncode(state.toJson()), flush: true);
      await temp.rename(file.path);
    } on FileSystemException {
      // A layout is not worth failing a turn over. The next change tries again.
    }
  }

  /// Session ids come from the runtime and could in principle contain a
  /// separator; anything that is not plainly safe is replaced rather than
  /// trusted, so one cannot name a file outside [directory].
  File _fileFor(String sessionId) {
    final safe = sessionId.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return File('${directory.path}/${safe.isEmpty ? 'unnamed' : safe}.json');
  }
}
