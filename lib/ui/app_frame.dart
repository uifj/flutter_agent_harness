// The three-column shell: sidebar | center | details.
//
// A port of `deepseek-harness/packages/client/ui-layout/src/client/AppFrame.tsx`
// and its module CSS. The frame owns the viewport reading, the concession solve
// ([computeColumns]), the drag handles, and the sidebar's `collapsed`/`width`
// parameters — the sidebar cannot know them, because they are outputs of the
// solve.
//
// Two behaviours worth keeping straight while reading:
//
//   * Column widths animate on the slow curve, and the animation is switched off
//     for the whole gesture (`.frame[data-dragging] { transition: none }`): an
//     eased track cannot follow the pointer.
//   * The sidebar is handed the *target* width and is laid out at it regardless
//     of how far the column has slid, so nothing reflows mid-slide. The column
//     clips instead. That is what [OverflowBox] is doing below. A child that
//     wants a width of its own anyway — the rail, while its wide content fades —
//     releases the constraint the same way and is clipped in turn.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/layout_controller.dart';
import '../theme/dsw_alias.dart';
import '../theme/dsw_motion.dart';
import '../theme/dsw_theme.dart';
import 'layout/columns.dart';

/// Which divider a gesture belongs to.
enum _Side { sidebar, details }

class AppFrame extends StatefulWidget {
  const AppFrame({
    super.key,
    required this.layout,
    required this.sidebarBuilder,
    required this.center,
    required this.details,
    this.overlay,
  });

  final LayoutController layout;

  /// Built with the resolved rail state and width, per `AppFrame.tsx:179-182`.
  final Widget Function(BuildContext context, bool collapsed, double width)
  sidebarBuilder;

  final Widget center;

  /// Stays mounted at zero width when closed, as in dsh — closing a panel must
  /// not throw away its state.
  final Widget details;

  /// Floats over all three columns; only hit-tests where it paints.
  final Widget? overlay;

  @override
  State<AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends State<AppFrame> {
  /// The rendered width captured at drag start. Grabbing a concession-clamped
  /// panel must not jump back to the stored preference, and the base stays frozen
  /// for the whole gesture so deltas do not compound.
  double _base = 0;
  double _dx = 0;
  _Side? _dragging;
  _Side? _hovered;
  bool _detailsHovered = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.layout,
    builder: (context, _) =>
        LayoutBuilder(builder: (context, constraints) => _frame(constraints)),
  );

