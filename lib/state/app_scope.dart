// The composition root's lifetime half.
//
// `main.dart` decides the ORDER the pieces are built in and where they hang
// in the tree; this object owns everything after that moment — the runtime,
// the nine controllers, and the one swap no single controller can perform
// alone: replacing the runtime when the settings document changes. The
// widget tree reaches everything through the getters below, and nothing here
// reaches back into the tree: every state change it makes travels through a
// controller's own `notifyListeners`, which is what keeps the widget a view
// and this object testable without one.

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show compute;

import '../genkit/agent_runtime.dart';
import '../genkit/models_endpoint.dart';
import '../host/project_folder_ops.dart';
import '../host/terminal_manager.dart';
import '../model/app_settings.dart' as cfg;
import '../model/workspace_index.dart';
import '../model/workbench_prefs.dart';
import 'conversation_controller.dart';
import 'details_selection.dart';
import 'layout_controller.dart';
import 'model_directory.dart';
import 'prefs_store.dart';
import 'session_index.dart';
import 'settings_store.dart';
import 'side_chat_controller.dart';
import 'streaming_tail.dart';
import 'workbench_controller.dart';
import 'workbench_store.dart';

class AppScope {
  AppScope({
    required Directory support,
    required this.settings,
    required this.prefs,
  }) : _support = support {
    _sessionRoot = Directory('${support.path}/sessions')
      ..createSync(recursive: true);
    _runtime = _build(settings.value);
    // The model seat follows the document, not the runtime: a save that
    // rebuilds one re-points the other in the same write.
    _adoptModelDirectory(settings.value);
    settings.addListener(_onSettingsSaved);
    // The side chat rides the same runtime the transcript does, from the
    // first frame: its tab can be open before any conversation starts.
    _sideChat.adoptSource(_runtime.side);
    _sessions = SessionIndex(_runtime);
    _workbench = WorkbenchController(
      store: WorkbenchStore.open(support),
      workspaceRoot: settings.value.workspaceRoot,
    );
    _workbench.setDisabledTabs(_disabledTabsOf(prefs.value));
    prefs.addListener(_onPrefs);
    _layout.addListener(_onLayoutEdge);
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
  }

  /// Application Support, handed down from `main`: snapshots and the session
  /// tree are app state, not user files.
  final Directory _support;

  /// The settings document — read by the tree, written through [save].
  final SettingsStore settings;

  /// The workbench preferences, the same contract.
  final PrefsStore prefs;

  late final Directory _sessionRoot;
  late AgentRuntime _runtime;

  final _tail = StreamingTail();
  final _layout = LayoutController();
  final _terminals = TerminalManager();
  final _sideChat = SideChatController();

  /// The composer's model seat — dsh's `ctx.modelDirectories`. Adopted on
  /// every settings save so the chip can never name a model the document
  /// does not carry.
  late final ModelDirectory _modelDirectory = ModelDirectory(
    current: settings.value.model,
    fetcher: const HttpModelsEndpointFetcher(),
  );
  late final ConversationController _conversation;
  late final SessionIndex _sessions;
  late final WorkbenchController _workbench;

  /// dsh's `openDetails(target)` is one call that both points the panel at a
  /// tool call and opens the column it lives in. Here those are two objects,
  /// and this is where they are joined.
  late final DetailsSelection _selection = DetailsSelection(
    onSelect: _layout.openDetails,
  );

  /// The session whose bottom-panel seed has already fired. Seeding is once
  /// per session — the second expansion of the same session's bottom panel is
  /// the user's own business. Null means the current (unsaved) conversation
  /// has not had one yet; the empty-string key is that conversation's identity.
  String? _bottomSeededFor;

  /// Mirrors [_layout]'s bottom state between notifications, so the listener
  /// sees edges rather than levels — a resize drag fires dozens of times, and
  /// only the closed-to-open one is the seed's moment.
  bool _bottomWasOpen = false;

