// The collection screen (ADR-0037 P3): one plan collection, its viewer strip,
// its configuration sheets and its cells.
//
// The store arrives as a constructor argument, not through a provider:
// `check_architecture` rule 6 keeps riverpod in `main.dart` +
// `app_providers.dart`, and this is the same seam the plan screens use.
//
// Two local rules. First, the panel LISTENS: the store is the only truth, and a
// surface that reads it without subscribing is the bug ADR-0007 already recorded
// once (the table drew `store.tasks` and never refreshed). Second, every
// affordance is gated on the collection's `DataViewRestriction` set — a
// read-only space loses the "+", the menus and the editor, because the
// restriction is data the model carries, not a judgement this widget makes.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadButton, ShadDialog, ShadInput, showShadDialog;

import '../../../l10n/locales.dart';
import '../../../model/plan_dataview.dart';
import '../../../model/plan_object_type.dart';
import '../../../model/plan_relation.dart';
import '../../../model/plan_struct.dart';
import '../../../state/plan_object_store.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_shad_bridge.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/confirm_dialog.dart';
import '../../primitives/feedback.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';
import 'plan_board_viewer.dart';
import 'plan_calendar_viewer.dart';
import 'plan_cell_value.dart';
import 'plan_viewer_bar.dart';
import 'plan_viewer_sheets.dart';
import 'plan_viewers.dart';

class PlanDataViewScreen extends StatefulWidget {
  const PlanDataViewScreen({
    super.key,
    required this.store,
    required this.collectionId,
  });

  final PlanObjectStore store;
  final String collectionId;

  @override
  State<PlanDataViewScreen> createState() => _PlanDataViewScreenState();
}

class _PlanDataViewScreenState extends State<PlanDataViewScreen> {
  /// The header (icon, name, description) is chrome the user can hide —
  /// upstream's "toggle header" in the view's right-click area.
  bool _headerVisible = true;

  @override
  void initState() {
    super.initState();
    // Refcounted: a second screen on the same collection does not duplicate
    // state, and this one releases on dispose.
    widget.store.subscribe(widget.collectionId);
    widget.store.addListener(_onStoreChanged);
  }

  @override
  void didUpdateWidget(PlanDataViewScreen old) {
    super.didUpdateWidget(old);
    if (old.collectionId != widget.collectionId) {
      widget.store.unsubscribe(old.collectionId);
      widget.store.subscribe(widget.collectionId);
    }
  }

  @override
  void dispose() {
    widget.store.removeListener(_onStoreChanged);
    widget.store.unsubscribe(widget.collectionId);
    super.dispose();
  }

  void _onStoreChanged() => setState(() {});

  PlanObjectStore get _store => widget.store;

  PlanCollection? get _collection => _store.collectionById(widget.collectionId);

