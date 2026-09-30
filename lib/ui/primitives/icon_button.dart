// The one icon-only button.
//
// ADR-0021 unified the tap primitive underneath these; the layer above stayed
// copied. Three private classes in `lib/ui/workbench/tabs/` each rebuilt the
// same `Tooltip + DswHoverTap + hover wash` body and then answered five
// questions three different ways — radius, shape, the glyph's colour ladder, how
// "disabled" is said, and whether keyboard focus counts as being active.
// `browser_tab.dart` carried an `enabled` field *and* an optional `onTap`, and
// for the back/forward buttons those two already disagreed.
//
// The reference is one component with size variants:
// `_archive_project/ZCode-main/packages/ui/src/components/ui/button.tsx:10,33-37`
// — base `rounded-md` (there is no circle in that family), a colour one step
// dimmer at rest than on hover, and disabled as `pointer-events-none` plus
// `opacity-50`. Two of our copies cited that `.iconButton` in their own doc
// comment while drawing a circle. See ADR-0024.

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadBorder, ShadDecoration, ShadIconButton;

import '../../theme/dsw_shad_bridge.dart';

import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';

/// An icon control whose tooltip is also its accessible name.
class DswIconButton extends StatelessWidget {
  const DswIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = DswShape.controlMd,
    this.iconSize = DswShape.iconSm,
  });

  final IconData icon;

  /// Both the bubble's text and the name a screen reader says. Two fields would
  /// be how a button ends up labelled one thing and named another.
  final String tooltip;

  /// Null is the only way to say "nothing to do right now": dimmed, no wash,
  /// not tappable. There is no `enabled` flag left to disagree with this.
  final VoidCallback? onTap;

  /// The box, taken from the row this sits in — controls on one line must be the
  /// same height. Geometry is the call site's only say; colour, radius, wash and
  /// timing come from here.
  final double size;

  final double iconSize;

  /// Radius follows the box per ADR-0017's nesting law, so a 20px glyph inside a
  /// dense tree row does not wear a card-sized corner.
  double get _radius => size <= 20
      ? DswShape.inset
      : size <= DswShape.controlMd
      ? DswShape.inner
      : DswShape.control;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final enabled = onTap != null;
    // The body is shad's (ADR-0036 decision 3): the four properties this
    // primitive exists to guarantee — pointer, keyboard, semantics, and one
    // disabled spelling — stop being re-implemented per control, and the focus
    // ring arrives free. What stays here is the ladder and the geometry, which
    // is what the call sites were each answering differently.
    return dswEnsureShadTheme(
      context,
      Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          label: tooltip,
          child: ShadIconButton.ghost(
            onPressed: onTap,
            // shad's own `disabledOpacity` dims it and the ladder drops it one
            // step further; both say the same thing, and the second is the
            // colour the design sheet asks for.
            enabled: enabled,
            width: size,
            height: size,
            padding: EdgeInsets.zero,
            icon: Icon(icon, size: iconSize),
            backgroundColor: Colors.transparent,
            hoverBackgroundColor: color.interactiveBgHover,
            foregroundColor: enabled
                ? color.labelSecondary
                : color.labelCaption,
            hoverForegroundColor: color.labelPrimary,
            decoration: ShadDecoration(
              border: ShadBorder.all(
                width: 0,
                radius: DswShape.radius(_radius),
              ),
              focusedBorder: ShadBorder.all(
                width: 0,
                radius: DswShape.radius(_radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
