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

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../model/app_settings.dart';
import '../model/app_settings_migration.dart';
import '../model/model_settings.dart';
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
          var movedIntoKeychain = true;
          if (secrets != null && legacyKey != null && legacyKey.isNotEmpty) {
            movedIntoKeychain = await _keychainAllows(
              () => secrets.write(AppSettings.apiKeySecretKey, legacyKey),
            );
            if (!movedIntoKeychain) {
              // Nothing moved, so the key stays exactly where the migration
              // found it. Cleaning the document here would delete the only copy.
              value = value.copyWithModelApiKey(legacyKey);
            }
          }
          // The on-disk document is re-written without the secret and with
          // the current schema version, whether or not a key moved — the
          // version stamp is what makes future migrations targeted. Except
          // when the move was refused: then the file keeps its key.
          if (movedIntoKeychain) {
            final cleaned = File('${file.path}.tmp');
            await cleaned.parent.create(recursive: true);
            await cleaned.writeAsString(
              jsonEncode(value.toJson()),
              flush: true,
            );
            await cleaned.rename(file.path);
          }
        }
      }
    } on FileSystemException {
      // Unreadable; carry on with the defaults.
    } on FormatException {
      await _quarantine(file);
    }
    if (secrets != null) {
      // A keychain this build cannot reach answers "nothing stored here", and
      // that answer must not be fatal: what the document itself carries stays
      // in force, and the next save will surface the refusal where the user
      // can act on it.
      try {
        final key = await secrets.read(AppSettings.apiKeySecretKey);
        if (key != null && key.isNotEmpty) {
          value = value.copyWithModelApiKey(key);
        }
        // The book's keys ride their own slots (ADR-0045 PF-2).
        final restored = <ModelSettings>[];
        for (final provider in value.savedProviders) {
          final id = provider.id;
          var entry = provider;
          if (id != null) {
            final bookKey = await secrets.read(
              AppSettings.providerSecretKey(id),
            );
            if (bookKey != null && bookKey.isNotEmpty) {
              entry = entry.copyWith(apiKey: bookKey);
            }
          }
          restored.add(entry);
        }
        value = value.copyWith(savedProviders: restored);
      } on Object {
        // Left as the document said it.
      }
    }
    return SettingsStore._(file, value, secrets);
  }

  static const _fileName = 'settings.json';

  /// Runs one keychain call and reports whether it answered.
  ///
  /// A refusal is a normal outcome, not a crash: what sits behind these calls
  /// is an access control keyed to the build's signing identity, so a user can
  /// be shown a permission prompt and decline it, and an unsigned build gets
  /// `-34018` on every call. The launch has to survive either way — this file's
  /// own rule is that a lost setting is recoverable while a dead app is not —
  /// but the caller must still learn *which* answer arrived, because the
  /// document may only be stripped of a plaintext key once that key has really
  /// moved.
  static Future<bool> _keychainAllows(Future<void> Function() call) async {
    try {
      await call();
      return true;
    } on Object {
      return false;
    }
  }

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
    // The saved-provider book: any entry whose key changed gets its own
    // keychain slot (ADR-0045 PF-2). Keys ride the entry's stable id.
    if (secrets != null) {
      final previousById = {
        for (final provider in _value.savedProviders)
          if (provider.id != null) provider.id!: provider,
      };
      for (final provider in next.savedProviders) {
        final id = provider.id;
        if (id == null) continue;
        final previous = previousById[id];
        final previousKey = previous?.apiKey ?? '';
        if (provider.apiKey == previousKey) continue;
        final slot = AppSettings.providerSecretKey(id);
        if (provider.apiKey.isEmpty) {
          await secrets.delete(slot);
        } else {
          await secrets.write(slot, provider.apiKey);
        }
      }
      for (final provider in previousById.values) {
        if (!next.savedProviders.any((entry) => entry.id == provider.id)) {
          await secrets.delete(AppSettings.providerSecretKey(provider.id!));
        }
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

  // ---- saved-provider book (ADR-0045 PF-2) ---------------------------------

  /// Saves the ACTIVE connection into the book (minting an id when the
  /// connection came from no entry), reusing the existing entry's id when the
  /// active connection IS a book entry. The key lands in the entry's own
  /// keychain slot; the active slot keeps working.
  Future<void> saveCurrentProviderToBook() async {
    final current = _value;
    // Reuse the referenced entry's id only when the connection IS that entry
    // (an update-in-place); an edited or brand-new connection mints a new id,
    // or saving a second provider would silently overwrite the first.
    final referenced = current.savedProviders
        .where((entry) => entry.id == current.activeProviderId)
        .firstOrNull;
    final sameAsReferenced =
        referenced != null &&
        referenced.copyWith(id: null) == current.model.copyWith(id: null);
    final id = sameAsReferenced
        ? referenced.id!
        : 'p${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    final model = current.model.copyWith(id: id);
    final secrets = _secrets;
    if (secrets != null && model.apiKey.isNotEmpty) {
      await secrets.write(AppSettings.providerSecretKey(id), model.apiKey);
    }
    final book = [...current.savedProviders]
      ..removeWhere((entry) => entry.id == id);
    book.add(model);
    await save(current.copyWith(savedProviders: book, activeProviderId: id));
  }

  /// Activates a saved entry: its connection becomes [AppSettings.model] and
  /// its key moves to the active keychain slot. The entry stays in the book,
  /// so a later re-activation needs no re-entry.
  Future<void> activateSavedProvider(String id) async {
    final entry = _value.savedProviders
        .where((provider) => provider.id == id)
        .firstOrNull;
    if (entry == null) return;
    final secrets = _secrets;
    var key = _value.model.apiKey;
    if (secrets != null) {
      final stored = await secrets.read(AppSettings.providerSecretKey(id));
      if (stored != null && stored.isNotEmpty) {
        key = stored;
        await secrets.write(AppSettings.apiKeySecretKey, stored);
      }
    }
    final activated = entry.copyWith(apiKey: key);
    await save(_value.copyWith(model: activated, activeProviderId: id));
  }

  /// Removes a saved entry and its keychain slot. Never removes the ACTIVE
  /// connection — callers delete from the book only.
  Future<void> deleteSavedProvider(String id) async {
    final secrets = _secrets;
    if (secrets != null) {
      await secrets.delete(AppSettings.providerSecretKey(id));
    }
    final book = [
      for (final provider in _value.savedProviders)
        if (provider.id != id) provider,
    ];
    await save(
      _value.copyWith(
        savedProviders: book,
        activeProviderId: _value.activeProviderId == id
            ? null
            : _value.activeProviderId,
      ),
    );
  }
}
