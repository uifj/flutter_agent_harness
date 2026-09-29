// The queue panel is the only place a waiting input can be edited, so this
// file guards three things: a row says what it is, the two row actions reach the
// controller, and the drag handle actually moves the line.
//
// The panel keeps no list of its own — it renders `controller.pendingInputs` —
// so every assertion here is about wiring: a row that stays behind after its
// input left the queue is the same bug as a drag that does nothing.

import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/conversation/input_queue_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
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
    // A turn that never settles, so the four sends below land in the queue
    // rather than starting turns of their own.
    controller.send('running');
    controller.send('alpha');
    controller.send('beta');
    controller.send('gamma');
  });

  tearDown(() {
    controller.dispose();
    tail.dispose();
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: Scaffold(body: _QueueHost(conversation: controller)),
      ),
    );
  }

  List<String> queuedTexts() => [
    for (final input in controller.pendingInputs) input.preview,
  ];

  testWidgets('it hides itself with nothing waiting', (tester) async {
    controller.startNewSession();
    await pump(tester);

    expect(find.byType(InputQueuePanel), findsOneWidget);
    expect(find.text('Waiting to send'), findsNothing);
  });

  testWidgets('one row per waiting input, in line order', (tester) async {
    await pump(tester);

    expect(find.text('Waiting to send'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('gamma'), findsOneWidget);
    expect(find.byIcon(LucideIcons.grip_vertical), findsNWidgets(3));
  });

  testWidgets('a row shows its delivery and flips it', (tester) async {
    await pump(tester);

    expect(find.text('After this turn'), findsNWidgets(3));
    expect(find.text('Steer this turn'), findsNothing);

    await tester.tap(find.text('After this turn').first);
    await tester.pump();

    expect(queuedTexts(), ['beta', 'gamma']);
    expect(controller.pendingInputs, hasLength(2));
    // The one that flipped left the line for the running turn, and the panel
    // follows the controller rather than keeping its own copy.
    expect(source.handedGuides, hasLength(1));
    expect(find.text('alpha'), findsNothing);
  });

  testWidgets('a row can be dropped', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Remove').first);
    await tester.pump();

    expect(queuedTexts(), ['beta', 'gamma']);
  });

  testWidgets('a drag down moves the row down', (tester) async {
    await pump(tester);

    // What this proves is the wiring and the direction: the grip is the drag
    // handle, and what it reports reaches the controller's line. The exact
    // drop-slot arithmetic is `input_queue_test.dart`'s job — a 96px drag
    // settles wherever the preview says, and pinning that to a pixel would make
    // the test a screenshot.
    await tester.drag(
      find.byIcon(LucideIcons.grip_vertical).first,
      const Offset(0, 96),
    );
    await tester.pumpAndSettle();

    expect(queuedTexts(), ['beta', 'alpha', 'gamma']);
    expect(find.text('alpha'), findsOneWidget);
  });
}

/// The panel as conversation_root mounts it: it reads the controller's queue
/// and forwards the three row actions to it, with no list of its own.
class _QueueHost extends StatefulWidget {
  const _QueueHost({required this.conversation});

  final ConversationController conversation;

  @override
  State<_QueueHost> createState() => _QueueHostState();
}

class _QueueHostState extends State<_QueueHost> {
  @override
  void initState() {
    super.initState();
    widget.conversation.addListener(_onEdited);
  }

  @override
  void dispose() {
    widget.conversation.removeListener(_onEdited);
    super.dispose();
  }

  void _onEdited() => setState(() {});

  @override
  Widget build(BuildContext context) => InputQueuePanel(
    items: widget.conversation.pendingInputs,
    onRemove: widget.conversation.removeQueued,
    onReorder: widget.conversation.moveQueued,
    onDelivery: widget.conversation.setQueuedDelivery,
  );
}
