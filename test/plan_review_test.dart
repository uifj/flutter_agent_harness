// The plan review card, and the contract that puts it on screen.
//
// Two layers, because the card alone is only half the feature:
//
//   * The panel: one decision over one markdown body, whose buttons are
//     one-shot — a double-click must not double-send, and a second plan
//     must re-arm the latch. Both are State-level properties a render of
//     the card cannot show.
//   * The host: `ConversationRoot` swaps the composer for the card exactly
//     when the app's plan-mode contract holds (mode is plan, input not
//     blocked, a plan of record exists, and it has not been answered), and
//     the three answers do what they say — approve leaves plan mode and
//     sends, decline stays and sends, discuss just gives the composer back.
//     The fake turn source supplies a `plan` tool call the way a real turn
//     would, so the trigger is exercised end to end.

import 'dart:async';

import 'package:agent_harness/model/approval_mode.dart';
import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/conversation/conversation_root.dart';
import 'package:agent_harness/ui/conversation/plan_review_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_turn_source.dart';

void main() {
  group('the panel', () {
    var approved = 0;
    var declined = 0;
    var discussed = 0;

    Future<void> pump(WidgetTester tester, String plan) => tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: ListView(
            children: [
              PlanReviewPanel(
                plan: plan,
                onApprove: () => approved++,
                onDecline: () => declined++,
                onDiscuss: () => discussed++,
              ),
            ],
          ),
        ),
      ),
    );

    setUp(() {
      approved = 0;
      declined = 0;
      discussed = 0;
    });

    testWidgets('paints the header, the body, and all three actions', (
      tester,
    ) async {
      await pump(tester, '# Ship it\n\n- one\n- two');
      await tester.pumpAndSettle();

      expect(find.text('Plan review'), findsOneWidget);
      expect(find.text('Ship it', findRichText: true), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Discuss'), findsOneWidget);
    });

    testWidgets('each action fires once and only once', (tester) async {
      await pump(tester, '# once');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Approve'));
      await tester.pump();
      // The latch: a second tap on any action must not re-fire.
      await tester.tap(find.text('Decline'), warnIfMissed: false);
      await tester.tap(find.text('Discuss'), warnIfMissed: false);
      await tester.pump();

      expect(approved, 1);
      expect(declined, 0);
      expect(discussed, 0);
    });

    testWidgets('a new plan text re-arms the latch', (tester) async {
      await pump(tester, '# first');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Decline'));
      await tester.pump();
      expect(declined, 1);

      // The same widget instance with a new plan: a new review.
      await pump(tester, '# second');
      await tester.pump();
      await tester.tap(find.text('Decline'));
      await tester.pump();
      expect(declined, 2);
    });
  });

  group('the host', () {
    late FakeTurnSource source;
    late StreamingTail tail;
    late ConversationController controller;

    setUp(() {
      source = FakeTurnSource();
      tail = StreamingTail();
      controller = ConversationController(runtime: source, tail: tail);
      controller.approvalMode = ApprovalMode.plan;
    });

    tearDown(() {
      controller.dispose();
      tail.dispose();
    });

    Future<void> pump(WidgetTester tester) {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp(
          theme: dswThemeData(Brightness.light),
          home: Scaffold(body: ConversationRoot(conversation: controller, tail: tail)),
        ),
      );
    }

    /// Delivers a finished turn whose only tool call was a successful `plan`.
    Future<void> deliverPlan(WidgetTester tester, String plan) async {
      unawaited(controller.send('plan it'));
      await tester.pump();
      source.emit(
        const ToolCallRequested(ref: 'r1', name: 'plan', arguments: {}),
      );
      source.emit(ToolCallSucceeded(ref: 'r1', output: {'ok': true, 'plan': plan}));
      source.emit(const TurnFinished(outcome: TurnOutcome.completed, sessionId: 's1'));
      await source.close();
      await tester.pumpAndSettle();
    }

    /// Ends whatever turn the last answer started, so no ticker outlives the
    /// test that armed it.
    Future<void> finish(WidgetTester tester) async {
      source.emit(const TurnFinished(outcome: TurnOutcome.completed));
      await source.close();
      await tester.pumpAndSettle();
    }

    testWidgets('a plan under plan mode takes the composer\'s seat', (
      tester,
    ) async {
      await pump(tester);
      // Before any plan: the composer is there, the card is not.
      expect(find.text('Ask anything, or describe a task'), findsOneWidget);
      expect(find.text('Plan review'), findsNothing);

      await deliverPlan(tester, '# the plan');

      expect(find.text('Plan review'), findsOneWidget);
      expect(find.text('the plan', findRichText: true), findsOneWidget);
      expect(find.text('Ask anything, or describe a task'), findsNothing);
    });

    testWidgets('no plan, or not plan mode, means no card', (tester) async {
      await pump(tester);
      // Plan mode but a turn with no plan tool call.
      unawaited(controller.send('just talk'));
      await tester.pump();
      source.emit(const TextDelta(text: 'hi', messageIndex: 0));
      source.emit(const TurnFinished(outcome: TurnOutcome.completed, sessionId: 's1'));
      await source.close();
      await tester.pumpAndSettle();
      expect(find.text('Plan review'), findsNothing);

      // A plan in the transcript, but the mode is ask.
      controller.approvalMode = ApprovalMode.ask;
      await deliverPlan(tester, '# the plan');
      expect(find.text('Plan review'), findsNothing);
    });

    testWidgets('approve leaves plan mode and tells the agent to proceed', (
      tester,
    ) async {
      await pump(tester);
      await deliverPlan(tester, '# the plan');

      await tester.tap(find.text('Approve'));
      await tester.pump();

      expect(controller.approvalMode, ApprovalMode.ask);
      // The message rode to the agent through the normal send path.
      expect(source.turns, 2);
      expect(find.text('Plan review'), findsNothing);
      // The composer is back, saying the mode it now is.
      expect(find.text('Ask every time'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('decline keeps plan mode and sends the agent back', (
      tester,
    ) async {
      await pump(tester);
      await deliverPlan(tester, '# the plan');

      await tester.tap(find.text('Decline'));
      await tester.pump();

      expect(controller.approvalMode, ApprovalMode.plan);
      expect(source.turns, 2);
      expect(find.text('Plan review'), findsNothing);
      await finish(tester);
    });

    testWidgets('discuss hands the seat back without sending', (tester) async {
      await pump(tester);
      await deliverPlan(tester, '# the plan');

      await tester.tap(find.text('Discuss'));
      await tester.pumpAndSettle();

      expect(source.turns, 1);
      expect(controller.approvalMode, ApprovalMode.plan);
      expect(find.text('Plan review'), findsNothing);
      expect(find.text('Ask anything, or describe a task'), findsOneWidget);
    });

    testWidgets('a discussed plan does not come back on the next rebuild', (
      tester,
    ) async {
      await pump(tester);
      await deliverPlan(tester, '# the plan');

      await tester.tap(find.text('Discuss'));
      await tester.pumpAndSettle();
      expect(find.text('Plan review'), findsNothing);

      // Any rebuild (a controller notification, a resize) must not resurrect
      // the answered plan: the settlement was for this text specifically.
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Plan review'), findsNothing);
    });

    testWidgets('a NEW plan after a discussed one reviews again', (
      tester,
    ) async {
      await pump(tester);
      await deliverPlan(tester, '# first');
      await tester.tap(find.text('Discuss'));
      await tester.pumpAndSettle();

      await deliverPlan(tester, '# second');
      expect(find.text('Plan review'), findsOneWidget);
      expect(find.text('second', findRichText: true), findsOneWidget);
    });
  });
}
