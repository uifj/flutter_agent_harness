// The four viewers a plan collection can draw (ADR-0037 §1).
//
// Grid, List and Gallery are drawn here in `dsw_*` vocabulary; Board lives in
// the next file because it wraps `packages/board_panel`, and Calendar and
// Graph are drawn as [PlanUnsupportedViewer] — that is upstream's own answer,
// not a stub: the kinds exist in the model, the client says so out loud
// (`ObjectSetRenderMapper.kt:188-193`, `strings.xml:1466-1467`).
//
// One geometry rule holds the whole set together: the header and the rows sit
// inside the SAME horizontal scroller, so a sticky header costs no second
// scroll controller and no offset syncing. The vertical scroller wraps only the
// rows. Perpendicular axes are legal to nest; two horizontal ones are not.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/tr_key.dart';
import '../../../model/plan_dataview.dart';
import '../../../model/plan_object_type.dart';
import '../../../model/plan_relation.dart';
import '../../../model/plan_struct.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/capsule_button.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';
import 'plan_cell_value.dart';

/// The name column's width: it always leads, like upstream's first column.
const planNameColumnWidth = 260.0;

/// One row's seat height, scaled with the user's text step (ADR-0017 S3).
double planRowSeat(BuildContext context) =>
    DswShape.rowSession * MediaQuery.textScalerOf(context).scale(1);

/// Taps a cell to edit that relation.
typedef PlanCellTap = void Function(PlanObject record, String relationKey);

/// Resolves a record id of an `object`-format relation to its title.
typedef PlanLinkedName = String? Function(String id);

/// The columns a viewer draws, in the viewer's own order.
List<PlanViewerRelation> planVisibleColumns(PlanViewer viewer) => [
  for (final column in viewer.relations)
    if (column.isVisible) column,
];

double _columnWidth(BuildContext context, PlanViewerRelation column) =>
    column.width.columnWidth * MediaQuery.textScalerOf(context).scale(1);

/// A header or body cell: fixed width, one right hairline, and the value
/// always inside a `Expanded` so a long string ellipsizes instead of
/// overflowing the panel (the rule `composer.dart` and `diff_tab.dart` taught).
class _Cell extends StatelessWidget {
  const _Cell({
    required this.width,
    required this.child,
    this.onTap,
    this.menu,
    this.header = false,
  });

  final double width;
  final Widget child;
  final VoidCallback? onTap;
  final List<DswMenuEntry>? menu;
  final bool header;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    Widget content(bool hovered) => Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: hovered
            ? color.interactiveBgHover
            : (header ? color.bgLayer1 : null),
        border: Border(right: BorderSide(color: color.borderL2, width: 1)),
      ),
      child: Row(children: [Expanded(child: child)]),
    );
    final tappable = DswHoverTap(
      onTap: onTap,
      semanticLabel: header ? null : null,
      builder: (context, hovered, focused) =>
          content(hovered || (focused && !header)),
    );
    return menu == null || menu!.isEmpty
        ? tappable
        : DswContextMenu(items: (context) => menu!, child: tappable);
  }
}

/// The grid: a sticky header, one row per record, a footer that adds one.
class PlanGridViewer extends StatelessWidget {
  const PlanGridViewer({
    super.key,
    required this.viewer,
    required this.records,
    required this.relationsByKey,
    required this.onCellTap,
    required this.onAddRow,
    required this.onSortColumn,
    required this.onHideColumn,
    required this.onToggleDone,
    this.rowMenu,
    this.linkedName,
    this.wrapCell,
  });

  final PlanViewer viewer;
  final List<PlanObject> records;
  final Map<String, PlanRelation> relationsByKey;
  final PlanCellTap onCellTap;
  final VoidCallback? onAddRow;

