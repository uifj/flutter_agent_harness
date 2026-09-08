// The one place Genkit lives (with `tools.dart`).
//
// Everything above this file — state, UI — speaks only `lib/model/`. That is
// deliberate: these are 0.x packages, so a breaking change should land in two
// files, not across the widget tree. A grep for `package:genkit` outside
// `lib/genkit/` should come up empty.
//
// The projection below is written against the findings recorded in
// `spike/agent_spike.dart`; re-run that spike after any genkit version bump.

import 'dart:async';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit/io.dart';
import 'package:genkit/plugin.dart' show GenkitPlugin;
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_mcp/genkit_mcp.dart' as mcp;
import 'package:genkit_middleware/genkit_middleware.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:path/path.dart' as p;

import '../model/app_settings.dart';
import '../model/approval_mode.dart';
import '../model/attached_image.dart';
import '../model/conversation.dart';
import '../model/mention_expansion.dart';
import '../model/model_settings.dart';
import '../model/todo_state.dart';
import '../model/turn_event.dart';
import '../model/turn_source.dart';
import '../model/workspace.dart';
import 'plan_tools.dart';
import 'tools.dart';

/// The system prompt.
///
/// The per-tool paragraphs are dsh's own `ctx.systemPrompt.section` texts —
/// `tool:read` (order 100) through `tool:bash` (105) — quoted rather than
/// paraphrased. dsh assembles them from each tool plugin so a deployment without
/// a tool never describes it; there is one fixed tool set here, so they are
/// inlined in the source's own order.
const _systemPrompt = '''
You are a focused coding and research assistant running on the user's Mac.

- Prefer using the tools over guessing about the workspace. Paths are relative to
  the workspace root.
- Use the read tool — not shell commands like cat — to inspect text files.
  Results include line numbers. Use offset and limit to continue reading large
  files.
- Use the write tool to create files or completely replace file contents.
  Existing files are overwritten, so read an existing file first and prefer edit
  for targeted changes.
- Use the edit tool for targeted changes to existing UTF-8 text files. It
  replaces literal old_string with new_string; by default old_string must appear
  exactly once. If old_string appears multiple times, provide a more specific
  old_string or set replace_all to true. Read the file first, unless you just
  created or edited it in this session.
- Use glob to find files by path and grep to find them by content, rather than
  shelling out to find or grep.
- Check the [exit code: N] marker on every bash result; investigate failures
  before moving on.
- write, edit and bash each need the user's approval, so batch your changes and
  explain what a call will do before you request it.
- Answer in the language the user writes in. Use Markdown, and fenced code
  blocks with a language tag for code.
- Be concise. Skip preamble and restating the question.
- Use todo_write to plan multi-step work: write the whole task list up front,
  one short line per task; mark a task in_progress before starting it and
  completed the moment it is done. The user sees the list as live progress.
- Use plan to record the plan of record — the approach and the ordered steps
  you intend to take — and update it whenever the approach changes.
''';

/// The extra paragraph the system prompt gains when MCP servers are
/// configured. The skills and sub-agent sections, by contrast, are written by
/// their own middlewares (`<skills>` from genkit_middleware, `<sub-agents>`
/// from the agents middleware), so they are not duplicated here.
const _mcpPrompt = '''
- Tools from external MCP servers are named <server>/<tool>. Treat them like
  any other tool; their schemas travel with them. If one fails or is missing,
  report that rather than guessing at its behaviour.
''';

/// The delegation target's prompt. Short on purpose: the task text it is
/// handed is the brief, and only its final message comes back.
const _subagentPrompt = '''
You are a research sub-agent invoked by the main assistant. The task you are
given is self-contained; answer it using the read, glob and grep tools over
the workspace. You cannot write files or run commands, so report findings
instead — with file paths and line numbers where they matter. Be concise:
only your final message is returned to the caller.
''';

/// The side chat's prompt: the thread pinned in the workbench's Side Chat tab.
///
/// No tools and no store — a side question is a one-shot aside, not a session,
/// and it must never touch the workspace or the main thread's transcript.
const _sidePrompt = '''
You are the side assistant pinned in a workbench panel. The user asks quick
asides here while a main conversation runs elsewhere. You have no tools: answer
from the question and general knowledge, and say so plainly when the answer
needs files or commands the main thread can run instead. Be brief.
''';

/// Registry name of the MCP host, and of the delegation target.
const _mcpHostName = 'mcp';
const _subagentName = 'general-purpose';
const _sideName = 'dsh-side';

/// The workspace tools the sub-agent is allowed: everything read-only. A
/// sub-agent's approval interrupt cannot reach the UI — the delegation
/// middleware resolves it as text — so it must not be able to reach a gated
/// tool (write, edit, bash) in the first place.
const _subagentTools = {'read', 'glob', 'grep'};

/// How many times the tool loop may go round before the runtime gives up. High
/// enough for real multi-step work, low enough to bound a runaway loop's cost.
const _maxTurns = 24;

/// The delegation target's own loop bound, and how many delegations one turn
/// of the parent may make. Both bound the same runaway-delegation cost.
const _maxSubagentTurns = 12;
const _maxDelegations = 4;

