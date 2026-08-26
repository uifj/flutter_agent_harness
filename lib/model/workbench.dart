// What the agent side may ask the workbench for.
//
// This file exists to keep `package:genkit` and `lib/sidebar/` apart. The
// `sidebar_open` tool has to reach the open workbench, and the workbench has to
// be reachable without anything in `lib/sidebar/` importing genkit or anything in
// `lib/genkit/` importing a widget — so both sides speak this instead. It is the
// same shape as the rest of `lib/model/`: plain data, no Flutter, no IO.
//
// better-sidebar solves the same problem with `AgentOpenRegistry` (`agent-opens.ts`):
// a per-session queue the tool appends to and the client drains over a websocket,
// because the tool runs in the host process and the view lives in a webview that
// may not be connected yet. Here the tool and the controller are objects in one
// isolate, so the queue would model a state — "no view attached" — that cannot
// happen: the controller outlives every widget that reads it.

/// What kind of thing `sidebar_open` was pointed at.
enum OpenKind {
  /// A file, shown in an editor tab.
  file,

  /// A directory, shown as a file tree root.
  folder,

  /// An http(s) address. Accepted by the tool so the refusal can say something
  /// useful; see [WorkbenchSink.open].
  url,
}

/// One `sidebar_open` request.
class OpenTarget {
  const OpenTarget({required this.kind, required this.target, this.line});

  final OpenKind kind;

  /// An absolute path already cleared by the workspace guard, or a URL.
  ///
  /// The guard runs in the tool, not here: refusing a path is a security
  /// decision and belongs next to the thing that knows the workspace root.
  final String target;

  /// 1-based line to scroll an editor tab to, if the caller named one.
  final int? line;

  @override
  String toString() => 'OpenTarget(${kind.name}, $target, line: $line)';
}

/// The workbench, as the agent side sees it.
///
/// An interface rather than the controller itself so a tool test can assert what
/// was asked for without building a workbench, and so the tool file has no path
/// to the widget layer.
abstract interface class WorkbenchSink {
  /// Opens [target], returning null on success or the reason it was refused.
  ///
  /// A returned string rather than a thrown exception, because the caller is a
  /// tool and `agent_runtime._toolResult` expects `{ok: false, error}` for
  /// anything recoverable — a refusal the model should read and act on, not a
  /// crash.
  String? open(OpenTarget target);

  /// Expands the file tree down to each of [paths] so they are visible.
  ///
  /// Separate from [open] because it is not an open: after a write tool touches
  /// three files, showing them means revealing them, not stacking three editors.
  void reveal(Iterable<String> paths);
}
