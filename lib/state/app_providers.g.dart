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
/// override, not the body, is the live path in production. The default
/// throws: opening a store needs a real directory, and there is no
/// meaningful default for "where do the app's documents live".

@ProviderFor(settingsStore)
final settingsStoreProvider = SettingsStoreProvider._();

/// The settings document. Opened before the first frame so the panel that
/// fixes a missing key can already be up, and so the workspace bookmark is
/// in hand before anything tries to read under the root.
///
/// Overridden in `main`'s container with the already-opened store — the
/// override, not the body, is the live path in production. The default
/// throws: opening a store needs a real directory, and there is no
/// meaningful default for "where do the app's documents live".

final class SettingsStoreProvider
    extends $FunctionalProvider<SettingsStore, SettingsStore, SettingsStore>
    with $Provider<SettingsStore> {
  /// The settings document. Opened before the first frame so the panel that
  /// fixes a missing key can already be up, and so the workspace bookmark is
  /// in hand before anything tries to read under the root.
  ///
  /// Overridden in `main`'s container with the already-opened store — the
  /// override, not the body, is the live path in production. The default
  /// throws: opening a store needs a real directory, and there is no
  /// meaningful default for "where do the app's documents live".
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

/// The settings document's current value. Theme, locale, workspace, model
/// fields — everything the tree renders straight out of the document.
///
/// `invalidateSelf`, NOT `notifyListeners`: on a functional provider
/// `notifyListeners` re-notifies the *cached* value without re-running the body,
/// so a store save never reaches readers — that was the theme/locale/workspace
/// not-updating regression. `invalidateSelf` re-runs the body (fresh `value`);
/// dependents rebuild only if it actually changed.

@ProviderFor(settingsDocument)
final settingsDocumentProvider = SettingsDocumentProvider._();

/// The settings document's current value. Theme, locale, workspace, model
/// fields — everything the tree renders straight out of the document.
///
/// `invalidateSelf`, NOT `notifyListeners`: on a functional provider
/// `notifyListeners` re-notifies the *cached* value without re-running the body,
/// so a store save never reaches readers — that was the theme/locale/workspace
/// not-updating regression. `invalidateSelf` re-runs the body (fresh `value`);
/// dependents rebuild only if it actually changed.

final class SettingsDocumentProvider
    extends $FunctionalProvider<AppSettings, AppSettings, AppSettings>
    with $Provider<AppSettings> {
  /// The settings document's current value. Theme, locale, workspace, model
  /// fields — everything the tree renders straight out of the document.
  ///
  /// `invalidateSelf`, NOT `notifyListeners`: on a functional provider
  /// `notifyListeners` re-notifies the *cached* value without re-running the body,
  /// so a store save never reaches readers — that was the theme/locale/workspace
  /// not-updating regression. `invalidateSelf` re-runs the body (fresh `value`);
  /// dependents rebuild only if it actually changed.
  SettingsDocumentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'settingsDocumentProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$settingsDocumentHash();

  @$internal
  @override
  $ProviderElement<AppSettings> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppSettings create(Ref ref) {
    return settingsDocument(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppSettings value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppSettings>(value),
    );
  }
}

String _$settingsDocumentHash() => r'6d830daa8b71a64caff549d0e5fdba89e29b9b3d';

/// The workbench preferences' current value. Same `invalidateSelf` reason as
/// [settingsDocument].

@ProviderFor(workbenchPrefs)
final workbenchPrefsProvider = WorkbenchPrefsProvider._();

/// The workbench preferences' current value. Same `invalidateSelf` reason as
/// [settingsDocument].

final class WorkbenchPrefsProvider
    extends $FunctionalProvider<WorkbenchPrefs, WorkbenchPrefs, WorkbenchPrefs>
    with $Provider<WorkbenchPrefs> {
  /// The workbench preferences' current value. Same `invalidateSelf` reason as
  /// [settingsDocument].
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

String _$workbenchPrefsHash() => r'f3c6344e70620ca42d5a0f9268276dcc1dd5a656';

@ProviderFor(conversation)
final conversationProvider = ConversationProvider._();

final class ConversationProvider
    extends
        $FunctionalProvider<
          ConversationController,
          ConversationController,
          ConversationController
        >
    with $Provider<ConversationController> {
  ConversationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationHash();

  @$internal
  @override
  $ProviderElement<ConversationController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConversationController create(Ref ref) {
    return conversation(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConversationController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConversationController>(value),
    );
  }
}

String _$conversationHash() => r'1166f76fc10f507832a88905157131f0474e8ef0';

/// The streaming tail: the high-frequency end of the transcript. Kept its
/// own provider — not a projection of [conversation] — because the streaming
/// split is the app's one performance contract: token deltas notify the tail
/// and nothing else (see `test/conversation_controller_test.dart`).

@ProviderFor(streamingTail)
final streamingTailProvider = StreamingTailProvider._();

/// The streaming tail: the high-frequency end of the transcript. Kept its
/// own provider — not a projection of [conversation] — because the streaming
/// split is the app's one performance contract: token deltas notify the tail
/// and nothing else (see `test/conversation_controller_test.dart`).

final class StreamingTailProvider
    extends $FunctionalProvider<StreamingTail, StreamingTail, StreamingTail>
    with $Provider<StreamingTail> {
  /// The streaming tail: the high-frequency end of the transcript. Kept its
  /// own provider — not a projection of [conversation] — because the streaming
  /// split is the app's one performance contract: token deltas notify the tail
  /// and nothing else (see `test/conversation_controller_test.dart`).
  StreamingTailProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'streamingTailProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$streamingTailHash();

  @$internal
  @override
  $ProviderElement<StreamingTail> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  StreamingTail create(Ref ref) {
    return streamingTail(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StreamingTail value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StreamingTail>(value),
    );
  }
}

String _$streamingTailHash() => r'5e1d1f2e8c3d201e4907890309bb05ceef44907d';

@ProviderFor(workbench)
final workbenchProvider = WorkbenchProvider._();

final class WorkbenchProvider
    extends
        $FunctionalProvider<
          WorkbenchController,
          WorkbenchController,
          WorkbenchController
        >
    with $Provider<WorkbenchController> {
  WorkbenchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workbenchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workbenchHash();

  @$internal
  @override
  $ProviderElement<WorkbenchController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkbenchController create(Ref ref) {
    return workbench(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkbenchController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkbenchController>(value),
    );
  }
}

String _$workbenchHash() => r'99ed79ce8faa1bbfd2487680d12dcec97811f9f4';

@ProviderFor(layout)
final layoutProvider = LayoutProvider._();

final class LayoutProvider
    extends
        $FunctionalProvider<
          LayoutController,
          LayoutController,
          LayoutController
        >
    with $Provider<LayoutController> {
  LayoutProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'layoutProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$layoutHash();

  @$internal
  @override
  $ProviderElement<LayoutController> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LayoutController create(Ref ref) {
    return layout(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LayoutController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LayoutController>(value),
    );
  }
}

String _$layoutHash() => r'64af33deb98ff587d9506880433b49e8ba64fa8e';

/// The terminal manager is host state, not a controller, but the same
/// projection applies: tabs watch it for session lifetime.

@ProviderFor(terminals)
final terminalsProvider = TerminalsProvider._();

/// The terminal manager is host state, not a controller, but the same
/// projection applies: tabs watch it for session lifetime.

final class TerminalsProvider
    extends
        $FunctionalProvider<TerminalManager, TerminalManager, TerminalManager>
    with $Provider<TerminalManager> {
  /// The terminal manager is host state, not a controller, but the same
  /// projection applies: tabs watch it for session lifetime.
  TerminalsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'terminalsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$terminalsHash();

  @$internal
  @override
  $ProviderElement<TerminalManager> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TerminalManager create(Ref ref) {
    return terminals(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TerminalManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TerminalManager>(value),
    );
  }
}

String _$terminalsHash() => r'3049d43f5665392cb91d3119f6c11a5d8841e184';

@ProviderFor(sideChat)
final sideChatProvider = SideChatProvider._();

final class SideChatProvider
    extends
        $FunctionalProvider<
          SideChatController,
          SideChatController,
          SideChatController
        >
    with $Provider<SideChatController> {
  SideChatProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sideChatProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sideChatHash();

  @$internal
  @override
  $ProviderElement<SideChatController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SideChatController create(Ref ref) {
    return sideChat(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SideChatController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SideChatController>(value),
    );
  }
}

String _$sideChatHash() => r'85673de5aaa8c65a57f8a6be4d629b638210fb7c';

@ProviderFor(modelDirectory)
final modelDirectoryProvider = ModelDirectoryProvider._();

final class ModelDirectoryProvider
    extends $FunctionalProvider<ModelDirectory, ModelDirectory, ModelDirectory>
    with $Provider<ModelDirectory> {
  ModelDirectoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'modelDirectoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$modelDirectoryHash();

  @$internal
  @override
  $ProviderElement<ModelDirectory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ModelDirectory create(Ref ref) {
    return modelDirectory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ModelDirectory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ModelDirectory>(value),
    );
  }
}

String _$modelDirectoryHash() => r'06a7e3129d56d62ede516f01f3e97b71f04f7163';

@ProviderFor(sessions)
final sessionsProvider = SessionsProvider._();

final class SessionsProvider
    extends $FunctionalProvider<SessionIndex, SessionIndex, SessionIndex>
    with $Provider<SessionIndex> {
  SessionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionsHash();

  @$internal
  @override
  $ProviderElement<SessionIndex> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionIndex create(Ref ref) {
    return sessions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionIndex value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionIndex>(value),
    );
  }
}

