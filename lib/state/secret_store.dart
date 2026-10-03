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

  // The classic file keychain, not the data-protection one. `kSecUseData-
  // ProtectionKeychain` derives the app's access group from its code-signing
  // identity, and this project signs ad-hoc with no DEVELOPMENT_TEAM
  // (`build.md` §4), so every call through it fails -34018 ("A required
  // entitlement isn't present") — which took the whole app down at startup.
  // The classic keychain needs no identity; when signing lands this is the line
  // to revisit, not the callers.
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    mOptions: MacOsOptions(useDataProtectionKeyChain: false),
  );

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
