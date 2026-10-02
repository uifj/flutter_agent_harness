// Local usage ledger (ADR-0045 PC): one JSONL file per month under
// `<support>/usage/`, one line per model turn, 30-day prune after every
// append (the same retention stance as ZCode's usage tables —
// `usage.ts:17-18`). The aggregation is a pure function so the settings
// section can render it without re-reading between saves.

import 'dart:convert';
import 'dart:io';

/// One recorded model turn.
class UsageEntry {
  const UsageEntry({
    required this.timestamp,
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    this.reasoningTokens = 0,
    this.error = false,
  });

  factory UsageEntry.fromJson(Map<String, Object?> json) => UsageEntry(
    timestamp: (json['timestamp'] as num?)?.toInt() ?? 0,
    model: json['model'] as String? ?? '',
    inputTokens: (json['inputTokens'] as num?)?.toInt() ?? 0,
    outputTokens: (json['outputTokens'] as num?)?.toInt() ?? 0,
    reasoningTokens: (json['reasoningTokens'] as num?)?.toInt() ?? 0,
    error: json['error'] == true,
  );

  final int timestamp;
  final String model;
  final int inputTokens;
  final int outputTokens;
  final int reasoningTokens;
  final bool error;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp,
    'model': model,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    if (reasoningTokens > 0) 'reasoningTokens': reasoningTokens,
    if (error) 'error': true,
  };

  int get totalTokens => inputTokens + outputTokens + reasoningTokens;
}

/// The lifetime aggregates the settings section renders — a local subset of
/// ZCode's snapshot (`usage-stats.ts:170-251`): tokens and counts, no cost.
class UsageSummary {
  const UsageSummary({
    required this.turns,
    required this.totalTokens,
    required this.errorCount,
    required this.perModelTokens,
  });

  final int turns;
  final int totalTokens;
  final int errorCount;
  final Map<String, int> perModelTokens;

  /// Error rate over recorded turns, 0 when there is nothing yet.
  double get errorRate => turns == 0 ? 0 : errorCount / turns;
}

/// Appends and prunes. The file is `<support>/usage/usage-YYYYMM.jsonl`.
class UsageLedger {
  UsageLedger({required Directory directory, this.retentionDays = 30})
    : _directory = directory;

  final Directory _directory;
  final int retentionDays;

  Future<void> record(UsageEntry entry) async {
    await _directory.create(recursive: true);
    final month = DateTime.fromMillisecondsSinceEpoch(
      entry.timestamp,
      isUtc: true,
    );
    final file = File(
      '${_directory.path}/usage-${month.year}${_two(month.month)}.jsonl',
    );
    await file.writeAsString(
      '${jsonEncode(entry.toJson())}\n',
      mode: FileMode.append,
      flush: true,
    );
    cache.add(entry);
    await prune();
  }

  /// Deletes entries older than [retentionDays] by rewriting the affected
  /// monthly files; the ledger never grows past the window.
  Future<void> prune({DateTime? now}) async {
    final cutoff =
        (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch -
        retentionDays * 86400000;
    if (!await _directory.exists()) return;
    for (final file in await _directory.list().toList().then(
      (entries) => entries.whereType<File>(),
    )) {
      if (!file.path.contains('usage-') || !file.path.endsWith('.jsonl')) {
        continue;
      }
      final kept = <String>[];
      for (final line in await file.readAsLines()) {
        if (line.trim().isEmpty) continue;
        try {
          final entry = UsageEntry.fromJson(
            jsonDecode(line) as Map<String, Object?>,
          );
          if (entry.timestamp >= cutoff) kept.add(line);
        } on FormatException {
          // A torn tail line from a killed process: drop it, the next entry
          // starts a fresh line.
        }
      }
      if (kept.isEmpty) {
        await file.delete();
      } else {
        await file.writeAsString('${kept.join('\n')}\n', flush: true);
      }
    }
  }

  /// Every surviving entry, oldest first — [summarize] folds it.
  Future<List<UsageEntry>> entries() async {
    if (!await _directory.exists()) return const [];
    final files =
        (await _directory.list().toList())
            .whereType<File>()
            .where(
              (file) =>
                  file.path.contains('usage-') && file.path.endsWith('.jsonl'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final entries = <UsageEntry>[];
    for (final file in files) {
      for (final line in await file.readAsLines()) {
        if (line.trim().isEmpty) continue;
        try {
          entries.add(
            UsageEntry.fromJson(jsonDecode(line) as Map<String, Object?>),
          );
        } on FormatException {
          // Same torn-tail rule as prune.
        }
      }
    }
    return entries;
  }

  /// The entries read at open time, kept so the settings screen can render a
  /// summary synchronously; [record] appends to both the file and this list.
  final List<UsageEntry> cache = [];

  static UsageSummary summarize(List<UsageEntry> entries) {
    final perModel = <String, int>{};
    var errors = 0;
    var total = 0;
    for (final entry in entries) {
      perModel[entry.model] = (perModel[entry.model] ?? 0) + entry.totalTokens;
      total += entry.totalTokens;
      if (entry.error) errors++;
    }
    return UsageSummary(
      turns: entries.length,
      totalTokens: total,
      errorCount: errors,
      perModelTokens: perModel,
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
