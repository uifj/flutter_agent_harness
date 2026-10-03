// The whole shell, rendered at both sides of the breakpoint.
//
// `columns_test.dart` already proves the concession solve arithmetically. This
// pumps the frame the solve feeds: the sidebar auto-collapsing at 1024px, the
// details column opening over a squeezed centre, and the animated tracks in
// between. The 800px pass is the one that used to be a manual acceptance step.

import 'dart:async';
import 'dart:io';

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/layout_controller.dart';
import 'package:agent_harness/state/session_index.dart';
import 'package:agent_harness/state/session_registry.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/app_frame.dart';
import 'package:agent_harness/ui/conversation/conversation_root.dart';
import 'package:agent_harness/ui/layout/columns.dart';
import 'package:agent_harness/ui/sidebar/sidebar.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'amplified_text_probe.dart';
import 'fake_turn_source.dart';

void main() {
  late FakeTurnSource source;
  late Directory support;
  late SessionRegistry registry;
  late SessionIndex index;
  late StreamingTail tail;
  late ConversationController controller;
  late LayoutController layout;

  setUp(() {
    source = FakeTurnSource();
    // Registry-backed: pinning and renaming are sidecar writes, and a header
    // menu whose pin does nothing but reorder the list in memory would be
    // asserting a lie about the door it presses (ADR-0039).
    support = Directory.systemTemp.createTempSync('app_frame');
    registry = SessionRegistry.open(support);
    index = SessionIndex(source, registry: registry);
    tail = StreamingTail();
    controller = ConversationController(runtime: source, tail: tail);
    layout = LayoutController();
  });

  tearDown(() {
    controller.dispose();
    tail.dispose();
    index.dispose();
    registry.dispose();
    if (support.existsSync()) support.deleteSync(recursive: true);
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
    String? workspaceRoot,
    SessionSummary? session,
    VoidCallback? onPickWorkspace,
    VoidCallback? onOpenSettings,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => amplifiedAppBuilder(scale ?? 1.0, child),
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: AppFrame(
            layout: layout,
            workspaceRoot: workspaceRoot,
            session: session,
            sessions: session == null ? null : index,
            onPickWorkspace: onPickWorkspace,
            onOpenSettings: onOpenSettings,
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
                center ??
                ConversationRoot(conversation: controller, tail: tail),
            details: details,
            workbench: workbench,
            bottom: bottom,
          ),
        ),
      ),
    );
  }

  /// Walks the animated tracks rather than jumping to their ends: a column that
  /// only ever gets asserted at rest is a column whose transition is untested.
  Future<void> cross(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('the header names the workspace and the conversation', (
    tester,
  ) async {
    // The strip used to be empty on the left, so the screen never said which
    // folder was selected — only the system title bar did.
    var picked = 0;
    var settings = 0;
    source.sessions = [
      SessionSummary(
        id: 's1',
        updatedAt: DateTime(2026, 10, 3),
        title: 'Rebuild the composer',
        workspaceRoot: '/work/alpha',
      ),
    ];
    await index.refresh();
    index.setActive('s1');

    await pump(
      tester,
      workspaceRoot: '/work/alpha',
      session: index.active,
      onPickWorkspace: () => picked++,
      onOpenSettings: () => settings++,
    );

    // The strip, not the sidebar beside it: the group header shows the same
    // folder name and carries the same `⋯` glyph.
    final strip = find.byKey(const ValueKey('center-strip'));
    // The folder's own name, not the path, and the conversation beside it.
    expect(
      find.descendant(of: strip, matching: find.text('alpha')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strip, matching: find.text('Rebuild the composer')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: strip, matching: find.byIcon(LucideIcons.ellipsis)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pin to top'), findsOneWidget);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Copy session id'), findsOneWidget);
    expect(find.text('Copy workspace path'), findsOneWidget);
    expect(find.text('Reveal in file manager'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    // The list's door, not the header's: nothing here destroys the transcript
    // the reader is looking at.
    expect(find.text('Delete'), findsNothing);

    // Pressed, not collected: pinning has to reach the index.
    await tester.tap(find.text('Pin to top'));
    await tester.pumpAndSettle();
    expect(index.sessions.single.pinnedAt, isNotNull);

    await tester.tap(
      find.descendant(of: strip, matching: find.byIcon(LucideIcons.ellipsis)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(settings, 1);
    expect(tester.takeException(), isNull);

    // An unsaved conversation has no id to act on, so the menu is absent rather
    // than empty — a `⋯` that opens nothing is a dead control (ADR-0022).
    await pump(tester, workspaceRoot: '/work/alpha');
    final bare = find.byKey(const ValueKey('center-strip'));
    expect(
      find.descendant(of: bare, matching: find.text('alpha')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bare, matching: find.byIcon(LucideIcons.ellipsis)),
      findsNothing,
    );
  });

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

  testWidgets('the panel toggles switch both panels', (tester) async {
    await pump(tester);
    await cross(tester);
    // Both toggles are in the shell's top bar from the first frame, whatever
    // the panels' state (ADR-0048: one home, in flow).
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
  // *children* are what spill — and a paragraph clipped by a fixed-height seat
  // throws nothing at all, so both axes have to be measured rather than looked
  // at. The measuring lives in `amplified_text_probe.dart` now, because the
  // workbench, the settings page and the plan workspace need the same proof.
  //
  // What this shell showed the first time it ran at 1.8x. Two rows spilled: the
  // sidebar's "New session" label wanted 299.9px in a 222px bar (a non-flex
  // `Text` never gets its ellipsis to trigger), and the approval panel's three
  // buttons wanted 809.6px in a 622px seat. Seven labels were cut: the tool
  // card's "Read" header 43.0 in a 24.0 seat — behind that header's own
  // `ClipRect` — and its path summary likewise, the running row 40.0 in 26.0,
  // the sidebar's "New Session" 40.0 in 34.0, the composer's mode chip 25.0 in
  // 22.0, the three approval answers 40.0 in 36.0, the queued draft's chips
  // 32.0 in 28.0. The rows flex or wrap; every one-line seat now takes its
  // height from the same step the label does, which is the same pixel at rest.
  //
  // A `minHeight` floor was tried first and is wrong for the shared header: its
  // collapsed preview is a widget the caller hands over, and given an unbounded
  // line it wrapped to 88px and grew the whole row — `disclosure_row_test`
  // caught that.
  // Two steps, not one: a seat can be exactly one line at 1.8x and still be cut
  // at the next one (the session row's 36 passed 1.8 and clipped at 2.2), so a
  // single step certifies a single number.
  for (final (label, step) in const [
    ('1.8x', amplifiedTextStep),
    ('2.2x', nextTextStep),
  ]) {
    testWidgets('nothing spills when the system amplifies text ($label)', (
      tester,
    ) async {
      await pump(tester, scale: step);
      expect(textDefects(tester), isEmpty, reason: 'hero');

      source.sessions = [
        SessionSummary(
          id: 'a-very-long-session-identifier',
          updatedAt: DateTime(2026, 9, 30),
          title: 'Refactor the workspace picker so recents open on one tap',
        ),
      ];
      await index.refresh();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        textDefects(tester),
        isEmpty,
        reason: 'a session titled in two sentences',
      );

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
      expect(textDefects(tester), isEmpty, reason: 'a tool card mid-turn');

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
      expect(
        textDefects(tester),
        isEmpty,
        reason: 'the approval panel with three answers',
      );

      await controller.send('a queued follow-up draft for the line');
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        textDefects(tester),
        isEmpty,
        reason: 'a draft waiting in the queue',
      );
      expect(tester.takeException(), isNull);
    });
  }
  // An icon-only control is unreadable to a screen reader unless it names
  // itself, and the shapes differ by width: the wide footer's gear and the
  // rail's New Session bar are the icon-only halves of different forms. A
  // control that sheds its label for width has to keep the name — the mode
  // cells already did this, these two did not.
  testWidgets('every icon-only control in the shell names itself', (
    tester,
  ) async {
    for (final width in const [1400.0, 1100.0, 700.0]) {
      await pump(tester, width: width);
      await tester.pumpAndSettle();
      final offenders = unlabelledIconControls(tester);
      expect(offenders, isEmpty, reason: 'an icon-only control at $width');
    }
  });

  // ADR-0048: the cluster used to answer "where do I live" twice — in the
  // center column's strip while the panel was closed, floating at the viewport
  // corner while it was open. The floating half is what could cover content,
  // and the panels each carved a 72px hole to make room for it. One home now,
  // in flow, so the test is that the cluster sits inside the center column and
  // moves with it.
  testWidgets('the panel toggles have one home, and the centre pays for it', (
    tester,
  ) async {
    await pump(tester, width: 1400);
    await cross(tester);
    expect(find.byTooltip('Collapse workbench panel'), findsOneWidget);
    // Open: the cluster's right edge is the centre column's right edge, minus
    // the strip's own 10px gutter. It is the workbench's right border that
    // decides where the toggle sits — not the viewport.
    expect(
      tester.getRect(find.byTooltip('Collapse workbench panel')).right,
      closeTo(1400 - workbenchDefault - 10, 1),
    );

    layout.closeWorkbench();
    await cross(tester);
    expect(find.byTooltip('Open workbench panel'), findsOneWidget);
    // Closed: the same in-flow row, now reaching the viewport's edge because
    // the centre owns the whole width. Same widget, one placement rule.
    expect(
      tester.getRect(find.byTooltip('Open workbench panel')).right,
      closeTo(1400 - 10, 1),
    );

    // Merged: one drawer, so one toggle — and it is still the centre's row,
    // which the drawer overlays rather than squeezes.
    await resize(tester, 700);
    await cross(tester);
    expect(find.byTooltip('Open workbench panel'), findsOneWidget);
    expect(find.byTooltip('Open bottom panel'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shell top bar rides the text step', (tester) async {
    await pump(tester, width: 1400, scale: amplifiedTextStep);
    await cross(tester);
    // The row and its seats grow together, like every other one-line chrome:
    // a nailed 36 over nailed 32 was the strip that did not breathe.
    expect(
      tester.getSize(find.byTooltip('Collapse workbench panel')).width,
      closeTo(32 * amplifiedTextStep, 0.1),
    );
    expect(
      tester.getRect(find.byTooltip('Collapse workbench panel')).bottom,
      lessThan(36 * amplifiedTextStep + 1),
    );
    expect(textDefects(tester), isEmpty);
  });
}
