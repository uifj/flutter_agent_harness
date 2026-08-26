// The binding layer: hangs the alias tokens on `ThemeData` so widgets reach
// them through `context`, and maps them onto the Material surfaces Flutter
// paints on our behalf.
//
// Also home to the elevation tokens, which live here rather than in
// `dsw_alias.dart` because they are shadows, not colours, and dsh declares them
// once (`gradient-shadow-text.css:4-11`) without a dark-theme override.

import 'package:flutter/material.dart';

import 'dsw_alias.dart';
import 'dsw_typography.dart';

/// The `--dsw-shadow-*` elevation ramp.
///
/// CSS blur radius and Flutter's [BoxShadow.blurRadius] are different units, so
/// the values are converted rather than copied — see [_blur].
abstract final class DswShadow {
  /// CSS blurs with a Gaussian of `σ = blur / 2`, while Flutter derives σ from
  /// `blurRadius` as `radius * 0.57735 + 0.5`. Solving for radius keeps the two
  /// builds visually identical instead of merely numerically similar.
  static double _blur(double cssBlur) {
    final radius = (cssBlur / 2 - 0.5) / 0.57735;
    return radius < 0 ? 0 : radius;
  }

  /// `0 2px 4px 0 rgba(0, 0, 0, 0.05)`
  static final lv1 = <BoxShadow>[
    BoxShadow(
      offset: const Offset(0, 2),
      blurRadius: _blur(4),
      color: const Color.fromRGBO(0, 0, 0, 0.05),
    ),
  ];

  /// `0 4px 12px 0 rgba(0, 0, 0, 0.02)`
  static final lv1Blur = <BoxShadow>[
    BoxShadow(
      offset: const Offset(0, 4),
      blurRadius: _blur(12),
      color: const Color.fromRGBO(0, 0, 0, 0.02),
    ),
  ];

  /// `0 4px 12px 0 rgba(0, 0, 0, 0.02), 0 2px 8px 0 rgba(0, 0, 0, 0.04)`
  static final lv2 = <BoxShadow>[
    BoxShadow(
      offset: const Offset(0, 4),
      blurRadius: _blur(12),
      color: const Color.fromRGBO(0, 0, 0, 0.02),
    ),
    BoxShadow(
      offset: const Offset(0, 2),
      blurRadius: _blur(8),
      color: const Color.fromRGBO(0, 0, 0, 0.04),
    ),
  ];

  /// `0 0 1px 0 rgba(0,0,0,.2), 0 0 4px 0 rgba(0,0,0,.02),
  /// 0 12px 32px 0 rgba(0,0,0,.08)` — the hairline layer stands in for a border
  /// on floating surfaces, so it must survive the port.
  static final lv3 = <BoxShadow>[
    BoxShadow(
      blurRadius: _blur(1),
      color: const Color.fromRGBO(0, 0, 0, 0.2),
    ),
    BoxShadow(
      blurRadius: _blur(4),
      color: const Color.fromRGBO(0, 0, 0, 0.02),
    ),
    BoxShadow(
      offset: const Offset(0, 12),
      blurRadius: _blur(32),
      color: const Color.fromRGBO(0, 0, 0, 0.08),
    ),
  ];

  /// `--dsw-mask-blur: blur(2px)`, as a sigma for [ImageFilter.blur].
  static const maskBlurSigma = 1.0;
}

/// Carries the resolved [DswAlias] down the tree.
///
/// Typography ([DswType]), motion (`DswMotion`) and elevation ([DswShadow]) are
/// theme-independent in dsh, so only colour needs to ride on the theme.
@immutable
final class DswTheme extends ThemeExtension<DswTheme> {
  const DswTheme({required this.color});

  final DswAlias color;

  static const lightExtension = DswTheme(color: DswAlias.light);
  static const darkExtension = DswTheme(color: DswAlias.dark);

  @override
  DswTheme copyWith({DswAlias? color}) => DswTheme(color: color ?? this.color);

  /// Switches wholesale at the halfway point instead of interpolating.
  ///
  /// dsh swaps CSS custom properties, which is instantaneous — cross-fading 89
  /// tokens independently would invent intermediate palettes that the design
  /// system never sanctioned, and briefly produce unreadable contrast.
  @override
  DswTheme lerp(DswTheme? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}

/// Sugar for `Theme.of(context).extension<DswTheme>()!.color`.
///
/// Widgets should reach tokens this way and never name [DswAlias.light] or
/// [DswAlias.dark] directly, or they will not follow the theme.
extension DswThemeAccess on BuildContext {
  DswAlias get dsw => Theme.of(this).extension<DswTheme>()!.color;
}

/// Builds the `ThemeData` for one brightness.
///
/// The `ColorScheme` mapping exists so the Material widgets we do use (menus,
/// scrollbars, text selection) land on dsh colours instead of Material's
/// defaults. Feature code should still read tokens through [DswThemeAccess].
ThemeData dswThemeData(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final extension = isDark ? DswTheme.darkExtension : DswTheme.lightExtension;
  final c = extension.color;

  return ThemeData(
    brightness: brightness,
    extensions: [extension],
    scaffoldBackgroundColor: c.bgBase,
    canvasColor: c.bgBase,
    dividerColor: c.borderL2,
    splashFactory: NoSplash.splashFactory,
    // dsh is a pointer-first desktop UI; Material's touch-sized defaults would
    // inflate every control past the ported geometry.
    visualDensity: VisualDensity.compact,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.brandPrimary,
      onPrimary: c.labelPrimaryForeground,
      secondary: c.stateBusinessPrimary,
      onSecondary: c.labelPrimaryForeground,
      error: c.stateErrorPrimary,
      onError: c.labelPrimaryForeground,
      surface: c.bgLayer1,
      onSurface: c.labelPrimary,
      surfaceContainerHighest: c.bgLayer3,
      outline: c.borderL2,
      outlineVariant: c.borderL1,
      shadow: const Color.fromRGBO(0, 0, 0, 0.08),
    ),
    textTheme: TextTheme(
      // Only the roles dsh actually has a token for are filled in; leaving the
      // rest to Material is better than inventing sizes off-scale.
      headlineLarge: DswType.xl24,
      headlineMedium: DswType.l20,
      titleLarge: DswType.m18,
      titleMedium: DswType.baseStrong16,
      bodyLarge: DswType.base16,
      bodyMedium: DswType.s14,
      bodySmall: DswType.xs13,
      labelLarge: DswType.sStrong14,
      labelMedium: DswType.xxs12,
      labelSmall: DswType.xxxs11,
    ).apply(bodyColor: c.labelPrimary, displayColor: c.labelPrimary),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.tooltipBg,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: DswType.xxxs11.copyWith(color: c.labelPrimaryForeground),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.hovered)
            ? c.scrollbarHoverL1
            : c.scrollbarBgL1,
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.brandPrimary,
      selectionColor: c.bubbleHighlight,
      selectionHandleColor: c.brandPrimary,
    ),
  );
}
