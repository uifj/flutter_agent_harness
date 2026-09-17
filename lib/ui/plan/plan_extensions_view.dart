// The plan workspace's extension panels (ADR-0007 D4): 看板 (kanban), 日程
// (calendar), 表格 (table) — three projections of the SAME `PlanTaskStore`,
// exactly as starkins's three plan pages project one task store.
//
// The board and the calendar come from the vendored `board_panel` package
// (BoardPanel drag & drop, MonthView) — the two panels worth a dependency. The
// table is hand-rolled in dsw vocabulary: board_panel's ExpandableTable is built
// on ChangeNotifier cell objects with a build(context, details) contract, which
// is heavier machinery than a flat task list needs, and a plain table reads
// better against the rest of the app. (Recorded refinement of ADR-0007 D4.)
//
// The add row is shared by all three panels. MVP editing (the ADR's "最小的
// 新建/编辑"): add a task (title + optional yyyy-mm-dd due date), tap a card/row
// to toggle done, × to remove, drag on the board to move. Richer editors are
// follow-up work.

import 'package:board_panel/board_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadInput;

import '../../l10n/locales.dart';
import '../../model/plan_task.dart';
import '../../state/plan_task_store.dart';
import '../../state/workspace_mode_controller.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/capsule_button.dart';
import '../primitives/tappable.dart';

/// Which extension panel is up, and the store it projects.
class PlanExtensionsView extends StatelessWidget {
  const PlanExtensionsView({
    super.key,
    required this.store,
    required this.view,
  });

  final PlanTaskStore store;
  final PlanExtensionView view;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ColoredBox(
      color: color.bgBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AddTaskRow(store: store),
          Expanded(
            child: switch (view) {
              PlanExtensionView.board => _BoardView(store: store),
              PlanExtensionView.calendar => _CalendarView(store: store),
              PlanExtensionView.table => _TableView(store: store),
              PlanExtensionView.none => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

// ---- The add row -----------------------------------------------------------

class _AddTaskRow extends StatefulWidget {
  const _AddTaskRow({required this.store});

  final PlanTaskStore store;

  @override
  State<_AddTaskRow> createState() => _AddTaskRowState();
}

class _AddTaskRowState extends State<_AddTaskRow> {
  final _title = TextEditingController();
  final _date = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _date.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _title.text.trim();
    if (title.isEmpty) return;
    final due = DateTime.tryParse(_date.text.trim());
    await widget.store.add(title, dueDate: due);
    _title.clear();
    _date.clear();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ShadInput(
              controller: _title,
              style: DswType.s14.copyWith(color: color.labelPrimary),
              placeholder: Text(
                context.tr('planTaskTitleHint'),
                style: DswType.s14.copyWith(color: color.labelDimmed),
              ),
              onSubmitted: (_) => _add(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ShadInput(
              controller: _date,
              style: DswType.xs13.copyWith(color: color.labelPrimary),
              placeholder: Text(
                context.tr('planTaskDateHint'),
                style: DswType.xs13.copyWith(color: color.labelDimmed),
              ),
              onSubmitted: (_) => _add(),
            ),
          ),
          const SizedBox(width: 8),
          CapsuleButton(
            label: context.tr('planAddTask'),
            variant: CapsuleVariant.primary,
            size: CapsuleSize.sm,
            onTap: _add,
          ),
        ],
      ),
    );
  }
}

// ---- The board -------------------------------------------------------------

/// Wraps a [PlanTask] as a board item. `BoardPanelGroupItem` (reorder_flex) is
/// a mutable base needing only a unique `id`; the model stays a plain Dart
/// value object (the `lib/model` invariant) rather than importing board_panel.
class _TaskCard extends BoardPanelGroupItem {
  _TaskCard(this.task);

  final PlanTask task;

  @override
  String get id => task.id;
}

class _BoardView extends StatefulWidget {
  const _BoardView({required this.store});

  final PlanTaskStore store;

  @override
  State<_BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<_BoardView> {
  late BoardPanelController _board = _seed();
  final _scroll = BoardPanelScrollController();

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    super.dispose();
  }

  /// A drag first mutates the store (its move callbacks); the store's
  /// notification lands here and re-seeds the board — idempotent, since the
  /// store already reflects the move.
  void _onStoreChanged() => setState(() => _board = _seed());

  BoardPanelController _seed() {
    final controller = BoardPanelController(
      onMoveGroupItemToGroup: (fromGroupId, fromIndex, toGroupId, toIndex) {
        final id = _taskId(fromGroupId, fromIndex);
        if (id != null) widget.store.move(id, int.parse(toGroupId), toIndex);
      },
      onMoveGroupItem: (groupId, fromIndex, toIndex) {
        final id = _taskId(groupId, fromIndex);
        if (id != null) widget.store.move(id, int.parse(groupId), toIndex);
      },
    );
    for (var g = 0; g < planGroupCount; g++) {
      controller.addGroup(
        BoardPanelGroupData<_TaskCard>(
          id: '$g',
          name: _groupName(context, g),
          items: [for (final task in widget.store.group(g)) _TaskCard(task)],
        ),
        notify: false,
      );
    }
    return controller;
  }

  String? _taskId(String groupId, int index) {
    final group = widget.store.group(int.parse(groupId));
    return index < group.length ? group[index].id : null;
  }

