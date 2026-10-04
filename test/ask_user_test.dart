// ADR-0059 guards: the tool input's bounds, the interrupt payload's parse,
// the controller's answer hand-off, and the panel's answer form.
//
// The controller test is the spine: ApprovalRequired(kind: ask_user) must
// clear on submit and carry the answers to the runtime verbatim — that hand-
// off is the whole feature; everything else is chrome around it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/genkit/tools.dart';
import 'package:planstar/model/ask_user.dart';
import 'package:planstar/model/conversation.dart';
import 'package:planstar/model/turn_event.dart';
import 'package:planstar/state/conversation_controller.dart';
import 'package:planstar/state/streaming_tail.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/conversation/ask_user_panel.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadInput, ShadTheme;

import 'fake_turn_source.dart';

void main() {
  group('askUserQuestionsOf', () {
    test('parses well-formed questions', () {
      final questions = askUserQuestionsOf({
        'questions': [
          {
            'question': 'Which provider?',
            'options': ['DeepSeek', 'OpenAI'],
          },
          {'question': 'Any context?', 'multi': true},
        ],
      });
      expect(questions, hasLength(2));
      expect(questions[0].options, ['DeepSeek', 'OpenAI']);
      expect(questions[0].multi, isFalse);
      expect(questions[1].multi, isTrue);
    });

    test('enforces the schema bounds by clipping, not failing', () {
      final questions = askUserQuestionsOf({
        'questions': [
          for (var i = 0; i < 6; i++) {'question': 'q$i'},
        ],
      });
      // More than four questions: the first four are the ones asked.
      expect(questions, hasLength(AskUserQuestion.maxQuestions));
      final clipped = askUserQuestionsOf({
        'questions': [
          {
            'question': 'q',
            'options': [for (var i = 0; i < 7; i++) 'o$i'],
          },
        ],
      });
      expect(clipped.single.options, hasLength(AskUserQuestion.maxOptions));
    });

    test('drops junk entries and answers nothing when nothing is left', () {
      expect(
        askUserQuestionsOf({
          'questions': [
            {'question': '   '},
            'a bare string',
            {'no_question': true},
          ],
        }),
        isEmpty,
      );
      expect(askUserQuestionsOf(null), isEmpty);
      expect(askUserQuestionsOf({'questions': 'not-a-list'}), isEmpty);
      expect(askUserQuestionsOf({}), isEmpty);
    });
  });

  group('AskUserAnswer payload', () {
    test('rides the tool-result envelope with skips marked', () {
      final payload = AskUserAnswer.payload([
        const AskUserAnswer(question: 'Which provider?', values: ['DeepSeek']),
        const AskUserAnswer(question: 'Why?', values: [], custom: 'because'),
        AskUserAnswer(question: 'When?', values: const [], skipped: true),
      ]);
      expect(payload['ok'], isTrue);
      final answers = payload['answers']! as List<Object?>;
      expect(answers, hasLength(3));
      expect(answers[0], containsPair('values', ['DeepSeek']));
      expect(answers[1], containsPair('custom', 'because'));
      expect(answers[2], containsPair('skipped', true));
      // An empty answer is not written; absence is the only absence.
      expect(
        (answers[2] as Map<Object?, Object?>).containsKey('values'),
        isTrue,
      );
    });
  });

  group('controller', () {
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

    ApprovalRequest askRequest() => const ApprovalRequest(
      ref: 'ask-1',
      toolName: 'ask_user',
      arguments: {},
      details: {
        'kind': 'ask_user',
        'questions': [
          {
            'question': 'Which database?',
            'options': ['sqlite', 'postgres'],
          },
        ],
      },
    );

    Future<void> interrupt() async {
      controller.send('hello');
      await Future<void>.delayed(Duration.zero);
      source.emit(ApprovalRequired(askRequest()));
      // The real projection closes the stream right after the interrupt: the
      // paused turn reports TurnFinished, which is what un-busies the
      // controller while the question stays pending.
      source.emit(const TurnFinished(outcome: TurnOutcome.completed));
      await Future<void>.delayed(Duration.zero);
    }

    test('an ask_user interrupt blocks input and clears on answer', () async {
      await interrupt();
      expect(controller.pendingApproval, isNotNull);
      expect(controller.isInputBlocked, isTrue);

      final answering = controller.respondToAskUser([
        const AskUserAnswer(question: 'Which database?', values: ['postgres']),
      ]);
      // The resumed turn finishes like any other: emit, then close the fake's
      // stream so `_consume` can complete and the answer can be awaited.
      await Future<void>.delayed(Duration.zero);
      source.emit(const TurnFinished(outcome: TurnOutcome.completed));
      await source.close();
      await answering;

      expect(controller.pendingApproval, isNull);
      expect(controller.isInputBlocked, isFalse);
      // The answers ARE the tool result, verbatim.
      expect(source.askUserAnswers['ask-1'], {
        'ok': true,
        'answers': [
          {
            'question': 'Which database?',
            'values': ['postgres'],
          },
        ],
      });
    });

    test('answering with nothing pending is a no-op', () async {
      await controller.respondToAskUser([
        const AskUserAnswer(question: 'q', values: ['a']),
      ]);
      expect(source.askUserAnswers, isEmpty);
    });
  });

  group('panel', () {
    const askForm = ApprovalRequest(
      ref: 'ask-1',
      toolName: 'ask_user',
      arguments: {},
      details: {
        'kind': 'ask_user',
        'questions': [
          {
            'question': 'Which database?',
            'options': ['sqlite', 'postgres'],
          },
          {'question': 'Any extra context?'},
        ],
      },
    );

    Future<void> pump(
      WidgetTester tester, {
      ApprovalRequest request = askForm,
      void Function(List<AskUserAnswer> answers)? onSubmit,
    }) => tester.pumpWidget(
      // The free-text field is a ShadInput, which reads ShadTheme — mount the
      // bridge the same way the settings tests do.
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: child!,
        ),
        home: Scaffold(
          body: AskUserPanel(
            request: request,
            onSubmit: onSubmit ?? (answers) {},
          ),
        ),
      ),
    );

    testWidgets('renders every question from the interrupt payload', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Which database?'), findsOneWidget);
      expect(find.text('sqlite'), findsOneWidget);
      expect(find.text('postgres'), findsOneWidget);
      expect(find.text('Any extra context?'), findsOneWidget);
    });

    testWidgets('submit stays dead until every question is answered', (
      tester,
    ) async {
      final submitted = <List<AskUserAnswer>>[];
      await pump(tester, onSubmit: submitted.add);
      // Answer only the choice.
      await tester.tap(find.text('postgres'));
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pump();
      expect(submitted, isEmpty);
    });

    testWidgets('a full answer set submits options and free text', (
      tester,
    ) async {
      final submitted = <List<AskUserAnswer>>[];
      await pump(tester, onSubmit: submitted.add);
      await tester.tap(find.text('postgres'));
      await tester.pump();
      await tester.enterText(find.byType(ShadInput).last, 'look at the docs');
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pump();
      expect(submitted, hasLength(1));
      expect(submitted.single[0].values, ['postgres']);
      expect(submitted.single[1].custom, 'look at the docs');
    });

    testWidgets('skip answers a question without a value', (tester) async {
      final submitted = <List<AskUserAnswer>>[];
      await pump(tester, onSubmit: submitted.add);
      await tester.tap(find.text('Skip').first);
      await tester.pump();
      await tester.enterText(
        find.byType(ShadInput).last,
        'the migration notes',
      );
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pump();
      expect(submitted, hasLength(1));
      expect(submitted.single[0].skipped, isTrue);
      expect(submitted.single[0].values, isEmpty);
      expect(submitted.single[1].custom, 'the migration notes');
    });

    testWidgets('multi-select carries every chosen option in order', (
      tester,
    ) async {
      final multi = const ApprovalRequest(
        ref: 'ask-2',
        toolName: 'ask_user',
        arguments: {},
        details: {
          'kind': 'ask_user',
          'questions': [
            {
              'question': 'Which files?',
              'options': ['a.dart', 'b.dart', 'c.dart'],
              'multi': true,
            },
          ],
        },
      );
      final submitted = <List<AskUserAnswer>>[];
      await pump(tester, request: multi, onSubmit: submitted.add);
      await tester.tap(find.text('b.dart'));
      await tester.pump();
      await tester.tap(find.text('a.dart'));
      await tester.pump();
      await tester.tap(find.text('Submit answer'));
      await tester.pump();
      expect(submitted.single.single.values, ['b.dart', 'a.dart']);
    });
  });
}
