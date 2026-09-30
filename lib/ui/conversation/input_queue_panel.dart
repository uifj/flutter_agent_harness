// What the user typed while a turn held the transcript, in the order it will
// go out (ADR-0013).
//
// It sits above the composer card rather than inside it: the draft is one thing
// with one button, and these are separate inputs with their own lifecycle —
// reorder them, change how each one lands, or drop one. The panel is the only
// place a queued input can be edited, so a row that no longer exists in the
// queue has to disappear with the notification that removed it, not on a timer.
//
// Rows are keyed by the controller's queue id. Without keys a drag would be
// reported as every row below it having changed identity, and the drag overlay
// would land the row in the wrong slot.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../l10n/locales.dart';
import '../../model/queued_input.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../appearance_scope.dart';
import '../primitives/capsule_button.dart';
import 'conversation_root.dart';

class InputQueuePanel extends StatelessWidget {
  const InputQueuePanel({
    super.key,
    required this.items,
    required this.onRemove,
    required this.onReorder,
    required this.onDelivery,
  });

  final List<QueuedInput> items;

  /// By queue id, not by index: a removal renumbered everything below it.
  final ValueChanged<int> onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int id, InputDelivery delivery) onDelivery;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final color = context.dsw;
    return Padding(
      // The same content column as the card below it.
      padding: const EdgeInsets.fromLTRB(
        composerSideClearance,
        8,
        composerSideClearance,
        0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppearanceScope.widthOf(context, chatContentWidth),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: color.bgLayer1,
              border: Border.all(color: color.borderL2),
              borderRadius: BorderRadius.circular(DswShape.float),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [_header(context, color), _rows(context, color)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, DswAlias color) => Row(
    children: [
      Icon(
        LucideIcons.list_end,
        size: DswShape.iconSm,
        color: color.labelTertiary,
      ),
      const SizedBox(width: 6),
      Text(
        context.tr('inputQueue'),
        style: DswType.xxxs11.copyWith(color: color.labelSecondary),
      ),
      const Spacer(),
      Text(
        '${items.length}',
        style: DswType.xxxs11.copyWith(color: color.labelTertiary),
      ),
    ],
  );

  /// Scrollable only past the cap, so a two-item queue does not reserve a
  /// viewport it does not need.
  Widget _rows(BuildContext context, DswAlias color) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 152),
    child: ReorderableListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: onReorder,
      itemBuilder: (context, index) => _QueueRow(
        key: ValueKey(items[index].id),
        item: items[index],
        index: index,
        color: color,
        onRemove: onRemove,
        onDelivery: onDelivery,
      ),
    ),
  );
}

/// One queue row: the grip that drags it, what it says, and the two things the
/// user can still change about it.
class _QueueRow extends StatelessWidget {
  const _QueueRow({
    super.key,
    required this.item,
    required this.index,
    required this.color,
    required this.onRemove,
    required this.onDelivery,
  });

  final QueuedInput item;
  final int index;
  final DswAlias color;
  final ValueChanged<int> onRemove;
  final void Function(int id, InputDelivery delivery) onDelivery;

  @override
  Widget build(BuildContext context) {
    final guiding = item.delivery == InputDelivery.guide;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: context.tr('dragToReorder'),
              child: Icon(
                LucideIcons.grip_vertical,
                size: DswShape.iconSm,
                color: color.labelTertiary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.preview,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xxs12.copyWith(color: color.labelPrimary),
            ),
          ),
          const SizedBox(width: 8),
          CapsuleButton(
            label: context.tr(guiding ? 'deliveryGuide' : 'deliveryQueue'),
            size: CapsuleSize.sm,
            variant: CapsuleVariant.ghost,
            icon: guiding ? LucideIcons.route : LucideIcons.list_end,
            onTap: () => onDelivery(
              item.id,
              guiding ? InputDelivery.queue : InputDelivery.guide,
            ),
          ),
          const SizedBox(width: 4),
          CapsuleButton(
            label: context.tr('removeAttachment'),
            size: CapsuleSize.sm,
            variant: CapsuleVariant.ghost,
            onTap: () => onRemove(item.id),
          ),
        ],
      ),
    );
  }
}
