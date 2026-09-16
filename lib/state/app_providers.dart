// The app's riverpod entry layer (ADR-0002).
//
// Stage 1 moved the three objects `main` opens before `runApp` — the stores
// and Application Support — into overridden keepAlive providers.
// Stage 2 made the composition root itself a provider.
// Stage 3 (this file's lower half) adds the read seams and the per-controller
// providers that let deep widgets `ref.watch` their controller instead of
// receiving it through constructors.
//
// What deliberately stays put for stage 4: the runtime hot-swap chain
// (`AppScope.save` → conditional runtime rebuild → the two `adopt*` calls).
// That chain is conditional (`requiresRuntimeRestart`), ordered (the replaced
// runtime is disposed last), and load-bearing for the streaming contract —
// expressing it as a provider rebuild needs `ref.listen` choreography that
// deserves its own commit behind its own test run.
//
// Shape: `main` creates the container, overrides the store providers with
// the opened instances, and hands the container to the tree through
// `UncontrolledProviderScope`. The providers take no parameters — a
// parameterized provider is a family, and a family is the wrong shape for
// objects that must exist exactly once.

import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/app_settings.dart';
import '../model/user_profile.dart';
import '../model/workbench_prefs.dart';
import 'app_scope.dart';
import 'conversation_controller.dart';
import 'details_selection.dart';
import '../host/profile_repository.dart';
import '../host/terminal_manager.dart';
import 'layout_controller.dart';
import 'model_directory.dart';
import 'prefs_store.dart';
import 'session_index.dart';
import 'settings_store.dart';
import 'side_chat_controller.dart';
import 'streaming_tail.dart';
import 'workbench_controller.dart';
import 'workspace_mode_controller.dart';

part 'app_providers.g.dart';

/// Application Support, opened once by `main` and overridden into the
/// container — same pattern as the two stores below. A provider rather than
/// a constructor parameter, because [appScope] reads it through the
/// container and the tree above never threads a `Directory` around.
@Riverpod(keepAlive: true)
Directory supportDirectory(Ref ref) =>
    throw UnimplementedError('override supportDirectory in main or tests');

/// The settings document. Opened before the first frame so the panel that
/// fixes a missing key can already be up, and so the workspace bookmark is
/// in hand before anything tries to read under the root.
///
/// Overridden in `main`'s container with the already-opened store — the
/// override, not the body, is the live path in production. The default
/// throws: opening a store needs a real directory, and there is no
/// meaningful default for "where do the app's documents live".
@Riverpod(keepAlive: true)
SettingsStore settingsStore(Ref ref) =>
    throw UnimplementedError('override settingsStore in main or tests');

/// The workbench preferences, opened alongside the settings for the same
/// reason: the first frame's tab menus already need the switches.
@Riverpod(keepAlive: true)
PrefsStore prefsStore(Ref ref) =>
    throw UnimplementedError('override prefsStore in main or tests');

/// The composition root (ADR-0002 stage 2): the runtime, the nine
/// controllers, and the runtime swap, now owned by the container instead of
/// `_DshAppState`. The widget tree reads it through
/// `ref.watch(appScopeProvider)`; nothing in the tree constructs it.
///
/// Lifetime: keepAlive, so the scope lives as long as the container — which
/// lives as long as `main`. Disposal order is delegated to [AppScope.dispose]
/// via `onDispose`; the container tears it down when `main` drops it, the
/// same moment `_DshAppState.dispose` used to.
@Riverpod(keepAlive: true)
AppScope appScope(Ref ref) {
  final scope = AppScope(
    support: ref.watch(supportDirectoryProvider),
    settings: ref.watch(settingsStoreProvider),
    prefs: ref.watch(prefsStoreProvider),
  );
  ref.onDispose(scope.dispose);
  return scope;
}

// ---- Read seams (stage 3a) ------------------------------------------------
//
// The stores stay the write path (atomic tmp+rename); these providers are
// the read side, so a save anywhere rebuilds every reader in the same write.

