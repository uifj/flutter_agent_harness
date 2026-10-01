// The one way this app says "how long ago" (ADR-0039 D5).
//
// Four steps, taken from the reference implementation's `formatTaskRelativeTime`
// (`_archive_project/ZCode-main/packages/ui/src/lib/taskListItemPresentation.ts:33-53`):
// under a minute, then minutes, then hours, then days. The screenshots'
// `59分` and `23天` are the second and fourth step.
//
// It answers with an i18n key plus params rather than a string: `lib/model` may
// not reach for the locale table (invariant 2), and a literal English word in
// here would be a second copy of the copy that `l10n_parity_test` cannot see.

/// A translation key and its `{n}` placeholder, resolved by the surface that
/// renders it through `context.tr`.
class RelativeTime {
  const RelativeTime(this.key, [this.params = const {}]);

  final String key;
  final Map<String, Object> params;

  /// Value equality, because this is a value: the guards that pin the four
  /// steps compare whole answers, not fields.
  @override
  bool operator ==(Object other) =>
      other is RelativeTime &&
      other.key == key &&
      other.params.length == params.length &&
      other.params.entries.every((entry) => params[entry.key] == entry.value);

  @override
  int get hashCode => Object.hashAll([
    key,
    ...params.entries.map((entry) => Object.hash(entry.key, entry.value)),
  ]);

  @override
  String toString() => 'RelativeTime($key, $params)';
}

/// The distance from [at] to [now], in the four steps above.
///
/// A timestamp in the future (a clock that drifted, a file copied from another
/// machine) reads as "just now" instead of `-3天`: the honest answer to
/// "when was this last touched" when the answer is not yet.
RelativeTime formatRelativeTime(DateTime at, DateTime now) {
  final elapsed = now.difference(at);
  if (elapsed.isNegative || elapsed.inSeconds < 60) {
    return const RelativeTime('justNow');
  }
  if (elapsed.inMinutes < 60) {
    return RelativeTime('minutesAgo', {'n': elapsed.inMinutes});
  }
  if (elapsed.inHours < 24) {
    return RelativeTime('hoursAgo', {'n': elapsed.inHours});
  }
  return RelativeTime('daysAgo', {'n': elapsed.inDays});
}
