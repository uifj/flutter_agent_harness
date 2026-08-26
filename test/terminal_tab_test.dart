// The terminal tab, over a fake pty pool.
//
// What is worth a widget test here is the wiring the manager's own tests
// cannot see: that the emulator and the session are one terminal (output one
// way, keystrokes the other, resize the third), that a dead session is a
// banner over a working restart rather than a silent input sink, and — the
// property the whole pool exists for — that a shell survives everything the
// workbench does to its tab except closing it.

import 'dart:io';

import 'package:agent_harness/host/terminal_manager.dart';
import 'package:agent_harness/sidebar/model/sidebar_tab.dart';
import 'package:agent_harness/sidebar/model/split_node.dart';
import 'package:agent_harness/sidebar/state/workbench_controller.dart';
import 'package:agent_harness/sidebar/state/workbench_store.dart';
import 'package:agent_harness/sidebar/ui/tabs/terminal_tab.dart';
import 'package:agent_harness/sidebar/ui/workbench.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xterm/xterm.dart';

import 'fake_terminal_process.dart';
import 'fake_turn_source.dart';

void main() {
  late Directory support;
  late WorkbenchController workbench;
  late FakeTurnSource source;
  late StreamingTail tail;
  late ConversationController conversation;
  late FakeTerminalSpawner fake;
  late TerminalManager manager;

  setUp(() {
    support = Directory.systemTemp.createTempSync('dsh_terminal_tab_');
    workbench = WorkbenchController(store: WorkbenchStore.open(support));
    // Only there so the column's SubagentHost has something to carry: this
    // suite never opens a sub-agent tab.
    source = FakeTurnSource();
    tail = StreamingTail();
    conversation = ConversationController(runtime: source, tail: tail);
    fake = FakeTerminalSpawner();
    manager = fake.manager();
  });

  tearDown(() {
    workbench.dispose();
    conversation.dispose();
    tail.dispose();
    manager.dispose();
    support.deleteSync(recursive: true);
  });

  /// The tab pumped on its own, the way a unit harness would: no pane, no
  /// tab strip, just the body.
  Future<void> pumpBody(WidgetTester tester, [WorkbenchController? withWorkbench]) =>
      tester.pumpWidget(
        MaterialApp(
          theme: dswThemeData(Brightness.light),
          home: Scaffold(
            body: TerminalHost(
              manager: manager,
              child: TerminalTab(
                workbench: withWorkbench ?? workbench,
                tab: const SidebarTab(
                  id: 'terminal:1',
                  type: BuiltinTabType.terminal,
                  title: 'Terminal 1',
                ),
              ),
            ),
          ),
        ),
      );

  /// The whole workbench column, at the width the layout was made for.
  Future<void> pumpColumn(WidgetTester tester, [WorkbenchController? withWorkbench]) =>
      tester.pumpWidget(
        MaterialApp(
          theme: dswThemeData(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 600,
              child: Workbench(
                workbench: withWorkbench ?? workbench,
                conversation: conversation,
                terminals: manager,
                onClose: () {},
              ),
            ),
          ),
        ),
      );

  /// The emulator a pumped tab is showing.
  Terminal emulator(WidgetTester tester) =>
      tester.widget<TerminalView>(find.byType(TerminalView)).terminal;

  group('the wiring', () {
    testWidgets('attaches on first build, renders output, sends input', (
      tester,
    ) async {
      await pumpBody(tester);
      final process = fake.spawned.single;

      process.emit('hello world\n');
      await tester.pump();
      expect(emulator(tester).buffer.getText(), contains('hello world'));

      emulator(tester).textInput('ls -l\n');
      expect(process.writes, ['ls -l\n']);
    });

    testWidgets('resizes the process when the view lays out', (tester) async {
      await pumpBody(tester);
      await tester.pump();
      expect(fake.spawned.single.resizes, isNotEmpty);
    });

    testWidgets('spawns in the workspace when there is one', (tester) async {
      workbench.workspaceRoot = support.path;
      await pumpBody(tester);
      expect(fake.spawnArgs.single.$2, support.path);
    });
  });

  group('dead sessions', () {
    testWidgets('a spawn failure banners and the retry reaches a real spawn', (
      tester,
    ) async {
      fake.failNext = 1;
      await pumpBody(tester);
      expect(fake.spawned, isEmpty);
      expect(find.textContaining('Could not start the shell'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(fake.spawned, hasLength(1));
      expect(find.textContaining('Could not start the shell'), findsNothing);

      // The retry wired a live shell, not just a quieter banner.
      fake.spawned.single.emit('back\n');
      await tester.pump();
      expect(emulator(tester).buffer.getText(), contains('back'));
    });

    testWidgets('an exited shell banners with its code and restarts', (
      tester,
    ) async {
      await pumpBody(tester);
      fake.spawned.single.exit(127);
      await tester.pumpAndSettle();
      expect(find.text('The shell exited (127).'), findsOneWidget);

      await tester.tap(find.text('Restart'));
      await tester.pumpAndSettle();
      expect(fake.spawned, hasLength(2));
      expect(fake.spawned.first.exited, isTrue);
      expect(find.text('The shell exited (127).'), findsNothing);
    });

    testWidgets('a clean exit says so without a code', (tester) async {
      await pumpBody(tester);
      fake.spawned.single.exit(0);
      await tester.pumpAndSettle();
      expect(find.text('The shell exited.'), findsOneWidget);
    });
  });

  group('the process lifetime', () {
    testWidgets('unmounting with the tab gone from the layout kills it', (
      tester,
    ) async {
      await pumpBody(tester);
      final process = fake.spawned.single;

      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

      expect(process.killed, isTrue);
    });

    testWidgets('switching tabs keeps the shell attached', (tester) async {
      workbench.openTerminal();
      await pumpColumn(tester);
      final process = fake.spawned.single;

      workbench.openGit();
      await tester.pumpAndSettle();
      expect(process.killed, isFalse);

      await tester.tap(find.text('Terminal 1'));
      await tester.pumpAndSettle();
      // Still the one process: keep-alive is what the IndexedStack is for.
      expect(fake.spawned, hasLength(1));

      workbench.closeTab(workbench.state.activePane, 'terminal:1');
      await tester.pumpAndSettle();
      expect(process.killed, isTrue);
    });

    testWidgets('moving the tab to another pane reattaches the same shell', (
      tester,
    ) async {
      workbench.openTerminal();
      await pumpColumn(tester);
      final process = fake.spawned.single;

      workbench.splitPane(SplitDirection.row);
      await tester.pumpAndSettle();
      final panes = workbench.state.panes.map((pane) => pane.id).toList();
      workbench.moveTab(panes[0], 'terminal:1', panes[1]);
      await tester.pumpAndSettle();

      // A fresh body, the same process: the pool's whole job.
      expect(fake.spawned, hasLength(1));
      expect(process.killed, isFalse);
      expect(fake.spawned.single.writes, isEmpty);
    });

    testWidgets('persisting the conversation keeps its shells', (tester) async {
      workbench.openTerminal();
      await pumpColumn(tester);
      final process = fake.spawned.single;

      // The unsaved conversation's first persisted turn adopts its layout,
      // which is the moment a layout stops being nameless — not the moment
      // its terminals stop being its terminals.
      await tester.runAsync(() => workbench.bindSession('s1'));
      await tester.pumpAndSettle();

      expect(fake.spawned, hasLength(1));
      expect(process.killed, isFalse);

      // And the re-keyed session dies when the conversation is left.
      await tester.runAsync(() => workbench.bindSession('s2'));
      await tester.pumpAndSettle();
      expect(process.killed, isTrue);
    });

    testWidgets('a conversation swap retires the old shell', (tester) async {
      workbench.openTerminal();
      await pumpColumn(tester);
      final first = fake.spawned.single;

      late WorkbenchController other;
      await tester.runAsync(() async {
        await workbench.bindSession('s1');
        other = WorkbenchController(store: WorkbenchStore.open(support));
        await other.bindSession('s2');
        // Same pane id, same tab id: the element is reused rather than
        // rebuilt, which is the case didUpdateWidget exists for.
        other.openTerminal();
      });
      addTearDown(other.dispose);

      await pumpColumn(tester, other);
      await tester.pumpAndSettle();

      expect(fake.spawned, hasLength(2));
      expect(first.killed, isTrue);
      expect(fake.spawned.last.killed, isFalse);
    });
  });
}
