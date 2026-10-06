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

/// One scheduled task (ADR-0069): minute-of-day + weekday-mask schedule.
class ScheduledTaskRows extends Table {
  @override
  String get tableName => 'scheduled_tasks';

  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get prompt => text()();
  IntColumn get hour => integer()();
  IntColumn get minute => integer()();
  IntColumn get weekdaysMask => integer().withDefault(const Constant(0))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  IntColumn get lastRunAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One fire of a scheduled task (ADR-0069): outcome and a 200-char preview.
class ScheduledTaskRunRows extends Table {
  @override
  String get tableName => 'scheduled_task_runs';

  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskId => text()();
  IntColumn get startedAt => integer()();
  BoolColumn get ok => boolean()();
  TextColumn get preview => text().withDefault(const Constant(''))();
}

/// The plan space's single meta row (ADR-0071): revision and the recycle
/// bin's id list. Content rows live in [PlanRecordRows].
class PlanSpaceMetaRows extends Table {
  @override
  String get tableName => 'plan_space_meta';

  TextColumn get id => text()();
  IntColumn get revision => integer()();
  TextColumn get bin => text().withDefault(const Constant('[]'))();

  /// Which generation of the demo seed this space came from (ADR-0074): 0 =
  /// pre-seed-version (the original English mock), 2 = the localized seed.
  /// A one-time re-seed reads it to decide whether the demo furniture should
  /// be refreshed to the user's language.
  IntColumn get seedVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One record of the plan space (ADR-0071): six collections in one table,
/// partitioned by kind. The payload stays the model's hand-written JSON —
/// columnizing Anytype's Struct view here would put the data model in two
/// places (ADR-0037).
class PlanRecordRows extends Table {
  @override
  String get tableName => 'plan_records';

  TextColumn get kind => text()();
  TextColumn get id => text()();
  TextColumn get payload => text()();

  @override
  Set<Column> get primaryKey => {kind, id};
}

@DriftDatabase(
  tables: [
    UsageRows,
    ScheduledTaskRows,
    ScheduledTaskRunRows,
    PlanSpaceMetaRows,
    PlanRecordRows,
  ],
)
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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE INDEX usage_rows_timestamp ON usage_rows (timestamp)',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(scheduledTaskRows);
        await m.createTable(scheduledTaskRunRows);
      }
      if (from < 3) {
        await m.createTable(planSpaceMetaRows);
        await m.createTable(planRecordRows);
      }
      if (from < 4) {
        await m.addColumn(planSpaceMetaRows, planSpaceMetaRows.seedVersion);
      }
    },
  );
}
