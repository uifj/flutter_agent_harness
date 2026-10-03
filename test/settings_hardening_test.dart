// ADR-0045 PB guards: the settings file never carries the API key again, a
// corrupt file is quarantined (the user's bytes recoverable) instead of
// silently reset, the v1→v2 migration moves a legacy plaintext key into the
// secret store, and the reset entry starts from defaults while keeping a
// recoverable copy.

import 'dart:convert';
import 'dart:io';

import 'package:planstar/model/app_settings.dart';
import 'package:planstar/model/model_settings.dart';
import 'package:planstar/model/app_settings_migration.dart';
import 'package:planstar/state/prefs_store.dart';
import 'package:planstar/state/secret_store.dart';
import 'package:planstar/state/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late InMemorySecretStore secrets;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('settings_hardening');
    secrets = InMemorySecretStore();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  File settingsFile() => File('${root.path}/settings.json');
  File prefsFile() => File('${root.path}/prefs.json');

  test(
    'a saved document carries the schema version and never the key',
    () async {
      final store = await SettingsStore.open(root, secrets: secrets);
      await store.save(store.value.copyWithModelApiKey('sk-test-123'));
      final onDisk =
          jsonDecode(settingsFile().readAsStringSync()) as Map<String, dynamic>;
      expect(onDisk['schemaVersion'], AppSettings.schemaVersion);
      final model = onDisk['model'] as Map<String, dynamic>;
      expect(model['apiKey'], '');
      // The key reached the secret store, and the in-memory readers keep it.
      expect(await secrets.read(AppSettings.apiKeySecretKey), 'sk-test-123');
      expect(store.value.model.apiKey, 'sk-test-123');
    },
  );

  test('reopening restores the key from the secret store', () async {
    final first = await SettingsStore.open(root, secrets: secrets);
    await first.save(first.value.copyWithModelApiKey('sk-round-trip'));
    final second = await SettingsStore.open(root, secrets: secrets);
    expect(second.value.model.apiKey, 'sk-round-trip');
  });

  test(
    'clearing the key in settings removes it from the secret store',
    () async {
      final store = await SettingsStore.open(root, secrets: secrets);
      await store.save(store.value.copyWithModelApiKey('sk-gone'));
      await store.save(store.value.copyWithModelApiKey(''));
      expect(await secrets.read(AppSettings.apiKeySecretKey), isNull);
    },
  );

  test(
    'a legacy v1 document migrates: key to the store, file cleaned',
    () async {
      settingsFile().writeAsStringSync(
        jsonEncode({
          'model': {
            'provider': 'openai-compatible',
            'apiKey': 'sk-legacy-plain',
            'baseUrl': 'https://api.deepseek.com/v1',
          },
        }),
      );
      final store = await SettingsStore.open(root, secrets: secrets);
      expect(store.value.model.apiKey, 'sk-legacy-plain');
      expect(
        await secrets.read(AppSettings.apiKeySecretKey),
        'sk-legacy-plain',
      );
      final onDisk =
          jsonDecode(settingsFile().readAsStringSync()) as Map<String, dynamic>;
      expect((onDisk['model'] as Map<String, dynamic>)['apiKey'], '');
      expect(onDisk['schemaVersion'], 3);
    },
  );

  test('a corrupt settings file is quarantined, not deleted', () async {
    settingsFile().writeAsStringSync('{not json at all');
    final store = await SettingsStore.open(root, secrets: secrets);
    expect(store.value, const AppSettings());
    final quarantined = root
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('.corrupt-'))
        .toList();
    expect(quarantined, hasLength(1));
    expect(quarantined.single.readAsStringSync(), '{not json at all');
  });

  test(
    'resetToDefaults quarantines the current file and clears the key',
    () async {
      final store = await SettingsStore.open(root, secrets: secrets);
      await store.save(store.value.copyWithModelApiKey('sk-reset'));
      await store.save(store.value.copyWith(workspaceRoot: '/some/workspace'));
      await store.resetToDefaults();

      expect(store.value.workspaceRoot, isNull);
      expect(store.value.model.apiKey, '');
      expect(await secrets.read(AppSettings.apiKeySecretKey), isNull);
      final quarantined = root
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('settings.json.corrupt-'))
          .toList();
      expect(quarantined, hasLength(1));
      final kept =
          jsonDecode(quarantined.single.readAsStringSync())
              as Map<String, dynamic>;
      expect(kept['workspaceRoot'], '/some/workspace');
    },
  );

  test('prefs quarantine mirrors settings: corrupt bytes kept', () async {
    prefsFile().writeAsStringSync('{{{');
    final store = await PrefsStore.open(root);
    expect(store.value.terminalFontSize, isNotNull); // defaults took over
    expect(
      root.listSync().whereType<File>().where(
        (file) => file.path.contains('prefs.json.corrupt-'),
      ),
      hasLength(1),
    );
  });

  group('saved-provider book (PF-2)', () {
    test(
      'saveCurrentProviderToBook mints an id and copies the key to its slot',
      () async {
        final store = await SettingsStore.open(root, secrets: secrets);
        await store.save(store.value.copyWithModelApiKey('sk-book'));
        await store.saveCurrentProviderToBook();
        expect(store.value.savedProviders, hasLength(1));
        final entry = store.value.savedProviders.single;
        expect(entry.id, isNotNull);
        expect(store.value.activeProviderId, entry.id);
        expect(
          await secrets.read(AppSettings.providerSecretKey(entry.id!)),
          'sk-book',
        );
        // The active slot still answers.
        expect(store.value.model.apiKey, 'sk-book');
      },
    );

    test('activate swaps the connection and the active key', () async {
      final store = await SettingsStore.open(root, secrets: secrets);
      await store.save(store.value.copyWithModelApiKey('sk-first'));
      await store.saveCurrentProviderToBook();
      final firstId = store.value.activeProviderId!;

      // A second connection replaces the active one and is saved too.
      await store.save(
        store.value.copyWith(
          model: const ModelSettings(
            provider: LlmProvider.anthropic,
            apiKey: 'sk-second',
            baseUrl: '',
            model: 'claude-sonnet-4-5',
          ),
        ),
      );
      await store.saveCurrentProviderToBook();
      expect(store.value.savedProviders, hasLength(2));

      // Back to the first: the anthropic key leaves the active slot, the
      // first entry's key arrives from its own slot.
      await store.activateSavedProvider(firstId);
      expect(store.value.model.provider, LlmProvider.openai);
      expect(store.value.model.apiKey, 'sk-first');
      expect(await secrets.read(AppSettings.apiKeySecretKey), 'sk-first');
    });

    test('delete removes the entry and its key slot', () async {
      final store = await SettingsStore.open(root, secrets: secrets);
      await store.save(store.value.copyWithModelApiKey('sk-del'));
      await store.saveCurrentProviderToBook();
      final id = store.value.activeProviderId!;
      await store.deleteSavedProvider(id);
      expect(store.value.savedProviders, isEmpty);
      expect(await secrets.read(AppSettings.providerSecretKey(id)), isNull);
    });

    test(
      'the book survives a reopen: keys from slots, file stays clean',
      () async {
        final store = await SettingsStore.open(root, secrets: secrets);
        await store.save(store.value.copyWithModelApiKey('sk-rt'));
        await store.saveCurrentProviderToBook();
        // The on-disk document carries no keys anywhere.
        final onDisk =
            jsonDecode(settingsFile().readAsStringSync())
                as Map<String, dynamic>;
        final diskBook = onDisk['savedProviders'] as List;
        expect((diskBook.single as Map)['apiKey'], '');
        // Reopen restores the book entry's key from its slot.
        final reopened = await SettingsStore.open(root, secrets: secrets);
        expect(reopened.value.savedProviders, hasLength(1));
        expect(reopened.value.savedProviders.single.apiKey, 'sk-rt');
      },
    );
  });

  group('AppSettingsMigration', () {
    test('v1→v2 extracts the key and stamps the version', () {
      final result = AppSettingsMigration.apply({
        'model': {'apiKey': 'sk-x'},
      });
      expect(result.legacyApiKey, 'sk-x');
      expect(result.json['schemaVersion'], 3);
      expect((result.json['model'] as Map)['apiKey'], '');
    });

    test('a version-2 document passes through untouched', () {
      final document = {
        'schemaVersion': 2,
        'model': {'apiKey': ''},
      };
      final result = AppSettingsMigration.apply(document);
      expect(result.legacyApiKey, isNull);
      expect(identical(result.json, document), isFalse);
      expect(result.json['schemaVersion'], 3);
    });

    test('v2→v3 seeds the book from a configured active connection', () {
      final result = AppSettingsMigration.apply({
        'schemaVersion': 2,
        'model': {
          'provider': 'openai',
          'apiKey': 'sk-live',
          'baseUrl': 'https://api.deepseek.com/v1',
          'model': 'deepseek-chat',
        },
      });
      expect(result.json['schemaVersion'], 3);
      final book = result.json['savedProviders'] as List;
      expect(book, hasLength(1));
      expect((book.single as Map)['id'], 'p1');
      expect(result.json['activeProviderId'], 'p1');
      // The key stays under the active slot; no secret moved into the doc.
      expect((book.single as Map)['apiKey'], 'sk-live');
    });

    test('v2→v3 leaves an unconfigured document with an empty book', () {
      final result = AppSettingsMigration.apply({
        'schemaVersion': 2,
        'model': {'apiKey': ''},
      });
      expect(result.json['schemaVersion'], 3);
      expect(result.json['savedProviders'], isNull);
    });

    test('a newer document is not downgraded', () {
      final result = AppSettingsMigration.apply({
        'schemaVersion': 99,
        'model': {'apiKey': 'sk-future'},
      });
      expect(result.legacyApiKey, isNull);
      expect(result.json['schemaVersion'], 99);
    });
  });
  // ADR-0049: the keychain is an outside service, and outside services say no.
  // Two of its answers used to be fatal — a refused write was followed
  // unconditionally by the cleaned rewrite (which would have deleted the only
  // copy of the key), and the read-back at open sat outside every catch.
  group('a keychain that refuses', () {
    test('keeps the legacy key in the document and still opens', () async {
      settingsFile().writeAsStringSync(
        jsonEncode({
          'model': {'apiKey': 'sk-refused', 'provider': 'openai'},
        }),
      );
      final store = await SettingsStore.open(
        root,
        secrets: _RefusingSecretStore(),
      );
      expect(store.value.model.apiKey, 'sk-refused');
      final onDisk =
          jsonDecode(settingsFile().readAsStringSync()) as Map<String, dynamic>;
      expect(
        (onDisk['model'] as Map)['apiKey'],
        'sk-refused',
        reason:
            'nothing moved into the keychain, so nothing may be cleaned '
            'out of the file — the copy the app has is the copy it keeps',
      );
    });

    test('opens a current document whose read-back throws', () async {
      final good = InMemorySecretStore();
      final first = await SettingsStore.open(root, secrets: good);
      await first.save(first.value.copyWithModelApiKey('sk-in-keychain'));
      // The same document against a store that now refuses everything: the
      // key is unreachable, not gone, and the rest of the settings still load.
      final second = await SettingsStore.open(
        root,
        secrets: _RefusingSecretStore(),
      );
      expect(second.value.model.apiKey, '');
      expect(second.value.workspaceRoot, first.value.workspaceRoot);
    });
  });

  test('the macOS seam names the keychain an unsigned build can reach', () {
    final source = File('lib/state/secret_store.dart').readAsStringSync();
    expect(
      source,
      contains('useDataProtectionKeyChain: false'),
      reason:
          'the data-protection keychain derives its access group from the '
          'code-signing identity, and this project signs ad-hoc with no '
          'DEVELOPMENT_TEAM (build.md §4) — the plugin default made every call '
          'fail -34018 and took the app down at startup.',
    );
  });
}

/// A [SecretStore] that refuses every call the way a declined keychain prompt
/// does — with a platform error, not a null.
class _RefusingSecretStore implements SecretStore {
  @override
  Future<String?> read(String key) async => throw StateError('-34018');

  @override
  Future<void> write(String key, String value) async =>
      throw StateError('-34018');

  @override
  Future<void> delete(String key) async => throw StateError('-34018');
}
