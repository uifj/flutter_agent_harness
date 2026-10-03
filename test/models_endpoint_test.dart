// The models-endpoint fetch: what a `/models` body yields per provider
// family, and what the settings panel does with a fetch it can drive.
//
// The HTTP fetcher itself is not exercised here — a socket needs a real
// endpoint — so the pure parser is pinned by data, and the panel's probe row
// is driven through the `ModelsEndpointFetcher` seam with a fake, the same
// seam the app hands its HTTP implementation to.

import 'dart:io' show HttpException;

import 'package:planstar/genkit/models_endpoint.dart';
import 'package:planstar/model/app_settings.dart';
import 'package:planstar/model/model_settings.dart';
import 'package:planstar/state/usage_ledger.dart' show UsageSummary;
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/ui/settings/model_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme;

import 'amplified_text_probe.dart';

/// Scripts the answer, or the failure; records every ask.
class FakeModelsFetcher implements ModelsEndpointFetcher {
  FakeModelsFetcher({this.models = const [], this.error});

  final List<String> models;
  final Object? error;

  final asks = <({LlmProvider provider, String baseUrl, String apiKey})>[];

  @override
  Future<List<String>> listModels({
    required LlmProvider provider,
    required String baseUrl,
    required String apiKey,
  }) async {
    asks.add((provider: provider, baseUrl: baseUrl, apiKey: apiKey));
    if (error != null) throw error!;
    return models;
  }
}

