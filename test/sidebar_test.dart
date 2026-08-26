// The rail, driven through its own collapse.
//
// This file exists because of a bug that only showed up in frames nobody was
// pumping: the New Session control animated between a hugging width and a fixed
// 36px one, so every collapse asked `BoxConstraints.lerp` to interpolate a finite
// width against an unbounded one. That throws, and the half-way widths it handed
// the label's row on the way overflowed it. Both were invisible to a test that
// only ever pumped a settled sidebar.
//
// So the contract here is coarse: put the rail in each form, pump the frames
// between them, and assert nothing was thrown.

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/state/session_index.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/layout/columns.dart';
import 'package:agent_harness/ui/sidebar/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_turn_source.dart';

void main() {
  late FakeTurnSource source;
  late SessionIndex index;

  setUp(() {
    source = FakeTurnSource();
    index = SessionIndex(source);
  });

  tearDown(() => index.dispose());

  /// Mounts the rail at [collapsed], in the seat the frame gives it: a bounded,
  /// clipped column of full height.
  ///
  /// Bounded matters. The rail releases its own width constraint so the fading
  /// wide content can stay wider than the column, which means it sizes itself to
  /// whatever it is given — hand it an unbounded width and it takes all of it.
  /// `_column` in the frame always hands it a tight one.
  Future<void> pump(WidgetTester tester, {required bool collapsed}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: dswThemeData(Brightness.light),
          home: Scaffold(
            body: Row(
              children: [
                ClipRect(
                  child: SizedBox(
                    width: collapsed ? sidebarCollapsed : sidebarDefault,
                    child: Sidebar(
                      collapsed: collapsed,
                      width: collapsed ? sidebarCollapsed : sidebarDefault,
                      sessions: index,
                      onNewSession: () {},
                      onToggle: () {},
                      onOpenSession: (_) {},
                      onOpenSettings: () {},
                      onToggleDetails: () {},
                      detailsOpen: false,
                      onToggleWorkbench: () {},
                      workbenchOpen: false,
                      onToggleBottom: () {},
                      bottomOpen: false,
                    ),
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );

  /// Walks the whole transition a frame at a time.
  ///
  /// The collapse is two-phase — the wide content fades at its frozen width, then
  /// a timer lets the rail layout apply — so it is the frames in the middle that
  /// matter, not the ends. `pumpAndSettle` would step over exactly the ones that
  /// used to throw.
  Future<void> cross(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('collapsing and expanding throws nothing on the way', (
    tester,
  ) async {
    source.sessions = [
      SessionSummary(
        id: 's1',
        updatedAt: DateTime(2026, 8, 25),
        // Long enough that the wide row has to ellipsis it, which is what makes a
        // half-way width overflow rather than merely look wrong.
        title: 'A session with a title far too long for the rail',
      ),
    ];
    await index.refresh();

    await pump(tester, collapsed: false);
    expect(find.text('New Session'), findsOneWidget);

    await pump(tester, collapsed: true);
    await cross(tester);
    // Phase 2 has applied: the wide content is gone and the rail is what is left.
    expect(find.text('New Session'), findsNothing);
    expect(tester.takeException(), isNull);

    await pump(tester, collapsed: false);
    await cross(tester);
    expect(find.text('New Session'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stocked list survives both forms', (tester) async {
    source.sessions = [
      for (var i = 0; i < 12; i++)
        SessionSummary(
          id: 's$i',
          updatedAt: DateTime(2026, 8, 25 - (i % 20)),
          title: 'Session $i',
        ),
    ];
    await index.refresh();
    index.setActive('s3');

    await pump(tester, collapsed: false);
    expect(find.text('Session 3'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pump(tester, collapsed: true);
    await cross(tester);
    expect(tester.takeException(), isNull);
  });
}
