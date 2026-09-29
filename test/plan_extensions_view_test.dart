// The one sentence this file holds: the board, the calendar and the table are
// three projections of ONE `PlanTaskStore` — an add, a toggle and a remove made
// in the shared row land in all three — and no panel clips when the system
// amplifies text.
//
// ADR-0007 D4 mounted these panels, and its guards covered the STORE
// (`plan_task_store_test.dart`) but never the panels: until now the only proof
// they render at all was the app being run. The 1.8x check is ADR-0017 S3's
// shared probe, so the plan mode's chrome is measured with the same ruler as the
// shell, the workbench tabs and the settings page.

import 'dart:async';
import 'dart:io';

import 'package:agent_harness/state/plan_task_store.dart';
import 'package:agent_harness/state/workspace_mode_controller.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/plan/plan_extensions_view.dart';
import 'amplified_text_probe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadInput, ShadTheme;

void main() {
  late Directory root;
  late PlanTaskStore store;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('dsh_plan_panels_');
    store = await PlanTaskStore.open(root);
    await store.add('write the intro', dueDate: DateTime(2026, 9, 20));
    await store.add('draft outline', groupIndex: 1);
  });

  tearDown(() {
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        root.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        sleep(const Duration(milliseconds: 25));
      }
    }
  });

  Future<void> pump(
    WidgetTester tester,
    PlanExtensionView view, {
    double scale = 1.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: child!,
        ),
        home: Scaffold(
          body: AmplifiedText(
            step: scale,
            child: PlanExtensionsView(store: store, view: view),
          ),
        ),
      ),
    );
    // One extra frame: the board's drag machinery and the calendar animate on
    // mount, and a single pump leaves them at their first tick.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Hands the loop real time until [finder] matches. The store's
  /// `notifyListeners` sits behind an atomic file write, and a `testWidgets`
  /// body runs under FakeAsync - which never yields to the real event loop, so a
  /// panel repaint cannot be forced with fake pumps alone (same reason
  /// `plan_workspace_test.dart` has a `pumpUntil`).
  Future<void> settled(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 50; attempt++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    throw TestFailure('never appeared: $finder');
  }

  /// The same drain for the other direction - a row leaving is the fact the
  /// removal test actually needs proven.
  Future<void> settledGone(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 50; attempt++) {
      if (finder.evaluate().isEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    throw TestFailure('never went away: $finder');
  }

  testWidgets('the table projects every task, dated or not', (tester) async {
    await pump(tester, PlanExtensionView.table);

    expect(tester.takeException(), isNull);
    expect(find.text('Task'), findsOneWidget);
    expect(find.text('write the intro'), findsOneWidget);
    expect(find.text('2026-09-20'), findsOneWidget);
    expect(find.text('draft outline'), findsOneWidget);
    // The undated task shows the em dash, not an empty cell - a blank column
    // reads as a rendering bug to the person looking at it.
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('the shared add row writes through to the panel', (tester) async {
    await pump(tester, PlanExtensionView.table);

    await tester.enterText(find.byType(ShadInput).first, 'ship the audit note');
    await tester.tap(find.text('Add'));
    // Scoped to the panel's own scroll view: `find.text` matches an `EditableText`
    // as readily as a `Text`, so the unscoped version of this finder is satisfied
    // by the field the title was typed into and settles on nothing. The add row is
    // a sibling of this scroll view, so the scope cannot be reached that way.
    await settled(
      tester,
      find.descendant(
        of: find.byType(SingleChildScrollView),
        matching: find.text('ship the audit note'),
      ),
    );

    expect(store.tasks.length, 3);
    // The row is for the NEXT task, so it has to empty itself: a kept title reads
    // as "not saved" and gets typed a second time. `find.text` matches an
    // `EditableText` as well as a `Text`, so two hits here mean the field still
    // holds it and one means the panel shows it while the field let go.
    expect(find.text('ship the audit note'), findsOneWidget);
  });

  testWidgets('the check marks done and the cross removes, through the store', (
    tester,
  ) async {
    await pump(tester, PlanExtensionView.table);

    await tester.tap(find.byIcon(LucideIcons.circle).first);
    await settled(tester, find.byIcon(LucideIcons.check));
    expect(store.tasks.where((task) => task.done).length, 1);

    await tester.tap(find.byIcon(LucideIcons.x).first);
    // The removed row has to LEAVE the panel, not just the store: this table was
    // the panel that rendered `store.tasks` without subscribing to it.
    await settledGone(tester, find.text('write the intro'));
    expect(store.tasks.length, 1);
    expect(find.text('draft outline'), findsOneWidget);
  });

  testWidgets('the board groups the same store under the four column names', (
    tester,
  ) async {
    await pump(tester, PlanExtensionView.board);

    expect(tester.takeException(), isNull);
    for (final column in const ['To do', 'In progress', 'Review', 'Done']) {
      expect(find.text(column), findsWidgets, reason: column);
    }
    expect(find.text('write the intro'), findsOneWidget);
    // The card carries the short date; the full ISO string is the table's.
    expect(find.text('09-20'), findsOneWidget);
  });

  testWidgets('the calendar mounts the dated task without an exception', (
    tester,
  ) async {
    await pump(tester, PlanExtensionView.calendar);

    expect(tester.takeException(), isNull);
    // The add row above the grid is the host's, and the day cell now is too
    // (`_DayCell`), so the dated task's own title is on screen.
    expect(find.text('New task title'), findsOneWidget);
    expect(find.text('write the intro'), findsOneWidget);
  });

  testWidgets("tapping a day's task toggles it through the store", (
    tester,
  ) async {
    await pump(tester, PlanExtensionView.calendar);

    await tester.tap(find.text('write the intro'));
    expect(store.tasks.first.done, isTrue);

    // The strike-through is the panel's side of the same write, and it lands
    // only once the store's atomic save drains.
    await settled(
      tester,
      find.byWidgetPredicate(
        (w) =>
            w is Text &&
            w.data == 'write the intro' &&
            w.style?.decoration == TextDecoration.lineThrough,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  group('amplified text', () {
    // One step does not certify a seat: a row can be exactly one line at 1.8x
    // and cut the next line up at 2.2x, so every panel here is measured twice.
    for (final (label, step) in const [
      ('1.8x', amplifiedTextStep),
      ('2.2x', nextTextStep),
    ]) {
      Future<void> pumpWide(WidgetTester tester, PlanExtensionView view) async {
        // NOT awaited. A `testWidgets` body runs under FakeAsync, where a real
        // file write never completes - awaiting the store's save here hangs the
        // whole run with no failure and no stack. The list mutation happens
        // before the await inside `add`, and the panels read `store.tasks` at
        // build time, so the task is on screen regardless.
        unawaited(
          store.add(
            'review the quarterly report draft and hand the summary to the owner',
            dueDate: DateTime(2026, 10, 5),
          ),
        );
        tester.view.physicalSize = const Size(1400, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pump(tester, view, scale: step);
      }

      testWidgets('the add row and the table keep their labels ($label)', (
        tester,
      ) async {
        await pumpWide(tester, PlanExtensionView.table);
        expect(textDefects(tester), isEmpty, reason: 'the table');
      });

      testWidgets('the board keeps its columns and cards ($label)', (
        tester,
      ) async {
        await pumpWide(tester, PlanExtensionView.board);
        expect(textDefects(tester), isEmpty, reason: 'the board');
      });

      // The month grid is guarded too, since its cells are drawn here now: the
      // package's own `FilledCell` seated every day number in a 22.0 circle,
      // which at 1.8x wanted 36.0 ("31" 36.0 vs 22.0, one defect per visible
      // day). `MonthView.cellBuilder` is the package's extension point, so the
      // seat rides the step without touching the lint-excluded package.
      testWidgets('the calendar keeps its days and its task rows ($label)', (
        tester,
      ) async {
        await pumpWide(tester, PlanExtensionView.calendar);
        expect(textDefects(tester), isEmpty, reason: 'the month grid');
      });
    }
  });
}
