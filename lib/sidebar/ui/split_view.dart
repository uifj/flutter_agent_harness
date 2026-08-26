// The recursive layout: a split renders its children with a draggable divider
// between each pair, a leaf renders a pane.
//
// A port of `DSH-better-sidebar/src/client/split-pane.tsx`. Sizes are fractions
// of the parent rather than pixels, which is what the source does and what makes
// the whole workbench survive the details column being dragged narrower — pixel
// sizes would need re-solving on every resize of the container.
//
// One piece of the source is deliberately absent: its per-frame `requestAnimationFrame`
// batcher around divider drags. It exists because a React `onMouseMove` fires per
// OS event and each one would be a render. Flutter's [GestureDetector.onPanUpdate]
// already coalesces per frame and already reports a *delta*, which is exactly the
// shape [SidebarState.resize] wants — a cumulative offset would drift as soon as
// the clamp bit.

import 'package:flutter/material.dart';

import '../../theme/dsw_theme.dart';
import '../model/split_node.dart';
import '../state/workbench_controller.dart';
import 'pane.dart';

/// The divider's hit area. Wider than the 1px line it draws, because a 1px target
/// is not hittable; the source does the same with a `::before` overlay.
const _dividerThickness = 6.0;

class SplitView extends StatelessWidget {
  const SplitView({
    super.key,
    required this.workbench,
    required this.node,
    required this.alone,
    this.reserveTrailing = 0,
  });

  final WorkbenchController workbench;
  final SplitNode node;

  /// True when the whole workbench is this one leaf. Passed down so a lone pane
  /// can turn off its edge drop zones.
  final bool alone;

  /// Width each pane's tab strip keeps free at its right end — the toggle
  /// cluster squeezing into the open right panel's corner.
  final double reserveTrailing;

  @override
  Widget build(BuildContext context) => switch (node) {
    SidebarLeaf() => WorkbenchPane(
      workbench: workbench,
      pane: node as SidebarLeaf,
      alone: alone,
      reserveTrailing: reserveTrailing,
    ),
    SidebarSplit() => _Split(
      workbench: workbench,
      split: node as SidebarSplit,
      reserveTrailing: reserveTrailing,
    ),
  };
}

class _Split extends StatelessWidget {
  const _Split({
    required this.workbench,
    required this.split,
    required this.reserveTrailing,
  });

  final WorkbenchController workbench;
  final SidebarSplit split;
  final double reserveTrailing;

  @override
  Widget build(BuildContext context) {
    final horizontal = split.dir == SplitDirection.row;
    return LayoutBuilder(
      builder: (context, constraints) {
        // The dividers come out of the space the children share, so their
        // fractions add up over the remainder rather than over the whole box —
        // otherwise every nesting level would overflow by one divider.
        final total = horizontal ? constraints.maxWidth : constraints.maxHeight;
        final dividers = (split.children.length - 1) * _dividerThickness;
        final free = (total - dividers).clamp(0.0, double.infinity);

        final children = <Widget>[];
        for (var i = 0; i < split.children.length; i++) {
          if (i > 0) {
            children.add(
              _Divider(
                horizontal: horizontal,
                // `i - 1` because a divider resizes the pair it sits between, and
                // the reducer names a pair by its first member.
                onDrag: (delta) => workbench.resize(
                  split.id,
                  i - 1,
                  free <= 0 ? 0 : delta / free,
                ),
              ),
            );
          }
          final fraction = i < split.sizes.length
              ? split.sizes[i]
              : 1 / split.children.length;
          children.add(
            SizedBox(
              width: horizontal ? free * fraction : null,
              height: horizontal ? null : free * fraction,
              child: SplitView(
                workbench: workbench,
                node: split.children[i],
                alone: false,
                reserveTrailing: reserveTrailing,
              ),
            ),
          );
        }

        return horizontal
            ? Row(children: children)
            : Column(children: children);
      },
    );
  }
}

class _Divider extends StatefulWidget {
  const _Divider({required this.horizontal, required this.onDrag});

  final bool horizontal;

  /// Called with the pixel delta along the split's axis.
  final void Function(double delta) onDrag;

  @override
  State<_Divider> createState() => _DividerState();
}

class _DividerState extends State<_Divider> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final line = SizedBox(
      width: widget.horizontal ? 1 : null,
      height: widget.horizontal ? null : 1,
      child: ColoredBox(
        color: _active ? color.brandPrimary : color.borderL1,
      ),
    );

    return MouseRegion(
      cursor: widget.horizontal
          ? SystemMouseCursors.resizeColumn
          : SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _active = true),
      onExit: (_) => setState(() => _active = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: widget.horizontal
            ? (details) => widget.onDrag(details.delta.dx)
            : null,
        onVerticalDragUpdate: widget.horizontal
            ? null
            : (details) => widget.onDrag(details.delta.dy),
        child: SizedBox(
          width: widget.horizontal ? _dividerThickness : null,
          height: widget.horizontal ? null : _dividerThickness,
          child: Center(child: line),
        ),
      ),
    );
  }
}
