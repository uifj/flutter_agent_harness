// ADR-0045 PC guards: the crash archive keeps the newest N and nothing more,
// the usage ledger rides a 30-day window and never grows past it, and the
// summary is the pure fold the settings page renders.

import 'dart:convert';
import 'dart:io';

import 'package:planstar/state/crash_archive.dart';
import 'package:planstar/state/usage_ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('production_ops');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  group('CrashArchive', () {
    test(
      'writes self-describing reports and prunes to the newest five',
      () async {
        final archive = CrashArchive(
          directory: Directory('${root.path}/logs/crash'),
          maxFiles: 5,
        );
        for (var i = 0; i < 7; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
          await archive.write('flutter', 'boom $i');
        }
        final files = await archive.files();
        expect(files, hasLength(5));
        // The oldest two are gone; the newest carries the last message.
        final newest =
            jsonDecode(await files.first.readAsString())
                as Map<String, dynamic>;
        expect(newest['details'], 'boom 6');
        // The count cap ran without any caller asking.
        expect(archive.knownNonEmpty, isTrue);
      },
    );

    test('a locked file survives prune and does not crash the write', () async {
      final archive = CrashArchive(
        directory: Directory('${root.path}/logs/crash'),
        maxFiles: 2,
      );
      final blocker = await archive.write('flutter', 'blocked');
      // Open the file for writing so a delete fails on some platforms; the
      // prune must swallow the error either way.
      final sink = blocker.openWrite(mode: FileMode.append);
      sink.add([0]);
      try {
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
          await archive.write('flutter', 'later $i');
        }
        expect((await archive.files()).length, lessThanOrEqualTo(3));
      } finally {
        await sink.close();
      }
    });
  });

  group('UsageLedger', () {
    UsageEntry entry(
      int timestamp, {
      String model = 'glm-5',
      int input = 10,
      int output = 5,
      bool error = false,
    }) => UsageEntry(
      timestamp: timestamp,
      model: model,
      inputTokens: input,
      outputTokens: output,
      error: error,
    );

    test('records and reads back, ordered by time', () async {
      final ledger = UsageLedger(directory: Directory('${root.path}/usage'));
      try {
        await ledger.record(
          entry(DateTime.utc(2026, 9, 15).millisecondsSinceEpoch),
        );
        await ledger.record(
          entry(DateTime.utc(2026, 10, 1).millisecondsSinceEpoch),
        );
        final entries = await ledger.entries();
        expect(entries, hasLength(2));
        expect(entries.first.totalTokens, 15);
        expect(entries.first.timestamp, lessThan(entries.last.timestamp));
        // The rows live in the drift database now (ADR-0060).
        expect(File('${root.path}/usage/usage.db').existsSync(), isTrue);
      } finally {
        await ledger.close();
      }
    });

    test('prune drops rows past the window with one DELETE', () async {
      final ledger = UsageLedger(directory: Directory('${root.path}/usage'));
      try {
        final now = DateTime.utc(2026, 10, 2);
        await ledger.record(
          entry(now.subtract(const Duration(days: 40)).millisecondsSinceEpoch),
        );
        await ledger.record(
          entry(now.subtract(const Duration(days: 5)).millisecondsSinceEpoch),
        );
        await ledger.prune(now: now);
        final entries = await ledger.entries();
        expect(entries, hasLength(1));
        expect(
          entries.single.timestamp,
          now.subtract(const Duration(days: 5)).millisecondsSinceEpoch,
        );
      } finally {
        await ledger.close();
      }
    });

    test('legacy monthly files import once, torn lines and all', () async {
      final dir = Directory('${root.path}/usage')..createSync(recursive: true);
      File('${dir.path}/usage-202609.jsonl').writeAsStringSync(
        '{"timestamp":100,"model":"old","inputTokens":2,"outputTokens":1}\n'
        '{"timestamp":200,"model":"old","inputTokens":3,"outputTokens":1}\n',
      );
      File('${dir.path}/usage-202610.jsonl').writeAsStringSync(
        '{"timestamp":1,"model":"m","inputTokens":1,"outputTokens":1}\n{"torn',
      );
      final ledger = UsageLedger(directory: dir);
      try {
        final entries = await ledger.entries();
        // The valid rows from both files; the torn tail dropped, the files
        // imported and gone — the database is the only copy now.
        expect(entries, hasLength(3));
        expect(entries.first.timestamp, 1);
        expect(entries[1].timestamp, 100);
        expect(
          dir.listSync().whereType<File>().where(
            (file) => file.path.endsWith('.jsonl'),
          ),
          isEmpty,
        );
      } finally {
        await ledger.close();
      }
    });

    test('summarize folds tokens, per-model buckets and the error rate', () {
      final summary = UsageLedger.summarize([
        entry(1, model: 'a', input: 100, output: 50),
        entry(2, model: 'a', input: 10, output: 5),
        entry(3, model: 'b', input: 1, output: 2, error: true),
      ]);
      expect(summary.turns, 3);
      expect(summary.totalTokens, 168);
      expect(summary.errorCount, 1);
      expect(summary.errorRate, closeTo(1 / 3, 0.001));
      expect(summary.perModelTokens['a'], 165);
      expect(summary.perModelTokens['b'], 3);
    });
  });
}
