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
import '../../theme/dsw_shape.dart';
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
              PlanExtensionView.none ||
              PlanExtensionView.collection => const SizedBox.shrink(),
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
        // One line of column chrome, so the seat rides the text step: pinned at
        // 40 the group name wanted 48.0 in it once the system amplified text.
        height: 40 * MediaQuery.textScalerOf(context).scale(1),
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
    final step = MediaQuery.textScalerOf(context).scale(1);
    return CalendarControllerProvider<PlanTask>(
      controller: _events,
      // Two facts about `MonthView`'s defaults, both measured here rather than
      // read off the package: its own cell seats the day number in an 11.0-radius
      // `CircleAvatar` with a hardcoded 12px font, so at 1.8x every visible number
      // is cut (`"31" 36.0 vs 22.0`, one defect per cell); and it sizes its grid
      // from `MediaQuery.size.width` over which `cellAspectRatio` it was given
      // (`month_view.dart:391-395`), so in a panel it lays six full-window-wide
      // rows and runs off-screen - a dated task's chip measured `Offset(742.9,
      // 605.6)` in an 800x600 window, in the tree but unreachable. `cellBuilder`
      // and `width`/`cellAspectRatio` are the package's own extension points, so
      // the fix stays in the host: the cell is drawn with the app's labels and a
      // seat that rides the step, and the grid gets the panel's constraints.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowHeight = constraints.maxHeight / 6;
          return MonthView<PlanTask>(
            width: constraints.maxWidth,
            cellAspectRatio: rowHeight <= 0
                ? 0.55
                : constraints.maxWidth / 7 / rowHeight,
            cellBuilder: (date, events, isToday, isInMonth, position) =>
                _DayCell(
                  date: date,
                  events: events,
                  isToday: isToday,
                  isInMonth: isInMonth,
                  step: step,
                  store: widget.store,
                ),
          );
        },
      ),
    );
  }
}

/// One day of the month grid, drawn in the app's vocabulary (see `_CalendarViewState.build`).
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.events,
    required this.isToday,
    required this.isInMonth,
    required this.step,
    required this.store,
  });

  final DateTime date;
  final List<CalendarEventData<PlanTask>> events;
  final bool isToday;
  final bool isInMonth;
  final double step;
  final PlanTaskStore store;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final number = Text(
      '${date.day}',
      style: DswType.xs13.copyWith(
        color: isToday
            ? color.brandPrimaryInvert
            : isInMonth
            ? color.labelPrimary
            : color.labelDimmed,
      ),
    );
    return ColoredBox(
      color: isInMonth ? color.bgBase : color.bgLayer1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 22 * step,
              height: 22 * step,
              child: isToday
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: color.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(child: number),
                    )
                  : Center(child: number),
            ),
            if (events.isNotEmpty)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final event in events) _chip(context, event),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The task row inside a day. `DswHoverTap` rather than the grid's own
  /// `onEventTap`, so the toggle is keyboard- and screen-reader-reachable like
  /// every other interactive surface here.
  Widget _chip(BuildContext context, CalendarEventData<PlanTask> event) {
    final color = context.dsw;
    final task = event.event;
    if (task == null) return Text(event.title, style: DswType.xxxs11);
    return DswHoverTap(
      onTap: () => store.toggleDone(task.id),
      toggled: task.done,
      builder: (context, hovered, focused) => ColoredBox(
        color: (hovered || focused) ? color.interactiveBgHover : color.bgBase,
        child: Text(
          event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DswType.xxxs11.copyWith(
            color: task.done ? color.labelTertiary : color.labelPrimary,
            decoration: task.done ? TextDecoration.lineThrough : null,
            decorationColor: color.labelTertiary,
          ),
        ),
      ),
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
    // A row here is one line of chrome, so BOTH its seat and the width of the
    // fixed cell inside it ride the text step: at 1.8x the ISO date wanted 72.0
    // in a 36.0 seat (it wrapped onto a clipped second line) because 120px was
    // never going to hold ten glyphs at that step.
    final step = MediaQuery.textScalerOf(context).scale(1);
    final dueWidth = 120 * step;
    // The table used to render `store.tasks` without subscribing to the store:
    // only the board and the calendar listened, so an add, a toggle or a remove
    // changed the data and left these rows stale until something else rebuilt
    // the pane. Measured, not guessed - the panel kept showing two rows for a
    // store that already held three.
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(
              color,
              step,
              children: [
                const SizedBox(width: 40),
                _head(color, context.tr('planColumnTask')),
                _head(color, context.tr('planColumnDue'), width: dueWidth),
                const SizedBox(width: 28),
              ],
            ),
            Divider(height: 1, thickness: 1, color: color.borderL1),
            for (final task in store.tasks)
              _row(
                color,
                step,
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
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: color.labelTertiary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: dueWidth,
                    child: Text(
                      task.dueDate == null
                          ? context.tr('planNoDue')
                          : task.dueDateIso,
                      maxLines: 1,
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
      ),
    );
  }

  Widget _row(DswAlias color, double step, {required List<Widget> children}) =>
      SizedBox(
        height: 36 * step,
        child: Row(children: children),
      );

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
        size: DswShape.iconMd,
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
          borderRadius: BorderRadius.circular(DswShape.control),
          border: Border.all(color: color.borderL2),
        ),
        // The date sits under the title, not beside it. Measured reason: at the
        // system's largest step the card column is 108.0 wide, and one line
        // cannot hold a title plus `09-20` plus the × - the row spilled by 14
        // pixels (`A RenderFlex overflowed by 14 pixels on the right`) and the
        // title was squeezed to 0.0. A card is content, so it takes the second
        // line; a `Flexible` date would have ellipsised the day away instead.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: DswType.xs13.copyWith(
                      color: task.done
                          ? color.labelTertiary
                          : color.labelPrimary,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                      decorationColor: color.labelTertiary,
                    ),
                  ),
                  if (task.dueDate != null)
                    Text(
                      task.dueDateIso.substring(5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DswType.xxxs11.copyWith(
                        color: color.labelTertiary,
                      ),
                    ),
                ],
              ),
            ),
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
        size: DswShape.iconTiny,
        color: hovered ? color.stateErrorPrimary : color.labelTertiary,
      ),
    );
  }
}
