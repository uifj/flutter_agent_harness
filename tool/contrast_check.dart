// The one runnable check behind docs/design-audit-2026-09.md section A2.
//
// Parses lib/theme/dsw_static.dart + dsw_alias.dart (only dart:io/dart:math,
// so `dart tool/contrast_check.dart` runs on a fresh clone before pub get)
// and computes WCAG 2.x contrast ratios for the token pairs the audit named,
// compositing translucent tokens over their surface. Pairs below 4.5:1 are
// printed FAIL/LARGE-ONLY; the light theme has known debt there (audit A2),
// so read the output as a regression tripwire, not a gate: what must never
// happen is the DARK theme or currently-passing pairs regressing.
//
// Run: dart tool/contrast_check.dart
library;

import 'dart:io';
import 'dart:math' as math;

typedef Rgba = (double, double, double, double);

final _staticRe = RegExp(
  r'static const (\w+) = Color\.from(ARGB|RGB)\(([^)]*)\)',
);
final _aliasRe = RegExp(
  r'(\w+): (?:Color\.from(?:RGB|ARGB)\([^)]*\)|DswStatic\.(\w+))',
);

Map<String, Rgba> _parseStatic(String src) {
  final out = <String, Rgba>{};
  for (final m in _staticRe.allMatches(src)) {
    final v = m.group(3)!.split(',').map(double.parse).toList();
    out[m.group(1)!] = m.group(2) == 'ARGB'
        ? (v[1], v[2], v[3], v[0] / 255)
        : (v[0], v[1], v[2], v[3]);
  }
  return out;
}

Map<String, Rgba> _parseAlias(String block, Map<String, Rgba> static) {
  final out = <String, Rgba>{};
  for (final m in _aliasRe.allMatches(block)) {
    final name = m.group(1)!, ref = m.group(2);
    if (ref != null) {
      final v = static[ref];
      if (v != null) out[name] = v;
      continue;
    }
    final cm = RegExp(
      '(\\w+): Color\\.from(ARGB|RGB)\\(([^)]*)\\)',
    ).allMatches(block).firstWhere((x) => x.group(1) == name);
    final v = cm.group(3)!.split(',').map(double.parse).toList();
    out[name] = cm.group(2) == 'ARGB'
        ? (v[1], v[2], v[3], v[0] / 255)
        : (v[0], v[1], v[2], v[3]);
  }
  return out;
}

double _lin(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _lum((double, double, double) c) =>
    0.2126 * _lin(c.$1 / 255) +
    0.7152 * _lin(c.$2 / 255) +
    0.0722 * _lin(c.$3 / 255);

double _ratio(Rgba fg, Rgba bg) {
  final f = fg.$4 < 1
      ? (
          fg.$1 * fg.$4 + bg.$1 * (1 - fg.$4),
          fg.$2 * fg.$4 + bg.$2 * (1 - fg.$4),
          fg.$3 * fg.$4 + bg.$3 * (1 - fg.$4),
        )
      : (fg.$1, fg.$2, fg.$3);
  final l1 = _lum(f), l2 = _lum((bg.$1, bg.$2, bg.$3));
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final root = Platform.script.toFilePath().replaceAll('\\', '/');
  final repo = root.substring(0, root.lastIndexOf('/tool/'));
  final static = _parseStatic(
    File('$repo/lib/theme/dsw_static.dart').readAsStringSync(),
  );
  final aliasSrc = File('$repo/lib/theme/dsw_alias.dart').readAsStringSync();
  final themes = {
    'light': _parseAlias(
      aliasSrc.substring(
        aliasSrc.indexOf('static const light'),
        aliasSrc.indexOf('static const dark'),
      ),
      static,
    ),
    'dark': _parseAlias(
      aliasSrc.substring(aliasSrc.indexOf('static const dark')),
      static,
    ),
  };

  const pairs = [
    ('labelPrimary', 'bgBase'),
    ('labelSecondary', 'bgBase'),
    ('labelTertiary', 'bgBase'),
    ('labelCaption', 'bgBase'),
    ('labelDimmed', 'bgBase'),
    ('labelPrimary', 'bubble'),
    ('stateWarnLabel', 'bgBase'),
    ('stateWarnPrimary', 'stateWarnTertiary'),
    ('stateSuccessPrimary', 'bgBase'),
    ('stateErrorPrimary', 'bgBase'),
    ('labelPrimaryForeground', 'buttonPrimaryFill'),
    ('labelPrimaryForeground', 'buttonInfoFill'),
    ('labelSecondary', 'sidebarFill'),
  ];

  var failures = 0;
  for (final e in themes.entries) {
    for (final (fgk, bgk) in pairs) {
      final fg = e.value[fgk], bg = e.value[bgk];
      if (fg == null || bg == null) continue;
      final r = _ratio(fg, bg);
      final grade = r >= 4.5 ? 'PASS' : (r >= 3.0 ? 'LARGE-ONLY' : 'FAIL');
      if (r < 4.5) failures++;
      print('${e.key.padRight(6)} $fgk/$bgk: ${r.toStringAsFixed(2)}:1 $grade');
    }
  }
  print(
    failures == 0
        ? 'All checked pairs >= 4.5:1.'
        : '$failures pair(s) below 4.5:1 — light-theme debt is known '
              '(docs/design-audit-2026-09.md A2); watch for DARK regressions.',
  );
}
