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
import 'package:agent_harness/ui/primitives/tappable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadIconButton;
import 'package:flutter_test/flutter_test.dart';

// What the control resolves for its two states. shad paints the wash through
// its own decorator — a `CustomPaint`, not a `BoxDecoration` this file could
// read — so the ladder is asserted on the state colours the primitive hands it,
// which is the same shift ADR-0029 accepted for a dialog's radius. What stays
// behavioural is the part that can be: a disabled control takes no tap, an
// enabled one does.
class _States {
  const _States(this.button);
  final ShadIconButton button;
  Color? get washAtRest => button.backgroundColor;
  Color? get washOnHover => button.hoverBackgroundColor;
  Color? get glyphAtRest => button.foregroundColor;
  Color? get glyphOnHover => button.hoverForegroundColor;
}

_States _states(WidgetTester tester) => _States(
  tester.widget<ShadIconButton>(
    find.descendant(
      of: find.byType(DswIconButton),
      matching: find.byType(ShadIconButton),
    ),
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

      final states = _states(tester);
      expect(
        states.glyphAtRest,
        DswAlias.dark.labelCaption,
        reason: 'the disabled step of the ladder, not a per-site guess',
      );
      // One spelling of off all the way down: `onTap == null` is the only thing
      // a call site says, and shad's own disabled state is what withholds the
      // wash on hover — no second `enabled` field to disagree with the first.
      expect(states.button.enabled, isFalse);
      expect(states.button.onPressed, isNull);

      await tester.tap(find.byType(DswIconButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the body is shad\'s, and no second tap layer is left under it', (
      tester,
    ) async {
      await _pump(tester, onTap: () {});
      // The primitive stays the only icon control, and what it stands on is now
      // the library's button: focus ring, disabled dimming and the semantic
      // press all stop being re-implemented per copy (ADR-0036 decision 3).
      expect(
        find.descendant(
          of: find.byType(DswIconButton),
          matching: find.byType(ShadIconButton),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DswIconButton),
          matching: find.byType(DswHoverTap),
        ),
        findsNothing,
      );
    });

    testWidgets('the wash and the brighter glyph arrive together', (
      tester,
    ) async {
      var taps = 0;
      await _pump(tester, onTap: () => taps++);

      final states = _states(tester);
      expect(states.washAtRest, Colors.transparent);
      expect(states.glyphAtRest, DswAlias.dark.labelSecondary);

      // Together, not one without the other: a glyph that brightened over no
      // wash — or a wash behind a glyph that stayed put — is the split this
      // primitive exists to prevent.
      expect(states.washOnHover, DswAlias.dark.interactiveBgHover);
      expect(states.glyphOnHover, DswAlias.dark.labelPrimary);

      await _hover(tester);

      await tester.tap(find.byType(DswIconButton));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  });
}
