// The one sentence this file holds: the plan task store persists across reopen,
// orders tasks by group then position, and the board's move lands the task
// exactly where it was dropped.
//
// This is the ADR-0007 S4 guard. The board/calendar/table all project this one
// store, so its ordering + persistence are the shared truth the panels rest on —
// real temp-directory IO, because a fake would not prove the atomic write.

import 'dart:io';

import 'package:agent_harness/state/plan_task_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('dsh_plan_tasks_'));

  tearDown(() {
    for (var i = 0; i < 20 && root.existsSync(); i++) {
      try {
        root.deleteSync(recursive: true);
      } on FileSystemException {
        sleep(const Duration(milliseconds: 25));
      }
    }
  });

  test('a fresh store is empty', () async {
    final store = await PlanTaskStore.open(root);
    expect(store.tasks, isEmpty);
  });

  test('added tasks persist across a reopen', () async {
    final store = await PlanTaskStore.open(root);
    await store.add('write the intro', dueDate: DateTime(2026, 9, 20));
    await store.add('draft outline', groupIndex: 1);

    final reopened = await PlanTaskStore.open(root);
    expect(reopened.tasks.length, 2);
    expect(
      reopened.tasks.map((t) => t.title),
      containsAll(<String>['write the intro', 'draft outline']),
    );
    final dated = reopened.tasks.firstWhere(
      (t) => t.title == 'write the intro',
    );
    expect(dated.dueDateIso, '2026-09-20');
    expect(dated.groupIndex, 0);
    expect(
      reopened.tasks.firstWhere((t) => t.title == 'draft outline').groupIndex,
      1,
    );
  });

  test(
    'move places the task at the target index within the new group',
    () async {
      final store = await PlanTaskStore.open(root);
      await store.add('a');
      await store.add('b');
      await store.add('c');
      String idOf(String title) =>
          store.tasks.firstWhere((t) => t.title == title).id;

      // Move 'c' to group 2 at the front, then 'a' to group 2 after 'c'.
      await store.move(idOf('c'), 2, 0);
      await store.move(idOf('a'), 2, 1);

      final moved = store.group(2).map((t) => t.title).toList();
      expect(moved, ['c', 'a']);
      // The source group keeps the remaining task in order.
      expect(store.group(0).map((t) => t.title), ['b']);
    },
  );

  test('toggleDone and remove round-trip', () async {
    final store = await PlanTaskStore.open(root);
    await store.add('finish chapter');
    final id = store.tasks.single.id;
    await store.toggleDone(id);
    expect(store.tasks.single.done, isTrue);

    final reopened = await PlanTaskStore.open(root);
    expect(reopened.tasks.single.done, isTrue);

    await reopened.remove(id);
    expect((await PlanTaskStore.open(root)).tasks, isEmpty);
  });

  test('a corrupt file reads as empty rather than throwing', () async {
    File('${root.path}/plan_tasks.json').writeAsStringSync('{not json');
    final store = await PlanTaskStore.open(root);
    expect(store.tasks, isEmpty);
  });
}
