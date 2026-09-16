// The starkins grouping frame (ADR-0005 S2).
//
// starkins' settings page reads as a stack of rounded, hairline-bordered cards,
// each holding a group of label/value rows. Borrowing that *form* is the point of
// the rebuild; borrowing its *controls* is not — this panel already has dsw-
// re-tokenized equivalents of everything starkins' `settings_controls.dart`
// offers: `_SettingCellRow` is its SettingRow+SettingSelect (a title/description
// row with a 36px selector pill), `_SwitchRow`/`_Switch` is its SettingToggle, and
// `_heading` is its SettingsPageTitle. Re-implementing those here would be a
// second source of the same control (ADR-0005 guard #6, and the reuse ladder).
//
// The one thing the panel lacks is the enclosing card: its `_general` list today
// runs the hairline-separated rows straight onto the panel fill with no frame.
// So this file supplies just that frame, matching the existing card idiom in
// `model_settings.dart` (`_providerRowCard`): border-only surface, radius 12,
// `borderL2` — not starkins' filled `cs.card`.
//
// The reused rows draw their own separators, so by default the frame adds none
// (that would double them). It only insets horizontally so a row's text does not
// touch the side border; rows keep their own vertical padding. When [dividers] is
// set, the frame instead draws the hairline between rows itself — the choice for a
// group that mixes the self-spacing selector rows with the bare `_SwitchRow`s. In
// that mode pass `last: true` to every `_SettingCellRow` inside so it suppresses
// its own bottom border and the card stays the single source of separation.

import 'package:flutter/widgets.dart';

import '../../../theme/dsw_theme.dart';

/// A rounded, hairline-bordered surface that stacks full-width setting rows into
/// one visual group. The [children] are expected to be the panel's row widgets
/// (`_SettingCellRow` / `_SwitchRow`), which supply their own vertical padding.
/// With [dividers] off they also draw the separators between them (last row
/// suppressing its own); with [dividers] on the card draws them instead.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    required this.children,
    this.dividers = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final List<Widget> children;

  /// Whether the frame draws a hairline between consecutive rows. Off by
  /// default, leaving the rows to separate themselves.
  final bool dividers;

  /// Horizontal inset for the row content. The rows carry their own vertical
  /// padding, so the frame adds none vertically.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (dividers && i > 0) {
        rows.add(SizedBox(height: 1, child: ColoredBox(color: color.borderL2)));
      }
      rows.add(children[i]);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.borderL2),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}
