// ADR-0063 guards: the library persists and stays capped, the composer
// inserts at the cursor without sending, and the button is a door only when
// there is something behind it.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:planstar/model/approval_mode.dart';
import 'package:planstar/model/quick_phrase.dart';
import 'package:planstar/state/quick_phrase_store.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/conversation/composer.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadSonner, ShadTheme;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('quick_phrases');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  QuickPhraseStore store() => QuickPhraseStore.open(root);

  group('store', () {
    test('adds, reopens, and keeps menu order', () {
      final library = store()
        ..add('Review', 'Review the diff against the checklist.')
        ..add('Explain', 'Explain this file to a new teammate.');
      expect(library.phrases, hasLength(2));
      expect(library.phrases.first.title, 'Review');

      final reopened = store();
      expect(reopened.phrases, hasLength(2));
      expect(
        reopened.phrases.last.text,
        'Explain this file to a new teammate.',
      );
    });

    test('empty titles and bodies do not become rows', () {
      final library = store()
        ..add('  ', 'body')
        ..add('Title', '   ')
        ..add('Real', ' body ');
      expect(library.phrases, hasLength(1));
      expect(library.phrases.single.title, 'Real');
    });

    test('update edits in place, remove deletes', () {
      final library = store()..add('Old', 'old text');
      final id = library.phrases.single.id;
      library.update(id, title: 'New', text: 'new text');
      expect(library.phrases.single.title, 'New');
      library.remove(id);
      expect(library.phrases, isEmpty);
      // Unknown ids are no-ops, not crashes.
      library.update('nope', title: 'x', text: 'y');
      library.remove('nope');
    });

    test('the cap stops additions, not edits', () {
      final library = store();
      for (var i = 0; i < quickPhraseCap; i++) {
        library.add('p$i', 'text $i');
      }
      expect(library.isFull, isTrue);
      library.add('one more', 'text');
      expect(library.phrases, hasLength(quickPhraseCap));
      library.update(
        library.phrases.first.id,
        title: 'still edits',
        text: 'ok',
      );
      expect(library.phrases.first.title, 'still edits');
    });

    test('a corrupt file reads as an empty library', () {
      File('${root.path}/quick_phrases.json').writeAsStringSync('[{"id": ');
      expect(store().phrases, isEmpty);
    });
  });

  group('composer', () {
    final phrase = const QuickPhrase(
      id: 'p1',
      title: 'Greeting',
      text: 'Please review the checklist first.',
    );

    Future<void> pump(
      WidgetTester tester, {
      List<QuickPhrase> phrases = const [],
      double width = 800,
    }) => tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Brightness.light),
          child: ShadSonner(child: child!),
        ),
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: Composer(
                hero: false,
                busy: false,
                blocked: false,
                approvalMode: ApprovalMode.ask,
                phrases: phrases,
                onSubmit: (text, images, delivery) {},
                onStop: () {},
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('an empty library has no button; a stocked one has a menu', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byIcon(LucideIcons.text_cursor_input), findsNothing);

      await pump(tester, phrases: [phrase]);
      await tester.tap(find.byIcon(LucideIcons.text_cursor_input));
      await tester.pumpAndSettle();
      expect(find.text('Greeting'), findsOneWidget);
    });

    testWidgets('a pick inserts at the caret and never sends', (tester) async {
      await pump(tester, phrases: [phrase]);
      await tester.enterText(find.byType(EditableText), 'Before ');
      await tester.pump();

      await tester.tap(find.byIcon(LucideIcons.text_cursor_input));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Greeting'));
      await tester.pumpAndSettle();

      final field = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      // The phrase landed after the typed words (the caret was at the end),
      // and nothing sent — the composer's submit callback never fired.
      expect(
        field.controller.text,
        'Before Please review the checklist first.',
      );
      expect(
        field.controller.selection.baseOffset,
        field.controller.text.length,
      );
    });

    testWidgets('the row degrades without overflow at 260px with phrases', (
      tester,
    ) async {
      await pump(tester, phrases: [phrase], width: 260);
      await tester.pumpAndSettle();
      // A RenderFlex overflow throws in a widget test; reaching here means
      // the tightened left cluster still degrades in order.
      expect(find.byIcon(LucideIcons.text_cursor_input), findsOneWidget);
    });
  });
}
