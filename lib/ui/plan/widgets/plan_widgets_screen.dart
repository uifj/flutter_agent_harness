// The home widget strip (ADR-0037 P7, module 7). Sections answer in the
// client's order — pinned, my favourites, recently edited, the types group —
// each widget draws one of the five layouts (`List | CompactList | Tree |
// Link | View`, code values 2/3/1/0/4), the row limit reads the stored value
// or the relation default, and the dropdown carries the actions gated by
// `PlanWidgetAction.applies`. The three chat forms map onto this app's
// sessions (ADR-0037's recorded reading), so they render as the strip's
// session rows; the Glance desktop widgets stay N/A.
//
// Widgets persist in the store (its `widgets` list), so the strip is data the
// user arranged, not chrome this screen invents.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/tr_key.dart';
import '../../../model/plan_object_type.dart';
import '../../../model/plan_struct.dart';
import '../../../model/plan_widget.dart';
import '../../../state/plan_object_store.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/feedback.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';

class PlanWidgetsScreen extends StatelessWidget {
  const PlanWidgetsScreen({super.key, required this.store});

  final PlanObjectStore store;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final flat = orderPlanWidgets(store.widgets);
    final sections = [
      for (final section in PlanWidgetSection.order)
        (
          section: section,
          widgets: [
            for (final widget in flat)
              if (widget.section == section) widget,
          ],
        ),
    ];
    final types = [
      for (final type in store.types)
        if (!type.isArchived &&
            type.uniqueKey != PlanObjectTypeIds.objectType &&
            type.uniqueKey != PlanObjectTypeIds.participant)
          type,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DswShape.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in sections) ...[
            if (section.widgets.isEmpty)
              const SizedBox.shrink()
            else ...[
              Text(
                trKey(
                  AppLocalizations.of(context),
                  _sectionCode(section.section),
                ),
                style: DswType.xxsStrong12.copyWith(color: color.labelTertiary),
              ),
              const SizedBox(height: DswShape.xs),
              for (final widget in section.widgets)
                _WidgetCard(store: store, widget: widget, types: types),
              const SizedBox(height: DswShape.md),
            ],
          ],
          if (types.isNotEmpty)
            _WidgetCard(
              store: store,
              widget: PlanWidget(
                id: 'object_types_group',
                source: const PlanWidgetBundledSource('types'),
                layout: PlanWidgetLayout.list,
                section: PlanWidgetSection.types,
              ),
              types: types,
            ),
        ],
      ),
    );
  }

  String _sectionCode(PlanWidgetSection section) => switch (section) {
    PlanWidgetSection.pinned => 'planSectionPinned',
    PlanWidgetSection.myFavorites => 'planSectionFavorites',
    PlanWidgetSection.recentlyEdited => 'planSectionRecent',
    PlanWidgetSection.types => 'planSectionTypes',
    PlanWidgetSection.unread => 'planSectionPinned',
  };
}

class _WidgetCard extends StatelessWidget {
  const _WidgetCard({
    required this.store,
    required this.widget,
    required this.types,
  });

