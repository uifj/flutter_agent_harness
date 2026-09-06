// The side chat: the controller's exchange, and the tab that shows it.
//
// The controller is driven over a hand-pumped fake runner, which is where the
// properties live: a streaming answer is ONE bubble that grows, a failure is
// a bubble with the error in it, reset drops both the exchange and the
// thread's context, and a missing runner is said out loud rather than
// swallowed. The widget tests cover the seam the controller cannot see — the
// host, the empty states, and the composer's reach into send.

import 'dart:async';
import 'dart:io';

import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/model/turn_source.dart';
import 'package:agent_harness/model/sidebar_tab.dart';
import 'package:agent_harness/state/workbench_controller.dart';
import 'package:agent_harness/state/workbench_store.dart';
import 'package:agent_harness/ui/workbench/tabs/sidechat_tab.dart';
import 'package:agent_harness/state/side_chat_controller.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

/// A runner the test drives by hand: each send gets its own stream, the
/// controller's reset is counted.
///
/// The controller is sync and a finished turn closes the stream, because the
/// real one is an async* generator — the end of the turn IS the end of the
/// stream, and `SideChatController.send` awaits exactly that.
class FakeSideSource implements SideTurnSource {
  final sends = <String>[];
  var resets = 0;
  StreamController<TurnEvent>? _current;

  @override
  Stream<TurnEvent> send(String text) {
    sends.add(text);
    _current = StreamController<TurnEvent>(sync: true);
    return _current!.stream;
  }

  void emit(TurnEvent event) {
    final current = _current;
    if (current == null) return;
    current.add(event);
    if (event is TurnFinished) {
      unawaited(current.close());
    }
  }

  @override
  void reset() => resets++;
}

void main() {
  group('the controller', () {
    late SideChatController chat;
    late FakeSideSource source;

    setUp(() {
      chat = SideChatController();
      source = FakeSideSource();
      chat.adoptSource(source);
    });

    tearDown(() => chat.dispose());

    test('an aside is a user bubble followed by a growing answer', () async {
      final sending = chat.send('what is this file?');

      // The aside lands immediately; busy is on with no answer yet.
      expect(chat.messages, hasLength(1));
      expect(chat.messages.single.isUser, isTrue);
      expect(chat.busy, isTrue);

      source.emit(const TextDelta(text: 'a ', messageIndex: 0));
      source.emit(const TextDelta(text: 'file', messageIndex: 0));
      expect(chat.messages.last.text, 'a file');

      source.emit(
        const TurnFinished(outcome: TurnOutcome.completed),
      );
      await sending;
      expect(chat.busy, isFalse);
      expect(chat.messages, hasLength(2));
    });

    test('a failed turn is the error, not a silent nothing', () async {
      final sending = chat.send('x');
      source.emit(
        const TurnFinished(
          outcome: TurnOutcome.failed,
          errorMessage: 'no model',
        ),
      );
      await sending;

      expect(chat.busy, isFalse);
      expect(chat.messages.last.isUser, isFalse);
      expect(chat.messages.last.text, 'no model');
    });

    test('reset drops the exchange and the runner context', () async {
      final sending = chat.send('x');
      source.emit(
        const TurnFinished(outcome: TurnOutcome.completed),
      );
      await sending;

      chat.reset();
      expect(chat.messages, isEmpty);
      expect(chat.busy, isFalse);
      expect(source.resets, 1);
    });

    test('busy refuses a second aside', () async {
      final first = chat.send('one');
      final second = chat.send('two');

      source.emit(
        const TurnFinished(outcome: TurnOutcome.completed),
      );
      await first;
      await second;

      expect(source.sends, ['one']);
      expect(
        chat.messages.map((message) => message.text),
        ['one'],
      );
    });

    test('a missing runner says so rather than dropping the aside', () async {
      final orphan = SideChatController();
      addTearDown(orphan.dispose);

      await orphan.send('hello?');

      expect(orphan.messages.last.text, 'no source');
      expect(orphan.ready, isFalse);
    });

    test('a runtime swap abandons the in-flight exchange', () async {
      chat.send('x');
      chat.adoptSource(FakeSideSource());

      expect(chat.busy, isFalse);
      expect(chat.messages.map((message) => message.text), ['x']);
      // The abandoned turn's stream is cancelled, not answered: events on
      // the old runner land on a subscription that no longer exists.
      source.emit(const TextDelta(text: 'late', messageIndex: 0));
      await Future<void>.delayed(Duration.zero);
      expect(chat.messages, hasLength(1));
    });
  });

  group('the tab', () {
    late Directory support;
    late WorkbenchController workbench;
    late SideChatController chat;
    late FakeSideSource source;

    setUp(() {
      support = Directory.systemTemp.createTempSync('dsh_sidechat_tab_');
      workbench = WorkbenchController(store: WorkbenchStore.open(support));
      chat = SideChatController();
      source = FakeSideSource();
      chat.adoptSource(source);
    });

    tearDown(() {
      workbench.dispose();
      chat.dispose();
      support.deleteSync(recursive: true);
    });

    Future<void> pumpTab(
      WidgetTester tester, {
      SideChatController? withChat,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: SideChatHost(
            chat: withChat ?? chat,
            child: SideChatTab(
              workbench: workbench,
              tab: SidebarTab.sidechat,
            ),
          ),
        ),
      ),
    );

    testWidgets('without a runner the hero says to connect a model', (
      tester,
    ) async {
      final orphan = SideChatController();
      addTearDown(orphan.dispose);
      await pumpTab(tester, withChat: orphan);

      expect(find.text('Connect a model in Settings to chat here.'), findsOneWidget);
      expect(find.text('Ask an aside…'), findsOneWidget);
    });

    testWidgets('with a runner the hero explains the page', (tester) async {
      await pumpTab(tester);
      expect(
        find.text('A lighter conversation beside the main one.'),
        findsOneWidget,
      );
    });

    testWidgets('sending from the composer bubbles the exchange', (
      tester,
    ) async {
      await pumpTab(tester);

      await tester.enterText(find.byType(TextField), 'quick one');
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pump();

      expect(find.text('quick one'), findsOneWidget);
      expect(find.text('Thinking…'), findsOneWidget);

      source.emit(const TextDelta(text: 'answer', messageIndex: 0));
      await tester.pump();
      expect(find.text('answer'), findsOneWidget);

      source.emit(const TurnFinished(outcome: TurnOutcome.completed));
      await tester.pump();
      expect(find.text('Thinking…'), findsNothing);

      // The composer was cleared by the send.
      expect(find.widgetWithText(TextField, 'quick one'), findsNothing);
    });

    testWidgets('the new-side-chat button resets the exchange', (
      tester,
    ) async {
      await pumpTab(tester);
      await tester.enterText(find.byType(TextField), 'quick one');
      await tester.tap(find.byIcon(LucideIcons.send));
      await tester.pump();
      source.emit(const TurnFinished(outcome: TurnOutcome.completed));
      await tester.pump();
      expect(find.text('quick one'), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.message_square_plus));
      await tester.pump();

      expect(find.text('quick one'), findsNothing);
      expect(source.resets, 1);
      expect(
        find.text('A lighter conversation beside the main one.'),
        findsOneWidget,
      );
    });
  });
}
