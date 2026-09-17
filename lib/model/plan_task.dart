// One task on the plan side (ADR-0007 D4) — the single record the board,
// calendar, and table all project. Pure Dart (the `lib/model` invariant), with
// the store in `lib/state/plan_task_store.dart` doing the persisting.

class PlanTask {
  const PlanTask({
    required this.id,
    required this.title,
    required this.groupIndex,
    this.order = 0,
    this.done = false,
    this.dueDate,
  });

  final String id;

  final String title;

  /// Which board column the task sits in. The columns themselves are UI copy
  /// (i18n); the store only ever sees 0..3.
  final int groupIndex;

  /// Position within the group; the board's drag result writes it.
  final double order;

  final bool done;

  /// The calendar's anchor, or null for "no date yet". Date-only, stored as an
  /// ISO yyyy-MM-dd string so the JSON stays human-readable on disk.
  final DateTime? dueDate;

  String get dueDateIso =>
      dueDate == null ? '' : dueDate!.toIso8601String().substring(0, 10);

  PlanTask copyWith({
    String? title,
    int? groupIndex,
    double? order,
    bool? done,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) => PlanTask(
    id: id,
    title: title ?? this.title,
    groupIndex: groupIndex ?? this.groupIndex,
    order: order ?? this.order,
    done: done ?? this.done,
    dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'groupIndex': groupIndex,
    'order': order,
    'done': done,
    if (dueDate != null) 'dueDate': dueDateIso,
  };

  static PlanTask fromJson(Map<String, dynamic> json) => PlanTask(
    id: json['id'] as String,
    title: json['title'] as String,
    groupIndex: json['groupIndex'] as int? ?? 0,
    order: (json['order'] as num?)?.toDouble() ?? 0,
    done: json['done'] as bool? ?? false,
    dueDate: DateTime.tryParse(json['dueDate'] as String? ?? ''),
  );

  @override
  bool operator ==(Object other) =>
      other is PlanTask &&
      other.id == id &&
      other.title == title &&
      other.groupIndex == groupIndex &&
      other.order == order &&
      other.done == done &&
      other.dueDate == dueDate;

  @override
  int get hashCode => Object.hash(id, title, groupIndex, order, done, dueDate);
}
