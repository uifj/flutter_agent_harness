// The streaming split is the app's only performance contract, so it gets a test.
//
// The claim: token deltas reach the tail's notifiers and nothing else. If a delta
// ever notifies the conversation controller, every message widget in the list
// rebuilds per token — the failure this file exists to catch.

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_turn_source.dart';

void main() {
  late FakeTurnSource source;
  late StreamingTail tail;
  late ConversationController controller;
  late int controllerNotifications;
  late int tailNotifications;

  setUp(() {
    source = FakeTurnSource();
    tail = StreamingTail();
    controller = ConversationController(runtime: source, tail: tail);
    controllerNotifications = 0;
    tailNotifications = 0;
    controller.addListener(() => controllerNotifications++);
    tail.text.addListener(() => tailNotifications++);
  });

  tearDown(() {
    controller.dispose();
    tail.dispose();
  });

  /// Starts a turn and waits for the send to be reflected in the transcript.
  /// `send` only completes when the turn does, so it is deliberately not awaited.
  Future<void> startTurn() async {
    controller.send('hello');
    await Future<void>.delayed(Duration.zero);
  }

  test('token deltas notify the tail and never the controller', () async {
    await startTurn();
    // The user message and the opening of the assistant bubble are shape changes,
    // so they legitimately notify. Everything after this point must not.
    source.emit(const TextDelta(text: 'He', messageIndex: 0));
    await Future<void>.delayed(Duration.zero);
    final baseline = controllerNotifications;

    for (final token in ['llo', ' the', 're', '!']) {
      source.emit(TextDelta(text: token, messageIndex: 0));
    }
    await Future<void>.delayed(Duration.zero);

    expect(controllerNotifications, baseline, reason: 'list rebuilt per token');
    expect(tail.text.value, 'Hello there!');
    expect(tailNotifications, 5);
  });

  test('a new message index opens a second bubble', () async {
    await startTurn();
    source.emit(const TextDelta(text: 'first', messageIndex: 0));
    source.emit(const TextDelta(text: 'second', messageIndex: 1));
    await Future<void>.delayed(Duration.zero);

    // Index 0 froze into its own node; the tail now belongs to index 1.
    expect(controller.nodes, hasLength(3));
    expect((controller.nodes[1] as AssistantMessageNode).text, 'first');
    expect((controller.nodes[1] as AssistantMessageNode).isStreaming, isFalse);
    expect(tail.nodeId, controller.nodes[2].id);
    expect(tail.text.value, 'second');
  });

  test('reasoning streams on its own notifier', () async {
    await startTurn();
    source.emit(const ReasoningDelta(text: 'thinking', messageIndex: 0));
    source.emit(const TextDelta(text: 'answer', messageIndex: 0));
    await Future<void>.delayed(Duration.zero);

    expect(tail.reasoning.value, 'thinking');
    expect(tail.text.value, 'answer');
  });

  test('turn end freezes the tail into the node exactly once', () async {
    await startTurn();
    source.emit(const TextDelta(text: 'done', messageIndex: 0));
    await Future<void>.delayed(Duration.zero);
    final beforeFinish = controllerNotifications;

    source.emit(const TurnFinished(outcome: TurnOutcome.completed));
    await Future<void>.delayed(Duration.zero);

    expect(controllerNotifications, beforeFinish + 1);
    final node = controller.nodes.last as AssistantMessageNode;
    expect(node.text, 'done');
    expect(node.isStreaming, isFalse);
    expect(tail.nodeId, isNull);
    expect(tail.text.value, isEmpty);
    expect(controller.isBusy, isFalse);
  });

  test('a bubble that never received content is dropped', () async {
    await startTurn();
    source.emit(
      const ToolCallRequested(ref: 'r1', name: 'glob', arguments: {}),
    );
    source.emit(const TurnFinished(outcome: TurnOutcome.completed));
    await Future<void>.delayed(Duration.zero);

    // Just the user message and the tool card — no empty assistant bubble.
    expect(controller.nodes, hasLength(2));
    expect(controller.nodes[1], isA<ToolCallNode>());
  });

  test('tool results settle the card that asked', () async {
    await startTurn();
    source.emit(
      const ToolCallRequested(
        ref: 'r1',
        name: 'read',
        arguments: {'file_path': 'a.txt'},
      ),
    );
    source.emit(const ToolCallSucceeded(ref: 'r1', output: {'ok': true}));
    await Future<void>.delayed(Duration.zero);

    final card = controller.nodes[1] as ToolCallNode;
    expect(card.status, ToolStatus.succeeded);
    expect(card.output, {'ok': true});
  });

  test('declining an approval leaves the card denied, not failed', () async {
    await startTurn();
    source.emit(
      const ToolCallRequested(
        ref: 'r1',
        name: 'write',
        arguments: {'file_path': 'a.txt'},
      ),
    );
    source.emit(
      const ApprovalRequired(
        ApprovalRequest(
          ref: 'r1',
          toolName: 'write',
          arguments: {'file_path': 'a.txt'},
        ),
      ),
    );
    source.emit(const TurnFinished(outcome: TurnOutcome.awaitingApproval));
    await Future<void>.delayed(Duration.zero);

    expect(controller.pendingApproval?.ref, 'r1');
    expect((controller.nodes[1] as ToolCallNode).status,
        ToolStatus.awaitingApproval);
    expect(controller.isBusy, isFalse);
    expect(controller.isInputBlocked, isTrue,
        reason: 'a pending decision must block the composer');

    controller.respondToApproval(false);
    await Future<void>.delayed(Duration.zero);
    // The tool reports the refusal back as a failure; `denied` is the more
    // precise story and must survive it.
    source.emit(const ToolCallFailed(ref: 'r1', message: 'declined'));
    source.emit(const TurnFinished(outcome: TurnOutcome.completed));
    await Future<void>.delayed(Duration.zero);

    final card = controller.nodes[1] as ToolCallNode;
    expect(card.status, ToolStatus.denied);
    expect(card.approval, isNull);
    expect(controller.pendingApproval, isNull);
  });

  test('stop goes quiet immediately, without waiting for the runtime', () async {
    await startTurn();
    source.emit(const TextDelta(text: 'partial', messageIndex: 0));
    await Future<void>.delayed(Duration.zero);

    controller.stop();

    expect(source.stopCalls, 1);
    expect(controller.isBusy, isFalse);
    // Whatever was streamed is kept: a cancelled answer is still a record of
    // what happened.
    expect((controller.nodes.last as AssistantMessageNode).text, 'partial');
    expect(tail.nodeId, isNull);
  });

  test('a failed turn appends an error node', () async {
    await startTurn();
    source.emit(
      const TurnFinished(outcome: TurnOutcome.failed, errorMessage: 'boom'),
    );
    await Future<void>.delayed(Duration.zero);

    expect((controller.nodes.last as ErrorNode).message, 'boom');
  });

  test('a persisted session id is reported once', () async {
    final seen = <String>[];
    final local = ConversationController(
      runtime: source,
      tail: tail,
      onSessionPersisted: seen.add,
    );
    addTearDown(local.dispose);

    local.send('hello');
    await Future<void>.delayed(Duration.zero);
    source.emit(
      const TurnFinished(outcome: TurnOutcome.completed, sessionId: 's-1'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(seen, ['s-1']);
  });

  test('a second send is refused while a turn is running', () async {
    await startTurn();
    final nodesBefore = controller.nodes.length;

    controller.send('again');
    await Future<void>.delayed(Duration.zero);

    expect(controller.nodes.length, nodesBefore);
  });
}
