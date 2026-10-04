// Local backup and restore.
//
// Exports the app's persistent data (settings, prefs, workbench layouts,
// session history and its sidecar, skills, checkpoints) to a zip archive, and
// restores from one. The backup is a single .zip file the user picks a location
// for; the restore overwrites the current data with the archive's contents.
//
// The service is stateless — each call is a self-contained operation. The
// caller (settings UI) owns the file picker and error handling.

import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the archive entry [name] is allowed to land, or null when it would
/// leave [supportPath] (ADR-0042).
///
/// A backup is a file the user picked, not bytes this app wrote: an entry named
/// `../../.ssh/authorized_keys` used to be joined onto the support directory and
/// written — the classic zip-slip. Normalising first and asking "is this still
/// inside" is the whole defence; the answer is a path so the caller never has to
/// repeat the arithmetic.
String? resolveBackupEntry(String supportPath, String name) {
  final target = p.normalize(p.join(supportPath, name));
  return p.isWithin(supportPath, target) ? target : null;
}

/// Writes one exported message to [path] (ADR-0066). The UI holds the picked
/// path only; the bytes go through here so lib/ui stays off dart:io.
Future<void> writeMessageExport(String path, String text) async {
  await File(path).writeAsString(text, flush: true);
}

/// The app's local backup/restore service.
class BackupService {
  /// The file extension used for backup archives.
  static const backupExtension = 'zip';

  /// The file name pattern for backups: `planstar_backup_YYYYMMDD_HHMMSS.zip`.
  static String defaultFileName() {
    final now = DateTime.now();
    final stamp =
        '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}_'
        '${now.second.toString().padLeft(2, '0')}';
    return 'planstar_backup_$stamp.$backupExtension';
  }

  /// Creates a backup archive at [destinationPath] containing all persistent
  /// data from the application support directory.
  ///
  /// Returns the number of files included in the backup.
  static Future<int> createBackup(String destinationPath) async {
    final support = await getApplicationSupportDirectory();
    final archive = Archive();

    // Files to back up (relative to support directory).
    final files = <String>['settings.json', 'prefs.json', 'plan_tasks.json'];

    // Add individual files.
    for (final relative in files) {
      final file = File(p.join(support.path, relative));
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(relative, bytes.length, bytes));
      }
    }

    // Add directories (workbench, sessions, skills, checkpoints).
    final dirs = <String>['workbench', 'sessions', 'skills', 'checkpoints'];
    var count = 0;
    for (final dirName in dirs) {
      final dir = Directory(p.join(support.path, dirName));
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File) {
            final relative = p.relative(entity.path, from: support.path);
            final bytes = await entity.readAsBytes();
            archive.addFile(ArchiveFile(relative, bytes.length, bytes));
            count++;
          }
        }
      }
    }

    // Count the individual files too.
    for (final relative in files) {
      final file = File(p.join(support.path, relative));
      if (await file.exists()) count++;
    }

    // Write the zip.
    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw StateError('Failed to encode backup archive');
    }
    final destFile = File(destinationPath);
    await destFile.writeAsBytes(zipData);
    return count;
  }

  /// Restores persistent data from a backup archive at [sourcePath],
  /// overwriting existing files in the application support directory.
  ///
  /// Returns the number of files restored.
  static Future<int> restoreBackup(String sourcePath) async {
    final support = await getApplicationSupportDirectory();
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw FileSystemException('Backup file not found', sourcePath);
    }

    final zipData = await sourceFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipData);

    // Every entry name is settled before a single byte is written. Skipping the
    // bad ones would leave half the data replaced and half not — a state nobody
    // can see, let alone undo (ADR-0042).
    final targets = {
      for (final entry in archive.where((entry) => entry.isFile))
        entry.name: resolveBackupEntry(support.path, entry.name),
    };
    for (final target in targets.entries) {
      if (target.value == null) {
        throw FileSystemException(
          'Backup carries a path outside its own folder',
          target.key,
        );
      }
    }

    // Third line of defence (ADR-0065): whatever this restore is about to
    // overwrite is copied aside first. ADR-0042 keeps the restore from
    // writing somewhere it should not; this keeps the OLD bytes findable
    // when the restore succeeds but the user picked the wrong archive.
    await snapshotBeforeRestore(
      support.path,
      targets.values.whereType<String>(),
    );

    var count = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      final outFile = File(targets[file.name]!);
      // Ensure parent directory exists.
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
      count++;
    }

    return count;
  }

  /// How many pre-restore snapshots survive a new restore (ADR-0065).
  static const preRestoreRetained = 3;
  static const _preRestoreDirName = 'pre-restore';

  /// Copies every existing file the restore will overwrite into
  /// `<support>/pre-restore/<stamp>/<relative-path>`, mirroring the layout so
  /// a rollback is "copy the directory back" with no manifest of its own.
  /// Only touched files are snapshotted: data the restore never touches is
  /// not part of "the world before the restore", and folding it in would
  /// make the copy lie about what it can restore.
  @visibleForTesting
  static Future<void> snapshotBeforeRestore(
    String supportPath,
    Iterable<String> targets,
  ) async {
    final stamp = _preRestoreStamp(DateTime.now());
    final snapshotRoot = Directory(
      p.join(supportPath, _preRestoreDirName, stamp),
    );
    var copied = 0;
    for (final target in targets) {
      final file = File(target);
      if (!await file.exists()) continue;
      final relative = p.relative(target, from: supportPath);
      final copy = File(p.join(snapshotRoot.path, relative));
      await copy.parent.create(recursive: true);
      await file.copy(copy.path);
      copied++;
    }
    if (copied == 0) {
      // Nothing existing was touched; an empty snapshot folder would claim
      // otherwise.
      return;
    }
    await _prunePreRestoreSnapshots(supportPath);
  }

  static String _preRestoreStamp(DateTime now) =>
      '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}'
      '_${now.millisecondsSinceEpoch % 1000}';

  /// Keeps the newest [preRestoreRetained] snapshots.
  static Future<void> _prunePreRestoreSnapshots(String supportPath) async {
    final root = Directory(p.join(supportPath, _preRestoreDirName));
    if (!await root.exists()) return;
    final snapshots = [
      await for (final entity in root.list())
        if (entity is Directory) entity,
    ]..sort((a, b) => a.path.compareTo(b.path));
    for (var i = 0; i < snapshots.length - preRestoreRetained; i++) {
      await snapshots[i].delete(recursive: true);
    }
  }
}
