// Scheduled task vocabulary (ADR-0069): a minute-of-day plus weekday-mask
// schedule and the pure "is this minute due" check. The scheduler ticks;
// the vocabulary decides.

class ScheduledTask {
  const ScheduledTask({
    required this.id,
    required this.name,
    required this.prompt,
    required this.hour,
    required this.minute,
    required this.weekdaysMask,
    required this.enabled,
    this.lastRunAt,
  });

  /// Bitmask for DateTime.weekday (Monday = 1 … Sunday = 64). Zero means
  /// every day.
  static int weekdayBit(DateTime time) => 1 << (time.weekday - 1);

  final String id;
  final String name;
  final String prompt;

  /// Hour and minute of the local day the task fires at.
  final int hour;
  final int minute;
  final int weekdaysMask;
  final bool enabled;

  /// The last fire, used for single-flight: a task fires at most once per
  /// matching minute even if the ticker lands twice inside it.
  final DateTime? lastRunAt;

  /// Whether [time]'s local minute is one this task should fire on.
  bool isDueAt(DateTime time) {
    if (!enabled) return false;
    if (time.hour != hour || time.minute != minute) return false;
    if (weekdaysMask == 0) return true;
    return (weekdaysMask & weekdayBit(time)) != 0;
  }

  /// Whether this task already fired inside [time]'s minute — the
  /// single-flight check.
  bool firedWithin(DateTime time) {
    final last = lastRunAt;
    if (last == null) return false;
    return last.year == time.year &&
        last.month == time.month &&
        last.day == time.day &&
        last.hour == time.hour &&
        last.minute == time.minute;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'prompt': prompt,
    'hour': hour,
    'minute': minute,
    'weekdaysMask': weekdaysMask,
    'enabled': enabled,
    if (lastRunAt != null) 'lastRunAt': lastRunAt!.millisecondsSinceEpoch,
  };
}
