// The bash backend. The rendering is tested against constructed runs — every
// marker's presence and position is a promise to a parser, and a real command
// cannot be made to produce all of them at once — and the execution is tested
// against a real `/bin/bash`, since what is worth checking about it (the working
// directory, the exit code, a command cut off by its budget) is only true of a
// real process.

import 'dart:io';

import 'package:agent_harness/genkit/shell_run.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// A finished run, spelled out.
ShellRun run({
  int exitCode = 0,
  String? signal,
  bool timedOut = false,
  int timeoutMs = 1000,
  String stdout = '',
  bool stdoutTruncated = false,
  String stderr = '',
}) => ShellRun(
  exitCode: exitCode,
  signal: signal,
  timedOut: timedOut,
  timeoutMs: timeoutMs,
  stdout: ShellStream(text: stdout, truncated: stdoutTruncated),
  stderr: ShellStream(text: stderr, truncated: false),
);

void main() {
  group('rendering', () {
    test('a clean run is its output, with nothing added', () {
      expect(renderShellRun(run(stdout: 'hello\n')), 'hello\n');
    });

    test('an empty run says so rather than being blank', () {
      // A blank result reads as a broken tool; `(no output)` reads as a command
      // that had nothing to say.
      expect(renderShellRun(run()), '(no output)');
    });

    test('stderr is labelled and follows stdout', () {
      expect(
        renderShellRun(run(stdout: 'out\n', stderr: 'bad\n')),
        'out\n[stderr]\nbad\n',
      );
    });

    test('a stdout without a trailing newline still gets its own line', () {
      expect(
        renderShellRun(run(stdout: 'out', stderr: 'bad')),
        'out\n[stderr]\nbad',
      );
    });

    test('stderr alone is still labelled', () {
      expect(renderShellRun(run(stderr: 'bad')), '[stderr]\nbad');
    });

    test('a non-zero exit ends with its marker', () {
      final text = renderShellRun(run(exitCode: 3, stdout: 'out\n'));

      // Last, always: dsh's own exit parser anchors on the end of the text.
      expect(text, 'out\n[exit code: 3]');
      expect(text.endsWith('[exit code: 3]'), isTrue);
    });

    test('a zero exit has no marker at all', () {
      expect(renderShellRun(run(stdout: 'out')), isNot(contains('exit code')));
    });

    test('a signal replaces the exit code', () {
      // The negated-signal exit code is not a code the user would recognise, so
      // the name is reported instead of both.
      final text = renderShellRun(run(exitCode: -15, signal: 'SIGTERM'));

      expect(text, '(no output)\n[killed by signal: SIGTERM]');
      expect(text, isNot(contains('exit code')));
    });

    test('a timeout is reported before how the process ended', () {
      final text = renderShellRun(
        run(timedOut: true, timeoutMs: 500, exitCode: -15, signal: 'SIGTERM'),
      );

      expect(
        text,
        '(no output)\n[timed out after 500ms]\n[killed by signal: SIGTERM]',
      );
    });

    test('a timeout is reported even when the command exited cleanly', () {
      // A command can trap the terminate signal and exit 0; "it finished" and "we
      // cut it off" lead the model to different next steps.
      expect(
        renderShellRun(run(timedOut: true, timeoutMs: 500, stdout: 'out')),
        'out\n[timed out after 500ms]',
      );
    });

    test('dropped output is announced above what survived', () {
      expect(
        renderShellRun(run(stdout: 'tail\n', stdoutTruncated: true)),
        '[output truncated; earlier output dropped]\ntail\n',
      );
    });
  });

  group('running', () {
    late Directory workdir;

    setUp(() {
      workdir = Directory.systemTemp.createTempSync('dsh_shell_test_');
    });

    tearDown(() => workdir.deleteSync(recursive: true));

    test('captures stdout and a zero exit', () async {
      final result = await runBash(command: 'echo hi', workdir: workdir.path);

      expect(result.stdout.text, 'hi\n');
      expect(result.exitCode, 0);
      expect(result.signal, isNull);
      expect(result.timedOut, isFalse);
      expect(renderShellRun(result), 'hi\n');
    });

    test('a non-zero exit is a result, not a thrown failure', () async {
      final result = await runBash(command: 'exit 7', workdir: workdir.path);

      expect(result.exitCode, 7);
      expect(renderShellRun(result), '(no output)\n[exit code: 7]');
    });

    test('keeps the two streams apart', () async {
      final result = await runBash(
        command: 'echo out; echo bad >&2',
        workdir: workdir.path,
      );

      expect(result.stdout.text, 'out\n');
      expect(result.stderr.text, 'bad\n');
    });

    test('runs in the given directory', () async {
      File(p.join(workdir.path, 'marker.txt')).writeAsStringSync('');

      final result = await runBash(command: 'ls', workdir: workdir.path);

      // The reason the tool takes a `workdir` instead of letting the model `cd`:
      // no state survives between calls, so the directory has to be a parameter.
      expect(result.stdout.text.trim(), 'marker.txt');
    });

    test('no state carries between calls', () async {
      await runBash(command: 'export MARK=1', workdir: workdir.path);
      final result = await runBash(
        command: 'echo "[\$MARK]"',
        workdir: workdir.path,
      );

      expect(result.stdout.text.trim(), '[]');
    });

    test('the last line of output is not lost to the exit', () async {
      // Awaiting only the exit code drops output written in the same breath.
      final result = await runBash(
        command: 'printf "final"; exit 0',
        workdir: workdir.path,
      );

      expect(result.stdout.text, 'final');
    });

    test('a command past its budget is cut off and says so', () async {
      final result = await runBash(
        command: 'sleep 30',
        workdir: workdir.path,
        timeout: const Duration(milliseconds: 200),
      );

      expect(result.timedOut, isTrue);
      expect(renderShellRun(result), contains('[timed out after 200ms]'));
    });

    test('output written before the budget ran out survives it', () async {
      final started = DateTime.now();
      final result = await runBash(
        // Two commands, so the shell does not exec into `sleep` — the signal
        // reaches the shell and leaves the sleep behind, holding the same pipes.
        command: 'echo early; sleep 30',
        workdir: workdir.path,
        timeout: const Duration(milliseconds: 200),
      );

      // The point of draining after the exit: a cut-off command's output is
      // usually the only evidence of how far it got.
      expect(result.stdout.text, 'early\n');
      expect(result.timedOut, isTrue);
      // And the point of bounding that drain: an orphan holding the pipes open
      // must not hold the tool call open with them.
      expect(
        DateTime.now().difference(started),
        lessThan(const Duration(seconds: 5)),
      );
    });

    test('a shell that cannot start is a thrown failure', () async {
      expect(
        () => runBash(
          command: 'echo hi',
          workdir: p.join(workdir.path, 'gone'),
        ),
        throwsA(isA<ProcessException>()),
      );
    });
  });
}