String _$sessionsHash() => r'a48d42d075a42010bf349726e2fc10e4d23249f3';

@ProviderFor(detailsSelection)
final detailsSelectionProvider = DetailsSelectionProvider._();

final class DetailsSelectionProvider
    extends
        $FunctionalProvider<
          DetailsSelection,
          DetailsSelection,
          DetailsSelection
        >
    with $Provider<DetailsSelection> {
  DetailsSelectionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'detailsSelectionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$detailsSelectionHash();

  @$internal
  @override
  $ProviderElement<DetailsSelection> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DetailsSelection create(Ref ref) {
    return detailsSelection(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DetailsSelection value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DetailsSelection>(value),
    );
  }
}

String _$detailsSelectionHash() => r'ceb363300cfc0ed37b3145876bc34eb14814d3cf';

@ProviderFor(workspaceMode)
final workspaceModeProvider = WorkspaceModeProvider._();

final class WorkspaceModeProvider
    extends
        $FunctionalProvider<
          WorkspaceModeController,
          WorkspaceModeController,
          WorkspaceModeController
        >
    with $Provider<WorkspaceModeController> {
  WorkspaceModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workspaceModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workspaceModeHash();

  @$internal
  @override
  $ProviderElement<WorkspaceModeController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  WorkspaceModeController create(Ref ref) {
    return workspaceMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(WorkspaceModeController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<WorkspaceModeController>(value),
    );
  }
}

