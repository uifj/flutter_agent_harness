// The quick phrase store (ADR-0063): `<support>/quick_phrases.json`, a list
// with synchronous tmp+rename writes — the session sidecar's shape. A
// corrupt file is an empty library: phrases are content the user can retype,
// not state the app depends on.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/quick_phrase.dart';

class QuickPhraseStore extends ChangeNotifier {
  QuickPhraseStore._(this._file, List<QuickPhrase> phrases)
    : _phrases = List.of(phrases);

  static const fileName = 'quick_phrases.json';

  static QuickPhraseStore open(Directory support) {
    final file = File('${support.path}/$fileName');
    final phrases = <QuickPhrase>[];
    try {
      if (file.existsSync()) {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is! Map<String, dynamic>) continue;
            try {
              final phrase = QuickPhrase.fromJson(entry);
              // A phrase with no text inserts nothing; dropping it here
              // keeps the menu honest.
              if (phrase.id.isNotEmpty && phrase.text.isNotEmpty) {
                phrases.add(phrase);
              }
            } on FormatException {
              // One unreadable row drops; the rest still count.
            }
          }
        }
      }
    } on FileSystemException {
      // Unreadable: start from nothing.
    } on FormatException {
      // Not JSON: same.
    }
    return QuickPhraseStore._(file, phrases);
  }

  final File _file;
  final List<QuickPhrase> _phrases;

  /// The phrases, in menu order.
  List<QuickPhrase> get phrases => List.unmodifiable(_phrases);

  bool get isFull => _phrases.length >= quickPhraseCap;

  QuickPhrase phraseOf(String id) => _phrases.firstWhere(
    (phrase) => phrase.id == id,
    orElse: () => const QuickPhrase(id: '', title: '', text: ''),
  );

  void add(String title, String text) {
    if (isFull) return;
    final trimmed = title.trim();
    final body = text.trim();
    if (trimmed.isEmpty || body.isEmpty) return;
    _phrases.add(
      QuickPhrase(
        id: DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        title: trimmed,
        text: body,
      ),
    );
    _persist();
    notifyListeners();
  }

  void update(String id, {required String title, required String text}) {
    final index = _phrases.indexWhere((phrase) => phrase.id == id);
    if (index < 0) return;
    final trimmed = title.trim();
    final body = text.trim();
    if (trimmed.isEmpty || body.isEmpty) return;
    _phrases[index] = _phrases[index].copyWith(title: trimmed, text: body);
    _persist();
    notifyListeners();
  }

  void remove(String id) {
    final before = _phrases.length;
    _phrases.removeWhere((phrase) => phrase.id == id);
    if (_phrases.length == before) return;
    _persist();
    notifyListeners();
  }

  void _persist() {
    final temp = File('${_file.path}.tmp');
    try {
      temp.writeAsStringSync(
        const JsonEncoder.withIndent(
          '  ',
        ).convert([for (final phrase in _phrases) phrase.toJson()]),
        flush: true,
      );
      temp.renameSync(_file.path);
    } on FileSystemException {
      // The in-memory list still answers; the next change retries.
    }
  }
}
