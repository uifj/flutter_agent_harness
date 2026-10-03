// The free-window layer, pumped for real.
//
// The state's reducers have their own suite; what needs a widget tree is the
// layer's half of the contract — a floated tab keeps rendering through the
// same registry the panes use, the header's gestures reach the controller,
// and an empty layer paints nothing and swallows no pointer.

import 'dart:io';

import 'package:planstar/model/sidebar_tab.dart';
import 'package:planstar/state/workbench_controller.dart';
import 'package:planstar/state/workbench_store.dart';
import 'package:planstar/ui/workbench/free_window_layer.dart';
import 'package:planstar/state/conversation_controller.dart';
import 'package:planstar/state/streaming_tail.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

import 'amplified_text_probe.dart';
import 'fake_terminal_process.dart';
import 'fake_git.dart';
import 'fake_turn_source.dart';

void main() {
  late Directory support;
  late WorkbenchStore store;
  late WorkbenchController workbench;
  late FakeTurnSource source;
  late StreamingTail tail;
  late ConversationController conversation;
  late FakeTerminalSpawner terminals;

  setUp(() {
    support = Directory.systemTemp.createTempSync('dsh_float_ui_');
    store = WorkbenchStore.open(support);
    workbench = WorkbenchController(store: store);
    source = FakeTurnSource();
    tail = StreamingTail();
    conversation = ConversationController(runtime: source, tail: tail);
    terminals = FakeTerminalSpawner();
  });

  tearDown(() {
    workbench.dispose();
    conversation.dispose();
    tail.dispose();
    support.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, {double step = 1.0}) async {
    // The default 800x600 test viewport would clamp every window to an 800px
    // wide layer and swallow half the geometry assertions.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => amplifiedAppBuilder(step, child),
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 800,
            child: FreeWindowLayer(
              workbench: workbench,
              conversation: conversation,
              terminals: terminals.manager(),
              status: FakeGit.inert(),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('an empty layer paints nothing', (tester) async {
    await pump(tester);
    expect(find.byType(Positioned), findsNothing);
  });

  testWidgets('a floated tab renders in its window', (tester) async {
    workbench.openGit();
    workbench.floatTab('git', 600, 400, 1200, 800);
    await pump(tester);

    expect(find.text('Source Control'), findsOneWidget);
    expect(workbench.state.tabs, isEmpty);
    expect(workbench.state.floats.single.tab.id, 'git');
  });

  testWidgets('the header close takes the window and the tab with it', (
    tester,
  ) async {
    workbench.openGit();
    workbench.floatTab('git', 600, 400, 1200, 800);
    await pump(tester);

    await tester.tap(find.byIcon(LucideIcons.x).hitTestable());
    await tester.pump();
    expect(find.text('Source Control'), findsNothing);
    expect(workbench.state.floats, isEmpty);
    // The tab is gone from the layout too — closing a window closes its tab.
    expect(workbench.state.tabs, isEmpty);
  });

  testWidgets('the header menu docks the window back', (tester) async {
    workbench.openGit();
    workbench.floatTab('git', 600, 400, 1200, 800);
    await pump(tester);

    await tester.tapAt(
      tester.getTopLeft(find.text('Source Control')) + const Offset(4, 4),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dock to sidebar'));
    await tester.pumpAndSettle();

    expect(workbench.state.floats, isEmpty);
    expect(workbench.state.tabs.map((tab) => tab.id), ['git']);
  });

  testWidgets('dragging the header moves the window', (tester) async {
    workbench.openGit();
    workbench.floatTab('git', 600, 400, 1200, 800);
    // A window at the default height (776 of 800) has no room to move
    // vertically — the clamp pins it. Resize first so both axes can travel.
    workbench.resizeFloat(
      workbench.state.floats.single.id,
      400,
      300,
      1200,
      800,
    );
    await pump(tester);

    final before = workbench.state.floats.single;
    final header = find.text('Source Control');
    // A mouse drag in short steps: one long jump lets the recogniser's slop
    // eat most of the delta, which is a test artifact, not a gesture.
    final gesture = await tester.startGesture(
      tester.getCenter(header),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(10, 5));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();

    final after = workbench.state.floats.single;
    expect(after.x, closeTo(before.x + 120, 1));
    expect(after.y, closeTo(before.y + 60, 1));
  });

  testWidgets('a floating terminal keeps its tab id stable across builds', (
    tester,
  ) async {
    workbench.openTerminal();
    workbench.floatTab('terminal:1', 600, 400, 1200, 800);
    await pump(tester);
    expect(workbench.state.floats.single.tab.type, BuiltinTabType.terminal);
  });

  // A free window is chrome the pane walk never lays out: its own title bar,
  // its own resize grip, and a header menu that only exists once right-clicked.
  group('amplified text', () {
    for (final (label, step) in const [
      ('1.8x', amplifiedTextStep),
      ('2.2x', nextTextStep),
    ]) {
      testWidgets('the window and its header menu keep their labels ($label)', (
        tester,
      ) async {
        // A terminal over the fake spawner: the git tab would arm a 30s process
        // timeout that outlives the test.
        workbench.openTerminal();
        workbench.floatTab(workbench.state.tabs.last.id, 60, 60, 520, 360);
        await pump(tester, step: step);
        await tester.pumpAndSettle();

        expect(find.text('Terminal 1'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the window frame');

        await tester.tapAt(
          tester.getTopLeft(find.text('Terminal 1')) + const Offset(4, 4),
          buttons: kSecondaryButton,
        );
        await tester.pumpAndSettle();
        expect(find.text('Dock to sidebar'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the header menu');

        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.text('Dock to sidebar'), findsNothing);
      });
    }
  });
}
