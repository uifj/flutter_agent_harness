// Spot-checks the token port. The failure this guards against is an off-by-one
// row while transcribing 89 aliases twice — which produces a plausible-looking
// UI that is subtly wrong, not a crash.
//
// Sampled rather than exhaustive: asserting all 89 pairs would just be the same
// transcription a second time, and would fail for the same reason.

import 'dart:io';
import 'dart:ui';

import 'package:agent_harness/theme/dsw_alias.dart';
import 'package:agent_harness/theme/dsw_static.dart';
import 'package:agent_harness/theme/dsw_shape.dart';
import 'package:agent_harness/theme/dsw_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('static palette', () {
    test('rgb() values land on the right channels', () {
      // design-platform.css:27 — rgb(65, 118, 230)
      expect(DswStatic.deepseek500, const Color.fromARGB(255, 65, 118, 230));
      // :54 — rgb(15, 17, 21), the near-black that anchors light-theme text.
      expect(
        DswStatic.neutralBluish1000,
        const Color.fromARGB(255, 15, 17, 21),
      );
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

    test(
      'light collapses the three layers onto white; dark separates them',
      () {
        expect(DswAlias.light.bgLayer1, DswAlias.light.bgLayer3);
        expect(DswAlias.dark.bgLayer1, isNot(DswAlias.dark.bgLayer3));
      },
    );

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
      expect(
        DswAlias.light.markdownPlaceholder,
        DswStatic.neutralBluish60Light,
      );
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

  // ADR-0017: shape has one source of truth, and the two interactive states are
  // two different tokens. These are scans rather than value checks because the
  // failure they guard is "someone added a 13th radius", which no fixed
  // assertion can catch.
  group('shape token contract', () {
    test('no widget picks its own radius', () {
      // Not a digit-only check: `wide ? 12 : 999` is a widget picking two radii
      // with no tier names in sight, and it reads as a ternary to a regex that
      // only looks for `[0-9]` right after the paren.
      final circular = RegExp(r'Radius\.circular\(\s*');
      final offenders = <String>[];
      for (final entry in Directory('lib/ui').listSync(recursive: true)) {
        if (entry is! File || !entry.path.endsWith('.dart')) continue;
        final source = entry.readAsStringSync();
        for (final match in circular.allMatches(source)) {
          final argument = source.substring(match.end);
          if (argument.startsWith('DswShape.')) continue;
          final line =
              '\n'.allMatches(source.substring(0, match.start)).length + 1;
          offenders.add(
            '${entry.path}:$line  ${argument.split('\n').first.trim()}',
          );
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'a radius must name a DswShape tier (ADR-0017)',
      );
    });

    test('the radius scale decreases inward, and pill is last', () {
      expect([
        DswShape.inset,
        DswShape.inner,
        DswShape.control,
        DswShape.card,
        DswShape.shell,
        DswShape.float,
      ], orderedEquals([4.0, 6.0, 8.0, 10.0, 12.0, 16.0]));
      expect(DswShape.pill, greaterThan(DswShape.float));
    });

    test('spacing is on the 4px rhythm', () {
      for (final step in [
        DswShape.xs,
        DswShape.sm,
        DswShape.md,
        DswShape.lg,
        DswShape.xl,
      ]) {
        expect(step % 4, 0, reason: 'base unit is 4px');
      }
    });

    test('selected is NOT the same colour as hover, in either theme', () {
      // The whole point of ADR-0017 S2: one colour for both means hovering a
      // row fakes an active state.
      expect(
        DswAlias.light.interactiveSelected,
        isNot(DswAlias.light.interactiveBgHover),
      );
      expect(
        DswAlias.dark.interactiveSelected,
        isNot(DswAlias.dark.interactiveBgHover),
      );
      // And it must sit between hover and the accent step, so it reads as a
      // state rather than as a pressed control.
      expect(
        DswAlias.light.interactiveSelected.a,
        greaterThan(DswAlias.light.interactiveBgHover.a),
      );
      expect(
        DswAlias.light.interactiveSelected.a,
        lessThan(DswAlias.light.interactiveBgHoverAccent.a),
      );
    });
  });

  group('motion ramp', () {
    // A transition duration is a token too. Eleven of the thirteen `Animated*`
    // sites in `lib/ui` take `DswMotion.respecting(context, …)`; two in
    // `sidebar.dart` had invented `const Duration(milliseconds: 50)` instead —
    // a hover wash that faded twice as fast as every other hover wash in the
    // app, and one that kept animating for users who asked for reduced motion
    // (ADR-0023's second instance of "a timing value with two truths").
    //
    // The scan follows the opening line of each `Animated*` widget rather than
    // every `duration:` in the file, on purpose: an `AnimationController`'s
    // duration is a loop period (the thinking shimmer, the row sweep), not a
    // transition, and forcing those onto the ramp would be wrong.
    test('no transition in lib/ui invents its own duration', () {
      final opener = RegExp(r'Animated(Container|Switcher|Size|CrossFade)\(');
      final offenders = <String>[];
      for (final file in Directory('lib/ui').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (!opener.hasMatch(lines[i])) continue;
          for (var j = i + 1; j <= i + 4 && j < lines.length; j++) {
            final trimmed = lines[j].trim();
            if (!trimmed.startsWith('duration:')) continue;
            final tokenised =
                trimmed.contains('DswMotion') ||
                trimmed == 'duration: duration,';
            if (!tokenised) offenders.add('${file.path}:${j + 1}  $trimmed');
            break;
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'hover/press transitions read the ramp (DswMotion.fast/normal/slow) '
            'so reduced motion is honoured everywhere and one interaction never '
            'moves faster than the same interaction elsewhere.',
      );
    });
  });

  group('glyphs sit on the icon ramp', () {
    // `lib/ui` spelled its glyph sizes as 10, 11, 12, 13, 14, 15, 16, 18 — eight
    // steps where the reference has four (`button.tsx:33-37`: 10/12/14/16, each
    // paired with a box size). 11 and 13 are not decisions, they are the numbers
    // someone typed while the surrounding text was 12px. ADR-0026.
    test('no Icon names a size off the ramp', () {
      const onRamp = {10, 12, 14, 16, 18, 20, 24, 28, 32, 34, 40};
      final literal = RegExp(r'\b(?:icon)?[Ss]ize: (\d+)(?:\.0)?,');
      final offenders = <String>[];
      for (final file in Directory('lib/ui').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final match = literal.firstMatch(lines[i]);
          if (match == null) continue;
          if (!onRamp.contains(int.parse(match.group(1)!))) {
            offenders.add('${file.path}:${i + 1}  ${lines[i].trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a glyph size that is not a step of the ramp reads as a rounding '
            'accident: use DswShape.iconCaption/iconTiny/iconSm/iconMd/iconLg '
            '(20 and up are boxes and decorative marks, not glyph steps).',
      );
    });
  });

  group('a style name never lies about its size', () {
    // `DswType.xs13.copyWith(fontSize: 12, …)` renders 12 while its name says 13.
    // Two numbers for one fact, and the reader of the call site is told the wrong
    // one (ADR-0014's shape, ADR-0022's "a comment that admits it is still a
    // lying control"). Re-sizing a named step is how the type scale grew a
    // shadow copy of itself: 18 under `l20`, 26 under `xl24`, 15 under `s14`.
    test('no call site resteps a DswType size', () {
      final declared = {
        for (final match in RegExp(
          r'static final (\w+) = _(?:ui|code)\((\d+),',
        ).allMatches(File('lib/theme/dsw_typography.dart').readAsStringSync()))
          match.group(1)!: int.parse(match.group(2)!),
      };
      expect(declared.length, greaterThan(10), reason: 'the parse rotted');

      final opener = RegExp(r'DswType\.(\w+)\.copyWith\($');
      final resizer = RegExp(r'fontSize: (\d+)(?:\.0)?,');
      final lies = <String>[];
      for (final file in Directory('lib/ui').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final start = opener.firstMatch(lines[i].trim());
          if (start == null) continue;
          final step = declared[start.group(1)!];
          expect(
            step,
            isNotNull,
            reason: '${start.group(1)} is not on the ramp',
          );
          for (var j = i + 1; j <= i + 6 && j < lines.length; j++) {
            final sized = resizer.firstMatch(lines[j].trim());
            if (sized == null) continue;
            if (int.parse(sized.group(1)!) != step) {
              lies.add(
                '${file.path}:${j + 1}  DswType.${start.group(1)} '
                '(=$step) renders ${sized.group(1)}',
              );
            }
            break;
          }
        }
      }
      expect(
        lies,
        isEmpty,
        reason:
            'a step that renders another number is a second truth about the '
            'type scale. Read the step that has the size you want, or name the '
            'new one in dsw_typography.dart.',
      );
    });
  });

  group('every shape token has a reader', () {
    // ADR-0022's law aimed at the theme layer. A constant nothing reads is not
    // harmless: it is a second spelling of a value someone will later
    // contradict, and it hides the real defect — the widget that wrote its own
    // number instead of reading the token. `DswShape.rowSession` was dead while
    // `sidebar.dart` spelled that same row as `36` twice (ADR-0025).
    test('no DswShape member is declared and never used', () {
      final definition = File('lib/theme/dsw_shape.dart');
      final declared = RegExp(r'^\s+static const (\w+) =', multiLine: true)
          .allMatches(definition.readAsStringSync())
          .map((match) => match.group(1)!)
          .toList();
      expect(declared, isNotEmpty, reason: 'the parse found no tokens at all');

      final sources = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart') && file != definition)
          .map((file) => MapEntry(file.path, file.readAsStringSync()))
          .toList();

      final unread = [
        for (final name in declared)
          if (!sources.any(
            (entry) => RegExp('DswShape\\.$name\\b').hasMatch(entry.value),
          ))
            name,
      ];
      expect(
        unread,
        isEmpty,
        reason:
            'a shape token with no reader is a claim nothing verifies. Either '
            'wire the surface that means to use it, or delete the constant '
            '(ADR-0025).',
      );
    });
  });
}
