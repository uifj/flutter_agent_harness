// What a tool result has to do for a human: read like the thing it stands for.
// The sentence this file guards (ADR-0031): a card never shows the model-facing
// JSON envelope as the answer a person asked for.
//
// Reproduced from a real window screenshot of a `bash ls -la` turn: the OUT
// section was one wall of `{"output": "/Users/…\n.total 88\ndrwxr-xr-x@ 25 …`
// — `JsonEncoder` escapes the newlines inside a string value, so a 30-line
// directory listing became a single unscannable paragraph. The IN section of the
// same card was pretty-printed multi-line, so one card answered in two voices.

import 'dart:convert';

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/appearance_scope.dart';
import 'package:agent_harness/ui/conversation/conversation_root.dart';
import 'package:agent_harness/ui/tool/tool_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  Future<void> pumpOutput(WidgetTester tester, Object? output) {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
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
                    id: 'call-1',
                    name: 'bash',
                    arguments: const {'command': 'pwd && ls -la'},
                    status: ToolStatus.succeeded,
                    output: output,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<String> rendered(WidgetTester tester) async {
    await tester.pumpAndSettle();
    return tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .join('\u0000');
  }

  const listing =
      '/Users/uifj/Workspace/pinplan/flutter_tiptap_test\n'
      'total 88\n'
      'drwxr-xr-x@ 25 uifj staff 800 May 26 22:35 .\n'
      'drwxr-xr-x@ 15 uifj staff 480 May 26 00:35 ..';

  testWidgets(
    'a multi-line payload is shown as lines, not as an escaped wall',
    (tester) async {
      // The shape the projection carries: the tool's Map result.
      await pumpOutput(tester, {'output': listing});
      final text = await rendered(tester);
      expect(text, contains('total 88'));
      expect(
        text,
        isNot(contains(r'\n')),
        reason:
            'a literal backslash-n means the JSON envelope reached the screen',
      );
    },
  );

  testWidgets('the same payload arriving as the model-facing JSON string is '
      'decoded before it is shown', (tester) async {
    await pumpOutput(tester, jsonEncode({'output': listing}));
    final text = await rendered(tester);
    expect(text, contains('total 88'));
    expect(text, isNot(contains(r'\n')));
  });

  testWidgets('the structure a person needs to read stays on screen', (
    tester,
  ) async {
    // `read` answers with several fields plus a multi-line body; flattening the
    // map to just the body would lose which file and which lines this is.
    await pumpOutput(tester, {
      'path': 'lib/main.dart',
      'startLine': 1,
      'totalLines': 42,
      'content': 'void main() {\n  runApp();\n}',
    });
    final text = await rendered(tester);
    expect(text, contains('path: lib/main.dart'));
    expect(text, contains('totalLines: 42'));
    expect(text, contains('runApp();'));
    expect(text, isNot(contains(r'\n')));
  });

  testWidgets('a plain string result is not touched', (tester) async {
    await pumpOutput(tester, 'nothing to report');
    expect(await rendered(tester), contains('nothing to report'));
  });
}
