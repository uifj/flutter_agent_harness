// ADR-0064 guards: names are injectable identifiers, redaction protects the
// values that flow back to the model, and the store keeps names on disk with
// values in the keychain.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/model/environment.dart';
import 'package:planstar/state/environment_store.dart';
import 'package:planstar/state/secret_store.dart';

/// In-memory keychain — the same shape the hardening tests use.
class _MemorySecretStore implements SecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  late Directory root;
  late _MemorySecretStore secrets;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('environment');
    secrets = _MemorySecretStore();
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  EnvironmentStore store() => EnvironmentStore.open(root, secrets);

  group('names', () {
    test('accept identifiers only', () {
      expect(isValidEnvironmentName('API_TOKEN'), isTrue);
      expect(isValidEnvironmentName('_private'), isTrue);
      expect(isValidEnvironmentName('9START'), isFalse);
      expect(isValidEnvironmentName('has-dash'), isFalse);
      expect(isValidEnvironmentName('has space'), isFalse);
      expect(isValidEnvironmentName(''), isFalse);
    });
  });

  group('redaction', () {
    test('replaces values in output', () {
      expect(
        redactToolOutput('token is sk-abcdef123456', const ['sk-abcdef123456']),
        'token is [REDACTED]',
      );
    });

    test('longest value wins when values overlap', () {
      expect(
        redactToolOutput('a sk-short and sk-extended-long here', const [
          'sk-short',
          'sk-extended-long',
        ]),
        contains('[REDACTED]'),
      );
      expect(redactToolOutput('x', const ['sk-extended-long']).length, 1);
    });

    test('short values are skipped, not matched', () {
      // 'abc' would match inside half the English language; the bound keeps
      // the output readable instead of redacting the world.
      expect(
        redactToolOutput('abc and abc', const ['ab', 'abc']),
        'abc and abc',
      );
    });

    test('no secrets, no change', () {
      expect(redactToolOutput('plain output', const []), 'plain output');
    });
  });

  group('store', () {
    test('add persists the name and the keychain value', () async {
      final library = store();
      await library.add('API_TOKEN', 'sk-value-123');
      expect(library.names, ['API_TOKEN']);
      expect(secrets.values['environment:API_TOKEN'], 'sk-value-123');

      final reopened = EnvironmentStore.open(root, secrets);
      final loaded = await reopened.load();
      expect(loaded, {'API_TOKEN': 'sk-value-123'});
    });

    test('invalid names and empty values are refused', () async {
      final library = store();
      await library.add('has-dash', 'value-1');
      await library.add('GOOD', '');
      expect(library.names, isEmpty);
    });

    test('remove takes the name and the keychain slot with it', () async {
      final library = store();
      await library.add('TOKEN', 'value-for-TOKEN');
      await library.remove('TOKEN');
      expect(library.names, isEmpty);
      expect(secrets.values.containsKey('environment:TOKEN'), isFalse);
    });
  });
}
