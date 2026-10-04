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

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadButton, ShadDialog;
import 'package:url_launcher/url_launcher.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadSonner, ShadTheme;
import 'package:screen_retriever/screen_retriever.dart' as retriever;
import 'package:window_manager/window_manager.dart';

import 'genkit/models_endpoint.dart';
import 'host/project_folder_ops.dart';
import 'host/reveal.dart';
import 'host/support_directory.dart';
import 'l10n/locales.dart';
import 'model/app_settings.dart' as cfg;
import 'state/app_providers.dart';
import 'state/window_geometry_store.dart';
import 'state/details_selection.dart';
import 'state/hotkey_service.dart';
import 'model/plan_mock_content.dart';
import 'state/plan_object_store.dart';
import 'state/prefs_store.dart';
import 'state/crash_archive.dart';
import 'state/auth_session.dart';
import 'state/secret_store.dart';
import 'state/usage_ledger.dart';
import 'state/settings_store.dart';
import 'state/tray_service.dart';
import 'state/window_title_service.dart';
import 'state/workspace_mode_controller.dart';
import 'theme/dsw_shad_bridge.dart';
import 'theme/dsw_theme.dart';
import 'ui/app_frame.dart';
import 'ui/appearance_scope.dart';
import 'ui/conversation/conversation_root.dart';
import 'ui/conversation/details_panel.dart';
import 'ui/conversation/hero_workspace_picker.dart';
import 'ui/plan/dataview/plan_data_view_screen.dart';
import 'ui/plan/library/plan_all_content_screen.dart';
import 'ui/plan/library/plan_bin_screen.dart';
import 'ui/plan/library/plan_create_collection.dart';
import 'ui/plan/library/plan_gallery_screen.dart';
import 'ui/plan/widgets/plan_widgets_screen.dart';
import 'ui/plan/plan_workspace.dart';
import 'model/app_meta.dart';
import 'theme/dsw_shape.dart';
import 'theme/dsw_typography.dart';
import 'ui/auth/welcome_screen.dart';
import 'ui/settings/model_settings.dart';
import 'ui/sidebar/sidebar.dart';
import 'ui/workbench/free_window_layer.dart';
import 'ui/workbench/workbench.dart';
import 'ui/workbench/workbench_prefs_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Local crash archive (ADR-0045 PC): the support root is known only after
  // getApplicationSupportDirectory, so the handlers capture the archive once
  // it exists; errors before that point keep the framework's default path.
  // Assigned in main() once the archive exists — the handlers read the same
  // instance the container overrides with.
  CrashArchive? crashArchive;
  FlutterError.onError = (details) {
    crashArchive?.write(
      'flutter',
      '${details.exception}\n${details.stack ?? ''}',
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    crashArchive?.write('platform', '$error\n$stack');
    return false;
  };
  // Application Support, not Documents: snapshots and an API key are app state,
  // not user files. Inside the macOS sandbox container this is writable without
  // any further entitlement.
  final support = await getApplicationSupportDirectory();
  // The app's own files are keyed by the application identity, which changed
  // with the 企划星 rename. Move them before anything reads them, or a full
  // install boots looking like a first run.
  final movedFrom = await migrateSupportDirectory(support);
  if (movedFrom != null) {
    debugPrint(
      'support directory migrated from "$movedFrom" to ${support.path}',
    );
  }
  final crash = CrashArchive(
    directory: Directory('${support.path}/logs/crash'),
  );
  // Warm the checks the settings page reads synchronously (ADR-0045 PC).
  crashArchive = crash;
  crash.knownNonEmpty = (await crash.files()).isNotEmpty;
  final usageLedger = UsageLedger(
    directory: Directory('${support.path}/usage'),
  );
  await usageLedger.prune();
  final bootUsageSummary = UsageLedger.summarize(await usageLedger.entries());
  final settings = await SettingsStore.open(
    support,
    secrets: SecureSecretStore(),
  );
  final prefsStore = await PrefsStore.open(support);
  // The plan workspace's object store (ADR-0037): the same bootstrap rule, and
  // the only place the mock seed is named.
  final planSpace = await PlanObjectStore.open(support, seed: planMockSeed());
  // The workspace access a previous launch recorded has to be claimed BEFORE
  // anything reads under the root — the file tree's first listing, the
  // session restore, the tools. A failure here is not an error: the hero
  // picker's own UI is the "ask again" path.
  await restoreWorkspaceAccess(bookmark: settings.value.workspaceBookmark);
  // Window manager: required for global hotkeys and system tray.
  await windowManager.ensureInitialized();
  // The window's last shape (ADR-0062): restore clamped to the primary
  // display, keep the window reachable (min 960x640), and save as the user
  // drags. A failure here is cosmetic — the default window shows anyway.
  final geometryStore = WindowGeometryStore.open(support);
  await windowManager.setMinimumSize(const Size(960, 640));
  try {
    final display = await retriever.screenRetriever.getPrimaryDisplay();
    final visible = Rect.fromLTWH(
      display.visiblePosition?.dx ?? 0,
      display.visiblePosition?.dy ?? 0,
      display.visibleSize?.width ?? display.size.width,
      display.visibleSize?.height ?? display.size.height,
    );
    final restored = geometryStore.value?.clampedTo(visible);
    if (restored != null) {
      await windowManager.setBounds(
        Rect.fromLTWH(restored.x, restored.y, restored.width, restored.height),
      );
    }
    windowManager.addListener(WindowGeometryListener(store: geometryStore));
  } on Exception {
    // No display answer: the platform default stands.
  }
  // The container owns the store providers (ADR-0002 stage 1): `main` opens
  // the stores above — async bootstrap stays imperative, a first frame racing
  // a FutureProvider for its own settings document is a bug, not a loading
  // state — then overrides the providers with the opened instances. The tree
  // reads them through the scope; nothing below `main` may open a store.
  // The auth session (ADR-0045 PE): the origin comes from the packaging env
  // var the self-built backend ships with, defaulting to empty — empty
  // disables the browser flow and leaves the API-key path.
  final appOrigin = const bool.hasEnvironment('ZCODE_ENDPOINT_ORIGIN')
      ? const String.fromEnvironment('ZCODE_ENDPOINT_ORIGIN')
      : const String.fromEnvironment('ZCODE_ENDPOINT_ORIGIN', defaultValue: '');
  final auth = AuthSession(secrets: SecureSecretStore(), origin: appOrigin);
  final container = ProviderContainer(
    overrides: [
      supportDirectoryProvider.overrideWithValue(support),
      settingsStoreProvider.overrideWithValue(settings),
      prefsStoreProvider.overrideWithValue(prefsStore),
      planObjectStoreProvider.overrideWithValue(planSpace),
      usageSummaryProvider.overrideWithValue(bootUsageSummary),
      crashArchiveNonEmptyProvider.overrideWithValue(crash.knownNonEmpty),
      crashArchiveProvider.overrideWithValue(crash),
      authSessionProvider.overrideWithValue(auth),
      zcodeOriginProvider.overrideWithValue(appOrigin),
      appWindowProvider.overrideWithValue(windowManager),
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

  /// Whether the auth-restore already ran (ADR-0045 PE): the gate renders
  /// only after the cached session had its chance.
  bool _authRestored = false;

  /// Global hotkey service. Initialized after the first frame so the window
  /// handle is available for system-scope registration.
  HotkeyService? _hotkeys;

  /// System tray service. Initialized alongside hotkeys after the first frame.
  TrayService? _tray;

  /// The window's own title line, pushed after the frame (ADR-0019).
  WindowTitleService? _windowTitles;

  @override
  void initState() {
    super.initState();
    // Nothing works without a key, and the composer's failure message is a
    // worse way to learn that than the panel that fixes it. dsh opens an
    // onboarding dialog on the same condition.
    _settingsOpen = !ref.read(settingsStoreProvider).value.model.isConfigured;
    // The auth gate (ADR-0045 PE): restore runs before the first frame's
    // gate decision, so a returning signed-in user never sees the welcome.
    () async {
      final session = ref.read(authSessionProvider);
      await session.restore(
        hasApiKey: ref
            .read(settingsStoreProvider)
            .value
            .model
            .apiKey
            .isNotEmpty,
      );
      if (mounted) setState(() => _authRestored = true);
    }();
    // Register hotkeys and tray after the frame so window_manager has a handle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initHotkeys();
      _initTray();
      _initWindowTitle();
    });
  }

  void _initHotkeys() {
    _hotkeys = HotkeyService(
      onToggleWindow: _toggleWindow,
      onNewSession: () => ref.read(appScopeProvider).newSession(),
      onOpenSettings: () => setState(() => _settingsOpen = true),
      onToggleSidebar: () => ref.read(layoutProvider).toggleSidebar(),
    );
    _hotkeys!.init();
  }

  void _initTray() {
    _tray = TrayService(onQuit: () => windowManager.close());
    _tray!.init();
  }

  void _initWindowTitle() {
    final scope = ref.read(appScopeProvider);
    _windowTitles = WindowTitleService(sessions: scope.sessions)
      ..setWorkspace(ref.read(settingsDocumentProvider).workspaceRoot)
      ..init();
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
    _windowTitles?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Data: read seams. The document a save commits (theme, locale, workspace,
    // model) and the workbench prefs rebuild this frame in the same write.
    final doc = ref.watch(settingsDocumentProvider);
    // The title bar is painted by the system, so the two facts it reads are
    // pushed to the service instead of composed in the tree (ADR-0019).
    ref.listen<String?>(
      settingsDocumentProvider.select((d) => d.workspaceRoot),
      (_, next) => _windowTitles?.setWorkspace(next),
    );
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
      title: AppMeta.productName,
      debugShowCheckedModeBanner: false,
      theme: dswThemeData(Brightness.light),
      darkTheme: dswThemeData(Brightness.dark),
      // Every shad component asserts a ShadTheme ancestor; this builder sits
      // above the Navigator, so pushed routes (dialogs, sheets) inherit it
      // too. The colour scheme is dsw's own (ADR-0002 decision 4, route A):
      // the bridge reads the resolved brightness back out of the Material
      // theme, so one themeMode drives both systems.
      builder: (context, child) {
        // ADR-0017 S3: the stored text-size step multiplies INTO the platform's
        // own scaler instead of replacing it, so the OS's "放大文本" and the
        // user's own choice compose rather than compete. One seat above the
        // Navigator means dialogs and the settings page scale with the frame,
        // and `DswType` stays the pure ramp it is — the framework already has
        // this channel, and every `Text` reads it.
        final textScale =
            MediaQuery.textScalerOf(context).scale(1) * doc.fontSize.scale;
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: ShadTheme(
            // The bridge needs the same number: shad sizes a few seats with a
            // plain double (`ShadContextMenuItem.height` → `ShadButton.raw`),
            // and a seat that does not know the step cuts a scaled label.
            data: dswShadTheme(
              Theme.of(context).brightness,
              textScale: textScale,
            ),
            // The locale seat, resolved once per document: an explicit choice
            // wins, `system` follows the platform. It belongs here rather than on
            // `home:` because an overlay route is not under `home:` — mounted
            // there, every menu and dialog silently fell back to English
            // key-by-key (ADR-0032, caught in a real window screenshot as
            // `Retry` next to 中文). Same seam ADR-0017 learned for `MediaQuery`.
            child: AppLocaleScope(
              locale: switch (doc.locale) {
                cfg.LocaleMode.en => AppLocaleId.en,
                cfg.LocaleMode.zh => AppLocaleId.zh,
                cfg.LocaleMode.system =>
                  Platform.localeName.toLowerCase().startsWith('zh')
                      ? AppLocaleId.zh
                      : AppLocaleId.en,
              },
              // ADR-0020: the feedback strip's host. Above the Navigator, so a
              // toast raised from a dialog route or from the full-screen settings
              // still lands on the one strip the bridge colours from `DswAlias`.
              child: ShadSonner(child: child!),
            ),
          ),
        );
      },
      // The mode the settings screen writes. `system` hands the decision to the
      // platform's own brightness, which MaterialApp reads through this same
      // parameter — there is nothing else to wire.
      themeMode: switch (doc.theme) {
        cfg.ThemeMode.system => ThemeMode.system,
        cfg.ThemeMode.light => ThemeMode.light,
        cfg.ThemeMode.dark => ThemeMode.dark,
      },
      home: Scaffold(
        // The prefs scope wraps the whole frame — the tab strip's `+` menu, the
        // empty pane's cards and the terminal's glyphs all read it, and the
        // settings panel that writes it floats over the same tree.
        body: WorkbenchPrefsScope(
          prefs: prefs,
          child: AppearanceScope(
            contentWidth: contentWidth,
            expandToolCalls: doc.expandToolCalls,
            // ADR-0006 S4: settings is a full-screen view that replaces the
            // body, not an overlay on top of it — a state swap, still no route.
            child: _welcomeGate(doc)
                ? _welcomeScreen()
                : _settingsOpen
                ? _settingsPage(doc)
                // ADR-0007: the frame re-renders when the top-level
                // workspace mode (企划/代理) changes — the controller is a
                // ChangeNotifier the provider fronts, so this is the same
                // listen-and-rebuild shape the layout controller uses.
                : ListenableBuilder(
                    listenable: ref.watch(workspaceModeProvider),
                    builder: (context, _) => AppFrame(
                      layout: ref.watch(layoutProvider),
                      // The centre column's header: which folder, which
                      // conversation, and the menu of verbs that belongs to it.
                      workspaceRoot: doc.workspaceRoot,
                      // The index, not a snapshot out of it: the header reads
                      // `active` on every rebuild the index itself announces.
                      sessions: ref.watch(sessionsProvider),
                      onPickWorkspace: scope.pickFromHero,
                      onOpenSettings: () =>
                          setState(() => _settingsOpen = true),
                      // The plan-object store is a ChangeNotifier the
                      // providers cannot re-project; the builder re-reads its
                      // collections on every write so the sidebar's extension
                      // area and the center pane agree on what exists.
                      sidebarBuilder: (context, collapsed, width) => ListenableBuilder(
                        listenable: ref.watch(planObjectStoreProvider),
                        builder: (context, _) => Sidebar(
                          collapsed: collapsed,
                          width: width,
                          sessions: ref.watch(sessionsProvider),
                          // The identity the footer avatar shows. `.value` — the
                          // avatar renders a placeholder until the (mock, later Supabase)
                          // source resolves; riverpod stays out of the widget tree.
                          profile: ref.watch(userProfileProvider).value,
                          signedIn: ref.watch(authSnapshotProvider).signedIn,
                          userDisplayName: ref
                              .watch(authSnapshotProvider)
                              .user
                              ?.displayName,
                          onLogin: () => ref
                              .read(authSessionProvider)
                              .openWelcome(WelcomeReason.manualLogin),
                          onLogout: () =>
                              ref.read(authSessionProvider).logout(),
                          onOpenLink: (url) => launchUrl(
                            Uri.parse(url),
                            mode: LaunchMode.externalApplication,
                          ),
                          onAbout: () => _showAboutDialog(),
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
                          // The plan collections the extension area lists,
                          // re-read on every store write by the
                          // ListenableBuilder wrapping this Sidebar (the store
                          // is a ChangeNotifier, not a provider rebuild).
                          collections: [
                            for (final collection
                                in ref
                                    .watch(planObjectStoreProvider)
                                    .collections)
                              (id: collection.id, name: collection.name),
                          ],
                          openCollectionId: ref
                              .watch(workspaceModeProvider)
                              .openCollectionId,
                          extensionView: ref
                              .watch(workspaceModeProvider)
                              .extensionView,
                          onOpenLibrary: ref
                              .watch(workspaceModeProvider)
                              .toggleLibrary,
                          onAddCollection: () =>
                              showPlanCreateCollectionDialog(
                                context,
                                ref.watch(planObjectStoreProvider),
                              ).then((id) {
                                if (id != null) {
                                  ref
                                      .watch(workspaceModeProvider)
                                      .openCollection(id);
                                }
                              }),
                          onOpenCollection: ref
                              .watch(workspaceModeProvider)
                              .openCollection,
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
                          // The grouped history (ADR-0039): which folder is
                          // current, which ones are known, and the view state
                          // that belongs to the prefs document rather than to
                          // the settings one (a fold must never restart the
                          // runtime).
                          currentWorkspace: doc.workspaceRoot,
                          knownWorkspaces: doc.recentWorkspaces,
                          historyOrganize: prefs.historyOrganize,
                          collapsedWorkspaces: prefs.collapsedWorkspaces,
                          onToggleWorkspaceCollapsed: (key) => ref
                              .read(prefsStoreProvider)
                              .save(
                                prefs.withWorkspaceCollapsed(
                                  key,
                                  !prefs.workspaceCollapsed(key),
                                ),
                              ),
                          onHistoryOrganizeChanged: (organize) => ref
                              .read(prefsStoreProvider)
                              .save(prefs.withHistoryOrganize(organize)),
                          onNewSessionInWorkspace: (path) async {
                            await scope.adoptRecent(path);
                            await scope.newSession();
                          },
                          onOpenWorkspaceTree: (path) async {
                            // The tree has to point at a folder the app may
                            // read, so switching is the first half of the
                            // gesture — and `setWorkspace` stays the only path
                            // that changes folders.
                            await scope.adoptRecent(path);
                            scope.workbench.openFolder(path);
                          },
                          onRemoveWorkspace: (path) => scope.save(
                            doc.copyWith(
                              recentWorkspaces: [
                                for (final recent in doc.recentWorkspaces)
                                  if (recent != path) recent,
                              ],
                            ),
                          ),
                          onAddWorkspace: scope.pickFromHero,
                          onSetCollapsedWorkspaces: (keys) => ref
                              .read(prefsStoreProvider)
                              .save(prefs.copyWith(collapsedWorkspaces: keys)),
                        ),
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
                        status: ref.watch(appScopeProvider).gitStatus,
                        onClose: ref.read(layoutProvider).closeWorkbench,
                      ),
                      bottom: Workbench(
                        workbench: ref.watch(workbenchProvider),
                        conversation: ref.watch(conversationProvider),
                        sideChat: ref.watch(sideChatProvider),
                        terminals: ref.watch(terminalsProvider),
                        status: ref.watch(appScopeProvider).gitStatus,
                        onClose: ref.read(layoutProvider).closeBottom,
                        panel: WorkbenchPanel.bottom,
                      ),
                      overlay: _floats(),
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
      final planStore = ref.watch(planObjectStoreProvider);
      return switch (modes.extensionView) {
        PlanExtensionView.none => PlanWorkspace(
          workspaceRoot: doc.workspaceRoot,
          onPickWorkspace: scope.pickFromHero,
          collections: [
            for (final collection in planStore.collections)
              (id: collection.id, name: collection.name),
          ],
          onOpenCollection: modes.openCollection,
        ),
        PlanExtensionView.collection => PlanDataViewScreen(
          store: planStore,
          collectionId:
              modes.openCollectionId ??
              planStore.collections.firstOrNull?.id ??
              '',
        ),
        PlanExtensionView.allContent => PlanAllContentScreen(store: planStore),
        PlanExtensionView.widgets => PlanWidgetsScreen(store: planStore),
        PlanExtensionView.bin => PlanBinScreen(store: planStore),
        PlanExtensionView.gallery => PlanGalleryScreen(store: planStore),
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
          quickPhrases: scope.quickPhrases.phrases,
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
          onOpenSettings: () => setState(() => _settingsOpen = true),
          // ADR-0014 S3: the card offers the undo, the scope decides whether
          // there is a folder to undo inside and which conversation owns it.
          onPreviewRewind: scope.previewRewind,
          onRewind: scope.rewindCheckpoint,
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
      status: ref.watch(appScopeProvider).gitStatus,
    );
  }

  /// The About dialog (ADR-0045 PG): the product mark, name, version and the
  /// help links — ZCode's `关于 ZCode` entry, our own shape.
  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => ShadDialog.alert(
        radius: BorderRadius.circular(DswShape.float),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Theme.of(dialogContext).colorScheme.primary,
                borderRadius: BorderRadius.circular(DswShape.control),
              ),
              child: const Icon(
                LucideIcons.bot,
                size: DswShape.iconMd,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: DswShape.sm),
            Expanded(
              child: Text(
                context.tr('helpAboutTitle'),
                style: DswType.sStrong14,
              ),
            ),
          ],
        ),
        description: Text(
          context.tr('helpAboutBody').replaceAll('{version}', AppMeta.version),
          style: DswType.xs13,
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('planCancel')),
          ),
        ],
      ),
    );
  }

  /// The welcome gate (ADR-0045 PE): open while a welcome reason stands, the
  /// auth restore has run, and the user has an API key to fall back on or
  /// not — ZCode's rule is "no usable provider", which here means no key and
  /// no session.
  bool _welcomeGate(cfg.AppSettings doc) {
    if (!_authRestored) return false;
    final auth = ref.watch(authSnapshotProvider);
    if (!auth.welcomeOpen) return false;
    // ZCode's rule: the manual-login and session-expired reasons open the
    // gate regardless of an API key (the form carries its own skip); only
    // the startup reason defers to a usable key.
    if (auth.reason == WelcomeReason.manualLogin ||
        auth.reason == WelcomeReason.sessionExpired) {
      return true;
    }
    return doc.model.apiKey.isEmpty;
  }

  Widget _welcomeScreen() {
    final session = ref.read(authSessionProvider);
    final origin = ref.watch(zcodeOriginProvider);
    return WelcomeScreen(
      reason: session.welcomeReason ?? WelcomeReason.manualLogin,
      origin: origin,
      auth: session,
      onComplete: (reason) => setState(() {}),
      onApiKeyEnter: (key) {
        final current = ref.read(settingsStoreProvider).value;
        ref.read(settingsStoreProvider).save(current.copyWithModelApiKey(key));
        setState(() {});
      },
      onOpenRegister: (url) {
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
    );
  }

  /// The full-screen settings view (ADR-0006 S4). It replaces the frame body
  /// while open — not an overlay — and reads the saved document, so a save
  /// rebuilds it in the same write (the credential dot goes green without
  /// closing anything).
  Widget _settingsPage(cfg.AppSettings doc) {
    final scope = ref.watch(appScopeProvider);
    final supportPath = ref.watch(supportDirectoryProvider).path;

    return SettingsPanel(
      settings: doc,
      onSave: scope.save,
      onReset: () async {
        await ref.read(settingsStoreProvider).resetToDefaults();
        await ref.read(prefsStoreProvider).resetToDefaults();
      },
      usageSummary: ref.watch(usageSummaryProvider),
      onSaveCurrentToBook: () =>
          ref.read(settingsStoreProvider).saveCurrentProviderToBook(),
      onActivateSavedProvider: (id) =>
          ref.read(settingsStoreProvider).activateSavedProvider(id),
      onDeleteSavedProvider: (id) =>
          ref.read(settingsStoreProvider).deleteSavedProvider(id),
      crashFiles: ref.watch(crashArchiveNonEmptyProvider),
      onOpenCrashLog: () {
        revealInFileManager(
          '${ref.watch(supportDirectoryProvider).path}/logs/crash',
        );
      },
      onOpenDiagnosticsFolder: () {
        revealInFileManager(
          '${ref.watch(supportDirectoryProvider).path}/diagnostics',
        );
      },
      onClose: () => setState(() => _settingsOpen = false),
      onPickFolder: scope.pickFolder,
      // The field hints on the settings page name directories the user can open,
      // so they name the real one (ADR-0033). Read here, not in the panel:
      // riverpod stays out of the widget tree.
      supportPath: supportPath,
      workbenchPrefs: ref.watch(workbenchPrefsProvider),
      onPrefsChange: (next) => ref.read(prefsStoreProvider).save(next),
      // The endpoint interrogation behind "Test connection" and the model
      // quick-select: one HTTP fetcher, shared by both.
      modelsFetcher: const HttpModelsEndpointFetcher(),
      // The saved approvals are listed where they can be revoked — the panel's
      // "Always allow" is not the only place they can be seen (ADR-0012).
      approvals: scope.approvals,
      quickPhrases: scope.quickPhrases,
    );
  }
}
