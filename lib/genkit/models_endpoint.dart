// The models-endpoint fetch: the one live interrogation the settings panel
// can run against a provider before committing it.
//
// Modeled on IstiN/flutter_agent_harness's `ModelsEndpointFetcher` seam (see
// `AgentSettingsForm.modelsFetcher`): the panel owns an interface, the app
// hands it the HTTP implementation, tests hand it a fake. The parse is a
// pure function beside the fetcher so the response shapes — which differ
// per provider family — are testable without a socket.
//
// A fetched list answers two questions at once, which is why the panel's
// "Test connection" and its model quick-select share one call: a 200 with a
// list proves the endpoint AND the key, and the list itself is what the
// model field offers back.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../model/model_settings.dart';

/// Lists the model ids a configured endpoint serves.
abstract interface class ModelsEndpointFetcher {
  /// [provider] decides the auth header shape; [baseUrl] and [apiKey] are the
  /// draft's own values, trimmed by the caller. Throws on transport or
  /// non-2xx answers — the caller renders the failure beside the button that
  /// caused it rather than as a dialog.
  Future<List<String>> listModels({
    required LlmProvider provider,
    required String baseUrl,
    required String apiKey,
  });
}

/// The production fetcher: `dart:io HttpClient`, ten-second timeout, one
/// request. No retry, no cache — this is a probe the user asked for, and a
/// stale list is worse than a missing one.
final class HttpModelsEndpointFetcher implements ModelsEndpointFetcher {
  const HttpModelsEndpointFetcher();

  static const _timeout = Duration(seconds: 10);

  @override
  Future<List<String>> listModels({
    required LlmProvider provider,
    required String baseUrl,
    required String apiKey,
  }) async {
    final uri = _modelsUri(provider, baseUrl);
    if (uri == null) {
      throw UnsupportedError('no models endpoint for $baseUrl');
    }
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      switch (provider) {
        // The OpenAI-compatible family: `Authorization: Bearer`.
        case LlmProvider.openai:
          request.headers.set(
            HttpHeaders.authorizationHeader,
            'Bearer $apiKey',
          );
        // Anthropic's own shape: the key in its header, plus the pinned
        // version the API refuses to answer without.
        case LlmProvider.anthropic:
          request.headers.set('x-api-key', apiKey);
          request.headers.set('anthropic-version', '2023-06-01');
        // Gemini's shape: the key as a query parameter.
        case LlmProvider.google:
          break; // already on the uri
      }
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        // 401/403 is the answer a mistyped key earns; anything else is the
        // endpoint's own complaint. Either way the status code is the most
        // useful sentence available.
        throw HttpException(
          'HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(_timeout);
      return parseModelsResponse(provider, body);
    } finally {
      client.close(force: true);
    }
  }

  /// The `/models` seat for [baseUrl], or null when the URL cannot host one
  /// (unparseable, or no host).
  static Uri? _modelsUri(LlmProvider provider, String baseUrl) {
    final parsed = Uri.tryParse(baseUrl);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return null;
    }
    final path = parsed.path.replaceAll(RegExp(r'/+$'), '');
    final modelsPath = path.isEmpty ? '/models' : '$path/models';
    return parsed.replace(path: modelsPath);
  }
}

/// Pulls the model ids out of a `/models` response body — pure, so the three
/// families' shapes are pinned by tests:
///
///  * OpenAI-compatible and Anthropic: `{"data": [{"id": ...}, ...]}`
///  * Google Gemini: `{"models": [{"name": "models/gemini-..."}]}`
///
/// Unreadable bodies throw FormatException — a list the panel cannot trust
/// is worth less than the error that says why.
List<String> parseModelsResponse(LlmProvider provider, String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('models response is not an object');
  }
  switch (provider) {
    case LlmProvider.openai:
    case LlmProvider.anthropic:
      final data = decoded['data'];
      if (data is! List) {
        throw const FormatException('models response has no "data" list');
      }
      return [
        for (final entry in data)
          if (entry is Map<String, dynamic> && entry['id'] is String)
            entry['id'] as String,
      ];
    case LlmProvider.google:
      final models = decoded['models'];
      if (models is! List) {
        throw const FormatException('models response has no "models" list');
      }
      return [
        for (final entry in models)
          if (entry is Map<String, dynamic> && entry['name'] is String)
            // "models/gemini-2.0-flash" → "gemini-2.0-flash": the field
            // holds a wire id, and the user picks one to paste there.
            (entry['name'] as String).replaceFirst(RegExp(r'^models/'), ''),
      ];
  }
}
