// The five-region shell: sidebar | center | details | workbench, with the
// bottom panel squeezing only the center column.
//
// A port of `deepseek-harness/packages/client/ui-layout/src/client/AppFrame.tsx`
// and its module CSS, widened to better-sidebar's layout: the workbench is its
// own right column (the tool surface, not an inspection drawer), and the bottom
// panel sits beneath the CENTER column alone — from the sidebar's right edge to
// the workbench's left — exactly as `sidebar.module.css:197-221` describes it
// ("neither sidebar gives up any position; the right panel keeps its full
// height"). The frame owns the viewport reading, the concession solve
// ([computeColumns], [computeBottom]), the drag handles, the viewport-corner
// toggle cluster, and the sidebar's `collapsed`/`width` parameters — the panels
// cannot know them, because they are outputs of the solve.
//
// Three behaviours worth keeping straight while reading:
//
//   * Column widths and the bottom panel's height animate on the slow curve,
//     and the animation is switched off for the whole gesture
//     (`.frame[data-dragging] { transition: none }`): an eased track cannot
//     follow the pointer.
//   * A column is handed the *target* width and is laid out at it regardless of
//     how far the column has slid, so nothing reflows mid-slide. The column
//     clips instead. That is what [OverflowBox] is doing below. A child that
//     wants a width of its own anyway — the rail, while its wide content fades
//     — releases the constraint the same way and is clipped in turn.
//   * Closed panels stay mounted at zero size. Closing a workbench must not
//     throw away its editors; hiding the bottom panel must not kill its shells.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../state/layout_controller.dart';
import '../theme/dsw_alias.dart';
import '../theme/dsw_motion.dart';
import '../theme/dsw_theme.dart';
import 'layout/columns.dart';

/// Which divider a gesture belongs to.
enum _Region { sidebar, details, workbench, bottom }

