// Where the workbench preferences live between launches.
//
// `<support>/prefs.json`, separate from `settings.json` on purpose — the two
// documents differ in what a save costs. Settings may rebuild the agent;
// prefs are layout-class (a font, a switch) and apply live. Keeping the files
// apart is what keeps the prefs out of the runtime-restart channel without any
// per-field filtering logic.
//
// The shape mirrors `SettingsStore` — atomic write, notify on change, corrupt
// reads as absent — because both are "one document, one file, one writer" and
// the reasoning is the same in both.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/workbench_prefs.dart';

/// Holds the current [WorkbenchPrefs] and writes every change through.
class PrefsStore extends ChangeNotifier {
  PrefsStore._(this._file, this._value);

  /// Reads the stored prefs from [root], falling back to the defaults.
  static Future<PrefsStore> open(Directory root) async {
    final file = File('${root.path}/$_fileName');
    var value = const WorkbenchPrefs();
    try {
      if (file.existsSync()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          value = WorkbenchPrefs.fromJson(decoded);
        }
      }
    } on FileSystemException {
      // Unreadable; carry on with the defaults.
    } on FormatException {
      // Not JSON; same.
    }
    return PrefsStore._(file, value);
  }

  static const _fileName = 'prefs.json';

  final File _file;
  WorkbenchPrefs _value;

  WorkbenchPrefs get value => _value;

  /// Persists [next] and notifies. Same sibling-and-rename discipline as
  /// `SettingsStore.save`.
  Future<void> save(WorkbenchPrefs next) async {
    if (next == _value) return;
    _value = next;
    final temp = File('${_file.path}.tmp');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(jsonEncode(next.toJson()), flush: true);
    await temp.rename(_file.path);
    notifyListeners();
  }
}
