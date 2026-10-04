// The scheduled task store (ADR-0069): the two drift tables wrapped in the
// vocabulary. CRUD plus the due query; the scheduler owns the clock.

import 'package:drift/drift.dart' show OrderingTerm, Value;

import '../model/scheduled_task.dart';
import 'app_database.dart';

class ScheduledTaskStore {
  ScheduledTaskStore(this._db);

  final AppDatabase _db;

  /// Every task, enabled or not, ordered by name.
  Future<List<ScheduledTask>> tasks() async {
    final rows = await (_db.select(
      _db.scheduledTaskRows,
    )..orderBy([(row) => OrderingTerm(expression: row.name)])).get();
    return [for (final row in rows) _taskOf(row)];
  }

  /// Tasks due at [time] — enabled, minute match, weekday mask, and not
  /// already fired inside this minute.
  Future<List<ScheduledTask>> dueAt(DateTime time) async => [
    for (final task in await tasks())
      if (task.isDueAt(time) && !task.firedWithin(time)) task,
  ];

  Future<void> add({
    required String name,
    required String prompt,
    required int hour,
    required int minute,
    required int weekdaysMask,
  }) async {
    final trimmed = name.trim();
    final body = prompt.trim();
    if (trimmed.isEmpty || body.isEmpty) return;
    await _db
        .into(_db.scheduledTaskRows)
        .insert(
          ScheduledTaskRowsCompanion.insert(
            id: DateTime.now().toUtc().microsecondsSinceEpoch.toString(),
            name: trimmed,
            prompt: body,
            hour: hour.clamp(0, 23),
            minute: minute.clamp(0, 59),
            weekdaysMask: Value(weekdaysMask),
          ),
        );
  }

  Future<void> setEnabled(String id, {required bool enabled}) async {
    await (_db.update(_db.scheduledTaskRows)..where((row) => row.id.equals(id)))
        .write(ScheduledTaskRowsCompanion(enabled: Value(enabled)));
  }

  Future<void> remove(String id) async {
    await (_db.delete(
      _db.scheduledTaskRows,
    )..where((row) => row.id.equals(id))).go();
  }

  /// Marks the fire before the run starts — the single-flight guard.
  Future<void> markFired(String id, DateTime at) async {
    await (_db.update(
      _db.scheduledTaskRows,
    )..where((row) => row.id.equals(id))).write(
      ScheduledTaskRowsCompanion(lastRunAt: Value(at.millisecondsSinceEpoch)),
    );
  }

  Future<void> recordRun({
    required String taskId,
    required DateTime startedAt,
    required bool ok,
    required String preview,
  }) async {
    await _db
        .into(_db.scheduledTaskRunRows)
        .insert(
          ScheduledTaskRunRowsCompanion.insert(
            taskId: taskId,
            startedAt: startedAt.millisecondsSinceEpoch,
            ok: ok,
            preview: Value(
              preview.length <= 200 ? preview : '${preview.substring(0, 200)}…',
            ),
          ),
        );
  }

  ScheduledTask _taskOf(ScheduledTaskRow row) => ScheduledTask(
    id: row.id,
    name: row.name,
    prompt: row.prompt,
    hour: row.hour,
    minute: row.minute,
    weekdaysMask: row.weekdaysMask,
    enabled: row.enabled,
    lastRunAt: row.lastRunAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.lastRunAt!),
  );
}
