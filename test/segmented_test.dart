// The segmented control the library does not ship, and the two things a swap
// of its body could quietly lose.
//
// ADR-0036 decision 2 (mapping row 1): `shadcn_ui` 0.56.3 has a Tabs, a
// RadioGroup, a Select and a Switch, and none of them is a two-cell either/or
// sitting in a track — so the third rung applies: wrap it, and let the cell's
// body be the library's button. The track, the seat and the shedding rule stay
// ours because shad has no opinion about them.
//
// Which is exactly why this file exists. The cells used to be drawn here with
// `DswHoverTap`, which answers the keyboard; a swap to `ShadButton` moves that
// answer into someone else's widget, and nothing in the suite would notice if
// the new one did not take a Tab stop. So claim 2 is the swap's regression
// surface, and claim 3 the shed label's: `ShadButton` has no `semanticLabel`, so
// the name rides on a `Semantics` node added at this level, and if it stopped
// being added the control would read as two anonymous glyphs.
//
// Claim 1 is the ADR-0036 claim itself (the body is the library's), and is the
// reason a bare tap layer under it would be a second answer to the same
// question.

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/primitives/segmented.dart';
import 'package:planstar/ui/primitives/tappable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadButton;

import 'amplified_text_probe.dart';

enum _Mode { plan, agent }

const _segments = [
  DswSegment<_Mode>(
    value: _Mode.plan,
    label: 'Plan',
    icon: LucideIcons.book_open,
  ),
  DswSegment<_Mode>(
    value: _Mode.agent,
    label: 'Agent',
    icon: LucideIcons.message_square,
  ),
];

/// Pumps the track [width] wide under [step] of the platform's scaler, and hands
/// back the cells [onSelect] heard from.
Future<List<_Mode>> _pumpTrack(
  WidgetTester tester, {
  double step = 1.0,
  double width = 280,
}) async {
  final picked = <_Mode>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),

      theme: dswThemeData(Brightness.dark),
      builder: (context, child) => amplifiedAppBuilder(step, child),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: DswSegmented<_Mode>(
              segments: _segments,
              selected: _Mode.plan,
              onSelect: picked.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picked;
}

void main() {
  testWidgets(
    'a cell is the library button, with nothing hand-drawn under it',
    (tester) async {
      await _pumpTrack(tester);
      expect(
        find.descendant(
          of: find.byType(DswSegmented<_Mode>),
          matching: find.byType(ShadButton),
        ),
        findsNWidgets(_segments.length),
      );
      expect(
        find.descendant(
          of: find.byType(DswSegmented<_Mode>),
          matching: find.byType(DswHoverTap),
        ),
        findsNothing,
        reason:
            'a second tap layer under the cell is a second answer about '
            'focus, hover and what a press looks like (ADR-0021).',
      );
    },
  );

  testWidgets('the keyboard reaches a cell and picks it', (tester) async {
    final picked = await _pumpTrack(tester);

    // Traversal order is the segments' order, so the first Tab stop is 企划.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(picked, [
      _Mode.plan,
    ], reason: 'the cell took the Tab stop and answered Space');

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(picked, [_Mode.plan, _Mode.agent]);
  });

  testWidgets('a cell too narrow for its word sheds the word, not the name', (
    tester,
  ) async {
    // The name is the `Semantics` wrapper the primitive adds, not the word: a
    // cell that still draws its label contributes that text to the node anyway,
    // so a semantics-label finder would match both states and prove nothing.
    final namedCell = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Plan',
    );

    await _pumpTrack(tester);
    expect(find.text('Plan'), findsOneWidget);
    expect(namedCell, findsNothing);
    // The designed step is the control's own size; the seat law says every
    // other step is this one multiplied, not this one kept.
    expect(tester.getSize(find.byType(DswSegmented<_Mode>)).height, 32);

    await _pumpTrack(tester, step: amplifiedTextStep);
    expect(find.text('Plan'), findsNothing);
    expect(namedCell, findsOneWidget);
    expect(
      tester.getSize(find.byType(DswSegmented<_Mode>)).height,
      closeTo(32 * amplifiedTextStep, 0.001),
    );
    expect(textDefects(tester), isEmpty);
    expect(tester.takeException(), isNull);
  });
}