String _$workspaceModeHash() => r'2e17f5e7553863c2043fd1b432ee7e2ed7ab4734';

/// The plan side's task list (ADR-0007 D4), the one record the board, the
/// calendar, and the table all project. Same bootstrap shape as the settings
/// store: `main` opens it before the first frame and overrides this provider —
/// the default throws because there is no meaningful default for "where do the
/// tasks live".

@ProviderFor(planTaskStore)
final planTaskStoreProvider = PlanTaskStoreProvider._();

/// The plan side's task list (ADR-0007 D4), the one record the board, the
/// calendar, and the table all project. Same bootstrap shape as the settings
/// store: `main` opens it before the first frame and overrides this provider —
/// the default throws because there is no meaningful default for "where do the
/// tasks live".

final class PlanTaskStoreProvider
    extends $FunctionalProvider<PlanTaskStore, PlanTaskStore, PlanTaskStore>
    with $Provider<PlanTaskStore> {
  /// The plan side's task list (ADR-0007 D4), the one record the board, the
  /// calendar, and the table all project. Same bootstrap shape as the settings
  /// store: `main` opens it before the first frame and overrides this provider —
  /// the default throws because there is no meaningful default for "where do the
  /// tasks live".
  PlanTaskStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planTaskStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planTaskStoreHash();

  @$internal
  @override
  $ProviderElement<PlanTaskStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PlanTaskStore create(Ref ref) {
    return planTaskStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlanTaskStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlanTaskStore>(value),
    );
  }
}

String _$planTaskStoreHash() => r'e5bf21593487422478a4d3379bd960134c61f420';

/// The identity source. The mock is the live path today; `main` overrides this
/// with a Supabase-backed repository when that lands (the seam is documented in
/// `host/profile_repository.dart`) — the only thing the rest of the app sees is
/// a different [userProfile] value.

@ProviderFor(profileRepository)
final profileRepositoryProvider = ProfileRepositoryProvider._();

/// The identity source. The mock is the live path today; `main` overrides this
/// with a Supabase-backed repository when that lands (the seam is documented in
/// `host/profile_repository.dart`) — the only thing the rest of the app sees is
/// a different [userProfile] value.

final class ProfileRepositoryProvider
    extends
        $FunctionalProvider<
          ProfileRepository,
          ProfileRepository,
          ProfileRepository
        >
    with $Provider<ProfileRepository> {
  /// The identity source. The mock is the live path today; `main` overrides this
  /// with a Supabase-backed repository when that lands (the seam is documented in
  /// `host/profile_repository.dart`) — the only thing the rest of the app sees is
  /// a different [userProfile] value.
  ProfileRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfileRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileRepository create(Ref ref) {
    return profileRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileRepository>(value),
    );
  }
}

String _$profileRepositoryHash() => r'fcdda6eff68dc66e22df50c50607e025181b80ee';

/// The current user's profile, or null while loading / when signed out — the
/// avatar then falls back to an anonymous placeholder.

@ProviderFor(userProfile)
final userProfileProvider = UserProfileProvider._();

/// The current user's profile, or null while loading / when signed out — the
/// avatar then falls back to an anonymous placeholder.

final class UserProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProfile?>,
          UserProfile?,
          FutureOr<UserProfile?>
        >
    with $FutureModifier<UserProfile?>, $FutureProvider<UserProfile?> {
  /// The current user's profile, or null while loading / when signed out — the
  /// avatar then falls back to an anonymous placeholder.
  UserProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userProfileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userProfileHash();

  @$internal
  @override
  $FutureProviderElement<UserProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<UserProfile?> create(Ref ref) {
    return userProfile(ref);
  }
}

String _$userProfileHash() => r'ab7440c762ee3eb4089008c4f31a9ae7b8cbf82d';
