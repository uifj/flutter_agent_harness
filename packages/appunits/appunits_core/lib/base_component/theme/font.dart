import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// iOS-only font-size scale factor.
///
/// SF Pro + PingFang on iOS render visually smaller than Roboto + Noto
/// Sans CJK on Android at the same logical pixel size, which made the
/// whole product feel "one size too small" on iPhones. We bump every
/// fontSize in the design system by this factor on iOS only — other
/// platforms keep the original size.
///
/// Hardcoded `fontSize: xx` literals scattered around the codebase are
/// NOT affected by this scale. Those should be migrated to FontScheme
/// over time; until then they will still look slightly small on iOS.
const double _kIosFontScale = 1.07;

double _scaled(double base) {
  return defaultTargetPlatform == TargetPlatform.iOS ? base * _kIosFontScale : base;
}

final SemanticFontScheme FontScheme = SemanticFontScheme(
  title1Bold: _Fonts.bold40,
  title2Bold: _Fonts.bold36,
  title3Bold: _Fonts.bold34,
  title4Bold: _Fonts.bold32,
  body1Bold: _Fonts.bold28,
  body2Bold: _Fonts.bold24,
  body3Bold: _Fonts.bold20,
  body4Bold: _Fonts.bold18,
  caption1Bold: _Fonts.bold16,
  caption2Bold: _Fonts.bold14,
  caption3Bold: _Fonts.bold12,
  caption4Bold: _Fonts.bold10,

  title1Medium: _Fonts.medium40,
  title2Medium: _Fonts.medium36,
  title3Medium: _Fonts.medium34,
  title4Medium: _Fonts.medium32,
  body1Medium: _Fonts.medium28,
  body2Medium: _Fonts.medium24,
  body3Medium: _Fonts.medium20,
  body4Medium: _Fonts.medium18,
  caption1Medium: _Fonts.medium16,
  caption2Medium: _Fonts.medium14,
  caption3Medium: _Fonts.medium12,
  caption4Medium: _Fonts.medium10,

  title1Regular: _Fonts.regular40,
  title2Regular: _Fonts.regular36,
  title3Regular: _Fonts.regular34,
  title4Regular: _Fonts.regular32,
  body1Regular: _Fonts.regular28,
  body2Regular: _Fonts.regular24,
  body3Regular: _Fonts.regular20,
  body4Regular: _Fonts.regular18,
  caption1Regular: _Fonts.regular16,
  caption2Regular: _Fonts.regular14,
  caption3Regular: _Fonts.regular12,
  caption4Regular: _Fonts.regular10,
);

class SemanticFontScheme {
  final TextStyle title1Bold;
  final TextStyle title2Bold;
  final TextStyle title3Bold;
  final TextStyle title4Bold;
  final TextStyle body1Bold;
  final TextStyle body2Bold;
  final TextStyle body3Bold;
  final TextStyle body4Bold;
  final TextStyle caption1Bold;
  final TextStyle caption2Bold;
  final TextStyle caption3Bold;
  final TextStyle caption4Bold;

  final TextStyle title1Medium;
  final TextStyle title2Medium;
  final TextStyle title3Medium;
  final TextStyle title4Medium;
  final TextStyle body1Medium;
  final TextStyle body2Medium;
  final TextStyle body3Medium;
  final TextStyle body4Medium;
  final TextStyle caption1Medium;
  final TextStyle caption2Medium;
  final TextStyle caption3Medium;
  final TextStyle caption4Medium;

  final TextStyle title1Regular;
  final TextStyle title2Regular;
  final TextStyle title3Regular;
  final TextStyle title4Regular;
  final TextStyle body1Regular;
  final TextStyle body2Regular;
  final TextStyle body3Regular;
  final TextStyle body4Regular;
  final TextStyle caption1Regular;
  final TextStyle caption2Regular;
  final TextStyle caption3Regular;
  final TextStyle caption4Regular;

  const SemanticFontScheme({
    required this.title1Bold,
    required this.title2Bold,
    required this.title3Bold,
    required this.title4Bold,
    required this.body1Bold,
    required this.body2Bold,
    required this.body3Bold,
    required this.body4Bold,
    required this.caption1Bold,
    required this.caption2Bold,
    required this.caption3Bold,
    required this.caption4Bold,
    required this.title1Medium,
    required this.title2Medium,
    required this.title3Medium,
    required this.title4Medium,
    required this.body1Medium,
    required this.body2Medium,
    required this.body3Medium,
    required this.body4Medium,
    required this.caption1Medium,
    required this.caption2Medium,
    required this.caption3Medium,
    required this.caption4Medium,
    required this.title1Regular,
    required this.title2Regular,
    required this.title3Regular,
    required this.title4Regular,
    required this.body1Regular,
    required this.body2Regular,
    required this.body3Regular,
    required this.body4Regular,
    required this.caption1Regular,
    required this.caption2Regular,
    required this.caption3Regular,
    required this.caption4Regular,
  });
}