void main() {
  group('parseModelsResponse', () {
    test('the OpenAI-compatible shape: data[].id', () {
      const body = '{"data": [{"id": "gpt-4o"}, {"id": "o3-mini"}]}';
      expect(parseModelsResponse(LlmProvider.openai, body), [
        'gpt-4o',
        'o3-mini',
      ]);
    });

    test('the Anthropic shape is the same one', () {
      const body = '{"data": [{"id": "claude-3-5-sonnet"}]}';
      expect(parseModelsResponse(LlmProvider.anthropic, body), [
        'claude-3-5-sonnet',
      ]);
    });

    test('the Gemini shape: models[].name, prefix stripped', () {
      const body =
          '{"models": [{"name": "models/gemini-2.0-flash"},'
          ' {"name": "models/gemini-2.5-pro"}]}';
      expect(parseModelsResponse(LlmProvider.google, body), [
        'gemini-2.0-flash',
        'gemini-2.5-pro',
      ]);
    });

    test('entries without an id are skipped, not fatal', () {
      const body = '{"data": [{"id": "one"}, {"object": "model"}]}';
      expect(parseModelsResponse(LlmProvider.openai, body), ['one']);
    });

    test('a body without the expected list throws, not empties', () {
      // An empty list is a success the panel would paint green; an
      // unparseable body is the opposite and must say so.
      expect(
        () => parseModelsResponse(LlmProvider.openai, '{"data": {}}'),
        throwsFormatException,
      );
      expect(
        () => parseModelsResponse(LlmProvider.google, '{"other": []}'),
        throwsFormatException,
      );
    });
  });

  group('the settings panel probe', () {
    Future<void> pump(
      WidgetTester tester, {
      required FakeModelsFetcher fetcher,
      double step = 1.0,
    }) => tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: amplifiedAppBuilder(step, child),
        ),
        home: Scaffold(
          body: SettingsPanel(
            usageSummary: const UsageSummary(
              turns: 0,
              totalTokens: 0,
              errorCount: 0,
              perModelTokens: {},
            ),
            onSaveCurrentToBook: () async {},
            onActivateSavedProvider: (_) async {},
            onDeleteSavedProvider: (_) async {},
            onReset: () async {},
            settings: const AppSettings(
              model: ModelSettings(apiKey: 'sk-live'),
            ),
            onSave: (_) async {},
            onClose: () {},
            onPickFolder: (_) async => null,
            supportPath: '/support',
            modelsFetcher: fetcher,
          ),
        ),
      ),
    );

    testWidgets('a successful probe says the count and fills the pick menu', (
      tester,
    ) async {
      final fetcher = FakeModelsFetcher(
        models: ['gpt-4o', 'o3-mini', 'gpt-4.1'],
      );
      await pump(tester, fetcher: fetcher);

      await tester.tap(find.text('Models'));
      await tester.pump();
      // The probe row is in the open editor card, behind the disclosure.
      await tester.tap(find.text('Test connection'));
      await tester.pump();

      expect(find.text('3 models available'), findsOneWidget);
      // The fetch asked about the draft: the saved provider, its default
      // endpoint, and the key the panel was handed.
      expect(fetcher.asks, hasLength(1));
      expect(fetcher.asks.single.provider, LlmProvider.openai);
      expect(fetcher.asks.single.baseUrl, defaultBaseUrl);
      expect(fetcher.asks.single.apiKey, 'sk-live');

      // The quick select lives inside the Customized disclosure.
      await tester.tap(find.text('Customized'));
      // The accordion animates its height, so one frame leaves the trigger
      // mid-flight and a tap there misses.
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.list));
      await tester.pumpAndSettle();
      expect(find.text('gpt-4o'), findsOneWidget);
      expect(find.text('o3-mini'), findsOneWidget);
    });

    // The quick-select is the settings surface's last popup nobody had laid out
    // amplified: it opens only over a fetch that landed, so the hosts without a
    // fetcher could not reach it. Its rows are the worst case for a one-line
    // label — a code font, no spaces to break at, and real endpoints answer
    // with names like `gpt-4.1-2024-10-21-preview`.
    group('amplified text', () {
      for (final (label, step) in const [
        ('1.8x', amplifiedTextStep),
        ('2.2x', nextTextStep),
      ]) {
        testWidgets('the pick menu keeps every id ($label)', (tester) async {
          // The editor card's rows grow with the step, so in the default 600px
          // window the quick-select button is at y 689.6 by 1.8x: the host has
          // to be tall enough to reach it, the same reason the settings walk
          // asks for one page.
          tester.view.physicalSize = const Size(1400, 6000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          await pump(
            tester,
            fetcher: FakeModelsFetcher(
              models: ['gpt-4o', 'o3-mini', 'gpt-4.1-2024-10-21-preview'],
            ),
            step: step,
          );

          await tester.tap(find.text('Models'));
          await tester.pump();
          await tester.tap(find.text('Test connection'));
          await tester.pump();
          await tester.tap(find.text('Customized'));
          await tester.pumpAndSettle();
          await tester.tap(find.byIcon(LucideIcons.list));
          await tester.pumpAndSettle();

          // The last row, not the first: the menu's height cap means a row the
          // list never built is a row the probe never saw.
          expect(find.text('gpt-4.1-2024-10-21-preview'), findsOneWidget);
          expect(textDefects(tester), isEmpty, reason: 'the pick menu');
          expect(tester.takeException(), isNull);
        });
      }
    });

    testWidgets('a failed probe reports the failure beside the button', (
      tester,
    ) async {
      final fetcher = FakeModelsFetcher(error: const HttpException('HTTP 401'));
      await pump(tester, fetcher: fetcher);

      await tester.tap(find.text('Models'));
      await tester.pump();
      await tester.tap(find.text('Test connection'));
      await tester.pump();

      expect(find.text('HTTP 401'), findsOneWidget);
      // No count painted on a failure.
      expect(find.textContaining('models available'), findsNothing);
    });

    testWidgets('no fetcher wired, no probe row at all', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: dswThemeData(Brightness.light),
          builder: (context, child) => ShadTheme(
            data: dswShadTheme(Theme.of(context).brightness),
            child: child!,
          ),
          home: Scaffold(
            body: SettingsPanel(
              usageSummary: const UsageSummary(
                turns: 0,
                totalTokens: 0,
                errorCount: 0,
                perModelTokens: {},
              ),
              onSaveCurrentToBook: () async {},
              onActivateSavedProvider: (_) async {},
              onDeleteSavedProvider: (_) async {},
              onReset: () async {},
              settings: const AppSettings(),
              onSave: (_) async {},
              onClose: () {},
              onPickFolder: (_) async => null,
              supportPath: '/support',
            ),
          ),
        ),
      );

      await tester.tap(find.text('Models'));
      await tester.pump();
      expect(find.text('Test connection'), findsNothing);
    });
  });
}
