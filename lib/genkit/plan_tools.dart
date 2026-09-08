// The task-planning tools: todo_write and plan.
//
// dsh's todo/plan capabilities, projected onto this app's single-agent
// runtime. Both are plain JSON-in/JSON-out so the transcript can render them
// without knowing anything about Genkit, and both keep their state in the
// conversation itself — the tool output IS the state, persisted with the
// snapshot and replayed on restore by `todosFromToolOutput` / the plan text.
//
// The live copies live on this object so the UI can read them between turns;
// they are rebuilt from the transcript when a session is opened, which is why
// the tools never need their own store.

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import '../model/todo_state.dart';

/// Registers the planning tools against [ai] and holds their latest state.
class PlanTools {
  PlanTools(this._ai);

  final Genkit _ai;

  /// The todo list as of the last `todo_write` (or the session transcript's
  /// last one, after a restore). Empty until the model writes its first list.
  List<TodoItem> todos = const [];

  /// The current plan text as of the last `plan` call, or the transcript's.
  String? plan;

  /// Defines and registers both tools. Call exactly once per [Genkit] instance.
  List<Tool> define() => [_todoWrite(), _plan()];

  /// Drops the state, for a new conversation.
  void reset() {
    todos = const [];
    plan = null;
  }

  /// Replays the last `todo_write` / `plan` output from a persisted transcript.
  ///
  /// A tool response says nothing about which tool produced it, so the requests
  /// are indexed by ref first and the responses matched against that — the same
  /// pairing `_projectMessages` in `agent_runtime.dart` performs to attach
  /// results to call cards.
  void restoreFrom(List<Message> messages) {
    final toolNamesByRef = <String, String>{};
    for (final message in messages) {
      if (message.role.value != 'model') continue;
      for (final part in message.content) {
        if (!part.isToolRequest) continue;
        final request = part.toolRequest!;
        final ref = request.ref;
        if (ref != null) toolNamesByRef[ref] = request.name;
      }
    }

    for (final message in messages) {
      if (message.role.value != 'tool') continue;
      for (final part in message.content) {
        if (!part.isToolResponse) continue;
        final response = part.toolResponse!;
        final name = toolNamesByRef[response.ref];
        final output = response.output;
        if (output is! Map) continue;
        if (name == 'todo_write') {
          final raw = output['todos'];
          todos = [
            for (final row in (raw is List ? raw : const []))
              ?TodoItem.fromJson(row),
          ];
        } else if (name == 'plan') {
          final text = output['plan'];
          plan = text is String ? text : null;
        }
      }
    }
  }

  Tool _todoWrite() =>
      _ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
        name: 'todo_write',
        description:
            'Create or replace the task list for the current work. Use it to '
            'plan multi-step work, to show progress, and to stay oriented '
            'while the work is underway. Submit the WHOLE list each time — '
            'one line per task, each kept short. The list is shown to the '
            'user as live progress, so mark a task in_progress before '
            'starting it and completed the moment it is done.',
        inputSchema: SchemanticType.from<Map<String, dynamic>>(
          jsonSchema: {
            'type': 'object',
            'properties': {
              'todos': {
                'type': 'array',
                'description': 'The complete task list.',
                'items': {
                  'type': 'object',
                  'properties': {
                    'content': {
                      'type': 'string',
                      'description': 'One short line of work.',
                    },
                    'status': {
                      'type': 'string',
                      'enum': ['pending', 'in_progress', 'completed'],
                      'description':
                          'pending has not been started; in_progress is '
                          'underway; completed is done.',
                    },
                  },
                  'required': ['content', 'status'],
                },
              },
            },
            'required': ['todos'],
          },
          parse: (json) => (json as Map).cast<String, dynamic>(),
        ),
        fn: (input, _) async {
          final raw = input['todos'];
          final rows = [
            for (final row in (raw is List ? raw : const []))
              ?TodoItem.fromJson(row),
          ];
          // The state the UI reads between turns; the copy in the tool output
          // is the one a restore replays, and they are the same list.
          todos = rows;
          return ToolResult.response({
            'ok': true,
            'todos': [for (final row in rows) row.toJson()],
          });
        },
      );

  Tool _plan() => _ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'plan',
    description:
        'Record the plan of record for the current task: the approach and the '
        'steps, in order, that you intend to take. Update it whenever the '
        'approach changes. The user sees the current plan with the '
    'conversation.',
    inputSchema: SchemanticType.from<Map<String, dynamic>>(
      jsonSchema: {
        'type': 'object',
        'properties': {
          'plan': {
            'type': 'string',
            'description': 'The plan, as brief ordered steps.',
          },
        },
        'required': ['plan'],
      },
      parse: (json) => (json as Map).cast<String, dynamic>(),
    ),
    fn: (input, _) async {
      final text = input['plan'];
      plan = text is String ? text : null;
      return ToolResult.response({'ok': true, if (plan != null) 'plan': plan});
    },
  );
}
