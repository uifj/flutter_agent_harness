// 本文件守住的那句话：历史按"这次对话发生在哪个文件夹"分组，组内置顶优先、其余按
// 最新优先，当前工作区排第一，没有归属的会话单独一档垫底，而输入列表不被改写。
//
// 纯函数，所以不挂任何界面：分组规则要能在没有磁盘、没有时钟、没有 locale 的地方
// 被证伪（ADR-0039 D2）。

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/session_groups.dart';

SessionSummary _session(
  String id, {
  String? workspaceRoot,
  int minutesAgo = 0,
  DateTime? pinnedAt,
}) => SessionSummary(
  id: id,
  updatedAt: DateTime(2026, 10, 2, 12).subtract(Duration(minutes: minutesAgo)),
  title: id,
  workspaceRoot: workspaceRoot,
  pinnedAt: pinnedAt,
);

void main() {
  const alpha = '/Users/me/alpha';
  const beta = '/Users/me/beta';

  test('each folder is its own group, newest group first', () {
    final groups = groupSessionsByWorkspace(
      sessions: [
        _session('a-old', workspaceRoot: alpha, minutesAgo: 90),
        _session('b-new', workspaceRoot: beta, minutesAgo: 1),
        _session('a-new', workspaceRoot: alpha, minutesAgo: 10),
      ],
    );

    expect(groups.map((g) => g.displayName), ['beta', 'alpha']);
  });

  test('the workspace the user is in leads, whatever its age', () {
    final groups = groupSessionsByWorkspace(
      currentWorkspace: alpha,
      sessions: [
        _session('b-new', workspaceRoot: beta, minutesAgo: 1),
        _session('a-old', workspaceRoot: alpha, minutesAgo: 900),
      ],
    );

    expect(groups.first.displayName, 'alpha');
  });

  test('inside a group pinned rows come first, then recency', () {
    final groups = groupSessionsByWorkspace(
      sessions: [
        _session('fresh', workspaceRoot: alpha, minutesAgo: 1),
        _session(
          'stuck',
          workspaceRoot: alpha,
          minutesAgo: 600,
          pinnedAt: DateTime(2026, 10, 1),
        ),
        _session('older', workspaceRoot: alpha, minutesAgo: 60),
      ],
    );

    expect(groups.single.sessions.map((s) => s.id), [
      'stuck',
      'fresh',
      'older',
    ]);
  });

  test('a session with no recorded folder gets its own trailing bucket', () {
    final groups = groupSessionsByWorkspace(
      sessions: [
        _session('nobody'),
        _session('in-alpha', workspaceRoot: alpha, minutesAgo: 30),
      ],
    );

    expect(groups.map((g) => g.isUnassigned), [false, true]);
    expect(groups.last.displayName, isEmpty);
  });

  test('one folder is one group even when macOS spells it /private/var', () {
    const plain = '/var/folders/x/proj';
    const real = '/private/var/folders/x/proj';

    final groups = groupSessionsByWorkspace(
      currentWorkspace: real,
      sessions: [
        _session('a', workspaceRoot: plain, minutesAgo: 5),
        _session('b', workspaceRoot: '/private$plain', minutesAgo: 1),
      ],
    );

    expect(groups, hasLength(1));
    expect(groups.single.sessions.map((s) => s.id), ['b', 'a']);
  });

  test('the input list is not reordered in place', () {
    final input = [
      _session('x', workspaceRoot: beta, minutesAgo: 1),
      _session('y', workspaceRoot: alpha, minutesAgo: 99),
    ];
    final before = input.map((s) => s.id).toList();

    groupSessionsByWorkspace(sessions: input);

    expect(input.map((s) => s.id), before);
  });
}
