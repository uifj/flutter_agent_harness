// ADR-0045 PB guards: the settings file never carries the API key again, a
// corrupt file is quarantined (the user's bytes recoverable) instead of
// silently reset, the v1→v2 migration moves a legacy plaintext key into the
// secret store, and the reset entry starts from defaults while keeping a
// recoverable copy.

import 'dart:convert';
import 'dart:io';

import 'package:agent_harness/model/app_settings.dart';
import 'package:agent_harness/model/app_settings_migration.dart';
import 'package:agent_harness/state/prefs_store.dart';
import 'package:agent_harness/state/secret_store.dart';
import 'package:agent_harness/state/settings_store.dart';
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
      expect(onDisk['schemaVersion'], 2);
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

  group('AppSettingsMigration', () {
    test('v1→v2 extracts the key and stamps the version', () {
      final result = AppSettingsMigration.apply({
        'model': {'apiKey': 'sk-x'},
      });
      expect(result.legacyApiKey, 'sk-x');
      expect(result.json['schemaVersion'], 2);
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
      expect(result.json['schemaVersion'], 2);
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
}
