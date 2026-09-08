// Spike (task 3 of the plan): probe the real shape of the Genkit agent runtime
// before any projection logic is written against it.
//
// Runs entirely offline against scripted fake models, so it is deterministic
// and needs no API key. Kept in the repo as executable evidence for the
// findings below — re-run it after any genkit version bump.
//
// Run: fvm dart run spike/agent_spike.dart
//
// =============================== FINDINGS ==================================
//
// 1. `Part` is ONE json-backed type. `part is TextPart` and `switch (part) {
//    TextPart() => ... }` NEVER match — every part's runtimeType is `Part` and
//    `TextPart`/`ToolRequestPart` are only factory constructors. Discriminate
//    via `PartExtension`: isText/text, isToolRequest/toolRequest,
//    isToolResponse/toolResponse, isMedia/media, isData.
//
// 2. `SchemanticType.jsonSchema(...)` does not exist. Runtime schemas are built
//    with `SchemanticType.from<T>(jsonSchema: {...}, parse: ...)`.
//
// 3. Real token streaming works: one `AgentChunk` per model `sendChunk`.
//    `chunk.text` is the delta. `chunk.accumulatedText` is TURN-global — it
//    keeps accumulating across model calls within one turn, so it cannot be
//    used as a single message's body. Group by `chunk.raw.modelChunk.index`.
//
// 4. Chunk taxonomy inside one turn:
//      text        -> raw.modelChunk {role: model, index: N, content:[{text}]}
//      toolRequest -> raw.modelChunk {role: model, index: N, content:[{toolRequest}]}
//      toolResponse-> raw.modelChunk {role: tool,  index: N, content:[{toolResponse}]}
//      turn end    -> raw.turnEnd    {snapshotId, finishReason}
//    `AgentChunk` exposes `toolRequests` but has NO toolResponse accessor — the
//    tool result must be read off `raw.modelChunk.content` via isToolResponse.
//
// 5. An interrupting tool's request is streamed TWICE: once plain, then again
//    carrying `metadata.interrupt` with the payload passed to
//    `context.interrupt(...)`. Tool cards MUST dedupe by `toolRequest.ref`.
//
// 6. Approval round trip confirmed end to end:
//    tool calls `context.interrupt(payload)` -> turn ends with
//    finishReason `interrupted` and `response.interrupts` populated ->
//    `chat.resumeStream(restart: [interrupt.restart({'approved': true})])`
//    re-runs the tool with `context.resumed == {'approved': true}`.
//    Denial is the same call with `respond:` instead of `restart:`.
//
// 7. CANCELLATION DOES NOT INTERRUPT ANYTHING (genkit 0.15.1).
//    Measured: cancel() at t=400ms of a 3s turn -> onCancel fired and
//    isCancelled became true, yet the model ran to completion, all 31 chunks
//    were still delivered, and finishReason was `stop` (not `aborted`).
//    Why: `AgentTurn.abort()` is literally `token.cancel()`; the token is only
//    consulted (a) as a pre-flight short-circuit before the turn starts and
//    (b) in catch blocks, to relabel an already-thrown error as `aborted`.
//    `ActionFnArg` has no cancellation field at all, so the model fn — and
//    therefore the provider HTTP request — never sees the signal, and the whole
//    maxTurns tool loop runs inside a single `generate` that ignores it.
//    => The stop button must be implemented client-side: cancel the token for
//       bookkeeping AND stop consuming the stream, marking the turn cancelled
//       immediately. To also prevent FURTHER model calls, a
//       `GenerateMiddleware.model` hook that throws when our own flag is set
//       cuts the loop at the next turn boundary. The in-flight request still
//       finishes (and is still billed) — an accepted limitation.
//
// 8. `chat.messages` is NOT the transcript. After a tool-loop turn it held only
//    [user, model] (2) while the persisted snapshot held the full
//    [user, model, tool, model] (4). Build the transcript by projecting chunks;
//    use `loadChat` for restore.
//
// 9. FileSessionStore layout (dirPath = store root):
//      <root>/global/<snapshotId>.json            one per turn
//      <root>/global/.pointers/<sessionId>.json   {currentSnapshotId, updatedAt}
//    `global` is the default context prefix. `SessionStore` has no list API, so
//    the session list is a scan of the `.pointers` directory (filename =
//    sessionId, `updatedAt` for ordering).
//
// 10. `defineAgent` without a `stateSchema` infers `State = dynamic`.
//     `Genkit(promptDir: null)` avoids the prompt-directory lookup.
//
// 11. USAGE: `AgentOutput` carries no usage block (0.16.1). The providers fill
//     `ModelResponse.usage` on the model seam, so any token accounting must be
//     a `GenerateMiddleware.model` hook accumulating from `next(...).usage` —
//     see `_UsageCapture` in agent_runtime.dart, and probe E below.
//
// 12. CUSTOM STATE: `defineAgent` with a `stateSchema` only emits `customPatch`
//     chunks when the agent actively writes state (a scripted model never does,
//     so probe F reports `sawCustom=false`). A planned sub-agent progress
//     channel must therefore drive state from a tool or a custom agent fn, not
//     from the model alone.
//
// 13. TOOL v2: genkit 0.16 made tools return `ToolResult<Output>` — `.response`,
//     `.interrupt` — and deprecated the throwing `context.interrupt`. Bare-map
//     returns no longer type-check. Migrated in tools.dart / plan_tools.dart.
//
// 14. RESTORE (0.16.1): `loadChat` hydrates the full snapshot history,
//     [user, model, tool, model] — the tool turn survives. The restore bug
//     recorded in the earlier report was fixed at the projection layer; see
//     test/restore_projection_test.dart for the locked contract.
//
// ===========================================================================
library;

