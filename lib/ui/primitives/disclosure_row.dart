// The 24px disclosure header, ported from `ui-primitives/src/DisclosureRow.tsx`.
//
// Shared chrome: `[16px leading] gap 6 [title 14/24]`, with room after the title
// for a collapsed preview. Both the reasoning row and the tool card are this row
// plus a body, which is why it lives here rather than in either of them.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import 'tappable.dart';

class DisclosureRow extends StatelessWidget {
  const DisclosureRow({
    super.key,
    required this.icon,
    required this.title,
    required this.open,
    required this.expandable,
    required this.onToggle,
    this.titleStyle,
    this.chevronColor,
    this.rowOverlay,
    this.collapsed,
    this.keepCollapsedWhenOpen = false,
    this.child,
  });

  /// The 14px leading glyph, swapped for a chevron while the row is hovered.
  final Widget icon;

  final String title;
  final bool open;
  final bool expandable;
  final VoidCallback onToggle;

  /// Overrides the default 14/24 secondary title.
  final TextStyle? titleStyle;

  /// Overrides the chevron's tertiary tint. The tool row lifts it a step, since
  /// there the chevron is the row's only affordance.
  final Color? chevronColor;

  /// Painted over the header and clipped to it — the seat the reasoning row's
  /// running sweep uses.
  final Widget? rowOverlay;

  /// Shown after the title while closed: a separator, a summary, a status.
  final Widget? collapsed;

  /// Keeps [collapsed] in place while open. The tool row wants this: its summary
  /// says which call this is, which stays worth knowing once the body is out.
  final bool keepCollapsedWhenOpen;

  /// Shown below the header while open.
  final Widget? child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [_header(context), if (open && child != null) child!],
  );

  Widget _header(BuildContext context) {
    final color = context.dsw;
    // `hovered` drives only the leading cross-fade; a keyboard focus lights the
    // same way through DswHoverTap's builder.
    Widget painted(bool hovered) {
      final row = SizedBox(
        height: 24,
        child: Row(
          children: [
            SizedBox.square(
              dimension: 16,
              child: Center(child: _leading(context, color, hovered)),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style:
                  titleStyle ??
                  DswType.s14.copyWith(
                    // dsh writes the header's leading literally rather than through
                    // the 14/22 token, so the port does too.
                    height: 24 / 14,
                    color: color.labelSecondary,
                  ),
            ),
            if ((keepCollapsedWhenOpen || !open) && collapsed != null)
              Expanded(child: collapsed!),
          ],
        ),
      );

      final overlay = rowOverlay;
      // `overflow: hidden` on the header: the sweep must not escape past the row.
      return overlay == null
          ? row
          : ClipRect(
              child: Stack(
                children: [
                  row,
                  Positioned.fill(child: overlay),
                ],
              ),
            );
    }

    if (!expandable) return painted(false);
    return DswHoverTap(
      onTap: onToggle,
      builder: (context, hovered, _) => painted(hovered),
    );
  }

  /// Open shows the chevron; closed cross-fades icon and chevron on hover, so
  /// the affordance appears without the row changing size.
  Widget _leading(BuildContext context, DswAlias color, bool hovered) {
    final chevron = Icon(
      LucideIcons.chevron_down,
      size: 14,
      color: chevronColor ?? color.labelTertiary,
    );
    if (open) return chevron;
    if (!expandable) return icon;

    final duration = DswMotion.respecting(context, DswMotion.fast);
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: hovered ? 0 : 1,
          duration: duration,
          child: icon,
        ),
        AnimatedOpacity(
          opacity: hovered ? 1 : 0,
          duration: duration,
          child: chevron,
        ),
      ],
    );
  }
}
