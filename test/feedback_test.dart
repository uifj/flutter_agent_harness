// The feedback strip belongs to the app, not to the framework.
//
// Nine messages used to be painted by a Material `SnackBar`: the framework's
// own radius, typography and animation, shown by a `ScaffoldMessenger` nothing
// else in this app uses. That made the surface a user is most likely to meet —
// a save that failed, a backup that finished — the one surface outside the token
// system, and it had no test: nothing proved the message ever reached a screen.
//
// So this file holds four claims: the strip paints what the caller passed, a
// failure says so in a distinguishable variant, the strip keeps its label when
// the system amplifies text (adopting a library component hands its geometry to
// the library, which is worth re-walking rather than assuming), and a host with
// no strip loses the toast without crashing — the behaviour the previews rely
// on.

import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/primitives/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'amplified_text_probe.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String message = 'Saved 12 files',
    bool destructive = false,
    bool withStrip = true,
    double step = 1.0,
  }) => tester.pumpWidget(
    MaterialApp(
      // The same seam `main.dart` uses: the step composes ABOVE the Navigator,
      // and the strip's host sits inside the bridged theme so it takes
      // `DswAlias` colours.
      builder: (context, child) {
        final themed = ShadTheme(
          data: dswShadTheme(Brightness.light),
          child: withStrip ? ShadSonner(child: child!) : child!,
        );
        return AmplifiedText(step: step, child: themed);
      },
      theme: dswThemeData(Brightness.light),
      home: Scaffold(
        body: Builder(
          builder: (context) => Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  showFeedback(context, message, destructive: destructive),
              child: const Text('say it'),
            ),
          ),
        ),
      ),
    ),
  );

  Future<void> say(WidgetTester tester) async {
    await tester.tap(find.text('say it'));
    await tester.pump();
  }

  // The toast dismisses itself after its theme's duration, and a timer left
  // running when the tree goes away fails the test for the wrong reason. This
  // outlives any default and lets the fade finish.
  Future<void> expire(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
  }

  testWidgets('the strip paints the message the caller passed', (tester) async {
    await pump(tester);
    await say(tester);

    expect(find.text('Saved 12 files'), findsOneWidget);
    // The one place that decides whether the user was told at all.
    expect(tester.takeException(), isNull);

    await expire(tester);
    expect(find.text('Saved 12 files'), findsNothing);
  });

  testWidgets('a failure is not the same strip as a success', (tester) async {
    await pump(tester);
    await say(tester);
    final calm = tester.widget<ShadToast>(find.byType(ShadToast)).variant;

    await expire(tester);
    await pump(tester, message: 'Could not save: disk full', destructive: true);
    await say(tester);

    expect(find.text('Could not save: disk full'), findsOneWidget);
    final loud = tester.widget<ShadToast>(find.byType(ShadToast)).variant;
    // One state, one token — the same law ADR-0017 S2 set for hover/selected.
    expect(loud, isNot(equals(calm)));
    // Named on both sides, because a one-sided difference proves nothing if the
    // default constructor is not the calm one.
    expect(calm, ShadToastVariant.primary);
    expect(loud, ShadToastVariant.destructive);

    await expire(tester);
  });

  testWidgets('no strip means no toast and no crash', (tester) async {
    await pump(tester, withStrip: false);
    await say(tester);

    expect(find.text('Saved 12 files'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // The library's own seat: the toast's title is one line of chrome inside a
  // box the component sizes. Nothing about the ruler's law changes because the
  // widget came from `shadcn_ui`, so it gets measured like every other face.
  group('amplified text', () {
    for (final (label, step) in const [
      ('1.8x', amplifiedTextStep),
      ('2.2x', nextTextStep),
    ]) {
      testWidgets('the strip keeps its label ($label)', (tester) async {
        const msg = 'Restored 7 sessions from the zip';
        // Measured at the designed step first. If the harness's own wiring
        // dropped the scaler — the trap `chat_view_test` fell in — the pass
        // below would be measuring the same pixels twice and calling it proof.
        await pump(tester, message: msg);
        await say(tester);
        final at1 = tester.getSize(find.text(msg)).height;
        await expire(tester);

        await pump(tester, step: step, message: msg);
        await say(tester);
        expect(
          tester.getSize(find.text(msg)).height,
          greaterThan(at1),
          reason: 'the step has to reach the library subtree',
        );
        expect(find.text(msg), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the feedback strip');

        await expire(tester);
      });
    }
  });
}
