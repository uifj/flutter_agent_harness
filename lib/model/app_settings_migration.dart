// The settings document's versioned migration table (ADR-0045 PB), the shape
// ZCode keeps as field-level functions (`migrateLegacyLocalePreference:227`
// & co): a document declares (or implies) its version, each migration is one
// named function, and the chain runs until the document reaches
// [AppSettings.schemaVersion]. Side effects (the v1→v2 secret extraction) come
// back as named results, never as hidden IO inside a "pure" migration.

import 'app_settings.dart';

/// The result of running the chain: the cleaned document plus whatever a
/// migration dug out for a caller with hands (the plaintext API key moves to
/// the secret store, not into this map).
class AppSettingsMigrationResult {
  const AppSettingsMigrationResult({required this.json, this.legacyApiKey});

  final Map<String, dynamic> json;
  final String? legacyApiKey;
}

abstract final class AppSettingsMigration {
  /// v1 documents carried no `schemaVersion`; the current writer stamps 2.
  static const int _latest = AppSettings.schemaVersion;

  /// Runs every migration between the document's version and [_latest] in
  /// order. Unknown (newer) documents pass through untouched — a newer app
  /// writing older fields is the compatibility rule, not a parse error.
  static AppSettingsMigrationResult apply(Map<String, dynamic> json) {
    var version = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    var working = Map<String, dynamic>.of(json);
    String? legacyApiKey;
    if (version < 2 && version < _latest) {
      final result = _v1ToV2(working);
      working = result.json;
      legacyApiKey = result.legacyApiKey;
      version = 2;
    }
    return AppSettingsMigrationResult(
      json: working,
      legacyApiKey: legacyApiKey,
    );
  }

  /// v1 → v2: the API key leaves the document for the secret store. The key
  /// is removed from the map (the in-memory copy receives it through
  /// `SettingsStore.open`) and handed back as [AppSettingsMigrationResult].
  static AppSettingsMigrationResult _v1ToV2(Map<String, dynamic> json) {
    final working = Map<String, dynamic>.of(json);
    var legacyKey = '';
    final model = working['model'];
    if (model is Map<String, dynamic>) {
      final key = model['apiKey'];
      if (key is String && key.isNotEmpty) {
        legacyKey = key;
        working['model'] = Map<String, dynamic>.of(model)..['apiKey'] = '';
      }
    }
    working['schemaVersion'] = 2;
    return AppSettingsMigrationResult(json: working, legacyApiKey: legacyKey);
  }
}
