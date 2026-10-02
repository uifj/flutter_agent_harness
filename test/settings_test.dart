// Settings: what is stored, and what the panel does with it.
//
// The store is worth testing because a corrupt file must not stop the app from
// launching, and because an interrupted save must not lose the previous
// document. The panel is worth testing for one thing above all: Save must commit
// exactly what was typed, since a key with a stray newline fails with the same
// 401 as a wrong one.

import 'dart:convert';
import 'dart:io';

import 'amplified_text_probe.dart';
import 'package:agent_harness/model/app_settings.dart';
import 'package:agent_harness/model/model_settings.dart';
import 'package:agent_harness/model/workbench_prefs.dart';
import 'package:agent_harness/state/secret_store.dart';
import 'package:agent_harness/state/usage_ledger.dart';
import 'package:agent_harness/state/settings_store.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/ui/settings/model_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme, ShadInput;

/// A settings field, and not the panel's own search box. Since ADR-0036 B7 the
/// search box is a `ShadInput` too and it sits above every section, so "the
/// first input in the tree" no longer means "the field under test".
Finder settingsField({int index = 0}) {
  final fields = find.byWidgetPredicate(
    (w) => w is ShadInput && w.key != const ValueKey('settings-search'),
  );
  return index == 0 ? fields : fields.at(index);
}

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

    test('appearance preferences round-trip when off the defaults', () {
      const settings = AppSettings(
        fontSize: AppFontSize.large,
        conversationWidth: AppConversationWidth.wide,
        expandToolCalls: false,
      );
      final json = settings.toJson();
      expect(
        AppSettings.fromJson(
          jsonDecode(jsonEncode(json)) as Map<String, dynamic>,
        ),
        settings,
      );
      // Off-default-only persistence: every field is written because each is
      // non-default, and a default document writes none of them.
      expect(json.containsKey('fontSize'), isTrue);
      expect(const AppSettings().toJson().containsKey('fontSize'), isFalse);
    });

    // The stored step multiplies INTO the platform's own scaler at the root, so
    // two properties are load-bearing: `medium` must be a no-op (a default that
    // quietly scaled the whole app by 0.95 would be invisible in a screenshot
    // and impossible to attribute), and the three steps must actually differ —
    // a stepper whose two ends render the same size is a control that lies.
    test('the text-size steps compose onto the platform scaler', () {
      expect(AppFontSize.medium.scale, 1.0);
      expect(AppFontSize.small.scale, lessThan(1.0));
      expect(AppFontSize.large.scale, greaterThan(1.0));
      expect(
        {for (final size in AppFontSize.values) size.scale}.length,
        AppFontSize.values.length,
      );
      expect(const AppSettings().fontSize, AppFontSize.medium);
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

    test(
      'any model change asks for a restart, since all three are baked in',
      () {
        const base = ModelSettings(apiKey: 'a');
        expect(base.requiresRestart(base), isFalse);
        expect(base.copyWith(apiKey: 'b').requiresRestart(base), isTrue);
        expect(base.copyWith(model: 'other').requiresRestart(base), isTrue);
        expect(
          base.copyWith(baseUrl: 'https://x/v1').requiresRestart(base),
          isTrue,
        );
      },
    );
  });

  group('SettingsStore', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('dsh-settings'));
    tearDown(() => root.deleteSync(recursive: true));

    test('starts at the defaults when nothing is stored', () async {
      final store = await SettingsStore.open(root);
      expect(store.value, const AppSettings());
    });

    test(
      'a saved document survives a reopen, the key via the secret store',
      () async {
        // ADR-0045 PB: the file never carries the API key — without a secret
        // store the key is dropped on reopen (a host without a keychain), with
        // one it comes back.
        final secrets = InMemorySecretStore();
        final store = await SettingsStore.open(root, secrets: secrets);
        const next = AppSettings(
          model: ModelSettings(apiKey: 'sk-live'),
          workspaceRoot: '/tmp/work',
        );
        await store.save(next);

        final reopened = await SettingsStore.open(root, secrets: secrets);
        expect(reopened.value, next);
        final keyless = await SettingsStore.open(root);
        expect(keyless.value.model.apiKey, '');
        expect(keyless.value.workspaceRoot, '/tmp/work');
      },
    );

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
      Future<AppSettings?> Function(AppSettings)? onPickFolder,
      String supportPath = '/support',
      VoidCallback? onClose,
      WorkbenchPrefs workbenchPrefs = const WorkbenchPrefs(),
      ValueChanged<WorkbenchPrefs>? onPrefsChange,
      double scale = 1.0,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        // The panel's fields are ShadInputs, which read ShadTheme — mount the
        // same ancestor main does, via MaterialApp.builder.
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: child!,
        ),
        // The panel is a bare `Stack`; in the app it floats over the frame, which
        // sits in a `Scaffold`. The text fields need that Material ancestor, so
        // the harness supplies the same one rather than a lighter wrapper.
        home: Scaffold(
          body: SettingsPanel(
            onReset: () async {},
            usageSummary: const UsageSummary(
              turns: 0,
              totalTokens: 0,
              errorCount: 0,
              perModelTokens: {},
            ),
            settings: settings,
            onSave: onSave,
            onClose: onClose ?? () {},
            onPickFolder: onPickFolder ?? (_) async => null,
            supportPath: supportPath,
            workbenchPrefs: workbenchPrefs,
            onPrefsChange: onPrefsChange,
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

      // The panel opens on General; the key lives in Models.
      await tester.tap(find.text('Models'));
      await tester.pump();
      await tester.enterText(settingsField(), '  sk-new\n');
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
      await tester.enterText(settingsField(), '');
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

      await tester.tap(find.text('Models'));
      await tester.pump();
      await tester.enterText(settingsField(), 'sk-typed');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(closes, 1);
      expect(saves, 0);
    });

    testWidgets('the theme menu changes the saved mode', (tester) async {
      AppSettings? saved;
      await pump(
        tester,
        settings: const AppSettings(),
        onSave: (next) async => saved = next,
      );

      // General is the opening section; the theme row is the FIRST of the two
      // rows that read "Follow system" — the language row below it says it too.
      expect(find.text('Follow system'), findsNWidgets(2));
      await tester.tap(find.text('Follow system').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // The name comparison dodges the ThemeMode name clash with material.
      expect(saved?.theme.name, 'dark');
    });

    testWidgets('the language menu changes the saved locale', (tester) async {
      AppSettings? saved;
      await pump(
        tester,
        settings: const AppSettings(),
        onSave: (next) async => saved = next,
      );

      // The language row sits under the theme row on General.
      await tester.tap(find.text('Follow system').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('中文'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved?.locale.name, 'zh');
      // Saving without touching the row keeps the document's own locale —
      // the panel must not reset an explicit choice to "system".
      expect(saved?.theme.name, 'system');
    });

    testWidgets('the appearance section commits width and tool-call toggles', (
      tester,
    ) async {
      AppSettings? saved;
      await pump(
        tester,
        settings: const AppSettings(),
        onSave: (next) async => saved = next,
      );

      await tester.tap(find.text('Appearance'));
      await tester.pump();
      // The panel opens the Appearance section with the document's defaults, so
      // the width pill reads "Normal" and the tool-call switch is on.
      final width = find.text('Normal');
      await tester.ensureVisible(width);
      await tester.tap(width);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wide'));
      await tester.pumpAndSettle();

      final expand = find.text('Expand tool calls');
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved?.conversationWidth.name, 'wide');
      expect(saved?.expandToolCalls, isFalse);
      // Untouched preferences keep their defaults rather than arriving null.
      expect(saved?.fontSize.name, 'medium');
      expect(saved?.locale.name, 'system');
      // A pure appearance edit carries the model half through untouched.
      expect(saved?.model.apiKey, '');
    });

    testWidgets('the provider rows carry one editor at a time', (tester) async {
      AppSettings? saved;
      await pump(
        tester,
        settings: const AppSettings(model: ModelSettings(apiKey: 'sk-old')),
        onSave: (next) async => saved = next,
      );

      await tester.tap(find.text('Models'));
      await tester.pump();

      // Three rows; the saved provider's is the open one — its key field is
      // on screen, the other providers' are not.
      expect(find.text('OpenAI-compatible'), findsOneWidget);
      expect(find.text('Anthropic'), findsOneWidget);
      expect(find.text('Google'), findsOneWidget);
      expect(settingsField(), findsOneWidget);
      expect(find.text('Customized'), findsOneWidget);

      // The advanced fields hide behind the disclosure until it is opened.
      expect(find.text('Base URL'), findsNothing);
      await tester.tap(find.text('Customized'));
      await tester.pump();
      expect(find.text('Base URL'), findsOneWidget);
      expect(find.text('Model'), findsOneWidget);

      // Edit on another provider row adopts it: the fields reset to that
      // provider's defaults, the card moves, and the disclosure closes again
      // (its open state belonged to the provider being edited, not the seat).
      // Brought on-screen first: the open card above pushes the lower rows
      // past the fold, and a tap that misses silently is a test that tests
      // nothing.
      await tester.ensureVisible(find.text('Edit').first);
      await tester.pump();
      await tester.tap(find.text('Edit').first);
      await tester.pump();
      expect(settingsField(), findsOneWidget);
      expect(find.text('Customized'), findsOneWidget);

      // The moved card still carries the advanced fields behind its own
      // disclosure.
      await tester.tap(find.text('Customized'));
      await tester.pump();
      expect(settingsField(), findsNWidgets(3));

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.model.provider, LlmProvider.anthropic);
      // A provider switch resets the key — an OpenAI key in an Anthropic
      // client is worse than retyping one field.
      expect(saved?.model.apiKey, '');
      expect(saved?.model.model, defaultModelFor(LlmProvider.anthropic));
    });

    testWidgets('a picked folder fills the field and the recents', (
      tester,
    ) async {
      AppSettings? saved;
      final picked = Directory.systemTemp.createTempSync('dsh_pick_');
      addTearDown(() => picked.deleteSync(recursive: true));
      await pump(
        tester,
        settings: const AppSettings(),
        onPickFolder: (current) async => current.withWorkspace(picked.path),
        supportPath: '/support',
        onSave: (next) async => saved = next,
      );

      await tester.tap(find.text('Workspace'));
      await tester.pump();
      await tester.tap(find.text('Choose…'));
      await tester.pumpAndSettle();

      // The field carries the choice, the recents list it, and Save commits
      // both in one document.
      expect(find.text(picked.path), findsWidgets);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.workspaceRoot, picked.path);
      expect(saved?.recentWorkspaces, [picked.path]);
    });

    testWidgets('the skills hint is the directory this app actually uses', (
      tester,
    ) async {
      // ADR-0033: the hint used to read `/Users/you/.dsh/skills` - another
      // product's path, on a screen whose description says "application support
      // directory". It now comes from the support path handed in, so the field
      // and the sentence above it cannot disagree.
      await pump(
        tester,
        settings: const AppSettings(),
        supportPath: '/var/app-support',
        onSave: (_) async {},
      );
      await tester.tap(find.text('Extensions'));
      await tester.pumpAndSettle();

      expect(find.text('/var/app-support/skills'), findsOneWidget);
      expect(find.textContaining('.dsh'), findsNothing);
    });

    testWidgets('a dismissed picker changes nothing', (tester) async {
      AppSettings? saved;
      await pump(
        tester,
        settings: const AppSettings(workspaceRoot: '/tmp/kept'),
        onPickFolder: (_) async => null,
        supportPath: '/support',
        onSave: (next) async => saved = next,
      );

      await tester.tap(find.text('Workspace'));
      await tester.pump();
      // The field holds the kept path before and after the cancelled pick.
      expect(find.text('/tmp/kept'), findsOneWidget);
      await tester.tap(find.text('Choose…'));
      await tester.pumpAndSettle();
      expect(find.text('/tmp/kept'), findsOneWidget);
      // No recents appeared for a folder that was never adopted.
      expect(find.text('Recent'), findsNothing);

      // Nothing was edited, so there is nothing to save — the inert Save is
      // the assertion: a cancelled pick must not manufacture a diff.
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
    });

    testWidgets('a recent row adopts its path; forgetting removes only it', (
      tester,
    ) async {
      AppSettings? saved;
      final kept = Directory.systemTemp.createTempSync('dsh_keep_');
      addTearDown(() => kept.deleteSync(recursive: true));
      await pump(
        tester,
        settings: AppSettings(
          recentWorkspaces: ['/tmp/gone', kept.path],
          workspaceRoot: kept.path,
        ),
        onSave: (next) async => saved = next,
      );

      await tester.tap(find.text('Workspace'));
      await tester.pump();
      // The dead folder shows its missing badge and cannot be adopted.
      expect(find.text('missing'), findsOneWidget);

      // Hover the dead row so its forget button appears, then press it. Scoped
      // to the row's container: the panel's own close button is an X too, and
      // the forget button only exists inside a hovered recent row.
      final gone = find.text('/tmp/gone');
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: tester.getCenter(gone));
      addTearDown(gesture.removePointer);
      await tester.pump();
      final forget = find.byIcon(LucideIcons.x).last;
      await tester.tap(forget);
      await tester.pumpAndSettle();
      expect(find.text('/tmp/gone'), findsNothing);
      expect(find.text(kept.path), findsWidgets);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved?.recentWorkspaces, [kept.path]);
      expect(saved?.workspaceRoot, kept.path);
    });

    testWidgets('the workbench switches commit on the spot', (tester) async {
      final changes = <WorkbenchPrefs>[];
      await pump(
        tester,
        settings: const AppSettings(model: ModelSettings(apiKey: 'k')),
        onSave: (_) async {},
        onPrefsChange: changes.add,
      );

      await tester.tap(find.text('Workbench'));
      await tester.pump();

      // No Save, no waiting: a switch is its own commit, because none of
      // these preferences can rebuild the agent. The section scrolls — the
      // switches sit below the terminal card.
      await tester.ensureVisible(find.text('Source control'));
      await tester.pump();
      await tester.tap(find.text('Source control'));
      await tester.pump();
      expect(changes, hasLength(1));
      expect(changes.single.tabEnabled('git'), isFalse);

      await tester.ensureVisible(find.text('Seed the bottom panel'));
      await tester.pump();
      await tester.tap(find.text('Seed the bottom panel'));
      await tester.pump();
      expect(changes, hasLength(2));
      expect(changes.last.bottomPanelAutoTerminal, isFalse);
    });

    testWidgets('the font stepper and field commit their own values', (
      tester,
    ) async {
      final changes = <WorkbenchPrefs>[];
      await pump(
        tester,
        settings: const AppSettings(model: ModelSettings(apiKey: 'k')),
        onSave: (_) async {},
        onPrefsChange: changes.add,
      );

      await tester.tap(find.text('Workbench'));
      await tester.pump();

      // One step up from the default.
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pump();
      expect(changes.single.terminalFontSize, terminalFontSizeDefault + 1);

      // The family commits on submit — a half-typed font stack is not a
      // preference.
      await tester.enterText(settingsField(), "'JetBrains Mono', monospace");
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(changes.last.terminalFontFamily, "'JetBrains Mono', monospace");
    });
    // ADR-0017 S3, on the settings panel. Measured at 1.8x before these three
    // seats were scaled: the search field's 14/22 text wanted 40.0 in the 30.0 a
    // nailed 32 left it, the action row's dense capsule wanted 32.0 in the 26.0
    // the 54px header allowed after its own padding, and a provider row wanted
    // 40.0 in 36.0. All three are one line of chrome, so each now rides the step.
    // The step above 1.8x then named two more: the nav cells (48.0 in 40.0) and
    // a provider name that was handed its row's whole width instead of yielding
    // to the credential dot next to it.
    group('amplified text', () {
      for (final (label, step) in const [
        ('1.8x', amplifiedTextStep),
        ('2.2x', nextTextStep),
      ]) {
        testWidgets('no section spills or cuts a label ($label)', (
          tester,
        ) async {
          // Tall enough that the panel's whole content lays out at once: the
          // sections are a single scroll list, so measuring one page would only
          // ever see the first.
          tester.view.physicalSize = const Size(1400, 6000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await pump(
            tester,
            settings: const AppSettings(model: ModelSettings(apiKey: 'k')),
            onSave: (_) async {},
            scale: step,
          );
          await tester.pumpAndSettle();
          expect(textDefects(tester), isEmpty, reason: 'every section at once');

          // The provider rows and the workbench card expand on demand, so the
          // panel has to be walked nav by nav: the pass above never laid out
          // what a closed section keeps hidden.
          for (final section in const [
            'General',
            'Appearance',
            'Models',
            'Workbench',
            'Workspace',
            'Extensions',
            'Backup & Restore',
          ]) {
            // Both the nav cell and the section's own heading carry the label,
            // and the tall viewport lays both out at once.
            await tester.tap(find.text(section).first);
            await tester.pumpAndSettle();
            expect(textDefects(tester), isEmpty, reason: section);
          }

          // The General rows are chips that open menus, and a menu is in no
          // one's tree until it is opened — the walk above only ever measured
          // the closed chip.
          await tester.tap(find.text('General').first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Follow system').first);
          await tester.pumpAndSettle();
          expect(find.text('Dark'), findsWidgets);
          expect(textDefects(tester), isEmpty, reason: 'the theme menu');
          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();
          expect(find.text('Dark'), findsNothing);

          // The language chip is the same widget with the same three-row shape,
          // but its own menu had never been opened: the two labels are a Chinese
          // string and a proper noun, so its widths are not the theme menu's.
          await tester.tap(find.text('Follow system').last);
          await tester.pumpAndSettle();
          expect(find.text('English'), findsOneWidget);
          expect(textDefects(tester), isEmpty, reason: 'the language menu');
          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();
          expect(find.text('English'), findsNothing);
        });
      }

      // The shell sets no minimum window size, so a narrow window is a state
      // users reach, and the card is then ~430px wide. Measured there at 1.8x
      // before this: the General row's title column was given 0.0px and the
      // value pill spilled past the card — the pill has now moved under the
      // label. The step above this still cannot be served at that width (a
      // capsule's own one-line label is 396px inside 380), and the reason it
      // cannot is registered in the debt table rather than papered over here.
      testWidgets('a narrow card moves its pill under the label', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(700, 6000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pump(
          tester,
          settings: const AppSettings(model: ModelSettings(apiKey: 'k')),
          onSave: (_) async {},
          scale: amplifiedTextStep,
        );
        await tester.tap(find.text('General').first);
        await tester.pumpAndSettle();

        expect(find.text('Follow system'), findsWidgets);
        expect(textDefects(tester), isEmpty, reason: 'General at 700px');
        expect(tester.takeException(), isNull);
      });
    });
  });
}
