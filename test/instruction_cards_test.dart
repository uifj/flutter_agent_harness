// ADR-0067 guards: cards persist, cap and clip; the injection block joins
// enabled cards; the enable-set survives a settings round-trip and never
// restarts the runtime.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/genkit/instructions.dart';
import 'package:planstar/model/app_settings.dart';
import 'package:planstar/model/instruction_card.dart';
import 'package:planstar/state/instruction_card_store.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('instruction_cards');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('store', () {
    test('add, reopen, update, remove', () {
      final store = InstructionCardStore.open(root)
        ..add('Concise', 'Answer in three sentences or fewer.')
        ..add('Comments', 'Write code comments in English.');
      expect(store.cards, hasLength(2));

      final reopened = InstructionCardStore.open(root);
      expect(reopened.cards.first.title, 'Concise');

      final id = reopened.cards.last.id;
      reopened.update(id, title: 'Comments 2', text: 'Rewritten.');
      expect(reopened.cardOf(id)!.title, 'Comments 2');
      reopened.remove(id);
      expect(reopened.cardOf(id), isNull);
    });

    test('cap and empty-body refusals', () {
      final store = InstructionCardStore.open(root);
      for (var i = 0; i < instructionCardCap; i++) {
        store.add('c$i', 'text $i');
      }
      store.add('over', 'text');
      expect(store.cards, hasLength(instructionCardCap));
      store.add('', 'body');
      store.add('t', '  ');
      expect(store.cards, hasLength(instructionCardCap));
    });
  });

  group('injection block', () {
    test('joins enabled texts with a blank line, clips long ones', () {
      final block = instructionCardsBlock(['First rule.', 'Second rule.']);
      expect(block, 'First rule.\n\nSecond rule.');
      final clipped = instructionCardsBlock([
        'x' * (instructionCardTextCap + 50),
      ]);
      expect(clipped, contains('…(truncated)'));
      expect(clipped!.length, lessThan(instructionCardTextCap + 100));
    });

    test('no usable cards means no block tail', () {
      expect(instructionCardsBlock(const []), isNull);
      expect(instructionCardsBlock(['   ']), isNull);
    });
  });

  group('renderInstructions carries the cards', () {
    test('enabled cards land inside the block tail', () {
      final block = renderInstructions(
        const [],
        cardTexts: ['Answer in three sentences or fewer.'],
      );
      expect(block, isNotNull);
      expect(block, contains('Answer in three sentences or fewer.'));
      expect(block, contains('Additional instructions from the user'));
      // Still one channel: the whole block, cards included, is injected.
      expect(isInjectedPart(block!), isTrue);
    });

    test('no cards leaves the block byte-identical to before', () {
      expect(renderInstructions(const []), isNull);
      expect(renderInstructions(const [], cardTexts: const []), isNull);
    });
  });

  group('enable set', () {
    test('round-trips and never restarts the runtime', () {
      final flipped = const AppSettings().copyWith(enabledCardIds: ['a', 'b']);
      expect(flipped.enabledCardIds, ['a', 'b']);
      final json = flipped.toJson();
      expect(json['enabledCardIds'], ['a', 'b']);
      expect(
        AppSettings.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        ),
        flipped,
      );
      expect(
        const AppSettings().toJson().containsKey('enabledCardIds'),
        isFalse,
      );
      expect(flipped.requiresRuntimeRestart(const AppSettings()), isFalse);
    });
  });
}