/// Snapshots older than this in a chain are pruned on save, so a long-running
/// conversation does not grow the store without bound.
const _maxPersistedChainLength = 200;

const _stopGateName = 'dshStopGate';

/// Shared mutable stop bit.
///
/// A holder rather than a plain `bool` because the middleware is built by the
/// plugin during `Genkit`'s constructor — before the runtime object it belongs to
/// exists — so the two have to meet on something allocated first.
class _StopFlag {
  bool value = false;
}

/// Cuts the tool loop at its next boundary once the user has pressed stop.
///
/// The spike established that Genkit 0.15.1's `CancellationToken` interrupts
/// nothing: the token is consulted before a turn starts and in catch blocks, but
/// the model function never sees it, so an in-flight provider request runs to
/// completion. Without this gate, stopping a turn mid tool-loop would still let
/// the remaining turns run — and bill. The request already in flight still
/// finishes; that part is not fixable from here.
class _StopGate extends GenerateMiddleware {
  _StopGate(this._stop);

  final _StopFlag _stop;

  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    )
    next,
  ) {
    _throwIfStopped();
    return next(request, ctx);
  }

  @override
  Future<ToolResponsePart> tool(
    ToolRequestPart request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResponsePart> Function(
      ToolRequestPart request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) {
    _throwIfStopped();
    return next(request, ctx);
  }

  void _throwIfStopped() {
    if (_stop.value) {
      throw GenkitException(
        'Stopped by the user.',
        status: StatusCodes.ABORTED,
      );
    }
  }
}

/// Middleware can only reach the registry through a plugin, so the gate travels
/// as one.
class _StopGatePlugin extends GenkitPlugin {
  _StopGatePlugin(this._stop);

  final _StopFlag _stop;

  @override
  String get name => _stopGateName;

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<Map<String, dynamic>>(
      name: _stopGateName,
      create: (config, ctx) => _StopGate(_stop),
    ),
  ];
}

const _usageName = 'dshUsageCapture';

/// Per-turn accumulator for the providers' usage blocks.
///
/// The spike's fake models and the real plugins report usage on the
/// `ModelResponse` the model call resolves with — genkit 0.16 fills it for
/// streaming and non-streaming alike — but nothing above the model seam
/// carries it, so the capture middleware adds each call's block into this
/// ledger and the turn's `TurnFinished` reports the sums. The per-field seen
/// bits keep a provider that reports no `thoughtsTokens` from turning its
/// absence into a displayed zero.
class _UsageLedger {
  int inputTokens = 0;
  int outputTokens = 0;
  int thoughtsTokens = 0;
  int totalTokens = 0;
  int modelCalls = 0;
  bool seen = false;
  bool sawInput = false;
  bool sawOutput = false;
  bool sawThoughts = false;
  bool sawTotal = false;

  void reset() {
    inputTokens = outputTokens = thoughtsTokens = totalTokens = 0;
    modelCalls = 0;
    seen = sawInput = sawOutput = sawThoughts = sawTotal = false;
  }

  void add(GenerationUsage? usage) {
    if (usage == null) return;
    seen = true;
    modelCalls++;
    final input = usage.inputTokens;
    if (input != null) {
      sawInput = true;
      inputTokens += input.round();
    }
    final output = usage.outputTokens;
    if (output != null) {
      sawOutput = true;
      outputTokens += output.round();
    }
    final thoughts = usage.thoughtsTokens;
    if (thoughts != null) {
      sawThoughts = true;
      thoughtsTokens += thoughts.round();
    }
    final total = usage.totalTokens;
    if (total != null) {
      sawTotal = true;
      totalTokens += total.round();
    }
  }
}

/// Reads the usage block off every settled model call. Runs after the stop
/// gate in the `use` list, so a call the gate throws away costs no figures.
class _UsageCapture extends GenerateMiddleware {
  _UsageCapture(this._ledger);

  final _UsageLedger _ledger;

  @override
  Future<ModelResponse> model(
    ModelRequest request,
    ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    Future<ModelResponse> Function(
      ModelRequest request,
      ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
    )
    next,
  ) async {
    final response = await next(request, ctx);
    _ledger.add(response.usage);
    return response;
  }
}

/// The ledger is allocated before the `Genkit` instance (same reason as the
/// stop flag) and travels as a plugin because middleware can only reach the
/// registry through one.
class _UsagePlugin extends GenkitPlugin {
  _UsagePlugin(this._ledger);

  final _UsageLedger _ledger;

  @override
  String get name => _usageName;

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<Map<String, dynamic>>(
      name: _usageName,
      create: (config, ctx) => _UsageCapture(_ledger),
    ),
  ];
}

const _toolGateName = 'dshToolGate';

/// What one tool call did, as the gate saw it — the audit trail dsh writes to
/// its session log; here a bounded in-memory ring until that log exists.
class ToolAuditRecord {
  ToolAuditRecord({
    required this.name,
    required this.startedAt,
    required this.durationMs,
    required this.outcome,
  });

