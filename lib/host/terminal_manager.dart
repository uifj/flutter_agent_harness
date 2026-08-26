// The pty pool behind the terminal tabs.
//
// A port of `DSH-better-sidebar/src/pty-manager.ts`, narrowed for an
// in-process host. The source is a webapp talking to a node process over a
// WebSocket, so its hard problems are the disconnect cases — the reconnect
// grace, the park frame, the transcript ring a reconnecting view replays. Here
// the pty is a Dart object in the same process as the view, and a terminal's
// lifetime is its tab body's lifetime: `pane.dart` keeps bodies mounted in an
// IndexedStack while the tab is open, so a shell survives tab switches and pane
// moves, and dies when the tab closes or the layout swaps to another session's
// tree. What survives from the source is the pooling shape that makes a repeat
// `open` reattach instead of leaking the old process, the shell-resolution
// chain, and the login-shell spawn flag.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';

/// The process half of one terminal, as the manager and the view see it.
///
/// An interface because `Pty` is an FFI-backed final class with nothing to
/// implement against, and because the pool's contract — reattach, respawn on
/// exit, kill on close — is worth testing without a real process.
abstract class TerminalProcess {
  /// Bytes the program has written. A pty merges stdout and stderr; so does
  /// this.
  Stream<Uint8List> get output;

  /// Completes with the process's exit code when it exits.
  Future<int> get exitCode;

  /// Sends input (keystrokes, pastes).
  void write(Uint8List data);

  /// Resizes the pty, rows first — `flutter_pty`'s convention, opposite the
  /// emulator's, so the flip belongs behind this seam.
  void resize(int rows, int cols);

  /// Terminates the process.
  void kill();
}

/// Spawns the process for one terminal. Injectable so tests can fake spawn
/// failures and I/O without a real pty.
typedef TerminalProcessSpawner =
    TerminalProcess Function({
      required String executable,
      required List<String> arguments,
      required String workingDirectory,
      required int columns,
      required int rows,
    });

TerminalProcess _spawnPty({
  required String executable,
  required List<String> arguments,
  required String workingDirectory,
  required int columns,
  required int rows,
}) => _PtyProcess(
  Pty.start(
    executable,
    arguments: arguments,
    workingDirectory: workingDirectory,
    columns: columns,
    rows: rows,
  ),
);

class _PtyProcess implements TerminalProcess {
  const _PtyProcess(this._pty);

  final Pty _pty;

  @override
  Stream<Uint8List> get output => _pty.output;

  @override
  Future<int> get exitCode => _pty.exitCode;

  @override
  void write(Uint8List data) => _pty.write(data);

  @override
  void resize(int rows, int cols) => _pty.resize(rows, cols);

  @override
  void kill() => _pty.kill();
}

/// The interactive shell a terminal tab runs, resolved like a terminal
/// emulator: `$SHELL` first (the deployment override), then the known POSIX
/// shells in order, then `/bin/bash` as the one POSIX promises exists.
///
/// Every input is injectable because the chain's job is to be wrong
/// differently on stripped-down machines, and the interesting wrongness never
/// runs on the machine that develops it.
String resolveShell({
  Map<String, String>? environment,
  bool Function(String path)? exists,
}) {
  final env = environment ?? Platform.environment;
  final probe = exists ?? (path) => File(path).existsSync();
  final envShell = env['SHELL'];
  if (envShell != null && envShell.trim().isNotEmpty) return envShell.trim();
  for (final candidate in const ['/bin/zsh', '/bin/bash']) {
    if (probe(candidate)) return candidate;
  }
  return '/bin/bash';
}

/// The arguments the shell is spawned with: POSIX shells get `-l` so they read
/// the profile files, which is what makes a tab behave like the user's own
/// terminal rather than a bare `sh`. Windows shells take no login flag.
List<String> shellSpawnArguments() =>
    Platform.isWindows ? const [] : const ['-l'];

