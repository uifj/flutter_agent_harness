// One tool result, two surfaces: the card in the transcript and the details
// inspector on the right, which the app shows at the same time. The sentence this
// file guards (ADR-0035): how a result reads is decided in one place, so the two
// surfaces cannot answer the same call in two voices.
//
// ADR-0031 moved the card off `JsonEncoder` — escaping the newlines inside a
// string value turned a 30-line `ls -la` into one unscannable paragraph — but the
// inspector kept its own `_format`, which returns a String result verbatim. The
// same bash call therefore showed lines in the middle of the screen and the
// model-facing envelope, escapes included, on the right.

import 'dart:async';
import 'dart:convert';

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/turn_event.dart';
import 'package:agent_harness/state/conversation_controller.dart';
import 'package:agent_harness/state/details_selection.dart';
import 'package:agent_harness/state/streaming_tail.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/appearance_scope.dart';
import 'package:agent_harness/ui/conversation/conversation_root.dart';
import 'package:agent_harness/ui/conversation/details_panel.dart';
import 'package:agent_harness/ui/tool/tool_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'fake_turn_source.dart';

/// What `bash` answers with: a JSON document carried in a string, its newlines
/// escaped for the model that reads it.
final envelope = jsonEncode({
  'output': 'total 88\ndrwxr-xr-x  2 u  wheel  64 Sep  1 10:00 docs\n',
  'exitCode': 0,
});

/// The longest string either surface paints that carries the payload.
///
/// Read off `RichText` for the card's `Text`, plus each `EditableText`'s
/// controller for the panel's `SelectableText` - neither alone sees both
/// surfaces.
String painted(WidgetTester tester, String needle) {
  final seen = <String>[
    for (final w in tester.widgetList<RichText>(find.byType(RichText)))
      w.text.toPlainText(),
    for (final w in tester.widgetList<EditableText>(find.byType(EditableText)))
      w.controller.text,
  ].where((t) => t.contains(needle));
  expect(seen, isNotEmpty, reason: 'nothing on screen carries $needle');
  return seen.reduce((a, b) => a.length >= b.length ? a : b);
}

void main() {
  late FakeTurnSource source;
  late StreamingTail tail;
  late ConversationController conversation;
  late DetailsSelection selection;

  setUp(() {
    source = FakeTurnSource();
    tail = StreamingTail();
    conversation = ConversationController(runtime: source, tail: tail);
    selection = DetailsSelection();
  });

  tearDown(() {
    selection.dispose();
    conversation.dispose();
    tail.dispose();
  });

  /// The expanded card for a settled `bash` call, as the transcript paints it.
  Future<String> cardResult(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: child!,
        ),
        home: Scaffold(
          body: AppearanceScope(
            contentWidth: chatContentWidth,
            expandToolCalls: true,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 640,
                child: ToolCard(
                  node: ToolCallNode(
                    id: 'c1',
                    name: 'bash',
                    arguments: const {'command': 'ls -la'},
                    status: ToolStatus.succeeded,
                    output: envelope,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return painted(tester, 'total 88');
  }

  /// The same call selected in the inspector.
  Future<String> panelResult(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: DetailsPanel(
              conversation: conversation,
              selection: selection,
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    unawaited(conversation.send('go'));
    await tester.pump();
    source.emit(
      const ToolCallRequested(
        ref: 'r1',
        name: 'bash',
        arguments: {'command': 'ls -la'},
      ),
    );
    await tester.idle();
    await tester.pump();
    source.emit(ToolCallSucceeded(ref: 'r1', output: envelope));
    await tester.idle();
    await tester.pump();
    // Read the node after the result lands: a settled call is a replacement, not
    // the running node mutated in place.
    final call = conversation.nodes.whereType<ToolCallNode>().single;
    selection.select(callId: call.id, toolName: 'Bash');
    await tester.pump();
    return painted(tester, 'total 88');
  }

  testWidgets('the inspector reads a result the way the card does', (
    tester,
  ) async {
    final card = await cardResult(tester);
    final panel = await panelResult(tester);
    expect(panel, card);
  });

  testWidgets('neither surface shows the model-facing envelope', (
    tester,
  ) async {
    final card = await cardResult(tester);
    final panel = await panelResult(tester);
    for (final text in [card, panel]) {
      expect(
        text,
        isNot(contains(r'\n')),
        reason: r'a literal \n is the envelope; a listing has real newlines',
      );
      expect(
        text,
        isNot(contains('{"')),
        reason: 'a JSON document on screen is the model-facing shape',
      );
    }
  });
}
