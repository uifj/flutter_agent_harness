// The app's relational store (ADR-0060): one drift database at
// `<support>/planstar.db`, one table per domain, schemaVersion migrations.
//
// drift is the second authorized code generator (riverpod's annotations were
// the first, ADR-0002 rev 1) — the table classes below need `drift_dev` via
// `build_runner`, and the generated `app_database.g.dart` is committed the
// same way `app_providers.g.dart` is. Everything the store gains — indexes,
// range deletes, GROUP BY aggregation — lives in SQL; the Dart vocabulary the
// UI reads stays in plain model classes.
//
// What deliberately does NOT live here yet: sessions.json (a sync contract by
// design, ADR-0039), the diagnostics JSONL streams (append-only files are the
// right tool), the settings/prefs documents (small, with their own versioned
// migration). ADR-0060 lists the candidates and the reasons.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'app_database.g.dart';

/// One recorded model turn (ADR-0045 PC → ADR-0060). Same fields as
/// `UsageEntry`; the timestamp carries the index (created in the migration
/// below — the resolved drift_dev lags the runtime and will not take
/// `@TableIndex`) because every read and every prune walks the window.
class UsageRows extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get timestamp => integer()();
  TextColumn get model => text()();
  IntColumn get inputTokens => integer()();
  IntColumn get outputTokens => integer()();
  IntColumn get reasoningTokens => integer().withDefault(const Constant(0))();
  BoolColumn get error => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [UsageRows])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  /// Opens (and creates) the database file. Lazy: the file materializes on
  /// the first query, so a bare runtime in a test never touches the disk.
  AppDatabase.open(File file)
    : super(
        LazyDatabase(() async {
          return NativeDatabase(file);
        }),
      );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX usage_rows_timestamp ON usage_rows (timestamp)',
      );
    },
  );
}