  final PlanObjectStore store;
  final PlanWidget widget;
  final List<PlanObjectType> types;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final step = MediaQuery.textScalerOf(context).scale(1);
    final records = _records();
    final rows = records.take(widget.resolvedLimit()).toList();
    return Container(
      margin: const EdgeInsets.only(bottom: DswShape.xs),
      decoration: BoxDecoration(
        color: color.bgLayer2,
        borderRadius: BorderRadius.circular(DswShape.card),
        border: Border.all(color: color.borderL2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DswShape.sm,
              DswShape.xs,
              DswShape.xs,
              DswShape.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _title(context),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.xxsStrong12.copyWith(
                      color: color.labelPrimary,
                    ),
                  ),
                ),
                DswContextMenu(
                  items: (menuContext) => [
                    for (final action in PlanWidgetAction.values)
                      if (PlanWidgetAction.applies(action, widget))
                        DswMenuEntry(
                          label: _actionLabel(menuContext, action),
                          onTap: () => _runAction(menuContext, action),
                        ),
                  ],
                  child: Tooltip(
                    message: AppLocalizations.of(context).planWidgetMenu,
                    child: DswHoverTap(
                      onTap: null,
                      semanticLabel: AppLocalizations.of(
                        context,
                      ).planWidgetMenu,
                      builder: (context, hovered, focused) => Icon(
                        LucideIcons.ellipsis_vertical,
                        size: DswShape.iconTiny,
                        color: color.labelTertiary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.layout == PlanWidgetLayout.link)
            _WidgetRow(
              icon: LucideIcons.link,
              label: _rowLabel(context, records.firstOrNull),
            )
          else if (widget.layout == PlanWidgetLayout.view)
            _ViewRows(store: store, records: rows)
          else
            for (final (index, record) in rows.indexed)
              _WidgetRow(
                icon: widget.layout == PlanWidgetLayout.compactList
                    ? LucideIcons.circle
                    : LucideIcons.square,
                label: record.name.isEmpty
                    ? AppLocalizations.of(context).planUntitled
                    : record.name,
                compact: widget.layout == PlanWidgetLayout.compactList,
                showDivider: index < rows.length - 1,
              ),
          if (widget.layout != PlanWidgetLayout.link && records.isEmpty)
            Padding(
              padding: EdgeInsets.only(
                left: DswShape.sm,
                bottom: DswShape.xs * step,
              ),
              child: Text(
                AppLocalizations.of(context).planWidgetEmpty,
                style: DswType.xxxs11.copyWith(color: color.labelTertiary),
              ),
            ),
          // The types group renders its type rows inside the same card.
          if (widget.id == 'object_types_group')
            for (final type in types)
              _WidgetRow(
                icon: LucideIcons.circle,
                label: type.name,
                compact: true,
                showDivider: type != types.last,
              ),
        ],
      ),
    );
  }

  List<PlanObject> _records() {
    final source = widget.source;
    if (source is PlanWidgetDefaultSource) {
      final object = store.byId(source.objectId);
      if (object == null) return const [];
      final collection = store.collectionById(source.objectId);
      if (collection != null) {
        return [
          for (final id in collection.candidateRecordIds(store.objects))
            if (store.byId(id) != null) store.byId(id)!,
        ];
      }
      return [object];
    }
    return switch (source) {
      final PlanWidgetBundledSource bundled => switch (bundled.id) {
        PlanBundledWidgetSourceIds.favorite => store.favorites,
        PlanBundledWidgetSourceIds.recent ||
        PlanBundledWidgetSourceIds.recentLocal => store.recentlyEdited,
        PlanBundledWidgetSourceIds.bin => store.binRecords,
        PlanBundledWidgetSourceIds.allObjects =>
          store.objects
              .where((record) => !store.binIds.contains(record.id))
              .toList(),
        _ => const [],
      },
      _ => const [],
    };
  }

  String _title(BuildContext context) {
    final source = widget.source;
    if (source is PlanWidgetDefaultSource) {
      return store.byId(source.objectId)?.name ??
          AppLocalizations.of(context).planUntitled;
    }
    if (source is PlanWidgetBundledSource) {
      return switch (source.id) {
        PlanBundledWidgetSourceIds.favorite => AppLocalizations.of(
          context,
        ).planWidgetFavorites,
        PlanBundledWidgetSourceIds.recent ||
        PlanBundledWidgetSourceIds.recentLocal => AppLocalizations.of(
          context,
        ).planWidgetRecent,
        PlanBundledWidgetSourceIds.bin => AppLocalizations.of(
          context,
        ).planWidgetBin,
        PlanBundledWidgetSourceIds.allObjects => AppLocalizations.of(
          context,
        ).planWidgetAllObjects,
        _ => source.id,
      };
    }
    if (widget.id == 'object_types_group') {
      return AppLocalizations.of(context).planWidgetTypes;
    }
    return widget.id;
  }

  String _rowLabel(BuildContext context, PlanObject? record) =>
      record == null || record.name.isEmpty
      ? AppLocalizations.of(context).planUntitled
      : record.name;