  /// Lets the screen wrap a value cell in its editor without the viewer
  /// knowing about the store: identity is preserved when there is no editor.
  final Widget Function(
    PlanObject record,
    PlanViewerRelation column,
    Widget cell,
  )?
  wrapCell;
  final void Function(String relationKey, PlanSortType type) onSortColumn;
  final void Function(String relationKey) onHideColumn;
  final void Function(String recordId) onToggleDone;
  final List<DswMenuEntry> Function(PlanObject record)? rowMenu;
  final PlanLinkedName? linkedName;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final step = MediaQuery.textScalerOf(context).scale(1);
    final seat = planRowSeat(context);
    final columns = planVisibleColumns(viewer);
    final total =
        planNameColumnWidth * step +
        columns.fold<double>(
          0,
          (sum, column) => sum + _columnWidth(context, column),
        );

    Widget headerCell(PlanViewerRelation column) {
      final relation = relationsByKey[column.key];
      final activeSort = viewer.sorts
          .where((sort) => sort.relationKey == column.key)
          .toList();
      return _Cell(
        width: _columnWidth(context, column),
        header: true,
        menu: [
          DswMenuEntry(
            label: AppLocalizations.of(context).planSortAsc,
            icon: LucideIcons.arrow_up,
            onTap: () => onSortColumn(column.key, PlanSortType.asc),
          ),
          DswMenuEntry(
            label: AppLocalizations.of(context).planSortDesc,
            icon: LucideIcons.arrow_down,
            onTap: () => onSortColumn(column.key, PlanSortType.desc),
          ),
          if (activeSort.isNotEmpty)
            DswMenuEntry(
              label: AppLocalizations.of(context).planSortClear,
              icon: LucideIcons.arrow_up_down,
              onTap: () => onSortColumn(column.key, PlanSortType.custom),
            ),
          const DswMenuEntry.divider(),
          DswMenuEntry(
            label: AppLocalizations.of(context).planHideField,
            icon: LucideIcons.eye_off,
            onTap: () => onHideColumn(column.key),
          ),
        ],
        child: Row(
          children: [
            Flexible(
              child: Text(
                relation?.name ?? column.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.xxxsStrong11.copyWith(
                  color: color.labelTertiary,
                ),
              ),
            ),
            if (activeSort.isNotEmpty &&
                activeSort.first.type != PlanSortType.custom)
              Padding(
                padding: const EdgeInsets.only(left: DswShape.xs),
                child: Icon(
                  activeSort.first.type == PlanSortType.asc
                      ? LucideIcons.arrow_up
                      : LucideIcons.arrow_down,
                  size: DswShape.iconCaption,
                  color: color.labelTertiary,
                ),
              ),
          ],
        ),
      );
    }

    Widget nameHeader() => _Cell(
      header: true,
      width: planNameColumnWidth * step,
      child: Text(
        AppLocalizations.of(context).planFieldName,
        style: DswType.xxxsStrong11.copyWith(color: color.labelTertiary),
      ),
    );

    Widget cellFor(PlanObject record, PlanViewerRelation column) =>
        PlanCellValue(
          object: record,
          relation: relationsByKey[column.key],
          viewerRelation: column,
          linkedName: linkedName,
          onToggleCheckbox: () => onToggleDone(record.id),
        );