  final String name;
  final DateTime startedAt;
  final int durationMs;
  final ToolAuditOutcome outcome;
}

enum ToolAuditOutcome { refused, interrupted, ok, failed }

/// How far the audit ring keeps, in entries — enough for a session's worth of
/// scrollback without growing without bound.
const _toolAuditCapacity = 200;

/// The single point every tool call passes through, dsh's tool pipeline
/// collapsed to what this app needs it for.
///
/// The local tools carry their own workspace guard and approval gate inside
/// their functions (see `tools.dart`), so for them the gate is observation
/// only: timing and an audit entry. The MCP wildcard's tools have no such
/// discipline — their schemas travel with the server — so here they meet the
/// same two rules: plan mode refuses outright (a refusal the model can read,
/// the firmer boundary), ask mode interrupts for the user's decision, exactly
/// like a local write. A resumed call consults only its verdict: once the
/// user has decided, the gate stays open for that call.
class _ToolGate extends GenerateMiddleware {
  _ToolGate(this._approval, this._audit);

  final ApprovalModeHolder _approval;
  final List<ToolAuditRecord> _audit;

  @override
  Future<ToolResponsePart> tool(
    ToolRequestPart request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResponsePart> Function(
      ToolRequestPart request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) async {
    final name = request.toolRequest.name;
    // The MCP host registers its tools as `<server>/<tool>`; every local tool
    // and middleware-contributed tool is a bare name. A slash is the whole
    // test.
    final external = name.contains('/');
    final resumed = request.metadata?['resumed'];
    final approved = resumed is Map && resumed['approved'] == true;

    if (external && !approved) {
      if (_approval.value == ApprovalMode.plan) {
        _record(name, 0, ToolAuditOutcome.refused);
        return _refusal(
          request,
          'Plan mode is on: external tools are disabled until the user approves '
          'the plan.',
        );
      }
      if (_approval.value == ApprovalMode.ask) {
        _record(name, 0, ToolAuditOutcome.interrupted);
        throw ToolInterruptException({
          'kind': 'mcp',
          'server': name.substring(0, name.indexOf('/')),
          'tool': name.substring(name.indexOf('/') + 1),
        });
      }
      // Auto mode: straight through, below.
    }

    return _timed(request, ctx, next);
  }

  Future<ToolResponsePart> _timed(
    ToolRequestPart request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResponsePart> Function(
      ToolRequestPart request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) async {
    final name = request.toolRequest.name;
    final watch = Stopwatch()..start();
    try {
      final part = await next(request, ctx);
      _record(name, watch.elapsedMilliseconds, ToolAuditOutcome.ok);
      return part;
    } catch (e) {
      _record(name, watch.elapsedMilliseconds, ToolAuditOutcome.failed);
      rethrow;
    }
  }

  ToolResponsePart _refusal(ToolRequestPart request, String message) =>
      ToolResponsePart(
        toolResponse: ToolResponse(
          ref: request.toolRequest.ref,
          name: request.toolRequest.name,
          output: {'ok': false, 'error': message},
        ),
      );

  void _record(String name, int durationMs, ToolAuditOutcome outcome) {
    if (_audit.length >= _toolAuditCapacity) {
      _audit.removeAt(0);
    }
    _audit.add(
      ToolAuditRecord(
        name: name,
        startedAt: DateTime.now(),
        durationMs: durationMs,
        outcome: outcome,
      ),
    );
  }
}

class _ToolGatePlugin extends GenkitPlugin {
  _ToolGatePlugin(this._approval, this._audit);

  final ApprovalModeHolder _approval;
  final List<ToolAuditRecord> _audit;

  @override
  String get name => _toolGateName;

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<Map<String, dynamic>>(
      name: _toolGateName,
      create: (config, ctx) => _ToolGate(_approval, _audit),
    ),
  ];
}

/// The side chat's turn source: a thin adapter over the side agent's chat.
///
/// No store — the side thread is one-shot asides, so nothing persists. Each
/// [send] starts a fresh exchange on the same chat, which keeps the aside's
/// own context without ever touching the main thread's transcript.
class SideChatSource implements SideTurnSource {
  SideChatSource(this._agent);

  final Agent<dynamic> _agent;
  AgentChat<dynamic>? _chat;

  /// Sends [text] and yields the answer as text deltas, ending with a
  /// [TurnFinished]. Same single-subscription contract as the main thread.
  @override
  Stream<TurnEvent> send(String text) async* {
    final chat = _chat ??= _agent.chat();
    final turn = chat.sendStream(text: text);
    try {
      await for (final chunk in turn.stream) {
        if (chunk.text.isNotEmpty) {
          yield TextDelta(text: chunk.text, messageIndex: 0);
        }
      }
      await turn.response;
      yield const TurnFinished(outcome: TurnOutcome.completed);
    } catch (e) {
      yield TurnFinished(
        outcome: TurnOutcome.failed,
        errorMessage: '$e',
      );
    }
  }

