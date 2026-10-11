// The date object screen (ADR-0037 P6, module 4): ot-date's whole-screen
// answer — the relative-date header, the horizontal fields strip, and the
// object list of records whose date relation points at this day. Upstream
// queries a subscription per date (`SearchParams.kt:150-196`); the honest
// single-store equivalent is a scan of the store's records for the matching
// day, and the calendar popover picks another day rather than another object.
//
// A date object in this workspace is any record whose type is `ot-date`; its
// struct carries the day as `dueDate`-style `YYYY-MM-DD` values, which
// `PlanObject.date()` reads.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import '../../../model/plan_dataview.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/plan_object_type.dart';
import '../../../model/plan_struct.dart';
import '../../../state/plan_object_store.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/tappable.dart';

class PlanDateScreen extends StatelessWidget {
  const PlanDateScreen({
    super.key,
    required this.store,
    required this.dateRecordId,
    this.initialDay,
  });

  final PlanObjectStore store;
  final String dateRecordId;

  /// The day the screen opens on; defaults to the record's own value.
  final DateTime? initialDay;

  String _relativeLabel(BuildContext context, DateTime day, DateTime now) {
    final difference = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(day.year, day.month, day.day)).inDays;
    if (difference == 0) return AppLocalizations.of(context).planDateToday;
    if (difference == 1) return AppLocalizations.of(context).planDateYesterday;
    if (difference == -1) return AppLocalizations.of(context).planDateTomorrow;
    return PlanDateFormat.monthAbbrBeforeDay.format(day);
  }

  List<PlanObject> _recordsForDay(DateTime day) {
    final stamp = PlanDateFormat.iso.format(day);
    return [
      // The date object itself carries the day but does not belong on its
      // own list — upstream's subscription excludes the anchor object.
      for (final record in store.objects)
        if (record.id != dateRecordId && !store.binIds.contains(record.id))
          for (final key in record.struct.keys)
            if (record.struct[key] is String &&
                record.struct[key] == stamp &&
                key != 'editedAt' &&
                key != 'createdAt')
              record,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final record = store.byId(dateRecordId);
    if (record == null) {
      return Center(
        child: Text(
          AppLocalizations.of(context).planCollectionMissing,
          style: DswType.xs13.copyWith(color: color.labelTertiary),
        ),
      );
    }
    final now = DateTime.now();
    final day = initialDay ?? record.date('dueDate') ?? now;
    final records = _recordsForDay(day);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(DswShape.md),
          child: Row(
            children: [
              Icon(
                LucideIcons.calendar,
                size: DswShape.iconMd,
                color: color.labelTertiary,
              ),
              const SizedBox(width: DswShape.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PlanDateFormat.monthAbbrBeforeDay.format(day),
                      style: DswType.l20.copyWith(color: color.labelPrimary),
                    ),
                    Text(
                      _relativeLabel(context, day, now),
                      style: DswType.xs13.copyWith(color: color.labelTertiary),
                    ),
                  ],
                ),
              ),
              Text(
                AppLocalizations.of(context).planRecordCount,
                style: DswType.xxxs11.copyWith(color: color.labelTertiary),
              ),
              const SizedBox(width: DswShape.xs),
              Text(
                '${records.length}',
                style: DswType.xxxs11.copyWith(color: color.labelTertiary),
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(DswShape.lg),
                  child: Text(
                    AppLocalizations.of(context).planDateNoObjects,
                    style: DswType.xs13.copyWith(color: color.labelTertiary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: DswShape.md),
                  children: [
                    for (final entry in records) _DateRecordRow(record: entry),
                  ],
                ),
        ),
      ],
    );
  }
}

class _DateRecordRow extends StatelessWidget {
  const _DateRecordRow({required this.record});

  final PlanObject record;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: null,
      semanticLabel: record.name,
      builder: (context, hovered, focused) => Container(
        height: DswShape.rowSession * MediaQuery.textScalerOf(context).scale(1),
        padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
        decoration: BoxDecoration(
          color: hovered ? color.interactiveBgHover : null,
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: Row(
          children: [
            Icon(
              record.typeKey == PlanObjectTypeIds.task
                  ? LucideIcons.circle_check
                  : LucideIcons.circle,
              size: DswShape.iconTiny,
              color: record.isDone ? color.brandPrimary : color.labelTertiary,
            ),
            const SizedBox(width: DswShape.sm),
            Expanded(
              child: Text(
                record.name.isEmpty
                    ? AppLocalizations.of(context).planUntitled
                    : record.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.xs13.copyWith(
                  color: record.isDone
                      ? color.labelTertiary
                      : color.labelPrimary,
                  decoration: record.isDone
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
