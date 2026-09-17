// The app entry: read the settings, build the scope, run the frame.
//
// Assembly only, twice over: `main` decides the order the stores are opened
// in and owns the riverpod container; `_DshAppState` decides what hangs
// where in the tree. Every decision of consequence lives in the piece that
// owns it — the runtime swap and the controller wiring in
// `state/app_scope.dart`, the concession solve in `ui/layout/columns.dart`,
// the turn projection in `state/conversation_controller.dart`.
//
// Since ADR-0002 stage 3 this frame is a pure Consumer tree: data arrives
// through `ref.watch` on the providers in `state/app_providers.dart`, and
// the only remaining use of the scope handle is the imperative actions
// (save, session commands, folder picks) that were never data in the first
// place. The ListenableBuilder scaffolding for theme/locale/prefs/hero
// rebuilds is gone — a store save now notifies through the read-seam
// providers and the tree rebuilds from the same write.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme;
import 'package:window_manager/window_manager.dart';

import 'genkit/models_endpoint.dart';
import 'host/project_folder_ops.dart';
import 'l10n/locales.dart';
import 'model/app_settings.dart' as cfg;
import 'state/app_providers.dart';
import 'state/details_selection.dart';
import 'state/hotkey_service.dart';
import 'state/plan_task_store.dart';
import 'state/prefs_store.dart';
import 'state/settings_store.dart';
import 'state/tray_service.dart';
import 'state/workspace_mode_controller.dart';
import 'theme/dsw_shad_bridge.dart';
import 'theme/dsw_theme.dart';
import 'ui/app_frame.dart';
import 'ui/appearance_scope.dart';
import 'ui/conversation/conversation_root.dart';
import 'ui/conversation/details_panel.dart';
import 'ui/conversation/hero_workspace_picker.dart';
import 'ui/plan/plan_extensions_view.dart';
import 'ui/plan/plan_workspace.dart';
import 'ui/settings/model_settings.dart';
import 'ui/sidebar/sidebar.dart';
import 'ui/workbench/free_window_layer.dart';
import 'ui/workbench/workbench.dart';
import 'ui/workbench/workbench_prefs_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Application Support, not Documents: snapshots and an API key are app state,
  // not user files. Inside the macOS sandbox container this is writable without
  // any further entitlement.
  final support = await getApplicationSupportDirectory();
  final settings = await SettingsStore.open(support);
  final prefsStore = await PrefsStore.open(support);
  // The plan side's tasks (ADR-0007): same bootstrap rule — opened before the
  // first frame, never from a provider body.
  final planTasks = await PlanTaskStore.open(support);
  // The workspace access a previous launch recorded has to be claimed BEFORE
  // anything reads under the root — the file tree's first listing, the
  // session restore, the tools. A failure here is not an error: the hero
  // picker's own UI is the "ask again" path.
  await restoreWorkspaceAccess(bookmark: settings.value.workspaceBookmark);
  // Window manager: required for global hotkeys and system tray.
  await windowManager.ensureInitialized();
  // The container owns the store providers (ADR-0002 stage 1): `main` opens
  // the stores above — async bootstrap stays imperative, a first frame racing
  // a FutureProvider for its own settings document is a bug, not a loading
  // state — then overrides the providers with the opened instances. The tree
  // reads them through the scope; nothing below `main` may open a store.
  final container = ProviderContainer(
    overrides: [
      supportDirectoryProvider.overrideWithValue(support),
      settingsStoreProvider.overrideWithValue(settings),
      prefsStoreProvider.overrideWithValue(prefsStore),
      planTaskStoreProvider.overrideWithValue(planTasks),
    ],
  );
  runApp(
    UncontrolledProviderScope(container: container, child: const DshApp()),
  );
}

class DshApp extends ConsumerStatefulWidget {
  const DshApp({super.key});

  @override
  ConsumerState<DshApp> createState() => _DshAppState();
}

class _DshAppState extends ConsumerState<DshApp> {
  /// The settings panel's visibility — the one piece of app-wide state that
  /// is a view concern rather than a controller's.
  bool _settingsOpen = false;

  /// Global hotkey service. Initialized after the first frame so the window
  /// handle is available for system-scope registration.
  HotkeyService? _hotkeys;

  /// System tray service. Initialized alongside hotkeys after the first frame.
  TrayService? _tray;

