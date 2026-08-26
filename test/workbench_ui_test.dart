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
import 'package:agent_harness/sidebar/state/workbench_controller.dart';
import 'package:agent_harness/sidebar/state/workbench_store.dart';
import 'package:agent_harness/sidebar/ui/workbench.dart';
import 'package:agent_harness/sidebar/ui/workbench_tab_bar.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

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

  /// The workbench at the details column's default width, which is the width
  /// every layout decision in it was made for.
  Future<void> pump(WidgetTester tester, [WorkbenchController? controller]) =>
      tester.pumpWidget(
        MaterialApp(
          theme: dswThemeData(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: Workbench(
                workbench: controller ?? workbench,
                conversation: conversation,
                terminals: pool,
                onClose: () => closed++,
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

  group('the header', () {
    testWidgets('names the folder, or says there is none', (tester) async {
      await pump(tester);
      expect(find.text('No folder'), findsOneWidget);

      workbench.workspaceRoot = '/somewhere/my-project';
      await tester.pump();
      expect(find.text('my-project'), findsOneWidget);
    });

    testWidgets('closes the column', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Close panel'));
      await tester.pump();
      expect(closed, 1);
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
}
