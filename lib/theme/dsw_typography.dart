// dsh typography, ported from the token sheet rather than reverse-engineered
// from component call sites.
//
// Source: `deepseek-harness/packages/client/ui-theme/src/styles/`
//   - `gradient-shadow-text.css:21-232` — the full `--dsw-font-*` table, exported
//     from Figma by dsh's `custom-variable-name` plugin. This is authoritative.
//   - `base.css:6-15` — the two font stacks.
//
// Every entry pairs a size with a line height, because that is what the CSS
// shorthand `font: 500 13px/20px var(--dsw-font-family)` does. Never set a size
// without its height; that rule is spelled out in dsh's `docs/web-styling.md`
// and is why these are whole `TextStyle`s and not loose numbers.
//
// Two CSS-to-Flutter conversions worth knowing:
//   - `height` is a multiplier, so `20px/13px` becomes `height: 20 / 13`.
//   - `leadingDistribution: even` splits the extra leading above and below the
//     text the way CSS `line-height` does. Flutter's default (`proportional`)
//     follows font metrics instead and would sit glyphs a hair off from the web
//     build.

import 'dart:ui' show FontStyle, FontWeight, TextLeadingDistribution;

import 'package:flutter/painting.dart' show TextStyle;

/// `--dsw-font-family`, from `base.css:7-8`.
///
/// `.AppleSystemUIFont` resolves to SF on macOS, standing in for the
/// `-apple-system, BlinkMacSystemFont` head of the CSS stack.
const dswFontFamily = '.AppleSystemUIFont';

const dswFontFamilyFallback = <String>[
  'Segoe UI',
  'PingFang SC',
  'Hiragino Sans GB',
  'Microsoft YaHei',
  'Helvetica Neue',
  'Helvetica',
  'Arial',
];

/// `--ds-font-family-code`, from `base.css:9-10`.
///
/// The stack deliberately ends without a bare `monospace`: on Windows that tail
/// drags CJK text into SimSun. Kept as-is even though this build is macOS-only,
/// so the two codebases stay comparable.
const dswFontFamilyCode = 'SF Mono';

const dswFontFamilyCodeFallback = <String>[
  'JetBrains Mono',
  'Fira Code',
  'Consolas',
  'Liberation Mono',
  'Menlo',
  'Courier',
  'PingFang SC',
  'Microsoft YaHei',
];

TextStyle _ui(double size, double lineHeight, FontWeight weight) => TextStyle(
  fontFamily: dswFontFamily,
  fontFamilyFallback: dswFontFamilyFallback,
  fontSize: size,
  height: lineHeight / size,
  fontWeight: weight,
  leadingDistribution: TextLeadingDistribution.even,
);

TextStyle _code(double size, double lineHeight) => TextStyle(
  fontFamily: dswFontFamilyCode,
  fontFamilyFallback: dswFontFamilyCodeFallback,
  fontSize: size,
  height: lineHeight / size,
  fontWeight: FontWeight.w400,
  leadingDistribution: TextLeadingDistribution.even,
);

/// The `--dsw-font-*` scale. Names drop the prefix and keep the trailing px
/// number, so `--dsw-font-xs-strong-13` is [xsStrong13] and can be grepped in
/// either direction.
abstract final class DswType {
  // ---- UI scale -----------------------------------------------------------
  // `strong` is weight 500 against the plain variant's 400, except at the two
  // largest steps where the source jumps to 600.

  static final xl24 = _ui(24, 32, FontWeight.w600);
  static final l20 = _ui(20, 28, FontWeight.w500);

  /// Named `m-18` upstream but really 16px/28px — the Figma export kept the
  /// step's name after its size was reduced. Ported by value, not by name.
  static final m18 = _ui(16, 28, FontWeight.w500);

  static final base16 = _ui(16, 24, FontWeight.w400);
  static final baseStrong16 = _ui(16, 24, FontWeight.w500);
  static final s14 = _ui(14, 22, FontWeight.w400);
  static final sStrong14 = _ui(14, 22, FontWeight.w500);
  static final xs13 = _ui(13, 20, FontWeight.w400);
  static final xsStrong13 = _ui(13, 20, FontWeight.w500);
  static final xxs12 = _ui(12, 18, FontWeight.w400);
  static final xxsStrong12 = _ui(12, 18, FontWeight.w500);
  static final xxxs11 = _ui(11, 14, FontWeight.w400);
  static final xxxsStrong11 = _ui(11, 14, FontWeight.w500);

  // ---- Markdown scale -----------------------------------------------------
  // A separate ramp with looser line heights, for prose rather than chrome.

  static final markdownH1 = _ui(24, 34, FontWeight.w700);
  static final markdownH2 = _ui(22, 32, FontWeight.w700);
  static final markdownH3 = _ui(20, 30, FontWeight.w700);
  static final markdownH4 = _ui(16, 28, FontWeight.w600);

  static final markdownBase = _ui(16, 28, FontWeight.w400);
  static final markdownBaseStrong = _ui(16, 28, FontWeight.w600);
  static final markdownBaseItalic = _ui(16, 28, FontWeight.w400).italic;
  static final markdownBaseStrongItalic = _ui(
    16,
    28,
    FontWeight.w600,
  ).italic;

  static final markdownSmall = _ui(14, 24, FontWeight.w400);
  static final markdownSmallStrong = _ui(14, 24, FontWeight.w600);
  static final markdownSmallItalic = _ui(14, 24, FontWeight.w400).italic;
  static final markdownSmallStrongItalic = _ui(
    14,
    24,
    FontWeight.w600,
  ).italic;

  static final markdownTable = _ui(15, 25, FontWeight.w400);
  static final markdownTableHead = _ui(15, 25, FontWeight.w500);

  /// Inline code inside prose.
  static final markdownCode = _code(14, 22);
  static final markdownCodeBlock = _code(13, 22);

  /// Hand-added upstream (not from the Figma export) for code inside an
  /// expanded tool row — which is exactly what `ui/tool/tool_card.dart` needs.
  static final markdownCodeBlockSmall = _code(12, 18);
}

extension on TextStyle {
  /// The `-italic` variants differ from their upright twins by `font-style`
  /// alone, so they are derived instead of respelled.
  TextStyle get italic => copyWith(fontStyle: FontStyle.italic);
}
