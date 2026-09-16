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

import 'genkit/models_endpoint.dart';
import 'host/project_folder_ops.dart';
import 'l10n/locales.dart';
import 'model/app_settings.dart' as cfg;
import 'state/app_providers.dart';
import 'state/details_selection.dart';
import 'state/prefs_store.dart';
import 'state/settings_store.dart';
import 'theme/dsw_shad_bridge.dart';
import 'theme/dsw_theme.dart';
import 'ui/app_frame.dart';
import 'ui/appearance_scope.dart';
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
              child: AppFrame(
                layout: ref.watch(layoutProvider),
                sidebarBuilder: (context, collapsed, width) => Sidebar(
                  collapsed: collapsed,
                  width: width,
                  sessions: ref.watch(sessionsProvider),
                  // The identity the footer avatar shows. `.value` — the
                  // avatar renders a placeholder until the (mock, later Supabase)
                  // source resolves; riverpod stays out of the widget tree.
                  profile: ref.watch(userProfileProvider).value,
                  onNewSession: scope.newSession,
                  onToggle: ref.read(layoutProvider).toggleSidebar,
                  onOpenSession: scope.openSession,
                  onOpenSettings: () => setState(() => _settingsOpen = true),
                  // The frame rebuilds the sidebar on every layout write, so the
                  // open state read here is never stale.
                  onToggleDetails: ref.read(layoutProvider).toggleDetails,
                  detailsOpen: ref.watch(layoutProvider).details != 0,
                ),
                center: DetailsSelectionScope(
                  selection: ref.watch(detailsSelectionProvider),
                  // The hero's picker reads the saved document, not a form, so a
                  // folder adopted anywhere (the hero itself, the settings panel)
                  // shows here in the same write that recorded it — `doc` above.
                  child: HeroWorkspaceScope(
                    workspaceRoot: doc.workspaceRoot,
                    recent: doc.recentWorkspaces,
                    onPick: scope.pickFromHero,
                    onAdopt: scope.adoptRecent,
                    child: ConversationRoot(
                      conversation: ref.watch(conversationProvider),
                      tail: ref.watch(streamingTailProvider),
                      modelDirectory: ref.watch(modelDirectoryProvider),
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
                overlay: _overlay(doc),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _overlay(cfg.AppSettings doc) {
    final scope = ref.watch(appScopeProvider);
    // The free windows first: they float over everything, and the settings
    // panel — when it is up — floats over them.
    final floats = FreeWindowLayer(
      workbench: ref.watch(workbenchProvider),
      conversation: ref.watch(conversationProvider),
      sideChat: ref.watch(sideChatProvider),
      terminals: ref.watch(terminalsProvider),
    );
    if (!_settingsOpen) return floats;
    // The panel reads the saved document, so it has to rebuild on save —
    // that is what turns the credential dot green without closing anything.
    return Stack(
      children: [
        floats,
        SettingsPanel(
          settings: doc,
          onSave: scope.save,
          onClose: () => setState(() => _settingsOpen = false),
          onPickFolder: scope.pickFolder,
          workbenchPrefs: ref.watch(workbenchPrefsProvider),
          onPrefsChange: (next) => ref.read(prefsStoreProvider).save(next),
          // The endpoint interrogation behind "Test connection" and the
          // model quick-select: one HTTP fetcher, shared by both.
          modelsFetcher: const HttpModelsEndpointFetcher(),
        ),
      ],
    );
  }
}
