// ADR-0085 D3's migration reads the retired `<support>/usage/usage.db` through
// a second AppDatabase handle. drift's double-instantiation check compares the
// CLASS, not the file, so on a machine still holding a legacy db the boot log
// printed the very warning D3 was filed to remove — found by running the app on
// macOS, not by the suite.
//
// One test in one file on purpose: drift counts instances in process-global
// state, and `flutter test` gives each file its own isolate. In a file where
// other tests already opened and closed databases the counter can sit below the
// threshold, so the guard would pass for the wrong reason.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/state/app_database.dart';
import 'package:planstar/state/usage_ledger.dart';

void main() {
  test(
    'the one-shot legacy read does not log a double-instantiation warning',
    () async {
      final root = await Directory.systemTemp.createTemp('usage_migration');
      addTearDown(() => root.delete(recursive: true));
      final dir = Directory('${root.path}/usage')..createSync(recursive: true);
      final legacyFile = File('${dir.path}/usage.db');
      // drift opens its connection lazily: a handle that never ran a query
      // leaves no file behind, and then the migration has nothing to read.
      final seed = AppDatabase.open(legacyFile);
      await seed
          .into(seed.usageRows)
          .insert(
            UsageRowsCompanion.insert(
              timestamp: 1000,
              model: 'old',
              inputTokens: 2,
              outputTokens: 1,
            ),
          );
      await seed.close();
      expect(legacyFile.existsSync(), isTrue);

      final warnings = <String>[];
      final printer = driftRuntimeOptions.debugPrint;
      driftRuntimeOptions.debugPrint = warnings.add;
      final db = AppDatabase.open(File('${root.path}/planstar.db'));
      try {
        await UsageLedger(db, legacyDirectory: dir).entries();
        expect(
          warnings.where((w) => w.contains('multiple times')),
          isEmpty,
          reason:
              'two handles over two files is the migration, not a shared '
              'executor — the boot log must not claim otherwise',
        );
        // A quiet log would also be a vacuous one: the read really ran.
        expect(legacyFile.existsSync(), isFalse);
      } finally {
        driftRuntimeOptions.debugPrint = printer;
        await db.close();
      }
    },
  );
}
