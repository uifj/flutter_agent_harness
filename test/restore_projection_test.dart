// The restore contract, locked as a regression test.
//
// `projectMessages` rebuilds a transcript from a snapshot's own message list —
// the one place tool turns are guaranteed to survive (spike finding 8: a live
// chat's list omits them). These tests build that message list by hand, the
// way FileSessionStore persists it, and pin what comes back: tool calls pair
// with their results by ref, a call left mid-flight stays running, reasoning
// rides along, and the plan tools replay their state off the same list.
//
// This file imports `package:genkit` to *construct* the persisted shapes; the
// architecture rule (genkit confined to `lib/genkit/`) is about `lib/`, and a
// test that builds store data is exactly the consumer that needs the types.

import 'package:agent_harness/genkit/agent_runtime.dart' show AgentRuntime;
import 'package:agent_harness/genkit/plan_tools.dart';
import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/todo_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genkit/genkit.dart';

Message _user(String text) =>
    Message(role: Role.user, content: [TextPart(text: text)]);

Message _model(List<Part> content) =>
    Message(role: Role.model, content: content);

Message _tool(List<Part> content) =>
    Message(role: Role.tool, content: content);

Part _request(String ref, String name, Map<String, dynamic> input) =>
    ToolRequestPart(
      toolRequest: ToolRequest(ref: ref, name: name, input: input),
    );

Part _response(String ref, String name, Object? output) => ToolResponsePart(
  toolResponse: ToolResponse(ref: ref, name: name, output: output),
);

void main() {
  test('a full round trip restores user, tool call and assistant text', () {
    final nodes = AgentRuntime.projectMessages([
      _user('read the config'),
      _model([
        _request('r1', 'read', {
          'file_path': 'pubspec.yaml',
        }),
      ]),
      _tool([_response('r1', 'read', {'path': 'pubspec.yaml', 'lines': 30})]),
      _model([
        ReasoningPart(reasoning: 'thinking it through'),
        TextPart(text: 'Here is what the config holds.'),
      ]),
    ]);

    expect(nodes, hasLength(3));
    expect(nodes[0], isA<UserMessageNode>());
    final call = nodes[1] as ToolCallNode;
    expect(call.name, 'read');
    expect(call.arguments['file_path'], 'pubspec.yaml');
    expect(call.status, ToolStatus.succeeded);
    expect((call.output as Map)['lines'], 30);
    final answer = nodes[2] as AssistantMessageNode;
    expect(answer.text, 'Here is what the config holds.');
    expect(answer.reasoning, 'thinking it through');
  });

  test('two assistant messages keep their order around a tool call', () {
    final nodes = AgentRuntime.projectMessages([
      _user('go'),
      _model([TextPart(text: 'Looking.')]),
      _model([_request('r1', 'grep', {'pattern': 'x'})]),
      _tool([_response('r1', 'grep', {'total': 0})]),
      _model([TextPart(text: 'Nothing matched.')]),
    ]);

    expect(
      nodes.map((n) => n.runtimeType).toList(),
      [
        UserMessageNode,
        AssistantMessageNode,
        ToolCallNode,
        AssistantMessageNode,
      ],
    );
  });

  test('a call persisted mid-flight comes back running, not invented', () {
    final nodes = AgentRuntime.projectMessages([
      _user('go'),
      _model([_request('r1', 'write', {'file_path': 'a.txt'})]),
    ]);

    final call = nodes[1] as ToolCallNode;
    expect(call.status, ToolStatus.running);
    expect(call.output, isNull);
  });

  test('an ok:false output settles the call as failed with its message', () {
    final nodes = AgentRuntime.projectMessages([
      _user('go'),
      _model([_request('r1', 'edit', {'file_path': 'a.txt'})]),
      _tool([
        _response('r1', 'edit', {'ok': false, 'error': 'not found once'}),
      ]),
    ]);

    final call = nodes[1] as ToolCallNode;
    expect(call.status, ToolStatus.failed);
    expect(call.errorMessage, 'not found once');
  });

  test('a response with no matching request is dropped, not fatal', () {
    final nodes = AgentRuntime.projectMessages([
      _user('go'),
      _tool([_response('orphan', 'read', {'lines': 1})]),
    ]);

    expect(nodes, hasLength(1));
  });

  test('reasoning survives restore on its own channel', () {
    final nodes = AgentRuntime.projectMessages([
      _user('go'),
      _model([
        ReasoningPart(reasoning: 'chain of thought'),
        TextPart(text: 'Answer.'),
      ]),
    ]);

    final answer = nodes[1] as AssistantMessageNode;
    expect(answer.reasoning, 'chain of thought');
    expect(answer.text, 'Answer.');
  });

  test('PlanTools replays todo_write and plan state off the same list', () {
    final tools = PlanTools(Genkit(promptDir: null));
    tools.restoreFrom([
      _user('plan this'),
      _model([_request('r1', 'todo_write', {})]),
      _tool([
        _response('r1', 'todo_write', {
          'ok': true,
          'todos': [
            {'content': 'step one', 'status': 'completed'},
            {'content': 'step two', 'status': 'in_progress'},
          ],
        }),
      ]),
      _model([_request('r2', 'plan', {})]),
      _tool([
        _response('r2', 'plan', {
          'ok': true,
          'plan': '1. one\n2. two',
        }),
      ]),
    ]);

    expect(tools.todos, hasLength(2));
    expect(tools.todos[0].status, TodoStatus.completed);
    expect(tools.todos[1].status, TodoStatus.inProgress);
    expect(tools.plan, '1. one\n2. two');
  });
}
