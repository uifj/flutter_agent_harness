// The app entry: read the settings, build the runtime, wire the four controllers
// into the frame.
//
// Assembly only. Every decision of consequence lives in the piece that owns it —
// the concession solve in `ui/layout/columns.dart`, the turn projection in
// `genkit/agent_runtime.dart`, the transcript in `state/`. What is here is the
// order those pieces have to be built in, and the one thing none of them can do
// alone: swapping the runtime when the model settings change.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'genkit/agent_runtime.dart';
import 'host/terminal_manager.dart';
import 'model/app_settings.dart';
import 'sidebar/state/workbench_controller.dart';
import 'sidebar/state/workbench_store.dart';
import 'sidebar/ui/workbench.dart';
import 'state/conversation_controller.dart';
import 'state/details_selection.dart';
import 'state/layout_controller.dart';
import 'state/session_index.dart';
import 'state/settings_store.dart';
import 'state/streaming_tail.dart';
import 'theme/dsw_theme.dart';
import 'ui/app_frame.dart';
import 'ui/conversation/conversation_root.dart';
import 'ui/conversation/details_panel.dart';
import 'ui/settings/model_settings.dart';
import 'ui/sidebar/sidebar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Application Support, not Documents: snapshots and an API key are app state,
  // not user files. Inside the macOS sandbox container this is writable without
  // any further entitlement.
  final support = await getApplicationSupportDirectory();
  final settings = await SettingsStore.open(support);
  runApp(DshApp(support: support, settings: settings));
}

class DshApp extends StatefulWidget {
  const DshApp({super.key, required this.support, required this.settings});

  final Directory support;

  /// Opened before `runApp` so the first frame already knows whether a key is on
  /// file, and can put the settings panel up if not.
  final SettingsStore settings;

  @override
  State<DshApp> createState() => _DshAppState();
}

class _DshAppState extends State<DshApp> {
  late final Directory _sessionRoot;
  late AgentRuntime _runtime;

  final _tail = StreamingTail();
  final _layout = LayoutController();
  final _terminals = TerminalManager();
  late final ConversationController _conversation;
  late final SessionIndex _sessions;
  late final WorkbenchController _workbench;

  /// dsh's `openDetails(target)` is one call that both points the panel at a
  /// tool call and opens the column it lives in. Here those are two objects,
  /// and this is where they are joined.
  late final DetailsSelection _selection = DetailsSelection(
    onSelect: _layout.openDetails,
  );

  bool _settingsOpen = false;

  @override
  void initState() {
    super.initState();
    _sessionRoot = Directory('${widget.support.path}/sessions')
      ..createSync(recursive: true);
    _runtime = _build(widget.settings.value);
    _sessions = SessionIndex(_runtime);
    _workbench = WorkbenchController(
      store: WorkbenchStore.open(widget.support),
      workspaceRoot: widget.settings.value.workspaceRoot,
    );
    _conversation = ConversationController(
      runtime: _runtime,
      tail: _tail,
      // A conversation gets its id from its first persisted turn, so this is when
      // a new session becomes listable — and when the sidebar can mark it. It is
      // also when the workbench layout built while composing that turn acquires
      // somewhere to be saved; see [WorkbenchController.bindSession].
      onSessionPersisted: (id) {
        _sessions.setActive(id);
        _sessions.refresh();
        _workbench.bindSession(id);
      },
    );
    _sessions.refresh();
    // Nothing works without a key, and the composer's failure message is a worse
    // way to learn that than the panel that fixes it. dsh opens an onboarding
    // dialog on the same condition.
    _settingsOpen = !widget.settings.value.model.isConfigured;
  }

  @override
  void dispose() {
    _runtime.dispose();
    _conversation.dispose();
    _sessions.dispose();
    // One call, not flush-then-dispose: the last layout change may still be
    // inside its debounce window, and the write has to finish before the queue is
    // cleared. `dispose` cannot await, so the ordering lives in `shutdown`.
    _workbench.shutdown();
    // Safety net: the tabs close their own sessions as they unmount, but the
    // state teardown at app exit is not guaranteed to run each body's dispose,
    // and a shell that outlives its window is a leak on the host.
    _terminals.dispose();
    _selection.dispose();
    _layout.dispose();
    _tail.dispose();
    super.dispose();
  }

  AgentRuntime _build(AppSettings settings) => AgentRuntime(
    settings: settings,
    sessionRoot: _sessionRoot,
    support: widget.support,
  )..workspaceRoot = settings.workspaceRoot;

