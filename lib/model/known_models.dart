// A local catalog of well-known model ids and the one-line descriptions the
// composer's model menu shows beside them. The endpoint's `/models` response
// carries ids only — no human-readable name, no cost — so the menu would
// otherwise be a flat list of opaque strings. This table fills the gap for
// the ids the app's providers commonly serve; unknown ids fall back to a
// provider-shaped hint ("OpenAI-compatible model") rather than nothing.
//
// Kept in `lib/model/` so it sits beside `model_settings.dart` (the provider
// enum and default ids) — both are domain facts, not UI.

import 'model_settings.dart';

/// A one-line description for [modelId], or null when the id is not in the
/// catalog. The caller renders null as "no description" — the menu item
/// collapses to a single line rather than showing a placeholder.
String? descriptionForModel(String modelId) => _known[modelId];

/// The provider family label for the fallback line when [descriptionForModel]
/// returns null: "OpenAI-compatible model" etc. The menu uses this as the
/// second line for ids the catalog does not know — better a generic label
/// than an empty gap.
String providerFamilyLabel(LlmProvider provider) => switch (provider) {
  LlmProvider.openai => 'OpenAI-compatible model',
  LlmProvider.anthropic => 'Anthropic model',
  LlmProvider.google => 'Google AI model',
};

const Map<String, String> _known = {
  // DeepSeek (the shipped default provider)
  'deepseek-chat': 'DeepSeek-V3.2 — balanced general model',
  'deepseek-reasoner': 'DeepSeek-R1 — extended reasoning',
  // OpenAI
  'gpt-4o': 'GPT-4o — multimodal flagship',
  'gpt-4o-mini': 'GPT-4o mini — cost-efficient',
  'gpt-4.1': 'GPT-4.1 — latest generation',
  'gpt-4.1-mini': 'GPT-4.1 mini — balanced',
  'gpt-4.1-nano': 'GPT-4.1 nano — lightweight',
  'o3': 'o3 — advanced reasoning',
  'o4-mini': 'o4-mini — efficient reasoning',
  // Anthropic
  'claude-sonnet-4-5': 'Claude Sonnet 4.5 — balanced',
  'claude-sonnet-4-0': 'Claude Sonnet 4 — balanced',
  'claude-opus-4-0': 'Claude Opus 4 — most capable',
  'claude-haiku-4-0': 'Claude Haiku 4 — fast and affordable',
  // Google
  'gemini-2.5-flash': 'Gemini 2.5 Flash — fast and efficient',
  'gemini-2.5-pro': 'Gemini 2.5 Pro — most capable',
  'gemini-2.0-flash': 'Gemini 2.0 Flash — previous generation',
  // Qwen
  'qwen-max': 'Qwen Max — flagship',
  'qwen-plus': 'Qwen Plus — balanced',
  'qwen-turbo': 'Qwen Turbo — fast and affordable',
};