    Widget row(PlanObject record) {
      final done = record.isDone;
      return Row(
        children: [
          _Cell(
            width: planNameColumnWidth * step,
            onTap: () => onCellTap(record, PlanRelationKeys.name),
            menu: rowMenu?.call(record),
            child: _NameCell(
              record: record,
              onToggleDone: () => onToggleDone(record.id),
              strike: done,
            ),
          ),
          for (final column in columns)
            _Cell(
              width: _columnWidth(context, column),
              onTap: () => onCellTap(record, column.key),
              child:
                  wrapCell?.call(record, column, cellFor(record, column)) ??
                  cellFor(record, column),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: seat,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: total,
              child: Row(children: [nameHeader(), ...columns.map(headerCell)]),
            ),
          ),
        ),
        SizedBox(height: 1, child: ColoredBox(color: color.borderL2)),
        Expanded(
          // Rows scroll vertically; a multi-value cell (tag badges wrapping)
          // owns its second line, so the row grows from the seat
          // (`BoxConstraints(minHeight:)` below) and the scroll view — not a
          // fixed seat — takes the growth.
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: total,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final record in records)
                      ConstrainedBox(
                        constraints: BoxConstraints(minHeight: seat),
                        child: row(record),
                      ),
                    if (records.isEmpty)
                      SizedBox(
                        height: seat,
                        child: _EmptyRow(width: total),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(DswShape.sm),
                        child: CapsuleButton(
                          label: AppLocalizations.of(context).planNewRow,
                          icon: LucideIcons.plus,
                          size: CapsuleSize.sm,
                          enabled: onAddRow != null,
                          onTap: onAddRow ?? () {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NameCell extends StatelessWidget {
  const _NameCell({
    required this.record,
    required this.onToggleDone,
    required this.strike,
  });

  final PlanObject record;
  final VoidCallback onToggleDone;
  final bool strike;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final task = record.typeKey == PlanObjectTypeIds.task;
    final style = DswType.s14.copyWith(
      color: strike ? color.labelTertiary : color.labelPrimary,
      decoration: strike ? TextDecoration.lineThrough : null,
      decorationColor: color.labelTertiary,
    );
    return Row(
      children: [
        if (task) ...[
          PlanCheckbox(checked: record.isDone, onTap: onToggleDone),
          const SizedBox(width: DswShape.sm),
        ] else ...[
          Icon(
            _iconFor(record.typeKey),
            size: DswShape.iconTiny,
            color: color.labelTertiary,
          ),
          const SizedBox(width: DswShape.sm),
        ],
        Expanded(
          child: Text(
            record.name.isEmpty
                ? AppLocalizations.of(context).planUntitled
                : record.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }

  static IconData _iconFor(String typeKey) => switch (typeKey) {
    PlanObjectTypeIds.note => LucideIcons.pencil,
    PlanObjectTypeIds.bookmark => LucideIcons.bookmark,
    PlanObjectTypeIds.image => LucideIcons.image,
    PlanObjectTypeIds.task => LucideIcons.circle,
    _ => LucideIcons.file,
  };
}

class _EmptyRow extends StatelessWidget {
  const _EmptyRow({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(left: DswShape.sm),
        child: Text(
          AppLocalizations.of(context).planNoRecords,
          style: DswType.xs13.copyWith(color: context.dsw.labelTertiary),
        ),
      ),
    ),
  );
}

/// The List viewer. Upstream gives it three row shapes and the task row is the
/// one with a checkbox (`Viewer.kt:110-126`); a profile row shows its object
/// relation, everything else is the plain title row.
class PlanListViewer extends StatelessWidget {
  const PlanListViewer({
    super.key,
    required this.viewer,
    required this.records,
    required this.relationsByKey,
    required this.onCellTap,
    this.onAddRow,
    required this.onToggleDone,
    this.rowMenu,
    this.linkedName,
  });

  final PlanViewer viewer;
  final List<PlanObject> records;
  final Map<String, PlanRelation> relationsByKey;
  final PlanCellTap onCellTap;
  final VoidCallback? onAddRow;
  final void Function(String recordId) onToggleDone;
  final List<DswMenuEntry> Function(PlanObject record)? rowMenu;
  final PlanLinkedName? linkedName;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final seat = planRowSeat(context);
    final columns = planVisibleColumns(viewer);
    // The secondary text is the first visible column that is not the title;
    // a one-column list stays a single-line row.
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
      children: [
        for (final record in records)
          SizedBox(
            height: seat,
            child: DswHoverTap(
              onTap: () => onCellTap(record, PlanRelationKeys.name),
              semanticLabel: record.name.isEmpty
                  ? AppLocalizations.of(context).planUntitled
                  : record.name,
              builder: (context, hovered, focused) => Container(
                color: hovered ? color.interactiveBgHover : null,
                padding: const EdgeInsets.symmetric(horizontal: DswShape.md),
                child: Row(
                  children: [
                    if (record.typeKey == PlanObjectTypeIds.task) ...[
                      PlanCheckbox(
                        checked: record.isDone,
                        onTap: () => onToggleDone(record.id),
                      ),
                      const SizedBox(width: DswShape.sm),
                    ],
                    Expanded(
                      child: Text(
                        record.name.isEmpty
                            ? AppLocalizations.of(context).planUntitled
                            : record.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DswType.s14.copyWith(
                          color: record.isDone
                              ? color.labelTertiary
                              : color.labelPrimary,
                          decoration: record.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: DswShape.md),
                    for (final column in columns.where(
                      (c) => c.key != PlanRelationKeys.name,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(right: DswShape.md),
                        child: SizedBox(
                          width: _columnWidth(context, column),
                          child: PlanCellValue(
                            object: record,
                            relation: relationsByKey[column.key],
                            viewerRelation: column,
                            linkedName: linkedName,
                            onToggleCheckbox: () => onToggleDone(record.id),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(DswShape.sm),
          child: CapsuleButton(
            label: AppLocalizations.of(context).planNewRow,
            icon: LucideIcons.plus,
            size: CapsuleSize.sm,
            enabled: onAddRow != null,
            onTap: onAddRow ?? () {},
          ),
        ),
      ],
    );
  }
}

/// The Gallery viewer: a card per record, cover from the viewer's
/// `coverRelationKey`, size from `cardSize` (`Block.kt:284-287`).
class PlanGalleryViewer extends StatelessWidget {
  const PlanGalleryViewer({
    super.key,
    required this.viewer,
    required this.records,
    required this.relationsByKey,
    required this.onCellTap,
    required this.onAddRow,
  });

  final PlanViewer viewer;
  final List<PlanObject> records;
  final Map<String, PlanRelation> relationsByKey;
  final PlanCellTap onCellTap;
  final VoidCallback? onAddRow;

  double _cardExtent(BuildContext context) {
    final step = MediaQuery.textScalerOf(context).scale(1);
    final base = switch (viewer.cardSize) {
      PlanViewerSize.small => 160.0,
      PlanViewerSize.medium => 220.0,
      PlanViewerSize.large => 300.0,
    };
    return base * step;
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final extent = _cardExtent(context);
    return ListView(
      padding: const EdgeInsets.all(DswShape.md),
      children: [
        Wrap(
          spacing: DswShape.md,
          runSpacing: DswShape.md,
          children: [
            for (final record in records)
              SizedBox(
                width: extent,
                height: extent * 0.72,
                child: _GalleryCard(
                  record: record,
                  viewer: viewer,
                  relationsByKey: relationsByKey,
                  onTap: () => onCellTap(record, PlanRelationKeys.name),
                ),
              ),
            SizedBox(
              width: extent,
              // The capsule scales its own height with the text step
              // (capsule_button.dart:87); the box around it must not clamp
              // that seat back to the 1.0 pixel value.
              height:
                  DswShape.controlMd *
                  MediaQuery.textScalerOf(context).scale(1),
              child: CapsuleButton(
                label: AppLocalizations.of(context).planNewRow,
                icon: LucideIcons.plus,
                size: CapsuleSize.sm,
                enabled: onAddRow != null,
                onTap: onAddRow ?? () {},
              ),
            ),
          ],
        ),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: DswShape.md),
            child: Text(
              AppLocalizations.of(context).planNoRecords,
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
          ),
      ],
    );
  }
}

class _GalleryCard extends StatelessWidget {
  const _GalleryCard({
    required this.record,
    required this.viewer,
    required this.relationsByKey,
    required this.onTap,
  });

  final PlanObject record;
  final PlanViewer viewer;
  final Map<String, PlanRelation> relationsByKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final cover = viewer.coverRelationKey;
    final coverValue = cover == null ? null : record.text(cover);
    // The card's second line is the viewer's first non-title column — the same
    // answer the grid gives in its second cell, not a type label.
    final detail = viewer.relations.firstWhere(
      (column) => column.isVisible && column.key != PlanRelationKeys.name,
      orElse: () => const PlanViewerRelation(key: ''),
    );
    final detailKey = detail.key;
    final detailColumn = detailKey.isEmpty ? null : detail;
    // The header band takes the colour of the record's first option value —
    // the same reading the grid's status badge gives.
    PlanRelation? optionRelation;
    for (final relation in relationsByKey.values) {
      if (relation.format.hasOptions && record.hasRelation(relation.key)) {
        optionRelation = relation;
        break;
      }
    }
    final held = optionRelation == null
        ? const <String>[]
        : record.options(optionRelation.key);
    final bandColor = planLadderColor(
      color,
      held.isEmpty ? null : optionRelation!.option(held.first)?.colorIndex,
    );
    return DswHoverTap(
      onTap: onTap,
      semanticLabel: record.name,
      builder: (context, hovered, focused) => Container(
        decoration: BoxDecoration(
          color: color.bgLayer1,
          borderRadius: BorderRadius.circular(DswShape.card),
          border: Border.all(
            color: hovered ? color.borderL3 : color.borderL2,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: DswShape.md * 3,
              child: coverValue == null
                  ? ColoredBox(color: bandColor)
                  : ColoredBox(
                      color: color.bgLayer3,
                      child: Row(
                        children: [
                          const SizedBox(width: DswShape.sm),
                          Icon(
                            LucideIcons.image,
                            size: DswShape.iconSm,
                            color: color.labelTertiary,
                          ),
                          const SizedBox(width: DswShape.xs),
                          Expanded(
                            child: Text(
                              coverValue.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DswType.xxxs11.copyWith(
                                color: color.labelTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(DswShape.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!viewer.hideIcon)
                    PlanCellValue(
                      object: record,
                      relation: relationsByKey[detailKey],
                      viewerRelation: detailColumn,
                    ),
                  const SizedBox(height: DswShape.xs),
                  Text(
                    record.name.isEmpty
                        ? AppLocalizations.of(context).planUntitled
                        : record.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.s14.copyWith(color: color.labelPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calendar and Graph: the kind is real, the client's answer is this card
/// (inventory §1 and §17). Copy names the two ways out, exactly as upstream's
/// strings do.
class PlanUnsupportedViewer extends StatelessWidget {
  const PlanUnsupportedViewer({super.key, required this.kind});

  final PlanViewerKind kind;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(DswShape.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                kind == PlanViewerKind.calendar
                    ? LucideIcons.calendar_x
                    : LucideIcons.network,
                size: DswShape.iconLg + DswShape.sm,
                color: color.labelTertiary,
              ),
              const SizedBox(height: DswShape.md),
              Text(
                trKey(
                  AppLocalizations.of(context),
                  kind.unsupportedL10nKey ?? 'planViewGraphUnsupported',
                ),
                textAlign: TextAlign.center,
                style: DswType.xs13.copyWith(color: color.labelSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The checkbox a task row leads with, reused by the board card.
class PlanCheckbox extends StatelessWidget {
  const PlanCheckbox({super.key, required this.checked, this.onTap});

  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: onTap,
      toggled: checked,
      semanticLabel: checked
          ? AppLocalizations.of(context).planCellChecked
          : AppLocalizations.of(context).planCellUnchecked,
      builder: (context, hovered, focused) => checked
          ? Container(
              width: DswShape.iconSm,
              height: DswShape.iconSm,
              decoration: BoxDecoration(
                color: color.brandPrimary,
                borderRadius: BorderRadius.circular(DswShape.inset),
              ),
              child: Icon(
                LucideIcons.check,
                size: DswShape.iconCaption + 2,
                color: color.labelPrimaryForeground,
              ),
            )
          : Icon(
              LucideIcons.square,
              size: DswShape.iconSm,
              color: hovered || focused
                  ? color.labelSecondary
                  : color.labelTertiary,
            ),
    );
  }
}
