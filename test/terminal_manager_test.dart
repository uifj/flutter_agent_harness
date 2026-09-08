// The pty pool's own contract, without a widget in sight.
//
// What is pinned here is the reattach discipline — the one property that
// separates a pool from a factory — plus the shell-resolution chain, whose
// job is to be wrong differently on stripped-down machines and therefore
// cannot be tested against the machine that develops it.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:agent_harness/host/terminal_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_terminal_process.dart';

/// A process whose output is a single-subscription stream, the way a real
/// `flutter_pty` `Pty.output` (a `ReceivePort`) behaves. The fake above is
/// broadcast, which is why the pane-move reattach bug never surfaced in tests.
class _SingleSubProcess implements TerminalProcess {
  final _output = StreamController<Uint8List>();
  final _exit = Completer<int>();

  @override
  Stream<Uint8List> get output => _output.stream;

  @override
  Future<int> get exitCode => _exit.future;

  @override
  void write(Uint8List data) {}

  @override
  void resize(int rows, int cols) {}

  @override
  void kill() {
    _output.close();
    _exit.complete(0);
  }
}

void main() {
  group('TerminalManager', () {
    test('open spawns once per key and reattaches while alive', () {
      final fake = FakeTerminalSpawner();
      final manager = fake.manager();

      final first = manager.open('t');
      final second = manager.open('t');

      expect(fake.spawned, hasLength(1));
      expect(identical(first, second), isTrue);
      expect(first.isAlive, isTrue);
    });

    test('a repeat open of a dead session spawns a replacement', () async {
      final fake = FakeTerminalSpawner();
      final manager = fake.manager();

      final dead = manager.open('t');
      fake.spawned.single.exit(0);
      // The exit reaches the session's liveness through its exitCode future,
      // so the replacement is spawned only once that has landed.
      await dead.done;

      final replacement = manager.open('t');
      expect(fake.spawned, hasLength(2));
      expect(identical(dead, replacement), isFalse);
      expect(replacement.isAlive, isTrue);
    });

    // The retry button on the spawn-failure banner has to reach a real
    // spawn; caching the failure would make it replay the banner instead.
    test('a failed spawn is not cached', () {
      final fake = FakeTerminalSpawner(failNext: 1);
      final manager = fake.manager();

      final failed = manager.open('t');
      expect(failed.error, isNotNull);
      expect(failed.isAlive, isFalse);
      expect(fake.spawned, isEmpty);

      final retried = manager.open('t');
      expect(retried.error, isNull);
      expect(fake.spawned, hasLength(1));
    });

    test('close kills the session for that key and only that key', () {
      final fake = FakeTerminalSpawner();
      final manager = fake.manager();
      manager.open('a');
      manager.open('b');
      final a = fake.spawned[0];
      final b = fake.spawned[1];

      manager.close('a');

      expect(a.killed, isTrue);
      expect(b.killed, isFalse);
      // And the slot is gone, so the next open is a fresh process.
      manager.open('a');
      expect(fake.spawned, hasLength(3));
    });

    test('close of a key never opened is a no-op', () {
      final manager = FakeTerminalSpawner().manager();
      manager.close('nothing');
    });

    test('dispose kills every session', () {
      final fake = FakeTerminalSpawner();
      final manager = fake.manager();
      manager.open('a');
      manager.open('b');
      manager.open('c');

      manager.dispose();

      for (final process in fake.spawned) {
        expect(process.killed, isTrue);
      }
    });

    test('sessions are keyed by their key, not their shell', () {
      final fake = FakeTerminalSpawner();
      final manager = fake.manager();

      manager.open('one/t');
      manager.open('two/t');

      expect(fake.spawned, hasLength(2));
    });

    test('the spawn gets the working directory it was handed', () {
      final fake = FakeTerminalSpawner();
      final manager = fake.manager();

      manager.open('t', workingDirectory: '/somewhere/else');

      expect(fake.spawnArgs.single.$2, '/somewhere/else');
    });

    test('rename moves a live session to its new key', () {
      final fake = FakeTerminalSpawner();
      final manager = fake.manager();
      final session = manager.open('draft/t');

      manager.rename('draft/t', 'n1/t');

      expect(fake.spawned, hasLength(1));
      expect(manager.open('n1/t'), same(session));
      // The old key no longer reattaches it: a fresh process instead.
      expect(manager.open('draft/t'), isNot(same(session)));
      expect(fake.spawned, hasLength(2));
    });

    test('rename kills whatever squats the destination key', () {
      final fake = FakeTerminalSpawner();
      final manager = fake.manager();
      final live = manager.open('draft/t');
      manager.open('n1/t');
      final stale = fake.spawned[1];

      manager.rename('draft/t', 'n1/t');

      expect(stale.killed, isTrue);
      expect(manager.open('n1/t'), same(live));
      expect(fake.spawned, hasLength(2));
    });

    test('rename of a key with no session is a no-op', () {
      final fake = FakeTerminalSpawner();
      final manager = fake.manager();

      manager.rename('nothing', 'somewhere');

      expect(fake.spawned, isEmpty);
    });

    test('a single-subscription pty output is broadcast for a pane-move reattach',
        () async {
      // Real flutter_pty output is single-subscription; a tab moving between
      // panes attaches a new body to the pooled session before the old body
      // detaches, so the second listen must not throw.
      final manager = TerminalManager(
        spawner: ({
          required executable,
          required arguments,
          required workingDirectory,
          required columns,
          required rows,
        }) => _SingleSubProcess(),
      );
      final session = manager.open('t');

      final first = <String>[];
      final second = <String>[];
      session.output.listen(
        (bytes) => first.add(String.fromCharCodes(bytes)),
      );
      session.output.listen(
        (bytes) => second.add(String.fromCharCodes(bytes)),
      );
    });
  });

  group('resolveShell', () {
    test('SHELL wins when it is set to something', () {
      expect(
        resolveShell(environment: {'SHELL': '/opt/bin/fish'}, exists: (_) => false),
        '/opt/bin/fish',
      );
    });

    test('a blank SHELL falls through to the probe chain', () {
      expect(
        resolveShell(environment: {'SHELL': '  '}, exists: (_) => false),
        '/bin/bash',
      );
    });

    test('zsh is preferred over bash when both exist', () {
      expect(
        resolveShell(environment: const {}, exists: (_) => true),
        '/bin/zsh',
      );
    });

    test('bash when zsh is missing', () {
      expect(
        resolveShell(
          environment: const {},
          exists: (path) => path == '/bin/bash',
        ),
        '/bin/bash',
      );
    });

    test('/bin/bash as the last resort, POSIX\'s promise', () {
      expect(resolveShell(environment: const {}, exists: (_) => false), '/bin/bash');
    });
  });

  group('shellSpawnArguments', () {
    test('is a login shell off Windows, and nothing on it', () {
      final args = shellSpawnArguments();
      if (Platform.isWindows) {
        expect(args, isEmpty);
      } else {
        expect(args, const ['-l']);
      }
    });
  });
}
