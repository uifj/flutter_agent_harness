// The board viewer: the only viewer that reuses `packages/board_panel`
// (ADR-0037 §1, the reuse line in the build sheet). Columns are the options of
// the viewer's group relation, plus the empty bucket upstream keeps last; the
// drag writes back through the screen's [onMove], which is what turns a drag
// into a relation value change plus a column order.
//
// Re-seeded on every store notification, exactly as the existing kanban panel
// does — a drag mutates the store first, so re-seeding is idempotent, and it
// keeps the package's mutable item type out of `lib/model`.

import 'package:board_panel/board_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/locales.dart';
import '../../../model/plan_dataview.dart';
import '../../../model/plan_relation.dart';
import '../../../model/plan_struct.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../primitives/tappable.dart';
import '../../../theme/dsw_typography.dart';
import 'plan_cell_value.dart';
import 'plan_viewers.dart';

/// A record on the board. `BoardPanelGroupItem` needs only a unique id; the
/// model stays a plain Dart value object rather than importing board_panel.
class _RecordCard extends BoardPanelGroupItem {
  _RecordCard(this.record);

  final PlanObject record;

  @override
  String get id => record.id;
}

/// The column window — upstream's `DEFAULT_LIMIT = 50`
/// (`presentation/relations/ObjectSetConfig.kt:27`), grown per column when the
/// column's scroll reaches its end.
const int boardPageLimit = 50;

class PlanBoardViewer extends StatefulWidget {
  const PlanBoardViewer({
    super.key,
    required this.viewer,
    required this.groups,
    required this.recordsById,
    required this.relationsByKey,
    required this.onMove,
    required this.onOpen,
    this.onAddToColumn,
    required this.groupLabel,
    required this.onReorderColumns,
    required this.revision,
  });

  /// The store's revision, so a re-seed happens once per write — not once per
  /// rebuild. Comparing the groups map by identity made every frame a change,
  /// and `didUpdateWidget` fed `setState` forever.
  final int revision;

  final PlanViewer viewer;

  /// Column → ordered record ids, in the order the stage produced.
  final Map<String, List<String>> groups;
  final Map<String, PlanObject> recordsById;
  final Map<String, PlanRelation> relationsByKey;

  /// (recordId, optionId of the destination column, index within it).
  final void Function(String recordId, String optionId, int index) onMove;
  final void Function(PlanObject record) onOpen;
  final void Function(String optionId)? onAddToColumn;

  /// Option id → column title; the empty id is the "no value" column.
  final String Function(String optionId) groupLabel;

  /// The viewer's `groupOrders` after a column drag.
  final void Function(List<String> optionIds) onReorderColumns;

  @override
  State<PlanBoardViewer> createState() => _PlanBoardViewerState();
}

class _PlanBoardViewerState extends State<PlanBoardViewer> {
  late BoardPanelController _board = _seed();
  final _scroll = BoardPanelScrollController();
  final _groupIds = <String>[];

  @override
  void didUpdateWidget(PlanBoardViewer old) {
    super.didUpdateWidget(old);
    // The screen re-reads the store on notification; a new groups map is the
    // signal to re-seed. A drag already landed in the store, so this is
    // idempotent rather than a second write.
    if (widget.revision != old.revision || old.viewer.id != widget.viewer.id) {
      setState(() => _board = _seed());
    }
  }

  BoardPanelController _seed() {
    _groupIds.clear();
    final controller = BoardPanelController(
      onMoveGroupItemToGroup: (fromGroupId, fromIndex, toGroupId, toIndex) {
        final id = _recordId(fromGroupId, fromIndex);
        if (id != null) widget.onMove(id, toGroupId, toIndex);
      },
      onMoveGroupItem: (groupId, fromIndex, toIndex) {
        final id = _recordId(groupId, fromIndex);
        if (id != null) widget.onMove(id, groupId, toIndex);
      },
      onMoveGroup: (fromGroupId, fromIndex, toGroupId, toIndex) {
        // Column order is data (`groupOrders`), so the drag is translated into
        // the new list and the screen writes it; the notification re-seeds.
        final order = [..._groupIds];
        if (!order.contains(fromGroupId)) return;
        order.remove(fromGroupId);
        order.insert(toIndex.clamp(0, order.length), fromGroupId);
        widget.onReorderColumns(order);
      },
    );
    // The whole column goes into the group data; the package windows it to
    // [boardPageLimit] and grows the window when the column's scroll reaches
    // its end — the `hasLoadedRecords` answer upstream carries on every board
    // column (`Viewer.kt:152-155`), with the store holding the full list
    // instead of a per-column subscription.
    widget.groups.forEach((optionId, ids) {
      _groupIds.add(optionId);
      controller.addGroup(
        BoardPanelGroupData<_RecordCard>(
          id: optionId,
          name: widget.groupLabel(optionId),
          items: [
            for (final id in ids)
              if (widget.recordsById[id] != null)
                _RecordCard(widget.recordsById[id]!),
          ],
        ),
        notify: false,
      );
    });
    return controller;
  }

