// The sub-agent tab, over a hand-driven turn.
//
// What is worth a widget test here is the projection the pure helpers cannot
// see: that a `delegate_to_*` call in the transcript lands as a topology card
// (agent chip, task, status), that the dock follows the selection, that a
// running card's kill takes two clicks and stops the turn, and that the empty
// page explains itself. The vocabulary — names, dots, durations — is pinned
// directly, since the source's equivalents live beside them in
// `subagent-jobs.ts` and the shape is the contract.

import 'dart:async';
import 'dart:io';

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/sidebar/model/sidebar_tab.dart';
import 'package:agent_harness/sidebar/state/workbench_controller.dart';
import 'package:agent_harness/sidebar/state/workbench_store.dart';
import 'package:agent_harness/sidebar/ui/tabs/subagent_tab.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/primitives/state_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_turn_source.dart';

void main() {
  group('the vocabulary', () {
    test('agentNameOf strips the delegation prefix and keeps the rest', () {
      expect(
        agentNameOf('delegate_to_general-purpose'),
        'general-purpose',
      );
      expect(agentNameOf('glob'), 'glob');
    });

    test('a delegation is recognised by its tool name alone', () {
      const running = ToolCallNode(
        id: 'n1',
        name: 'delegate_to_general-purpose',
        arguments: {},
        status: ToolStatus.running,
      );
      const other = ToolCallNode(
        id: 'n2',
        name: 'read',
        arguments: {},
        status: ToolStatus.running,
      );
      expect(isDelegation(running), isTrue);
      expect(isDelegation(other), isFalse);
    });

    test('each status maps to one dot and one label', () {
      expect(dotStateOf(ToolStatus.running), StateDotState.ongoing);
      expect(dotStateOf(ToolStatus.awaitingApproval), StateDotState.ongoing);
      expect(dotStateOf(ToolStatus.succeeded), StateDotState.done);
      expect(dotStateOf(ToolStatus.failed), StateDotState.error);
      expect(dotStateOf(ToolStatus.denied), StateDotState.warning);
      expect(statusLabelOf(ToolStatus.running), 'Running');
      expect(statusLabelOf(ToolStatus.awaitingApproval), 'Running');
      expect(statusLabelOf(ToolStatus.succeeded), 'Done');
      expect(statusLabelOf(ToolStatus.failed), 'Failed');
      expect(statusLabelOf(ToolStatus.denied), 'Declined');
    });

    test('the middleware response is the only output the dock reads', () {
      expect(delegationResponseOf({'response': 'found it'}), 'found it');
      expect(delegationResponseOf({'artifacts': []}), isNull);
      expect(delegationResponseOf('plain text'), isNull);
      expect(delegationResponseOf(null), isNull);
    });

    test('a task preview is flattened, truncated at 80, or empty', () {
      expect(taskPreviewOf({'task': 'find\n\nthe   tests'}), 'find the tests');
      expect(taskPreviewOf({'task': 'x' * 100}).length, 81);
      expect(taskPreviewOf({'task': 'x' * 100}).endsWith('…'), isTrue);
      expect(taskPreviewOf({}), isEmpty);
      expect(taskPreviewOf({'task': '   '}), isEmpty);
    });

    test('durations read in at most two adjacent units', () {
      expect(formatDuration(const Duration(seconds: 0)), '0s');
      expect(formatDuration(const Duration(seconds: 45)), '45s');
      expect(formatDuration(const Duration(minutes: 1)), '1m 0s');
      expect(formatDuration(const Duration(minutes: 2, seconds: 5)), '2m 5s');
      expect(formatDuration(const Duration(hours: 1, minutes: 1)), '1h 1m');
    });

    test('a failure line is its first line only', () {
      const node = ToolCallNode(
        id: 'n1',
        name: 'delegate_to_general-purpose',
        arguments: {},
        status: ToolStatus.failed,
        errorMessage: 'boom\ntraceback',
      );
      expect(failureLineOf(node), 'boom');
    });

    test('the clock needs a start stamp, and stops at the finish', () {
      const bare = ToolCallNode(
        id: 'n1',
        name: 'delegate_to_general-purpose',
        arguments: {},
        status: ToolStatus.succeeded,
      );
      expect(elapsedOf(bare), isNull);

      final start = DateTime.now();
      final running = bare.copyWith(
        status: ToolStatus.running,
        startedAt: start,
      );
      expect(elapsedOf(running), isNotNull);

      final done = running.copyWith(
        status: ToolStatus.succeeded,
        finishedAt: start.add(const Duration(seconds: 3)),
      );
      expect(elapsedOf(done), const Duration(seconds: 3));
    });
  });

  group('the tab', () {
    late Directory support;
    late WorkbenchController workbench;
    late FakeTurnSource source;
    late StreamingTail tail;
    late ConversationController conversation;

    setUp(() {
      support = Directory.systemTemp.createTempSync('dsh_subagent_tab_');
      workbench = WorkbenchController(store: WorkbenchStore.open(support));
      source = FakeTurnSource();
      tail = StreamingTail();
      conversation = ConversationController(runtime: source, tail: tail);
    });

    tearDown(() {
      workbench.dispose();
      conversation.dispose();
      tail.dispose();
      support.deleteSync(recursive: true);
    });

    /// The tab on its own, the way a unit harness would: no pane, no strip.
    /// The tab is therefore not its pane's active tab, which also keeps the
    /// per-second clock from starting — nothing here waits on it.
    Future<void> pump(WidgetTester tester) => tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: SubagentHost(
              conversation: conversation,
              child: SubagentTab(
                workbench: workbench,
                tab: const SidebarTab(
                  id: 'subagent:1',
                  type: BuiltinTabType.subagent,
                  title: 'Sub-agents',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    /// Starts a turn and lets the frame that opens it settle. The send future
    /// stays pending until the turn finishes, which is why it is unawaited.
    Future<void> startTurn(WidgetTester tester) async {
      unawaited(conversation.send('go'));
      await tester.pump();
    }

    /// Emits a running delegation of the general-purpose agent and waits for
    /// the projection to pick it up. The stream delivers on a microtask, which
    /// `pump` alone does not drain — same reason as details_panel_test.
    Future<void> delegate(WidgetTester tester) async {
      source.emit(
        const ToolCallRequested(
          ref: 'r1',
          name: 'delegate_to_general-purpose',
          arguments: {'task': 'Find\n  the   tests'},
        ),
      );
      await tester.idle();
      await tester.pump();
    }

    /// Settles a turn with a finish event.
    Future<void> finishTurn(WidgetTester tester) async {
      source.emit(const TurnFinished(outcome: TurnOutcome.completed));
      await tester.idle();
      await tester.pump();
    }

    testWidgets('an empty topology is the root card and the empty state', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text('Main agent'), findsOneWidget);
      expect(find.text('Idle'), findsOneWidget);
      expect(find.text('No sub-agents yet'), findsOneWidget);
      expect(find.text('Sub-agents'), findsOneWidget);
      // No cards, so no count badge either.
      expect(find.textContaining('subagent'), findsNothing);
    });

    testWidgets('a delegation lands as a card with agent, task and status', (
      tester,
    ) async {
      await pump(tester);
      await startTurn(tester);
      await delegate(tester);

      // The agent chip, the flattened task, and the status line.
      expect(find.text('general-purpose'), findsOneWidget);
      expect(find.text('Find the tests'), findsOneWidget);
      // The root card's status is the only bare 'Running' — the delegation's
      // is always paired with its elapsed time.
      expect(find.text('Running'), findsOneWidget);
      expect(find.textContaining('Running · '), findsOneWidget);
      // One live card, announced in the header's badge.
      expect(find.text('1 subagent · 1 running'), findsOneWidget);
      // A live card carries the kill affordance.
      expect(find.byIcon(LucideIcons.square), findsOneWidget);
      // Nothing is selected, so no dock.
      expect(find.text('Thinking…'), findsNothing);
    });

    testWidgets('a settled delegation trades the kill for a duration', (
      tester,
    ) async {
      await pump(tester);
      await startTurn(tester);
      await delegate(tester);
      source.emit(
        const ToolCallSucceeded(ref: 'r1', output: {'response': 'In lib/.'}),
      );
      await finishTurn(tester);

      expect(find.byIcon(LucideIcons.square), findsNothing);
      expect(find.textContaining('Done · '), findsOneWidget);
      expect(find.text('1 subagent'), findsOneWidget);
      expect(find.text('Idle'), findsOneWidget);
    });

    testWidgets('the dock follows the selection and shows the response', (
      tester,
    ) async {
      await pump(tester);
      await startTurn(tester);
      await delegate(tester);
      source.emit(
        const ToolCallSucceeded(ref: 'r1', output: {'response': 'In lib/.'}),
      );
      await finishTurn(tester);

      await tester.tap(find.text('Find the tests'));
      await tester.pump();
      expect(find.text('In lib/.'), findsOneWidget);
      // The dock header repeats the agent, in the code face.
      expect(find.text('general-purpose'), findsNWidgets(2));

      // Tapping the card again closes the dock; the root card does too.
      await tester.tap(find.text('Find the tests'));
      await tester.pump();
      expect(find.text('In lib/.'), findsNothing);

      await tester.tap(find.text('Find the tests'));
      await tester.pump();
      expect(find.text('In lib/.'), findsOneWidget);
      await tester.tap(find.text('Main agent'));
      await tester.pump();
      expect(find.text('In lib/.'), findsNothing);
    });

    testWidgets('a running selection docks as thinking, a failure as its first line', (
      tester,
    ) async {
      await pump(tester);
      await startTurn(tester);
      await delegate(tester);

      await tester.tap(find.text('Find the tests'));
      await tester.pump();
      expect(find.text('Thinking…'), findsOneWidget);

      source.emit(
        const ToolCallFailed(ref: 'r1', message: 'boom\ntraceback'),
      );
      source.emit(const TurnFinished(outcome: TurnOutcome.failed));
      await tester.idle();
      await tester.pump();
      expect(find.text('boom'), findsOneWidget);
      expect(find.textContaining('Failed · '), findsOneWidget);
    });

    testWidgets('the kill takes two clicks and stops the turn', (tester) async {
      await pump(tester);
      await startTurn(tester);
      await delegate(tester);

      await tester.tap(find.byIcon(LucideIcons.square));
      await tester.pump();
      // The first click only arms: a confirm chip replaces the icon.
      expect(find.text('Confirm'), findsOneWidget);
      expect(source.stopCalls, 0);

      await tester.tap(find.text('Confirm'));
      await tester.pump();
      expect(source.stopCalls, 1);
      expect(conversation.isBusy, isFalse);
      expect(find.text('Idle'), findsOneWidget);

      // Retire the arm timer the first click scheduled, so the test ends with
      // nothing pending.
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
