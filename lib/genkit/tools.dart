// The tool set: read, write, edit, glob, grep, bash.
//
// One of only two files allowed to import `package:genkit` (see
// `agent_runtime.dart`). Everything the tools hand back is plain JSON, so the
// transcript can render it without knowing anything about Genkit.
//
// Names, parameter names and descriptions are dsh's, taken from `tool-fs`,
// `tool-fs-search` and `tool-bash` rather than invented: the model has opinions
// about tools called `read` and `bash` that it does not have about `readFile`,
// and a schema that matches the one it was trained against is the cheapest
// accuracy there is. What each tool actually does lives in a sibling file —
// `read_window.dart`, `file_search.dart`, `shell_run.dart`, `text_edit.dart` —
// none of which imports Genkit, so the behaviour is unit-testable and this file
// stays what it should be: schemas, the workspace guard, and the approval gate.
//
// dsh has no directory-listing tool and this build no longer has one either:
// `glob` is the discovery tool, and its own description says it "does not
// enumerate directory entries" — the model reaches for `**/*` under a directory
// instead, which answers the same question and costs one call.

import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import '../model/approval_mode.dart';
import '../model/workspace.dart';
import '../state/fs_revision.dart';
import 'file_search.dart';
import 'read_window.dart';
import 'shell_run.dart';
import 'text_edit.dart';

