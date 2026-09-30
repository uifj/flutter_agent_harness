// One icon button, not four.
//
// ADR-0021 gathered the tap primitive under these; the copy-paste above it
// survived. Three private classes in `lib/ui/workbench/tabs/` each rebuilt
// `Tooltip + DswHoverTap + hover wash` and then disagreed about radius, shape,
// the colour ladder, and how "disabled" is said — `browser_tab.dart` even had an
// `enabled` field next to a nullable `onTap`, and for the back/forward buttons
// the two already answered differently (ADR-0024).
//
// So the scan below pins the merge, and the two hover checks pin what a call
// site must never have to re-implement: null `onTap` being the *only* way to say
// "nothing to do", and the tooltip doubling as the accessible name. Hover is
// drivable here (a real `MouseRegion.onEnter`, unlike a Tooltip's timer, which a
// synthetic pointer never starts — see `tooltip_timing_test.dart`).

import 'dart:io';

import 'package:agent_harness/theme/dsw_alias.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/primitives/icon_button.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

/// The control's own wash layer, which is the only `AnimatedContainer` it draws.
BoxDecoration _wash(WidgetTester tester) =>
    (tester
            .widget<AnimatedContainer>(
              find.descendant(
                of: find.byType(DswIconButton),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .decoration!
        as BoxDecoration);

Icon _glyph(WidgetTester tester) => tester.widget<Icon>(
  find.descendant(
    of: find.byType(DswIconButton),
    matching: find.byIcon(LucideIcons.refresh_cw),
  ),
);

Future<void> _pump(
  WidgetTester tester, {
  required VoidCallback? onTap,
  double size = 28,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: dswThemeData(Brightness.dark),
      home: Scaffold(
        body: Center(
          child: DswIconButton(
            icon: LucideIcons.refresh_cw,
            tooltip: 'Refresh the tree',
            onTap: onTap,
            size: size,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _hover(WidgetTester tester) async {
  final gesture = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: 7,
  );
  addTearDown(gesture.removePointer);
  await gesture.addPointer(
    location: tester.getCenter(find.byType(DswIconButton)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('one icon button', () {
    test('no surface draws its own private icon button', () {
      final byFile = <String, int>{};
      final declaration = RegExp(r'class _\w*Icon\w*Button\b');
      for (final file in Directory('lib/ui').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final hits = file
            .readAsLinesSync()
            .where((line) => declaration.hasMatch(line))
            .length;
        if (hits > 0) byFile[file.path] = hits;
      }
      expect(
        byFile,
        {'lib/ui/sidebar/sidebar.dart': 1},
        reason:
            'a second private icon button is a second set of answers about '
            'radius, shape, the colour ladder and what "disabled" means. The '
            'shared one is `ui/primitives/icon_button.dart` (ADR-0024). The '
            'rail control is the recorded exception: its icons rest at '
            'labelPrimary because the rail carries no text, and the collapse '
            'toggle swaps both glyph and size on hover.',
      );
    });

    testWidgets('a null onTap says everything: dim, inert, and never washed', (
      tester,
    ) async {
      await _pump(tester, onTap: null);
      await _hover(tester);

      expect(
        _glyph(tester).color,
        DswAlias.dark.labelCaption,
        reason: 'the disabled step of the ladder, not a per-site guess',
      );
      expect(
        _wash(tester).color,
        isNull,
        reason: 'hovering a control with nothing to do must not offer it',
      );

      await tester.tap(find.byType(DswIconButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the wash and the brighter glyph arrive together', (
      tester,
    ) async {
      var taps = 0;
      await _pump(tester, onTap: () => taps++);

      expect(_wash(tester).color, isNull);
      expect(_glyph(tester).color, DswAlias.dark.labelSecondary);

      await _hover(tester);
      expect(_wash(tester).color, DswAlias.dark.interactiveBgHover);
      expect(_glyph(tester).color, DswAlias.dark.labelPrimary);

      await tester.tap(find.byType(DswIconButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
