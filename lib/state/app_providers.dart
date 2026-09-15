// The app's riverpod entry layer: the three objects `main` opens BEFORE
// `runApp`, now expressed as providers (ADR-0002 stage 1).
//
// Why these three and nothing else: everything the first frame needs —
// whether a key is on file, the theme, the locale, the tab switches, and the
// workspace permission a previous launch recorded — lives in one of these
// stores. Opening them before the first frame is what keeps the settings
// panel's first appearance (no key) and the hero picker's session restore
// race-free.
//
// Shape: `main` creates the container, pre-reads the (kept-alive) stores
// with `container.read`, then hands the container to the tree through
// `UncontrolledProviderScope`. The container's owner stays `main`, which is
// the riverpod-native version of the rule `app_scope.dart` has always had:
// lifetime decisions live above the tree. The providers take no parameters —
// a parameterized provider is a family, and a family is the wrong shape for
// objects that must exist exactly once.
//
// The controllers and the runtime swap stay in `AppScope` until their own
// stage; this file only moves what `main` already owned.

import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../model/workbench_prefs.dart';
import 'app_scope.dart';
import 'prefs_store.dart';
import 'settings_store.dart';

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
/// override, not the body, is the live path in production; the body exists
/// so tests without an override still get a working (empty) store only if
/// they provide a directory-scoped one. Opening a store needs a real
/// directory, so the default throws: there is no meaningful default for
/// "where do the app's documents live".
@Riverpod(keepAlive: true)
SettingsStore settingsStore(Ref ref) =>
    throw UnimplementedError('override settingsStore in main or tests');

/// The workbench preferences, opened alongside the settings for the same
/// reason: the first frame's tab menus already need the switches.
@Riverpod(keepAlive: true)
PrefsStore prefsStore(Ref ref) =>
    throw UnimplementedError('override prefsStore in main or tests');

/// The workbench preferences' current value, for the tree's read side. The
/// store stays the write path (atomic tmp+rename); this is the read seam so
/// a save anywhere rebuilds every reader in the same write.
@Riverpod(keepAlive: true)
WorkbenchPrefs workbenchPrefs(Ref ref) {
  final store = ref.watch(prefsStoreProvider);
  void listener() => ref.notifyListeners();
  store.addListener(listener);
  ref.onDispose(() => store.removeListener(listener));
  return store.value;
}

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
