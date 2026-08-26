// Task 6's acceptance gate: drive `AgentRuntime` from the command line, with no
// Flutter and no UI, and print every projected event.
//
// Run offline (checks the no-key and empty-store paths, then exits):
//   fvm dart run spike/runtime_smoke.dart
//
// Run against the real provider:
//   DEEPSEEK_API_KEY=sk-... fvm dart run spike/runtime_smoke.dart
//
// The live run exercises, in order: a plain streamed answer, the tool loop
// (listDir + readFile), and the approval round trip (writeFile -> interrupt ->
// resume), then restores the conversation from disk. Costs a few thousand tokens.
library;

import 'dart:io';

import 'package:agent_harness/genkit/agent_runtime.dart';
import 'package:agent_harness/model/app_settings.dart';
import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/model_settings.dart';
import 'package:agent_harness/model/turn_event.dart';

void banner(String title) {
  stdout.writeln('\n${'=' * 68}\n$title\n${'=' * 68}');
}

/// Prints a turn as it streams, and returns the approval it paused on, if any.
Future<ApprovalRequest?> drain(Stream<TurnEvent> events) async {
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

String _short(String s) => s.length <= 120 ? s : '${s.substring(0, 119)}…';

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
  File('${workspace.path}/hello.txt').writeAsStringSync(
    'The passphrase is "ochre lantern".\n',
  );
  File('${workspace.path}/notes.md').writeAsStringSync('# Notes\n\nnothing yet\n');
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
  stdout.writeln('  sessions in an empty store: '
      '${(await unconfigured.listSessions()).length}');
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

  final runtime = AgentRuntime(
    settings: AppSettings(model: ModelSettings(apiKey: key)),
    sessionRoot: sessions,
    support: Directory.systemTemp,
  )..workspaceRoot = workspace.path;

  // =========================================================================
  banner('1. plain streamed answer');
  // =========================================================================
  await drain(runtime.send('In one short sentence, what are you for?'));

  // =========================================================================
  banner('2. tool loop: listDir + readFile');
  // =========================================================================
  await drain(
    runtime.send(
      'List the files at the workspace root, then read hello.txt and tell me '
      'the passphrase.',
    ),
  );

  // =========================================================================
  banner('3. approval round trip: writeFile');
  // =========================================================================
  final pending = await drain(
    runtime.send('Append a line to notes.md recording the passphrase.'),
  );
  if (pending == null) {
    stdout.writeln('  !! expected an approval request; the gate did not fire');
  } else {
    stdout.writeln('  --> approving ${pending.ref}');
    await drain(
      runtime.respondToApproval(ref: pending.ref, approved: true),
    );
    stdout.writeln('  notes.md is now:');
    stdout.writeln(
      File('${workspace.path}/notes.md')
          .readAsLinesSync()
          .map((l) => '    $l')
          .join('\n'),
    );
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
