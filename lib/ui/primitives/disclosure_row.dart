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

class DisclosureRow extends StatefulWidget {
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
  State<DisclosureRow> createState() => _DisclosureRowState();
}

class _DisclosureRowState extends State<DisclosureRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      _header(context),
      if (widget.open && widget.child != null) widget.child!,
    ],
  );

  Widget _header(BuildContext context) {
    final color = context.dsw;
    final row = SizedBox(
      height: 24,
      child: Row(
        children: [
          SizedBox.square(dimension: 16, child: Center(child: _leading(color))),
          const SizedBox(width: 6),
          Text(
            widget.title,
            style:
                widget.titleStyle ??
                DswType.s14.copyWith(
                  // dsh writes the header's leading literally rather than through
                  // the 14/22 token, so the port does too.
                  height: 24 / 14,
                  color: color.labelSecondary,
                ),
          ),
          if ((widget.keepCollapsedWhenOpen || !widget.open) &&
              widget.collapsed != null)
            Expanded(child: widget.collapsed!),
        ],
      ),
    );

    final overlay = widget.rowOverlay;
    // `overflow: hidden` on the header: the sweep must not escape past the row.
    final painted = overlay == null
        ? row
        : ClipRect(
            child: Stack(
              children: [row, Positioned.fill(child: overlay)],
            ),
          );

    if (!widget.expandable) return painted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onToggle,
        behavior: HitTestBehavior.opaque,
        child: painted,
      ),
    );
  }

  /// Open shows the chevron; closed cross-fades icon and chevron on hover, so
  /// the affordance appears without the row changing size.
  Widget _leading(DswAlias color) {
    final chevron = Icon(
      LucideIcons.chevron_down,
      size: 14,
      color: widget.chevronColor ?? color.labelTertiary,
    );
    if (widget.open) return chevron;
    if (!widget.expandable) return widget.icon;

    final duration = DswMotion.respecting(context, DswMotion.fast);
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: _hovered ? 0 : 1,
          duration: duration,
          child: widget.icon,
        ),
        AnimatedOpacity(
          opacity: _hovered ? 1 : 0,
          duration: duration,
          child: chevron,
        ),
      ],
    );
  }
}
