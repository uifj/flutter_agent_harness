// Where the settings live between launches.
//
// A JSON file in Application Support, not the repository and not an asset.
// Since ADR-0045 PB the file holds NO secret: the API key persists through a
// [SecretStore] (OS keychain) and rides in memory on [AppSettings] so every
// existing reader stays synchronous. A legacy file that still carries a
// plaintext key is migrated once on open — key to the secret store, field
// stripped from the file on the next save.
//
// A file that fails to parse is quarantined as `settings.json.corrupt-<ts>`
// and the app starts from defaults — the same answer ZCode's setting service
// gives (`settingService.ts:67-94`): silently pretending the user never
// configured anything is data loss; keeping the bytes keeps it recoverable.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/app_settings.dart';
import '../model/app_settings_migration.dart';
import 'secret_store.dart';

/// Holds the current [AppSettings] and writes every change through.
///
/// Notifies on save, which is what the app entry listens to in order to rebuild
/// the runtime — see `ModelSettings.requiresRestart`.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._file, this._value, this._secrets);

  /// Reads the stored settings from [root], falling back to the defaults.
  ///
  /// A corrupt or half-written file is quarantined and the defaults take over:
  /// losing a saved base URL is recoverable from the settings screen, while
  /// failing to launch is not. A legacy file whose model section still
  /// carries a plaintext API key has the key moved into [secrets] and the
  /// cleaned document written straight back.
  static Future<SettingsStore> open(
    Directory root, {
    SecretStore? secrets,
    DateTime Function()? now,
  }) async {
    final file = File('${root.path}/$_fileName');
    var value = const AppSettings();
    try {
      if (file.existsSync()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          final migrated = AppSettingsMigration.apply(decoded);
          value = AppSettings.fromJson(migrated.json);
          final legacyKey = migrated.legacyApiKey;
          if (secrets != null && legacyKey != null && legacyKey.isNotEmpty) {
            await secrets.write(AppSettings.apiKeySecretKey, legacyKey);
          }
          // The on-disk document is re-written without the secret and with
          // the current schema version, whether or not a key moved — the
          // version stamp is what makes future migrations targeted.
          final cleaned = File('${file.path}.tmp');
          await cleaned.parent.create(recursive: true);
          await cleaned.writeAsString(jsonEncode(value.toJson()), flush: true);
          await cleaned.rename(file.path);
        }
      }
    } on FileSystemException {
      // Unreadable; carry on with the defaults.
    } on FormatException {
      await _quarantine(file);
    }
    if (secrets != null) {
      final key = await secrets.read(AppSettings.apiKeySecretKey);
      if (key != null && key.isNotEmpty) {
        value = value.copyWithModelApiKey(key);
      }
    }
    return SettingsStore._(file, value, secrets);
  }

  static const _fileName = 'settings.json';

  static Future<void> _quarantine(File file) async {
    try {
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await file.rename('${file.path}.corrupt-$stamp');
    } on FileSystemException {
      // The quarantine copy matters more than the rename: if renaming fails
      // the corrupt bytes stay in place and the defaults take over anyway.
    }
  }

  final File _file;
  final SecretStore? _secrets;
  AppSettings _value;

  AppSettings get value => _value;

  /// Persists [next] and notifies. Returns once the bytes are on disk, so a
  /// caller may rebuild the runtime knowing the settings survived.
  ///
  /// The API key is routed to the secret store and the on-disk document is
  /// written WITHOUT it — a file that only ever held preferences stays a file
  /// that can be backed up without exfiltrating credentials.
  Future<void> save(AppSettings next) async {
    if (next == _value) return;
    final previousKey = _value.model.apiKey;
    final nextKey = next.model.apiKey;
    final secrets = _secrets;
    if (secrets != null && nextKey != previousKey) {
      if (nextKey.isEmpty) {
        await secrets.delete(AppSettings.apiKeySecretKey);
      } else {
        await secrets.write(AppSettings.apiKeySecretKey, nextKey);
      }
    }
    _value = next;
    final temp = File('${_file.path}.tmp');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(
      jsonEncode(next.toJsonWithoutSecrets()),
      flush: true,
    );
    await temp.rename(_file.path);
    notifyListeners();
  }

  /// Resets settings to the defaults: the current file is quarantined (the
  /// user's bytes are recoverable), the secret store loses the API key, and
  /// the defaults take over. Used by the settings screen's reset entry —
  /// behind a confirm dialog, never automatically.
  Future<void> resetToDefaults() async {
    if (_file.existsSync()) {
      await _quarantine(_file);
    }
    final secrets = _secrets;
    if (secrets != null) {
      await secrets.delete(AppSettings.apiKeySecretKey);
    }
    _value = const AppSettings();
    final temp = File('${_file.path}.tmp');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(
      jsonEncode(_value.toJsonWithoutSecrets()),
      flush: true,
    );
    await temp.rename(_file.path);
    notifyListeners();
  }
}