/// One live terminal: the process, its streams, and the failure state a view
/// banners over.
class TerminalSession {
  TerminalSession._(this._process, this.error) {
    _done = _process == null
        ? Future<int?>.value()
        : _process.exitCode.then((code) {
            _exitCode = code;
            return code;
          });
  }

  /// A session whose spawn failed: nothing to read, nothing to write, and an
  /// explanation for the banner.
  TerminalSession.failed(String error) : this._(null, error);

  /// A session over a freshly spawned [process].
  TerminalSession.running(TerminalProcess process) : this._(process, null);

  final TerminalProcess? _process;

  /// Why the spawn failed, or null when the process ran.
  final String? error;

  late final Future<int?> _done;
  int? _exitCode;

  /// Bytes the program has written, decoded by the view.
  Stream<Uint8List> get output => _process?.output ?? const Stream.empty();

  /// The exit code once the process has exited; null while it runs (and
  /// forever, for a spawn that never happened).
  int? get exitCode => _exitCode;

  /// Completes when the process exits, with its code. A failed spawn completes
  /// immediately — there is nothing to outlive.
  Future<int?> get done => _done;

  /// False once there is no live process to talk to.
  bool get isAlive => _process != null && _exitCode == null;

  /// Sends input (keystrokes, pastes) to the process.
  void write(String data) =>
      _process?.write(Uint8List.fromList(utf8.encode(data)));

  /// Resizes the process to [columns] × [rows], in the emulator's argument
  /// order; the flip to `flutter_pty`'s rows-first convention happens here.
  void resize(int columns, int rows) => _process?.resize(rows, columns);

  /// Terminates the process. Idempotent.
  void kill() => _process?.kill();
}

/// The terminal pool: one session per terminal tab id, created on first open
/// and killed on close.
class TerminalManager {
  TerminalManager({TerminalProcessSpawner? spawner})
    : _spawn = spawner ?? _spawnPty;

  final TerminalProcessSpawner _spawn;

  final _sessions = <String, TerminalSession>{};

  /// The session for [tabId], spawning one on first use.
  ///
  /// A repeat open reattaches — that is the pool's whole job — unless the old
  /// process has exited, in which case it is replaced: reopening a dead
  /// terminal must yield a live shell, not an input sink.
  ///
  /// A spawn failure is *not* cached: the tab's retry has to reach a real
  /// spawn, not the memory of a failure.
  TerminalSession open(
    String tabId, {
    String? workingDirectory,
    int columns = 80,
    int rows = 24,
  }) {
    final existing = _sessions[tabId];
    if (existing != null && existing.isAlive) return existing;
    if (existing != null) _sessions.remove(tabId);
    try {
      final session = TerminalSession.running(
        _spawn(
          executable: resolveShell(),
          arguments: shellSpawnArguments(),
          // A packaged macOS app's process cwd is `/`, which makes for a
          // useless first prompt; HOME is the least surprising default when
          // no workspace has been granted.
          workingDirectory: workingDirectory ?? Platform.environment['HOME']!,
          columns: columns,
          rows: rows,
        ),
      );
      _sessions[tabId] = session;
      return session;
    } catch (error) {
      return TerminalSession.failed('$error');
    }
  }

  /// Kills the session for [tabId], if any. Safe for an id never opened.
  void close(String tabId) {
    _sessions.remove(tabId)?.kill();
  }

  /// Moves the session for [fromKey] to [toKey], for a conversation adoption:
  /// the same live shell, re-owned by the conversation it has become part of.
  ///
  /// A session already under [toKey] is killed rather than clobbered — the one
  /// being moved is the live one a view is attached to, and a stale entry under
  /// the new key can only be a session some earlier visit failed to retire.
  void rename(String fromKey, String toKey) {
    if (fromKey == toKey) return;
    final moved = _sessions.remove(fromKey);
    if (moved == null) return;
    _sessions.remove(toKey)?.kill();
    _sessions[toKey] = moved;
  }

  /// Kills every session. For the owning controller's teardown.
  void dispose() {
    for (final session in _sessions.values.toList()) {
      session.kill();
    }
    _sessions.clear();
  }
}
