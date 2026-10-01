// The two-way choice the design system has no component for.
//
// ADR-0036 decision 1, third rung: `shadcn_ui` 0.56.3 ships a Tabs, an
// Accordion, a Select and a RadioGroup, and none of them is a segmented
// control — Tabs is a page switch with panels behind it, RadioGroup is a column
// of labelled circles, Select replaces the choice with a popup. So this is the
// wrapper the decision asks for: a track of cells whose *body* is shad's button,
// and whose skin comes from the same aliases every other surface reads.
//
// What lives here rather than at the call site is the two rules a copy always
// gets wrong: the seat rides the text step (ADR-0017 S3 — a nailed 32 held
// 40.0 worth of `s14` label at the system's 1.8x step and cut 「企划」), and a
// cell too narrow for its word sheds the word before it sheds the control,
// naming itself through `semanticLabel` on the way (the same rule the composer's
// mode chip learned in the same walk).

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadBorder, ShadButton, ShadDecoration;

import '../../theme/dsw_shad_bridge.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';

/// One cell of the track.
class DswSegment<T> {
  const DswSegment({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// A segmented choice: pick one of [segments], and [onSelect] hears about it.
class DswSegmented<T> extends StatelessWidget {
  const DswSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelect,
    this.height = 32,
  });

  final List<DswSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelect;

  /// The track's height at the designed step; the cells sit inside its 2px
  /// gutter. Like every other seat here it is multiplied by the text step.
  final double height;

  /// How wide a cell must be to keep its word. The glyph and its gap cost 20 and
  /// do not grow — `Icon(size:)` answers to nothing but its own number — while
  /// the label rides the text step, so only the second term is multiplied. 71 is
  /// `Agent` at `s14`, the wider of the pair this app draws in English.
  static const _glyphCost = 20.0;
  static const _labelCost = 71.0;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final step = MediaQuery.textScalerOf(context).scale(1);
    return dswEnsureShadTheme(
      context,
      Container(
        height: height * step,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color.bgLayer3,
          borderRadius: BorderRadius.circular(DswShape.card),
        ),
        child: Row(
          children: [
            for (final segment in segments)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, cell) {
                    final showLabel =
                        cell.maxWidth >= _glyphCost + _labelCost * step;
                    final live = segment.value == selected;
                    final button = ShadButton.ghost(
                      onPressed: () => onSelect(segment.value),
                      // Both: the cell fills the track's height at the current
                      // step, and shad's `height` writes min AND max, so the seat
                      // has to be computed rather than asked for.
                      height: (height - 4) * step,
                      padding: EdgeInsets.zero,
                      backgroundColor: live
                          ? color.sidebarNavItemActive
                          : Colors.transparent,
                      hoverBackgroundColor: live
                          ? color.sidebarNavItemActive
                          : color.sidebarNavItemHover,
                      foregroundColor: live
                          ? color.labelPrimary
                          : color.labelSecondary,
                      hoverForegroundColor: color.labelPrimary,
                      decoration: ShadDecoration(
                        border: ShadBorder.all(
                          width: 0,
                          radius: DswShape.radius(DswShape.control),
                        ),
                        focusedBorder: ShadBorder.all(
                          width: 0,
                          radius: DswShape.radius(DswShape.control),
                        ),
                      ),
                      // min, not max: shad's button hands its child an unbounded
                      // width (the ConstrainedBox it writes carries only the
                      // height), and a max-sizing Row with a flex child inside
                      // that is the one combination the framework refuses.
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(segment.icon, size: DswShape.iconSm),
                          if (showLabel) ...[
                            const SizedBox(width: 6),
                            // Flexible, not a bare Text: a Row hands a non-flex
                            // child the whole row to size itself in, so an
                            // ellipsis would never get its turn.
                            Flexible(
                              child: Text(
                                segment.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DswType.s14,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                    // A cell whose word went away has to keep saying what it is:
                    // shad's button has no semantic label of its own, so the
                    // name rides on from here.
                    return showLabel
                        ? button
                        : Semantics(
                            button: true,
                            label: segment.label,
                            child: button,
                          );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
