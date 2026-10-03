// A user message is a bubble, not an avatar. The sentence this file guards
// (ADR-0034): the transcript's own words are capped by the same radius ramp as
// every other surface, so a three-character message still reads as a bubble.
//
// Reproduced from a real window screenshot: the first user message of a session
// named `h'i` rendered as a pale blue circle tucked under the panel toggles,
// because `_UserBubble` asked for `DswShape.pill` and Flutter clamps a radius to
// half the box — so as the text shrinks, a pill becomes a disc. The ramp
// reserves `pill` for dots and avatars (`dsw_shape.dart:27`), and the reference
// product's user bubble is `rounded-xl rounded-tr-xs border border-border`
// (`ConversationRowView.tsx:1253-1258`): a 12px corner with a near-square
// top-right that points at the edge the message comes from, plus a hairline.

import 'package:planstar/model/conversation.dart';
import 'package:planstar/theme/dsw_alias.dart';
import 'package:planstar/theme/dsw_shape.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/theme/dsw_typography.dart';
import 'package:planstar/ui/conversation/message_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpBubble(WidgetTester tester, String text) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              child: MessageItem(
                node: UserMessageNode(id: 'u1', text: text),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The bubble is the only painted box in the row wearing the bubble colour.
  BoxDecoration bubbleBox(WidgetTester tester) => tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .map((w) => w.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.color == DswAlias.light.bubble);

  testWidgets('a short message keeps the ramp, not a disc', (tester) async {
    await pumpBubble(tester, "h'i");
    expect(
      bubbleBox(tester).borderRadius,
      BorderRadius.only(
        topLeft: const Radius.circular(DswShape.shell),
        topRight: const Radius.circular(DswShape.inset),
        bottomRight: const Radius.circular(DswShape.shell),
        bottomLeft: const Radius.circular(DswShape.shell),
      ),
      reason:
          'pill clamps to half the box, so the shorter the message the rounder '
          'the bubble gets - until it is an avatar',
    );
  });

  testWidgets('the bubble states its edge like every other surface', (
    tester,
  ) async {
    await pumpBubble(
      tester,
      'a longer message that wraps over a couple of lines',
    );
    final border = bubbleBox(tester).border;
    expect(border, isNotNull);
    expect(border!.top.color, DswAlias.light.borderL2);
    expect(border.top.width, lessThanOrEqualTo(1.0));
  });

  testWidgets('the type inside the bubble is untouched by this', (
    tester,
  ) async {
    await pumpBubble(tester, 'still the body step');
    final style = tester
        .widget<SelectableText>(find.byType(SelectableText))
        .style;
    expect(style?.fontSize, DswType.base16.fontSize);
    expect(style?.height, DswType.base16.height);
  });
}
