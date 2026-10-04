// The instruction card store (ADR-0067): `<support>/instruction_cards.json`,
// the session sidecar's sync shape. Content lives here; which cards are
// enabled lives in AppSettings — content follows the person, preference
// follows the machine.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/instruction_card.dart';

class InstructionCardStore extends ChangeNotifier {
  InstructionCardStore._(this._file, List<InstructionCard> cards)
    : _cards = List.of(cards);

  static const fileName = 'instruction_cards.json';

  static InstructionCardStore open(Directory support) {
    final file = File('${support.path}/$fileName');
    final cards = <InstructionCard>[];
    try {
      if (file.existsSync()) {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is List) {
          for (final entry in decoded) {
            if (entry is! Map<String, dynamic>) continue;
            try {
              final card = InstructionCard.fromJson(entry);
              if (card.id.isNotEmpty && card.text.isNotEmpty) cards.add(card);
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
    return InstructionCardStore._(file, cards);
  }

  final File _file;
  final List<InstructionCard> _cards;

  List<InstructionCard> get cards => List.unmodifiable(_cards);

  bool get isFull => _cards.length >= instructionCardCap;

  InstructionCard? cardOf(String id) {
    for (final card in _cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  void add(String title, String text) {
    if (isFull) return;
    final trimmedTitle = title.trim();
    final body = text.trim();
    if (trimmedTitle.isEmpty || body.isEmpty) return;
    _cards.add(
      InstructionCard(
        id: DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
        title: trimmedTitle,
        text: body,
      ),
    );
    _persist();
    notifyListeners();
  }

  void update(String id, {required String title, required String text}) {
    final index = _cards.indexWhere((card) => card.id == id);
    if (index < 0) return;
    final trimmedTitle = title.trim();
    final body = text.trim();
    if (trimmedTitle.isEmpty || body.isEmpty) return;
    _cards[index] = InstructionCard(id: id, title: trimmedTitle, text: body);
    _persist();
    notifyListeners();
  }

  void remove(String id) {
    final before = _cards.length;
    _cards.removeWhere((card) => card.id == id);
    if (_cards.length == before) return;
    _persist();
    notifyListeners();
  }

  void _persist() {
    final temp = File('${_file.path}.tmp');
    try {
      temp.writeAsStringSync(
        const JsonEncoder.withIndent(
          '  ',
        ).convert([for (final card in _cards) card.toJson()]),
        flush: true,
      );
      temp.renameSync(_file.path);
    } on FileSystemException {
      // The in-memory list still answers; the next change retries.
    }
  }
}
