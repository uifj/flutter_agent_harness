// Local crash archive (ADR-0045 PC): Flutter errors and uncaught platform
// errors land as timestamped files under `<support>/logs/crash/` — the same
// local-only answer ZCode ships (`desktopCrashCapture.ts:20,23-24`: 5 files /
// 100 MB, upload URL pointing at .invalid). Nothing leaves the machine; the
// settings screen's log entry is how the user gets at them.

import 'dart:convert';
import 'dart:io';

/// Writes and prunes crash reports. All IO is async; [prune] runs after every
/// write so the cap is self-enforcing.
class CrashArchive {
  CrashArchive({required Directory directory, int maxFiles = 5})
    : _directory = directory,
      _maxFiles = maxFiles;

  final Directory _directory;
  final int _maxFiles;

  /// Monotonic within this process: two crashes in the same millisecond must
  /// not share a file name (the sort key is the name), so a serial suffix
  /// breaks the tie and also orders the pair.
  int _serial = 0;

  /// Appends one report. [details] is free-form (error + stack + context);
  /// the envelope carries the timestamp so the file is self-describing.
  Future<File> write(String kind, String details) async {
    await _directory.create(recursive: true);
    final stamp = DateTime.now().toUtc().millisecondsSinceEpoch;
    final file = File(
      '${_directory.path}/crash-${kind.toLowerCase()}-$stamp-${_serial++}.json',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent(
        '  ',
      ).convert({'kind': kind, 'timestamp': stamp, 'details': details}),
      flush: true,
    );
    await prune();
    knownNonEmpty = true;
    return file;
  }

  /// Keeps the newest [_maxFiles] reports; anything older is deleted. The
  /// size cap is a no-op for text reports this small — the count is the
  /// binding limit, mirroring upstream.
  Future<void> prune() async {
    if (!await _directory.exists()) return;
    final reports = await _crashFiles(); // newest first
    if (reports.length <= _maxFiles) return;
    for (final file in reports.skip(_maxFiles)) {
      try {
        await file.delete();
      } on FileSystemException {
        // A locked file survives this round; the next prune retries.
      }
    }
  }

  /// Newest first — the settings screen lists these.
  Future<List<File>> files() async => _crashFiles();

  /// Whether at least one report exists — checked once at open, so the
  /// settings row can hide without async ceremony.
  bool knownNonEmpty = false;

  Future<List<File>> _crashFiles() async {
    if (!await _directory.exists()) return const [];
    final files =
        (await _directory.list().toList())
            .whereType<File>()
            .where(
              (file) => RegExp(r'crash-.+-\d+-\d+\.json$').hasMatch(file.path),
            )
            .toList()
          ..sort(_newestFirst);
    return files;
  }

  /// Orders by the trailing `-<serial>` then the timestamp, both numeric —
  /// lexicographic order breaks the moment serials cross a digit boundary
  /// (`-2` sorts after `-10` as text).
  static int _newestFirst(File a, File b) {
    int? key(String path) {
      final match = RegExp(r'crash-(\w+)-(\d+)-(\d+)\.json$').firstMatch(path);
      if (match == null) return null;
      return int.parse(match.group(2)!) * 1000000 + int.parse(match.group(3)!);
    }

    final aKey = key(a.path);
    final bKey = key(b.path);
    if (aKey == null || bKey == null) return b.path.compareTo(a.path);
    return bKey.compareTo(aKey);
  }
}
