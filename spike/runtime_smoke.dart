// Task 6's acceptance gate: drive `AgentRuntime` from the command line, with no
// Flutter and no UI, and print every projected event.
//
// Run offline (checks the no-key and empty-store paths, then exits):
//   fvm dart run spike/runtime_smoke.dart
//
// Run against the real provider:
//   DEEPSEEK_API_KEY=sk-... fvm dart run spike/runtime_smoke.dart
//
// The live run exercises, in order: a plain streamed answer, the tool loop, the
// approval round trip (a gated tool -> interrupt -> resume), the before-image a
// file write hands to `CheckpointSink` (ADR-0014), then restores the
// conversation from disk. Costs a few thousand tokens.
//
// What this file cannot check: the rewind itself. `CheckpointStore` is a
// `ChangeNotifier`, so importing it here would drag `dart:ui` into a plain
// `dart run` — the very dependency ADR-0015 removed. The mirror of that
// sequence (write -> someone else edits the file -> the conflict guard refuses)
// runs against a real temp directory in `test/checkpoint_test.dart` instead.
library;

import 'dart:io';

import 'package:agent_harness/genkit/agent_runtime.dart';
import 'package:agent_harness/model/app_settings.dart';
import 'package:agent_harness/model/checkpoint.dart';
import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/model_settings.dart';
import 'package:agent_harness/model/turn_event.dart';

void banner(String title) {
  stdout.writeln('\n${'=' * 68}\n$title\n${'=' * 68}');
}

/// Records what the tools handed over, so the live run can assert on real bytes.
///
/// Deliberately not `CheckpointStore`: see the header. It keeps the entries in
/// memory because the question here is only whether the capture happened with
/// the right before-image.
class RecordingSink implements CheckpointSink {
  final List<FileCheckpoint> entries = [];
  final Map<String, List<int>> beforeBytes = {};
  final Map<String, List<int>> afterBytes = {};

  @override
  String? conversation;

  @override
  FileCheckpoint? record({
    required String path,
    required List<int> after,
    List<int>? before,
  }) {
    final entry = FileCheckpoint(
      id: 'r${entries.length}',
      conversation: conversation ?? '',
      path: path,
      change: before == null
          ? CheckpointChange.created
          : CheckpointChange.modified,
      captured: before != null,
      beforeFingerprint: before == null ? null : contentFingerprint(before),
      afterFingerprint: contentFingerprint(after),
      beforeBytes: before?.length,
      afterBytes: after.length,
      at: DateTime.now(),
    );
    entries.add(entry);
    if (before != null) beforeBytes[path] = before;
    afterBytes[path] = after;
    stdout.writeln(
      '  checkpoint ${entry.id}: $path ${entry.change.name} '
      '(${before?.length ?? 'none'} bytes -> ${after.length} bytes)',
    );
    return entry;
  }
}

/// Prints a turn as it streams, and returns the approval it paused on, if any.
///
/// Tool outputs are collected into [outputs] when given, so a caller can read a
/// value out of a result (the checkpoint id, say) rather than only its text.
Future<ApprovalRequest?> drain(
  Stream<TurnEvent> events, {
  List<Object?>? outputs,
}) async {
  ApprovalRequest? pending;
  var textRun = 0;
  await for (final event in events) {
    switch (event) {
      case TextDelta(:final text, :final messageIndex):
        // Deltas are printed raw so streaming is visible as it happens.
        if (textRun == 0) stdout.write('  text[$messageIndex] ');
        textRun++;
        stdout.write(text);
      case ReasoningDelta(:final text):
        if (textRun > 0) {
          stdout.writeln();
          textRun = 0;
        }
        stdout.write('  reasoning: $text');
      case ToolCallRequested(:final ref, :final name, :final arguments):
        if (textRun > 0) {
          stdout.writeln();
          textRun = 0;
        }
        stdout.writeln('  tool -> $name($arguments) [ref=$ref]');
      case ToolCallSucceeded(:final ref, :final output):
        outputs?.add(output);
        stdout.writeln('  tool <- ok [ref=$ref] ${_short('$output')}');
      case ToolCallFailed(:final ref, :final message):
        stdout.writeln('  tool <- FAILED [ref=$ref] $message');
      case ApprovalRequired(:final request):
        pending = request;
        stdout.writeln(
          '  APPROVAL needed: ${request.toolName} '
          'args=${request.arguments} details=${request.details}',
        );
      case TurnFinished(
        :final outcome,
        :final sessionId,
        :final snapshotId,
        :final errorMessage,
      ):
        if (textRun > 0) stdout.writeln();
        stdout.writeln(
          '  finished: ${outcome.name} session=$sessionId '
          'snapshot=$snapshotId${errorMessage == null ? '' : ' error=$errorMessage'}',
        );
    }
  }
  return pending;
}

