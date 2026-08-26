// The details column, which two panels now share.
//
// `DetailsPanel` was here first and `AppFrame` has one details slot, solved for
// by `computeColumns` — a fourth column would mean three minimums competing over
// the same viewport (640 + 300 + 300 leaves nothing below 1240px) and re-deciding
// the concession order this app already ported. So the two panels take turns in
// the one column instead.
//
// Both stay mounted, via [IndexedStack]. The frame already keeps the column
// mounted at zero width when it is closed, for the same reason: switching away
// from the workbench must not close its editors, and switching away from the
// details panel must not lose its scroll.
//
// Switching is a user gesture except in one case: selecting a tool call points
// *this* column at something, and if the workbench were showing, the click would
// look like it did nothing. `main.dart` therefore switches to details on select —
// the mirror of that, revealing the workbench when a tool opens a file, lands with
// the tool.

import 'package:flutter/material.dart';

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';

/// Which of the two panels the column is showing.
enum DetailsView { details, workbench }

/// Owns the column's current panel.
///
/// A [ChangeNotifier] rather than `setState` in `_DshAppState`, so switching a
/// panel does not rebuild the frame, the sidebar and the conversation with it.
class DetailsColumnController extends ChangeNotifier {
  DetailsView _view = DetailsView.details;

  DetailsView get view => _view;

  void show(DetailsView next) {
    if (_view == next) return;
    _view = next;
    notifyListeners();
  }
}

/// Height of the switcher strip. Matches the tab strip inside the workbench, so
/// the two rows read as one header rather than as two bands.
const _switcherHeight = 30.0;

class DetailsColumn extends StatelessWidget {
  const DetailsColumn({
    super.key,
    required this.controller,
    required this.details,
    required this.workbench,
  });

  final DetailsColumnController controller;
  final Widget details;
  final Widget workbench;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ColoredBox(
      color: color.bgBase,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Column(
          children: [
            _Switcher(controller: controller),
            Expanded(
              child: IndexedStack(
                index: controller.view.index,
                sizing: StackFit.expand,
                children: [details, workbench],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Switcher extends StatelessWidget {
  const _Switcher({required this.controller});

  final DetailsColumnController controller;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      height: _switcherHeight,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(bottom: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        children: [
          for (final view in DetailsView.values)
            _Segment(
              label: switch (view) {
                DetailsView.details => 'Details',
                DetailsView.workbench => 'Workbench',
              },
              selected: controller.view == view,
              onTap: () => controller.show(view),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatefulWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Segment> createState() => _SegmentState();
}

class _SegmentState extends State<_Segment> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: DswMotion.respecting(context, DswMotion.fast),
          curve: DswMotion.easeInOut,
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: _fill(color),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: DswType.xxsStrong12.copyWith(
                color: widget.selected
                    ? color.labelPrimary
                    : color.labelTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _fill(DswAlias color) {
    if (widget.selected) return color.interactiveBgActive;
    return _hovered ? color.interactiveBgHover : Colors.transparent;
  }
}