class AppFrame extends StatefulWidget {
  const AppFrame({
    super.key,
    required this.layout,
    required this.sidebarBuilder,
    required this.center,
    required this.details,
    required this.workbench,
    required this.bottom,
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

  /// The workbench column. Same keep-alive contract as [details].
  final Widget workbench;

  /// The bottom panel row. Spans the full width beneath the columns; stays
  /// mounted at zero height when closed.
  final Widget bottom;

  /// Floats over everything; only hit-tests where it paints.
  final Widget? overlay;

  @override
  State<AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends State<AppFrame> {
  /// The rendered size captured at drag start. Grabbing a concession-clamped
  /// panel must not jump back to the stored preference, and the base stays frozen
  /// for the whole gesture so deltas do not compound.
  double _base = 0;
  double _delta = 0;
  _Region? _dragging;
  _Region? _hovered;
  bool _detailsHovered = false;
  bool _workbenchHovered = false;

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
    final viewportHeight = constraints.maxHeight;

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
    final cols = computeColumns(
      viewport,
      preference,
      layout.details,
      layout.workbench,
    );
    final bottomHeight = computeBottom(layout.bottom, viewportHeight);

    // The solver lets the sidebar keep its width even when the viewport cannot
    // pay for it (it never concedes). Clamping here keeps that from becoming a
    // Row overflow in a window narrower than the rail plus the center floor.
    final sidebarWidth = math.min(cols.sidebar, viewport);
    final detailsWidth = math.min(
      cols.details,
      math.max(0.0, viewport - sidebarWidth),
    );
    final workbenchWidth = math.min(
      cols.workbench,
      math.max(0.0, viewport - sidebarWidth - detailsWidth),
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
                  border: Border(
                    right: BorderSide(color: color.borderL1),
                  ),
                ),
                child: widget.sidebarBuilder(
                  context,
                  collapsed,
                  sidebarWidth,
                ),
              ),
              // The center column: the conversation above, the bottom panel
              // beneath it. The bottom panel squeezes ONLY this column — the
              // side columns keep their full height, which is why it lives in
              // here rather than as a row under the whole frame.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: ClipRect(child: widget.center)),
                          _row(
                            height: bottomHeight,
                            duration: duration,
                            border: bottomHeight == 0
                                ? null
                                : BorderSide(color: color.borderL2),
                            child: widget.bottom,
                          ),
                        ],
                      ),
                      if (bottomHeight > 0)
                        _bottomDivider(
                          top: constraints.maxHeight - bottomHeight,
                          duration: duration,
                          color: color,
                          cols: cols,
                          bottomHeight: bottomHeight,
                        ),
                    ],
                  ),
                ),
              ),
              MouseRegion(
                onEnter: (_) => setState(() => _detailsHovered = true),
                onExit: (_) => setState(() => _detailsHovered = false),
                child: _column(
                  width: detailsWidth,
                  duration: duration,
                  decoration: BoxDecoration(
                    // A closed column is still mounted, so its border
                    // would paint a 1px seam against the center.
                    border: detailsWidth == 0
                        ? null
                        : Border(
                            left: BorderSide(color: color.borderL2),
                          ),
                  ),
                  child: widget.details,
                ),
              ),
              MouseRegion(
                onEnter: (_) => setState(() => _workbenchHovered = true),
                onExit: (_) => setState(() => _workbenchHovered = false),
                child: _column(
                  width: workbenchWidth,
                  duration: duration,
                  decoration: BoxDecoration(
                    border: workbenchWidth == 0
                        ? null
                        : Border(
                            left: BorderSide(color: color.borderL2),
                          ),
                  ),
                  child: widget.workbench,
                ),
              ),
            ],
          ),
          if (widget.overlay != null)
            Positioned.fill(child: widget.overlay!),
          // The persistent panel toggles at the viewport's top-right corner:
          // the bottom panel's glyph left of the workbench's, always pinned
          // whether the panels are open or not — while the workbench is open
          // they squeeze into its tab strip's reserved right end
          // (`sidebar.module.css:57-78`).
          Positioned(
            top: 3,
            right: 10,
            child: _ToggleCluster(layout: layout, narrow: narrow),
          ),
          // The collapsed rail is fixed-width: no handle while closed.
          if (!collapsed)
            _divider(
              region: _Region.sidebar,
              left: sidebarWidth,
              duration: duration,
              color: color,
              cols: cols,
            ),
          if (detailsWidth > 0)
            _divider(
              region: _Region.details,
              left: viewport - detailsWidth - workbenchWidth,
              duration: duration,
              color: color,
              cols: cols,
            ),
          if (workbenchWidth > 0)
            _divider(
              region: _Region.workbench,
              left: viewport - workbenchWidth,
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

  /// The bottom track. Same keep-alive and no-reflow contracts as [_column],
  /// on the vertical axis; the width is the frame's, so only height animates.
  ///
  /// The decoration is always present — a closed row still needs its clip, and
  /// `Container` refuses to clip without one — with a transparent border
  /// standing in for "none".
  Widget _row({
    required double height,
    required Duration duration,
    required BorderSide? border,
    required Widget child,
  }) => AnimatedContainer(
    duration: duration,
    curve: DswMotion.easeInOut,
    height: height,
    clipBehavior: Clip.hardEdge,
    decoration: BoxDecoration(border: Border(top: border ?? BorderSide.none)),
    child: OverflowBox(
      alignment: AlignmentDirectional.topStart,
      minHeight: 0,
      maxHeight: double.infinity,
      child: SizedBox(width: double.infinity, height: height, child: child),
    ),
  );

  /// An 8px hit strip centred on a column border, above the column content.
  ///
  /// The details and workbench sides also carry a 12x32 pill, revealed on hover
  /// over either the strip or the column it resizes — the two panels a user
  /// closes and reopens by hand. The pill cross-fades rather than popping, so its
  /// [AnimatedOpacity] is mounted whenever the strip is.
  Widget _divider({
    required _Region region,
    required double left,
    required Duration duration,
    required DswAlias color,
    required Columns cols,
  }) {
    final active = _hovered == region || _dragging == region;
    final pill = switch (region) {
      _Region.details => _detailsHovered || active,
      _Region.workbench => _workbenchHovered || active,
      _Region.sidebar => false,
      _Region.bottom => false,
    };

    return AnimatedPositioned(
      duration: duration,
      curve: DswMotion.easeInOut,
      left: left - 4,
      top: 0,
      bottom: 0,
      width: 8,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = region),
        onExit: (_) => setState(() {
          if (_hovered == region) _hovered = null;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // No throttling: Flutter coalesces the writes into one build per frame
          // on its own, which is what dsh's rAF wrapper is for.
          onHorizontalDragStart: (_) => _startDrag(region, cols, 0),
          onHorizontalDragUpdate: (event) =>
              _drag(region, event.delta.dx),
          onHorizontalDragEnd: (_) => _endDrag(),
          onHorizontalDragCancel: _endDrag,
          child: region == _Region.sidebar
              ? const SizedBox.expand()
              : Center(
                  child: AnimatedOpacity(
                    opacity: pill ? 1 : 0,
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
                ),
        ),
      ),
    );
  }

  /// The bottom row's resize strip: same 8px hit area, centred on the row's
  /// top border and spanning its full width.
  Widget _bottomDivider({
    required double top,
    required Duration duration,
    required DswAlias color,
    required Columns cols,
    required double bottomHeight,
  }) => AnimatedPositioned(
    duration: duration,
    curve: DswMotion.easeInOut,
    left: 0,
    right: 0,
    top: top - 4,
    height: 8,
    child: MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      onEnter: (_) => setState(() => _hovered = _Region.bottom),
      onExit: (_) => setState(() {
        if (_hovered == _Region.bottom) _hovered = null;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragStart: (_) =>
            _startDrag(_Region.bottom, cols, bottomHeight),
        onVerticalDragUpdate: (event) => _drag(_Region.bottom, event.delta.dy),
        onVerticalDragEnd: (_) => _endDrag(),
        onVerticalDragCancel: _endDrag,
        child: const SizedBox.expand(),
      ),
    ),
  );

  void _startDrag(_Region region, Columns cols, double bottomHeight) {
    setState(() {
      _dragging = region;
      _delta = 0;
      _base = switch (region) {
        _Region.sidebar => cols.sidebar,
        _Region.details => cols.details,
        _Region.workbench => cols.workbench,
        _Region.bottom => bottomHeight,
      };
    });
    widget.layout.isDragging = true;
  }

  void _drag(_Region region, double d) {
    _delta += d;
    // The right-hand panels grow leftwards, and the bottom row grows upwards,
    // so those handles read their deltas inverted.
    switch (region) {
      case _Region.sidebar:
        widget.layout.setSidebar(_base + _delta);
      case _Region.details:
        widget.layout.setDetails(_base - _delta);
      case _Region.workbench:
        widget.layout.setWorkbench(_base - _delta);
      case _Region.bottom:
        widget.layout.setBottom(_base - _delta);
    }
  }

  void _endDrag() {
    setState(() => _dragging = null);
    widget.layout.isDragging = false;
  }
}

