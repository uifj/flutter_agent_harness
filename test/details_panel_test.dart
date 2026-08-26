// The details column, and the pill that fills it.
//
// Three things are worth pinning here, and they are the three that would rot
// silently: the body's state machine (nothing selected / not in this transcript /
// still running / settled), the pill's contract that revealing it costs no
// layout, and the one bug this shape invites — the copy confirmation belongs to
// the call being shown, so it must not follow the selection to the next one.

import 'dart:async';

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/details_selection.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/conversation/details_panel.dart';
import 'package:agent_harness/ui/tool/tool_card.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_turn_source.dart';

void main() {
  late FakeTurnSource source;
  late StreamingTail tail;
  late ConversationController conversation;
  late DetailsSelection selection;
  var opened = 0;
  var closed = 0;

  setUp(() {
    source = FakeTurnSource();
    tail = StreamingTail();
    conversation = ConversationController(runtime: source, tail: tail);
    opened = 0;
    closed = 0;
    selection = DetailsSelection(onSelect: () => opened++);
  });

  tearDown(() {
    selection.dispose();
    conversation.dispose();
    tail.dispose();
  });

  /// The panel at the column's contract default width.
  Future<void> pumpPanel(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: dswThemeData(Brightness.light),
      home: Scaffold(
        body: SizedBox(
          width: 360,
          height: 600,
          child: DetailsPanel(
            conversation: conversation,
            selection: selection,
            onClose: () => closed++,
          ),
        ),
      ),
    ),
  );

  /// Opens a turn and lets the frame that starts it settle.
  Future<void> startTurn(WidgetTester tester) async {
    unawaited(conversation.send('go'));
    await tester.pump();
  }

  /// Hands an emitted event to the controller and paints the result. The stream
  /// delivers on a microtask, which `pump` alone does not drain.
  Future<void> deliver(WidgetTester tester) async {
    await tester.idle();
    await tester.pump();
  }

  /// The transcript's tool calls, in order.
  List<ToolCallNode> calls() =>
      conversation.nodes.whereType<ToolCallNode>().toList();

  testWidgets('with nothing selected it says where to click', (tester) async {
    await pumpPanel(tester);

    expect(find.text('Details'), findsOneWidget);
    expect(
      find.text('Click a tool row in the message flow to view its details'),
      findsOneWidget,
    );
    expect(find.text('Input'), findsNothing);
  });

  testWidgets('the close control reports up rather than clearing the selection', (
    tester,
  ) async {
    await pumpPanel(tester);
    selection.select(callId: 'n1', toolName: 'Read');
    await tester.pump();

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();

    expect(closed, 1);
    // Closing is a layout write. The selection survives it, which is what lets
    // the same pill reopen the column onto the same call.
    expect(selection.callId, 'n1');
  });

  testWidgets('a call this transcript does not hold is named as such', (
    tester,
  ) async {
    await pumpPanel(tester);
    selection.select(callId: 'gone', toolName: 'Read');
    await tester.pump();

    expect(find.text('This call is outside the current window'), findsOneWidget);
    // The header still has something to say: the name came with the selection.
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Output'), findsNothing);
  });

  testWidgets('a running call shows its input and waits for the output', (
    tester,
  ) async {
    await pumpPanel(tester);
    await startTurn(tester);
    source.emit(
      const ToolCallRequested(
        ref: 'r1',
        name: 'read',
        arguments: {'file_path': '/tmp/a.txt'},
      ),
    );
    await deliver(tester);

    selection.select(callId: calls().single.id, toolName: 'Read');
    await tester.pump();

    // Input is always a section: a call always has an args blob.
    expect(find.text('Input'), findsOneWidget);
    expect(find.textContaining('/tmp/a.txt'), findsOneWidget);
    expect(find.text('json'), findsOneWidget);
    expect(find.text('Running…'), findsOneWidget);

    source.emit(const ToolCallSucceeded(ref: 'r1', output: 'hello from disk'));
    await deliver(tester);

    // The panel follows the call it is already showing, without being reselected.
    expect(find.text('Running…'), findsNothing);
    expect(find.text('hello from disk'), findsOneWidget);
  });

  testWidgets('a failed call shows the failure as the output', (tester) async {
    await pumpPanel(tester);
    await startTurn(tester);
    source.emit(
      const ToolCallRequested(
        ref: 'r1',
        name: 'read',
        arguments: {'file_path': '/nope'},
      ),
    );
    await deliver(tester);
    source.emit(const ToolCallFailed(ref: 'r1', message: 'No such file.'));
    await deliver(tester);

    selection.select(callId: calls().single.id, toolName: 'Read');
    await tester.pump();

    expect(find.text('No such file.'), findsOneWidget);
    expect(find.text('Running…'), findsNothing);
  });

  testWidgets('the copy confirmation does not follow the selection', (
    tester,
  ) async {
    await pumpPanel(tester);
    await startTurn(tester);
    source.emit(
      const ToolCallRequested(
        ref: 'r1',
        name: 'read',
        arguments: {'file_path': '/tmp/a.txt'},
      ),
    );
    source.emit(
      const ToolCallRequested(
        ref: 'r2',
        name: 'read',
        arguments: {'file_path': '/tmp/b.txt'},
      ),
    );
    await deliver(tester);

    final both = calls();
    selection.select(callId: both.first.id, toolName: 'Read');
    await tester.pump();

    await tester.tap(find.text('Copy'));
    await tester.pump();
    expect(find.text('Copied'), findsOneWidget);

    // The panel does not unmount between calls, so without a key on the body the
    // second call's code block would open already confirmed.
    selection.select(callId: both.last.id, toolName: 'Read');
    await tester.pump();
    expect(find.text('Copied'), findsNothing);
    expect(find.text('Copy'), findsOneWidget);

    // And the confirmation still expires on its own.
    await tester.pump(const Duration(milliseconds: 1100));
  });

  group('the Inspect pill', () {
    /// One expanded tool card, inside the scope the pill needs.
    Future<ToolCallNode> pumpCard(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dswThemeData(Brightness.light),
          home: Scaffold(
            body: DetailsSelectionScope(
              selection: selection,
              child: ListenableBuilder(
                listenable: conversation,
                builder: (context, _) {
                  final node = conversation.nodes.whereType<ToolCallNode>();
                  return node.isEmpty
                      ? const SizedBox.shrink()
                      : ToolCard(node: node.first);
                },
              ),
            ),
          ),
        ),
      );
      await startTurn(tester);
      source.emit(
        const ToolCallRequested(
          ref: 'r1',
          name: 'read',
          arguments: {'file_path': '/tmp/a.txt'},
        ),
      );
      source.emit(const ToolCallSucceeded(ref: 'r1', output: 'hi'));
      await deliver(tester);

      // The body, and the pill under it, only exist while the row is open.
      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();
      return calls().single;
    }

    testWidgets('points the panel at its call and opens the column', (
      tester,
    ) async {
      final node = await pumpCard(tester);

      await tester.tap(find.text('Inspect'));
      await tester.pumpAndSettle();

      expect(selection.callId, node.id);
      expect(selection.toolName, 'Read');
      expect(opened, 1);

      // Selecting the same call again still asks for the column: it may have
      // been closed since.
      await tester.tap(find.text('Inspect'));
      await tester.pumpAndSettle();
      expect(opened, 2);
    });

    testWidgets('reserves its line, so revealing it shifts nothing', (
      tester,
    ) async {
      await pumpCard(tester);
      final hidden = tester.getSize(find.text('Inspect'));
      final cardTop = tester.getTopLeft(find.text('IN'));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Read')));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.text('Inspect')), hidden);
      expect(tester.getTopLeft(find.text('IN')), cardTop);
    });
  });
}