  @override
  void initState() {
    super.initState();
    // Nothing works without a key, and the composer's failure message is a
    // worse way to learn that than the panel that fixes it. dsh opens an
    // onboarding dialog on the same condition.
    _settingsOpen = !ref.read(settingsStoreProvider).value.model.isConfigured;
    // Register hotkeys and tray after the frame so window_manager has a handle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initHotkeys();
      _initTray();
    });
  }

  void _initHotkeys() {
    _hotkeys = HotkeyService(
      onToggleWindow: _toggleWindow,
      onNewSession: () => ref.read(appScopeProvider).newSession(),
      onOpenSettings: () => setState(() => _settingsOpen = true),
    );
    _hotkeys!.init();
  }

  void _initTray() {
    _tray = TrayService(onQuit: () => windowManager.close());
    _tray!.init();
  }

  Future<void> _toggleWindow() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void dispose() {
    _hotkeys?.dispose();
    _tray?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Data: read seams. The document a save commits (theme, locale, workspace,
    // model) and the workbench prefs rebuild this frame in the same write.
    final doc = ref.watch(settingsDocumentProvider);
    final prefs = ref.watch(workbenchPrefsProvider);
    // Actions: the scope handle. Save, session commands, folder picks —
    // imperative verbs that were never data.
    final scope = ref.watch(appScopeProvider);
    // The conversation column's width class, resolved to pixels once per
    // document and mounted below (ADR-0005 S4). The composer and the in-column
    // cards read the same value off the scope, so the whole column widens
    // together.
    final contentWidth = doc.conversationWidth == cfg.AppConversationWidth.wide
        ? chatContentWidthWide
        : chatContentWidth;

    return MaterialApp(
      title: 'Agent Harness',
      debugShowCheckedModeBanner: false,
      theme: dswThemeData(Brightness.light),
      darkTheme: dswThemeData(Brightness.dark),
      // Every shad component asserts a ShadTheme ancestor; this builder sits
      // above the Navigator, so pushed routes (dialogs, sheets) inherit it
      // too. The colour scheme is dsw's own (ADR-0002 decision 4, route A):
      // the bridge reads the resolved brightness back out of the Material
      // theme, so one themeMode drives both systems.
      builder: (context, child) => ShadTheme(
        data: dswShadTheme(Theme.of(context).brightness),
        child: child!,
      ),
      // The mode the settings screen writes. `system` hands the decision to the
      // platform's own brightness, which MaterialApp reads through this same
      // parameter — there is nothing else to wire.
      themeMode: switch (doc.theme) {
        cfg.ThemeMode.system => ThemeMode.system,
        cfg.ThemeMode.light => ThemeMode.light,
        cfg.ThemeMode.dark => ThemeMode.dark,
      },
      home: Scaffold(
        // The locale seat, resolved once per document: an explicit choice wins,
        // `system` follows the platform. The scope wraps the whole body — the
        // frame, the free windows and the settings panel that floats over them
        // all read the same resolution.
        body: AppLocaleScope(
          locale: switch (doc.locale) {
            cfg.LocaleMode.en => AppLocaleId.en,
            cfg.LocaleMode.zh => AppLocaleId.zh,
            cfg.LocaleMode.system =>
              Platform.localeName.toLowerCase().startsWith('zh')
                  ? AppLocaleId.zh
                  : AppLocaleId.en,
          },
          // The prefs scope wraps the whole frame — the tab strip's `+` menu, the
          // empty pane's cards and the terminal's glyphs all read it, and the
          // settings panel that writes it floats over the same tree.
          child: WorkbenchPrefsScope(
            prefs: prefs,
            child: AppearanceScope(
              contentWidth: contentWidth,
              expandToolCalls: doc.expandToolCalls,
              // ADR-0006 S4: settings is a full-screen view that replaces the
              // body, not an overlay on top of it — a state swap, still no route.
              child: _settingsOpen
                  ? _settingsPage(doc)
                  // ADR-0007: the frame re-renders when the top-level
                  // workspace mode (企划/代理) changes — the controller is a
                  // ChangeNotifier the provider fronts, so this is the same
                  // listen-and-rebuild shape the layout controller uses.
                  : ListenableBuilder(
                      listenable: ref.watch(workspaceModeProvider),
                      builder: (context, _) => AppFrame(
                        layout: ref.watch(layoutProvider),
                        sidebarBuilder: (context, collapsed, width) => Sidebar(
                          collapsed: collapsed,
                          width: width,
                          sessions: ref.watch(sessionsProvider),
                          // The identity the footer avatar shows. `.value` — the
                          // avatar renders a placeholder until the (mock, later Supabase)
                          // source resolves; riverpod stays out of the widget tree.
                          profile: ref.watch(userProfileProvider).value,
                          // The footer quick-menu edits these live (theme/locale/width
                          // never rebuild the runtime), so it needs the document and the
                          // save path — the same `scope.save` the settings panel uses.
                          // `ref.read` in the callback (audit F7): the save path is an
                          // action, not data, and keepAlive makes it identical either
                          // way — this is the riverpod-lint-conventional spelling.
                          settings: doc,
                          onSettingsChanged: (next) =>
                              ref.read(appScopeProvider).save(next),
                          // The 企划/代理 switch (ADR-0007).
                          mode: ref.watch(workspaceModeProvider).mode,
                          onSelectMode: ref
                              .watch(workspaceModeProvider)
                              .selectMode,
                          // The plan extension panels' open view + toggle.
                          extensionView: ref
                              .watch(workspaceModeProvider)
                              .extensionView,
                          onToggleExtension: ref
                              .watch(workspaceModeProvider)
                              .toggleExtension,
                          onNewSession: scope.newSession,
                          onToggle: ref.read(layoutProvider).toggleSidebar,
                          onOpenSession: scope.openSession,
                          onOpenSettings: () =>
                              setState(() => _settingsOpen = true),
                          // The frame rebuilds the sidebar on every layout write, so the
                          // open state read here is never stale.
                          onToggleDetails: ref
                              .read(layoutProvider)
                              .toggleDetails,
                          detailsOpen: ref.watch(layoutProvider).details != 0,
                        ),
                        center: _centerPane(doc),
                        details: DetailsPanel(
                          conversation: ref.watch(conversationProvider),
                          selection: ref.watch(detailsSelectionProvider),
                          // Closing the column keeps the selection. dsh's `closeDetails`
                          // does the same — it is a layout write and nothing else — which
                          // is what lets the pill on the call already selected reopen the
                          // panel onto it.
                          onClose: ref.read(layoutProvider).closeDetails,
                        ),
                        workbench: Workbench(
                          workbench: ref.watch(workbenchProvider),
                          conversation: ref.watch(conversationProvider),
                          sideChat: ref.watch(sideChatProvider),
                          terminals: ref.watch(terminalsProvider),
                          onClose: ref.read(layoutProvider).closeWorkbench,
                        ),
                        bottom: Workbench(
                          workbench: ref.watch(workbenchProvider),
                          conversation: ref.watch(conversationProvider),
                          sideChat: ref.watch(sideChatProvider),
                          terminals: ref.watch(terminalsProvider),
                          onClose: ref.read(layoutProvider).closeBottom,
                          panel: WorkbenchPanel.bottom,
                        ),
                        overlay: _floats(),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// The center pane by workspace mode (ADR-0007): 代理 keeps the conversation
  /// harness exactly as it was; 企划 swaps in the markdown vault, and its
  /// extension panels (board/calendar/table) take the pane over entirely.
  Widget _centerPane(cfg.AppSettings doc) {
    final scope = ref.watch(appScopeProvider);
    final modes = ref.watch(workspaceModeProvider);
    if (modes.mode == WorkspaceMode.plan) {
      return switch (modes.extensionView) {
        PlanExtensionView.none => PlanWorkspace(
          workspaceRoot: doc.workspaceRoot,
          onPickWorkspace: scope.pickFromHero,
        ),
        PlanExtensionView.board ||
        PlanExtensionView.calendar ||
        PlanExtensionView.table => PlanExtensionsView(
          store: ref.watch(planTaskStoreProvider),
          view: modes.extensionView,
        ),
      };
    }
    return DetailsSelectionScope(
      selection: ref.watch(detailsSelectionProvider),
      // The hero's picker reads the saved document, not a form, so a folder
      // adopted anywhere (the hero itself, the settings panel) shows here in
      // the same write that recorded it — `doc` above.
      child: HeroWorkspaceScope(
        workspaceRoot: doc.workspaceRoot,
        recent: doc.recentWorkspaces,
        onPick: scope.pickFromHero,
        onAdopt: scope.adoptRecent,
        child: ConversationRoot(
          conversation: ref.watch(conversationProvider),
          tail: ref.watch(streamingTailProvider),
          modelDirectory: ref.watch(modelDirectoryProvider),
          // The seat offers; the host commits. The commit is a plain
          // model-field save — the scope's, so the runtime follows the choice
          // the way any model change does.
          onModelSelected: scope.selectModel,
          // dsh-at-file's Remote, in one process: the index runs off the UI
          // thread and lands as entries.
          onLookupFiles: scope.lookupWorkspaceFiles,
          workspaceRoot: doc.workspaceRoot,
          onPickWorkspace: scope.pickFromHero,
        ),
      ),
    );
  }

  /// The free-floating windows, layered over the frame's work areas.
  Widget _floats() {
    return FreeWindowLayer(
      workbench: ref.watch(workbenchProvider),
      conversation: ref.watch(conversationProvider),
      sideChat: ref.watch(sideChatProvider),
      terminals: ref.watch(terminalsProvider),
    );
  }

  /// The full-screen settings view (ADR-0006 S4). It replaces the frame body
  /// while open — not an overlay — and reads the saved document, so a save
  /// rebuilds it in the same write (the credential dot goes green without
  /// closing anything).
  Widget _settingsPage(cfg.AppSettings doc) {
    final scope = ref.watch(appScopeProvider);
    return SettingsPanel(
      settings: doc,
      onSave: scope.save,
      onClose: () => setState(() => _settingsOpen = false),
      onPickFolder: scope.pickFolder,
      workbenchPrefs: ref.watch(workbenchPrefsProvider),
      onPrefsChange: (next) => ref.read(prefsStoreProvider).save(next),
      // The endpoint interrogation behind "Test connection" and the model
      // quick-select: one HTTP fetcher, shared by both.
      modelsFetcher: const HttpModelsEndpointFetcher(),
    );
  }
}
