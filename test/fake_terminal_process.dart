// A fake pty for the terminal tests.
//
// Implements the [TerminalProcess] seam the manager injects, so a test can
// drive output, exit and kill without spawning a real shell — which matters
// twice over: a widget test that spawned zsh would leak a process per pump,
// and the interesting behaviour (what the view does when the process dies)
// is exactly what a real shell will not do on cue.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:agent_harness/host/terminal_manager.dart';

class FakeTerminalProcess implements TerminalProcess {
  FakeTerminalProcess();

  final _output = StreamController<Uint8List>.broadcast();
  final _exit = Completer<int>();

  /// Everything keystroke-sending code has written, decoded for assertions.
  final writes = <String>[];

  /// `rows x cols` per resize, in the manager's argument order.
  final resizes = <String>[];

  var killed = false;

  int? _exited;

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  /// Whether the process has exited by any path.
  bool get exited => _exited != null || killed;

  @override
  void write(Uint8List data) => writes.add(utf8.decode(data));

  @override
  void resize(int rows, int cols) => resizes.add('${rows}x$cols');

  @override
  void kill() {
    if (exited) return;
    killed = true;
    _finish(0);
  }

  /// Emits [text] as the program's output.
  void emit(String text) => _output.add(Uint8List.fromList(utf8.encode(text)));

  /// Exits with [code], the way a shell does when the user types `exit`.
  void exit([int code = 0]) {
    if (exited) return;
    _finish(code);
  }

  void _finish(int code) {
    _exited = code;
    _output.close();
    _exit.complete(code);
  }
}

/// A spawner handing out [FakeTerminalProcess]es, recording what it started.
/// [failNext] models the spawn failure a machine with no usable shell
/// produces — once per count, because the manager's contract is that a
/// failure is never cached.
class FakeTerminalSpawner {
  FakeTerminalSpawner({this.failNext = 0});

  int failNext;
  final spawned = <FakeTerminalProcess>[];

  /// The executables and working directories each spawn was asked for.
  final spawnArgs = <(String, String)>[];

  TerminalProcess call({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    required int columns,
    required int rows,
  }) {
    if (failNext > 0) {
      failNext--;
      throw StateError('no pty for you');
    }
    final process = FakeTerminalProcess();
    spawned.add(process);
    spawnArgs.add((executable, workingDirectory));
    return process;
  }

  /// A [TerminalManager] over this spawner.
  TerminalManager manager() => TerminalManager(spawner: call);
}
