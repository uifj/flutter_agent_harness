// The workbench shell, pumped for real.
//
// What is worth a widget test here is the handful of behaviours that only exist
// once the controller and the widgets are wired together, and that a reducer test
// cannot see:
//
//   * the empty pane, which is the first thing a user meets and the only place
//     that explains what the column is for;
//   * middle-click close, which no reducer knows about because Flutter's tap
//     recognisers do not report the button;
//   * the keep-alive contract — switching tabs must not tear a body down, and a
//     restored tab that has never been looked at must not be built. Those two pull
//     in opposite directions, so both directions are pinned;
//   * the file tree against a real directory, since its whole job is to agree with
//     the disk through the same guard the tools use.

import 'dart:io';

import 'package:agent_harness/host/terminal_manager.dart';
import 'package:agent_harness/model/workbench_prefs.dart';
import 'package:agent_harness/model/fs_revision.dart';
import 'package:agent_harness/model/sidebar_tab.dart';
import 'package:agent_harness/state/workbench_controller.dart';
import 'package:agent_harness/state/workbench_store.dart';
import 'package:agent_harness/ui/workbench/workbench.dart';
import 'package:agent_harness/ui/workbench/workbench_prefs_scope.dart';
import 'package:agent_harness/ui/workbench/workbench_tab_bar.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'amplified_text_probe.dart';
import 'fake_terminal_process.dart';
import 'fake_turn_source.dart';

