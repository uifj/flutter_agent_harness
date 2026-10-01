// 本文件守住的那句话：会话行右侧的"多久以前"只有四档——一分钟以内、分钟、小时、天，
// 边界分别落在 60 秒、60 分、24 小时，而未来的时间戳读作"刚刚"而不是负数。
//
// 档位取自参考实现（`taskListItemPresentation.ts:33-53`）；它回答的是 i18n 键加
// 参数，因为 `lib/model` 不碰字典（不变量 2），把英文单词写在这里就是第二份文案。

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_harness/model/relative_time.dart';

void main() {
  final now = DateTime(2026, 10, 2, 12);

  RelativeTime at({
    int seconds = 0,
    int minutes = 0,
    int hours = 0,
    int days = 0,
  }) => formatRelativeTime(
    now.subtract(
      Duration(days: days, hours: hours, minutes: minutes, seconds: seconds),
    ),
    now,
  );

  test(
    'under a minute is "just now", and so is the clock running backwards',
    () {
      expect(at(seconds: 59).key, 'justNow');
      expect(
        formatRelativeTime(now.add(const Duration(minutes: 5)), now).key,
        'justNow',
      );
    },
  );

  test('minutes carry the count, up to but not including the hour', () {
    expect(at(seconds: 60), const RelativeTime('minutesAgo', {'n': 1}));
    expect(at(minutes: 59), const RelativeTime('minutesAgo', {'n': 59}));
  });

  test('hours take over at the hour and stop at the day', () {
    expect(at(minutes: 60), const RelativeTime('hoursAgo', {'n': 1}));
    expect(at(hours: 23), const RelativeTime('hoursAgo', {'n': 23}));
  });

  test('days are the last step and keep counting', () {
    expect(at(hours: 24), const RelativeTime('daysAgo', {'n': 1}));
    expect(at(days: 23), const RelativeTime('daysAgo', {'n': 23}));
  });
}