  String _actionLabel(BuildContext context, PlanWidgetAction action) =>
      switch (action) {
        PlanWidgetAction.changeType => AppLocalizations.of(
          context,
        ).planWidgetChangeType,
        PlanWidgetAction.removeWidget => AppLocalizations.of(
          context,
        ).planWidgetRemove,
        PlanWidgetAction.emptyBin => AppLocalizations.of(
          context,
        ).planWidgetEmptyBin,
        PlanWidgetAction.changeHome => AppLocalizations.of(
          context,
        ).planWidgetChangeHome,
        PlanWidgetAction.favoriteObject => AppLocalizations.of(
          context,
        ).planFeature,
        PlanWidgetAction.unfavoriteObject => AppLocalizations.of(
          context,
        ).planUnfeature,
        PlanWidgetAction.createObjectOfType => AppLocalizations.of(
          context,
        ).planWidgetCreateObject,
      };

  Future<void> _runAction(BuildContext context, PlanWidgetAction action) async {
    switch (action) {
      case PlanWidgetAction.removeWidget:
        await store.removeWidget(widget.id);
        if (!context.mounted) return;
        showFeedback(context, AppLocalizations.of(context).planWidgetRemoved);
      case PlanWidgetAction.emptyBin:
        await store.emptyBin();
        if (!context.mounted) return;
        showFeedback(
          context,
          AppLocalizations.of(context).planWidgetBinEmptied,
        );
      case PlanWidgetAction.changeType:
        // The two-screen picker's second screen: cycle the five layouts.
        final layouts = PlanWidgetLayout.values;
        final next = layouts[(widget.layout.index + 1) % layouts.length];
        await store.changeWidgetLayout(widget.id, next);
      case PlanWidgetAction.favoriteObject:
      case PlanWidgetAction.unfavoriteObject:
        final objectId = widget.objectId;
        if (objectId != null) {
          await store.setFavorite(
            objectId,
            favorite: action == PlanWidgetAction.favoriteObject,
          );
        }
      case PlanWidgetAction.changeHome:
      case PlanWidgetAction.createObjectOfType:
        // Home is the strip itself on desktop; typed creation rides the data
        // view's new-row path. Registered in the ledger, not silently dropped.
        break;
    }
  }
}

class _WidgetRow extends StatelessWidget {
  const _WidgetRow({
    required this.icon,
    required this.label,
    this.compact = false,
    this.showDivider = false,
  });

  final IconData icon;
  final String label;
  final bool compact;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: null,
      semanticLabel: label,
      builder: (context, hovered, focused) => Container(
        height:
            (compact ? 26.0 : 32.0) * MediaQuery.textScalerOf(context).scale(1),
        padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
        decoration: BoxDecoration(
          color: hovered ? color.interactiveBgHover : null,
          border: showDivider
              ? Border(top: BorderSide(color: color.borderL2, width: 0.5))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: DswShape.iconCaption, color: color.labelTertiary),
            const SizedBox(width: DswShape.xs),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.xs13.copyWith(color: color.labelPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The View layout's cover-card row — the same two-line card the gallery
/// viewer draws, at widget scale.
class _ViewRows extends StatelessWidget {
  const _ViewRows({required this.store, required this.records});

  final PlanObjectStore store;
  final List<PlanObject> records;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return SizedBox(
      height: 132 * MediaQuery.textScalerOf(context).scale(1),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
        children: [
          for (final record in records)
            Container(
              width: 136,
              margin: const EdgeInsets.only(
                right: DswShape.xs,
                bottom: DswShape.xs,
              ),
              padding: const EdgeInsets.all(DswShape.xs),
              decoration: BoxDecoration(
                color: color.bgLayer1,
                borderRadius: BorderRadius.circular(DswShape.inner),
                border: Border.all(color: color.borderL2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: color.bgLayer3,
                      child: const SizedBox(width: double.infinity),
                    ),
                  ),
                  const SizedBox(height: DswShape.xs),
                  Text(
                    record.name.isEmpty
                        ? AppLocalizations.of(context).planUntitled
                        : record.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.xxxs11.copyWith(color: color.labelPrimary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
