// The capsule button.
//
// A port of `ui-primitives/src/Button.module.css` (figma 1:155): the two
// sizes (`md` h36 / r18 / 14-22, `sm` h28 / r14 / 12-18) and the three fills
// the rest of this build asks for. dsh reaches for this same control in the
// approval row and all through the settings panel, so it lives in primitives
// rather than being spelled twice.
//
// Since ADR-0002 stage 5 the *mechanics* are shad's `ShadButton` — focus
// traversal, keyboard activation, the pressed/hover/disabled state machine,
// and the `Semantics(button: true)` node that the hand-rolled
// MouseRegion+GestureDetector pair never had. The *appearance* stays dsh's:
// geometry and every colour are passed from the alias layer here, and the
// public API (variants, sizes, danger) is unchanged, so no call site moved.
//
// Two deliberate deltas against the CSS port:
//   * A focused control draws shad's focus ring; dsh (pointer-first web CSS)
//     never specified one. That is the point of the swap — keyboard parity.
//   * A danger `outline` hover keeps its stroke. shad varies background and
//     foreground by state but not the border, and dropping the stroke was a
//     cosmetic flourish the fill wash already carries.

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../theme/dsw_shad_bridge.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';

/// The three fills in use. `ghost` is `outline` without the stroke — dsh's
/// `.ghost`, which it uses where a row already has chrome of its own.
enum CapsuleVariant { primary, outline, ghost }

/// `md` is the default; `sm` is the dense row variant (`.sm`).
enum CapsuleSize { md, sm }

class CapsuleButton extends StatelessWidget {
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

  /// Rendered at 14px in the `md` size and 12px in `sm`, ahead of the label
  /// with the 4px gap `.button` sets (shad's own leading gap).
  final IconData? icon;

  final bool enabled;

  /// Turns the hover red and washes red, as `.dangerButton` and the approval
  /// row's reject override do. Ignored by [CapsuleVariant.primary], which has
  /// no destructive form in the source.
  final bool danger;

  bool get _dense => size == CapsuleSize.sm;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final isPrimary = variant == CapsuleVariant.primary;

    return dswEnsureShadTheme(
      context,
      ShadButton(
        onPressed: enabled ? onTap : null,
        enabled: enabled,
        // figma 1:155 geometry, per size.
        height: _dense ? 28 : 36,
        padding: EdgeInsets.symmetric(horizontal: _dense ? 10 : 14),
        backgroundColor: isPrimary
            ? color.buttonPrimaryFill
            : Colors.transparent,
        hoverBackgroundColor: isPrimary
            ? color.buttonPrimaryHover
            : danger
            ? color.interactiveBgHoverDanger
            : color.interactiveBgHover,
        foregroundColor: isPrimary
            ? color.labelPrimaryForeground
            : color.labelPrimary,
        // The danger tint is worn on hover by a control that shares a row
        // with a safe default (the approval row's reject); at rest a
        // standalone destructive control wears it via [labelColor] below.
        hoverForegroundColor: isPrimary
            ? color.labelPrimaryForeground
            : danger
            ? color.stateErrorPrimary
            : color.labelPrimary,
        decoration: ShadDecoration(
          border: variant == CapsuleVariant.outline
              ? ShadBorder.fromBorderSide(
                  ShadBorderSide(color: color.borderL2, width: 1),
                  radius: BorderRadius.circular(_dense ? 14 : 18),
                )
              : ShadBorder(radius: BorderRadius.circular(_dense ? 14 : 18)),
        ),
        leading: icon == null ? null : Icon(icon, size: _dense ? 12 : 14),
        child: Text(label, style: _dense ? DswType.xxs12 : DswType.s14),
      ),
    );
  }
}