  /// Stops nothing — one turn, no loop, no cancel token worth threading. The
  /// in-flight request finishes; the UI goes quiet on its own.
  @override
  void reset() => _chat = null;
}

/// The application's whole interface to the agent.
class AgentRuntime implements TurnSource {
  AgentRuntime._({
    required Genkit ai,
    required Agent<dynamic> agent,
    required WorkspaceTools tools,
    required PlanTools planTools,
    required mcp.GenkitMcpHost? host,
    required _StopFlag stop,
    required _UsageLedger usage,
    required List<ToolAuditRecord> toolAudit,
    required ApprovalModeHolder approval,
    required this.side,
    required this.settings,
    required this.sessionRoot,
  }) : _ai = ai,
       _agent = agent,
       _tools = tools,
       _planTools = planTools,
       _host = host,
       _stop = stop,
       _usage = usage,
       _toolAudit = toolAudit,
       _approval = approval;

  /// Builds a runtime for [settings], persisting snapshots under [sessionRoot]
  /// and defaulting the skills directory to `<support>/skills`.
  ///
  /// Everything of consequence is baked in here — the model fields into the
  /// provider plugin and the registered agent, the MCP server set into the
  /// host, the skills directory into the middleware — so editing any of them
  /// means disposing this runtime and constructing another. See
  /// `AppSettings.requiresRuntimeRestart`.
  factory AgentRuntime({
    required AppSettings settings,
    required Directory sessionRoot,
    required Directory support,
  }) {
    final model = settings.model;
    final stop = _StopFlag();
    final approval = ApprovalModeHolder();

    // The provider branch. The OpenAI path declares its model explicitly
    // because capability sniffing by model name does not recognise DeepSeek's
    // names, and without `tools` the agent loop would never send a tool
    // definition; the Anthropic and Google plugins accept any model name and
    // discover the catalog from the API, so they need no such help.
    final GenkitPlugin providerPlugin;
    final ModelRef<dynamic> modelRef;
    switch (model.provider) {
      case LlmProvider.anthropic:
        providerPlugin = anthropic(
          apiKey: model.apiKey,
          baseUrl: model.baseUrl.isEmpty ? null : model.baseUrl,
        );
        modelRef = anthropic.model(model.model);
      case LlmProvider.google:
        providerPlugin = googleAI(apiKey: model.apiKey);
        modelRef = googleAI.gemini(model.model);
      case LlmProvider.openai:
        providerPlugin = openAI(
          apiKey: model.apiKey,
          baseUrl: model.baseUrl,
          models: [
            CustomModelDefinition(
              name: model.model,
              info: ModelInfo(
                label: model.model,
                supports: const {
                  'multiturn': true,
                  'tools': true,
                  'systemRole': true,
                },
              ),
            ),
          ],
        );
        modelRef = openAI.model(model.model);
    }

    // `skills()` and `agents()` are name references resolved through the
    // registry at generate time, so their plugin definitions must be registered
    // up front or the reference would resolve to nothing.
    final usage = _UsageLedger();
    final toolAudit = <ToolAuditRecord>[];
    final ai = Genkit(
      // No `prompts/` directory in this app; skip the lookup entirely.
      promptDir: null,
      plugins: [
        providerPlugin,
        _StopGatePlugin(stop),
        _UsagePlugin(usage),
        _ToolGatePlugin(approval, toolAudit),
        AgentsPlugin(),
        SkillsPlugin(),
      ],
    );

    // The MCP host is only wired when there is something to dial: with no
    // servers it would register a provider that lists nothing, and every
    // request would carry an empty `mcp:tool/*` resolution for no gain.
    // Connections themselves are lazy — the host dials on first use.
    final host = settings.mcpServers.isEmpty
        ? null
        : mcp.defineMcpHost(
            ai,
            mcp.McpHostOptionsWithCache(
              name: _mcpHostName,
              mcpServers: {
                for (final server in settings.mcpServers)
                  server.name: mcp.McpServerConfig(
                    command: server.command,
                    args: server.args,
                    url: server.url == null ? null : Uri.tryParse(server.url!),
                  ),
              },
            ),
          );

    final tools = WorkspaceTools(ai, approval: approval);
    final planTools = PlanTools(ai);
    final workspaceToolList = tools.define();

    // The delegation target, registered so the agents middleware can resolve
    // it by name. Read-only by construction — see [_subagentTools]. No store:
    // a sub-agent conversation is one task, not a session.
    //
    // It shares the parent's stop gate. Without it a delegation would keep
    // running to completion after the user pressed stop — its result then
    // discarded by a loop that is no longer listening — so the sub-agent tab's
    // kill button (which stops the turn) would be a lie. The gate cuts the
    // sub-agent at its next model or tool call; the request already in flight
    // still finishes, as everywhere else.
    ai.defineAgent(
      name: _subagentName,
      description:
          'Answers self-contained research questions about the workspace: '
          'finding code, reading files, summarising how something works. '
          'Cannot modify anything.',
      model: modelRef,
      system: _subagentPrompt,
      tools: [
        for (final tool in workspaceToolList)
          if (_subagentTools.contains(tool.name)) tool,
      ],
      use: [middlewareRef<Map<String, dynamic>>(name: _stopGateName),
        middlewareRef<Map<String, dynamic>>(name: _usageName),
        middlewareRef<Map<String, dynamic>>(name: _toolGateName)],
      maxTurns: _maxSubagentTurns,
    );

    // The side-chat agent: no tools, no store, one turn per ask. Registered
    // like the delegation target so the runtime object can hold a chat on it.
    final sideAgent = ai.defineAgent(
      name: _sideName,
      model: modelRef,
      system: _sidePrompt,
      maxTurns: 1,
    );

    final skillsDir = Directory(
      settings.skillsRoot ?? p.join(support.path, 'skills'),
    );
    final agent = ai.defineAgent(
      name: 'dsh',
      model: modelRef,
      system: host == null ? _systemPrompt : '$_systemPrompt\n$_mcpPrompt',
      tools: [...workspaceToolList, ...planTools.define()],
      // The host's tools are dynamic — their names are only known after it
      // dials — so they cannot be listed; the wildcard resolves them per
      // request instead. `_resolveTools` in genkit treats `<host>:tool/*` as
      // "every tool the host's cache holds".
      toolNames: host == null ? null : ['$_mcpHostName:tool/*'],
      maxTurns: _maxTurns,
      use: [
        middlewareRef<Map<String, dynamic>>(name: _stopGateName),
        middlewareRef<Map<String, dynamic>>(name: _usageName),
        middlewareRef<Map<String, dynamic>>(name: _toolGateName),
        agents(
          agents: const [_subagentName],
          maxDelegations: _maxDelegations,
        ),
        // The skills middleware contributes a `use_skill` tool even when its
        // scan finds nothing, so only attach it when there is something to
        // find. The `<skills>` system prompt section is likewise conditional —
        // the middleware writes it only when the cache is non-empty.
        if (skillsDir.existsSync()) skills(skillPaths: [skillsDir.path]),
      ],
      store: FileSessionStore(
        sessionRoot.path,
        maxPersistedChainLength: _maxPersistedChainLength,
      ),
    );

    return AgentRuntime._(
      ai: ai,
      agent: agent,
      tools: tools,
      planTools: planTools,
      host: host,
      stop: stop,
      usage: usage,
      toolAudit: toolAudit,
      approval: approval,
      side: SideChatSource(sideAgent),
      settings: settings,
      sessionRoot: sessionRoot,
    );
  }

