// ADR-0061 guards: the summarizer's source text has caps and skips tools,
// the summary block rides the injected-part predicate, the controller's
// compress flow guards and resets, and the composer offers the command
// exactly when the host can serve it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/genkit/instructions.dart';
import 'package:planstar/model/approval_mode.dart';
import 'package:planstar/model/context_compression.dart';
import 'package:planstar/model/conversation.dart';
import 'package:planstar/model/turn_event.dart';
import 'package:planstar/state/conversation_controller.dart';
import 'package:planstar/state/streaming_tail.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/conversation/composer.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadSonner, ShadTheme;

import 'fake_turn_source.dart';

void main() {
  group('compressionTranscriptOf', () {
    test('joins user and assistant turns, skipping tool nodes', () {
      final transcript = compressionTranscriptOf([
        const UserMessageNode(id: 'u1', text: 'Fix the flaky test.'),
        ToolCallNode(
          id: 't1',
          name: 'bash',
          arguments: const {'command': 'flutter test'},
          status: ToolStatus.succeeded,
          startedAt: DateTime.now(),
        ),
        const AssistantMessageNode(id: 'a1', text: 'It was a race.'),
      ]);
      expect(
        transcript,
        'user: Fix the flaky test.\nassistant: It was a race.',
      );
    });

    test('clips an overflowing message instead of dropping it', () {
      final transcript = compressionTranscriptOf([
        UserMessageNode(id: 'u1', text: 'x' * (compressionPerMessageCap + 500)),
      ]);
      expect(transcript, contains('…(truncated)'));
      expect(transcript.length, lessThan(compressionPerMessageCap + 100));
    });

    test('stops at the total cap and says so', () {
      final transcript = compressionTranscriptOf([
        for (var i = 0; i < 40; i++)
          UserMessageNode(id: 'u$i', text: 'message $i ${'y' * 400}'),
      ], totalCap: 12000);
      expect(transcript, contains('…(earlier turns omitted)'));
      expect(transcript.length, lessThan(12100));
    });

    test('an empty or tool-only transcript is empty', () {
      expect(compressionTranscriptOf([]), isEmpty);
      expect(
        compressionTranscriptOf([
          ToolCallNode(
            id: 't1',
            name: 'bash',
            arguments: const {},
            status: ToolStatus.succeeded,
            startedAt: DateTime.now(),
          ),
        ]),
        isEmpty,
      );
    });
  });

  group('the summary block', () {
    test('is tagged, closed, and read as injected', () {
      final block = conversationSummaryBlock('The user is fixing a race.');
      expect(block.startsWith(conversationSummaryOpenTag), isTrue);
      expect(block.endsWith('</conversation-summary>'), isTrue);
      expect(isInjectedPart(block), isTrue);
    });

    test('the predicate still knows the older blocks', () {
      expect(isInjectedPart('<project-instructions>\nDo things.'), isTrue);
      expect(isInjectedPart('<workspace-reference path="a.md">'), isTrue);
      expect(isInjectedPart('just words'), isFalse);
    });
  });

  group('controller', () {
    late FakeTurnSource source;
    late StreamingTail tail;
    late ConversationController controller;
    late List<bool> compressingSeen;

    setUp(() {
      source = FakeTurnSource();
      tail = StreamingTail();
      controller = ConversationController(runtime: source, tail: tail);
      compressingSeen = [];
      controller.addListener(
        () => compressingSeen.add(controller.isCompressing),
      );
    });

    tearDown(() {
      controller.dispose();
      tail.dispose();
    });

    /// One finished turn, so the transcript has a user and an assistant turn.
    Future<void> oneTurn() async {
      controller.send('hello');
      await Future<void>.delayed(Duration.zero);
      source.emit(const TextDelta(text: 'Hi there.', messageIndex: 0));
      source.emit(const TurnFinished(outcome: TurnOutcome.completed));
      await Future<void>.delayed(Duration.zero);
    }

    test('compress summarizes, starts fresh, arms the summary', () async {
      await oneTurn();
      final nodesBefore = controller.nodes.length;

      final compressing = controller.compressContext();
      await Future<void>.delayed(Duration.zero);
      await compressing;

      // The summarizer saw the conversation, not a projection of it.
      expect(source.summarizedTranscripts.single, contains('hello'));
      expect(source.summarizedTranscripts.single, contains('Hi there.'));
      // The fresh session happened (the transcript reset) and the summary
      // was armed after it — the order the runtime's clearing depends on.
      expect(controller.nodes, hasLength(nodesBefore - nodesBefore));
      expect(source.pendingSummaries, ['a summary']);
      expect(controller.isCompressing, isFalse);
      expect(compressingSeen.contains(true), isTrue);
    });

    test('a summarizer failure leaves the conversation untouched', () async {
      await oneTurn();
      source.summaryResult = Exception('window exceeded');

      await expectLater(controller.compressContext(), throwsException);

      expect(controller.nodes, isNotEmpty);
      expect(source.pendingSummaries, isEmpty);
      expect(controller.isCompressing, isFalse);
    });

    test('a pending approval or a busy turn says no', () async {
      controller.send('hello');
      await Future<void>.delayed(Duration.zero);
      source.emit(
        const ApprovalRequired(
          ApprovalRequest(ref: 'r', toolName: 'bash', arguments: {}),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(await controller.compressContext(), isFalse);
      expect(source.summarizedTranscripts, isEmpty);
    });
  });

  group('composer /compress', () {
    Future<void> pump(
      WidgetTester tester, {
      Future<void> Function()? onCompress,
    }) => tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),

        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Brightness.light),
          child: ShadSonner(child: child!),
        ),
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: Composer(
            hero: false,
            busy: false,
            blocked: false,
            approvalMode: ApprovalMode.ask,
            onSubmit: (text, images, delivery) {},
            onStop: () {},
            onCompress: onCompress,
          ),
        ),
      ),
    );

    testWidgets('the command fires the host callback', (tester) async {
      var compressed = 0;
      await pump(tester, onCompress: () async => compressed++);
      await tester.enterText(find.byType(EditableText), '/comp');
      await tester.pump();
      await tester.tap(find.text('Compress this conversation'));
      await tester.pump();
      expect(compressed, 1);
    });

    testWidgets('no callback, no command', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(EditableText), '/');
      await tester.pump();
      expect(find.text('Compress this conversation'), findsNothing);
      expect(find.text('Start a new session'), findsNothing);
    });
  });
}