  @override
  Widget build(BuildContext context) {
    final collection = _collection;
    if (collection == null) {
      return ColoredBox(
        color: context.dsw.bgBase,
        child: Center(
          child: Text(
            context.tr('planCollectionMissing'),
            style: DswType.s14.copyWith(color: context.dsw.labelSecondary),
          ),
        ),
      );
    }

    final stage = _store.stageFor(widget.collectionId);
    final viewer = stage.viewer;
    final relations = _store.relations;
    final relationsByKey = _store.relationsByKey;
    final canManage = !collection.restrictions.contains(
      PlanDataViewRestriction.views,
    );
    final canCreate = !collection.restrictions.contains(
      PlanDataViewRestriction.createObject,
    );

    return ColoredBox(
      color: context.dsw.bgBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_headerVisible)
            _CollectionHeader(
              collection: collection,
              count: stage.records.length,
              canRename: canManage,
              onRename: () async {
                final name = await _askName(
                  context,
                  title: context.tr('planRenameCollection'),
                  initial: collection.name,
                );
                if (name == null || name.isEmpty) return;
                await _store.renameCollection(collection.id, name);
              },
            ),
          PlanViewerBar(
            viewers: collection.dataView.viewers,
            activeId: viewer?.id,
            canManage: canManage,
            onSelect: (id) => _store.setActiveViewer(collection.id, id),
            onAdd: (kind) => _store.addViewer(collection.id, kind),
            onMenu: (action, id) => _onViewerMenu(action, id, collection),
            onOpenSettings: () {},
            onToggleHeader: () =>
                setState(() => _headerVisible = !_headerVisible),
          ),
          _SheetBar(
            viewer: viewer,
            advancedCount: stage.advancedFilterCount,
            // Every sheet edits the view (sorts, filters, visible columns,
            // layout land on the viewer), so `views` is the restriction that
            // takes them away; adding relations is gated at the cell instead.
            canManage: canManage,
            sheets: [
              if (viewer != null && viewer.kind.renderedByClient)
                DswSheetPopover(
                  label: context.tr('planFieldsTitle'),
                  minWidth: 320,
                  trigger: (context) => PlanSheetTrigger(
                    icon: LucideIcons.list,
                    label: context.tr('planFieldsTitle'),
                    count: planVisibleColumns(viewer).length,
                  ),
                  content: (context, close) => PlanFieldsSheet(
                    viewer: viewer,
                    relations: relations,
                    onChange: (columns) => _store.setViewerRelations(
                      collection.id,
                      viewer.id,
                      columns,
                    ),
                  ),
                ),
              if (viewer != null)
                DswSheetPopover(
                  label: context.tr('planSortBy'),
                  minWidth: 280,
                  trigger: (context) => PlanSheetTrigger(
                    icon: LucideIcons.arrow_up_down,
                    label: context.tr('planSortBy'),
                    count: viewer.sorts.length,
                  ),
                  content: (context, close) => PlanSortSheet(
                    viewer: viewer,
                    relations: relations,
                    onChanged: (sorts) =>
                        _store.setViewerSorts(collection.id, viewer.id, sorts),
                  ),
                ),
              if (viewer != null)
                DswSheetPopover(
                  label: context.tr('planFilterTitle'),
                  minWidth: 320,
                  trigger: (context) => PlanSheetTrigger(
                    icon: LucideIcons.sliders_horizontal,
                    label: context.tr('planFilterTitle'),
                    count: viewer.filters.length,
                  ),
                  content: (context, close) => PlanFilterSheet(
                    viewer: viewer,
                    relations: relations,
                    onChanged: (filters) => _store.setViewerFilters(
                      collection.id,
                      viewer.id,
                      filters,
                    ),
                  ),
                ),
              if (viewer != null)
                DswSheetPopover(
                  label: context.tr('planLayoutTitle'),
                  minWidth: 280,
                  trigger: (context) => PlanSheetTrigger(
                    icon: LucideIcons.layers,
                    label: context.tr('planLayoutTitle'),
                    count: 0,
                  ),
                  content: (context, close) => PlanLayoutSheet(
                    viewer: viewer,
                    relations: relations,
                    types: _store.types,
                    templates: _store.templates,
                    onChange: (next) => _store.setViewerLayoutFull(
                      collection.id,
                      viewer.id,
                      next,
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: switch (viewer) {
              null => const SizedBox.shrink(),
              final PlanViewer drawn when !drawn.kind.renderedByClient =>
                PlanUnsupportedViewer(kind: drawn.kind),
              final PlanViewer drawn => _body(
                collection,
                drawn,
                stage,
                relationsByKey,
                canCreate,
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _body(
    PlanCollection collection,
    PlanViewer viewer,
    PlanViewerStage stage,
    Map<String, PlanRelation> relationsByKey,
    bool canCreate,
  ) {
    Widget wrapCell(PlanObject record, PlanViewerRelation column, Widget cell) {
      final relation = relationsByKey[column.key];
      if (relation == null) return cell;
      return PlanCellEditor(
        record: record,
        relation: relation,
        onWrite: (value) => _store.amendRecord(record.id, {column.key: value}),
        onClear: () => _store.unsetRecord(record.id, [column.key]),
        child: cell,
      );
    }

    final recordsById = {for (final record in stage.records) record.id: record};

    return switch (viewer.kind) {
      PlanViewerKind.grid => PlanGridViewer(
        viewer: viewer,
        records: stage.records,
        relationsByKey: relationsByKey,
        wrapCell: wrapCell,
        linkedName: (id) => recordsById[id]?.name ?? _store.byId(id)?.name,
        onCellTap: (record, key) => _openRecord(record, viewer, relationsByKey),
        onAddRow: canCreate ? () => _addRow(collection, viewer) : null,
        onSortColumn: (key, type) => _setSort(collection, viewer, key, type),
        onHideColumn: (key) => _hideColumn(collection, viewer, key),
        onToggleDone: (id) => _store.toggleRecord(id),
        rowMenu: (record) => _rowMenu(collection, record),
      ),
      PlanViewerKind.list => PlanListViewer(
        viewer: viewer,
        records: stage.records,
        relationsByKey: relationsByKey,
        onCellTap: (record, key) => _openRecord(record, viewer, relationsByKey),
        onAddRow: canCreate ? () => _addRow(collection, viewer) : null,
        onToggleDone: (id) => _store.toggleRecord(id),
        linkedName: (id) => recordsById[id]?.name ?? _store.byId(id)?.name,
      ),
      PlanViewerKind.gallery => PlanGalleryViewer(
        viewer: viewer,
        records: stage.records,
        relationsByKey: relationsByKey,
        onCellTap: (record, key) => _openRecord(record, viewer, relationsByKey),
        onAddRow: canCreate ? () => _addRow(collection, viewer) : null,
      ),
      PlanViewerKind.board => PlanBoardViewer(
        viewer: viewer,
        revision: stage.revision,
        groups: stage.groups,
        recordsById: recordsById,
        relationsByKey: relationsByKey,
        groupLabel: (optionId) => _columnTitle(viewer, optionId),
        onMove: (recordId, optionId, index) => _store.moveWithinBoard(
          collectionId: collection.id,
          viewerId: viewer.id,
          recordId: recordId,
          toOptionId: optionId,
          toIndex: index,
        ),
        onReorderColumns: (ids) =>
            _store.setGroupOrder(collection.id, viewer.id, ids),
        onOpen: (record) => _openRecord(record, viewer, relationsByKey),
        onAddToColumn: canCreate
            ? (optionId) => _addRow(collection, viewer, status: optionId)
            : null,
      ),
      PlanViewerKind.calendar => PlanCalendarViewer(
        viewer: viewer,
        records: stage.records,
        relationsByKey: relationsByKey,
        revision: stage.revision,
        onOpen: (record) => _openRecord(record, viewer, relationsByKey),
        onToggleDone: (id) => _store.toggleRecord(id),
      ),
      PlanViewerKind.graph => PlanUnsupportedViewer(kind: viewer.kind),
    };
  }

  // ---- handlers -----------------------------------------------------------

  String _columnTitle(PlanViewer viewer, String optionId) {
    if (optionId.isEmpty) return context.tr('planColumnNoStatus');
    final relation = _store.relationByKey(viewer.groupRelationKey ?? '');
    // A checkbox group reads as the two checked states, not option ids.
    if (relation?.format == PlanRelationFormat.checkbox) {
      return context.tr(
        optionId == 'true' ? 'planColumnChecked' : 'planColumnUnchecked',
      );
    }
    return relation?.optionText(optionId) ?? optionId;
  }

  Future<void> _addRow(
    PlanCollection collection,
    PlanViewer viewer, {
    String? status,
  }) async {
    final typeKey =
        viewer.defaultObjectTypeId ??
        collection.sourceTypeKey ??
        PlanObjectTypeIds.page;
    await _store.createRecord(
      collectionId: collection.id,
      typeKey: typeKey,
      templateId: viewer.defaultTemplateId,
      values: {
        PlanRelationKeys.name: context.tr('planUntitled'),
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
  }

  Future<void> _setSort(
    PlanCollection collection,
    PlanViewer viewer,
    String relationKey,
    PlanSortType type,
  ) async {
    final kept = [
      for (final sort in viewer.sorts)
        if (sort.relationKey != relationKey) sort,
    ];
    await _store.setViewerSorts(
      collection.id,
      viewer.id,
      type == PlanSortType.custom
          ? kept
          : [...kept, PlanSort(relationKey: relationKey, type: type)],
    );
  }

  Future<void> _hideColumn(
    PlanCollection collection,
    PlanViewer viewer,
    String relationKey,
  ) async {
    await _store.setViewerRelations(collection.id, viewer.id, [
      for (final column in viewer.relations)
        if (column.key == relationKey)
          column.copyWith(isVisible: false)
        else
          column,
    ]);
  }

  List<DswMenuEntry> _rowMenu(PlanCollection collection, PlanObject record) {
    final favorite = record.relation('isFavorite') == true;
    final archived = record.relation('isArchived') == true;
    return [
      DswMenuEntry(
        label: context.tr(favorite ? 'planUnfavorite' : 'planFavorite'),
        icon: favorite ? LucideIcons.star : LucideIcons.circle,
        onTap: () => _store.setFavorite(record.id, favorite: !favorite),
      ),
      DswMenuEntry(
        label: context.tr(archived ? 'planRestore' : 'planMoveToBin'),
        icon: LucideIcons.x,
        destructive: !archived,
        onTap: () => archived
            ? _store.restoreRecords([record.id])
            : _store.archiveRecords([record.id]),
      ),
      if (collection.kind == PlanCollectionKind.set)
        DswMenuEntry(
          label: context.tr('planDuplicate'),
          icon: LucideIcons.copy,
          onTap: () => _store.createRecord(
            collectionId: collection.id,
            typeKey: record.typeKey,
            values: {...record.struct}
              ..remove(PlanRelationKeys.name)
              ..[PlanRelationKeys.name] = '${record.name} (1)',
          ),
        ),
    ];
  }

  Future<void> _onViewerMenu(
    PlanViewerMenuAction action,
    String viewerId,
    PlanCollection collection,
  ) async {
    switch (action) {
      case PlanViewerMenuAction.rename:
        final current = collection.dataView.viewerById(viewerId);
        final name = await _askName(
          context,
          title: context.tr('planViewRename'),
          initial: current?.name ?? '',
        );
        if (name != null && name.isNotEmpty) {
          await _store.renameViewer(collection.id, viewerId, name);
        }
      case PlanViewerMenuAction.duplicate:
        await _store.duplicateViewer(collection.id, viewerId);
      case PlanViewerMenuAction.delete:
        final confirmed = await showConfirmDialog(
          context,
          title: context.tr('planViewDelete'),
          description: context.tr('planViewDeleteBody'),
          confirmLabel: context.tr('planDelete'),
        );
        if (!confirmed) return;
        await _store.removeViewer(collection.id, viewerId);
        if (!mounted) return;
        showFeedback(context, context.tr('planViewDeleted'));
      case PlanViewerMenuAction.moveLeft:
      case PlanViewerMenuAction.moveRight:
        final index = collection.dataView.viewers.indexWhere(
          (viewer) => viewer.id == viewerId,
        );
        if (index < 0) return;
        final delta = action == PlanViewerMenuAction.moveLeft ? -1 : 1;
        await _store.moveViewer(collection.id, index, index + delta);
    }
  }

  /// Opening a record is the inspector: every field the viewer shows, editable
  /// in place, plus the two row actions. The block document for a note arrives
  /// with ADR-0037 P5; until then a record with no fields is still a record.
  Future<void> _openRecord(
    PlanObject record,
    PlanViewer viewer,
    Map<String, PlanRelation> relationsByKey,
  ) async {
    await showShadDialog<void>(
      context: context,
      builder: (context) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        title: Text(context.tr('planRecordTitle'), style: DswType.l20),
        description: Text(
          record.name.isEmpty ? context.tr('planUntitled') : record.name,
          style: DswType.xs13,
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('close')),
          ),
        ],
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final column in viewer.relations.where((c) => c.isVisible))
                PlanRecordField(
                  key: ValueKey('field-${column.key}'),
                  record: record,
                  relation: relationsByKey[column.key],
                  viewerRelation: column,
                  store: _store,
                ),
              if (viewer.relations.where((c) => c.isVisible).isEmpty)
                Text(
                  context.tr('planRecordNoFields'),
                  style: DswType.xs13.copyWith(
                    color: context.dsw.labelTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A field row in the record inspector: the value, and the same editor a cell
/// uses, so the two surfaces cannot answer differently.
class PlanRecordField extends StatelessWidget {
  const PlanRecordField({
    super.key,
    required this.record,
    required this.relation,
    required this.viewerRelation,
    required this.store,
  });

  final PlanObject record;
  final PlanRelation? relation;
  final PlanViewerRelation viewerRelation;
  final PlanObjectStore store;

  @override
  Widget build(BuildContext context) {
    final key = relation?.key ?? viewerRelation.key;
    final cell = PlanCellValue(
      object: record,
      relation: relation,
      viewerRelation: viewerRelation,
    );
    if (relation == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
        child: cell,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              relation!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xs13.copyWith(color: context.dsw.labelTertiary),
            ),
          ),
          Expanded(
            child: PlanCellEditor(
              record: record,
              relation: relation!,
              onWrite: (value) => store.amendRecord(record.id, {key: value}),
              onClear: () => store.unsetRecord(record.id, [key]),
              child: cell,
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionHeader extends StatelessWidget {
  const _CollectionHeader({
    required this.collection,
    required this.count,
    required this.canRename,
    required this.onRename,
  });

  final PlanCollection collection;
  final int count;
  final bool canRename;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final step = MediaQuery.textScalerOf(context).scale(1);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DswShape.md,
        DswShape.md,
        DswShape.sm,
        DswShape.xs,
      ),
      child: Row(
        children: [
          if (collection.iconEmoji case final emoji?)
            Text(emoji, style: DswType.l20)
          else
            Icon(
              LucideIcons.circle,
              size: DswShape.iconMd,
              color: context.dsw.labelTertiary,
            ),
          const SizedBox(width: DswShape.sm),
          Expanded(
            child: DswHoverTap(
              onTap: canRename ? onRename : null,
              semanticLabel: collection.name,
              builder: (context, hovered, focused) => Text(
                collection.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.l20.copyWith(
                  color: color.labelPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          Text(
            context.tr('planRecordCount'),
            style: DswType.xxxs11.copyWith(color: color.labelTertiary),
          ),
          SizedBox(width: DswShape.xs, height: 20 * step),
          Text(
            '$count',
            style: DswType.xxxs11.copyWith(color: color.labelTertiary),
          ),
          const SizedBox(width: DswShape.sm),
        ],
      ),
    );
  }
}

class _SheetBar extends StatelessWidget {
  const _SheetBar({
    required this.viewer,
    required this.advancedCount,
    required this.canManage,
    required this.sheets,
  });

  final PlanViewer? viewer;
  final int advancedCount;
  final bool canManage;
  final List<Widget> sheets;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DswShape.sm,
        DswShape.xs,
        DswShape.sm,
        DswShape.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: DswShape.xs,
            runSpacing: DswShape.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: canManage ? sheets : const [],
          ),
          if (advancedCount > 0)
            Padding(
              padding: const EdgeInsets.only(
                top: DswShape.xs,
                left: DswShape.xs,
              ),
              child: Text(
                context.tr('planFilterNestedUnsupported'),
                style: DswType.xxxs11.copyWith(color: color.labelTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

/// The name prompt, in the one shape the app already uses for a small dialog:
/// `ShadDialog` + `ShadInput` + an outline cancel and a filled confirm
/// (`plan_workspace.dart`'s new-note dialog is the same three parts).
Future<String?> _askName(
  BuildContext context, {
  required String title,
  required String initial,
}) async {
  final controller = TextEditingController(text: initial);
  return showShadDialog<String>(
    context: context,
    builder: (context) => ShadDialog(
      radius: BorderRadius.circular(DswShape.float),
      title: Text(title, style: DswType.sStrong14),
      actions: [
        ShadButton.outline(
          height:
              DswShape.controlMd * MediaQuery.textScalerOf(context).scale(1),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('planCancel')),
        ),
        ShadButton(
          height:
              DswShape.controlMd * MediaQuery.textScalerOf(context).scale(1),
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(context.tr('planSave')),
        ),
      ],
      child: SizedBox(
        width: 320,
        child: dswEnsureShadTheme(
          context,
          ShadInput(
            controller: controller,
            autofocus: true,
            style: DswType.s14,
            placeholder: Text(
              title,
              style: DswType.xs13.copyWith(color: context.dsw.labelTertiary),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
        ),
      ),
    ),
  );
}
