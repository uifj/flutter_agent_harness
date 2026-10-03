// What happens to input the user sends while a turn already holds the
// transcript (ADR-0013).
//
// The claim this file guards: nothing the user submitted is ever dropped, and
// nothing is sent that the user did not ask to send. Both halves matter — the
// first is the data-loss bug this feature exists to fix, the second is what a
// queue turns into if the drain is not careful about stop.

import 'package:planstar/model/conversation.dart';
import 'package:planstar/model/queued_input.dart';
import 'package:planstar/model/turn_event.dart';
import 'package:planstar/state/conversation_controller.dart';
import 'package:planstar/state/streaming_tail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_turn_source.dart';

void main() {
  late FakeTurnSource source;
  late StreamingTail tail;
  late ConversationController controller;

  setUp(() {
    source = FakeTurnSource();
    tail = StreamingTail();
    controller = ConversationController(runtime: source, tail: tail);
  });

  tearDown(() {
    controller.dispose();
    tail.dispose();
  });

  /// Starts a turn and waits until the send has landed in the transcript.
  Future<void> startTurn() async {
    controller.send('first');
    await Future<void>.delayed(Duration.zero);
  }

  /// Ends the running turn, then lets the drain that follows it run.
  Future<void> settleTurn() async {
    source.emit(const TurnFinished(outcome: TurnOutcome.completed));
    await source.close();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  List<String> queued() => [
    for (final input in controller.pendingInputs) input.text,
  ];

  List<String> userMessages() => [
    for (final node in controller.nodes)
      if (node is UserMessageNode) node.text,
  ];

  group('the queue', () {
    test('a send during a turn waits instead of being refused', () async {
      await startTurn();
      controller.send('second');
      await Future<void>.delayed(Duration.zero);

      expect(source.turns, 1, reason: 'a queued input must not start a turn');
      expect(queued(), ['second']);
      expect(userMessages(), ['first']);
    });

    test('it drains in order when the turn lets go', () async {
      await startTurn();
      controller.send('second');
      controller.send('third');
      await Future<void>.delayed(Duration.zero);

      await settleTurn();

      expect(source.turns, 2);
      expect(source.sentTexts, ['first', 'second']);
      expect(queued(), ['third']);
    });

    test('a drain stops at a turn that pauses on approval', () async {
      await startTurn();
      controller.send('second');
      controller.send('third');
      await Future<void>.delayed(Duration.zero);

      source.emit(
        ApprovalRequired(
          ApprovalRequest(ref: 't1', toolName: 'write', arguments: const {}),
        ),
      );
      await settleTurn();

      // The resumed turn is the drain's problem, not this one's: an approval is
      // pending, so the line waits.
      expect(source.turns, 1);
      expect(queued(), ['second', 'third']);
    });

    test('stop parks the queue rather than starting what it queued', () async {
      await startTurn();
      controller.send('second');
      await Future<void>.delayed(Duration.zero);

      controller.stop();
      await settleTurn();

      expect(controller.isQueueHeld, isTrue);
      expect(source.turns, 1);
      expect(queued(), ['second']);
    });

    test('sending again goes now, and the parked line follows', () async {
      await startTurn();
      controller.send('second');
      controller.stop();
      await settleTurn();
      expect(source.turns, 1);

      controller.send('third');
      await Future<void>.delayed(Duration.zero);

      // The message typed after the stop is the one the user wants read first;
      // the parked row keeps its place behind it.
      expect(source.sentTexts, ['first', 'third']);
      expect(queued(), ['second']);

      await settleTurn();
      expect(source.sentTexts, ['first', 'third', 'second']);
      expect(queued(), isEmpty);
    });

    test('a new session drops the queue with the transcript', () async {
      await startTurn();
      controller.send('second');
      await Future<void>.delayed(Duration.zero);

      controller.startNewSession();

      expect(queued(), isEmpty);
      expect(controller.isQueueHeld, isFalse);
    });

    test('an empty draft never reaches the queue', () async {
      await startTurn();
      controller.send('   ');
      await Future<void>.delayed(Duration.zero);

      expect(queued(), isEmpty);
    });
  });

  group('steering', () {
    test(
      'a guide goes to the running turn and shows in the transcript',
      () async {
        await startTurn();
        controller.send('look here', delivery: InputDelivery.guide);
        await Future<void>.delayed(Duration.zero);

        expect(source.handedGuides, hasLength(1));
        expect(source.turns, 1, reason: 'a steer is not a new turn');
        expect(queued(), isEmpty);
        expect(userMessages(), ['first', 'look here']);
      },
    );

    test('a guide with no turn running is simply sent', () async {
      controller.send('go', delivery: InputDelivery.guide);
      await Future<void>.delayed(Duration.zero);

      expect(source.handedGuides, isEmpty);
      expect(source.turns, 1);
      expect(source.sentTexts, ['go']);
    });

    test('an unreached guide comes back to the front of the line', () async {
      await startTurn();
      controller.send('second');
      controller.send('steer now', delivery: InputDelivery.guide);
      await Future<void>.delayed(Duration.zero);
      expect(queued(), ['second']);

      // The answer streamed without another model call, so nothing read the
      // steer: it must not vanish with the turn. It goes to the FRONT — it was
      // said earlier than the row queued after it.
      await settleTurn();

      expect(source.sentTexts, ['first', 'steer now']);
      expect(queued(), ['second']);
    });

    test('a queued row switched to guide hands itself over', () async {
      await startTurn();
      controller.send('waiting');
      await Future<void>.delayed(Duration.zero);
      expect(queued(), ['waiting']);

      controller.setQueuedDelivery(
        controller.pendingInputs.single.id,
        InputDelivery.guide,
      );
      await Future<void>.delayed(Duration.zero);

      expect(queued(), isEmpty);
      expect(source.handedGuides, hasLength(1));
      expect(userMessages(), ['first', 'waiting']);
    });
  });

  group('editing the line', () {
    test('a row can be dropped', () async {
      await startTurn();
      controller.send('keep');
      controller.send('drop');
      await Future<void>.delayed(Duration.zero);

      controller.removeQueued(controller.pendingInputs[1].id);

      expect(queued(), ['keep']);
    });

    test('a drag down moves the row down one, not two', () async {
      await startTurn();
      controller.send('a');
      controller.send('b');
      controller.send('c');
      await Future<void>.delayed(Duration.zero);

      // ReorderableListView reports the drop slot against the list the dragged
      // row is still in, so index 2 means "after the last row".
      controller.moveQueued(0, 3);
      expect(queued(), ['b', 'c', 'a']);

      controller.moveQueued(2, 0);
      expect(queued(), ['a', 'b', 'c']);
    });

    test('out-of-range indices change nothing', () async {
      await startTurn();
      controller.send('a');
      await Future<void>.delayed(Duration.zero);

      controller.moveQueued(5, 0);
      controller.moveQueued(0, -2);
      expect(queued(), ['a']);
    });
  });
}