import 'dart:async';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';
import 'package:schemantic/schemantic.dart';

/// Tool input schema built at runtime. Note this is `SchemanticType.from`, not
/// a `jsonSchema(...)` constructor — the latter does not exist.
SchemanticType<Map<String, dynamic>> objectSchema(
  Map<String, Object?> properties, {
  List<String> required = const [],
}) => SchemanticType.from<Map<String, dynamic>>(
  jsonSchema: {
    'type': 'object',
    'properties': properties,
    if (required.isNotEmpty) 'required': required,
  },
  parse: (json) => (json as Map).cast<String, dynamic>(),
);

void banner(String title) {
  stdout.writeln('\n${'=' * 68}\n$title\n${'=' * 68}');
}

/// Dumps everything an [AgentChunk] exposes, so we can see which accessors are
/// populated in practice rather than guessing from the docs.
///
/// The type argument is `dynamic` because `defineAgent` without a `stateSchema`
/// infers `State = dynamic`.
void dumpChunk(int i, AgentChunk<dynamic> c) {
  final turnEnd = c.raw.turnEnd;
  stdout.writeln(
    '  chunk[$i] '
    'text=${c.text.isEmpty ? '-' : '"${c.text}"'} '
    'reasoning=${c.reasoning.isEmpty ? '-' : '"${c.reasoning}"'} '
    'accumulated="${c.accumulatedText}" '
    'toolRequests=${c.toolRequests.map((t) => '${t.toolRequest.name}(${t.toolRequest.input})').toList()} '
    'data=${c.data} media=${c.media} '
    'artifact=${c.artifact?.toJson()} '
    'custom=${c.custom} '
    'turnEnd=${turnEnd == null ? '-' : '{snapshotId=${turnEnd.snapshotId}, finishReason=${turnEnd.finishReason?.value}}'}',
  );
  stdout.writeln('          raw=${c.raw.toJson()}');
}

void dumpResponse(String label, AgentResponse<dynamic> r) {
  stdout.writeln(
    '  $label: finishReason=${r.finishReason.value} '
    'text="${r.text}" '
    'toolRequests=${r.toolRequests.map((t) => t.toolRequest.name).toList()} '
    'interrupts=${r.interrupts.map((i) => '${i.name}(${i.input})').toList()} '
    'messages=${r.messages.length} '
    'sessionId=${r.sessionId} snapshotId=${r.snapshotId} '
    'state=${r.state} artifacts=${r.artifacts.length}',
  );
}

