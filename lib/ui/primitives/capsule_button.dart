// The capsule button.
//
// A port of `ui-primitives/src/Button.module.css` (figma 1:155): the two sizes
// (`md` h36 / r18 / 14-22, `sm` h28 / r14 / 12-18) and the three fills the rest
// of this build asks for. dsh reaches for this same control in the approval row
// and all through the settings panel, so it lives in primitives rather than
// being spelled twice.
//
// Material's `TextButton` would bring a ripple, its own hover overlay, and its
// own disabled tint; dsh washes the whole box with an alias token and drops the
// box to 40% opacity instead, which is what this reproduces.

import 'package:flutter/material.dart';

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';

/// The three fills in use. `ghost` is `outline` without the stroke — dsh's
/// `.ghost`, which it uses where a row already has chrome of its own.
enum CapsuleVariant { primary, outline, ghost }

/// `md` is the default; `sm` is the dense row variant (`.sm`).
enum CapsuleSize { md, sm }

class CapsuleButton extends StatefulWidget {
  const CapsuleButton({
    super.key,
    required this.label,
    required this.onTap,
    this.variant = CapsuleVariant.outline,
    this.size = CapsuleSize.md,
    this.icon,
    this.enabled = true,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final CapsuleVariant variant;
  final CapsuleSize size;

  /// Rendered at 14px in the `md` size and 12px in `sm`, ahead of the label with
  /// the 4px gap `.button` sets.
  final IconData? icon;

  final bool enabled;

  /// Turns the hover red and drops the stroke, as `.dangerButton` and the
  /// approval row's reject override do. Ignored by [CapsuleVariant.primary],
  /// which has no destructive form in the source.
  final bool danger;

  @override
  State<CapsuleButton> createState() => _CapsuleButtonState();
}

class _CapsuleButtonState extends State<CapsuleButton> {
  bool _hovered = false;

  bool get _dense => widget.size == CapsuleSize.sm;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // A disabled control still receives pointer events, so the hover state has
    // to be gated here rather than at the listener.
    final hovered = _hovered && widget.enabled;
    final label = _label(color, hovered);
    return MouseRegion(
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.4,
          child: AnimatedContainer(
            duration: DswMotion.respecting(context, DswMotion.fast),
            height: _dense ? 28 : 36,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: _dense ? 10 : 14),
            decoration: BoxDecoration(
              color: _fill(color, hovered),
              border: _border(color, hovered),
              borderRadius: BorderRadius.circular(_dense ? 14 : 18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: _dense ? 12 : 14, color: label),
                  const SizedBox(width: 4),
                ],
                Text(
                  widget.label,
                  style: (_dense ? DswType.xxs12 : DswType.s14).copyWith(
                    color: label,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _fill(DswAlias color, bool hovered) {
    if (widget.variant == CapsuleVariant.primary) {
      return hovered ? color.buttonPrimaryHover : color.buttonPrimaryFill;
    }
    if (!hovered) return Colors.transparent;
    // A solid danger wash would swallow the label, so the outline variant keeps
    // the translucent token and shifts the text instead.
    return widget.danger
        ? color.interactiveBgHoverDanger
        : color.interactiveBgHover;
  }

  /// The stroke drops on a danger hover, where the fill is carrying the state on
  /// its own.
  BoxBorder? _border(DswAlias color, bool hovered) {
    if (widget.variant != CapsuleVariant.outline) return null;
    if (widget.danger && hovered) return null;
    return Border.all(color: color.borderL2);
  }

  Color _label(DswAlias color, bool hovered) {
    if (widget.variant == CapsuleVariant.primary) {
      return color.labelPrimaryForeground;
    }
    // The danger tint is worn at rest by a standalone destructive control
    // (`.dangerButton`) and on hover by one that shares a row with a safe
    // default (the approval row's reject).
    if (widget.danger) {
      return hovered ? color.stateErrorPrimary : color.labelPrimary;
    }
    return color.labelPrimary;
  }
}
