// Pill: the small rounded label chip, ported from `ui-primitives/src/Pill.tsx`
// and its stylesheet.
//
// The source has an interactive arm (a `<button>` with hover and active states)
// for view-switcher tabs and filters. Nothing in this build has those surfaces
// yet, so only the static chip is ported — the terminal card's exit-status pill.
// The interactive arm drops in beside it when a caller needs one.

import 'package:flutter/material.dart';

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
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.bgLayer2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DswType.xxs12.copyWith(color: color ?? scheme.labelSecondary),
      ),
    );
  }
}
