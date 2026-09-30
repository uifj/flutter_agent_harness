// Pill: the small rounded label chip, ported from `ui-primitives/src/Pill.tsx`
// and its stylesheet — now drawn by shad's badge (ADR-0036 row 33).
//
// What the wrapper still owns is the geometry a caller passes: the chip's seat
// rides the text step (ADR-0017 S3) and the corner is `shell`, not the badge's
// control tier, because this chip floats on a card rather than being a control.
//
// The source has an interactive arm (a `<button>` with hover and active states)
// for view-switcher tabs and filters; `ShadBadge.onPressed` is that arm, and
// nothing here needs it yet — the terminal card's exit-status pill is the only
// reader, and it is static.

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadBadge;

import '../../theme/dsw_shape.dart';
import '../../theme/dsw_shad_bridge.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, this.height = 24, this.color});

  final String label;

  /// 24 is the chip's own height. A caller on a smaller font overrides it: the
  /// terminal card caps the pill to its 22px prompt line, because the chip's own
  /// height would stretch the banner around it.
  final double height;

  /// Text colour. Defaults to `label-secondary`; the terminal card's status pill
  /// overrides it with the error token, which is the pill's whole point there.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = context.dsw;
    return dswEnsureShadTheme(
      context,
      ShadBadge(
        backgroundColor: scheme.bgLayer2,
        foregroundColor: color ?? scheme.labelSecondary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(DswShape.shell)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          // The caller's number is a design-px line (24 here, 22 for the
          // terminal's prompt row), so it rides the text step: at 1.8x the 12px
          // label wanted 32.0 inside the 24.0 seat and was cut top and bottom
          // (ADR-0017 S3).
          height: height * MediaQuery.textScalerOf(context).scale(1),
          // `widthFactor`, because a chip in an unbounded row must not reach for
          // the whole line — `Center` would, and the badge would overflow the
          // banner it is pinned to. Its width is its label.
          child: Align(
            widthFactor: 1,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // The typography stays this file's: the bridge maps no text theme,
              // so a badge that inherited shad's ramp would fork a second one.
              style: DswType.xxs12,
            ),
          ),
        ),
      ),
    );
  }
}