/// Answers every approval a turn asks for, until it finishes on its own.
///
/// Which tool the model reaches for is the model's choice, so the run cannot
/// assume it is the one the prompt was worded for: a `bash ls` instead of a
/// `listDir` pauses the turn all the same, and leaving that unanswered is what
/// makes the next send fail.
Future<void> approveAll(
  AgentRuntime runtime,
  ApprovalRequest? pending, {
  List<Object?>? outputs,
}) async {
  var ask = pending;
  var answered = 0;
  while (ask != null) {
    if (answered == 5) {
      stdout.writeln('  !! still asking after 5 approvals; giving up here');
      return;
    }
    stdout.writeln('  --> approving ${ask.ref} (${ask.toolName})');
    answered++;
    ask = await drain(
      runtime.respondToApproval(ref: ask.ref, approved: true),
      outputs: outputs,
    );
  }
}

String _short(String s) => s.length <= 120 ? s : '${s.substring(0, 119)}…';

bool _sameBytes(List<int>? a, List<int>? b) {
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

void dumpTranscript(List<ConversationNode> nodes) {
  for (final node in nodes) {
    final line = switch (node) {
      UserMessageNode(:final text) => 'user: ${_short(text)}',
      AssistantMessageNode(:final text, :final reasoning) =>
        'assistant: ${_short(text)}'
            '${reasoning.isEmpty ? '' : ' (+${reasoning.length}B reasoning)'}',
      ToolCallNode(:final name, :final status, :final output) =>
        'tool $name [${status.name}] ${_short('$output')}',
      ErrorNode(:final message) => 'error: $message',
    };
    stdout.writeln('  ${node.id}  $line');
  }
}

Future<void> main() async {
  final sessions = Directory.systemTemp.createTempSync('dsh_smoke_sessions_');
  final workspace = Directory.systemTemp.createTempSync('dsh_smoke_ws_');
  File(
    '${workspace.path}/hello.txt',
  ).writeAsStringSync('The passphrase is "ochre lantern".\n');
  File(
    '${workspace.path}/notes.md',
  ).writeAsStringSync('# Notes\n\nnothing yet\n');
  stdout.writeln('sessions: ${sessions.path}\nworkspace: ${workspace.path}');

  final key = Platform.environment['DEEPSEEK_API_KEY'];

  // =========================================================================
  banner('0. offline checks (no provider traffic)');
  // =========================================================================
  final unconfigured = AgentRuntime(
    settings: const AppSettings(),
    sessionRoot: sessions,
    support: Directory.systemTemp,
  );
  stdout.writeln(
    '  sessions in an empty store: '
    '${(await unconfigured.listSessions()).length}',
  );
  stdout.writeln('  sending without a key:');
  await drain(unconfigured.send('hello?'));
  await unconfigured.dispose();

  if (key == null || key.isEmpty) {
    stdout.writeln(
      '\nDEEPSEEK_API_KEY is not set, so the live turns are skipped.\n'
      'Re-run with the key to complete task 6\'s acceptance.',
    );
    sessions.deleteSync(recursive: true);
    workspace.deleteSync(recursive: true);
    return;
  }

  final sink = RecordingSink()..conversation = 'smoke';
  final runtime = AgentRuntime(
    settings: AppSettings(model: ModelSettings(apiKey: key)),
    sessionRoot: sessions,
    support: Directory.systemTemp,
    checkpoints: sink,
  )..workspaceRoot = workspace.path;

  // =========================================================================
  banner('1. plain streamed answer');
  // =========================================================================
  await drain(runtime.send('In one short sentence, what are you for?'));

  // =========================================================================
  banner('2. tool loop, with whatever tool the model picks');
  // =========================================================================
  // It may answer this with `listDir` or with a gated `bash ls`, and either is a
  // working tool loop — but the second pauses, so the approval has to be
  // answered before anything else is sent.
  await approveAll(
    runtime,
    await drain(
      runtime.send(
        'List the files at the workspace root, then read hello.txt and tell me '
        'the passphrase.',
      ),
    ),
  );

  // =========================================================================
  banner('3. approval round trip + the before-image it captures (ADR-0014)');
  // =========================================================================
  final notes = File('${workspace.path}/notes.md');
  final beforeWrite = notes.readAsBytesSync();
  stdout.writeln(
    '  notes.md on disk before the turn: ${beforeWrite.length} bytes',
  );
  final outputs = <Object?>[];
  await approveAll(
    runtime,
    await drain(
      runtime.send(
        'Append a line to notes.md recording the passphrase. Use the file '
        'editing tool for it.',
      ),
      outputs: outputs,
    ),
    outputs: outputs,
  );
  stdout.writeln('  notes.md is now:');
  stdout.writeln(notes.readAsLinesSync().map((l) => '    $l').join('\n'));

  final onNotes = [
    for (final e in sink.entries)
      if (e.path == 'notes.md') e,
  ];
  if (onNotes.isEmpty) {
    stdout.writeln(
      '  !! nothing was captured for notes.md '
      '(the sink saw: ${sink.entries.map((e) => e.path).join(', ')})',
    );
    exitCode = 1;
  } else {
    final entry = onNotes.last;
    stdout.writeln('  captured: ${entry.path} ${entry.change.name}');
    final onDisk = notes.readAsBytesSync();
    if (contentFingerprint(onDisk) != entry.afterFingerprint) {
      stdout.writeln('  !! the after fingerprint does not match the disk');
      exitCode = 1;
    }
    final recorded = sink.beforeBytes[entry.path];
    if (entry.change == CheckpointChange.modified &&
        !_sameBytes(recorded, beforeWrite)) {
      stdout.writeln(
        '  !! the before-image is not the bytes that were on disk '
        '(${recorded?.length} recorded vs ${beforeWrite.length} on disk)',
      );
      exitCode = 1;
    }
    // The id is what the tool card's rewind pill reads, so a capture the UI
    // cannot point at is only half a capture.
    final surfaced = outputs.any(
      (o) => o is Map && o['checkpoint'] == entry.id,
    );
    stdout.writeln(
      '  ${surfaced ? 'ok' : '!!'}: the tool result carried checkpoint id '
      '${entry.id} back to the caller',
    );
    if (!surfaced) exitCode = 1;
  }

  // =========================================================================
  banner('4. restore from disk');
  // =========================================================================
  final sessionId = runtime.sessionId;
  stdout.writeln('  listed sessions:');
  for (final summary in await runtime.listSessions()) {
    stdout.writeln(
      '    ${summary.id}  ${summary.updatedAt.toIso8601String()}  '
      '${summary.title}',
    );
  }
  await runtime.dispose();

  if (sessionId != null) {
    final reopened = AgentRuntime(
      settings: AppSettings(model: ModelSettings(apiKey: key)),
      sessionRoot: sessions,
      support: Directory.systemTemp,
    );
    stdout.writeln('  transcript restored from $sessionId:');
    dumpTranscript(await reopened.openSession(sessionId));
    await reopened.dispose();
  }

  sessions.deleteSync(recursive: true);
  workspace.deleteSync(recursive: true);
  stdout.writeln('\nsmoke done.');
}
