// The hero's greeting, by time of day.
//
// Port of `ConversationDraftEmptyState.tsx:29-35` with its boundary hour list
// (`:14`). Two things make it more than a lookup: the reference does not pick a
// random nice sentence — the six buckets tile the whole day, so exactly one
// applies at every hour — and it re-renders itself when the day crosses a
// boundary under it (`:38-52, :91-99`), so a hero left open across noon says
// something true at 13:00.
//
// Pure Dart, no clock read inside: the caller passes the instant, which is what
// lets `test/greeting_test.dart` walk all 24 hours instead of waiting for them.

/// The six greetings, in the order their boundaries start.
enum Greeting { morningEarly, morning, noon, afternoon, evening, lateNight }

abstract final class Greetings {
  /// The hour each bucket starts at, ascending. 5 早 / 9 上午 / 12 中午 /
  /// 14 下午 / 18 晚上 / 23 深夜; the hours before 5 belong to 深夜, which is why
  /// the list wraps rather than ending.
  static const _bounds = [5, 9, 12, 14, 18, 23];

  static Greeting of(DateTime at) {
    for (var i = _bounds.length - 1; i > 0; i--) {
      if (at.hour >= _bounds[i]) return Greeting.values[i];
    }
    return at.hour >= _bounds.first
        ? Greeting.morningEarly
        : Greeting.lateNight;
  }

  /// The i18n key for one bucket. The strings live in the dictionary like every
  /// other user-facing sentence (ADR-0008), including the six greetings.
  static String key(Greeting greeting) => switch (greeting) {
    Greeting.morningEarly => 'greetingMorningEarly',
    Greeting.morning => 'greetingMorning',
    Greeting.noon => 'greetingNoon',
    Greeting.afternoon => 'greetingAfternoon',
    Greeting.evening => 'greetingEvening',
    Greeting.lateNight => 'greetingLateNight',
  };

  /// The next instant at which [of] would answer differently.
  ///
  /// A hero that never repaints is a hero that lies at 18:05 — the reference
  /// schedules exactly this and re-renders on it.
  static DateTime nextBoundary(DateTime at) {
    DateTime? next;
    for (final bound in _bounds) {
      if (bound <= at.hour) continue;
      final candidate = DateTime(at.year, at.month, at.day, bound);
      if (next == null || candidate.isBefore(next)) next = candidate;
    }
    // Past the last boundary of the day the next one is tomorrow's first.
    return next ?? DateTime(at.year, at.month, at.day + 1, _bounds.first);
  }
}