/// A model whose replies are scripted per call, so the agent loop is fully
/// deterministic. [script] is consumed one entry per model invocation.
void defineScriptedModel(
  Genkit ai,
  String name,
  List<ModelResponse> Function(int call, ModelRequest req) script,
) {
  var call = 0;
  ai.defineModel(
    name: name,
    fn: (request, ctx) async {
      final index = call++;
      final responses = script(index, request);
      final response = responses.last;
      stdout.writeln(
        '    [model $name call#$index] '
        'streamingRequested=${ctx.streamingRequested} '
        'incoming messages=${request.messages.length} '
        'roles=${request.messages.map((m) => m.role.value).toList()} '
        'tools=${request.tools?.map((t) => t.name).toList()}',
      );
      var sent = 0;
      if (ctx.streamingRequested) {
        // Stream the final message's text in small slices to mimic token
        // streaming, then emit any non-text parts as their own chunk.
        //
        // NOTE: `part is TextPart` does NOT work. Every part's runtime type is
        // plain `Part` (a JSON-backed view); `TextPart` is only a factory
        // constructor. Discrimination must go through `PartExtension`.
        for (final part in response.message?.content ?? const <Part>[]) {
          final text = part.text;
          if (text != null) {
            for (final piece in _slice(text, 4)) {
              ctx.sendChunk(
                ModelResponseChunk(content: [TextPart(text: piece)]),
              );
              sent++;
              await Future<void>.delayed(const Duration(milliseconds: 5));
            }
          } else {
            ctx.sendChunk(ModelResponseChunk(content: [part]));
            sent++;
          }
        }
      }
      stdout.writeln('    [model $name call#$index] sendChunk calls=$sent');
      return response;
    },
  );
}

Iterable<String> _slice(String s, int size) sync* {
  for (var i = 0; i < s.length; i += size) {
    yield s.substring(i, i + size > s.length ? s.length : i + size);
  }
}

ModelResponse modelText(String text) => ModelResponse(
  message: Message(role: Role.model, content: [TextPart(text: text)]),
  finishReason: FinishReason.stop,
);

ModelResponse modelToolCall(String tool, Map<String, dynamic> input,
        {String? text, String ref = 'r1'}) =>
    ModelResponse(
      message: Message(
        role: Role.model,
        content: [
          if (text != null) TextPart(text: text),
          ToolRequestPart(
            toolRequest: ToolRequest(name: tool, ref: ref, input: input),
          ),
        ],
      ),
      finishReason: FinishReason.stop,
    );

