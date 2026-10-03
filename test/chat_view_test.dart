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
//
// The last two tests are of a different kind: they measure rectangles. Both came
// out of the production audit reading pixels off one screenshot, and the only
// way to settle a claim like that is to ask the rendered column for its own
// geometry at fixed viewport widths.

import 'dart:async';

import 'package:agent_harness/l10n/locales.dart';
import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/greeting.dart';
import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_alias.dart';
import 'package:agent_harness/theme/dsw_shape.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/conversation/conversation_root.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'amplified_text_probe.dart';
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
  ///
  /// The amplified step is composed in `MaterialApp.builder`, not under `home:`:
  /// a `MediaQuery` below the Navigator never reaches an overlay route, and the
  /// column's own popups are part of what the ruler is here to measure.
  Future<void> pump(
    WidgetTester tester, {
    bool stillness = false,
    double step = 1.0,
  }) {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        // Both steps are `copyWith` on what is already there, and the
        // disableAnimations layer sits BELOW the ruler's own `MediaQuery`: a
        // fresh `MediaQueryData(disableAnimations: …)` under `home:` replaces the
        // whole data object — `textScaler` included — and had this harness been
        // written that way the amplified faces would have measured the column at
        // 1.0 while reporting a pass.
        builder: (context, child) => AmplifiedText(
          step: step,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: stillness),
              child: child!,
            ),
          ),
        ),
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: ConversationRoot(conversation: controller, tail: tail),
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

  testWidgets('the hero headline says the hour, and only that', (tester) async {
    // H1 of `docs/hero-parity-zcode-2026-10-03.md`: the reference's empty-state
    // header is the mark plus ONE greeting, picked from six time bands
    // (`ConversationDraftEmptyState.tsx:29-35`). This app painted a fixed title
    // and a second line under it; neither has a counterpart there, so both went
    // along with their dictionary keys.
    await pump(tester);

    expect(
      find.text(enStrings[Greetings.key(Greetings.of(DateTime.now()))]!),
      findsOneWidget,
    );
    expect(find.text('Ask anything'), findsNothing);
    expect(
      find.text('Ask anything, or open a workspace to begin'),
      findsNothing,
    );
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

  // The column's own chrome under an amplified system.
  //
  // `block_primitives_test` measures the seven blocks in isolation; what no
  // block test ever builds is the row around them — the mid-turn activity strip
  // (one-line chrome by construction), the seat caption the fading band sits
  // over, and the composer this root mounts below. Two steps, because one step
  // cannot certify a seat: a 36px line is exactly one line of 14/20 at 1.8.
  group('amplified text', () {
    for (final (label, step) in const [
      ('1.8x', amplifiedTextStep),
      ('2.2x', nextTextStep),
    ]) {
      testWidgets('the column keeps its chrome and its cards ($label)', (
        tester,
      ) async {
        await pump(tester, step: step);
        expect(textDefects(tester), isEmpty, reason: 'the hero column');

        await startTurn(tester, 'hi');
        // Asserted before measured, and BEFORE the first delta: the strip is a
        // waiting-for-the-first-token row, so once a TextDelta lands it is gone
        // and the next `textDefects` would be measuring an empty column while
        // calling it the activity row.
        expect(find.text('Deep diving...'), findsOneWidget);
        expect(
          textDefects(tester),
          isEmpty,
          reason: 'the mid-turn activity row',
        );

        source.emit(const TextDelta(text: 'Thinking it over', messageIndex: 0));
        await deliver(tester);
        await reveal(tester);
        expect(answer('Thinking it over'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the streaming tail');

        source.emit(
          const ToolCallRequested(
            ref: 'r1',
            name: 'read',
            arguments: {'file_path': '/tmp/a-fairly-long-path-to-a-file.txt'},
          ),
        );
        await deliver(tester);
        expect(find.text('Read'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'a tool card in the flow');

        source.emit(const ToolCallSucceeded(ref: 'r1', output: 'contents'));
        await finish(tester);
        expect(textDefects(tester), isEmpty, reason: 'the settled column');
      });
    }
  });

  // Audit §3-C read the screenshot's "body hugs the right, blank strip on the
  // left" as an off-centre column and asked for a repro. Here it is, and the
  // column is not off-centre: at 1400/1152/700 the card lands on the middle of
  // the width it is given, the reply starts one inset inside its left edge and
  // the aside ends one inset inside its right edge. The strip belongs to the
  // aside, whose own cap is `min(525px, 82%)` of the column — 223px of the 748
  // column at full width, and the percentage takes over below it (at 700 the
  // column is 636 and the bubble is 521.5). Guarding the two axes, not the
  // pixels, is what keeps a future `Center` from quietly becoming one-sided.
  testWidgets('the transcript and the aside share the card\'s two axes', (
    tester,
  ) async {
    final longDraft = ('word ' * 200).trimRight();
    for (final width in const [1400.0, 1152.0, 700.0]) {
      final probeSource = FakeTurnSource();
      final probeTail = StreamingTail();
      final probeController = ConversationController(
        runtime: probeSource,
        tail: probeTail,
      );
      addTearDown(probeController.dispose);
      addTearDown(probeTail.dispose);
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: dswThemeData(Brightness.light),
          home: Scaffold(
            body: ConversationRoot(
              conversation: probeController,
              tail: probeTail,
            ),
          ),
        ),
      );
      unawaited(probeController.send(longDraft));
      await tester.pump();
      probeSource.emit(const TextDelta(text: 'Hello there', messageIndex: 0));
      await tester.idle();
      await tester.pump();
      probeSource.emit(
        const TurnFinished(outcome: TurnOutcome.completed, sessionId: 's1'),
      );
      await probeSource.close();
      await tester.pumpAndSettle();

      // The input card is the one float-radius box in this column, and the
      // user's pill is the only one in the transcript.
      final card = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).borderRadius ==
                  BorderRadius.circular(DswShape.float),
        ),
      );
      // The aside is found by the colour that makes it an aside, not by its
      // corner: ADR-0034 moved the bubble off `pill` (a short message clamped to
      // a disc), and a finder that keys off the radius would break for a reason
      // this test is not asserting.
      final aside = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == DswAlias.light.bubble,
        ),
      );
      final reply = tester.getRect(answer('Hello there'));
      final inset = composerCardWidthInset / 2;
      final column = card.width - composerCardWidthInset;

      expect(card.center.dx, width / 2, reason: 'at $width');
      expect(reply.left, card.left + inset, reason: 'at $width');
      expect(aside.right, card.right - inset, reason: 'at $width');
      expect(
        aside.width,
        column * 0.82 < 525 ? closeTo(column * 0.82, 0.01) : 525.0,
        reason: 'the aside takes min(525px, 82%) of the column at $width',
      );
    }
  });

  // Audit §3-B. The band at the top of the seat is see-through on purpose — that
  // is how a reply dissolves as it scrolls under the composer. The stats caption
  // used to be the seat's first row, i.e. painted *inside* that band, so any
  // scroll position that left a reply line under the seat drew two texts on top
  // of each other. The user's screenshot shows exactly that: the caption's CJK
  // glyphs across `SDK returns {data, error}`.
  testWidgets('the seat caption stays below the see-through band', (
    tester,
  ) async {
    await pump(tester);
    await startTurn(tester, 'hi');
    await finish(tester);

    // The caption is the only text in this column that says "turns" (the fake
    // source emits no deltas here). Its nearest CustomPaint ancestor is the
    // seat's scrim — `Material` paints one too, and ancestors come back
    // innermost-first, so take the first and pin it by size: the scrim is the
    // seat, not the window.
    final caption = find.textContaining('turns', findRichText: true);
    expect(caption, findsOneWidget);
    final band = find
        .ancestor(of: caption, matching: find.byType(CustomPaint))
        .first;
    expect(tester.getSize(band).height, lessThan(600));

    expect(
      tester.getRect(caption).top - tester.getRect(band).top,
      greaterThanOrEqualTo(composerMaskHeight),
      reason: 'inside the band the transcript is still partly visible',
    );
  });
}
