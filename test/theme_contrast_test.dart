// The CI-able form of tool/contrast_check.dart (audit A2), turned into a
// regression gate rather than a design change.
//
// Why a gate and not a palette fix here: the dsw light palette is a faithful
// 1:1 port of dsh's design-platform.css, and it genuinely falls below WCAG AA
// on six text pairs (audit A2, debt-register). Recoloring those is a design
// decision needing product sign-off (it breaks the upstream-diffable port), so
// it is proposed in ADR-0004, not applied blindly. What we CAN lock today is
// that nobody makes it worse: every checked pair must meet AA (4.5:1) unless it
// is on this file's explicit allowlist of known debt. A new pair dropping below
// AA — or a token someone lightens — fails here instead of shipping.
//
// When ADR-0004 lands and a debt pair is fixed, delete its allowlist line; the
// second test below catches a stale allowlist entry that already passes.

import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:agent_harness/theme/dsw_alias.dart';
import 'package:flutter_test/flutter_test.dart';

double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _lum((double, double, double) c) =>
    0.2126 * _lin(c.$1) + 0.7152 * _lin(c.$2) + 0.0722 * _lin(c.$3);

/// WCAG contrast of [fg] over [bg], compositing [fg]'s alpha onto [bg] first.
double _contrast(Color fg, Color bg) {
  (double, double, double) rgb(Color c) => (c.r, c.g, c.b);
  final base = rgb(bg);
  final f = fg.a < 1
      ? (
          fg.r * fg.a + base.$1 * (1 - fg.a),
          fg.g * fg.a + base.$2 * (1 - fg.a),
          fg.b * fg.a + base.$3 * (1 - fg.a),
        )
      : rgb(fg);
  final l1 = _lum(f);
  final l2 = _lum(base);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

/// text token painted on a surface token, as used across the UI.
const _pairs = <String, (String fg, String bg)>{
  'labelPrimary/bgBase': ('labelPrimary', 'bgBase'),
  'labelSecondary/bgBase': ('labelSecondary', 'bgBase'),
  'labelTertiary/bgBase': ('labelTertiary', 'bgBase'),
  'labelCaption/bgBase': ('labelCaption', 'bgBase'),
  'labelDimmed/bgBase': ('labelDimmed', 'bgBase'),
  'labelPrimary/bubble': ('labelPrimary', 'bubble'),
  'stateWarnLabel/bgBase': ('stateWarnLabel', 'bgBase'),
  'stateWarnPrimary/stateWarnTertiary': (
    'stateWarnPrimary',
    'stateWarnTertiary',
  ),
  'stateSuccessPrimary/bgBase': ('stateSuccessPrimary', 'bgBase'),
  'stateErrorPrimary/bgBase': ('stateErrorPrimary', 'bgBase'),
  'labelPrimaryForeground/buttonPrimaryFill': (
    'labelPrimaryForeground',
    'buttonPrimaryFill',
  ),
  'labelPrimaryForeground/buttonInfoFill': (
    'labelPrimaryForeground',
    'buttonInfoFill',
  ),
  'labelSecondary/sidebarFill': ('labelSecondary', 'sidebarFill'),
};

/// Known-below-AA pairs (audit A2 / ADR-0004), as `theme/pairName`. Each is a
/// deliberate, signed-off exception — fix the token and delete the line.
const _allowlistedDebt = <String>{
  'light/labelTertiary/bgBase',
  'light/labelCaption/bgBase',
  'light/labelDimmed/bgBase',
  'light/stateWarnLabel/bgBase',
  'light/stateWarnPrimary/stateWarnTertiary',
  'light/stateSuccessPrimary/bgBase',
  'light/labelPrimaryForeground/buttonInfoFill',
  'dark/labelDimmed/bgBase',
};

Map<String, Color> _tokens(DswAlias c) => {
  'labelPrimary': c.labelPrimary,
  'labelSecondary': c.labelSecondary,
  'labelTertiary': c.labelTertiary,
  'labelCaption': c.labelCaption,
  'labelDimmed': c.labelDimmed,
  'bubble': c.bubble,
  'bgBase': c.bgBase,
  'stateWarnLabel': c.stateWarnLabel,
  'stateWarnPrimary': c.stateWarnPrimary,
  'stateWarnTertiary': c.stateWarnTertiary,
  'stateSuccessPrimary': c.stateSuccessPrimary,
  'stateErrorPrimary': c.stateErrorPrimary,
  'labelPrimaryForeground': c.labelPrimaryForeground,
  'buttonPrimaryFill': c.buttonPrimaryFill,
  'buttonInfoFill': c.buttonInfoFill,
  'sidebarFill': c.sidebarFill,
};

void main() {
  const themes = [('light', DswAlias.light), ('dark', DswAlias.dark)];

  // WCAG conformance is judged on the ratio rounded to hundredths, so 4.4996 is
  // a "4.50" pass. Compare that way or every borderline token false-trips.
  double grade(Color fg, Color bg) =>
      double.parse(_contrast(fg, bg).toStringAsFixed(2));

  test('no non-exempted text token pair falls below WCAG AA 4.5:1', () {
    final failures = <String>[];
    for (final (name, alias) in themes) {
      final t = _tokens(alias);
      for (final entry in _pairs.entries) {
        final key = '$name/${entry.key}';
        final r = grade(t[entry.value.$1]!, t[entry.value.$2]!);
        if (r < 4.5 && !_allowlistedDebt.contains(key)) {
          failures.add('$key = ${r.toStringAsFixed(2)}:1 (not allowlisted)');
        }
      }
    }
    expect(
      failures,
      isEmpty,
      reason:
          'New sub-AA text contrast regression:\n${failures.join('\n')}\n'
          'If intentional+signed-off, add to _allowlistedDebt; else fix the token.',
    );
  });

  test('allowlist stays honest: every exempted pair really is below AA', () {
    for (final key in _allowlistedDebt) {
      final alias = key.startsWith('light') ? DswAlias.light : DswAlias.dark;
      final pairName = key.substring(key.indexOf('/') + 1);
      final (fgk, bgk) = _pairs[pairName]!;
      final t = _tokens(alias);
      final r = grade(t[fgk]!, t[bgk]!);
      expect(
        r < 4.5,
        isTrue,
        reason:
            '$key now passes AA (${r.toStringAsFixed(2)}:1) — remove it '
            'from _allowlistedDebt so the gate keeps biting.',
      );
    }
  });
}
