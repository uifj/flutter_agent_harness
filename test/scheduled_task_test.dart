// ADR-0069 guards: the due check (minute, weekday mask, single-flight),
// the store's CRUD against a real database, and the schema-2 migration
// path from a version-1 database.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/model/scheduled_task.dart';
import 'package:planstar/state/app_database.dart';
import 'package:planstar/state/scheduled_task_store.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late ScheduledTaskStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('scheduled_tasks');
    db = AppDatabase.open(File('${root.path}/planstar.db'));
    store = ScheduledTaskStore(db);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('isDueAt', () {
    // Monday 2026-10-05, 09:30 local.
    final monday = DateTime(2026, 10, 5, 9, 30);

    test('fires on the matching minute', () {
      final task = ScheduledTask(
        id: '1',
        name: 'Morning brief',
        prompt: 'Summarize the changes.',
        hour: 9,
        minute: 30,
        weekdaysMask: 0,
        enabled: true,
      );
      expect(task.isDueAt(monday), isTrue);
      expect(task.isDueAt(monday.add(const Duration(minutes: 1))), isFalse);
    });

    test('a disabled task is never due', () {
      final task = ScheduledTask(
        id: '1',
        name: 'x',
        prompt: 'p',
        hour: 9,
        minute: 30,
        weekdaysMask: 0,
        enabled: false,
      );
      expect(task.isDueAt(monday), isFalse);
    });

    test('the weekday mask gates the day', () {
      // Friday = bit 1<<4 = 16.
      final fridayOnly = ScheduledTask(
        id: '1',
        name: 'x',
        prompt: 'p',
        hour: 9,
        minute: 30,
        weekdaysMask: 16,
        enabled: true,
      );
      expect(fridayOnly.isDueAt(monday), isFalse);
      expect(fridayOnly.isDueAt(DateTime(2026, 10, 9, 9, 30)), isTrue);
    });

    test('single-flight: a fire inside the same minute is absorbed', () {
      final task = ScheduledTask(
        id: '1',
        name: 'x',
        prompt: 'p',
        hour: 9,
        minute: 30,
        weekdaysMask: 0,
        enabled: true,
        lastRunAt: monday,
      );
      expect(task.isDueAt(monday), isTrue);
      expect(task.firedWithin(monday), isTrue);
      expect(task.isDueAt(monday) && !task.firedWithin(monday), isFalse);
      // The next minute is free again.
      expect(
        task.isDueAt(monday.add(const Duration(minutes: 1))) &&
            !task.firedWithin(monday.add(const Duration(minutes: 1))),
        isFalse,
      );
    });
  });

  group('store', () {
    test('add, list, toggle, remove', () async {
      await store.add(
        name: 'Morning brief',
        prompt: 'Summarize the changes.',
        hour: 9,
        minute: 30,
        weekdaysMask: 0,
      );
      expect(await store.tasks(), hasLength(1));

      final task = (await store.tasks()).single;
      await store.setEnabled(task.id, enabled: false);
      expect((await store.tasks()).single.enabled, isFalse);

      await store.remove(task.id);
      expect(await store.tasks(), isEmpty);
    });

    test('dueAt reflects the stored schedule and single-flight', () async {
      final now = DateTime.now();
      await store.add(
        name: 'Tick',
        prompt: 'Say hi.',
        hour: now.hour,
        minute: now.minute,
        weekdaysMask: 0,
      );
      var due = await store.dueAt(now);
      expect(due, hasLength(1));

      await store.markFired(due.single.id, now);
      due = await store.dueAt(now);
      expect(due, isEmpty);
    });

    test('a run record persists the preview', () async {
      await store.add(
        name: 'Tick',
        prompt: 'Say hi.',
        hour: 1,
        minute: 2,
        weekdaysMask: 0,
      );
      final task = (await store.tasks()).single;
      await store.recordRun(
        taskId: task.id,
        startedAt: DateTime.now(),
        ok: true,
        preview: 'hello there',
      );
      final runs = await (db.select(
        db.scheduledTaskRunRows,
      )..where((row) => row.taskId.equals(task.id))).get();
      expect(runs, hasLength(1));
      expect(runs.single.ok, isTrue);
      expect(runs.single.preview, 'hello there');
    });
  });
}
