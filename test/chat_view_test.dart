// The conversation column, actually rendered.
//
// This file exists because of a bug the other 75 tests could not see: the
// mid-turn activity row asked its `State` for two tickers while mixing in
// `SingleTickerProviderStateMixin`, and one of them was created lazily inside
// `build`. Nothing threw until a real frame was painted with a turn in flight —
// which no unit test ever did.
//
// So it mounts `ConversationRoot` rather than `ChatView`: the rebuild on a
// controller notification lives in the root's `ListenableBuilder`, and a harness
// that supplies its own would be testing the harness. The contract is coarse and
// blunt — walk the column through every state a turn puts it in, pump real
// frames, and assert nothing was thrown.

import 'dart:async';

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/conversation/conversation_root.dart';
import 'package:flutter/material.dart';
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

  /// Pumps the column wide enough that the 748px content width, not the viewport,
  /// is what decides the layout.
  Future<void> pump(WidgetTester tester, {bool stillness = false}) {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(disableAnimations: stillness),
            child: ConversationRoot(conversation: controller, tail: tail),
          ),
        ),
      ),
    );
  }

  /// Starts a turn and lets the frame that opens it settle.
  Future<void> startTurn(WidgetTester tester, String text) async {
    unawaited(controller.send(text));
    await tester.pump();
  }

  /// Lets an emitted event reach the controller and then the screen.
  ///
  /// The stream delivers on a microtask, and `pump` alone does not drain those —
  /// `idle` is what hands the event over, and the pump after it is what paints the
  /// result. `pumpAndSettle` is not an option mid-turn: the activity row's sweep
  /// repeats forever, so there is nothing to settle to.
  Future<void> deliver(WidgetTester tester) async {
    await tester.idle();
    await tester.pump();
  }

  /// Ends the turn so the activity row unmounts and its tickers are disposed.
  /// Left running, the binding reports them as leaked instead of reporting
  /// whatever the test was actually about.
  Future<void> finish(
    WidgetTester tester, {
    TurnOutcome outcome = TurnOutcome.completed,
  }) async {
    source.emit(TurnFinished(outcome: outcome, sessionId: 's1'));
    await source.close();
    await tester.pumpAndSettle();
  }

  /// Assistant text goes through `GptMarkdown`, which paints a `RichText` rather
  /// than a `Text`, so the finder has to be told to look inside it.
  Finder answer(String text) => find.textContaining(text, findRichText: true);

  /// Runs the reveal out.
  ///
  /// A streaming message is not on screen the frame it arrives: the renderer
  /// uncovers it at 300 characters a second, so the first frame after a delta
  /// shows nothing at all. This is long enough for any of the short strings here.
  Future<void> reveal(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 300));

  testWidgets('the hero phase paints with nothing to show', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Deep diving...'), findsNothing);
  });

  testWidgets('the mid-turn activity row mounts and keeps animating', (
    tester,
  ) async {
    await pump(tester);
    await startTurn(tester, 'hi');

    // Mounting this row is what used to throw: it carries both tickers.
    expect(find.text('Deep diving...'), findsOneWidget);
    // And a ticker built during `build` throws on the second build, not the first.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    await finish(tester);
    expect(find.text('Deep diving...'), findsNothing);
  });

  // The elapsed clock is not asserted here. It reads wall time on purpose — a
  // turn's duration should not stall while the window is in the background, which
  // is exactly what a ticker's own elapsed count would do — and `pump(duration)`
  // only advances the test's fake clock. Waiting 15 real seconds for it is worse
  // than leaving it to the manual pass.

  testWidgets('reduced motion stills the sweep and still paints', (
    tester,
  ) async {
    await pump(tester, stillness: true);
    await startTurn(tester, 'hi');

    expect(find.text('Deep diving...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);

    await finish(tester);
  });

  testWidgets('a streamed answer survives being settled', (tester) async {
    await pump(tester);
    await startTurn(tester, 'hi');

    source.emit(const TextDelta(text: 'Hello there', messageIndex: 0));
    await deliver(tester);
    await reveal(tester);
    expect(answer('Hello there'), findsOneWidget);

    // The same text has to still be on screen once the tail is frozen into the
    // node — a different widget rendering the same content.
    await finish(tester);
    expect(answer('Hello there'), findsOneWidget);
  });

  testWidgets('a tool card and its approval prompt paint', (tester) async {
    await pump(tester);
    await startTurn(tester, 'write it');

    source.emit(
      const ToolCallRequested(
        ref: 'r1',
        name: 'write',
        arguments: {'file_path': '/tmp/x.txt', 'content': 'hi'},
      ),
    );
    await deliver(tester);
    // The card shows the tool's friendly title and a summary of its `path`, not
    // the raw tool name.
    expect(find.text('Write'), findsOneWidget);
    expect(find.textContaining('/tmp/x.txt'), findsWidgets);

    source.emit(
      const ApprovalRequired(
        ApprovalRequest(
          ref: 'r1',
          toolName: 'write',
          arguments: {'file_path': '/tmp/x.txt', 'content': 'hi'},
          details: {
            'kind': 'write',
            'path': '/tmp/x.txt',
            'bytes': 2,
            'exists': false,
          },
        ),
      ),
    );
    await finish(tester, outcome: TurnOutcome.awaitingApproval);

    expect(controller.pendingApproval, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed turn paints its error', (tester) async {
    await pump(tester);
    await startTurn(tester, 'hi');

    source.emit(
      const TurnFinished(
        outcome: TurnOutcome.failed,
        errorMessage: 'No API key set.',
      ),
    );
    await source.close();
    await tester.pumpAndSettle();

    expect(find.textContaining('No API key set.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
