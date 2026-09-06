// The model directory: the composer's model seat's catalog and selection.
//
// Driven through the `ModelsEndpointFetcher` seam with a fake — the same seam
// the app hands its HTTP fetcher. What is pinned here is the contract: the
// default survives every failure, a provider switch resets the catalog, and
// a refresh the provider abandoned cannot land.

import 'dart:io' show HttpException;

import 'package:agent_harness/genkit/models_endpoint.dart';
import 'package:agent_harness/model/model_settings.dart';
import 'package:agent_harness/state/model_directory.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFetcher implements ModelsEndpointFetcher {
  FakeFetcher({this.models = const [], this.error});

  final List<String> models;
  final Object? error;

  int calls = 0;

  @override
  Future<List<String>> listModels({
    required LlmProvider provider,
    required String baseUrl,
    required String apiKey,
  }) async {
    calls++;
    if (error != null) throw error!;
    return models;
  }
}

void main() {
  // The document's own default model — `ModelSettings` fills an empty model
  // field with the provider default, so the fixture names it directly.
  const selected = defaultModel;
  const connection = ModelSettings(
    apiKey: 'sk-live',
    baseUrl: 'https://example.test/v1',
  );

  ModelDirectory directoryWith(FakeFetcher fetcher) {
    final directory = ModelDirectory(current: connection, fetcher: fetcher);
    directory.adoptConnection(
        baseUrl: connection.baseUrl, apiKey: connection.apiKey);
    return directory;
  }

  group('the catalog', () {
    test('starts at the provider default alone', () {
      final directory = ModelDirectory(current: connection);
      expect(directory.models, hasLength(1));
      expect(directory.models.single.id, selected);
      expect(directory.models.single.fetched, isFalse);
      expect(directory.selectedModel, selected);
    });

    test('a refresh puts the fetched list after the default, deduped',
        () async {
      final fetcher = FakeFetcher(models: ['m-two', selected, 'm-one']);
      final directory = directoryWith(fetcher);

      await directory.refresh();

      expect(
        directory.models.map((m) => m.id),
        [selected, 'm-two', 'm-one'],
      );
      // Only the fetched entries claim the "listed" mark.
      expect(directory.models.first.fetched, isFalse);
      expect(directory.models[1].fetched, isTrue);
      expect(fetcher.calls, 1);
    });

    test('a failed refresh keeps the default and reports the failure',
        () async {
      final fetcher = FakeFetcher(error: const HttpException('HTTP 403'));
      final directory = directoryWith(fetcher);

      await directory.refresh();

      expect(directory.models, hasLength(1));
      expect(directory.loadError, 'HTTP 403');
      expect(directory.isLoading, isFalse);
    });

    test('no fetcher, no refresh — the default just stays', () async {
      final directory = ModelDirectory(current: connection);
      await directory.refresh();
      expect(directory.models, hasLength(1));
    });

    test('no key on file, the endpoint is not asked', () async {
      final fetcher = FakeFetcher(models: ['m-one']);
      final directory = ModelDirectory(
        current: connection.copyWith(apiKey: ''),
        fetcher: fetcher,
      );
      directory.adoptConnection(baseUrl: connection.baseUrl, apiKey: '');

      await directory.refresh();

      expect(fetcher.calls, 0);
      expect(directory.models, hasLength(1));
    });
  });

  group('adoption', () {
    test('a provider switch resets the catalog to the new default', () async {
      final fetcher = FakeFetcher(models: ['m-fetched']);
      final directory = directoryWith(fetcher);
      // Seed a fetched catalog for the old provider.
      await directory.refresh();
      expect(directory.models, hasLength(2));

      directory.adopt(connection.forProvider(LlmProvider.anthropic));

      expect(directory.provider, LlmProvider.anthropic);
      expect(directory.models.single.fetched, isFalse);
      expect(directory.selectedModel,
          defaultModelFor(LlmProvider.anthropic));
    });

    test('a same-provider save keeps the fetched catalog', () async {
      final fetcher = FakeFetcher(models: ['m-fetched']);
      final directory = directoryWith(fetcher);
      await directory.refresh();
      expect(directory.models, hasLength(2));

      directory.adopt(connection.copyWith(model: 'm-fetched'));
      // The catalog survives a save that only moved the selection.
      expect(directory.models, hasLength(2));
      expect(directory.selectedModel, 'm-fetched');
    });
  });

  group('the selection', () {
    test('selecting moves the check mark', () {
      final directory = ModelDirectory(current: connection);
      directory.select('other-model');
      expect(directory.selectedModel, 'other-model');
    });

    test('selecting the current model is a no-op (no notify)', () {
      final directory = ModelDirectory(current: connection);
      var notifications = 0;
      directory.addListener(() => notifications++);
      directory.select(selected);
      expect(notifications, 0);
    });
  });
}
