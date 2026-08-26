// Spot-checks the token port. The failure this guards against is an off-by-one
// row while transcribing 89 aliases twice — which produces a plausible-looking
// UI that is subtly wrong, not a crash.
//
// Sampled rather than exhaustive: asserting all 89 pairs would just be the same
// transcription a second time, and would fail for the same reason.

import 'dart:ui';

import 'package:agent_harness/theme/dsw_alias.dart';
import 'package:agent_harness/theme/dsw_static.dart';
import 'package:agent_harness/theme/dsw_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('static palette', () {
    test('rgb() values land on the right channels', () {
      // design-platform.css:27 — rgb(65, 118, 230)
      expect(DswStatic.deepseek500, const Color.fromARGB(255, 65, 118, 230));
      // :54 — rgb(15, 17, 21), the near-black that anchors light-theme text.
      expect(DswStatic.neutralBluish1000, const Color.fromARGB(255, 15, 17, 21));
    });

    test('neutral-bluish-60 is the one entry that differs by theme', () {
      expect(
        DswStatic.neutralBluish60Light,
        const Color.fromARGB(255, 245, 246, 247),
      );
      expect(
        DswStatic.neutralBluish60Dark,
        const Color.fromARGB(255, 249, 250, 251),
      );
      // The dark value collides with -50, which is why the light/dark split has
      // to be carried explicitly instead of folded into one constant.
      expect(DswStatic.neutralBluish60Dark, DswStatic.neutralBluish50);
    });
  });

  group('alias layer resolves to the intended static entry', () {
    test('surfaces invert between themes', () {
      expect(DswAlias.light.bgBase, DswStatic.neutralBluish00);
      expect(DswAlias.dark.bgBase, DswStatic.neutralBluish950);
    });

    test('light collapses the three layers onto white; dark separates them', () {
      expect(DswAlias.light.bgLayer1, DswAlias.light.bgLayer3);
      expect(DswAlias.dark.bgLayer1, isNot(DswAlias.dark.bgLayer3));
    });

    test('text inverts with the surface', () {
      expect(DswAlias.light.labelPrimary, DswStatic.neutralBluish1000);
      expect(DswAlias.dark.labelPrimary, DswStatic.neutralBluish50);
    });

    test('the user bubble is DeepSeek-tinted in light, neutral in dark', () {
      expect(DswAlias.light.bubble, DswStatic.deepseek50);
      expect(DswAlias.dark.bubble, DswStatic.neutralBluish850);
    });

    test('the neutral-bluish-60 consumers pick up the light variant', () {
      // The five light aliases that point at -60. Getting these wrong is
      // invisible in dark, where none of them reference it.
      expect(DswAlias.light.bgModulePlatform, DswStatic.neutralBluish60Light);
      expect(DswAlias.light.bgMultiSelect, DswStatic.neutralBluish60Light);
      expect(DswAlias.light.markdownPlaceholder, DswStatic.neutralBluish60Light);
      expect(DswAlias.light.selector, DswStatic.neutralBluish60Light);
      expect(DswAlias.light.tip, DswStatic.neutralBluish60Light);
    });

    test('borders keep the alpha the source wrote', () {
      // rgba(0, 0, 0, 0.04) light, rgba(255, 255, 255, 0.06) dark.
      expect(DswAlias.light.borderL1.a, closeTo(0.04, 0.005));
      expect(DswAlias.dark.borderL1.a, closeTo(0.06, 0.005));
      expect(DswAlias.dark.borderL1.r, 1);
    });

    test('fully transparent borders survive as transparent', () {
      expect(DswAlias.light.borderInverted.a, 0);
      expect(DswAlias.dark.borderInverted.a, greaterThan(0));
    });

    test('aliases that point at another alias are dereferenced correctly', () {
      // --dsw-alias-button-primary-fill: var(--dsw-alias-brand-primary)
      expect(DswAlias.light.buttonPrimaryFill, DswAlias.light.brandPrimary);
      expect(DswAlias.dark.buttonPrimaryFill, DswAlias.dark.brandPrimary);
      // --dsw-specific-menu: var(--dsw-alias-bg-layer-3)
      expect(DswAlias.light.menu, DswAlias.light.bgLayer3);
      expect(DswAlias.dark.menu, DswAlias.dark.bgLayer3);
    });

    test('tokens the source leaves theme-invariant stay identical', () {
      expect(DswAlias.light.stateWarnPrimary, DswAlias.dark.stateWarnPrimary);
      expect(DswAlias.light.buttonToolBarFill, DswAlias.dark.buttonToolBarFill);
      expect(DswAlias.light.bgMaskPhoto, DswAlias.dark.bgMaskPhoto);
    });
  });

  group('typography', () {
    test('height is the CSS line-height expressed as a multiplier', () {
      // font: 500 13px/20px
      expect(DswType.xsStrong13.fontSize, 13);
      expect(DswType.xsStrong13.height, 20 / 13);
      expect(DswType.xsStrong13.fontWeight, FontWeight.w500);
    });

    test('every style carries both a size and a height', () {
      final styles = {
        'xl24': DswType.xl24,
        'l20': DswType.l20,
        'm18': DswType.m18,
        'base16': DswType.base16,
        'baseStrong16': DswType.baseStrong16,
        's14': DswType.s14,
        'sStrong14': DswType.sStrong14,
        'xs13': DswType.xs13,
        'xsStrong13': DswType.xsStrong13,
        'xxs12': DswType.xxs12,
        'xxsStrong12': DswType.xxsStrong12,
        'xxxs11': DswType.xxxs11,
        'xxxsStrong11': DswType.xxxsStrong11,
        'markdownBase': DswType.markdownBase,
        'markdownCode': DswType.markdownCode,
        'markdownCodeBlockSmall': DswType.markdownCodeBlockSmall,
      };
      for (final entry in styles.entries) {
        expect(entry.value.fontSize, isNotNull, reason: entry.key);
        expect(entry.value.height, isNotNull, reason: entry.key);
      }
    });

    test('the bubble style matches the ported 16px/24px', () {
      expect(DswType.base16.fontSize, 16);
      expect(DswType.base16.height, 24 / 16);
    });

    test('code styles use the code stack, prose styles do not', () {
      expect(DswType.markdownCode.fontFamily, dswFontFamilyCode);
      expect(DswType.markdownBase.fontFamily, dswFontFamily);
    });

    test('italic variants differ from their upright twin by style alone', () {
      final italic = DswType.markdownBaseItalic;
      final upright = DswType.markdownBase;
      expect(italic.fontStyle, FontStyle.italic);
      // Not compared whole: the upright style leaves `fontStyle` unset, which is
      // not the same object as an explicit `normal`.
      expect(italic.fontSize, upright.fontSize);
      expect(italic.height, upright.height);
      expect(italic.fontWeight, upright.fontWeight);
      expect(italic.fontFamily, upright.fontFamily);
    });
  });
}