void main() {
  late Directory support;
  late WorkbenchStore store;
  late WorkbenchController workbench;
  late FakeTurnSource source;
  late StreamingTail tail;
  late ConversationController conversation;
  late FakeTerminalSpawner terminals;
  late TerminalManager pool;
  var closed = 0;

  setUp(() {
    support = Directory.systemTemp.createTempSync('dsh_workbench_ui_');
    store = WorkbenchStore.open(support);
    workbench = WorkbenchController(store: store);
    // The sub-agent tab reads the transcript, so the workbench needs the same
    // controller the app wires up — over a fake turn source, so no pump can
    // reach a real model.
    source = FakeTurnSource();
    tail = StreamingTail();
    conversation = ConversationController(runtime: source, tail: tail);
    // The workbench's terminal tabs draw from a fake pool: a test that opened
    // a real one would spawn a real shell per pump, on the developer's machine,
    // outside the test's control.
    terminals = FakeTerminalSpawner();
    pool = terminals.manager();
    closed = 0;
  });

  tearDown(() {
    workbench.dispose();
    conversation.dispose();
    tail.dispose();
    support.deleteSync(recursive: true);
  });

  /// The workbench at the width its strips were made for: the workbench
  /// column's default plus the toggle cluster's reserve, so the tab chips,
  /// split controls, `+` and reserve all fit together.
  Future<void> pump(
    WidgetTester tester, [
    WorkbenchController? controller,
    WorkbenchPrefs prefs = const WorkbenchPrefs(),
    double? scale,
  ]) => tester.pumpWidget(
    MaterialApp(
      theme: dswThemeData(Brightness.light),
      home: Scaffold(
        body: SizedBox(
          width: 460,
          height: 600,
          child: AmplifiedText(
            step: scale ?? 1.0,
            child: WorkbenchPrefsScope(
              prefs: prefs,
              child: Workbench(
                workbench: controller ?? workbench,
                conversation: conversation,
                terminals: pool,
                onClose: () => closed++,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// A canonical directory to use as a workspace. Resolved because the system
  /// temp directory is itself a symlink on macOS, and the guard canonicalises its
  /// root — an unresolved root would make every displayed path disagree with it.
  Directory workspace() {
    final root = Directory('${support.path}/work')..createSync();
    return Directory(root.resolveSymbolicLinksSync());
  }

  Finder tabStripCloseButton() => find.descendant(
    of: find.byType(WorkbenchTabBar),
    matching: find.byIcon(LucideIcons.x),
  );

  /// Pumps until [finder] matches, giving the real event loop a turn between
  /// frames.
  ///
  /// `testWidgets` runs in a fake-async zone, and a `dart:io` future never
  /// completes inside one on its own: the completion callback lands in the fake
  /// microtask queue, which only drains during a pump. Anything that reads the
  /// disk — the file tree, the editor — therefore needs [WidgetTester.runAsync]
  /// between pumps, and a condition rather than a fixed sleep, so a loaded
  /// machine makes this slower rather than red.
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    fail('$finder never appeared');
  }

  group('an empty pane', () {
    testWidgets('says what it is for and how to fill it', (tester) async {
      await pump(tester);
      expect(find.text('Files open here.'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('Terminal'), findsOneWidget);
      expect(find.text('Source control'), findsOneWidget);
    });

    // Disabled rather than hidden, and this is the assertion that keeps it from
    // being silently *enabled*: an explorer rooted at nothing would open a tab
    // whose only content is an error.
    testWidgets('the explorer action does nothing without a workspace', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Explorer'));
      await tester.pump();
      expect(workbench.state.tabs, isEmpty);
    });

    testWidgets('the explorer action opens the workspace once there is one', (
      tester,
    ) async {
      workbench.workspaceRoot = workspace().path;
      await pump(tester);
      await tester.tap(find.text('Explorer'));
      await tester.pumpAndSettle();
      expect(workbench.state.tabs.single.path, workbench.workspaceRoot);
    });
  });

  group('the panel chrome', () {
    // The source's `.panel` is a resize strip + panelBody(Workbench) — the tab
    // strip IS the top chrome, so there is no header row to name a folder or
    // carry openers: the `+` menu holds them.
    testWidgets('has no header row above the tab strip', (tester) async {
      await pump(tester);
      expect(find.text('No folder'), findsNothing);
    });

    testWidgets('the + menu opens the openable types', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('New tab'));
      await tester.pumpAndSettle();
      // Scoped to the menu rows: an empty pane's welcome cards carry the same
      // labels behind the popup. The predicate matcher is because find.byType
      // is generic-exact (PopupMenuItem<String> ≠ PopupMenuItem<dynamic>).
      Finder menuRow(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      );
      expect(menuRow('Explorer'), findsOneWidget);
      expect(menuRow('Terminal'), findsOneWidget);
      expect(menuRow('Source control'), findsOneWidget);
      expect(menuRow('Sub-agents'), findsOneWidget);

      await tester.tap(menuRow('Source control'));
      await tester.pumpAndSettle();
      expect(workbench.state.tabs.single.type, BuiltinTabType.git);
    });

    testWidgets('the + menu disables Explorer without a workspace', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byTooltip('New tab'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.ancestor(
          of: find.text('Explorer'),
          matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
        ),
      );
      await tester.pumpAndSettle();
      expect(workbench.state.tabs, isEmpty);
    });

    testWidgets('a switched-off type leaves the menu and the cards', (
      tester,
    ) async {
      await pump(
        tester,
        null,
        const WorkbenchPrefs(tabsEnabled: {'git': false, 'terminal': false}),
      );

      // The welcome cards dropped the disabled types; the enabled one stays.
      expect(find.text('Terminal'), findsNothing);
      expect(find.text('Source control'), findsNothing);
      expect(find.text('Explorer'), findsOneWidget);

      // And the + menu agrees — hidden, not greyed out.
      await tester.tap(find.byTooltip('New tab'));
      await tester.pumpAndSettle();
      Finder menuRow(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
      );
      expect(menuRow('Explorer'), findsOneWidget);
      expect(menuRow('Terminal'), findsNothing);
      expect(menuRow('Source control'), findsNothing);
    });
  });

  group('the tab strip', () {
    testWidgets('shows an opened tab, and its body', (tester) async {
      workbench.openGit();
      await pump(tester);
      expect(find.text('Source Control'), findsOneWidget);
      // No workspace is set in this shell, so the git body says so — the
      // placeholder it replaced never read anything.
      expect(
        find.text('No workspace folder is set, so there is nothing to list.'),
        findsOneWidget,
      );
    });

    testWidgets('middle-click closes a tab', (tester) async {
      workbench.openTerminal();
      await pump(tester);
      expect(find.text('Terminal 1'), findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Terminal 1')),
        kind: PointerDeviceKind.mouse,
        buttons: kMiddleMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();
      expect(workbench.state.tabs, isEmpty);
    });

    group('the right-click menu', () {
      Future<void> rightClick(WidgetTester tester, Finder chip) async {
        final gesture = await tester.startGesture(
          tester.getCenter(chip),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryButton,
        );
        await gesture.up();
        await tester.pumpAndSettle();
      }

      testWidgets('offers close, and closes', (tester) async {
        workbench.openGit();
        await pump(tester);
        expect(find.text('Source Control'), findsOneWidget);

        await rightClick(tester, find.text('Source Control'));
        expect(find.text('Close'), findsOneWidget);
        expect(find.text('Close all'), findsOneWidget);
        expect(find.text('Send to bottom panel'), findsOneWidget);
        // One tab only: "close others" would read as a no-op.
        expect(find.text('Close others'), findsNothing);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(workbench.state.tabs, isEmpty);
      });

      testWidgets('close all empties the strip', (tester) async {
        workbench.openGit();
        workbench.openTerminal();
        await pump(tester);
        expect(workbench.state.tabs, hasLength(2));

        await rightClick(tester, find.text('Source Control'));
        await tester.tap(find.text('Close all'));
        await tester.pumpAndSettle();
        expect(workbench.state.tabs, isEmpty);
        // A lone pane survives as the welcome pane.
        expect(workbench.state.panes, hasLength(1));
      });

      testWidgets('close others keeps only the clicked tab', (tester) async {
        workbench.openGit();
        workbench.openTerminal();
        await pump(tester);

        await rightClick(tester, find.text('Terminal 1'));
        await tester.tap(find.text('Close others'));
        await tester.pumpAndSettle();
        expect(workbench.state.tabs.single.type, BuiltinTabType.terminal);
      });

      testWidgets('send moves the tab to the bottom panel', (tester) async {
        workbench.openGit();
        await pump(tester);

        await rightClick(tester, find.text('Source Control'));
        await tester.tap(find.text('Send to bottom panel'));
        await tester.pumpAndSettle();
        expect(workbench.state.tabs, isEmpty);
        expect(workbench.state.bottomTabs.single.type, BuiltinTabType.git);
      });
    });

    testWidgets('the close affordance closes a tab', (tester) async {
      workbench.openGit();
      await pump(tester);
      await tester.tap(tabStripCloseButton());
      await tester.pumpAndSettle();
      expect(workbench.state.tabs, isEmpty);
    });

    // The split controls would otherwise offer to halve a pane with nothing in
    // it, which is two empty panes where there was one.
    testWidgets('offers no split controls for an empty pane', (tester) async {
      await pump(tester);
      expect(find.byTooltip('Split down'), findsNothing);

      workbench.openGit();
      await tester.pump();
      expect(find.byTooltip('Split down'), findsOneWidget);
    });

    testWidgets('splitting makes a second pane with its own strip', (
      tester,
    ) async {
      workbench.openGit();
      await pump(tester);
      await tester.tap(find.byTooltip('Split right'));
      await tester.pumpAndSettle();
      expect(workbench.state.panes, hasLength(2));
      expect(find.byType(WorkbenchTabBar), findsNWidgets(2));
    });
  });

  group('tab bodies', () {
    testWidgets('a body switched away from stays in the tree', (tester) async {
      const git = 'No workspace folder is set, so there is nothing to list.';
      // The terminal body is the one worth pinning here: it is the tab whose
      // content is a live process, so being torn down is not a lost scroll
      // position but a dead shell.
      final terminal = find.byType(TerminalView);

      // Opened with the workbench already up, because "has been active" is a
      // property of the mounted pane: a tab activated before the pane existed was
      // never looked at as far as the pane is concerned.
      workbench.openTerminal();
      await pump(tester);
      expect(terminal, findsOneWidget);

      workbench.openGit();
      await tester.pumpAndSettle();
      expect(find.text(git), findsOneWidget);
      expect(find.byType(TerminalView, skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('Terminal 1'));
      await tester.pumpAndSettle();
      expect(terminal, findsOneWidget);
      expect(find.text(git, skipOffstage: false), findsOneWidget);
    });

    // The other half of the same contract: [IndexedStack] builds every child, so
    // a restored layout with a dozen tabs would read a dozen files to show one.
    testWidgets('a restored tab that was never active is not built', (
      tester,
    ) async {
      late WorkbenchController reopened;
      // Outside the fake-async zone: this writes and reads the layout file.
      await tester.runAsync(() async {
        await workbench.bindSession('s1');
        workbench.openTerminal();
        workbench.openGit();
        await workbench.flush();

        reopened = WorkbenchController(store: WorkbenchStore.open(support));
        await reopened.bindSession('s1');
      });
      addTearDown(reopened.dispose);
      expect(reopened.state.tabs, hasLength(2));

      await pump(tester, reopened);
      expect(
        find.text('No workspace folder is set, so there is nothing to list.'),
        findsOneWidget,
      );
      // Never looked at, so never built — which for a terminal means never
      // spawned, not just never painted.
      expect(find.byType(TerminalView, skipOffstage: false), findsNothing);
      expect(terminals.spawned, isEmpty);
    });
  });

  group('the file tree', () {
    testWidgets('lists a folder, expands into it, and opens a file', (
      tester,
    ) async {
      final root = workspace();
      Directory('${root.path}/lib').createSync();
      File('${root.path}/lib/main.dart').writeAsStringSync('void main() {}\n');
      File('${root.path}/README.md').writeAsStringSync('# hi\n');

      workbench.workspaceRoot = root.path;
      workbench.openFolder(root.path);
      await pump(tester);
      await pumpUntil(tester, find.text('README.md'));

      // Folders first, then names — and the root is expanded by `openFolder`,
      // since a collapsed root is a tab showing one row.
      expect(find.text('lib'), findsOneWidget);
      expect(find.text('main.dart'), findsNothing);

      await tester.tap(find.text('lib'));
      await pumpUntil(tester, find.text('main.dart'));

      await tester.tap(find.text('main.dart'));
      // The editor names the file relative to the workspace, which is the whole
      // reason the guard's root is canonical.
      await pumpUntil(tester, find.text('lib/main.dart'));
    });

    testWidgets('an agent write refreshes the listing without a button', (
      tester,
    ) async {
      resetFsRevisionForTest();
      final root = workspace();
      File('${root.path}/README.md').writeAsStringSync('# hi\n');

      workbench.workspaceRoot = root.path;
      workbench.openFolder(root.path);
      await pump(tester);
      await pumpUntil(tester, find.text('README.md'));

      // The "agent" writes a new file behind the tree's back — the way the
      // write tool does, announcement included.
      File('${root.path}/notes.md').writeAsStringSync('# new\n');
      bumpFsRevision();
      await pumpUntil(tester, find.text('notes.md'));

      expect(find.text('notes.md'), findsOneWidget);
    });

    testWidgets('says so when there is no workspace to list', (tester) async {
      workbench.openFolder('');
      await pump(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('No workspace folder is set, so there is nothing to list.'),
        findsOneWidget,
      );
    });
  });

  group('the two panels', () {
    /// Both panels, sharing the one controller and its one state — the shape
    /// `main.dart` mounts. Each renders its own tree of the same layout.
    Future<void> pumpBoth(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(
                width: 460,
                height: 300,
                child: Workbench(
                  workbench: workbench,
                  conversation: conversation,
                  terminals: pool,
                  onClose: () {},
                ),
              ),
              SizedBox(
                width: 900,
                height: 240,
                child: Workbench(
                  workbench: workbench,
                  conversation: conversation,
                  terminals: pool,
                  onClose: () {},
                  panel: WorkbenchPanel.bottom,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    testWidgets(
      'a tab opened in the right column crosses to the bottom panel',
      (tester) async {
        await pumpBoth(tester);
        workbench.openGit();
        await tester.pump();

        // One tab strip per panel; the git tab lives in the right column's.
        expect(workbench.state.tabs.single.type, BuiltinTabType.git);
        expect(workbench.state.bottomTabs, isEmpty);

        workbench.sendTabToOtherPanel(
          workbench.state.activePane,
          workbench.state.tabs.single.id,
        );
        await tester.pump();

        // The tab crossed the trees: the right column's pane is empty, the
        // bottom panel's strip holds the tab, and the bottom pane is now the
        // active one.
        expect(workbench.state.tabs, isEmpty);
        expect(workbench.state.bottomTabs.single.type, BuiltinTabType.git);
        expect(
          workbench.state.activePane,
          workbench.state.bottomPanes.single.id,
        );

        // And the bottom panel's strip can send it back.
        workbench.sendTabToOtherPanel(
          workbench.state.activePane,
          workbench.state.bottomTabs.single.id,
        );
        await tester.pump();
        expect(workbench.state.bottomTabs, isEmpty);
        expect(workbench.state.tabs.single.type, BuiltinTabType.git);
      },
    );
  });

  // ADR-0017 S3, on the workbench's own chrome. `app_frame_test.dart` proves the
  // shell survives the system's larger text step; this proves the four tab bodies
  // hung off it do, because none of their labels were in that tree.
  //
  // Measured at 1.8x before the seats were scaled: the tree's search hint wanted
  // 32.0 in a 29.0 box, its rows 36.0 against a 22.0 `itemExtent`, the editor's
  // path 32.0 in 27.0, the side chat's title 40.0 in 35.0 and the browser's
  // address field 36.0 in 33.0. All five are one line of chrome, so each now
  // takes its height from the same step the type does. The step above that named
  // two more: the tab strip (40.0 for a title in the 33.5 a pinned 36 left) and
  // the tree's own header (31.0 in 27.0).
  group('amplified text', () {
    for (final (label, step) in const [
      ('1.8x', amplifiedTextStep),
      ('2.2x', nextTextStep),
    ]) {
      testWidgets('no tab body spills or cuts a label ($label)', (
        tester,
      ) async {
        // The root is resolved because the tree canonicalises it, and an
        // unresolved root makes every displayed path disagree with the disk.
        final root = workspace();
        Directory('${root.path}/deeply').createSync();
        File(
          '${root.path}/deeply/yet-another-nested-file-name.dart',
        ).writeAsStringSync('void main() {}\n');

        await pump(tester, null, const WorkbenchPrefs(), step);
        expect(textDefects(tester), isEmpty, reason: 'an empty pane');

        workbench.openGit();
        await pump(tester, null, const WorkbenchPrefs(), step);
        await tester.pumpAndSettle();
        expect(textDefects(tester), isEmpty, reason: 'the git tab');

        workbench.openTerminal();
        await pump(tester, null, const WorkbenchPrefs(), step);
        await tester.pumpAndSettle();
        expect(textDefects(tester), isEmpty, reason: 'the terminal tab');

        workbench.workspaceRoot = root.path;
        workbench.openFolder(root.path);
        await pump(tester, null, const WorkbenchPrefs(), step);
        await pumpUntil(tester, find.text('deeply'));
        expect(textDefects(tester), isEmpty, reason: 'the file tree');

        workbench.openFile(
          '${root.path}/deeply/yet-another-nested-file-name.dart',
        );
        await pump(tester, null, const WorkbenchPrefs(), step);
        await tester.pumpAndSettle();
        expect(textDefects(tester), isEmpty, reason: 'an open file');

        workbench.openSideChat();
        await pump(tester, null, const WorkbenchPrefs(), step);
        await tester.pumpAndSettle();
        expect(textDefects(tester), isEmpty, reason: 'a side chat');

        workbench.openBrowserUntitled();
        await pump(tester, null, const WorkbenchPrefs(), step);
        await tester.pumpAndSettle();
        expect(textDefects(tester), isEmpty, reason: 'a browser tab');
        // The web view arms a load timeout; left armed, the binding fails the
        // test for a pending timer rather than for anything about the layout.
        await tester.pump(const Duration(seconds: 31));
      });
    }
  });
}
