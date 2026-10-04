// Local diagnostics (ADR-0058): two JSONL families under
// `<support>/diagnostics/` — one line per model call (`requests-`) and one
// line per request's message snapshot (`contexts-`). The persistence stance
// is the usage ledger's (ADR-0045 PC): monthly files, 30-day prune after
// every append, torn tail lines dropped. The directory is not in the backup
// manifest (`backup_service.dart` packs workbench/sessions/skills/
// checkpoints only), so snapshots never leave the machine through a zip.

import 'dart:convert';
import 'dart:io';

import 'package:planstar/model/diagnostic_record.dart';

/// Appends and prunes both families. One instance per application, opened
/// by the composition root.
class DiagnosticLogStore {
  DiagnosticLogStore({required Directory directory, this.retentionDays = 30})
    : _directory = directory;

  final Directory _directory;
  final int retentionDays;

  Future<void> recordRequest(ModelCallRecord record) =>
      _append('requests', record.timestamp, record.toJson());

  Future<void> recordContext(ContextSnapshotRecord record) =>
      _append('contexts', record.timestamp, record.toJson());

  Future<void> _append(
    String prefix,
    int timestamp,
    Map<String, Object?> json,
  ) async {
    await _directory.create(recursive: true);
    final month = DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    final file = File(
      '${_directory.path}/$prefix-'
      '${month.year}${_two(month.month)}.jsonl',
    );
    await file.writeAsString(
      '${jsonEncode(json)}\n',
      mode: FileMode.append,
      flush: true,
    );
    await prune(prefix: prefix);
  }

  /// Deletes [prefix] entries older than [retentionDays] by rewriting the
  /// affected monthly files. A line that does not parse is a torn tail from
  /// a killed process: dropped, the next entry starts a fresh line.
  Future<void> prune({required String prefix, DateTime? now}) async {
    final cutoff =
        (now ?? DateTime.now()).toUtc().millisecondsSinceEpoch -
        retentionDays * 86400000;
    if (!await _directory.exists()) return;
    for (final file in await _directory.list().toList()) {
      if (file is! File) continue;
      final name = file.uri.pathSegments.last;
      if (!name.startsWith('$prefix-') || !name.endsWith('.jsonl')) continue;
      final kept = <String>[];
      for (final line in await file.readAsLines()) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line) as Map<String, Object?>;
          if (((json['timestamp'] as num?)?.toInt() ?? 0) >= cutoff) {
            kept.add(line);
          }
        } on FormatException {
          // Same torn-tail rule as the usage ledger.
        }
      }
      if (kept.isEmpty) {
        await file.delete();
      } else {
        await file.writeAsString('${kept.join('\n')}\n', flush: true);
      }
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
