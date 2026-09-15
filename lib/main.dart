// The app entry: read the settings, build the scope, run the frame.
//
// Assembly only, twice over: `main` decides the order the stores are opened
// in and owns the riverpod container; `_DshAppState` decides what hangs
// where in the tree. Every decision of consequence lives in the piece that
// owns it — the runtime swap and the controller wiring in
// `state/app_scope.dart`, the concession solve in `ui/layout/columns.dart`,
// the turn projection in `state/conversation_controller.dart`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'genkit/models_endpoint.dart';
import 'host/project_folder_ops.dart';
import 'l10n/locales.dart';
import 'model/app_settings.dart' as cfg;
import 'state/app_providers.dart';
import 'state/app_scope.dart';
import 'state/details_selection.dart';
import 'state/prefs_store.dart';
import 'state/settings_store.dart';
import 'theme/dsw_theme.dart';
import 'ui/app_frame.dart';
import 'ui/conversation/conversation_root.dart';
import 'ui/conversation/details_panel.dart';
import 'ui/conversation/hero_workspace_picker.dart';
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
  // The workspace access a previous launch recorded has to be claimed BEFORE
  // anything reads under the root — the file tree's first listing, the
  // session restore, the tools. A failure here is not an error: the hero
  // picker's own UI is the "ask again" path.
  await restoreWorkspaceAccess(bookmark: settings.value.workspaceBookmark);
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

  @override
  void initState() {
    super.initState();
    // Nothing works without a key, and the composer's failure message is a
    // worse way to learn that than the panel that fixes it. dsh opens an
    // onboarding dialog on the same condition.
    _settingsOpen = !ref.read(settingsStoreProvider).value.model.isConfigured;
  }

  @override
  Widget build(BuildContext context) {
    // The scope (runtime + nine controllers + the swap) is owned by the
    // container; the tree only reads it (ADR-0002 stage 2). Its disposal
    // rides the container's lifetime — `main` owns that, not this state.
    final scope = ref.watch(appScopeProvider);
    return ListenableBuilder(
      // The document the settings screen commits: theme and locale are read at
      // the MaterialApp level, which sits ABOVE the panels' own scopes, so the
      // rebuild has to start here for either to take effect without a restart.
      listenable: scope.settings,
      builder: (context, _) => MaterialApp(
        title: 'Agent Harness',
        debugShowCheckedModeBanner: false,
        theme: dswThemeData(Brightness.light),
        darkTheme: dswThemeData(Brightness.dark),
        // The mode the settings screen writes. `system` hands the decision to the
        // platform's own brightness, which MaterialApp reads through this same
        // parameter — there is nothing else to wire.
        themeMode: switch (scope.settings.value.theme) {
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
            locale: switch (scope.settings.value.locale) {
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
            child: ListenableBuilder(
              listenable: scope.prefs,
              builder: (context, _) => WorkbenchPrefsScope(
                prefs: scope.prefs.value,
                child: AppFrame(
                  layout: scope.layout,
                  sidebarBuilder: (context, collapsed, width) => Sidebar(
                    collapsed: collapsed,
                    width: width,
                    sessions: scope.sessions,
                    onNewSession: scope.newSession,
                    onToggle: scope.layout.toggleSidebar,
                    onOpenSession: scope.openSession,
                    onOpenSettings: () => setState(() => _settingsOpen = true),
                    // The frame rebuilds the sidebar on every layout write, so the
                    // open state read here is never stale.
                    onToggleDetails: scope.layout.toggleDetails,
                    detailsOpen: scope.layout.details != 0,
                  ),
                  center: DetailsSelectionScope(
                    selection: scope.selection,
                    child: ListenableBuilder(
                      // The hero's picker reads the saved document, not a form, so it
                      // has to rebuild on save — a folder adopted anywhere (the hero
                      // itself, the settings panel) shows here in the same write that
                      // recorded it.
                      listenable: scope.settings,
                      builder: (context, _) => HeroWorkspaceScope(
                        workspaceRoot: scope.settings.value.workspaceRoot,
                        recent: scope.settings.value.recentWorkspaces,
                        onPick: scope.pickFromHero,
                        onAdopt: scope.adoptRecent,
                        child: ConversationRoot(
                          conversation: scope.conversation,
                          tail: scope.tail,
                          modelDirectory: scope.modelDirectory,
                          // The seat offers; the host commits. The commit is a
                          // plain model-field save — the scope's, so the runtime
                          // follows the choice the way any model change does.
                          onModelSelected: scope.selectModel,
                          // dsh-at-file's Remote, in one process: the index
                          // runs off the UI thread and lands as entries.
                          onLookupFiles: scope.lookupWorkspaceFiles,
                        ),
                      ),
                    ),
                  ),
                  details: DetailsPanel(
                    conversation: scope.conversation,
                    selection: scope.selection,
                    // Closing the column keeps the selection. dsh's `closeDetails`
                    // does the same — it is a layout write and nothing else — which
                    // is what lets the pill on the call already selected reopen the
                    // panel onto it.
                    onClose: scope.layout.closeDetails,
                  ),
                  workbench: Workbench(
                    workbench: scope.workbench,
                    conversation: scope.conversation,
                    sideChat: scope.sideChat,
                    terminals: scope.terminals,
                    onClose: scope.layout.closeWorkbench,
                  ),
                  bottom: Workbench(
                    workbench: scope.workbench,
                    conversation: scope.conversation,
                    sideChat: scope.sideChat,
                    terminals: scope.terminals,
                    onClose: scope.layout.closeBottom,
                    panel: WorkbenchPanel.bottom,
                  ),
                  overlay: _overlay(scope),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(AppScope scope) {
    // The free windows first: they float over everything, and the settings
    // panel — when it is up — floats over them.
    final floats = FreeWindowLayer(
      workbench: scope.workbench,
      conversation: scope.conversation,
      sideChat: scope.sideChat,
      terminals: scope.terminals,
    );
    if (!_settingsOpen) return floats;
    return Stack(
      children: [
        floats,
        ListenableBuilder(
          // The panel reads the saved document, so it has to rebuild on save —
          // that is what turns the credential dot green without closing
          // anything.
          listenable: scope.settings,
          builder: (context, _) => SettingsPanel(
            settings: scope.settings.value,
            onSave: scope.save,
            onClose: () => setState(() => _settingsOpen = false),
            onPickFolder: scope.pickFolder,
            workbenchPrefs: scope.prefs.value,
            onPrefsChange: (next) => scope.prefs.save(next),
            // The endpoint interrogation behind "Test connection" and the
            // model quick-select: one HTTP fetcher, shared by both.
            modelsFetcher: const HttpModelsEndpointFetcher(),
          ),
        ),
      ],
    );
  }
}