/// The settings document's current value. Theme, locale, workspace, model
/// fields — everything the tree renders straight out of the document.
///
/// `invalidateSelf`, NOT `notifyListeners`: on a functional provider
/// `notifyListeners` re-notifies the *cached* value without re-running the body,
/// so a store save never reaches readers — that was the theme/locale/workspace
/// not-updating regression. `invalidateSelf` re-runs the body (fresh `value`);
/// dependents rebuild only if it actually changed.
@Riverpod(keepAlive: true)
AppSettings settingsDocument(Ref ref) {
  final store = ref.watch(settingsStoreProvider);
  void listener() => ref.invalidateSelf();
  store.addListener(listener);
  ref.onDispose(() => store.removeListener(listener));
  return store.value;
}

/// The workbench preferences' current value. Same `invalidateSelf` reason as
/// [settingsDocument].
@Riverpod(keepAlive: true)
WorkbenchPrefs workbenchPrefs(Ref ref) {
  final store = ref.watch(prefsStoreProvider);
  void listener() => ref.invalidateSelf();
  store.addListener(listener);
  ref.onDispose(() => store.removeListener(listener));
  return store.value;
}

// ---- Per-controller providers (stage 3b) ----------------------------------
//
// One provider per controller, each a thin projection of [appScope]. They
// exist so deep widgets can watch exactly the controller they need — the
// sidebar watches [sessions], a tab body watches [conversation] — instead of
// every widget threading the whole scope down. AppScope stays the single
// owner and the single place the controllers are wired together; dissolving
// it is stage 4's problem, not these providers'.
//
// All keepAlive: the controllers live for the app's lifetime, exactly as
// they did as AppScope fields.

@Riverpod(keepAlive: true)
ConversationController conversation(Ref ref) =>
    ref.watch(appScopeProvider).conversation;

/// The streaming tail: the high-frequency end of the transcript. Kept its
/// own provider — not a projection of [conversation] — because the streaming
/// split is the app's one performance contract: token deltas notify the tail
/// and nothing else (see `test/conversation_controller_test.dart`).
@Riverpod(keepAlive: true)
StreamingTail streamingTail(Ref ref) => ref.watch(appScopeProvider).tail;

@Riverpod(keepAlive: true)
WorkbenchController workbench(Ref ref) => ref.watch(appScopeProvider).workbench;

@Riverpod(keepAlive: true)
LayoutController layout(Ref ref) => ref.watch(appScopeProvider).layout;

/// The terminal manager is host state, not a controller, but the same
/// projection applies: tabs watch it for session lifetime.
@Riverpod(keepAlive: true)
TerminalManager terminals(Ref ref) => ref.watch(appScopeProvider).terminals;

@Riverpod(keepAlive: true)
SideChatController sideChat(Ref ref) => ref.watch(appScopeProvider).sideChat;

@Riverpod(keepAlive: true)
ModelDirectory modelDirectory(Ref ref) =>
    ref.watch(appScopeProvider).modelDirectory;

@Riverpod(keepAlive: true)
SessionIndex sessions(Ref ref) => ref.watch(appScopeProvider).sessions;

@Riverpod(keepAlive: true)
DetailsSelection detailsSelection(Ref ref) =>
    ref.watch(appScopeProvider).selection;

// ---- Workspace modes (ADR-0007) -------------------------------------------
//
// The 企划/代理 top-level switch and the plan workspace's extension panel
// selection. View state, not persisted (a launch starts in the agent workspace);
// the ChangeNotifier is this file's own pattern — see `workspace_mode_controller`
// for why it is not a riverpod Notifier.

@Riverpod(keepAlive: true)
WorkspaceModeController workspaceMode(Ref ref) {
  final controller = WorkspaceModeController();
  ref.onDispose(controller.dispose);
  return controller;
}

// ---- Profile (ADR-0006) ---------------------------------------------------
//
// The identity the sidebar avatar and footer quick-menu show. Fetched, not
// persisted (see `model/user_profile.dart`). `main` reads [userProfile] and
// passes the resolved value down as a constructor argument — the same shape the
// other per-controller providers use to keep riverpod out of the widget tree.

/// The identity source. The mock is the live path today; `main` overrides this
/// with a Supabase-backed repository when that lands (the seam is documented in
/// `host/profile_repository.dart`) — the only thing the rest of the app sees is
/// a different [userProfile] value.
@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) => const MockProfileRepository();

/// The current user's profile, or null while loading / when signed out — the
/// avatar then falls back to an anonymous placeholder.
@Riverpod(keepAlive: true)
Future<UserProfile?> userProfile(Ref ref) =>
    ref.watch(profileRepositoryProvider).fetchProfile();
