// Settings: what is stored, and what the panel does with it.
//
// The store is worth testing because a corrupt file must not stop the app from
// launching, and because an interrupted save must not lose the previous
// document. The panel is worth testing for one thing above all: Save must commit
// exactly what was typed, since a key with a stray newline fails with the same
// 401 as a wrong one.

import 'dart:convert';
import 'dart:io';

import 'package:agent_harness/model/app_settings.dart';
import 'package:agent_harness/model/model_settings.dart';
import 'package:agent_harness/state/settings_store.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/settings/model_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('round-trips through JSON', () {
      const settings = AppSettings(
        model: ModelSettings(
          apiKey: 'sk-test',
          baseUrl: 'https://example.test/v1',
          model: 'deepseek-reasoner',
        ),
        workspaceRoot: '/tmp/work',
      );
      final decoded = AppSettings.fromJson(
        jsonDecode(jsonEncode(settings.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, settings);
    });

    test('reads an absent document as the defaults', () {
      final decoded = AppSettings.fromJson(const {});
      expect(decoded.model.baseUrl, defaultBaseUrl);
      expect(decoded.model.model, defaultModel);
      expect(decoded.model.isConfigured, isFalse);
      expect(decoded.workspaceRoot, isNull);
    });

    test('withoutWorkspace revokes the permission copyWith cannot', () {
      const settings = AppSettings(workspaceRoot: '/tmp/work');
      expect(settings.copyWith().workspaceRoot, '/tmp/work');
      expect(settings.withoutWorkspace().workspaceRoot, isNull);
    });

    test('any model change asks for a restart, since all three are baked in', () {
      const base = ModelSettings(apiKey: 'a');
      expect(base.requiresRestart(base), isFalse);
      expect(base.copyWith(apiKey: 'b').requiresRestart(base), isTrue);
      expect(base.copyWith(model: 'other').requiresRestart(base), isTrue);
      expect(base.copyWith(baseUrl: 'https://x/v1').requiresRestart(base), isTrue);
    });
  });

  group('SettingsStore', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('dsh-settings'));
    tearDown(() => root.deleteSync(recursive: true));

    test('starts at the defaults when nothing is stored', () async {
      final store = await SettingsStore.open(root);
      expect(store.value, const AppSettings());
    });

    test('a saved document survives a reopen', () async {
      final store = await SettingsStore.open(root);
      const next = AppSettings(
        model: ModelSettings(apiKey: 'sk-live'),
        workspaceRoot: '/tmp/work',
      );
      await store.save(next);

      final reopened = await SettingsStore.open(root);
      expect(reopened.value, next);
    });

    test('notifies once per accepted save, and not for a no-op', () async {
      final store = await SettingsStore.open(root);
      var notifications = 0;
      store.addListener(() => notifications++);

      await store.save(const AppSettings(model: ModelSettings(apiKey: 'k')));
      await store.save(const AppSettings(model: ModelSettings(apiKey: 'k')));
      expect(notifications, 1);
    });

    test('a corrupt file reads as absent rather than throwing', () async {
      File('${root.path}/settings.json').writeAsStringSync('{not json');
      final store = await SettingsStore.open(root);
      expect(store.value, const AppSettings());
    });
  });

  group('SettingsPanel', () {
    Future<void> pump(
      WidgetTester tester, {
      required AppSettings settings,
      required Future<void> Function(AppSettings) onSave,
      VoidCallback? onClose,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        // The panel is a bare `Stack`; in the app it floats over the frame, which
        // sits in a `Scaffold`. The text fields need that Material ancestor, so
        // the harness supplies the same one rather than a lighter wrapper.
        home: Scaffold(
          body: SettingsPanel(
            settings: settings,
            onSave: onSave,
            onClose: onClose ?? () {},
          ),
        ),
      ),
    );

    testWidgets('Save is inert until something is edited', (tester) async {
      var saves = 0;
      await pump(
        tester,
        settings: const AppSettings(model: ModelSettings(apiKey: 'sk-old')),
        onSave: (_) async => saves++,
      );

      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saves, 0);
    });

    testWidgets('commits the typed key, trimmed', (tester) async {
      AppSettings? saved;
      await pump(
        tester,
        settings: const AppSettings(),
        onSave: (next) async => saved = next,
      );

      await tester.enterText(find.byType(TextField).first, '  sk-new\n');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved?.model.apiKey, 'sk-new');
      // Untouched fields keep their defaults rather than arriving empty.
      expect(saved?.model.baseUrl, defaultBaseUrl);
      expect(saved?.model.model, defaultModel);
    });

    testWidgets('an emptied workspace field revokes the permission', (
      tester,
    ) async {
      AppSettings? saved;
      await pump(
        tester,
        settings: const AppSettings(
          model: ModelSettings(apiKey: 'sk-old'),
          workspaceRoot: '/tmp/work',
        ),
        onSave: (next) async => saved = next,
      );

      await tester.tap(find.text('Workspace'));
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved?.workspaceRoot, isNull);
      // The model half is carried through untouched by a workspace edit.
      expect(saved?.model.apiKey, 'sk-old');
    });

    testWidgets('Escape dismisses without saving', (tester) async {
      var saves = 0;
      var closes = 0;
      await pump(
        tester,
        settings: const AppSettings(),
        onSave: (_) async => saves++,
        onClose: () => closes++,
      );

      await tester.enterText(find.byType(TextField).first, 'sk-typed');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(closes, 1);
      expect(saves, 0);
    });
  });
}