  final Genkit _ai;
  final Agent<dynamic> _agent;
  final WorkspaceTools _tools;
  final PlanTools _planTools;
  final mcp.GenkitMcpHost? _host;
  final _StopFlag _stop;
  final _UsageLedger _usage;
  final List<ToolAuditRecord> _toolAudit;
  final ApprovalModeHolder _approval;

  /// What the tool gate has seen, oldest first, capped at
  /// [_toolAuditCapacity] entries. In memory only for now — the persisted
  /// version is the session-log work this ring is the shape of.
  List<ToolAuditRecord> get toolAudit =>
      List.unmodifiable(_toolAudit);

  /// The side-chat thread's turn source — see [SideChatSource].
  final SideChatSource side;

  final AppSettings settings;
  final Directory sessionRoot;

  AgentChat<dynamic>? _chat;
  AgentTurn<dynamic>? _turn;
  CancellationToken? _cancel;

  /// Which folder the file tools may touch. Null means they all refuse.
  String? get workspaceRoot => _tools.workspace?.root;

  set workspaceRoot(String? path) =>
      _tools.workspace = path == null ? null : Workspace.of(path);

  /// How the gated tools decide, live. Held in a holder the tools read at call
  /// time; this setter is the seam the conversation controller forwards to.
  @override
  set approvalMode(ApprovalMode mode) => _approval.value = mode;

  /// The reference forms of every validated `@path` in [text] — empty when
  /// there is no workspace or nothing validated. See `mention_expansion.dart`;
  /// this is the send-time boundary the plugin's pre-step occupied.
  List<String> _mentionsIn(String text) {
    final workspace = _tools.workspace;
    if (workspace == null) return const [];
    return [
      for (final mention in resolveMentions(text, workspace))
        referenceForm(mention),
    ];
  }

  /// The task list and plan of record, for whatever surface shows them. Both
  /// live in the conversation itself (the tool output is the state), so these
  /// are read-only views onto `PlanTools`.
  List<TodoItem> get todos => _planTools.todos;
  String? get plan => _planTools.plan;

  /// Null until the first turn of a conversation has been persisted.
  @override
  String? get sessionId => _chat?.sessionId;

  bool get isTurnActive => _turn != null;