class _Fonts {
  // All font sizes below pass through [_scaled] so iOS gets the
  // _kIosFontScale bump while other platforms keep the design value.
  // Because [_scaled] reads `defaultTargetPlatform` at call time these
  // can't be `const`; `static final` is the right shape — initialised
  // once per process when the class is first touched.
  static final TextStyle bold40 = TextStyle(fontSize: _scaled(40), fontWeight: FontWeight.bold);
  static final TextStyle bold36 = TextStyle(fontSize: _scaled(36), fontWeight: FontWeight.bold);
  static final TextStyle bold34 = TextStyle(fontSize: _scaled(34), fontWeight: FontWeight.bold);
  static final TextStyle bold32 = TextStyle(fontSize: _scaled(32), fontWeight: FontWeight.bold);
  static final TextStyle bold28 = TextStyle(fontSize: _scaled(28), fontWeight: FontWeight.bold);
  static final TextStyle bold24 = TextStyle(fontSize: _scaled(24), fontWeight: FontWeight.bold);
  static final TextStyle bold20 = TextStyle(fontSize: _scaled(20), fontWeight: FontWeight.bold);
  static final TextStyle bold18 = TextStyle(fontSize: _scaled(18), fontWeight: FontWeight.bold);
  static final TextStyle bold16 = TextStyle(fontSize: _scaled(16), fontWeight: FontWeight.bold);
  static final TextStyle bold14 = TextStyle(fontSize: _scaled(14), fontWeight: FontWeight.bold);
  static final TextStyle bold12 = TextStyle(fontSize: _scaled(12), fontWeight: FontWeight.bold);
  static final TextStyle bold10 = TextStyle(fontSize: _scaled(10), fontWeight: FontWeight.bold);

  static final TextStyle medium40 = TextStyle(fontSize: _scaled(40), fontWeight: FontWeight.w500);
  static final TextStyle medium36 = TextStyle(fontSize: _scaled(36), fontWeight: FontWeight.w500);
  static final TextStyle medium34 = TextStyle(fontSize: _scaled(34), fontWeight: FontWeight.w500);
  static final TextStyle medium32 = TextStyle(fontSize: _scaled(32), fontWeight: FontWeight.w500);
  static final TextStyle medium28 = TextStyle(fontSize: _scaled(28), fontWeight: FontWeight.w500);
  static final TextStyle medium24 = TextStyle(fontSize: _scaled(24), fontWeight: FontWeight.w500);
  static final TextStyle medium20 = TextStyle(fontSize: _scaled(20), fontWeight: FontWeight.w500);
  static final TextStyle medium18 = TextStyle(fontSize: _scaled(18), fontWeight: FontWeight.w500);
  static final TextStyle medium16 = TextStyle(fontSize: _scaled(16), fontWeight: FontWeight.w500);
  static final TextStyle medium14 = TextStyle(fontSize: _scaled(14), fontWeight: FontWeight.w500);
  static final TextStyle medium12 = TextStyle(fontSize: _scaled(12), fontWeight: FontWeight.w500);
  static final TextStyle medium10 = TextStyle(fontSize: _scaled(10), fontWeight: FontWeight.w500);

  static final TextStyle regular40 = TextStyle(fontSize: _scaled(40), fontWeight: FontWeight.normal);
  static final TextStyle regular36 = TextStyle(fontSize: _scaled(36), fontWeight: FontWeight.normal);
  static final TextStyle regular34 = TextStyle(fontSize: _scaled(34), fontWeight: FontWeight.normal);
  static final TextStyle regular32 = TextStyle(fontSize: _scaled(32), fontWeight: FontWeight.normal);
  static final TextStyle regular28 = TextStyle(fontSize: _scaled(28), fontWeight: FontWeight.normal);
  static final TextStyle regular24 = TextStyle(fontSize: _scaled(24), fontWeight: FontWeight.normal);
  static final TextStyle regular20 = TextStyle(fontSize: _scaled(20), fontWeight: FontWeight.normal);
  static final TextStyle regular18 = TextStyle(fontSize: _scaled(18), fontWeight: FontWeight.normal);
  static final TextStyle regular16 = TextStyle(fontSize: _scaled(16), fontWeight: FontWeight.normal);
  static final TextStyle regular14 = TextStyle(fontSize: _scaled(14), fontWeight: FontWeight.normal);
  static final TextStyle regular12 = TextStyle(fontSize: _scaled(12), fontWeight: FontWeight.normal);
  static final TextStyle regular10 = TextStyle(fontSize: _scaled(10), fontWeight: FontWeight.normal);
}
