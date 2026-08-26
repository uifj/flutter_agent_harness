// The plan/todo state the todo_write and plan tools maintain.
//
// Pure data, so the transcript rebuild and the live turn projection share one
// definition. Nothing here imports Genkit.

/// One row of the task list the model maintains through `todo_write`.
class TodoItem {
  const TodoItem({required this.content, required this.status});

  factory TodoItem.pending(String content) =>
      TodoItem(content: content, status: TodoStatus.pending);

  final String content;
  final TodoStatus status;

  TodoItem copyWith({String? content, TodoStatus? status}) => TodoItem(
    content: content ?? this.content,
    status: status ?? this.status,
  );

  Map<String, Object?> toJson() => {'content': content, 'status': status.name};

  /// Null when [raw] is not a usable row, so one malformed entry costs one row.
  static TodoItem? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final content = raw['content'];
    if (content is! String || content.trim().isEmpty) return null;
    return TodoItem(
      content: content,
      status: switch (raw['status']) {
        'in_progress' => TodoStatus.inProgress,
        'completed' => TodoStatus.completed,
        _ => TodoStatus.pending,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TodoItem && other.content == content && other.status == status;

  @override
  int get hashCode => Object.hash(content, status);

  @override
  String toString() => 'TodoItem($status, "$content")';
}

enum TodoStatus {
  pending,
  inProgress,
  completed;

  String get name => switch (this) {
    pending => 'pending',
    inProgress => 'in_progress',
    completed => 'completed',
  };
}

/// Parses a `todo_write` tool output back into the list it replaced.
///
/// The tool returns the rows it accepted; restoring a transcript replays the
/// same output, so one function serves the live turn and the reload.
List<TodoItem> todosFromToolOutput(Object? output) {
  if (output is! Map) return const [];
  final rows = output['todos'];
  if (rows is! List) return const [];
  return [for (final row in rows) ?TodoItem.fromJson(row)];
}
