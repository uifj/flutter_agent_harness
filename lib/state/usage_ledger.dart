// Local usage ledger (ADR-0045 PC, carried into drift by ADR-0060, sharing the
// app's single database by ADR-0085 D3): rows in `<support>/planstar.db`'s
// usage_rows table, one per model turn, 30-day prune after every append.
// Aggregation is a pure fold so the settings section can render without
// re-reading; the heavy lifting (window delete, ordered read) lives in SQL.
//
// Two legacy shapes import once on first use and are retired: the JSONL era's
// `usage-YYYYMM.jsonl` files and ADR-0060's standalone `<legacy>/usage.db`.
// A crash between import and deletion can double-count a few rows inside the
// 30-day window, which is a bounded harm against losing the old totals.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import 'app_database.dart';

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

/// Appends and prunes against the app's single database (ADR-0085 D3) — the
/// rows live in the shared `usage_rows` table next to every other domain.
/// [legacyDirectory], when given, is scanned once for the pre-merge shapes
/// (monthly JSONL files, then a standalone `usage.db`), imported, and retired.
class UsageLedger {
  UsageLedger(
    AppDatabase db, {
    Directory? legacyDirectory,
    this.retentionDays = 30,
  }) : _db = db,
       _legacyDirectory = legacyDirectory {
    // One import, started at construction, awaited by every reader below —
    // so the first `record` cannot land ahead of the rows it would skew.
    _imported = _importLegacy();
  }

  final AppDatabase _db;
  final Directory? _legacyDirectory;
  final int retentionDays;
  late final Future<void> _imported;

  Future<void> record(UsageEntry entry) async {
    await _imported;
    await _db
        .into(_db.usageRows)
        .insert(
          UsageRowsCompanion.insert(
            timestamp: entry.timestamp,
            model: entry.model,
            inputTokens: entry.inputTokens,
            outputTokens: entry.outputTokens,
            reasoningTokens: Value(entry.reasoningTokens),
            error: Value(entry.error),
          ),
        );
    cache.add(entry);
    await prune();
  }

  /// Deletes rows older than [retentionDays]; the ledger never grows past
  /// the window. What used to be a file rewrite is one indexed DELETE.
  Future<void> prune({DateTime? now}) async {
    await _imported;
    final cutoff =
        (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch -
        retentionDays * 86400000;
    await (_db.delete(
      _db.usageRows,
    )..where((row) => row.timestamp.isSmallerThanValue(cutoff))).go();
  }

  /// Every surviving row, oldest first — [summarize] folds it.
  Future<List<UsageEntry>> entries() async {
    await _imported;
    final rows = await (_db.select(
      _db.usageRows,
    )..orderBy([(row) => OrderingTerm(expression: row.timestamp)])).get();
    return [
      for (final row in rows)
        UsageEntry(
          timestamp: row.timestamp,
          model: row.model,
          inputTokens: row.inputTokens,
          outputTokens: row.outputTokens,
          reasoningTokens: row.reasoningTokens,
          error: row.error,
        ),
    ];
  }

  /// The entries read at open time, kept so the settings screen can render a
  /// summary synchronously; [record] appends to both the database and this
  /// list.
  final List<UsageEntry> cache = [];

  /// Imports the pre-merge shapes, oldest format first: the monthly JSONL
  /// files (ADR-0060), then ADR-0085 D3's standalone `usage.db`. Each source
  /// is read, inserted, and deleted per source, so a torn line only costs its
  /// own tail and a crash mid-import bounds the double-count to the 30-day
  /// window. A file that cannot be parsed at all is deleted unread: the same
  /// "corrupt metadata must not brick the app" stance `SettingsStore.open`
  /// takes.
  Future<void> _importLegacy() async {
    await _importLegacyJsonl();
    await _importLegacyUsageDb();
  }

  Future<void> _importLegacyUsageDb() async {
    final directory = _legacyDirectory;
    if (directory == null) return;
    final file = File('${directory.path}/usage.db');
    if (!await file.exists()) return;
    // drift's double-instantiation check keys on the database CLASS, so this
    // one-shot read of a *different file* looks like the second live connection
    // it was filed to warn about (ADR-0085 D3's whole point). The flag is the
    // library's sanctioned answer; it is set around this handle only and
    // restored in the `finally`, so a genuine second connection elsewhere in the
    // app still logs the warning.
    final warnedBefore = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    final legacy = AppDatabase.open(file);
    try {
      final rows = await legacy.select(legacy.usageRows).get();
      for (final row in rows) {
        await _db
            .into(_db.usageRows)
            .insert(
              UsageRowsCompanion.insert(
                timestamp: row.timestamp,
                model: row.model,
                inputTokens: row.inputTokens,
                outputTokens: row.outputTokens,
                reasoningTokens: Value(row.reasoningTokens),
                error: Value(row.error),
              ),
            );
      }
    } finally {
      await legacy.close();
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = warnedBefore;
    }
    await file.delete();
  }

  Future<void> _importLegacyJsonl() async {
    final directory = _legacyDirectory;
    if (directory == null || !await directory.exists()) return;
    final files =
        (await directory.list().toList())
            .whereType<File>()
            .where(
              (file) =>
                  file.uri.pathSegments.last.startsWith('usage-') &&
                  file.uri.pathSegments.last.endsWith('.jsonl'),
            )
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) return;
    for (final file in files) {
      final entries = <UsageEntry>[];
      try {
        for (final line in await file.readAsLines()) {
          if (line.trim().isEmpty) continue;
          try {
            entries.add(
              UsageEntry.fromJson(jsonDecode(line) as Map<String, Object?>),
            );
          } on FormatException {
            // A torn tail line from a killed process: drop it, the next
            // entry starts a fresh line — the JSONL era's own rule.
          }
        }
      } on FileSystemException {
        // Unreadable: skip the file, leave it in place for a later boot.
        continue;
      }
      for (final entry in entries) {
        await _db
            .into(_db.usageRows)
            .insert(
              UsageRowsCompanion.insert(
                timestamp: entry.timestamp,
                model: entry.model,
                inputTokens: entry.inputTokens,
                outputTokens: entry.outputTokens,
                reasoningTokens: Value(entry.reasoningTokens),
                error: Value(entry.error),
              ),
            );
      }
      await file.delete();
    }
  }

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
}
