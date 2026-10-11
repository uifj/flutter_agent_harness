// ADR-0066 guards: the message menu's copy lands on the clipboard, the
// transcript assembly carries speakers, and the export menu shows all verbs.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/model/conversation.dart';
import 'package:planstar/model/context_compression.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/conversation/message_item.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme;

import 'clipboard_probe.dart';

void main() {
  late ClipboardProbe probe;

  setUp(() {
    probe = ClipboardProbe(
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger,
    );
  });

  Future<void> pumpMessage(WidgetTester tester, ConversationNode node) =>
      tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),

          builder: (context, child) =>
              ShadTheme(data: dswShadTheme(Brightness.light), child: child!),
          theme: dswThemeData(Brightness.light),
          home: Scaffold(body: MessageItem(node: node)),
        ),
      );

  testWidgets('a message right-click offers the verbs and copy works', (
    tester,
  ) async {
    await pumpMessage(
      tester,
      const AssistantMessageNode(id: 'a1', text: 'It was a race in setUp.'),
    );

    await tester.tap(
      find.text('It was a race in setUp.'),
      buttons: kSecondaryButton,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Copy text'), findsOneWidget);
    expect(find.text('Export as Markdown'), findsOneWidget);
    expect(find.text('Export as plain text'), findsOneWidget);

    await tester.tap(find.text('Copy text'));
    await tester.pump();
    expect(probe.text, 'It was a race in setUp.');
  });

  test('the whole transcript assembles with speakers, uncapped', () {
    final text = transcriptTextOf([
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
    expect(text, 'user: Fix the flaky test.\nassistant: It was a race.');
  });
}