  /// Sends [text], with [images] riding the same message, and streams the
  /// turn.
  ///
  /// The returned stream always ends with a [TurnFinished], including when it
  /// fails. Listen once: it drives a live turn, so it is not a broadcast stream.
  @override
  Stream<TurnEvent> send(String text, {List<AttachedImage> images = const []}) {
    if (!settings.model.isConfigured) {
      return Stream.value(
        const TurnFinished(
          outcome: TurnOutcome.failed,
          errorMessage:
              'No API key set. Open settings and paste the provider API key.',
        ),
      );
    }
    final chat = _chat ??= _agent.chat();
    // dsh-at-file's pre-step, inline: every validated `@path` token in the
    // user's own words becomes an existence-only reference part ahead of the
    // body, so the model sees the pointer without the send being blocked on
    // it. Invalid tokens stay prose.
    final references = _mentionsIn(text);
    // Images ride the message as media parts — the data-URI form genkit's
    // `Media.url` carries inline images as. Text-only sends keep the plain
    // string path, which is what a store round-trip preserves best.
    if (images.isEmpty) {
      if (references.isEmpty) {
        return _drive((cancel) => chat.sendStream(text: text, cancel: cancel));
      }
      final message = Message(
        role: Role.user,
        content: [
          for (final reference in references) TextPart(text: reference),
          if (text.isNotEmpty) TextPart(text: text),
        ],
      );
      return _drive(
        (cancel) => chat.sendStream(message: message, cancel: cancel),
      );
    }
    final message = Message(
      role: Role.user,
      content: [
        for (final reference in references) TextPart(text: reference),
        if (text.isNotEmpty) TextPart(text: text),
        for (final image in images)
          MediaPart(
            media: Media(
              contentType: image.mediaType,
              url: image.dataUrl,
            ),
          ),
      ],
    );
    return _drive(
      (cancel) => chat.sendStream(message: message, cancel: cancel),
    );
  }

  /// Answers a pending approval and streams the rest of the turn.
  ///
  /// Approving restarts the paused tool call with the verdict attached; declining
  /// responds on its behalf so the loop continues with the refusal in hand,
  /// rather than dying.
  @override
  Stream<TurnEvent> respondToApproval({
    required String ref,
    required bool approved,
  }) {
    final chat = _chat;
    final pending = _pendingInterrupts[ref];
    if (chat == null || pending == null) {
      return Stream.value(
        const TurnFinished(
          outcome: TurnOutcome.failed,
          errorMessage: 'That approval request is no longer pending.',
        ),
      );
    }
    _pendingInterrupts.remove(ref);
    return _drive(
      (cancel) => approved
          ? chat.resumeStream(
              restart: [pending.restart({'approved': true})],
              cancel: cancel,
            )
          : chat.resumeStream(
              respond: [
                pending.respond({
                  'ok': false,
                  'error': 'The user declined this call.',
                }),
              ],
              cancel: cancel,
            ),
    );
  }

  /// Stops the running turn.
  ///
  /// Three things at once, because no one of them is sufficient: cancel the token
  /// (bookkeeping, and short-circuits a turn that has not started), raise the
  /// stop gate (cuts the loop at the next model or tool call), and stop consuming
  /// the stream (which is what actually makes the UI go quiet immediately).
  @override
  void stop() {
    if (_turn == null) return;
    _stop.value = true;
    _cancel?.cancel();
    _turn?.abort();
  }

  /// Interrupts still awaiting a decision, keyed by tool-call ref.
  final Map<String, AgentInterrupt> _pendingInterrupts = {};

  /// Runs [start] and projects its chunks into [TurnEvent]s.
  Stream<TurnEvent> _drive(
    AgentTurn<dynamic> Function(CancellationToken cancel) start,
  ) async* {
    if (_turn != null) {
      yield const TurnFinished(
        outcome: TurnOutcome.failed,
        errorMessage: 'A turn is already running.',
      );
      return;
    }

    _stop.value = false;
    // One turn owns the ledger at a time (`_turn` is null-checked above), so
    // resetting here scopes every figure this turn reports to its own calls —
    // a delegation's model calls land in the same turn's ledger.
    _usage.reset();
    final cancel = CancellationToken();
    _cancel = cancel;
    final turn = start(cancel);
    _turn = turn;

    // Requests are streamed twice for an interrupting tool — once plain, once
    // carrying the interrupt payload — so both need deduping by ref.
    final announced = <String>{};
    final asked = <String>{};
    var stopped = false;

    // The stats line's clock: turn entry stamped here, first token stamped at
    // the first projected delta. `Stopwatch` rather than wall DateTime so a
    // suspended machine clock cannot produce a negative duration.
    final watch = Stopwatch()..start();
    int? ttftMs;

    try {
      await for (final chunk in turn.stream) {
        if (_stop.value) {
          stopped = true;
          break;
        }
        final events = _project(chunk, announced, asked);
        if (ttftMs == null && events.isNotEmpty) {
          ttftMs = watch.elapsedMilliseconds;
        }
        yield* Stream.fromIterable(events);
      }

      if (stopped) {
        // The response future will complete (or fail) on its own schedule now
        // that nobody is reading the stream; drop it so it is not an unhandled
        // async error.
        turn.response.ignore();
        yield TurnFinished(
          outcome: TurnOutcome.cancelled,
          sessionId: _chat?.sessionId,
        );
        return;
      }

      final response = await turn.response;
      // Any interrupt the stream did not surface — belt and braces, since the
      // response list is the authoritative one.
      for (final interrupt in response.interrupts) {
        final ref = interrupt.ref;
        if (ref == null || asked.contains(ref)) continue;
        asked.add(ref);
        _pendingInterrupts[ref] = interrupt;
        yield ApprovalRequired(
          ApprovalRequest(
            ref: ref,
            toolName: interrupt.name,
            arguments: _asArguments(interrupt.input),
            details: _asArguments(
              response.toolRequests
                  .firstWhere((r) => r.toolRequest.ref == ref)
                  .metadata?['interrupt'],
            ),
          ),
        );
      }

      yield TurnFinished(
        outcome: _outcomeOf(response.finishReason),
        sessionId: response.sessionId ?? _chat?.sessionId,
        snapshotId: response.snapshotId,
        errorMessage: _outcomeOf(response.finishReason) == TurnOutcome.failed
            ? (response.finishMessage ?? 'The turn failed.')
            : null,
        usage: _usageOf(watch, ttftMs),
      );
    } on AgentError catch (e) {
      yield TurnFinished(
        outcome: _stop.value ? TurnOutcome.cancelled : TurnOutcome.failed,
        sessionId: _chat?.sessionId,
        snapshotId: e.snapshotId,
        errorMessage: e.message,
      );
    } catch (e) {
      yield TurnFinished(
        outcome: _stop.value ? TurnOutcome.cancelled : TurnOutcome.failed,
        sessionId: _chat?.sessionId,
        errorMessage: '$e',
      );
    } finally {
      _turn = null;
      _cancel = null;
      _stop.value = false;
    }
  }

