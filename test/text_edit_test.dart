// The edit tool's occurrence contract. Every refusal here is a message the model
// reads and acts on, so the messages are asserted as text: a refusal that does
// not say what to do next costs a turn.

import 'package:agent_harness/genkit/text_edit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applies', () {
    test('a unique occurrence', () {
      final outcome = applyLiteralEdit(
        source: 'a\nb\nc\n',
        oldString: 'b',
        newString: 'B',
      );

      expect(outcome.content, 'a\nB\nc\n');
      expect(outcome.replacements, 1);
    });

    test('every occurrence when asked, and reports how many', () {
      final outcome = applyLiteralEdit(
        source: 'x = 1; x = 2; x = 3;',
        oldString: 'x',
        newString: 'y',
        replaceAll: true,
      );

      expect(outcome.content, 'y = 1; y = 2; y = 3;');
      // The count is the point of reporting it: the model asked for all of them
      // without knowing what that meant.
      expect(outcome.replacements, 3);
    });

    test('literally — regex metacharacters are text', () {
      final outcome = applyLiteralEdit(
        source: r'if (a.*b) {}',
        oldString: 'a.*b',
        newString: 'ok',
      );

      expect(outcome.content, 'if (ok) {}');
    });

    test('an insertion, by keeping the anchor in the replacement', () {
      final outcome = applyLiteralEdit(
        source: 'one\nthree\n',
        oldString: 'three',
        newString: 'two\nthree',
      );

      expect(outcome.content, 'one\ntwo\nthree\n');
    });
  });

  group('refuses', () {
    /// The message of the refusal [body] throws, or a failure if it does not.
    String rejection(void Function() body) {
      try {
        body();
      } on EditRejected catch (error) {
        return error.message;
      }
      fail('the edit was accepted');
    }

    test('an empty old_string, pointing at write', () {
      final message = rejection(
        () => applyLiteralEdit(source: 'a', oldString: '', newString: 'b'),
      );

      expect(message, contains('write tool'));
    });

    test('an edit that changes nothing', () {
      final message = rejection(
        () => applyLiteralEdit(source: 'a', oldString: 'a', newString: 'a'),
      );

      expect(message, contains('identical'));
    });

    test('text that is not there, telling the model to read first', () {
      final message = rejection(
        () => applyLiteralEdit(source: 'a', oldString: 'zz', newString: 'b'),
      );

      expect(message, contains('not found'));
      expect(message, contains('indentation'));
    });

    test('an ambiguous target, with the count and both ways out', () {
      final message = rejection(
        () => applyLiteralEdit(
          source: 'x\nx\nx\n',
          oldString: 'x',
          newString: 'y',
        ),
      );

      // Three facts, because the model needs all three to fix it: how many, that
      // more context works, that replace_all works.
      expect(message, contains('3 times'));
      expect(message, contains('surrounding text'));
      expect(message, contains('replace_all'));
    });
  });

  group('counting', () {
    test('is non-overlapping, matching what replaceAll does', () {
      // 'aa' in 'aaaa' is two non-overlapping hits, not three overlapping ones —
      // counting the other way would report a number the replacement contradicts.
      expect(countOccurrences('aaaa', 'aa'), 2);
    });

    test('an empty needle is nothing, not everything', () {
      expect(countOccurrences('abc', ''), 0);
    });

    test('a needle that is not there', () {
      expect(countOccurrences('abc', 'd'), 0);
    });
  });
}
