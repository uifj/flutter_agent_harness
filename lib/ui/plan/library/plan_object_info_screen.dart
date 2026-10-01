// The object info screen (ADR-0037 P6, module 5): the relations a record
// carries, in the segments the client answers — featured first, then the
// record's own "local" keys (on the record, not in the type's recommended
// list — FieldParser's reading, `FieldParser.kt:298-304`), then the hidden
// ones. The file segment stays out: upstream turns it off with `if (false)`
// (`RelationListViewModel.kt:204-208`) and the "edit mode" button there is
// commented-out dead code, so neither is drawn.
//
// Every row's value is the same cell the data view draws, wrapped in the same
// editor — the two surfaces cannot answer differently (the ADR-0035 law, one
// reader per answer).

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/locales.dart';
import '../../../model/plan_dataview.dart' show PlanViewerRelation;
import '../../../model/plan_relation.dart';
import '../../../model/plan_struct.dart';
import '../../../state/plan_object_store.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/confirm_dialog.dart';
import '../../primitives/feedback.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';
import '../dataview/plan_cell_value.dart' show PlanCellValue;
import '../dataview/plan_viewer_sheets.dart' show PlanCellEditor;

class PlanObjectInfoScreen extends StatelessWidget {
  const PlanObjectInfoScreen({
    super.key,
    required this.store,
    required this.recordId,
  });

  final PlanObjectStore store;
  final String recordId;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final record = store.byId(recordId);
    if (record == null) {
      return Center(
        child: Text(
          context.tr('planCollectionMissing'),
          style: DswType.xs13.copyWith(color: color.labelTertiary),
        ),
      );
    }
    final type = store.types
        .where((t) => t.uniqueKey == record.typeKey)
        .firstOrNull;
    final recommended = {...?type?.recommendedRelationKeys};
    final segments = _segments(record, recommended);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DswShape.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (record.text('iconEmoji') case final emoji?)
                Text(emoji, style: DswType.l20)
              else
                Icon(
                  LucideIcons.circle,
                  size: DswShape.iconMd,
                  color: color.labelTertiary,
                ),
              const SizedBox(width: DswShape.sm),
              Expanded(
                child: Text(
                  record.name.isEmpty
                      ? context.tr('planUntitled')
                      : record.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DswType.l20.copyWith(color: color.labelPrimary),
                ),
              ),
            ],
          ),
          for (final (titleCode, rows) in segments) ...[
            if (rows.isEmpty) ...[
              const SizedBox.shrink(),
            ] else ...[
              const SizedBox(height: DswShape.md),
              Text(
                context.tr(titleCode),
                style: DswType.xxsStrong12.copyWith(color: color.labelTertiary),
              ),
              for (final relation in rows)
                _RelationRow(
                  store: store,
                  recordId: recordId,
                  relation: relation,
                ),
            ],
          ],
          const SizedBox(height: DswShape.md),
          _AddRelationRow(store: store, recordId: recordId),
        ],
      ),
    );
  }

  /// (title i18n code, rows) in the order the screen draws them. A row needs
  /// a known relation — a bare struct key with no relation behind it shows in
  /// Local with the scalar the cell renders.
  List<(String, List<PlanRelation?>)> _segments(
    PlanObject record,
    Set<String> recommended,
  ) {
    final relations = store.relationsByKey;
    final featured = <PlanRelation?>[];
    final local = <PlanRelation?>[];
    final hidden = <PlanRelation?>[];
    for (final key in record.struct.keys) {
      if (key == PlanRelationKeys.name || key == PlanRelationKeys.type) {
        continue;
      }
      final relation = relations[key];
      if (relation?.hidden ?? false) {
        hidden.add(relation);
      } else if (relation?.featured ?? false) {
        featured.add(relation);
      } else if (!recommended.contains(key)) {
        local.add(relation);
      }
    }
    // The type's recommended relations are offerable even when the record
    // does not carry them yet — the Hidden segment is where upstream keeps
    // them (`FieldParser.kt:286-288`).
    for (final relation in store.relations) {
      if (relation.hidden &&
          !record.struct.keys.contains(relation.key) &&
          !hidden.any((row) => row?.key == relation.key)) {
        hidden.add(relation);
      }
    }
    return [
      ('planSegmentFeatured', featured),
      ('planSegmentLocal', local),
      ('planSegmentHidden', hidden),
    ];
  }
}