  Widget _frame(BoxConstraints constraints) {
    final layout = widget.layout;
    final color = context.dsw;
    final viewport = constraints.maxWidth;

    // The store's narrow flag only decides what `toggleSidebar` means. The
    // geometry below is solved from the viewport in hand, so crossing the
    // breakpoint never costs a frame of stale layout.
    final narrow = viewport < sidebarAutoCollapse;
    if (layout.narrow != narrow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) layout.setNarrow(narrow);
      });
    }

    final preference = effectiveSidebarPreference(
      viewport: viewport,
      sidebarPreference: layout.sidebar,
      narrowExpanded: layout.narrowExpanded,
    );
    final collapsed = preference == 0;
    final cols = computeColumns(viewport, preference, layout.details);

    // The solver lets the sidebar keep its width even when the viewport cannot
    // pay for it (it never concedes). Clamping here keeps that from becoming a
    // Row overflow in a window narrower than the rail plus the center floor.
    final sidebarWidth = math.min(cols.sidebar, viewport);
    final detailsWidth = math.min(
      cols.details,
      math.max(0.0, viewport - sidebarWidth),
    );

    final duration = _dragging != null
        ? Duration.zero
        : DswMotion.respecting(context, DswMotion.slow);

    return ColoredBox(
      color: color.bgBase,
      child: Stack(
        children: [
          Row(
            children: [
              _column(
                width: sidebarWidth,
                duration: duration,
                decoration: BoxDecoration(
                  color: color.sidebarFill,
                  border: Border(right: BorderSide(color: color.borderL1)),
                ),
                child: widget.sidebarBuilder(context, collapsed, sidebarWidth),
              ),
              Expanded(child: ClipRect(child: widget.center)),
              MouseRegion(
                onEnter: (_) => setState(() => _detailsHovered = true),
                onExit: (_) => setState(() => _detailsHovered = false),
                child: _column(
                  width: detailsWidth,
                  duration: duration,
                  decoration: BoxDecoration(
                    // A closed details column is still mounted, so its border
                    // would paint a 1px seam against the center.
                    border: detailsWidth == 0
                        ? null
                        : Border(left: BorderSide(color: color.borderL2)),
                  ),
                  child: widget.details,
                ),
              ),
            ],
          ),
          if (widget.overlay != null) Positioned.fill(child: widget.overlay!),
          // The collapsed rail is fixed-width: no handle while closed.
          if (!collapsed)
            _handle(
              side: _Side.sidebar,
              left: sidebarWidth,
              duration: duration,
              color: color,
              cols: cols,
            ),
          if (detailsWidth > 0)
            _handle(
              side: _Side.details,
              left: viewport - detailsWidth,
              duration: duration,
              color: color,
              cols: cols,
            ),
        ],
      ),
    );
  }

  /// One animated grid track.
  ///
  /// The child is laid out at [width] through an [OverflowBox] and clipped by the
  /// container, rather than being squeezed as the column animates.
  Widget _column({
    required double width,
    required Duration duration,
    required Decoration decoration,
    required Widget child,
  }) => AnimatedContainer(
    duration: duration,
    curve: DswMotion.easeInOut,
    width: width,
    clipBehavior: Clip.hardEdge,
    decoration: decoration,
    child: OverflowBox(
      alignment: AlignmentDirectional.topStart,
      // Both bounds, not just the ceiling. Releasing `maxWidth` alone only covers
      // a column that is growing: while one shrinks, the animated width arrives
      // as a tight *minimum*, and the [SizedBox] below would be pushed back up to
      // it every frame — the reflow this is here to prevent, in the one direction
      // nobody looked.
      minWidth: 0,
      maxWidth: double.infinity,
      child: SizedBox(width: width, child: child),
    ),
  );

  /// An 8px hit strip centred on a column border, above the column content.
  ///
  /// The details side also carries a 12x32 pill, revealed on hover over either
  /// the strip or the column it resizes.
  Widget _handle({
    required _Side side,
    required double left,
    required Duration duration,
    required DswAlias color,
    required Columns cols,
  }) {
    final isDetails = side == _Side.details;
    final active = _hovered == side || _dragging == side;
    final showPill = isDetails && (active || _detailsHovered);

    return AnimatedPositioned(
      duration: duration,
      curve: DswMotion.easeInOut,
      left: left - 4,
      top: 0,
      bottom: 0,
      width: 8,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = side),
        onExit: (_) => setState(() {
          if (_hovered == side) _hovered = null;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // No throttling: Flutter coalesces the writes into one build per frame
          // on its own, which is what dsh's rAF wrapper is for.
          onHorizontalDragStart: (_) => _startDrag(side, cols),
          onHorizontalDragUpdate: (event) => _drag(side, event.delta.dx),
          onHorizontalDragEnd: (_) => _endDrag(),
          onHorizontalDragCancel: _endDrag,
          child: isDetails
              ? Center(
                  child: AnimatedOpacity(
                    opacity: showPill ? 1 : 0,
                    duration: DswMotion.respecting(context, DswMotion.slow),
                    curve: DswMotion.easeInOut,
                    child: Container(
                      width: 12,
                      height: 32,
                      decoration: BoxDecoration(
                        color: active
                            ? color.buttonFloatingHover
                            : color.buttonFloatingFill,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active
                              ? color.borderL3
                              : color.borderL2DarkmodeThin,
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }

  void _startDrag(_Side side, Columns cols) {
    setState(() {
      _dragging = side;
      _dx = 0;
      _base = side == _Side.details ? cols.details : cols.sidebar;
    });
    widget.layout.isDragging = true;
  }

  void _drag(_Side side, double dx) {
    _dx += dx;
    // Details grows leftwards, so its handle reads the delta inverted.
    if (side == _Side.details) {
      widget.layout.setDetails(_base - _dx);
    } else {
      widget.layout.setSidebar(_base + _dx);
    }
  }

  void _endDrag() {
    setState(() => _dragging = null);
    widget.layout.isDragging = false;
  }
}
