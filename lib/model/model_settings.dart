// Which model to talk to, and with what credentials.
//
// Kept out of `lib/genkit/` so the settings screen and the persistence code can
// use it without importing the runtime.

/// Which genkit provider plugin backs the runtime.
enum LlmProvider {
  /// Any OpenAI-compatible endpoint (the shipped default: DeepSeek).
  openai,

  /// Anthropic's own API.
  anthropic,

  /// Google AI (Gemini).
  google;

  static LlmProvider fromName(String? name) => switch (name) {
    'anthropic' => anthropic,
    'google' => google,
    _ => openai,
  };
}

/// DeepSeek's OpenAI-compatible endpoint, which is what the app ships pointed at.
const defaultBaseUrl = 'https://api.deepseek.com/v1';

/// The general chat model. `deepseek-reasoner` is the other obvious choice and
/// works too — its chain of thought arrives on the reasoning channel.
const defaultModel = 'deepseek-chat';

/// The per-provider field defaults applied when the settings screen switches
/// provider: connection fields belong to a provider, so changing it resets
/// them rather than letting a DeepSeek URL leak into an Anthropic client.
String defaultBaseUrlFor(LlmProvider provider) => switch (provider) {
  // An OpenAI-compatible stand-in for any endpoint; empty means "the plugin's
  // own default".
  LlmProvider.openai => defaultBaseUrl,
  _ => '',
};

/// The model the composer offers first per provider.
String defaultModelFor(LlmProvider provider) => switch (provider) {
  LlmProvider.openai => defaultModel,
  LlmProvider.anthropic => 'claude-sonnet-4-5',
  LlmProvider.google => 'gemini-2.5-flash',
};

class ModelSettings {
  const ModelSettings({
    this.provider = LlmProvider.openai,
    this.apiKey = '',
    this.baseUrl = defaultBaseUrl,
    this.model = defaultModel,
  });

  ModelSettings.fromJson(Map<String, dynamic> json)
    : provider = LlmProvider.fromName(json['provider'] as String?),
      apiKey = json['apiKey'] as String? ?? '',
      baseUrl = json['baseUrl'] as String? ?? defaultBaseUrl,
      model = json['model'] as String? ?? defaultModel;

  final LlmProvider provider;

  /// Never written into the repository or into assets — see
  /// `ui/settings/model_settings.dart` for where it is stored.
  final String apiKey;

  /// Empty means the provider's own default endpoint; only the OpenAI-compatible
  /// path ships a non-empty default.
  final String baseUrl;

  final String model;

  /// False on first launch, which is why the composer starts disabled.
  bool get isConfigured => apiKey.trim().isNotEmpty;

  /// Returns [settings] with the connection fields reset to [provider]'s
  /// defaults, for the settings screen's provider switch.
  ModelSettings forProvider(LlmProvider provider) => ModelSettings(
    provider: provider,
    apiKey: '',
    baseUrl: defaultBaseUrlFor(provider),
    model: defaultModelFor(provider),
  );

  ModelSettings copyWith({
    LlmProvider? provider,
    String? apiKey,
    String? baseUrl,
    String? model,
  }) => ModelSettings(
    provider: provider ?? this.provider,
    apiKey: apiKey ?? this.apiKey,
    baseUrl: baseUrl ?? this.baseUrl,
    model: model ?? this.model,
  );

  Map<String, dynamic> toJson() => {
    'provider': provider.name,
    'apiKey': apiKey,
    'baseUrl': baseUrl,
    'model': model,
  };

  /// The runtime bakes all of these into a registered agent and a plugin's
  /// HTTP client, so any change at all means disposing that runtime and building
  /// another. Spelled out as a named question rather than left to `!=` at the
  /// call site, because the reason is not visible from there.
  bool requiresRestart(ModelSettings other) => other != this;

  @override
  bool operator ==(Object other) =>
      other is ModelSettings &&
      other.provider == provider &&
      other.apiKey == apiKey &&
      other.baseUrl == baseUrl &&
      other.model == model;

  @override
  int get hashCode => Object.hash(provider, apiKey, baseUrl, model);
}
