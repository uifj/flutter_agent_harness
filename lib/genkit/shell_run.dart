// The bash tool's backend: run a command, bound its output, say how it ended.
//
// A port of `tool-bash/src/index.ts`'s execution shape and `render.ts`'s
// model-facing text. dsh runs this through a shell service with a sandbox seam,
// process-tree termination and a spill file for dropped output; there is none of
// that here, and the three places it shows are marked below — the point of
// keeping the port in one small file is that those three stay visible.
//
// One thing is deliberately identical: `bash -c` per call, no persistent session.
// dsh's schema says it in as many words ("Each call runs in a fresh shell: no
// state (cwd, variables, functions) persists between calls"), and a model that
// has been told that will pass `workdir` instead of leading with `cd` — so
// matching the semantics is what makes the tool description true.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Default command budget. dsh leaves this to its executor's configuration; two
/// minutes is long enough for a test run or an install and short enough that a
/// command waiting on stdin — which nothing here can ever answer — does not hang
/// the turn until the user notices.
const bashTimeout = Duration(minutes: 2);

/// After the terminate signal, before the kill. A command that traps SIGTERM to
/// clean up gets a moment to do it; one that traps it to ignore it does not get
/// to outlive the call.
const bashKillGrace = Duration(seconds: 2);

/// Retained per stream, as the tail. dsh truncates to the tail too, for the same
/// reason: a failing command's last lines are the ones that say why.
const bashMaxStreamBytes = 24 * 1024;

/// How long the streams get to finish after the process has exited.
///
/// Normally they are already done, and this never comes into play. It exists for
/// the case below: a command that leaves a child behind hands that child the same
/// pipes, so the pipes do not close when the command does — and waiting for them
/// unconditionally would hang the call for as long as the orphan lives, which is
/// the one outcome a timeout is supposed to rule out.
const bashDrainGrace = Duration(seconds: 1);

/// One captured stream.
class ShellStream {
  const ShellStream({required this.text, required this.truncated});

  final String text;

  /// Whether earlier output was dropped to stay inside the cap. dsh names the
  /// spill file it wrote instead; here the notice is all there is, so it says
  /// what was lost rather than where to find it.
  final bool truncated;
}

/// A finished run.
class ShellRun {
  const ShellRun({
    required this.exitCode,
    required this.signal,
    required this.timedOut,
    required this.timeoutMs,
    required this.stdout,
    required this.stderr,
  });

  /// The process's own code, or the negated signal number when it was killed —
  /// which is what [signal] is derived from.
  final int exitCode;

  /// The signal name when the process was killed, else null.
  final String? signal;

  final bool timedOut;
  final int timeoutMs;
  final ShellStream stdout;
  final ShellStream stderr;
}

/// Runs [command] in a fresh `bash -c` rooted at [workdir].
///
/// Never throws for the command's own outcome — a non-zero exit is a result, not
/// a failure, and the caller renders it as one. A shell that cannot be spawned at
/// all is a different matter and does throw [ProcessException].
Future<ShellRun> runBash({
  required String command,
  required String workdir,
  Duration timeout = bashTimeout,
  int maxStreamBytes = bashMaxStreamBytes,
}) async {
  final process = await Process.start(
    '/bin/bash',
    ['-c', command],
    workingDirectory: workdir,
    // The app's own environment, minus nothing: the user's PATH is what makes
    // their toolchain reachable, and a scrubbed environment would make half of
    // what they ask for fail in ways they cannot see from here.
    includeParentEnvironment: true,
  );

  final out = _Tail(maxStreamBytes);
  final err = _Tail(maxStreamBytes);
  // Subscriptions, not `forEach`: these have to be cancellable, because the
  // grace below can expire with the streams still open. `onError` swallows a
  // decode-level stream error for the same reason the decoder allows malformed
  // input — losing the output we did get is worse than showing it imperfectly.
  final outSub = process.stdout
      .transform(_decoder)
      .listen(out.write, onError: (_) {});
  final errSub = process.stderr
      .transform(_decoder)
      .listen(err.write, onError: (_) {});
  final drained = Future.wait([
    outSub.asFuture<void>(),
    errSub.asFuture<void>(),
  ]);

  var timedOut = false;
  Timer? killer;
  final expiry = Timer(timeout, () {
    timedOut = true;
    process.kill(ProcessSignal.sigterm);
    // Only the shell process is signalled. dsh's subprocess seam terminates the
    // whole tree; doing that here would need the child in its own process group,
    // which `Process.start` cannot ask for — so a command that backgrounds a
    // grandchild can outlive its own timeout. It is a real gap, not an oversight,
    // and [bashDrainGrace] is what keeps it from becoming a hung call.
    killer = Timer(bashKillGrace, () => process.kill(ProcessSignal.sigkill));
  });

  final code = await process.exitCode;
  expiry.cancel();
  killer?.cancel();
  // After the exit, not before: a process can produce its last line and exit in
  // the same breath, and awaiting only the exit code drops it. Bounded, because
  // an orphaned grandchild holds these pipes open after its parent is gone.
  await drained.timeout(bashDrainGrace, onTimeout: () => const []);
  await outSub.cancel();
  await errSub.cancel();

  return ShellRun(
    exitCode: code,
    // POSIX exit codes are non-negative; Dart reports a signalled death as the
    // negated signal number, which is the only way to tell the two apart.
    signal: code < 0 ? _signalName(-code) : null,
    timedOut: timedOut,
    timeoutMs: timeout.inMilliseconds,
    stdout: out.stream(),
    stderr: err.stream(),
  );
}