  /// One chunk in, zero or more application events out.
  List<TurnEvent> _project(
    AgentChunk<dynamic> chunk,
    Set<String> announced,
    Set<String> asked,
  ) {
    final events = <TurnEvent>[];
    final modelChunk = chunk.raw.modelChunk;
    // Not `accumulatedText`: that one is turn-global and keeps growing across
    // model calls, so it cannot stand in for a single message's body.
    final index = modelChunk?.index ?? 0;

    if (chunk.text.isNotEmpty) {
      events.add(TextDelta(text: chunk.text, messageIndex: index));
    }
    if (chunk.reasoning.isNotEmpty) {
      events.add(ReasoningDelta(text: chunk.reasoning, messageIndex: index));
    }

    for (final part in chunk.toolRequests) {
      final request = part.toolRequest;
      final ref = request.ref;
      if (ref == null) continue;
      if (announced.add(ref)) {
        events.add(
          ToolCallRequested(
            ref: ref,
            name: request.name,
            arguments: _asArguments(request.input),
          ),
        );
      }
      final payload = part.metadata?['interrupt'];
      if (payload != null && asked.add(ref)) {
        _pendingInterrupts[ref] = AgentInterrupt(part);
        events.add(
          ApprovalRequired(
            ApprovalRequest(
              ref: ref,
              toolName: request.name,
              arguments: _asArguments(request.input),
              details: _asArguments(payload),
            ),
          ),
        );
      }
    }

    // `AgentChunk` has no tool-response accessor, so results come off the raw
    // model chunk.
    for (final part in modelChunk?.content ?? const <Part>[]) {
      if (!part.isToolResponse) continue;
      final response = part.toolResponse!;
      final ref = response.ref;
      if (ref == null) continue;
      events.add(_toolResult(ref, response.output));
    }

    return events;
  }

  /// Tools report recoverable trouble as `{ok: false, error: ...}` rather than
  /// throwing, so the model can retry instead of the turn dying. That convention
  /// is unpacked here, which is why it lives next to `tools.dart`.
  TurnEvent _toolResult(String ref, Object? output) {
    if (output is Map && output['ok'] == false) {
      return ToolCallFailed(
        ref: ref,
        message: output['error']?.toString() ?? 'The tool failed.',
      );
    }
    return ToolCallSucceeded(ref: ref, output: output);
  }

  static TurnOutcome _outcomeOf(AgentFinishReason reason) =>
      switch (reason.value) {
        'stop' => TurnOutcome.completed,
        'interrupted' => TurnOutcome.awaitingApproval,
        'aborted' || 'detached' => TurnOutcome.cancelled,
        'length' => TurnOutcome.truncated,
        _ => TurnOutcome.failed,
      };

  /// The turn's cost figures: wall time and TTFT are always measured; the
  /// token sums are present only when the provider reported usage at all, and
  /// each field only when the provider split it out.
  TurnUsage _usageOf(Stopwatch watch, int? ttftMs) => TurnUsage(
    wallMs: watch.elapsedMilliseconds,
    ttftMs: ttftMs,
    inputTokens: _usage.sawInput ? _usage.inputTokens : null,
    outputTokens: _usage.sawOutput ? _usage.outputTokens : null,
    thoughtsTokens: _usage.sawThoughts ? _usage.thoughtsTokens : null,
    totalTokens: _usage.sawTotal ? _usage.totalTokens : null,
    modelCalls: _usage.seen ? _usage.modelCalls : null,
  );

  static Map<String, dynamic> _asArguments(Object? raw) =>
      raw is Map ? raw.cast<String, dynamic>() : const {};

