// The head/tail arithmetic every block primitive's height cap runs on.
//
// One function, four consumers, and the numbers have to agree across them: a card
// that slices the head with one rule and reports `hidden` with another either
// drops a line silently or offers to expand rows it already shows. The slice
// helpers are here too, because Dart's `sublist` throws where the JavaScript
// `slice` this was ported from clamps — a difference that would surface as a crash
// on a short list rather than as a wrong number.

import 'package:agent_harness/ui/primitives/head_tail_cap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('headTailCap', () {
    test('a body within the cap is not capped', () {
      final cap = headTailCap(8, 16, false);
      expect(cap.capped, isFalse);
      expect(cap.hidden, -8);
    });

    test('an exact fit is not capped', () {
      // `hidden > 0`, not `>= 0`: at exactly the cap there is nothing to hide, and
      // a control offering to expand zero rows would still occupy a row.
      final cap = headTailCap(16, 16, false);
      expect(cap.capped, isFalse);
      expect(cap.hidden, 0);
    });

    test('an over-long body splits head-heavy on an odd cap', () {
      final cap = headTailCap(40, 9, false);
      expect(cap.capped, isTrue);
      expect(cap.hidden, 31);
      // ceil, so the odd row goes to the head: the start of a file or of a
      // command's output is what a reader orients by.
      expect(cap.headLines, 5);
      expect(cap.tailLines, 4);
      expect(cap.headLines + cap.tailLines, 9);
    });

    test('an even cap splits evenly', () {
      final cap = headTailCap(40, 16, false);
      expect(cap.headLines, 8);
      expect(cap.tailLines, 8);
    });

    test('expanded keeps hidden but stops capping', () {
      // The control's label reads off `hidden` in both directions, so expanding
      // must not zero it — only `capped` flips, which is what stops the slicing.
      final cap = headTailCap(40, 16, true);
      expect(cap.capped, isFalse);
      expect(cap.hidden, 24);
    });
  });

  group('slice helpers', () {
    test('take what is there when the list is shorter than the count', () {
      expect([1, 2].head(8), [1, 2]);
      expect([1, 2].tail(8), [1, 2]);
    });

    test('take from the right end', () {
      expect([1, 2, 3, 4].head(2), [1, 2]);
      expect([1, 2, 3, 4].tail(2), [3, 4]);
    });

    test('a non-positive count is nothing', () {
      expect([1, 2, 3].head(0), isEmpty);
      expect([1, 2, 3].tail(-1), isEmpty);
    });
  });
}