Future<void> main() async {
  final sessionDir = Directory.systemTemp.createTempSync('dsh_spike_');
  stdout.writeln('session store dir: ${sessionDir.path}');

  final ai = Genkit(promptDir: null);

  // ---- tools -------------------------------------------------------------
  final listDir = ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'listDir',
    description: 'List entries of a directory.',
    inputSchema: objectSchema(
      {'path': {'type': 'string', 'description': 'Directory to list.'}},
      required: ['path'],
    ),
    fn: (input, context) async {
      stdout.writeln('    [tool listDir] input=$input resumed=${context.resumed}');
      return ToolResult.response({
        'entries': ['a.txt', 'b.txt'],
        'path': input['path'],
      });
    },
  );

  // Approval-gated tool: interrupts on first entry, proceeds once resumed.
  final writeFile = ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'writeFile',
    description: 'Write a file. Requires user approval.',
    inputSchema: objectSchema(
      {
        'path': {'type': 'string'},
        'contents': {'type': 'string'},
      },
      required: ['path', 'contents'],
    ),
    fn: (input, context) async {
      final resumed = context.resumed;
      stdout.writeln('    [tool writeFile] input=$input resumed=$resumed');
      if (resumed == null) {
        // Pauses the whole generate loop and surfaces as an interrupt.
        return ToolResult.interrupt({
          'needsApproval': true,
          'path': input['path'],
        });
      }
      if (resumed is Map && resumed['approved'] != true) {
        return ToolResult.response({'ok': false, 'reason': 'denied by user'});
      }
      return ToolResult.response({'ok': true, 'written': input['path']});
    },
  );

  // =======================================================================
  banner('A. streamed turn with a tool loop (2 model calls, maxTurns)');
  // =======================================================================
  defineScriptedModel(ai, 'loop', (call, req) {
    return switch (call) {
      0 => [modelToolCall('listDir', {'path': '/tmp'},
          text: 'Let me look at that directory. ')],
      _ => [modelText('There are 2 files: a.txt and b.txt.')],
    };
  });

  final loopAgent = ai.defineAgent(
    name: 'loopAgent',
    model: modelRef('loop'),
    system: 'You are a helpful file assistant.',
    tools: [listDir],
    maxTurns: 8,
    store: FileSessionStore(sessionDir.path),
  );

  final loopChat = loopAgent.chat();
  final loopTurn = loopChat.sendStream(text: 'What is in /tmp?');
  var i = 0;
  await for (final chunk in loopTurn.stream) {
    dumpChunk(i++, chunk);
  }
  dumpResponse('response', await loopTurn.response);
  stdout.writeln(
    '  chat: sessionId=${loopChat.sessionId} snapshotId=${loopChat.snapshotId} '
    'messages=${loopChat.messages.length} '
    'roles=${loopChat.messages.map((m) => m.role.value).toList()}',
  );

  // =======================================================================
  banner('B. interrupt -> approve -> resume');
  // =======================================================================
  defineScriptedModel(ai, 'approval', (call, req) {
    return switch (call) {
      0 => [
          modelToolCall('writeFile', {'path': '/tmp/x.txt', 'contents': 'hi'},
              text: 'Writing that file. ')
        ],
      _ => [modelText('Done, the file is written.')],
    };
  });

  final approvalAgent = ai.defineAgent(
    name: 'approvalAgent',
    model: modelRef('approval'),
    tools: [writeFile],
    maxTurns: 8,
    store: FileSessionStore(sessionDir.path),
  );

  final approvalChat = approvalAgent.chat();
  final t1 = approvalChat.sendStream(text: 'Write hi to /tmp/x.txt');
  i = 0;
  await for (final chunk in t1.stream) {
    dumpChunk(i++, chunk);
  }
  final paused = await t1.response;
  dumpResponse('paused', paused);

  if (paused.finishReason == AgentFinishReason.interrupted &&
      paused.interrupts.isNotEmpty) {
    final interrupt = paused.interrupts.first;
    stdout.writeln('  --> approving interrupt "${interrupt.name}"');
    final t2 = approvalChat.resumeStream(
      restart: [interrupt.restart({'approved': true})],
    );
    i = 0;
    await for (final chunk in t2.stream) {
      dumpChunk(i++, chunk);
    }
    dumpResponse('resumed', await t2.response);
  } else {
    stdout.writeln('  !! expected an interrupt, got '
        '${paused.finishReason.value} — approval path needs rework');
  }

  // =======================================================================
  banner('C. cancellation mid-turn');
  // =======================================================================
  // The model deliberately takes 3s so there is a real in-flight window to
  // cancel, and reports whether it observed the cancellation itself.
  ai.defineModel(
    name: 'slow',
    fn: (request, ctx) async {
      stdout.writeln('    [model slow] start, '
          'streamingRequested=${ctx.streamingRequested}');
      for (var n = 0; n < 30; n++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (ctx.streamingRequested) {
          ctx.sendChunk(ModelResponseChunk(content: [TextPart(text: 'tok$n ')]));
        }
      }
      stdout.writeln('    [model slow] finished all 30 slices (NOT aborted)');
      return modelText('done');
    },
  );
  final slowAgent = ai.defineAgent(
    name: 'slowAgent',
    model: modelRef('slow'),
    maxTurns: 4,
    store: FileSessionStore(sessionDir.path),
  );
  final cancel = CancellationToken();
  cancel.onCancel(() => stdout.writeln('  [token] onCancel fired'));
  final slowChat = slowAgent.chat();
  final slowTurn = slowChat.sendStream(text: 'stream a lot', cancel: cancel);
  // Cancel from outside the stream loop, 400ms in.
  Timer(const Duration(milliseconds: 400), () {
    stdout.writeln('  --> cancel() + abort() at t=400ms');
    cancel.cancel();
    slowTurn.abort();
  });
  final startedAt = DateTime.now();
  i = 0;
  try {
    await for (final chunk in slowTurn.stream) {
      dumpChunk(i++, chunk);
    }
    stdout.writeln('  stream closed after '
        '${DateTime.now().difference(startedAt).inMilliseconds}ms, '
        '$i chunks');
    dumpResponse('after cancel', await slowTurn.response);
  } catch (e) {
    stdout.writeln('  stream/response threw after '
        '${DateTime.now().difference(startedAt).inMilliseconds}ms: '
        '${e.runtimeType}: $e');
  }
  stdout.writeln('  token.isCancelled=${cancel.isCancelled}');

  // =======================================================================
  banner('D. persistence: loadChat recovers history');
  // =======================================================================
  final sessionId = loopChat.sessionId;
  stdout.writeln('  reloading sessionId=$sessionId');
  if (sessionId != null) {
    final restored = await loopAgent.loadChat(sessionId: sessionId);
    stdout.writeln(
      '  restored: messages=${restored.messages.length} '
      'roles=${restored.messages.map((m) => m.role.value).toList()} '
      'snapshotId=${restored.snapshotId}',
    );
    for (final m in restored.messages) {
      stdout.writeln('    ${m.role.value}: ${_describeMessage(m)}');
    }
  }
  stdout.writeln('  snapshot files (recursive):');
  for (final f in sessionDir.listSync(recursive: true)) {
    final rel = f.path.substring(sessionDir.path.length + 1);
    final size = f is File ? '${f.lengthSync()}B' : 'dir';
    stdout.writeln('    $rel ($size)');
  }

  // =======================================================================
  banner('E. usage block on ModelResponse (0.16 fill behaviour)');
  // =======================================================================
  // The agent surface (AgentOutput) carries no usage, so the runtime's usage
  // middleware reads it off the model seam. This pins what a scripted model
  // has to report for the middleware to accumulate — i.e. the contract the
  // app's _UsageCapture counts on.
  ai.defineModel(
    name: 'metered',
    fn: (request, ctx) async {
      final response = modelText('metered');
      return ModelResponse(
        message: response.message,
        finishReason: response.finishReason,
        usage: GenerationUsage(
          inputTokens: 21,
          outputTokens: 7,
          totalTokens: 28,
          thoughtsTokens: 3,
        ),
      );
    },
  );
  final usageAgent = ai.defineAgent(
    name: 'usageAgent',
    model: modelRef('metered'),
    maxTurns: 2,
    store: FileSessionStore(sessionDir.path),
  );
  final usageChat = usageAgent.chat();
  final usageTurn = usageChat.sendStream(text: 'meter me');
  await for (final _ in usageTurn.stream) {}
  final usageResp = await usageTurn.response;
  stdout.writeln(
    '  AgentOutput has no usage (${usageResp.raw.toString().contains('usage') ? 'present!' : 'absent — read it at the model seam'}).',
  );

  // =======================================================================
  banner('F. customPatch: typed custom state streams per chunk');
  // =======================================================================
  // The planned sub-agent progress channel rides `chunk.custom`; this confirms
  // a defineAgent with a stateSchema + prompt can emit custom-state patches a
  // runtime can subscribe to, and whether the first patch is a whole-document
  // replace (the reported behaviour the projection must tolerate).
  final patchAgent = ai.defineAgent<dynamic, dynamic, Map<String, dynamic>>(
    name: 'patchAgent',
    model: modelRef('loop'),
    system: 'patch probe',
    maxTurns: 2,
    stateSchema: SchemanticType.from<Map<String, dynamic>>(
      jsonSchema: {'type': 'object'},
      parse: (json) => (json as Map).cast<String, dynamic>(),
    ),
    store: FileSessionStore(sessionDir.path),
  );
  final patchChat = patchAgent.chat();
  final patchTurn = patchChat.sendStream(text: 'go');
  var sawCustom = false;
  await for (final chunk in patchTurn.stream) {
    if (chunk.custom != null) {
      sawCustom = true;
      stdout.writeln('    chunk.custom=${chunk.custom}');
    }
  }
  stdout.writeln('  sawCustom=$sawCustom');

  await ai.shutdown();
  sessionDir.deleteSync(recursive: true);
  stdout.writeln('\nspike done.');
}

String _describeMessage(Message m) => m.content.map((p) {
  if (p.isText) return 'text("${p.text}")';
  if (p.isToolRequest) return 'toolRequest(${p.toolRequest!.name})';
  if (p.isToolResponse) {
    return 'toolResponse(${p.toolResponse!.name} -> ${p.toolResponse!.output})';
  }
  return 'other(${p.toJson().keys.toList()})';
}).join(', ');