  // -------------------------------------------------------------------------
  // Sessions
  // -------------------------------------------------------------------------

  /// Drops the current conversation. The old one stays on disk and in
  /// [listSessions].
  @override
  void startNewSession() {
    _chat = null;
    _pendingInterrupts.clear();
    _planTools.reset();
  }

  /// Restores a persisted conversation and returns its transcript.
  ///
  /// The transcript is rebuilt from the snapshot rather than from the chat's own
  /// message list, which the spike found omits tool turns. The todo list and
  /// plan come off the same snapshot, so they survive the reload too.
  @override
  Future<List<ConversationNode>> openSession(String id) async {
    final chat = await _agent.loadChat(sessionId: id);
    _chat = chat;
    _pendingInterrupts.clear();
    _planTools.restoreFrom(chat.messages);
    return projectMessages(chat.messages);
  }

  /// The persisted conversations, newest first.
  ///
  /// `SessionStore` has no listing API, so this walks the pointer files the store
  /// writes: one per session, named for the session id.
  @override
  Future<List<SessionSummary>> listSessions() async {
    // `global` is the store's default context prefix; the app never sets a
    // custom one.
    final pointers = Directory(p.join(sessionRoot.path, 'global', '.pointers'));
    if (!pointers.existsSync()) return const [];

    final summaries = <SessionSummary>[];
    for (final entry in pointers.listSync()) {
      if (entry is! File || p.extension(entry.path) != '.json') continue;
      final id = p.basenameWithoutExtension(entry.path);
      try {
        final snapshot = await _agent.getSnapshot(sessionId: id);
        if (snapshot == null) continue;
        summaries.add(
          SessionSummary(
            id: id,
            updatedAt:
                DateTime.tryParse(snapshot.updatedAt ?? '') ??
                entry.statSync().modified,
            title: _titleOf(snapshot.messages),
          ),
        );
      } catch (_) {
        // A half-written or orphaned pointer should cost one row, not the list.
        continue;
      }
    }
    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }

  /// The first user message, collapsed to a single line.
  static String? _titleOf(List<Message> messages) {
    for (final message in messages) {
      if (message.role.value != 'user') continue;
      final text = message.text.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text.isEmpty) continue;
      return text.length <= 80 ? text : '${text.substring(0, 79)}…';
    }
    return null;
  }

  /// Rebuilds a transcript from a persisted message list — the snapshot's own
  /// `state.messages`, which unlike a live chat's list carries the tool turns
  /// too (spike finding 8).
  ///
  /// Public and static so the restore contract — tool turns survive, results
  /// pair with their calls by ref, reasoning rides along — can be regression-
  /// tested without a store round trip. Ids are derived from positions so they
  /// are stable across reloads, which is what lets scroll position survive a
  /// restore.
  static List<ConversationNode> projectMessages(List<Message> messages) {
    final nodes = <ConversationNode>[];
    final toolsByRef = <String, int>{};

    for (var i = 0; i < messages.length; i++) {
      final message = messages[i];
      // Switched on `.value`: `Role` is an extension type over `String`, so
      // `Role.user` is a getter rather than a constant, and cannot be a pattern.
      switch (message.role.value) {
        case 'user':
          final text = message.text.trim();
          if (text.isNotEmpty) {
            nodes.add(UserMessageNode(id: 'm$i', text: text));
          }

        case 'model':
          final text = message.text;
          final reasoning = message.content
              .where((part) => part.isReasoning)
              .map((part) => part.reasoning ?? '')
              .join();
          if (text.trim().isNotEmpty || reasoning.trim().isNotEmpty) {
            nodes.add(
              AssistantMessageNode(
                id: 'm$i',
                text: text,
                reasoning: reasoning,
              ),
            );
          }
          for (final part in message.content) {
            if (!part.isToolRequest) continue;
            final request = part.toolRequest!;
            final ref = request.ref ?? 'm$i-${nodes.length}';
            toolsByRef[ref] = nodes.length;
            nodes.add(
              ToolCallNode(
                id: 'm$i-$ref',
                name: request.name,
                arguments: _asArguments(request.input),
                // No matching response means the conversation was persisted
                // mid-call; leave it running rather than inventing an outcome.
                status: ToolStatus.running,
              ),
            );
          }

        case 'tool':
          for (final part in message.content) {
            if (!part.isToolResponse) continue;
            final response = part.toolResponse!;
            final at = toolsByRef[response.ref];
            if (at == null) continue;
            final node = nodes[at] as ToolCallNode;
            final output = response.output;
            nodes[at] = output is Map && output['ok'] == false
                ? node.copyWith(
                    status: ToolStatus.failed,
                    errorMessage:
                        output['error']?.toString() ?? 'The tool failed.',
                  )
                : node.copyWith(status: ToolStatus.succeeded, output: output);
          }

        case _:
          break;
      }
    }
    return nodes;
  }

  Future<void> dispose() async {
    stop();
    // The host owns subprocesses (stdio servers); dropping it without closing
    // would leak them for the life of the app.
    await _host?.close();
    await _ai.shutdown();
  }
}
