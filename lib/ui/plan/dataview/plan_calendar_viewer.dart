// The Calendar viewer (ADR-0037, extension). Upstream's mobile client answers
// CALENDAR with an "not available" card; this workspace renders it — the user
// moved the retired plan calendar panel's capability here (2026-10-01), and
// the parity ledger registers that as an extension over the mobile answer.
//
// The month grid is `packages/board_panel`'s MonthView with the host drawing
// the cells — the same seam the retired panel used, for the same two measured
// reasons: the package's own cell nails a 12px day number (clipped at the
// amplified steps) and sizes its grid off `MediaQuery.size.width` (six
// window-wide rows off-screen in a pane). `cellBuilder` and `width` /
// `cellAspectRatio` are the package's extension points.
//
// Records land on the day their date relation holds; the key is the viewer's
// first visible date-format column, falling back to the mock's `dueDate`. A
// record with no date has no cell — the grid and list views carry it.

import 'package:board_panel/board_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/locales.dart';
import '../../../model/plan_dataview.dart';
import '../../../model/plan_object_type.dart';
import '../../../model/plan_relation.dart';
import '../../../model/plan_struct.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/tappable.dart';

class PlanCalendarViewer extends StatefulWidget {
  const PlanCalendarViewer({
    super.key,
    required this.viewer,
    required this.records,
    required this.relationsByKey,
    required this.revision,
    required this.onOpen,
    this.onToggleDone,
  });

  final PlanViewer viewer;
  final List<PlanObject> records;
  final Map<String, PlanRelation> relationsByKey;

  /// The store's revision: the event controller re-syncs once per write, not
  /// once per rebuild.
  final int revision;
  final void Function(PlanObject record) onOpen;
  final void Function(String recordId)? onToggleDone;

  @override
  State<PlanCalendarViewer> createState() => _PlanCalendarViewerState();
}

class _PlanCalendarViewerState extends State<PlanCalendarViewer> {
  final _events = EventController<PlanObject>();
  int _syncedRevision = -1;

  @override
  void didUpdateWidget(PlanCalendarViewer old) {
    super.didUpdateWidget(old);
    if (widget.revision != old.revision || old.viewer.id != widget.viewer.id) {
      _sync();
    }
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  /// The date key answers from the viewer's own columns: the first visible
  /// relation whose format is a date, then the mock's `dueDate` — the same
  /// "the viewer decides" reading the gallery's cover column makes.
  String get _dateKey {
    for (final column in widget.viewer.relations) {
      if (!column.isVisible) continue;
      final relation = widget.relationsByKey[column.key];
      if (relation?.format == PlanRelationFormat.date) return column.key;
    }
    return 'dueDate';
  }

  void _sync() {
    if (_syncedRevision == widget.revision) return;
    _syncedRevision = widget.revision;
    _events.removeWhere((_) => true);
    _events.addAll([
      for (final record in widget.records)
        if (record.date(_dateKey) case final day?)
          CalendarEventData<PlanObject>(
            title: record.name,
            date: day,
            event: record,
          ),
    ]);
  }

  int get _undatedCount =>
      widget.records.where((record) => record.date(_dateKey) == null).length;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final step = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CalendarControllerProvider<PlanObject>(
            controller: _events,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rowHeight = constraints.maxHeight / 6;
                return MonthView<PlanObject>(
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
                        onOpen: widget.onOpen,
                        onToggleDone: widget.onToggleDone,
                      ),
                );
              },
            ),
          ),
        ),
        if (_undatedCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DswShape.md,
              DswShape.xs,
              DswShape.md,
              DswShape.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.calendar_off,
                  size: DswShape.iconTiny,
                  color: color.labelTertiary,
                ),
                const SizedBox(width: DswShape.xs),
                Flexible(
                  child: Text(
                    context.tr('planCalendarUndated', {
                      'count': '$_undatedCount',
                    }),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.xxxs11.copyWith(color: color.labelTertiary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One day of the month grid, drawn in the app's vocabulary.
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.events,
    required this.isToday,
    required this.isInMonth,
    required this.step,
    required this.onOpen,
    this.onToggleDone,
  });

  final DateTime date;
  final List<CalendarEventData<PlanObject>> events;
  final bool isToday;
  final bool isInMonth;
  final double step;
  final void Function(PlanObject record) onOpen;
  final void Function(String recordId)? onToggleDone;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      margin: const EdgeInsets.all(1),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isInMonth ? color.bgLayer1 : color.bgBase,
        borderRadius: BorderRadius.circular(DswShape.inset),
        border: isToday ? Border.all(color: color.brandPrimary) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 1),
            child: Text(
              '${date.day}',
              style: DswType.xxxs11.copyWith(
                color: isToday
                    ? color.brandPrimary
                    : isInMonth
                    ? color.labelSecondary
                    : color.labelDimmed,
              ),
            ),
          ),
          for (final event in events.take(3))
            DswHoverTap(
              onTap: () => onOpen(event.event!),
              semanticLabel: event.title,
              builder: (context, hovered, focused) => Container(
                margin: const EdgeInsets.only(top: 1),
                padding: EdgeInsets.symmetric(
                  horizontal: DswShape.xs,
                  vertical: 1 * step,
                ),
                decoration: BoxDecoration(
                  color: hovered
                      ? color.interactiveBgHover
                      : color.interactiveSelected,
                  borderRadius: BorderRadius.circular(DswShape.inset),
                ),
                child: Row(
                  children: [
                    if (event.event?.typeKey == PlanObjectTypeIds.task) ...[
                      Icon(
                        event.event?.isDone ?? false
                            ? LucideIcons.circle_check
                            : LucideIcons.circle,
                        size: DswShape.iconCaption,
                        color: event.event?.isDone ?? false
                            ? color.brandPrimary
                            : color.labelTertiary,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: Text(
                        event.title.isEmpty
                            ? context.tr('planUntitled')
                            : event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DswType.xxxs11.copyWith(
                          color: color.labelPrimary,
                          decoration: event.event?.isDone ?? false
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
