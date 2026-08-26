// Layer 1 of the dsh design-token system: the raw palette.
//
// A 1:1 port of `--dsw-static-*` from
// `deepseek-harness/packages/client/ui-theme/src/styles/design-platform.css`
// (lines 5-77 light, 81-153 dark). Written as `Color.fromARGB(255, r, g, b)` so
// each line reads like the `rgb(r, g, b)` it came from and stays diffable
// against the source.
//
// The two layers must stay separate: feature code consumes only the alias layer
// (`dsw_alias.dart`), never this file. That is a hard rule in dsh's
// `docs/web-styling.md`, and it is what makes theme switching a remap of one
// layer instead of a sweep through every widget.
//
// Light and dark declare byte-identical palettes with exactly ONE exception,
// `neutral-bluish-60`, which is why it appears here as two named constants.

import 'dart:ui';

/// The `--dsw-static-*` palette. Not for direct use in widgets.
abstract final class DswStatic {
  static const amber100 = Color.fromARGB(255, 254, 245, 231);
  static const amber400 = Color.fromARGB(255, 247, 173, 49);
  static const amber500 = Color.fromARGB(255, 245, 158, 11);
  static const amber600 = Color.fromARGB(255, 221, 134, 41);
  static const amber900 = Color.fromARGB(255, 39, 36, 31);

  static const blue50 = Color.fromARGB(255, 239, 246, 255);
  static const blue50p = Color.fromARGB(255, 234, 243, 255);
  static const blue75 = Color.fromARGB(255, 229, 240, 255);
  static const blue100 = Color.fromARGB(255, 219, 234, 254);
  static const blue300 = Color.fromARGB(255, 147, 197, 253);
  static const blue400 = Color.fromARGB(255, 96, 165, 250);
  static const blue450 = Color.fromARGB(255, 77, 147, 248);
  static const blue500 = Color.fromARGB(255, 59, 130, 246);
  static const blue600 = Color.fromARGB(255, 37, 99, 235);
  static const blue800 = Color.fromARGB(255, 30, 64, 175);
  static const blue900 = Color.fromARGB(255, 14, 48, 116);
  static const blue950 = Color.fromARGB(255, 23, 37, 84);

  static const deepseek50 = Color.fromARGB(255, 237, 243, 254);
  static const deepseek100 = Color.fromARGB(255, 228, 237, 253);
  static const deepseek200 = Color.fromARGB(255, 211, 226, 255);
  static const deepseek300 = Color.fromARGB(255, 183, 200, 254);
  static const deepseek400 = Color.fromARGB(255, 103, 158, 254);
  static const deepseek450 = Color.fromARGB(255, 86, 134, 254);

  /// The DeepSeek brand blue.
  static const deepseek500 = Color.fromARGB(255, 65, 118, 230);
  static const deepseek600 = Color.fromARGB(255, 72, 104, 178);

  /// Ported verbatim including the `-delete` suffix the source uses to mark it
  /// as on its way out. Do not reference it from new aliases.
  static const deepseek700Delete = Color.fromARGB(255, 47, 76, 143);
  static const deepseek800 = Color.fromARGB(255, 52, 65, 91);
  static const deepseek900 = Color.fromARGB(255, 40, 49, 66);

  static const green100 = Color.fromARGB(255, 230, 250, 237);
  static const green400 = Color.fromARGB(255, 78, 209, 126);
  static const green500 = Color.fromARGB(255, 34, 197, 94);
  static const green900 = Color.fromARGB(255, 35, 60, 44);

  static const neutral00 = Color.fromARGB(255, 255, 255, 255);
  static const neutral50 = Color.fromARGB(255, 250, 250, 250);
  static const neutral100 = Color.fromARGB(255, 245, 245, 245);
  static const neutral150 = Color.fromARGB(255, 237, 237, 237);
  static const neutral200 = Color.fromARGB(255, 229, 229, 229);
  static const neutral250 = Color.fromARGB(255, 220, 220, 220);
  static const neutral300 = Color.fromARGB(255, 212, 212, 212);
  static const neutral400 = Color.fromARGB(255, 162, 164, 166);
  static const neutral500 = Color.fromARGB(255, 127, 130, 135);
  static const neutral550 = Color.fromARGB(255, 101, 103, 107);
  static const neutral600 = Color.fromARGB(255, 84, 85, 87);
  static const neutral700 = Color.fromARGB(255, 60, 60, 61);
  static const neutral800 = Color.fromARGB(255, 41, 41, 41);
  static const neutral850 = Color.fromARGB(255, 33, 33, 35);
  static const neutral900 = Color.fromARGB(255, 15, 15, 15);
  static const neutral1000 = Color.fromARGB(255, 0, 0, 0);

  static const neutralBluish00 = Color.fromARGB(255, 255, 255, 255);
  static const neutralBluish50 = Color.fromARGB(255, 249, 250, 251);

  /// The only palette entry that differs between themes.
  static const neutralBluish60Light = Color.fromARGB(255, 245, 246, 247);

  /// The only palette entry that differs between themes.
  static const neutralBluish60Dark = Color.fromARGB(255, 249, 250, 251);

  static const neutralBluish75 = Color.fromARGB(255, 241, 243, 245);
  static const neutralBluish100 = Color.fromARGB(255, 235, 238, 242);
  static const neutralBluish150 = Color.fromARGB(255, 233, 236, 242);
  static const neutralBluish200 = Color.fromARGB(255, 225, 229, 238);
  static const neutralBluish300 = Color.fromARGB(255, 207, 211, 214);
  static const neutralBluish400 = Color.fromARGB(255, 173, 178, 184);
  static const neutralBluish500 = Color.fromARGB(255, 151, 157, 166);
  static const neutralBluish600 = Color.fromARGB(255, 129, 133, 140);
  static const neutralBluish700 = Color.fromARGB(255, 97, 102, 107);
  static const neutralBluish750 = Color.fromARGB(255, 67, 69, 74);
  static const neutralBluish800 = Color.fromARGB(255, 53, 54, 56);
  static const neutralBluish850 = Color.fromARGB(255, 44, 44, 46);
  static const neutralBluish875 = Color.fromARGB(255, 35, 35, 36);
  static const neutralBluish900 = Color.fromARGB(255, 27, 27, 28);
  static const neutralBluish950 = Color.fromARGB(255, 21, 21, 23);
  static const neutralBluish1000 = Color.fromARGB(255, 15, 17, 21);

  static const red50 = Color.fromARGB(255, 254, 242, 242);
  static const red100 = Color.fromARGB(255, 254, 226, 226);
  static const red400 = Color.fromARGB(255, 242, 90, 90);
  static const red500 = Color.fromARGB(255, 239, 68, 68);
  static const red600 = Color.fromARGB(255, 236, 19, 19);
  static const red900 = Color.fromARGB(255, 87, 12, 12);
}