  static String _groupName(BuildContext context, int index) => switch (index) {
    0 => context.tr('planGroupTodo'),
    1 => context.tr('planGroupInProgress'),
    2 => context.tr('planGroupReview'),
    _ => context.tr('planGroupDone'),
  };

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return BoardPanel(
      controller: _board,
      boardScrollController: _scroll,
      config: BoardPanelConfig(
        groupBackgroundColor: color.bgLayer1,
        stretchGroupHeight: true,
        cardPageSize: 0,
      ),
      cardBuilder: (context, group, groupItem) => BoardPanelGroupCard(
        key: ValueKey(groupItem.id),
        child: _Card(task: (groupItem as _TaskCard).task, store: widget.store),
      ),
      headerBuilder: (context, columnData) => BoardPanelGroupHeader(
        title: Expanded(
          child: Text(
            columnData.headerData.groupName,
            style: DswType.sStrong14.copyWith(color: color.labelPrimary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        height: 40,
      ),
    );
  }
}

// ---- The calendar ----------------------------------------------------------

class _CalendarView extends StatefulWidget {
  const _CalendarView({required this.store});

  final PlanTaskStore store;

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  final _events = EventController<PlanTask>();

  @override
  void initState() {
    super.initState();
    _sync();
    widget.store.addListener(_sync);
  }

  @override
  void dispose() {
    widget.store.removeListener(_sync);
    super.dispose();
  }

  /// The calendar projects only the DATED tasks — an undated one has no cell to
  /// live in (the board and the table carry it).
  void _sync() {
    _events.removeWhere((_) => true);
    _events.addAll([
      for (final task in widget.store.tasks)
        if (task.dueDate != null)
          CalendarEventData<PlanTask>(
            title: task.title,
            date: task.dueDate!,
            event: task,
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return CalendarControllerProvider<PlanTask>(
      controller: _events,
      child: const MonthView<PlanTask>(),
    );
  }
}

// ---- The table -------------------------------------------------------------

class _TableView extends StatelessWidget {
  const _TableView({required this.store});

  final PlanTaskStore store;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(
            color,
            children: [
              const SizedBox(width: 40),
              _head(color, context.tr('planColumnTask')),
              _head(color, context.tr('planColumnDue'), width: 120),
              const SizedBox(width: 28),
            ],
          ),
          Divider(height: 1, thickness: 1, color: color.borderL1),
          for (final task in store.tasks)
            _row(
              color,
              children: [
                SizedBox(
                  width: 40,
                  child: _DoneToggle(task: task, store: store),
                ),
                Expanded(
                  child: Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.xs13.copyWith(
                      color: task.done
                          ? color.labelTertiary
                          : color.labelPrimary,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                      decorationColor: color.labelTertiary,
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Text(
                    task.dueDate == null
                        ? context.tr('planNoDue')
                        : task.dueDateIso,
                    style: DswType.xs13.copyWith(color: color.labelSecondary),
                  ),
                ),
                SizedBox(
                  width: 28,
                  child: _RemoveIcon(store: store, id: task.id),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _row(DswAlias color, {required List<Widget> children}) =>
      SizedBox(height: 36, child: Row(children: children));

  Widget _head(DswAlias color, String label, {double? width}) {
    final text = Text(
      label,
      style: DswType.xxsStrong12.copyWith(color: color.labelTertiary),
    );
    return width == null
        ? Expanded(child: text)
        : SizedBox(width: width, child: text);
  }
}

class _DoneToggle extends StatelessWidget {
  const _DoneToggle({required this.task, required this.store});

  final PlanTask task;
  final PlanTaskStore store;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: () => store.toggleDone(task.id),
      toggled: task.done,
      semanticLabel: task.title,
      excludeSemantics: true,
      builder: (context, hovered, _) => Icon(
        task.done ? LucideIcons.check : LucideIcons.circle,
        size: 15,
        color: task.done ? color.stateSuccessPrimary : color.labelTertiary,
      ),
    );
  }
}

// ---- The shared card pieces ------------------------------------------------

/// One task card (the board's). Tap toggles done; the × removes. The card body
/// is a `DswHoverTap` so the whole thing is keyboard-reachable, per the A1
/// policy every interactive surface in this app follows.
class _Card extends StatelessWidget {
  const _Card({required this.task, required this.store});

  final PlanTask task;
  final PlanTaskStore store;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: () => store.toggleDone(task.id),
      toggled: task.done,
      builder: (context, hovered, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.bgBase,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.borderL2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                task.title,
                style: DswType.xs13.copyWith(
                  color: task.done ? color.labelTertiary : color.labelPrimary,
                  decoration: task.done ? TextDecoration.lineThrough : null,
                  decorationColor: color.labelTertiary,
                ),
              ),
            ),
            if (task.dueDate != null) ...[
              const SizedBox(width: 6),
              Text(
                task.dueDateIso.substring(5),
                style: DswType.xxxs11.copyWith(color: color.labelTertiary),
              ),
            ],
            const SizedBox(width: 4),
            _RemoveIcon(store: store, id: task.id),
          ],
        ),
      ),
    );
  }
}

class _RemoveIcon extends StatelessWidget {
  const _RemoveIcon({required this.store, required this.id});

  final PlanTaskStore store;
  final String id;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: () => store.remove(id),
      semanticLabel: context.tr('remove'),
      excludeSemantics: true,
      builder: (context, hovered, _) => Icon(
        LucideIcons.x,
        size: 12,
        color: hovered ? color.stateErrorPrimary : color.labelTertiary,
      ),
    );
  }
}
