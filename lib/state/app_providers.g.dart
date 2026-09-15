// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Application Support, opened once by `main` and overridden into the
/// container — same pattern as the two stores below. A provider rather than
/// a constructor parameter, because [appScope] reads it through the
/// container and the tree above never threads a `Directory` around.

@ProviderFor(supportDirectory)
final supportDirectoryProvider = SupportDirectoryProvider._();

/// Application Support, opened once by `main` and overridden into the
/// container — same pattern as the two stores below. A provider rather than
/// a constructor parameter, because [appScope] reads it through the
/// container and the tree above never threads a `Directory` around.

final class SupportDirectoryProvider
    extends $FunctionalProvider<Directory, Directory, Directory>
    with $Provider<Directory> {
  /// Application Support, opened once by `main` and overridden into the
  /// container — same pattern as the two stores below. A provider rather than
  /// a constructor parameter, because [appScope] reads it through the
  /// container and the tree above never threads a `Directory` around.
  SupportDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supportDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supportDirectoryHash();

  @$internal
  @override
  $ProviderElement<Directory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Directory create(Ref ref) {
    return supportDirectory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Directory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Directory>(value),
    );
  }
}

String _$supportDirectoryHash() => r'd5d0370265316686df899e097919c251eb287ecf';

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

@ProviderFor(settingsStore)
final settingsStoreProvider = SettingsStoreProvider._();

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

final class SettingsStoreProvider
    extends $FunctionalProvider<SettingsStore, SettingsStore, SettingsStore>
    with $Provider<SettingsStore> {
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
  SettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsStoreHash();

  @$internal
  @override
  $ProviderElement<SettingsStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SettingsStore create(Ref ref) {
    return settingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsStore>(value),
    );
  }
}

String _$settingsStoreHash() => r'fd812616f78db7cb466aaddb8691cac6e5de47ff';

/// The workbench preferences, opened alongside the settings for the same
/// reason: the first frame's tab menus already need the switches.

@ProviderFor(prefsStore)
final prefsStoreProvider = PrefsStoreProvider._();

/// The workbench preferences, opened alongside the settings for the same
/// reason: the first frame's tab menus already need the switches.

final class PrefsStoreProvider
    extends $FunctionalProvider<PrefsStore, PrefsStore, PrefsStore>
    with $Provider<PrefsStore> {
  /// The workbench preferences, opened alongside the settings for the same
  /// reason: the first frame's tab menus already need the switches.
  PrefsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'prefsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$prefsStoreHash();

  @$internal
  @override
  $ProviderElement<PrefsStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PrefsStore create(Ref ref) {
    return prefsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrefsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrefsStore>(value),
    );
  }
}

String _$prefsStoreHash() => r'583633426036aca3f81046f064f19d73a5e56a41';

/// The workbench preferences' current value, for the tree's read side. The
/// store stays the write path (atomic tmp+rename); this is the read seam so
/// a save anywhere rebuilds every reader in the same write.

@ProviderFor(workbenchPrefs)
final workbenchPrefsProvider = WorkbenchPrefsProvider._();

/// The workbench preferences' current value, for the tree's read side. The
/// store stays the write path (atomic tmp+rename); this is the read seam so
/// a save anywhere rebuilds every reader in the same write.

final class WorkbenchPrefsProvider
    extends $FunctionalProvider<WorkbenchPrefs, WorkbenchPrefs, WorkbenchPrefs>
    with $Provider<WorkbenchPrefs> {
  /// The workbench preferences' current value, for the tree's read side. The
  /// store stays the write path (atomic tmp+rename); this is the read seam so
  /// a save anywhere rebuilds every reader in the same write.
  WorkbenchPrefsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workbenchPrefsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workbenchPrefsHash();

  @$internal
  @override
  $ProviderElement<WorkbenchPrefs> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  WorkbenchPrefs create(Ref ref) {
    return workbenchPrefs(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkbenchPrefs value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkbenchPrefs>(value),
    );
  }
}

String _$workbenchPrefsHash() => r'4da5a752b757bb0f68c12d6233773bcee673a6f4';

/// The composition root (ADR-0002 stage 2): the runtime, the nine
/// controllers, and the runtime swap, now owned by the container instead of
/// `_DshAppState`. The widget tree reads it through
/// `ref.watch(appScopeProvider)`; nothing in the tree constructs it.
///
/// Lifetime: keepAlive, so the scope lives as long as the container — which
/// lives as long as `main`. Disposal order is delegated to [AppScope.dispose]
/// via `onDispose`; the container tears it down when `main` drops it, the
/// same moment `_DshAppState.dispose` used to.

@ProviderFor(appScope)
final appScopeProvider = AppScopeProvider._();

/// The composition root (ADR-0002 stage 2): the runtime, the nine
/// controllers, and the runtime swap, now owned by the container instead of
/// `_DshAppState`. The widget tree reads it through
/// `ref.watch(appScopeProvider)`; nothing in the tree constructs it.
///
/// Lifetime: keepAlive, so the scope lives as long as the container — which
/// lives as long as `main`. Disposal order is delegated to [AppScope.dispose]
/// via `onDispose`; the container tears it down when `main` drops it, the
/// same moment `_DshAppState.dispose` used to.

final class AppScopeProvider
    extends $FunctionalProvider<AppScope, AppScope, AppScope>
    with $Provider<AppScope> {
  /// The composition root (ADR-0002 stage 2): the runtime, the nine
  /// controllers, and the runtime swap, now owned by the container instead of
  /// `_DshAppState`. The widget tree reads it through
  /// `ref.watch(appScopeProvider)`; nothing in the tree constructs it.
  ///
  /// Lifetime: keepAlive, so the scope lives as long as the container — which
  /// lives as long as `main`. Disposal order is delegated to [AppScope.dispose]
  /// via `onDispose`; the container tears it down when `main` drops it, the
  /// same moment `_DshAppState.dispose` used to.
  AppScopeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appScopeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appScopeHash();

  @$internal
  @override
  $ProviderElement<AppScope> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppScope create(Ref ref) {
    return appScope(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppScope value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppScope>(value),
    );
  }
}

String _$appScopeHash() => r'a2c0b3eccbef5ce40ab1f33025e4c2c564737b11';
