// The hero's greeting is a lookup that must never be wrong about the clock.
//
// Ported from `ConversationDraftEmptyState.tsx:29-35` with its boundary list
// (`:14`). The risk in a six-bucket day is not the wording, it is the seams: a
// hour nobody claims (the hero shows the wrong sentence for ten minutes) or one
// two buckets want (the sentence flips twice at 12:00). So this walks all 24
// hours and the boundaries themselves, and pins the timer the reference sets so
// a page left open across a boundary changes its own greeting rather than
// ageing badly (`:38-52, :91-99`).

import 'package:agent_harness/model/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every hour of the day lands in exactly one bucket', () {
    // The bucket list is the reference's, hour by hour: 5-8 早, 9-11 上午,
    // 12-13 中午, 14-17 下午, 18-22 晚上, and 23-4 深夜 wrapping the midnight.
    const expected = {
      0: Greeting.lateNight,
      1: Greeting.lateNight,
      2: Greeting.lateNight,
      3: Greeting.lateNight,
      4: Greeting.lateNight,
      5: Greeting.morningEarly,
      6: Greeting.morningEarly,
      7: Greeting.morningEarly,
      8: Greeting.morningEarly,
      9: Greeting.morning,
      10: Greeting.morning,
      11: Greeting.morning,
      12: Greeting.noon,
      13: Greeting.noon,
      14: Greeting.afternoon,
      15: Greeting.afternoon,
      16: Greeting.afternoon,
      17: Greeting.afternoon,
      18: Greeting.evening,
      19: Greeting.evening,
      20: Greeting.evening,
      21: Greeting.evening,
      22: Greeting.evening,
      23: Greeting.lateNight,
    };
    for (final entry in expected.entries) {
      expect(
        Greetings.of(DateTime(2026, 10, 3, entry.key)),
        entry.value,
        reason: '${entry.key}:00',
      );
    }
  });

  test('each bucket answers with its own dictionary key', () {
    // Six buckets, six keys — a seventh enum value would silently reuse a key
    // and the parity guard cannot see it, because the key is a string.
    final keys = Greeting.values.map(Greetings.key).toSet();
    expect(keys, hasLength(Greeting.values.length));
    for (final key in keys) {
      expect(key, startsWith('greeting'));
    }
  });

  test('the next boundary is always ahead and always changes the sentence', () {
    for (var hour = 0; hour < 24; hour++) {
      for (final minute in const [0, 1, 30, 59]) {
        final now = DateTime(2026, 10, 3, hour, minute);
        final next = Greetings.nextBoundary(now);
        expect(next.isAfter(now), isTrue, reason: '$now → $next');
        expect(
          Greetings.of(next),
          isNot(Greetings.of(now)),
          reason: 'a timer that fires inside the same bucket is a wasted frame',
        );
        // Nothing waits longer than the longest bucket (深夜, 6 hours).
        expect(next.difference(now).inHours, lessThanOrEqualTo(6));
      }
    }
  });

  test('exactly at a boundary the next one is the following hour', () {
    // The minute the greeting flips must not schedule another flip for the same
    // minute — that is an infinite re-render loop with a Timer in it.
    final noon = DateTime(2026, 10, 3, 12);
    expect(Greetings.nextBoundary(noon), DateTime(2026, 10, 3, 14));
    final late = DateTime(2026, 10, 3, 23, 30);
    expect(Greetings.nextBoundary(late), DateTime(2026, 10, 4, 5));
  });
}