/// The viewport-corner cluster of panel toggles — `sidebar.module.css:57-117`.
///
/// Two 28px circular buttons side by side, the bottom panel's glyph LEFT of the
/// workbench's. Pinned to the corner whether the panels are open or not; the
/// workbench's open strips reserve their right end for it, so it squeezes into
/// the tab band instead of covering tabs. A narrow viewport merges the two
/// panels into one drawer, so the bottom toggle is not offered there.
class _ToggleCluster extends StatelessWidget {
  const _ToggleCluster({required this.layout, required this.narrow});

  final LayoutController layout;
  final bool narrow;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!narrow)
        _ToggleButton(
          icon: LucideIcons.panel_bottom,
          tooltip: layout.bottom == 0 ? 'Open bottom panel' : 'Collapse bottom panel',
          onTap: layout.toggleBottom,
        ),
      _ToggleButton(
        icon: LucideIcons.panel_right,
        tooltip: layout.workbench == 0
            ? 'Open workbench panel'
            : 'Collapse workbench panel',
        onTap: layout.toggleWorkbench,
      ),
    ],
  );
}

/// One 28px circle of the cluster: transparent fill, secondary ink, hover
/// raises the fill — the app's own icon-button shape, no border, no shadow.
class _ToggleButton extends StatefulWidget {
  const _ToggleButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_ToggleButton> createState() => _ToggleButtonState();
}

class _ToggleButtonState extends State<_ToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered ? color.interactiveBgHover : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _hovered ? color.labelPrimary : color.labelSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
