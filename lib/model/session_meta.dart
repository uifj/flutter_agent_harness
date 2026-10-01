// What a conversation cannot answer about itself (ADR-0039 D1).
//
// genkit owns the session document, so the app gets to add nothing to it
// (invariant 1) — and the title already has its truth inside the snapshot
// (`sessionTitle(messages)` in `genkit/agent_runtime.dart`). This record holds
// exactly the four things a snapshot cannot carry, and nothing else: which
// folder the run happened in, whether the user pinned it, whether the user
// deleted it, and what the user chose to call it.
//
// `title` is an *override*, not a second title. `SessionIndex` resolves
// `override ?? derived` in one place, so no surface downstream ever has to
// pick between two candidates — the failure ADR-0014 names as "two fields that
// must be equal".

/// One session's app-side metadata, keyed by session id in `sessions.json`.
class SessionMeta {
  const SessionMeta({
    this.workspaceRoot,
    this.pinnedAt,
    this.deletedAt,
    this.title,
  });

  factory SessionMeta.fromJson(Map<String, dynamic> json) => SessionMeta(
    workspaceRoot: json['workspaceRoot'] as String?,
    pinnedAt: _time(json['pinnedAt']),
    deletedAt: _time(json['deletedAt']),
    title: (json['title'] as String?)?.trim().isEmpty ?? false
        ? null
        : json['title'] as String?,
  );

  final String? workspaceRoot;
  final DateTime? pinnedAt;
  final DateTime? deletedAt;
  final String? title;

  /// A tombstone, not a removal: the snapshot stays on disk (ADR-0039 D4).
  bool get isDeleted => deletedAt != null;

  Map<String, dynamic> toJson() => {
    if (workspaceRoot != null) 'workspaceRoot': workspaceRoot,
    if (pinnedAt != null) 'pinnedAt': pinnedAt!.toIso8601String(),
    if (deletedAt != null) 'deletedAt': deletedAt!.toIso8601String(),
    if (title != null) 'title': title,
  };

  SessionMeta copyWith({
    String? workspaceRoot,
    DateTime? pinnedAt,
    DateTime? deletedAt,
    String? title,
  }) => SessionMeta(
    workspaceRoot: workspaceRoot ?? this.workspaceRoot,
    pinnedAt: pinnedAt ?? this.pinnedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    title: title ?? this.title,
  );
}

DateTime? _time(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;
