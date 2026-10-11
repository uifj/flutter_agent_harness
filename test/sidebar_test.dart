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
//
// The last seven tests are not about the collapse. One pins the line every
// control in the column shares and the product name the brand row wears; the next
// pins that the footer's controls are not nested inside each other; and the last
// three pin the session row itself - the active session marked by shape and by
// semantics rather than by a fill alone, a cut title still readable on hover, and
// the rows' one-line seats grown to meet the text at 1.8x and at the step above
// it (audit 2a/2b, ADR-0017 S3). The last two wire the column's data - mode
// switch, extension rows, profile foot - and measure what only appears when it is
// handed, then prove an amplified chrome can be scrolled past to reach sessions.

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/model/conversation.dart';
import 'package:planstar/model/user_profile.dart';
import 'package:planstar/state/session_index.dart';
import 'package:planstar/state/workspace_mode_controller.dart';
import 'package:planstar/theme/dsw_shape.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/layout/columns.dart';
import 'package:planstar/ui/primitives/tappable.dart';
import 'package:planstar/ui/plan/plan_vault_tree.dart';
import 'package:planstar/ui/sidebar/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planstar/state/hotkey_service.dart';
import 'dart:io';

import 'fake_turn_source.dart';
import 'amplified_text_probe.dart';

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
  Future<void> pump(
    WidgetTester tester, {
    required bool collapsed,
    VoidCallback? onToggle,
    double scale = 1.0,
    WorkspaceMode? mode,
    UserProfile? profile,
    String? workspaceRoot,
    ValueChanged<String>? onOpenNote,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),

      builder: (context, child) => amplifiedAppBuilder(scale, child),
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
                  mode: mode,
                  onSelectMode: mode == null ? null : (_) {},
                  collections: const [
                    (id: 'set-tasks', name: 'Delivery board'),
                    (id: 'col-inbox', name: 'Reading inbox'),
                  ],
                  openCollectionId: 'col-inbox',
                  onOpenCollection: (_) {},
                  onOpenLibrary: (_) {},
                  onAddCollection: () {},
                  profile: profile,
                  onNewSession: () {},
                  onToggle: onToggle ?? () {},
                  onOpenSession: (_) {},
                  onOpenSettings: () {},
                  onToggleDetails: () {},
                  detailsOpen: false,
                  workspaceRoot: workspaceRoot,
                  onOpenNote: onOpenNote,
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

  /// The brand row starts on the same line as the controls under it, and it
  /// wears this product's name.
  ///
  /// Both were wrong at once. The row added its own `left: 4` on top of the
  /// column's inset, which made the logo the one thing in the sidebar not
  /// lining up with the list below it; and it spelled the initials of the
  /// project this one was written after, which is not a thing to ship.
  testWidgets('the brand row lines up and wears our name', (tester) async {
    source.sessions = [
      SessionSummary(
        id: 's1',
        updatedAt: DateTime(2026, 8, 25),
        title: 'Session 1',
      ),
    ];
    await index.refresh();
    await pump(tester, collapsed: false);

    expect(find.text('PlanStar'), findsOneWidget);
    expect(find.text('DSH'), findsNothing);

    // Everything the column stretches has to begin on its inset, so a second
    // offset anywhere in a row is now a failing test rather than a sighted
    // reviewer's job.
    final left = DswShape.sidebarInset;
    expect(tester.getTopLeft(find.byIcon(LucideIcons.sparkle)).dx, left);
    for (final label in ['New Session', 'Session 1']) {
      expect(
        tester
            .getTopLeft(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(AnimatedContainer),
              ),
            )
            .dx,
        left,
        reason: '$label is off the column inset',
      );
    }
  });

  // Audit 2c ③. The gear and the panel toggle used to live *inside* the profile
  // row's own hit target, so the "orphaned settings button" was literally a
  // button nested in a bigger one: hovering the gear lit the whole row, and a
  // tap in the empty middle opened the quick menu. Being neighbours at one gap
  // is the only way two controls can read as a group; sharing a hit area is not
  // grouping, it is nesting.
  testWidgets('the footer controls are neighbours, not nested targets', (
    tester,
  ) async {
    await pump(tester, collapsed: false);

    final trigger = find.byWidgetPredicate(
      (widget) =>
          widget is DswHoverTap && widget.semanticLabel == 'Quick preferences',
    );
    final gear = find.byIcon(LucideIcons.settings);
    expect(trigger, findsOneWidget);
    expect(gear, findsOneWidget);
    // The column carries `panel_right` twice (the header's own control and this
    // one), so scope the search to the footer row — the innermost Row that
    // contains the gear.
    final footer = find.ancestor(of: gear, matching: find.byType(Row)).first;
    final toggle = find.descendant(
      of: footer,
      matching: find.byIcon(LucideIcons.panel_right),
    );
    expect(toggle, findsOneWidget);

    final row = tester.getRect(trigger);
    final gearBox = tester.getRect(gear);
    final toggleBox = tester.getRect(toggle);

    expect(
      row.right,
      lessThanOrEqualTo(gearBox.left),
      reason: 'the gear is not part of the quick-menu trigger',
    );
    expect(
      row.right,
      lessThanOrEqualTo(toggleBox.left),
      reason: 'nor is the panel toggle',
    );
    expect(
      gearBox.center.dy,
      moreOrLessEquals(toggleBox.center.dy, epsilon: 0.5),
      reason: 'the two controls share one centre line — that is the grouping',
    );
  });

  /// Audit 2b's second half: the active session has to be readable as active
  /// without relying on a colour difference alone.
  testWidgets('the active row is marked by shape and semantics, not only wash', (
    tester,
  ) async {
    source.sessions = [
      SessionSummary(
        id: 's1',
        updatedAt: DateTime(2026, 8, 25),
        title: 'Alpha',
      ),
      SessionSummary(id: 's2', updatedAt: DateTime(2026, 8, 24), title: 'Beta'),
    ];
    await index.refresh();
    index.setActive('s2');
    await pump(tester, collapsed: false);

    // One scroll view carries the chrome and the rows, so the scope that used to
    // be the list is the rows' own sliver.
    final list = find.byType(SliverList);
    expect(
      find.descendant(
        of: list,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
      findsOneWidget,
      reason: 'exactly one row is the active session',
    );

    // The slot is reserved on every row: an indicator that only the active row
    // has would shove that row's title sideways, which is a jump, not a mark.
    expect(
      tester.getTopLeft(find.text('Alpha')).dx,
      tester.getTopLeft(find.text('Beta')).dx,
    );

    // The same row has to announce it to a screen reader. Queried on the row's
    // own `Semantics` node, not on the node `find.text` lands on: with the merge
    // boundary in place, walking up from the label reaches the focus detector
    // under the row, which says nothing about selection. Measured, not assumed -
    // the first version of this assertion read `isSelected` false there.
    final announced = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.selected == true,
    );
    expect(announced, findsOneWidget);
    expect(
      find.descendant(of: announced, matching: find.text('Beta')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: announced, matching: find.text('Alpha')),
      findsNothing,
    );
  });

  /// Audit 2a's other half: the ellipsis is the right strategy only if the cut
  /// part can still be read.
  testWidgets('a cut title can still be read', (tester) async {
    const long = 'A session with a title far too long for the column to show';
    source.sessions = [
      SessionSummary(id: 's1', updatedAt: DateTime(2026, 8, 25), title: long),
    ];
    await index.refresh();
    await pump(tester, collapsed: false);

    final tip = tester.widget<Tooltip>(
      find.descendant(
        of: find.byType(SliverList),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tip.message, long);

    // And the row really is narrower than its own title, so the tooltip is doing
    // work rather than decorating a case that never happens.
    final paragraph = tester.renderObject<RenderParagraph>(find.text(long));
    expect(
      paragraph.getMaxIntrinsicWidth(double.infinity),
      greaterThan(paragraph.size.width),
      reason: 'the title is genuinely cut in this column',
    );
  });

  testWidgets('the session list keeps its rows at the amplified step', (
    tester,
  ) async {
    source.sessions = [
      for (var i = 0; i < 4; i++)
        SessionSummary(
          id: 's$i',
          updatedAt: DateTime(2026, 8, 25),
          title: 'Session $i with a title long enough to be cut',
        ),
    ];
    await index.refresh();
    index.setActive('s1');

    for (final step in const [amplifiedTextStep, nextTextStep]) {
      await pump(tester, collapsed: false, scale: step);
      expect(
        textDefects(tester),
        isEmpty,
        reason: 'the session list at ${step}x',
      );
      expect(tester.takeException(), isNull);
    }
  });

  // The column's other two groups are invisible unless they are wired: the mode
  // switch needs `onSelectMode`, the extension rows need 企划 mode, and the
  // footer's name and email only render with a fetched profile. A walk that
  // visited the rail without them measured a sidebar nobody launches, so this
  // face hands the column its data and reads the ruler over what appears (the
  // coverage lesson from ADR-0017 S3: a visited tree is not a covered one).
  //
  // It walks the designed step too, because the switch's answer to running out of
  // width is the other half of the contract: at 1.0 both cells spell themselves
  // out, above that a cell sheds its label and keeps its name, and either way
  // nothing is cut.
  testWidgets('the wired column keeps its labels at the amplified step', (
    tester,
  ) async {
    final profile = UserProfile(
      displayName: 'InSail',
      email: 'uifj@example.com',
      subscription: 'Pro',
    );
    // The cell that shed its word has to keep naming itself. Recognised by the
    // semantics node rather than a primitive's parameter: since ADR-0036 the
    // switch's body is shad's button, which has no `semanticLabel` of its own, so
    // the name rides on the `Semantics` wrapper the primitive adds for exactly
    // this case. The assertion - a labelled cell exists only once the label is
    // gone - is unchanged.
    final namedCell = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Plan',
    );

    for (final collapsed in const [false, true]) {
      for (final step in const [1.0, amplifiedTextStep, nextTextStep]) {
        await pump(
          tester,
          collapsed: collapsed,
          scale: step,
          mode: WorkspaceMode.plan,
          profile: profile,
        );
        final designed = step == 1.0;
        // The rail draws glyphs only, so there the walk just measures.
        if (!collapsed) {
          // The extension area now lists the plan collections (2026-10-01).
          expect(find.text('Reading inbox'), findsOneWidget);
          expect(find.text(profile.email), findsOneWidget);
          expect(
            find.text('Plan'),
            designed ? findsOneWidget : findsNothing,
            reason: designed
                ? 'at the designed step the cell writes its own name'
                : 'a two-cell switch cannot fit an amplified label',
          );
          expect(namedCell, designed ? findsNothing : findsOneWidget);
        } else {
          // The rail draws one glyph per collection (kanban/inbox alternating).
          expect(find.byIcon(LucideIcons.kanban), findsOneWidget);
        }
        expect(
          textDefects(tester),
          isEmpty,
          reason:
              'the mode switch, extension rows and profile foot at '
              '${step}x (${collapsed ? 'rail' : 'wide'})',
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  // The wide column's chrome grows with the text step, and in 企划 mode it is the
  // taller of the two: measured at 2.2x in a 600px window the brand row, the mode
  // switch, three extension rows and New Session together left the session list
  // 0.0px - the user's own sessions were unreachable while the toggles above them
  // stayed on screen. The column scrolls as one now, so the guarantee is no longer
  // "the list is always visible" but "the list is always reachable", and that is
  // what this pins.
  testWidgets(
    'an amplified chrome can be scrolled past to reach the library in plan, '
    'the sessions in agent',
    (tester) async {
      source.sessions = [
        for (var i = 0; i < 4; i++)
          SessionSummary(
            id: 's$i',
            updatedAt: DateTime(2026, 8, 25),
            title: 'Session $i',
          ),
      ];
      await index.refresh();

      // 企划: the extension area (collections + library) replaced the session
      // list, so the scroll contract carries over to the library group's last
      // row — chrome may scroll away, content may not vanish.
      await pump(
        tester,
        collapsed: false,
        scale: nextTextStep,
        mode: WorkspaceMode.plan,
        profile: UserProfile(displayName: 'In', email: 'a@b.c'),
      );
      expect(find.text('Session 3'), findsNothing);
      // The library group is short enough to render whole even at 2.2x —
      // the contract is "reachable", and here that means visible outright
      // and still intact after the scroll attempt.
      final galleryRow = find.text('Gallery');
      expect(galleryRow, findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(galleryRow, findsOneWidget);
      expect(tester.takeException(), isNull);

      // 代理 keeps the conversation module: same chrome contract, sessions.
      await pump(
        tester,
        collapsed: false,
        scale: nextTextStep,
        mode: WorkspaceMode.agent,
        profile: UserProfile(displayName: 'In', email: 'a@b.c'),
      );
      final lastSession = find.text('Session 3');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(lastSession, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('plan mode hides the conversation module entirely', (
    tester,
  ) async {
    source.sessions = [
      SessionSummary(
        id: 's0',
        updatedAt: DateTime(2026, 8, 25),
        title: 'Session 0',
      ),
    ];
    await index.refresh();
    await pump(
      tester,
      collapsed: false,
      mode: WorkspaceMode.plan,
      profile: UserProfile(displayName: 'In', email: 'a@b.c'),
    );
    await tester.pumpAndSettle();
    // The conversation affordances are agent-only (user decision 2026-10-01).
    expect(find.text('Session 0'), findsNothing);
    expect(find.byTooltip('New Session'), findsNothing);
    // …and the extension area is there instead, with the library group.
    expect(find.text('Delivery board'), findsOneWidget);
    expect(find.text('Reading inbox'), findsOneWidget);
    expect(find.text('All content'), findsOneWidget);
  });
  // The rail has no hamburger: its brand mark *is* the way back out, swapping to
  // a panel glyph when hovered or focused. A reading of the code is not evidence
  // that it works, so both forms are pressed here — and each has to say which
  // way it goes, because the same control means "collapse" in one form and
  // "open" in the other. The reveal-on-focus itself is the primitive's own
  // contract, already pinned in dsw_hover_tap_test.dart.
  testWidgets('both forms carry a working collapse control', (tester) async {
    for (final collapsed in const [false, true]) {
      var toggles = 0;
      await pump(tester, collapsed: collapsed, onToggle: () => toggles++);
      // The two-phase collapse fades the wide content in behind an
      // IgnorePointer, so a tap before the settle lands on nothing.
      await tester.pumpAndSettle();

      final tip = collapsed
          ? 'Open sidebar (${HotkeyService.sidebarAccelerator})'
          : 'Collapse sidebar (${HotkeyService.sidebarAccelerator})';
      expect(
        find.byTooltip(tip),
        findsOneWidget,
        reason: collapsed
            ? 'the rail says how to open'
            : 'the wide form says how to close',
      );

      await tester.tap(find.byTooltip(tip));
      await tester.pump();
      expect(toggles, 1, reason: tip);
    }
  });

  testWidgets('集合 header collapses the collection rows', (tester) async {
    // Mirrors the 笔记 fold: the "Collections" caption is a toggle that folds
    // the collection rows away and back. The "+" button shares the header row
    // but not the word, so the toggle is the tappable that OWNS the caption.
    await pump(
      tester,
      collapsed: false,
      mode: WorkspaceMode.plan,
      profile: UserProfile(displayName: 'In', email: 'a@b.c'),
    );
    await tester.pumpAndSettle();
    // Expanded by default: both collections show.
    expect(find.text('Delivery board'), findsOneWidget);
    expect(find.text('Reading inbox'), findsOneWidget);

    final toggle = find.descendant(
      of: find.byType(DswHoverTap),
      matching: find.text('Collections'),
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('Delivery board'), findsNothing);
    expect(find.text('Reading inbox'), findsNothing);
    // The header affordance survives the fold and stays clickable.
    expect(toggle, findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('Delivery board'), findsOneWidget);
    expect(find.text('Reading inbox'), findsOneWidget);
  });

  testWidgets('expanding 笔记 never hides the section header', (tester) async {
    // A short window: the chrome + collections above the notes section (plus
    // the 库 strip and footer now pinned below the scroll) outrun the viewport.
    // The expanded section used to be a SliverFillRemaining whose extent
    // clamps to 0 in that state — the whole section (collapse header included)
    // collapsed to zero height, so clicking 笔记 made it disappear with no way
    // back. Now the section falls back to a fixed-height box the outer scroll
    // can reach.
    tester.view.physicalSize = const Size(800, 340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final root = Directory.systemTemp.createTempSync('dsh_side_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/a.md').writeAsStringSync('# A\n');

    await pump(
      tester,
      collapsed: false,
      mode: WorkspaceMode.plan,
      workspaceRoot: root.path,
      onOpenNote: (_) {},
    );
    // The vault index runs in a compute isolate — hand it real time.
    for (var attempt = 0; attempt < 100; attempt++) {
      if (find.text('a.md').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    // The section starts expanded, but the content above it outruns the
    // viewport's build cache — drag until the section materializes. The
    // bug's shape was a SliverFillRemaining clamped to ZERO extent here:
    // its child still builds, so find.text sees it, and only geometry
    // tells the truth.
    for (var attempt = 0; attempt < 80; attempt++) {
      if (find.byType(PlanVaultTree).evaluate().isNotEmpty) break;
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -80),
      );
      await tester.pump();
    }
    expect(
      tester.getRect(find.byType(PlanVaultTree)).height,
      greaterThan(200),
      reason: 'the expanded tree must keep its floor height',
    );

    // The click round-trip on the collapse toggle. The tree's own header
    // repeats the word "Notes", so match the tappable that OWNS the label
    // (the collapse row) rather than a bare text — and pull it on-screen
    // first, since the pinned 库 strip shrinks the scroll viewport here.
    final notesToggle = find.descendant(
      of: find.byType(DswHoverTap),
      matching: find.text('Notes'),
    );
    await tester.ensureVisible(notesToggle);
    await tester.pump();
    // Collapse to the header-only row, expand again — the toggle survives both
    // states and stays clickable.
    await tester.tap(notesToggle);
    await tester.pump();
    expect(find.byType(PlanVaultTree), findsNothing);
    await tester.ensureVisible(notesToggle);
    await tester.pump();
    await tester.tap(notesToggle);
    await tester.pump();
    expect(tester.getRect(find.byType(PlanVaultTree)).height, greaterThan(200));
  });

  testWidgets('expanding 笔记 in a tall window keeps the tree (ADR-0073)', (
    WidgetTester tester,
  ) async {
    // The other half of the bug the test above does not reach: a TALL window
    // where the notes section has plenty of remaining height. There the
    // expanded form used a SliverFillRemaining returned from a
    // SliverLayoutBuilder, which leaves an onstage child element with a null
    // renderObject — `find` throws and, on device, the section disappears the
    // moment it expands. The floor branch (short window) was green while this
    // one was broken, so both halves need a guard.
    tester.view.physicalSize = const Size(1000, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final root = Directory.systemTemp.createTempSync('dsh_side_tall_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/a.md').writeAsStringSync('# A\n');

    await pump(
      tester,
      collapsed: false,
      mode: WorkspaceMode.plan,
      workspaceRoot: root.path,
      onOpenNote: (_) {},
    );
    for (var attempt = 0; attempt < 100; attempt++) {
      if (find.text('a.md').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    // Expanded by default and the tree fills real height (no crash, no zero).
    expect(find.byType(PlanVaultTree), findsOneWidget);
    expect(
      tester.getRect(find.byType(PlanVaultTree)).height,
      greaterThan(200),
      reason: 'the tall-window tree must fill, not vanish',
    );

    // Collapse, then expand again — the round-trip stays reachable. Match the
    // collapse toggle (the tappable owning the "Notes" label), not the bare
    // text, so the tree's own "Notes" header cannot be mistaken for it.
    final notesToggle = find.descendant(
      of: find.byType(DswHoverTap),
      matching: find.text('Notes'),
    );
    await tester.tap(notesToggle);
    await tester.pump();
    expect(find.byType(PlanVaultTree), findsNothing);
    expect(find.text('Notes'), findsWidgets, reason: 'header after collapse');
    await tester.tap(notesToggle);
    await tester.pump();
    expect(
      tester.getRect(find.byType(PlanVaultTree)).height,
      greaterThan(200),
      reason: 'the tree survives re-expansion',
    );
  });
}
