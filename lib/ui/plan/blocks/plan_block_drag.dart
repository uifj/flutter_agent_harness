// Drag to move (ADR-0044 P10-d, AC3-18). Upstream drops into three zones —
// above, inside, below (`DragAndDropConfig.kt:4-8`) — and auto-scrolls near
// the viewport edges at 60ms ticks with a 350px band and a faster 200px core
// (`scrollandmove/`). The zones answer through the document's moveBlock /
// moveAsChild; the scroll decision is the pure function below so the
// thresholds are testable without a live drag.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/app_localizations.dart';
import '../../../state/plan_block_document.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/tappable.dart';

/// What one drag carries: the root block being moved.
class PlanBlockDrag {
  const PlanBlockDrag(this.id);

  final String id;
}

enum PlanDropZone { before, inside, after }

/// The scroll step for [distanceToEdge] pixels from the viewport edge during
/// a drag. Upstream's two bands: within 200px the step doubles, within 350px
/// a single step, both applied per 60ms tick (`scrollandmove/`). Zero keeps
/// the viewport still. Negative means the pointer is past the edge.
double planAutoScrollStep(double distanceToEdge, {double step = 12}) {
  if (distanceToEdge < 0) return step * 2;
  if (distanceToEdge <= 200) return step * 2;
  if (distanceToEdge <= 350) return step;
  return 0;
}

/// The grip a root row shows on hover, wrapped in the [Draggable]. The
/// feedback card carries [text] — the block's first line — so the pointer
/// shows WHAT is being dragged without a document lookup in the overlay.
class PlanDragGrip extends StatelessWidget {
  const PlanDragGrip({super.key, required this.blockId, required this.text});

  final String blockId;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: null,
      semanticLabel: AppLocalizations.of(context).planActionDrag,
      builder: (context, hovered, focused) => Draggable<PlanBlockDrag>(
        data: PlanBlockDrag(blockId),
        feedback: _DragFeedback(text: text),
        dragAnchorStrategy: pointerDragAnchorStrategy,
        childWhenDragging: const SizedBox(),
        child: Padding(
          padding: const EdgeInsets.only(left: DswShape.xs),
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Icon(
              LucideIcons.grip_vertical,
              size: DswShape.iconTiny,
              color: color.labelTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Material(
      color: color.bgLayer2,
      borderRadius: BorderRadius.circular(DswShape.inner),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DswShape.sm,
          vertical: DswShape.xs,
        ),
        child: Text(
          text.isEmpty ? AppLocalizations.of(context).planUntitled : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DswType.xs13.copyWith(color: color.labelPrimary),
        ),
      ),
    );
  }
}

/// Wraps a root row: one drop target, three zones read from the pointer's
/// local Y — the top quarter drops before, the bottom quarter after, the
/// middle nests inside (only when the target can take children; otherwise the
/// middle halves join before/after). The zone paints as a 2px brand rule
/// above/below the row or a tint over it, so the layout never shifts.
class PlanDragRow extends StatefulWidget {
  const PlanDragRow({
    super.key,
    required this.document,
    required this.targetId,
    required this.canNest,
    required this.child,
  });

  final PlanBlockDocument document;
  final String targetId;
  final bool canNest;
  final Widget child;

  @override
  State<PlanDragRow> createState() => _PlanDragRowState();
}

class _PlanDragRowState extends State<PlanDragRow> {
  PlanDropZone? _zone;

  PlanDropZone? _zoneFor(DragTargetDetails<PlanBlockDrag> details) {
    if (details.data.id == widget.targetId) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    final localY = box.globalToLocal(details.offset).dy;
    if (localY < box.size.height * 0.25) return PlanDropZone.before;
    if (localY > box.size.height * 0.75) return PlanDropZone.after;
    if (widget.canNest) return PlanDropZone.inside;
    return localY < box.size.height * 0.5
        ? PlanDropZone.before
        : PlanDropZone.after;
  }

  void _onDrop(DragTargetDetails<PlanBlockDrag> details) {
    final zone = _zoneFor(details);
    if (zone != null) {
      switch (zone) {
        case PlanDropZone.before:
          widget.document.moveBlock(
            details.data.id,
            targetId: widget.targetId,
            below: false,
          );
        case PlanDropZone.after:
          widget.document.moveBlock(
            details.data.id,
            targetId: widget.targetId,
            below: true,
          );
        case PlanDropZone.inside:
          widget.document.moveAsChild(
            details.data.id,
            parentId: widget.targetId,
          );
      }
    }
    if (_zone != null) setState(() => _zone = null);
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final rule = BorderSide(color: color.brandPrimary, width: 2);
    return DragTarget<PlanBlockDrag>(
      onMove: (details) {
        final zone = _zoneFor(details);
        if (zone != _zone) setState(() => _zone = zone);
      },
      onLeave: (_) {
        if (_zone != null) setState(() => _zone = null);
      },
      onWillAcceptWithDetails: (details) => details.data.id != widget.targetId,
      onAcceptWithDetails: (details) => _onDrop(details),
      builder: (context, candidates, rejected) => DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: _zone == PlanDropZone.before ? rule : BorderSide.none,
            bottom: _zone == PlanDropZone.after ? rule : BorderSide.none,
          ),
        ),
        child: Container(
          decoration: _zone == PlanDropZone.inside
              ? BoxDecoration(color: color.interactiveBgHover)
              : null,
          child: widget.child,
        ),
      ),
    );
  }
}
