// Diagnostic log vocabulary (ADR-0058): what one model call did, and what
// one model request actually carried. Pure Dart — the runtime builds these
// at the model seam and hands them out through [DiagnosticHooks]; the store
// in lib/state persists them. Same layering as `TurnUsage`.

/// One settled model call — the requests log line (ADR-0058 S1). One line
/// per model call, not per turn: a turn with a tool loop produces several,
/// which is exactly the "why was this turn slow" evidence.
class ModelCallRecord {
  const ModelCallRecord({
    required this.timestamp,
    required this.model,
    required this.durationMs,
    required this.ok,
    this.error,
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
  });

  factory ModelCallRecord.fromJson(Map<String, Object?> json) =>
      ModelCallRecord(
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        model: json['model'] as String? ?? '',
        durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
        ok: json['ok'] != false,
        error: json['error'] as String?,
        inputTokens: (json['inputTokens'] as num?)?.toInt(),
        outputTokens: (json['outputTokens'] as num?)?.toInt(),
        totalTokens: (json['totalTokens'] as num?)?.toInt(),
      );

  final int timestamp;
  final String model;
  final int durationMs;
  final bool ok;

  /// The failure's own words, truncated by the capture site.
  final String? error;

  /// The provider's usage block, absent when it reported nothing.
  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp,
    'model': model,
    'durationMs': durationMs,
    'ok': ok,
    if (error != null) 'error': error,
    if (inputTokens != null) 'inputTokens': inputTokens,
    if (outputTokens != null) 'outputTokens': outputTokens,
    if (totalTokens != null) 'totalTokens': totalTokens,
  };
}

/// What one model request carried — the contexts log line (ADR-0058 S2).
/// Text keeps its whole words; tool payloads are capped by the capture
/// site; media bytes never land on disk at all.
class ContextSnapshotRecord {
  const ContextSnapshotRecord({
    required this.timestamp,
    required this.model,
    required this.messages,
  });

  factory ContextSnapshotRecord.fromJson(Map<String, Object?> json) =>
      ContextSnapshotRecord(
        timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
        model: json['model'] as String? ?? '',
        messages: [
          for (final entry in (json['messages'] as List? ?? const []))
            if (entry is Map<String, Object?>) ContextMessage.fromJson(entry),
        ],
      );

  final int timestamp;
  final String model;
  final List<ContextMessage> messages;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp,
    'model': model,
    'messages': [for (final message in messages) message.toJson()],
  };
}

/// One message of a context snapshot: role plus the parts as serialized.
class ContextMessage {
  const ContextMessage({required this.role, required this.parts});

  factory ContextMessage.fromJson(Map<String, Object?> json) => ContextMessage(
    role: json['role'] as String? ?? '',
    parts: [
      for (final entry in (json['parts'] as List? ?? const []))
        if (entry is Map<String, Object?>) ContextPart.fromJson(entry),
    ],
  );

  final String role;
  final List<ContextPart> parts;

  Map<String, Object?> toJson() => {
    'role': role,
    'parts': [for (final part in parts) part.toJson()],
  };
}

/// One part of a context message. [kind] is the dispatch answer — `text`,
/// `reasoning`, `toolRequest`, `toolResponse`, `media`, `data`, `custom`,
/// or `other` for a part type this capture does not know yet. [text] holds
/// prose; [name] and [payload] hold tool identity and truncated JSON;
/// [elided] marks a value the capture replaced with a placeholder.
class ContextPart {
  const ContextPart({
    required this.kind,
    this.text,
    this.name,
    this.payload,
    this.elided = false,
  });

  factory ContextPart.fromJson(Map<String, Object?> json) => ContextPart(
    kind: json['kind'] as String? ?? 'other',
    text: json['text'] as String?,
    name: json['name'] as String?,
    payload: json['payload'],
    elided: json['elided'] == true,
  );

  final String kind;
  final String? text;
  final String? name;
  final Object? payload;
  final bool elided;

  Map<String, Object?> toJson() => {
    'kind': kind,
    if (text != null) 'text': text,
    if (name != null) 'name': name,
    if (payload != null) 'payload': payload,
    if (elided) 'elided': true,
  };
}

/// The seams the runtime calls — held by the composition root, which owns
/// the enable switches (live reads; a toggle must not rebuild the runtime)
/// and the store. Runtime-never-touches-state is unchanged: these are
/// function values, the `CheckpointSink` shape.
class DiagnosticHooks {
  const DiagnosticHooks({
    required this.requestEnabled,
    required this.contextEnabled,
    required this.onRequest,
    required this.onContext,
  });

  final bool Function() requestEnabled;
  final bool Function() contextEnabled;
  final void Function(ModelCallRecord record) onRequest;
  final void Function(ContextSnapshotRecord record) onContext;
}
