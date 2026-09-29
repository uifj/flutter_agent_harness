// The whole shell, rendered at both sides of the breakpoint.
//
// `columns_test.dart` already proves the concession solve arithmetically. This
// pumps the frame the solve feeds: the sidebar auto-collapsing at 1024px, the
// details column opening over a squeezed centre, and the animated tracks in
// between. The 800px pass is the one that used to be a manual acceptance step.

import 'dart:async';

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/layout_controller.dart';
import 'package:agent_harness/state/session_index.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/app_frame.dart';
import 'package:agent_harness/ui/conversation/conversation_root.dart';
import 'package:agent_harness/ui/layout/columns.dart';
import 'package:agent_harness/ui/sidebar/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_turn_source.dart';

void main() {
  late FakeTurnSource source;
  late SessionIndex index;
  late StreamingTail tail;
  late ConversationController controller;
  late LayoutController layout;

  setUp(() {
    source = FakeTurnSource();
    index = SessionIndex(source);
    tail = StreamingTail();
    controller = ConversationController(runtime: source, tail: tail);
    layout = LayoutController();
  });

  tearDown(() {
    controller.dispose();
    tail.dispose();
    index.dispose();
    layout.dispose();
  });

  Future<void> resize(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pump();
  }

  Future<void> pump(
    WidgetTester tester, {
    double width = 1400,
    double? scale,
    Widget details = const SizedBox(),
    Widget workbench = const SizedBox(),
    Widget bottom = const SizedBox(),
    Widget? center,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scaffold = Scaffold(
      body: AppFrame(
        layout: layout,
        sidebarBuilder: (context, collapsed, width) => Sidebar(
          collapsed: collapsed,
          width: width,
          sessions: index,
          onNewSession: () {},
          onToggle: layout.toggleSidebar,
          onOpenSession: (_) {},
          onOpenSettings: () {},
          onToggleDetails: layout.toggleDetails,
          detailsOpen: layout.details != 0,
        ),
        center:
            center ?? ConversationRoot(conversation: controller, tail: tail),
        details: details,
        workbench: workbench,
        bottom: bottom,
      ),
    );
    // A `Builder` because the scaler has to read the MediaQuery MaterialApp just
    // installed — and its child is a separate value, not the variable holding the
    // builder: a closure that captures the variable it assigns to builds itself
    // forever, and the frame dies with a StackOverflowError.
    final root = scale == null
        ? scaffold
        : Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: scaffold,
            ),
          );
    await tester.pumpWidget(
      MaterialApp(theme: dswThemeData(Brightness.light), home: root),
    );
  }

  /// Walks the animated tracks rather than jumping to their ends: a column that
  /// only ever gets asserted at rest is a column whose transition is untested.
  Future<void> cross(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('crossing the auto-collapse breakpoint and coming back', (
    tester,
  ) async {
    source.sessions = [
      SessionSummary(
        id: 's1',
        updatedAt: DateTime(2026, 8, 25),
        title: 'A session with a title far too long for the rail',
      ),
    ];
    await index.refresh();

    await pump(tester);
    await cross(tester);
    expect(find.text('New Session'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Below 1024 the sidebar concedes to the rail without touching the stored
    // preference.
    await resize(tester, 800);
    await cross(tester);
    expect(find.text('New Session'), findsNothing);
    expect(layout.sidebar, sidebarDefault);
    expect(tester.takeException(), isNull);

    // The manual override re-expands it over the squeezed centre.
    layout.toggleSidebar();
    await cross(tester);
    expect(find.text('New Session'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await resize(tester, 1400);
    await cross(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a column hands its child the target width, never a frame of it', (
    tester,
  ) async {
    // The contract, asserted directly rather than through whatever happens to
    // overflow when it is broken: a column animates its own width, and the child
    // inside it is laid out at the target for the whole slide. Wide enough that
    // details can open beside the workbench, or the closing slide never happens
    // and there is nothing to observe.
    final seen = <double>[];
    await pump(
      tester,
      width: 1800,
      details: LayoutBuilder(
        builder: (context, constraints) {
          seen.add(constraints.maxWidth);
          return const SizedBox();
        },
      ),
    );
    await cross(tester);

    layout.openDetails();
    await cross(tester);
    seen.clear();

    // Closing is the direction that used to leak: the shrinking width arrived as a
    // tight minimum and overrode the target.
    layout.closeDetails();
    await cross(tester);
    expect(seen, isNotEmpty);
    expect(seen, everyElement(0.0));
  });

  testWidgets('the details column opens against a squeezed centre', (
    tester,
  ) async {
    await pump(tester, width: 800);
    await cross(tester);

    layout.setDetails(detailsDefault);
    await cross(tester);
    expect(tester.takeException(), isNull);

    layout.closeDetails();
    await cross(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bottom row opens and closes without unmounting its child', (
    tester,
  ) async {
    await pump(tester, bottom: const Text('the bottom panel'));
    await cross(tester);
    final text = find.text('the bottom panel');
    // The row starts closed at zero height — better-sidebar's
    // `makeDefaultState` ships `bottomOpen: false` — but its child is mounted
    // from the first frame: the shells a bottom panel hosts must survive being
    // hidden.
    expect(text, findsOneWidget);
    expect(tester.renderObject<RenderBox>(text).size.height, 0);

    layout.openBottom();
    await cross(tester);
    expect(tester.renderObject<RenderBox>(text).size.height, bottomDefault);
    expect(tester.takeException(), isNull);

    layout.closeBottom();
    await cross(tester);
    expect(text, findsOneWidget);
    expect(tester.renderObject<RenderBox>(text).size.height, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bottom panel squeezes only the center column', (
    tester,
  ) async {
    // The side column's own height, captured from inside it — a Text would
    // only ever report its own line box.
    final sideHeights = <double>[];
    await pump(
      tester,
      workbench: LayoutBuilder(
        builder: (context, constraints) {
          sideHeights.add(constraints.maxHeight);
          return const Text('the workbench column');
        },
      ),
      bottom: const Text('the bottom panel'),
    );
    layout.openBottom();
    await cross(tester);

    // The workbench column keeps its full height (the bottom panel never takes
    // vertical position from the side columns — `sidebar.module.css:124-126`).
    expect(sideHeights, everyElement(900.0));
    // And the bottom panel spans from the sidebar's right edge to the
    // workbench's left — not the whole viewport.
    final bottom = tester.renderObject<RenderBox>(
      find.text('the bottom panel'),
    );
    expect(bottom.size.height, bottomDefault);
    expect(bottom.size.width, 1400 - sidebarDefault - workbenchDefault);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the corner toggle cluster switches both panels', (tester) async {
    await pump(tester);
    await cross(tester);
    // Both toggles are pinned at the viewport corner from the first frame,
    // whatever the panels' state.
    expect(find.byTooltip('Collapse workbench panel'), findsOneWidget);
    expect(find.byTooltip('Open bottom panel'), findsOneWidget);

    await tester.tap(find.byTooltip('Collapse workbench panel'));
    await cross(tester);
    expect(layout.workbench, 0);

    await tester.tap(find.byTooltip('Open workbench panel'));
    await cross(tester);
    expect(layout.workbench, workbenchDefault);

    await tester.tap(find.byTooltip('Open bottom panel'));
    await cross(tester);
    expect(layout.bottom, bottomDefault);

    await tester.tap(find.byTooltip('Collapse bottom panel'));
    await cross(tester);
    expect(layout.bottom, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('between the breakpoints the desktop pair of toggles stays', (
    tester,
  ) async {
    await pump(tester, width: 800);
    await cross(tester);
    // 800 sits between the merge (768) and the sidebar's auto-collapse (1024):
    // a split-screen laptop keeps the two-panel desktop, toggles and all.
    expect(find.byTooltip('Collapse workbench panel'), findsOneWidget);
    expect(find.byTooltip('Open bottom panel'), findsOneWidget);
  });

  testWidgets('below the merge breakpoint the bottom toggle goes away', (
    tester,
  ) async {
    await pump(tester, width: 700);
    await cross(tester);
    // One drawer, one toggle (`Sidebar.tsx:1350-1355`).
    expect(find.byTooltip('Collapse workbench panel'), findsOneWidget);
    expect(find.byTooltip('Open bottom panel'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the merged workbench is a full-width drawer over the centre', (
    tester,
  ) async {
    // The centre's own width, captured from inside it: the merge's whole
    // promise is that the floating drawer takes nothing from it.
    final centerWidths = <double>[];
    await pump(
      tester,
      width: 700,
      workbench: const Text('the workbench column'),
      bottom: const Text('the bottom panel'),
      center: LayoutBuilder(
        builder: (context, constraints) {
          centerWidths.add(constraints.maxWidth);
          return const SizedBox();
        },
      ),
    );
    await cross(tester);

    // The drawer starts open and spans the whole viewport — the sidebar's rail
    // and the centre sit underneath it, not beside it.
    final drawer = tester.renderObject<RenderBox>(
      find.text('the workbench column'),
    );
    expect(drawer.size.width, 700);
    // Rail (56) + centre = the viewport; the centre paid for none of the
    // drawer, whatever the workbench preference held.
    expect(centerWidths, everyElement(700 - sidebarCollapsed));

    // The bottom panel stays mounted (shells survive hiding) but never opens
    // below the breakpoint, whatever the preference says.
    layout.openBottom();
    await cross(tester);
    expect(
      tester.renderObject<RenderBox>(find.text('the bottom panel')).size.height,
      0,
    );

    // The drawer closes to zero width and back, without unmounting.
    layout.closeWorkbench();
    await cross(tester);
    expect(
      tester
          .renderObject<RenderBox>(find.text('the workbench column'))
          .size
          .width,
      0,
    );
    layout.openWorkbench();
    await cross(tester);
    expect(
      tester
          .renderObject<RenderBox>(find.text('the workbench column'))
          .size
          .width,
      700,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a turn runs through the squeezed frame', (tester) async {
    await pump(tester, width: 800);
    await cross(tester);

    unawaited(controller.send('hi'));
    await tester.pump();
    expect(find.text('Deep diving...'), findsOneWidget);

    source.emit(const TextDelta(text: 'Hello there', messageIndex: 0));
    await tester.idle();
    await tester.pump();
    // Long enough for the reveal to uncover the whole string.
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('Hello there', findRichText: true),
      findsOneWidget,
    );

    source.emit(const TurnFinished(outcome: TurnOutcome.completed));
    await source.close();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // ADR-0017 S3. Every other widget test in this repo runs under
  // `TextScaler.noScaling`, so none of them proves the shell survives the
  // system's "放大文本"; 1.8 is macOS's largest step short of XXL.
  //
  // An overflowing `RenderFlex` is itself sized to its constraint — the
  // *children* are what spill — so this walks the render tree and adds the
  // children up, then names the owner by its creator chain. Two rows did spill
  // when this was first run: the sidebar's "New session" label (a non-flex
  // `Text`, so its ellipsis never got to trigger) wanted 299.9px in a 222px
  // bar, and the approval panel's three buttons wanted 809.6px in a 622px
  // seat. Both now flex or wrap.
  //
  // The other axis fails quietly, so it is measured too: a seat nailed to a
  // pixel height clips the label the text step just grew, and the framework
  // says nothing when it does. One-line chrome now sizes itself from that step.
  testWidgets('nothing spills when the system amplifies text', (tester) async {
    List<String> spills() {
      final found = <String>[];
      for (final ro in tester.allRenderObjects.whereType<RenderFlex>()) {
        if (ro.direction != Axis.horizontal) continue;
        final max = ro.constraints.maxWidth;
        if (max >= double.infinity) continue;
        final sum = ro.getChildrenAsList().whereType<RenderBox>().fold<double>(
          0,
          (a, b) => a + b.size.width,
        );
        if (sum <= max + 0.5) continue;
        var chain = ro.toStringShort();
        for (final el in tester.allElements) {
          if (el.renderObject != ro) continue;
          chain = el.debugGetCreatorChain(8);
          break;
        }
        found.add(
          '${sum.toStringAsFixed(1)} vs ${max.toStringAsFixed(1)} :: $chain',
        );
      }
      return found;
    }

    // A paragraph tells no lies about its own box: `getMaxIntrinsicHeight`
    // ignores the constraint that clipped it, so a need taller than the box it
    // was handed is a silent clip - no framework error, just a cut-off label.
    // Seven labels were measured this way at 1.8x: the tool card's "Read" header
    // wanted 43.0 in a 24.0 seat (behind that header's own `ClipRect`), as did
    // its path summary, the sidebar's "New Session" wanted 40.0 in 34.0, the
    // running row 40.0 in 26.0, the composer's mode chip 25.0 in 22.0, and the
    // three approval answers 40.0 in 36.0. Every one of those seats is chrome
    // that is exactly one line tall, so each now takes its height from the same
    // text step the label does - the same pixels at rest, and no cut glyphs at
    // the larger steps. (A `minHeight` floor was tried first and is wrong here:
    // the header's collapsed preview is a free widget, and given an unbounded
    // line it wrapped to 88px and grew the whole row - `disclosure_row_test`
    // caught it.)
    List<String> clips() {
      final found = <String>[];
      for (final el in tester.allElements) {
        final ro = el.renderObject;
        if (ro is! RenderParagraph || !ro.hasSize) continue;
        final needed = ro.getMaxIntrinsicHeight(ro.size.width);
        if (needed <= ro.size.height + 0.5) continue;
        found.add(
          '${needed.toStringAsFixed(1)} vs ${ro.size.height.toStringAsFixed(1)} '
          ':: "${ro.text.toPlainText()}" <- ${el.debugGetCreatorChain(6)}',
        );
      }
      return found;
    }

    List<String> defects() => [...spills(), ...clips()];

    await pump(tester, scale: 1.8);
    expect(defects(), isEmpty, reason: 'hero');

    source.sessions = [
      SessionSummary(
        id: 'a-very-long-session-identifier',
        updatedAt: DateTime(2026, 9, 30),
        title: 'Refactor the workspace picker so recents open on one tap',
      ),
    ];
    await index.refresh();
    await tester.pump(const Duration(milliseconds: 400));
    expect(defects(), isEmpty, reason: 'a session titled in two sentences');

    unawaited(controller.send('hi'));
    await tester.pump();
    source.emit(
      const ToolCallRequested(
        ref: 'r1',
        name: 'read',
        arguments: {'file_path': 'lib/ui/conversation/composer.dart'},
      ),
    );
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(defects(), isEmpty, reason: 'a tool card mid-turn');

    source.emit(
      const ApprovalRequired(
        ApprovalRequest(
          ref: 'r1',
          toolName: 'write',
          arguments: {
            'file_path': '/tmp/deeply/nested/path/notes.md',
            'content': 'hi',
          },
          details: {
            'kind': 'write',
            'path': '/tmp/deeply/nested/path/notes.md',
            'bytes': 2,
            'exists': false,
          },
        ),
      ),
    );
    await tester.idle();
    await tester.pump(const Duration(milliseconds: 400));
    expect(defects(), isEmpty, reason: 'the approval panel with three answers');

    await controller.send('a queued follow-up draft for the line');
    await tester.pump(const Duration(milliseconds: 400));
    expect(defects(), isEmpty, reason: 'a draft waiting in the queue');
    expect(tester.takeException(), isNull);
  });
}