/// Builds a runtime object schema.
///
/// Note this is `SchemanticType.from`, not a `jsonSchema(...)` constructor — the
/// latter does not exist. Tool inputs stay as maps rather than generated classes,
/// which keeps `build_runner` out of the project.
SchemanticType<Map<String, dynamic>> _objectSchema(
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

/// Registers the tool set against [ai] and keeps it pointed at whichever folder
/// the user has open.
///
/// Registration happens once, in [define]; the tools read [workspace] at call
/// time, so opening a different folder does not mean re-registering anything.
class WorkspaceTools {
  WorkspaceTools(this._ai, {ApprovalModeHolder? approval})
    : _approval = approval ?? ApprovalModeHolder();

  final Genkit _ai;

  /// How gated calls decide, read at call time so switching is live.
  final ApprovalModeHolder _approval;

  /// Null until the user opens a folder — in which case every tool refuses,
  /// telling the model why.
  Workspace? workspace;

  /// The one line every gated tool runs before it does anything. Returns the
  /// refusal when the mode says no, null when the call may proceed.
  ///
  /// `ask` interrupts — the interruption surfaces as the approval panel.
  /// `plan` refuses outright: plan mode is read-only, and a refusal the model
  /// can read is a firmer boundary than a prompt it has to wait on.
  /// `auto` skips the gate entirely.
  Map<String, dynamic>? gateRefusal() {
    if (_approval.value == ApprovalMode.plan) {
      return {
        'ok': false,
        'error':
            'Plan mode is on: the workspace is read-only until the user '
            'approves the plan. Read, search and plan are available; make no '
            'changes.',
      };
    }
    return null;
  }

  /// Whether the approval interrupt should fire for this call.
  bool get shouldInterrupt => _approval.value == ApprovalMode.ask;

  Workspace get _workspace {
    final ws = workspace;
    if (ws == null) {
      throw WorkspaceDenied(
        'No workspace folder is open. Ask the user to open one before using '
        'tools.',
      );
    }
    return ws;
  }

  /// Defines and registers every tool. Call exactly once per [Genkit] instance.
  List<Tool> define() => [
    _read(),
    _write(),
    _edit(),
    _glob(),
    _grep(),
    _bash(),
  ];

  // ---------------------------------------------------------------------------
  // Filesystem
  // ---------------------------------------------------------------------------

  Tool _read() => _ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'read',
    description: 'Read a UTF-8 text file and return line-numbered content.',
    inputSchema: _objectSchema(
      {
        'file_path': {
          'type': 'string',
          'description':
              'Path to read. Relative paths resolve against the workspace root.',
        },
        'offset': {
          'type': 'number',
          'description': '1-based first line to return. Defaults to 1.',
        },
        'limit': {
          'type': 'number',
          'description':
              'Maximum number of lines to return. Defaults to $readLimit.',
        },
      },
      required: ['file_path'],
    ),
    fn: (input, context) async =>
        ToolResult.response(await _guard(() async {
      final ws = _workspace;
      final path = ws.resolve(_string(input, 'file_path'));
      if (Directory(path).existsSync()) {
        throw WorkspaceDenied(
          'That is a directory, not a file. Use glob with a pattern under it to '
          'see what it holds.',
        );
      }
      final file = File(path);
      if (!file.existsSync()) {
        throw WorkspaceDenied('No such file: ${ws.relative(path)}');
      }
      final requested = _int(input['limit']) ?? readLimit;
      final outcome = await readWindowOf(
        decodeLines(file.openRead()),
        offset: _int(input['offset'])?.clamp(1, 1 << 40) ?? 1,
        // The model may ask for more than the cap; the cap wins silently and the
        // footer says where the window stopped, which is the same signal it gets
        // from any other short window.
        limit: requested < 1 ? readLimit : (requested.clamp(1, readLimit)),
      );
      return {
        'path': ws.relative(path),
        'startLine': outcome.offset,
        'endLine': outcome.endLine,
        'totalLines': outcome.totalLines,
        'content': numberedLines(outcome),
        // dsh's footer, in its own field rather than glued to the content: the
        // card that renders this later shows the file, not the note about it.
        'note': readFooter(outcome),
      };
    })),
  );

  /// Approval-gated, like [_edit] and [_bash].
  ///
  /// First entry interrupts, which pauses the whole loop and surfaces to the UI.
  /// Once the user decides, the runtime restarts this same call with the verdict
  /// in `context.resumed`.
  Tool _write() => _ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'write',
    description:
        'Create or fully replace a UTF-8 text file. Requires the user to '
        'approve.',
    inputSchema: _objectSchema(
      {
        'file_path': {
          'type': 'string',
          'description':
              'Path to write. Relative paths resolve against the workspace '
              'root; parent directories are created as needed.',
        },
        'content': {
          'type': 'string',
          'description': 'Full UTF-8 text content to write.',
        },
      },
      required: ['file_path', 'content'],
    ),
    fn: (input, context) async {
      final content = input['content'] as String? ?? '';

      // Resolved before asking: a path that would be refused anyway should not
      // cost the user an approval prompt.
      final String path;
      final Workspace ws;
      try {
        ws = _workspace;
        path = ws.resolve(_string(input, 'file_path'));
      } on WorkspaceDenied catch (e) {
        return ToolResult.response({'ok': false, 'error': e.message});
      }

      if (context.resumed == null) {
        final refusal = gateRefusal();
        if (refusal != null) return ToolResult.response(refusal);
        if (shouldInterrupt) {
          return ToolResult.interrupt({
            'kind': 'write',
            'path': ws.relative(path),
            'bytes': utf8.encode(content).length,
            'exists': File(path).existsSync(),
          });
        }
      }
      if (_declined(context.resumed)) {
        return ToolResult.response({
          'ok': false,
          'error': 'The user declined this write.',
        });
      }

      return ToolResult.response(
        await _guard(() async {
        final file = File(path);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(content);
        // The tree's revision: an agent write is the one change the panels
        // cannot see on their own, so it is the one that announces itself.
        bumpFsRevision();
        return {
          'ok': true,
          'path': ws.relative(path),
          'bytes': utf8.encode(content).length,
        };
      }));
    },
  );

  Tool _edit() => _ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'edit',
    description:
        'Edit an existing UTF-8 text file by replacing literal text. Requires '
        'the user to approve.',
    inputSchema: _objectSchema(
      {
        'file_path': {
          'type': 'string',
          'description':
              'Path to edit. Relative paths resolve against the workspace root.',
        },
        'old_string': {
          'type': 'string',
          'description': 'Literal text to replace. Must match exactly.',
        },
        'new_string': {
          'type': 'string',
          'description':
              'Literal replacement text. Use an empty string to delete the '
              'match.',
        },
        'replace_all': {
          'type': 'boolean',
          'description':
              'Replace all matches. Defaults to false; when false, old_string '
              'must appear exactly once.',
        },
      },
      required: ['file_path', 'old_string', 'new_string'],
    ),
    fn: (input, context) async {
      final oldString = input['old_string'] as String? ?? '';
      final newString = input['new_string'] as String? ?? '';
      final replaceAll = input['replace_all'] == true;

      final String path;
      final Workspace ws;
      final String before;
      try {
        ws = _workspace;
        path = ws.resolve(_string(input, 'file_path'));
        final file = File(path);
        if (!file.existsSync()) {
          return ToolResult.response({
            'ok': false,
            'error':
                'No such file: ${ws.relative(path)}. Use write to create it.',
          });
        }
        before = file.readAsStringSync();
      } on WorkspaceDenied catch (e) {
        return ToolResult.response({'ok': false, 'error': e.message});
      } on FileSystemException catch (e) {
        return ToolResult.response({'ok': false, 'error': _fsMessage(e)});
      }

      // Validated before asking, for the same reason as `write`, and with one
      // more: the occurrence count is what the approval prompt shows, so it has
      // to be known before the prompt exists.
      final EditOutcome edited;
      try {
        edited = applyLiteralEdit(
          source: before,
          oldString: oldString,
          newString: newString,
          replaceAll: replaceAll,
        );
      } on EditRejected catch (e) {
        return ToolResult.response({'ok': false, 'error': e.message});
      }

      if (context.resumed == null) {
        final refusal = gateRefusal();
        if (refusal != null) return ToolResult.response(refusal);
        if (shouldInterrupt) {
          return ToolResult.interrupt({
            'kind': 'edit',
            'path': ws.relative(path),
            'replacements': edited.replacements,
            'bytes': utf8.encode(edited.content).length,
          });
        }
      }
      if (_declined(context.resumed)) {
        return ToolResult.response({
          'ok': false,
          'error': 'The user declined this edit.',
        });
      }

      return ToolResult.response(
        await _guard(() async {
        final file = File(path);
        // Re-read after the pause: the user may have edited the file themselves
        // while the prompt was up, and writing the content computed before that
        // would silently revert them.
        final current = file.readAsStringSync();
        final outcome = current == before
            ? edited
            : applyLiteralEdit(
                source: current,
                oldString: oldString,
                newString: newString,
                replaceAll: replaceAll,
              );
        file.writeAsStringSync(outcome.content);
        // Same announcement as a write: an edit changed the disk, and the
        // tree that shows it should not wait for the user to notice.
        bumpFsRevision();
        return {
          'ok': true,
          'path': ws.relative(path),
          'replacements': outcome.replacements,
        };
      }));
    },
  );

  // ---------------------------------------------------------------------------
  // Discovery
  // ---------------------------------------------------------------------------

  Tool _glob() => _ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'glob',
    description:
        'Find files whose paths match a glob pattern. Returns matching file '
        'paths — never directories — including hidden files (VCS metadata '
        'directories are excluded). Up to $globMaxResults paths come back in '
        'modification-time order; a larger result returns the newest '
        '$globMaxResults and says how many matched. This tool does not '
        'enumerate directory entries.',
    inputSchema: _objectSchema(
      {
        'pattern': {
          'type': 'string',
          'description':
              'Glob pattern to match file paths against (e.g. "**/*.dart", '
              '"lib/**/*_test.dart"). A pattern with no "/" matches the '
              'basename at any depth, so "*" and "*.dart" both search the whole '
              'tree; include a separator to anchor the depth.',
        },
        'path': {
          'type': 'string',
          'description':
              'Directory to search in. Defaults to the workspace root; a '
              'relative path resolves against it.',
        },
      },
      required: ['pattern'],
    ),
    fn: (input, context) async =>
        ToolResult.response(await _guard(() async {
      final ws = _workspace;
      final root = Directory(ws.resolve(_pathArg(input) ?? '.'));
      if (!root.existsSync()) {
        throw WorkspaceDenied('No such directory: ${_pathArg(input) ?? '.'}');
      }
      final outcome = await globFiles(
        root: root,
        pattern: _string(input, 'pattern'),
      );
      return {
        'path': ws.relative(root.path),
        'pattern': input['pattern'],
        'paths': outcome.hits.map((hit) => hit.path).toList(),
        'total': outcome.total,
        if (outcome.capped)
          'note':
              'Showing the newest ${outcome.hits.length} of ${outcome.total} '
              'matches. Narrow the pattern to see the rest.',
        if (outcome.timedOut) 'timedOut': true,
      };
    })),
  );

  Tool _grep() => _ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'grep',
    description:
        'Search file contents with a regular expression. Returns matching lines '
        'with line numbers, grouped by file. Returns the first '
        '$grepMaxMatches matches; a capped result says how many matched. Use '
        'read on a matched file for surrounding context.',
    inputSchema: _objectSchema(
      {
        'pattern': {
          'type': 'string',
          'description': 'Regular expression to search for.',
        },
        'path': {
          'type': 'string',
          'description':
              'File or directory to search. Defaults to the workspace root; a '
              'relative path resolves against it.',
        },
        'include': {
          'type': 'string',
          'description':
              'One glob filter for which files to search (e.g. "*.dart", '
              '"*.{js,jsx}"). Not a list; negation is not supported.',
        },
      },
      required: ['pattern'],
    ),
    fn: (input, context) async =>
        ToolResult.response(await _guard(() async {
      final ws = _workspace;
      final raw = _pathArg(input) ?? '.';
      final resolved = ws.resolve(raw);
      final FileSystemEntity target = Directory(resolved).existsSync()
          ? Directory(resolved)
          : File(resolved);
      if (!target.existsSync()) {
        throw WorkspaceDenied('No such file or directory: $raw');
      }

      final RegExp pattern;
      try {
        pattern = RegExp(_string(input, 'pattern'));
      } on FormatException catch (e) {
        // The model's own mistake, and one it can fix: hand back the parse
        // failure rather than a generic refusal.
        throw WorkspaceDenied('Invalid regular expression: ${e.message}');
      }

      final outcome = await grepFiles(
        target: target,
        pattern: pattern,
        include: input['include'] as String?,
      );
      return {
        'path': ws.relative(resolved),
        'pattern': input['pattern'],
        // Grouped by file, in dsh's shape: one entry per file, its matches in
        // line order. Flat matches would repeat the path on every line, which on
        // a 250-match page is most of the payload.
        'matches': _group(outcome.hits),
        'total': outcome.total,
        'files': outcome.files,
        if (outcome.capped)
          'note':
              'Showing the first ${outcome.hits.length} of ${outcome.total} '
              'matches. Narrow the pattern or pass include to see the rest.',
        if (outcome.timedOut) 'timedOut': true,
      };
    })),
  );

  /// Matches to `[{path, lines: [{line, text}]}]`, preserving discovery order.
  static List<Map<String, Object?>> _group(List<GrepHit> hits) {
    final byPath = <String, List<Map<String, Object?>>>{};
    for (final hit in hits) {
      (byPath[hit.path] ??= []).add({'line': hit.line, 'text': hit.text});
    }
    return byPath.entries
        .map((entry) => {'path': entry.key, 'lines': entry.value})
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Shell
  // ---------------------------------------------------------------------------

  /// The third approval-gated tool, and the one where the gate is the whole
  /// safety story.
  ///
  /// dsh does not prompt per command: it runs the shell under a file sandbox and
  /// prompts only when the model asks to widen it. There is no sandbox here, so
  /// the choice is between prompting for every command and running arbitrary
  /// shell in the user's workspace unannounced. It prompts.
  Tool _bash() => _ai.defineTool<Map<String, dynamic>, Map<String, dynamic>>(
    name: 'bash',
    description:
        'Execute a bash command (`bash -c`) and return its stdout/stderr. Each '
        'call runs in a fresh shell: no state (cwd, variables, functions) '
        'persists between calls — pass workdir instead of using cd. Non-zero '
        'exits are reported as `[exit code: N]`. Long output is truncated to its '
        'tail. Every command requires the user to approve, so prefer one '
        'purposeful command over a chain of exploratory ones.',
    inputSchema: _objectSchema(
      {
        'command': {
          'type': 'string',
          'description': 'The bash command to execute.',
        },
        'description': {
          'type': 'string',
          'description':
              'Clear, concise description of what this command does in active '
              'voice, 5-10 words (shown in the UI). Examples: "ls" → "List '
              'files in current directory"; "git status" → "Show working tree '
              'status".',
        },
        'workdir': {
          'type': 'string',
          'description':
              'Working directory for this command. Defaults to the workspace '
              'root; a relative path resolves against it.',
        },
        'timeoutMs': {
          'type': 'number',
          'description':
              'Timeout in milliseconds, capped at '
              '${bashTimeout.inMilliseconds}. The command is killed on expiry.',
        },
      },
      required: ['command', 'description'],
    ),
    fn: (input, context) async {
      final command = input['command'] as String? ?? '';
      if (command.trim().isEmpty) {
        return ToolResult.response({'ok': false, 'error': 'command is empty.'});
      }

      final String workdir;
      final Workspace ws;
      try {
        ws = _workspace;
        workdir = ws.resolve(input['workdir'] as String? ?? '.');
        if (!Directory(workdir).existsSync()) {
          return ToolResult.response({
            'ok': false,
            'error': 'No such directory: ${input['workdir']}',
          });
        }
      } on WorkspaceDenied catch (e) {
        return ToolResult.response({'ok': false, 'error': e.message});
      }

      if (context.resumed == null) {
        final refusal = gateRefusal();
        if (refusal != null) return ToolResult.response(refusal);
        if (shouldInterrupt) {
          return ToolResult.interrupt({
            'kind': 'bash',
            'command': command,
            'description': input['description'],
            'workdir': ws.relative(workdir),
          });
        }
      }
      if (_declined(context.resumed)) {
        return ToolResult.response({
          'ok': false,
          'error': 'The user declined this command.',
        });
      }

      final requested = _int(input['timeoutMs']);
      try {
        final run = await runBash(
          command: command,
          workdir: workdir,
          timeout: requested == null || requested < 1
              ? bashTimeout
              : Duration(
                  milliseconds: requested.clamp(1, bashTimeout.inMilliseconds),
                ),
        );
        // A non-zero exit is a result, not a failure — dsh's rule, and the
        // reason it matters is that the model has to be able to read a failing
        // command's output to fix it. `ok: false` would hide that behind an
        // error line.
        return ToolResult.response({
          'output': renderShellRun(run),
          'exitCode': run.exitCode,
          'workdir': ws.relative(workdir),
          if (run.signal != null) 'signal': run.signal,
          if (run.timedOut) 'timedOut': true,
        });
      } on ProcessException catch (e) {
        // The shell itself could not start. That is infrastructure, not the
        // command's outcome, so it is a failure.
        return ToolResult.response({
          'ok': false,
          'error': 'Could not run bash: ${e.message}',
        });
      }
    },
  );

  // ---------------------------------------------------------------------------
  // Shared
  // ---------------------------------------------------------------------------

  /// Whether a resumed call was answered with a refusal.
  ///
  /// Anything that is not an explicit approval counts as one: a malformed resume
  /// payload must not be read as consent.
  static bool _declined(Object? resumed) =>
      resumed is! Map || resumed['approved'] != true;

  /// Turns a thrown failure into a tool result the model can read.
  ///
  /// Letting it propagate would abort the turn; returning it lets the model try
  /// a different path, which is almost always what the user wanted.
  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() body,
  ) async {
    try {
      return await body();
    } on WorkspaceDenied catch (e) {
      return {'ok': false, 'error': e.message};
    } on EditRejected catch (e) {
      return {'ok': false, 'error': e.message};
    } on FileSystemException catch (e) {
      return {'ok': false, 'error': _fsMessage(e)};
    }
  }

  static String _fsMessage(FileSystemException e) =>
      '${e.message}${e.osError == null ? '' : ' (${e.osError!.message})'}';

  /// A required string argument.
  ///
  /// Missing or wrong-typed is a schema violation the provider should have
  /// caught; refusing here rather than crashing keeps a malformed tool call from
  /// killing the turn.
  static String _string(Map<String, dynamic> input, String key) {
    final value = input[key];
    if (value is! String || value.isEmpty) {
      throw WorkspaceDenied('$key is required and must be a non-empty string.');
    }
    return value;
  }

  /// The optional `path` argument, absent and empty treated alike — a model that
  /// sends `""` meant "the default", not "the empty path".
  static String? _pathArg(Map<String, dynamic> input) {
    final value = input['path'];
    return value is String && value.isNotEmpty ? value : null;
  }

  /// Numbers arrive as numbers usually and as strings sometimes, depending on how
  /// the provider serialised the call.
  static int? _int(Object? value) => switch (value) {
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };
}
