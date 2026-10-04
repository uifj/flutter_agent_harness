// The environment store (ADR-0064): names in `<support>/environment.json`,
// values in the classic keychain under `environment:<name>`. The names file
// is not in the backup — the values are machine-bound secrets, and a name
// without its value is noise on another machine.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/environment.dart';
import 'secret_store.dart';

class EnvironmentStore extends ChangeNotifier {
  EnvironmentStore._(this._file, this._secrets, List<String> names)
    : _names = List.of(names);

  static const fileName = 'environment.json';
  static String secretKeyOf(String name) => 'environment:$name';

  static EnvironmentStore open(Directory support, SecretStore secrets) {
    final file = File('${support.path}/$fileName');
    final names = <String>[];
    try {
      if (file.existsSync()) {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is String && isValidEnvironmentName(entry)) {
              names.add(entry);
            }
          }
        }
      }
    } on FileSystemException {
      // Unreadable: start from nothing.
    } on FormatException {
      // Not JSON: same.
    }
    return EnvironmentStore._(file, secrets, names);
  }

  final File _file;
  final SecretStore _secrets;
  final List<String> _names;

  String? _error;

  /// Set when the last keychain write failed; the name was still recorded, so
  /// the next edit can rewrite the value (ADR-0049's "refusal must be known").
  String? get error => _error;

  List<String> get names => List.unmodifiable(_names);

  /// Loads every name's value from the keychain. A name whose read fails or
  /// returns null is omitted — an unset variable is not injected, which is
  /// what the name being there without a value means.
  Future<Map<String, String>> load() async {
    final values = <String, String>{};
    for (final name in _names) {
      try {
        final value = await _secrets.read(secretKeyOf(name));
        if (value != null && value.isNotEmpty) values[name] = value;
      } on Exception {
        // One unreadable value skips itself; the rest still inject.
      }
    }
    return values;
  }

  Future<void> add(String name, String value) async {
    final trimmed = name.trim();
    if (!isValidEnvironmentName(trimmed)) return;
    if (_names.contains(trimmed) || value.isEmpty) return;
    try {
      await _secrets.write(secretKeyOf(trimmed), value);
      _error = null;
      _names.add(trimmed);
      _persist();
      notifyListeners();
    } on Exception catch (error) {
      _error = error.toString();
      notifyListeners();
    }
  }

  Future<void> updateValue(String name, String value) async {
    if (!_names.contains(name) || value.isEmpty) return;
    try {
      await _secrets.write(secretKeyOf(name), value);
      _error = null;
      notifyListeners();
    } on Exception catch (error) {
      _error = error.toString();
      notifyListeners();
    }
  }

  Future<void> remove(String name) async {
    if (!_names.contains(name)) return;
    try {
      await _secrets.delete(secretKeyOf(name));
    } on Exception {
      // The name leaves the list even if the keychain slot resists: an
      // orphaned slot is invisible, a variable the user deleted coming back
      // is not.
    }
    _names.remove(name);
    _persist();
    notifyListeners();
  }

  void _persist() {
    final temp = File('${_file.path}.tmp');
    try {
      temp.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(_names),
        flush: true,
      );
      temp.renameSync(_file.path);
    } on FileSystemException {
      // The in-memory list still answers; the next change retries.
    }
  }
}
