// The sentence this file holds: the panel offers exactly the verdicts it can
// honour, and one answer per question.
//
// The approval panel replaces the input card while a call is paused, so its two
// properties that matter to a user are that every button says which decision it
// makes, that pressing twice does not answer twice, and that the row still reads
// whole when the system amplifies text — the last is what the bottom group
// measures, over a command, a long path, and a call with no subject at all.

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/model/conversation.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/conversation/approval_panel.dart';
import 'package:planstar/ui/primitives/capsule_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'amplified_text_probe.dart';

void main() {
  const bashAsk = ApprovalRequest(
    ref: 'r1',
    toolName: 'bash',
    arguments: {'command': 'git status', 'description': 'show the tree'},
    details: {'kind': 'bash', 'command': 'git status'},
  );

  const noSubjectAsk = ApprovalRequest(
    ref: 'r2',
    toolName: 'plan',
    arguments: {},
    details: {'kind': 'plan'},
  );

  Future<void> pump(
    WidgetTester tester, {
    ApprovalRequest request = bashAsk,
    double step = 1.0,
    void Function(bool approved, {bool remember})? onRespond,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),

      builder: (context, child) => amplifiedAppBuilder(step, child),
      theme: dswThemeData(Brightness.light),
      home: Scaffold(
        body: ApprovalPanel(
          request: request,
          onRespond: onRespond ?? (approved, {remember = false}) {},
        ),
      ),
    ),
  );

  testWidgets('names the target it is asking about', (tester) async {
    await pump(tester);
    expect(find.text('git status'), findsOneWidget);
    expect(
      find.text('Tool bash requests privileged execution'),
      findsOneWidget,
    );
  });

  Future<void> tapLabel(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
  }

  testWidgets('reject answers no, once only', (tester) async {
    final answers = <(bool, bool)>[];
    await pump(
      tester,
      onRespond: (approved, {remember = false}) =>
          answers.add((approved, remember)),
    );
    await tapLabel(tester, 'Reject');
    expect(answers, [(false, false)]);
  });

  testWidgets('always allow answers yes and asks to remember', (tester) async {
    final answers = <(bool, bool)>[];
    await pump(
      tester,
      onRespond: (approved, {remember = false}) =>
          answers.add((approved, remember)),
    );
    await tapLabel(tester, 'Always allow');
    expect(answers, [(true, true)]);
  });

  testWidgets('allow once answers yes without remembering', (tester) async {
    final answers = <(bool, bool)>[];
    await pump(
      tester,
      onRespond: (approved, {remember = false}) =>
          answers.add((approved, remember)),
    );
    await tapLabel(tester, 'Allow once');
    expect(answers, [(true, false)]);
  });

  testWidgets('one question gets one answer', (tester) async {
    var answered = 0;
    await pump(tester, onRespond: (approved, {remember = false}) => answered++);

    await tester.tap(find.text('Reject'));
    await tester.pump();

    // The rest of the row goes inert rather than merely ignoring a second tap:
    // the panel stays on screen until the controller clears it, so a stale
    // button would look answerable.
    for (final label in ['Always allow', 'Allow once']) {
      final button = tester.widget<CapsuleButton>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(CapsuleButton),
        ),
      );
      expect(button.enabled, isFalse, reason: label);
    }
    expect(answered, 1);
  });

  testWidgets('a call with no named subject offers nothing to remember', (
    tester,
  ) async {
    await pump(tester, request: noSubjectAsk);

    expect(find.text('Always allow'), findsNothing);
    expect(find.text('Allow once'), findsOneWidget);
    expect(find.text('Reject'), findsOneWidget);
  });

  testWidgets('a second question re-arms the buttons', (tester) async {
    var answered = 0;
    await pump(tester, onRespond: (approved, {remember = false}) => answered++);

    await tester.tap(find.text('Allow once'));
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),

        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: ApprovalPanel(
            request: const ApprovalRequest(
              ref: 'r9',
              toolName: 'bash',
              arguments: {'command': 'git push'},
              details: {'kind': 'bash', 'command': 'git push'},
            ),
            onRespond: (approved, {remember = false}) => answered++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Allow once'));
    await tester.pump();

    expect(answered, 2);
  });

  // The panel is the one surface that must stay readable while the user is
  // being asked to say yes — and its three buttons are capsule seats with a
  // subject line of model-produced text (a command, a path) above them.
  group('amplified text', () {
    for (final (label, step) in const [
      ('1.8x', amplifiedTextStep),
      ('2.2x', nextTextStep),
    ]) {
      testWidgets('the subject and the three buttons keep their labels ($label)', (
        tester,
      ) async {
        await pump(tester, step: step);
        expect(find.text('Allow once'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'a bash ask');

        // A path is the widest subject the file tools can put on this row.
        await pump(
          tester,
          step: step,
          request: const ApprovalRequest(
            ref: 'r3',
            toolName: 'write',
            arguments: {
              'file_path':
                  'lib/src/features/a-markedly-long-directory-name/another_long_one/approval_panel.dart',
            },
            details: {
              'kind': 'file',
              'path':
                  'lib/src/features/a-markedly-long-directory-name/another_long_one/approval_panel.dart',
            },
          ),
        );
        expect(
          textDefects(tester),
          isEmpty,
          reason: 'a file ask with a long path',
        );

        // No subject at all: the row then carries only the three buttons.
        await pump(tester, step: step, request: noSubjectAsk);
        expect(
          textDefects(tester),
          isEmpty,
          reason: 'an ask with nothing to remember',
        );
      });
    }
  });
}