class _RelationRow extends StatelessWidget {
  const _RelationRow({
    required this.store,
    required this.recordId,
    required this.relation,
  });

  final PlanObjectStore store;
  final String recordId;
  final PlanRelation? relation;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final record = store.byId(recordId)!;
    final relation = this.relation;
    final key = relation?.key ?? '';
    final cell = PlanCellValue(
      object: record,
      relation: relation,
      viewerRelation: const PlanViewerRelation(key: ''),
    );
    return Padding(
      padding: const EdgeInsets.only(top: DswShape.xs),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(
              relation?.name ?? key,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
          ),
          Expanded(
            child: relation == null
                ? Align(alignment: Alignment.centerLeft, child: cell)
                : PlanCellEditor(
                    record: record,
                    relation: relation,
                    onWrite: (value) =>
                        store.amendRecord(recordId, {key: value}),
                    onClear: () => store.unsetRecord(recordId, [key]),
                    child: Align(alignment: Alignment.centerLeft, child: cell),
                  ),
          ),
          if (relation != null)
            DswContextMenu(
              items: (menuContext) => [
                DswMenuEntry(
                  label: context.tr(
                    relation.featured ? 'planUnfeature' : 'planFeature',
                  ),
                  icon: LucideIcons.star,
                  onTap: () => store.setRelationFeatured(
                    relation.key,
                    featured: !relation.featured,
                  ),
                ),
                DswMenuEntry(
                  label: context.tr(
                    relation.hidden ? 'planUnhide' : 'planHide',
                  ),
                  icon: LucideIcons.eye_off,
                  onTap: () => store.setRelationHidden(
                    relation.key,
                    hidden: !relation.hidden,
                  ),
                ),
                DswMenuEntry(
                  label: context.tr('planRemoveRelation'),
                  icon: LucideIcons.trash,
                  destructive: true,
                  onTap: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: context.tr('planRemoveRelation'),
                      description: relation.name,
                      confirmLabel: context.tr('planActionDelete'),
                    );
                    if (!confirmed) return;
                    await store.unsetRecord(recordId, [relation.key]);
                    if (!menuContext.mounted) return;
                    showFeedback(
                      menuContext,
                      context.tr('planRelationRemoved'),
                    );
                  },
                ),
              ],
              child: Tooltip(
                message: context.tr('planRelationActions'),
                child: DswHoverTap(
                  onTap: null,
                  semanticLabel: context.tr('planRelationActions'),
                  builder: (context, hovered, focused) => Padding(
                    padding: const EdgeInsets.only(left: DswShape.xs),
                    child: Icon(
                      LucideIcons.ellipsis_vertical,
                      size: DswShape.iconTiny,
                      color: color.labelTertiary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddRelationRow extends StatelessWidget {
  const _AddRelationRow({required this.store, required this.recordId});

  final PlanObjectStore store;
  final String recordId;

  Future<void> _add(BuildContext context, PlanRelation relation) async {
    // A checkbox lands as false, a multi-value as an empty list, everything
    // else as an empty scalar — the same normalised empties the dataview's
    // new-row path seeds.
    final value = switch (relation.format) {
      PlanRelationFormat.checkbox => false,
      PlanRelationFormat.tag ||
      PlanRelationFormat.file ||
      PlanRelationFormat.object => <String>[],
      _ => '',
    };
    await store.amendRecord(recordId, {relation.key: value});
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final record = store.byId(recordId)!;
    final offerable = [
      for (final relation in store.relations)
        if (!relation.hidden &&
            !record.struct.keys.contains(relation.key) &&
            relation.key != PlanRelationKeys.name)
          relation,
    ];
    if (offerable.isEmpty) return const SizedBox.shrink();
    return DswContextMenu(
      items: (_) => [
        for (final relation in offerable)
          DswMenuEntry(
            label: relation.name,
            onTap: () => _add(context, relation),
          ),
      ],
      child: DswHoverTap(
        onTap: null,
        semanticLabel: context.tr('planAddRelation'),
        builder: (context, hovered, focused) => Padding(
          padding: const EdgeInsets.only(top: DswShape.sm),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.plus,
                size: DswShape.iconTiny,
                color: color.labelTertiary,
              ),
              const SizedBox(width: DswShape.xs),
              Text(
                context.tr('planAddRelation'),
                style: DswType.xs13.copyWith(color: color.labelTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