  /// Persists the edited settings, then brings the runtime in line with them.
  ///
  /// The model fields, the MCP server set and the skills directory are all
  /// baked into a registered agent, so a change to any of them is a rebuild;
  /// the workspace is a live setter and is not. Both controllers are handed
  /// the replacement, which drops the open conversation — it belonged to the
  /// old connection. It stays on disk.
  Future<void> _save(AppSettings next) async {
    final previous = widget.settings.value;
    await widget.settings.save(next);
    // The workbench reads the same folder as the tools, through the same guard,
    // so it moves whether or not the runtime is rebuilt.
    _workbench.workspaceRoot = next.workspaceRoot;
    if (!next.requiresRuntimeRestart(previous)) {
      _runtime.workspaceRoot = next.workspaceRoot;
      return;
    }
    final replaced = _runtime;
    _runtime = _build(next);
    _conversation.adoptRuntime(_runtime);
    _selection.clear();
    _sessions.setActive(null);
    // The dropped conversation took its layout with it, the same as the two
    // session commands below.
    await _workbench.bindSession(null);
    await _sessions.adoptRuntime(_runtime);
    // Disposed last: it may still be unwinding a turn the swap just abandoned.
    await replaced.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Agent Harness',
    debugShowCheckedModeBanner: false,
    theme: dswThemeData(Brightness.light),
    darkTheme: dswThemeData(Brightness.dark),
    home: Scaffold(
      body: AppFrame(
        layout: _layout,
        sidebarBuilder: (context, collapsed, width) => Sidebar(
          collapsed: collapsed,
          width: width,
          sessions: _sessions,
          onNewSession: _newSession,
          onToggle: _layout.toggleSidebar,
          onOpenSession: _openSession,
          onOpenSettings: () => setState(() => _settingsOpen = true),
          // The frame rebuilds the sidebar on every layout write, so the open
          // state read here is never stale.
          onToggleDetails: _layout.toggleDetails,
          detailsOpen: _layout.details != 0,
          onToggleWorkbench: _layout.toggleWorkbench,
          workbenchOpen: _layout.workbench != 0,
          onToggleBottom: _layout.toggleBottom,
          bottomOpen: _layout.bottom != 0,
        ),
        center: DetailsSelectionScope(
          selection: _selection,
          child: ConversationRoot(conversation: _conversation, tail: _tail),
        ),
        details: DetailsPanel(
          conversation: _conversation,
          selection: _selection,
          // Closing the column keeps the selection. dsh's `closeDetails` does
          // the same — it is a layout write and nothing else — which is what
          // lets the pill on the call already selected reopen the panel onto it.
          onClose: _layout.closeDetails,
        ),
        workbench: Workbench(
          workbench: _workbench,
          conversation: _conversation,
          terminals: _terminals,
          onClose: _layout.closeWorkbench,
        ),
        bottom: Workbench(
          workbench: _workbench,
          conversation: _conversation,
          terminals: _terminals,
          onClose: _layout.closeBottom,
          panel: WorkbenchPanel.bottom,
        ),
        overlay: _overlay(),
      ),
    ),
  );

  Widget? _overlay() {
    if (!_settingsOpen) return null;
    return ListenableBuilder(
      // The panel reads the saved document, so it has to rebuild on save — that
      // is what turns the credential dot green without closing anything.
      listenable: widget.settings,
      builder: (context, _) => SettingsPanel(
        settings: widget.settings.value,
        onSave: _save,
        onClose: () => setState(() => _settingsOpen = false),
      ),
    );
  }

  /// Both session commands drop the selection. The transcript they replace is
  /// where the selected call lived, and a selection that outlives it would leave
  /// the panel on `notInWindow` with no way back — that state is for a call
  /// scrolled out of the window, not for one from another conversation.
  ///
  /// The workbench follows for the same reason it is keyed by session at all: the
  /// files a conversation was about are part of that conversation. Binding to null
  /// is not "empty" — it is the unsaved conversation's own layout, which the next
  /// first turn will carry over.
  Future<void> _newSession() async {
    _conversation.startNewSession();
    _selection.clear();
    _sessions.setActive(null);
    await _workbench.bindSession(null);
  }

  Future<void> _openSession(String id) async {
    await _conversation.openSession(id);
    _selection.clear();
    _sessions.setActive(id);
    await _workbench.bindSession(id);
  }
}
