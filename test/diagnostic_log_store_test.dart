// ADR-0058 guards: the two diagnostics families land in separate monthly
// files, prune on the usage ledger's 30-day stance, survive a torn tail
// line, and the records round-trip through JSON.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/model/diagnostic_record.dart';
import 'package:planstar/state/diagnostic_log_store.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('diagnostic_logs');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  DiagnosticLogStore store() =>
      DiagnosticLogStore(directory: Directory('${root.path}/diagnostics'));

  ModelCallRecord aRequest({int? timestamp}) => ModelCallRecord(
    timestamp: timestamp ?? DateTime.now().toUtc().millisecondsSinceEpoch,
    model: 'deepseek-chat',
    durationMs: 120,
    ok: true,
    inputTokens: 10,
    outputTokens: 5,
    totalTokens: 15,
  );

  test('the two families land in separate monthly files', () async {
    final log = store();
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    await log.recordRequest(aRequest(timestamp: stamp));
    await log.recordContext(
      ContextSnapshotRecord(
        timestamp: stamp,
        model: 'deepseek-chat',
        messages: [
          ContextMessage(
            role: 'user',
            parts: [ContextPart(kind: 'text', text: 'hi')],
          ),
        ],
      ),
    );

    final names = await Directory(
      '${root.path}/diagnostics',
    ).list().map((entry) => entry.uri.pathSegments.last).toList();
    expect(names.where((n) => n.startsWith('requests-')), hasLength(1));
    expect(names.where((n) => n.startsWith('contexts-')), hasLength(1));

    final requestLines = await _lines(root, 'requests');
    expect(requestLines, hasLength(1));
    final request = ModelCallRecord.fromJson(
      jsonDecode(requestLines.single) as Map<String, Object?>,
    );
    expect(request.model, 'deepseek-chat');
    expect(request.ok, isTrue);
    expect(request.totalTokens, 15);

    final contextLines = await _lines(root, 'contexts');
    expect(contextLines, hasLength(1));
    final context = ContextSnapshotRecord.fromJson(
      jsonDecode(contextLines.single) as Map<String, Object?>,
    );
    expect(context.messages.single.role, 'user');
    expect(context.messages.single.parts.single.text, 'hi');
  });

  test('prune keeps fresh entries and drops entries past the window', () async {
    final log = store();
    final now = DateTime.utc(2026, 10, 4, 12);
    final file = File('${root.path}/diagnostics/requests-202610.jsonl');
    await file.create(recursive: true);
    // A fresh line and a line from 31 days ago, in the same file — the
    // window decides, not the month.
    final fresh = aRequest(timestamp: now.millisecondsSinceEpoch);
    final stale = aRequest(
      timestamp: now.subtract(const Duration(days: 31)).millisecondsSinceEpoch,
    );
    await file.writeAsString(
      '${jsonEncode(stale.toJson())}\n${jsonEncode(fresh.toJson())}\n',
    );

    await log.prune(prefix: 'requests', now: now);

    final kept = await _lines(root, 'requests');
    expect(kept, hasLength(1));
    expect(
      (jsonDecode(kept.single) as Map<String, Object?>)['timestamp'],
      fresh.timestamp,
    );
  });

  test(
    'an empty file after prune is deleted, a torn tail line is dropped',
    () async {
      final log = store();
      final now = DateTime.utc(2026, 10, 4, 12);
      final staleOnly = File('${root.path}/diagnostics/requests-202609.jsonl');
      await staleOnly.create(recursive: true);
      await staleOnly.writeAsString(
        '${jsonEncode(aRequest(timestamp: now.subtract(const Duration(days: 40)).millisecondsSinceEpoch).toJson())}\n',
      );
      final torn = File('${root.path}/diagnostics/contexts-202610.jsonl');
      await torn.create(recursive: true);
      final fresh = ContextSnapshotRecord(
        timestamp: now.millisecondsSinceEpoch,
        model: 'deepseek-chat',
        messages: const [],
      );
      await torn.writeAsString(
        '{"timestamp": 1, "mod\n${jsonEncode(fresh.toJson())}\n',
      );

      await log.prune(prefix: 'requests', now: now);
      await log.prune(prefix: 'contexts', now: now);

      expect(await staleOnly.exists(), isFalse);
      final kept = await _lines(root, 'contexts');
      expect(kept, hasLength(1));
    },
  );
}

Future<List<String>> _lines(Directory root, String prefix) async {
  final dir = Directory('${root.path}/diagnostics');
  final lines = <String>[];
  if (!await dir.exists()) return lines;
  await for (final entry in dir.list()) {
    if (entry is! File) continue;
    final name = entry.uri.pathSegments.last;
    if (!name.startsWith('$prefix-') || !name.endsWith('.jsonl')) continue;
    lines.addAll(await entry.readAsLines());
  }
  return lines.where((line) => line.trim().isNotEmpty).toList();
}
