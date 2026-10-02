// Secret storage (ADR-0045 PB): API keys live in the OS keychain, never in
// settings.json. The interface keeps the stores and tests free of the plugin;
// the secure implementation rides flutter_secure_storage — macOS Keychain,
// Windows DPAPI, Linux libsecret. This is the one deliberate deviation from
// ZCode's AES-GCM credentials file: that exists because Electron has no
// keychain story; Flutter does.

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key-value storage for small secrets. All methods are async by contract —
/// keychain calls cross a platform channel.
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// OS-keychain-backed [SecretStore].
class SecureSecretStore implements SecretStore {
  SecureSecretStore();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory [SecretStore] for tests and for hosts where the plugin channel
/// is absent: values live and die with the process, which is still better
/// than plaintext on disk.
class InMemorySecretStore implements SecretStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

/// Change-notifying wrapper so the settings screen can re-read a secret's
/// presence without polling.
class NotifyingSecretStore extends ChangeNotifier implements SecretStore {
  NotifyingSecretStore(this._inner);

  final SecretStore _inner;

  @override
  Future<String?> read(String key) => _inner.read(key);

  @override
  Future<void> write(String key, String value) async {
    await _inner.write(key, value);
    notifyListeners();
  }

  @override
  Future<void> delete(String key) async {
    await _inner.delete(key);
    notifyListeners();
  }
}
