// The plan side's task list (ADR-0007 D4) — the one record the board, the
// calendar, and the table all project.
//
// Same shape as `SettingsStore`: a JSON file in Application Support, atomic
// tmp+rename writes, notify-on-change, corrupt file reads as empty. Unsaved
// board drags are worth nothing — starkins persists its plan tasks too, and a
// kanban that forgets its columns on restart is a toy.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/plan_task.dart';

/// How many board columns there are. The column NAMES are UI copy (i18n);
/// the store only ever sees the index.
const planGroupCount = 4;

class PlanTaskStore extends ChangeNotifier {
  PlanTaskStore._(this._file, List<PlanTask> tasks)
    : _tasks = [...tasks]..sort(_compare);

  /// Reads the tasks from [root] (Application Support), falling back to empty.
  static Future<PlanTaskStore> open(Directory root) async {
    final file = File('${root.path}/$_fileName');
    var tasks = const <PlanTask>[];
    try {
      if (file.existsSync()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is List) {
          tasks = [
            for (final entry in decoded)
              if (entry is Map<String, dynamic>) PlanTask.fromJson(entry),
          ];
        }
      }
    } on FileSystemException {
      // Unreadable; start empty.
    } on FormatException {
      // Not JSON; same.
    }
    return PlanTaskStore._(file, tasks);
  }

  static const _fileName = 'plan_tasks.json';

  /// Tasks ordered for display: group, then position within the group.
  static int _compare(PlanTask a, PlanTask b) {
    if (a.groupIndex != b.groupIndex) {
      return a.groupIndex.compareTo(b.groupIndex);
    }
    return a.order.compareTo(b.order);
  }

  final File _file;
  List<PlanTask> _tasks;

  /// The tasks, display-ordered (group, then position). A copy, so a caller
  /// cannot mutate the store's list out from under its listeners.
  List<PlanTask> get tasks => List.unmodifiable(_tasks);

  /// The tasks of one board column, in order.
  List<PlanTask> group(int groupIndex) => [
    for (final task in _tasks)
      if (task.groupIndex == groupIndex) task,
  ];

  PlanTask? byId(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  /// Adds a task to the top of [groupIndex] (the board's "add" lands where the
  /// user clicked), first in the column's order.
  Future<void> add(
    String title, {
    int groupIndex = 0,
    DateTime? dueDate,
  }) async {
    final order = group(
      groupIndex,
    ).fold<double>(0, (min, task) => task.order < min ? task.order : min);
    _tasks = [
      ..._tasks,
      PlanTask(
        id: 't${DateTime.now().microsecondsSinceEpoch}',
        title: title,
        groupIndex: groupIndex,
        order: order - 1,
        dueDate: dueDate,
      ),
    ];
    await _save();
  }

  Future<void> toggleDone(String id) async {
    final task = byId(id);
    if (task == null) return;
    _tasks = [
      for (final other in _tasks)
        if (other.id == id) other.copyWith(done: !other.done) else other,
    ];
    await _save();
  }

  Future<void> remove(String id) async {
    _tasks = [
      for (final task in _tasks)
        if (task.id != id) task,
    ];
    await _save();
  }

  /// The board's drag result: [id] moves to [toGroup] at [toIndex] within it.
  /// Re-orders the column so the moved task lands exactly there.
  Future<void> move(String id, int toGroup, int toIndex) async {
    final task = byId(id);
    if (task == null) return;
    var column = [
      for (final other in _tasks)
        if (other.groupIndex == toGroup && other.id != id) other,
    ];
    toIndex = toIndex.clamp(0, column.length);
    column.insert(toIndex, task.copyWith(groupIndex: toGroup));
    _tasks = [
      for (final other in _tasks)
        if (other.groupIndex != toGroup && other.id != id) other,
      for (var i = 0; i < column.length; i++)
        column[i].copyWith(groupIndex: toGroup, order: i.toDouble()),
    ];
    await _save();
  }

  /// Persist and notify. Atomic: tmp + rename, so an interrupted write leaves
  /// the previous file intact.
  Future<void> _save() async {
    _tasks = [..._tasks]..sort(_compare);
    final temp = File('${_file.path}.tmp');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(
      jsonEncode([for (final task in _tasks) task.toJson()]),
      flush: true,
    );
    await temp.rename(_file.path);
    notifyListeners();
  }
}