  /// Mirrors [_layout]'s mobile flag the same way: only the crossing runs the
  /// merge, and the reducer's idempotence is the safety net under any
  /// notification the mirror missed.
  bool _mobileWasOn = false;

  // ---- What the tree reaches ----------------------------------------------

  AgentRuntime get runtime => _runtime;
  StreamingTail get tail => _tail;
  LayoutController get layout => _layout;
  TerminalManager get terminals => _terminals;
  SideChatController get sideChat => _sideChat;
  ModelDirectory get modelDirectory => _modelDirectory;
  ConversationController get conversation => _conversation;
  SessionIndex get sessions => _sessions;
  WorkbenchController get workbench => _workbench;
  DetailsSelection get selection => _selection;

  /// Tears the scope down in dependency order. Not a framework hook — the
  /// widget's `dispose` calls it — but the ordering rules below are the same
  /// kind of promise one would make there.
  void dispose() {
    _runtime.dispose();
    _conversation.dispose();
    _sideChat.dispose();
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
    prefs.removeListener(_onPrefs);
    settings.removeListener(_onSettingsSaved);
    _layout.removeListener(_onLayoutEdge);
    _modelDirectory.dispose();
  }

  /// The tab types [prefs] switches off — the controller's gate reads a set,
  /// the document keeps a map, and this is the only place they meet.
  static Set<String> _disabledTabsOf(WorkbenchPrefs prefs) => {
        for (final entry in prefs.tabsEnabled.entries)
          if (!entry.value) entry.key,
      };

  /// Re-points the model seat at the saved document. Called on every save —
  /// a provider change and a model change both ride it, and the seat has to
  /// follow either one.
  void _onSettingsSaved() => _adoptModelDirectory(settings.value);

  void _adoptModelDirectory(cfg.AppSettings settings) {
    final model = settings.model;
    _modelDirectory
      ..adopt(model)
      ..adoptConnection(
        baseUrl: model.baseUrl,
        apiKey: model.apiKey,
      );
  }

  /// The model seat's commit: the model field changes, the document saves,
  /// and [save] rebuilds the runtime the way any model change does — the
  /// conversation's replacement is the price of a single-process runtime,
  /// and dsh pays the same one for its own model-field edits.
  Future<void> selectModel(String id) async {
    final current = settings.value;
    if (current.model.model == id) return;
    await save(current.copyWith(model: current.model.copyWith(model: id)));
  }

  /// The `@` mention menu's index, off the UI thread: a synchronous walk is
  /// fine for a desktop workspace, but not on the platform thread.
  Future<List<FileEntry>> lookupWorkspaceFiles() async {
    final root = _runtime.workspaceRoot;
    if (root == null) return const [];
    return compute(indexWorkspace, root).then((index) => index.entries);
  }

  /// Pushes a prefs write into the workbench's gate. No notify needed there:
  /// a disabled type refuses opens, and an open tab's rendering never
  /// consulted the gate in the first place.
  void _onPrefs() =>
      _workbench.setDisabledTabs(_disabledTabsOf(prefs.value));

  /// The bottom panel's closed-to-open edge: where the terminal seed fires.
  void _onLayoutEdge() {
    // The mobile crossing first: the merge has to happen before anything reads
    // the trees this frame's widgets are about to build from.
    if (_layout.mobile != _mobileWasOn) {
      _mobileWasOn = _layout.mobile;
      _workbench.setMobileMerge(_layout.mobile);
      // Entering the merge closes the bottom preference too, as the source's
      // migration does: coming back to a wide viewport must not spring a panel
      // the user never had open there — the tabs are in the drawer's tree now,
      // and the desktop bottom panel returns as the empty welcome.
      if (_layout.mobile) _layout.closeBottom();
    }

    final open = _layout.bottom != 0;
    final wasOpen = _bottomWasOpen;
    _bottomWasOpen = open;
    if (!open || wasOpen) return;

    // Once per session, whatever "session" means right now.
    final session = _workbench.sessionId ?? '';
    if (_bottomSeededFor == session) return;
    _bottomSeededFor = session;

    if (!prefs.value.bottomPanelAutoTerminal) return;
    // A restored layout that already put a terminal down there has nothing
    // left to seed — the seed exists to make an empty panel useful, not to
    // stack shells on a settled one.
    final alreadyHasTerminal = _workbench.state.bottomPanes.any(
      (pane) => pane.tabs.any((tab) => tab.type == 'terminal'),
    );
    if (alreadyHasTerminal) return;
    _workbench.openTerminalInBottom();
  }