/// The text the model sees: `renderResult`, with the sandbox markers dropped
/// because nothing here confines the command.
///
/// The exit marker stays last, as the source's comment requires — dsh's own
/// `parseExitStatus` anchors on the end of the text, and a marker after it would
/// silently break the parse.
String renderShellRun(ShellRun run) {
  final out = _streamText(run.stdout);
  final err = _streamText(run.stderr);

  var body = out;
  if (err.isNotEmpty) {
    if (body.isNotEmpty && !body.endsWith('\n')) body += '\n';
    body += '[stderr]\n$err';
  }
  if (body.isEmpty) body = '(no output)';

  final markers = <String>[];
  // A command may trap SIGTERM and exit 0 after the timeout; the interruption is
  // reported either way, because "it finished" and "we cut it off" lead the model
  // to different next steps.
  if (run.timedOut) markers.add('[timed out after ${run.timeoutMs}ms]');
  if (run.signal != null) {
    markers.add('[killed by signal: ${run.signal}]');
  } else if (run.exitCode != 0) {
    markers.add('[exit code: ${run.exitCode}]');
  }
  if (markers.isEmpty) return body;
  if (!body.endsWith('\n')) body += '\n';
  return body + markers.join('\n');
}

String _streamText(ShellStream stream) => stream.truncated
    ? '[output truncated; earlier output dropped]\n${stream.text}'
    : stream.text;

/// Decoded as it arrives, malformed bytes included: a command's output is not
/// guaranteed to be UTF-8, and a decode failure would lose output that was
/// otherwise perfectly readable.
final _decoder = const Utf8Decoder(allowMalformed: true);

/// A bounded tail buffer.
///
/// Chunks are kept whole and dropped from the front, so the cap is honoured
/// within one chunk's slack rather than exactly. Cutting mid-chunk would be
/// exact and would also cut through a grapheme; for a display tail, the slack is
/// the better trade.
class _Tail {
  _Tail(this.maxBytes);

  final int maxBytes;
  final _chunks = <String>[];
  var _bytes = 0;
  var _dropped = false;

  void write(String chunk) {
    _chunks.add(chunk);
    _bytes += chunk.length;
    while (_bytes > maxBytes && _chunks.length > 1) {
      _bytes -= _chunks.removeAt(0).length;
      _dropped = true;
    }
  }

  ShellStream stream() =>
      ShellStream(text: _chunks.join(), truncated: _dropped);
}

/// The signals a killed command here can plausibly have died of.
///
/// Only the ones this runtime sends, plus the two a shell hands on from the
/// system, are named; anything else keeps its number, which is more useful than a
/// wrong name.
String _signalName(int number) => switch (number) {
  2 => 'SIGINT',
  9 => 'SIGKILL',
  11 => 'SIGSEGV',
  13 => 'SIGPIPE',
  15 => 'SIGTERM',
  _ => 'signal $number',
};
