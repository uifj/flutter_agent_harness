// The two pieces of chrome the four block primitives share: the horizontal
// scroller their bodies sit in, and the `… N more lines` / `Collapse` control
// under a capped body.
//
// dsh spells both four times over, once per block, in the same shape. Only the
// padding and the aria text differ, so those are props here and the rest is
// shared — four copies of a hover rule is four chances for one of them to drift.

import 'package:flutter/material.dart';

import '../../theme/dsw_theme.dart';

/// `overflow-x: auto` over a `white-space: pre` body.
///
/// The blocks agree that a line is never folded: a source line's indentation, a
/// match line's alignment and a diff's leading whitespace are the content, so a
/// long line scrolls sideways instead of wrapping. One scroller around the whole
/// body rather than one per row, because the rows have to move together.
///
/// The minimum width is this port's: the expand control below is `width: 100%` on
/// the web, and inside a shrink-wrapping scroller it would collapse to the width
/// of its own label and stop being a full-row target.
///
/// [IntrinsicWidth] is what makes that minimum reachable. A horizontal scroller
/// offers its child an unbounded width, and a stretching column cannot resolve
/// one — it hands `constraints.maxWidth` straight to its children, which is
/// infinity. Measuring the widest row first turns that into a real number, so the
/// body is `max(widest row, card width)` wide: short rows still span the card, and
/// a long line still overflows it and scrolls. The extra measuring pass is over
/// the capped row count, never the whole file.
class BlockScroller extends StatelessWidget {
  const BlockScroller({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: constraints.maxWidth),
        child: IntrinsicWidth(child: child),
      ),
    ),
  );
}

/// The collapse toggle under a capped body.
///
/// The visible text is `t('collapse')` and `t('terminal.expandRest')`, whose `en`
/// entries are `Collapse` and `… {n} more lines`; the aria strings vary by block
/// ("output lines", "result lines", "diff lines") and arrive from the caller.
class BlockExpandToggle extends StatefulWidget {
  const BlockExpandToggle({
    super.key,
    required this.expanded,
    required this.hidden,
    required this.onToggle,
    required this.textStyle,
    required this.expandSemantics,
    required this.collapseSemantics,
    this.padding = EdgeInsets.zero,
  });

  final bool expanded;

  /// Rows past the cap, from `headTailCap`. The caller only draws this control
  /// when it is positive, so the label never reads `… 0 more lines`.
  final int hidden;

  final VoidCallback onToggle;

  /// `font: inherit` — the body's font, not a step of its own, so the control
  /// occupies exactly the row it replaces.
  final TextStyle textStyle;

  /// `aria-label` for each direction. It differs from the visible label on
  /// purpose: `… 8 more lines` does not say more lines of what, and a screen
  /// reader has no card around it to tell.
  final String expandSemantics;
  final String collapseSemantics;

  final EdgeInsets padding;

  @override
  State<BlockExpandToggle> createState() => _BlockExpandToggleState();
}

class _BlockExpandToggleState extends State<BlockExpandToggle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Semantics(
      button: true,
      expanded: widget.expanded,
      label: widget.expanded
          ? widget.collapseSemantics
          : widget.expandSemantics,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: widget.padding,
            child: Align(
              // `display: block; width: 100%; text-align: left` — the row spans
              // the body so the whole line is the target, and the label sits at
              // the start of it.
              alignment: Alignment.centerLeft,
              child: Text(
                widget.expanded ? 'Collapse' : '… ${widget.hidden} more lines',
                style: widget.textStyle.copyWith(
                  color: _hovered ? color.labelSecondary : color.labelTertiary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