  String? _recordId(String groupId, int index) {
    final ids = widget.groups[groupId];
    if (ids == null || index >= ids.length) return null;
    return ids[index];
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final groupRelation = widget.relationsByKey[widget.viewer.groupRelationKey];
    Color? columnColor(String optionId) {
      if (!widget.viewer.groupBackgroundColors) return null;
      final index = groupRelation?.option(optionId)?.colorIndex;
      if (index == null) return null;
      return planLadderColor(color, index);
    }

    return BoardPanel(
      controller: _board,
      boardScrollController: _scroll,
      config: BoardPanelConfig(
        groupBackgroundColor: color.bgLayer1,
        groupCornerRadius: DswShape.card,
        groupMargin: const EdgeInsets.only(right: DswShape.md),
        groupHeaderPadding: const EdgeInsets.fromLTRB(
          DswShape.sm,
          DswShape.sm,
          DswShape.sm,
          0,
        ),
        cardMargin: const EdgeInsets.symmetric(
          horizontal: DswShape.xs,
          vertical: DswShape.xs,
        ),
        stretchGroupHeight: true,
        cardPageSize: boardPageLimit,
      ),
      cardBuilder: (context, group, groupItem) {
        final record = (groupItem as _RecordCard).record;
        return BoardPanelGroupCard(
          key: ValueKey(groupItem.id),
          decoration: BoxDecoration(
            color: color.bgLayer2,
            borderRadius: BorderRadius.circular(DswShape.inner),
            border: Border.all(color: color.borderL2, width: 1),
          ),
          child: _BoardCard(
            record: record,
            viewer: widget.viewer,
            relationsByKey: widget.relationsByKey,
            onTap: () => widget.onOpen(record),
          ),
        );
      },
      headerBuilder: (context, columnData) {
        final band = columnColor(columnData.id);
        final header = BoardPanelGroupHeader(
          height: planRowSeat(context),
          addIcon: Icon(
            LucideIcons.plus,
            size: DswShape.iconTiny,
            color: color.labelTertiary,
          ),
          onAddButtonClick: widget.onAddToColumn == null
              ? null
              : () => widget.onAddToColumn!(columnData.id),
          title: Expanded(
            child: Text(
              columnData.headerData.groupName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.sStrong14.copyWith(color: color.labelPrimary),
            ),
          ),
        );
        // "Color columns" paints the option colour onto the header band — the
        // one surface this builder owns; a whole-column wash needs a
        // per-group background on the package, which it does not expose yet.
        if (band == null) return header;
        return ColoredBox(color: band, child: header);
      },
    );
  }
}

class _BoardCard extends StatelessWidget {
  const _BoardCard({
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
    final detail = viewer.relations
        .where(
          (column) => column.isVisible && column.key != PlanRelationKeys.name,
        )
        .toList();
    return DswHoverTap(
      onTap: onTap,
      semanticLabel: record.name,
      builder: (context, hovered, focused) => Padding(
        padding: const EdgeInsets.all(DswShape.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.name.isEmpty ? context.tr('planUntitled') : record.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DswType.s14.copyWith(
                color: record.isDone ? color.labelTertiary : color.labelPrimary,
                decoration: record.isDone
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            if (detail.isNotEmpty) ...[
              const SizedBox(height: DswShape.xs),
              for (final column in detail.take(2))
                Padding(
                  padding: const EdgeInsets.only(top: DswShape.xs),
                  child: PlanCellValue(
                    object: record,
                    relation: relationsByKey[column.key],
                    viewerRelation: column,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