  AgentRuntime _build(cfg.AppSettings settings) => AgentRuntime(
        settings: settings,
        sessionRoot: _sessionRoot,
        support: _support,
      )..workspaceRoot = settings.workspaceRoot;

  /// Persists the edited settings, then brings the runtime in line with them.
  ///
  /// The model fields, the MCP server set and the skills directory are all
  /// baked into a registered agent, so a change to any of them is a rebuild;
  /// the workspace is a live setter and is not. Both controllers are handed
  /// the replacement, which drops the open conversation — it belonged to the
  /// old connection. It stays on disk.
  Future<void> save(cfg.AppSettings next) async {
    final previous = settings.value;
    await settings.save(next);
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
    // The side chat's exchange belonged to the replaced runtime's agent; the
    // controller drops it the way the transcript drops its conversation.
    _sideChat.adoptSource(_runtime.side);
    _selection.clear();
    _sessions.setActive(null);
    // The dropped conversation took its layout with it, the same as the two
    // session commands below.
    await _workbench.bindSession(null);
    await _sessions.adoptRuntime(_runtime);
    // Disposed last: it may still be unwinding a turn the swap just abandoned.
    await replaced.dispose();
  }

  /// The platform's directory picker, applied to the document the panel holds
  /// — adopted in the same write that records it, so the recent list and the
  /// permission can never disagree. A dismissed picker (null) is not an error:
  /// dsh's flow treats cancel as a no-op, and so does the panel.
  ///
  /// On macOS the native panel is the one that hands back a security-scoped
  /// bookmark with the path, so the pick survives a restart (see
  /// `ProjectFolderOps`); elsewhere — or if the channel is unavailable — the
  /// `file_picker` plugin's panel stands in, without the durable permission.
  ///
  /// The result is NOT saved — the panel commits the whole document on Save,
  /// and adopting is what the user asked the picker for, not what they asked
  /// Save for.
  Future<cfg.AppSettings?> pickFolder(cfg.AppSettings current) async {
    if (ProjectFolderChannelOps.isSupported) {
      const ops = ProjectFolderChannelOps();
      final picked = await ops.pickDirectory();
      if (picked == null) return null;
      return current.withWorkspace(
        picked.path,
        bookmark: picked.bookmark,
      );
    }
    final result = await FilePicker.platform.getDirectoryPath();
    if (result == null) return null;
    return current.withWorkspace(result);
  }

  /// The hero's pick flow. The panel's `Choose…` fills a field that waits for
  /// Save; the hero has no form, so the pick is committed in the same write
  /// that records it — [save], not a bare `settings.save`, so the runtime
  /// and the workbench follow the folder in the same step.
  Future<void> pickFromHero() async {
    final next = await pickFolder(settings.value);
    if (next == null) return;
    await save(next);
  }

  /// Adopts a recent folder from the hero's menu — same immediacy as
  /// [pickFromHero], and for the same reason: the menu is a list of places to
  /// be, not a form to edit.
  Future<void> adoptRecent(String path) async {
    final current = settings.value;
    if (current.workspaceRoot == path) return;
    await save(current.withWorkspace(path));
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
  Future<void> newSession() async {
    _conversation.startNewSession();
    _selection.clear();
    _sessions.setActive(null);
    await _workbench.bindSession(null);
  }

  Future<void> openSession(String id) async {
    await _conversation.openSession(id);
    _selection.clear();
    _sessions.setActive(id);
    await _workbench.bindSession(id);
  }
}
