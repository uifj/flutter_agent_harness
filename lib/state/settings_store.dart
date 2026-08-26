// Where the settings live between launches.
//
// A JSON file in Application Support, not the repository and not an asset: it
// holds an API key. On macOS that directory is inside the app's sandbox
// container, so it is already per-user and unreadable by other apps; the file
// mode is left alone because Dart has no `chmod` and shelling out for one would
// buy nothing inside the container.
//
// dsh keeps the equivalent in a settings document behind its own store
// (`ui-settings-models/src/client/store.ts` over the settings mirror). That
// machinery exists to merge contributions from ~50 packages; here there is one
// contributor and a handful of fields, so a file will do.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/app_settings.dart';

/// Holds the current [AppSettings] and writes every change through.
///
/// Notifies on save, which is what the app entry listens to in order to rebuild
/// the runtime — see `ModelSettings.requiresRestart`.
class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._file, this._value);

  /// Reads the stored settings from [root], falling back to the defaults.
  ///
  /// A corrupt or half-written file is treated as absent rather than thrown:
  /// losing a saved base URL is recoverable from the settings screen, while
  /// failing to launch is not.
  static Future<SettingsStore> open(Directory root) async {
    final file = File('${root.path}/$_fileName');
    var value = const AppSettings();
    try {
      if (file.existsSync()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          value = AppSettings.fromJson(decoded);
        }
      }
    } on FileSystemException {
      // Unreadable; carry on with the defaults.
    } on FormatException {
      // Not JSON; same.
    }
    return SettingsStore._(file, value);
  }

  static const _fileName = 'settings.json';

  final File _file;
  AppSettings _value;

  AppSettings get value => _value;

  /// Persists [next] and notifies. Returns once the bytes are on disk, so a
  /// caller may rebuild the runtime knowing the settings survived.
  ///
  /// Written to a sibling and renamed, so an interrupted save leaves the previous
  /// settings intact instead of a truncated file the next launch would discard.
  Future<void> save(AppSettings next) async {
    if (next == _value) return;
    _value = next;
    final temp = File('${_file.path}.tmp');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(jsonEncode(next.toJson()), flush: true);
    await temp.rename(_file.path);
    notifyListeners();
  }
}
