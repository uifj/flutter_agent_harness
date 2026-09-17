// Local backup and restore.
//
// Exports the app's persistent data (settings, prefs, plan tasks, workbench
// layouts, session history, and skills) to a zip archive, and restores from
// one. The backup is a single .zip file the user picks a location for; the
// restore overwrites the current data with the archive's contents.
//
// The service is stateless — each call is a self-contained operation. The
// caller (settings UI) owns the file picker and error handling.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The app's local backup/restore service.
class BackupService {
  /// The file extension used for backup archives.
  static const backupExtension = 'zip';

  /// The file name pattern for backups: `agent_harness_backup_YYYYMMDD_HHMMSS.zip`.
  static String defaultFileName() {
    final now = DateTime.now();
    final stamp = '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}_'
        '${now.second.toString().padLeft(2, '0')}';
    return 'agent_harness_backup_$stamp.$backupExtension';
  }

  /// Creates a backup archive at [destinationPath] containing all persistent
  /// data from the application support directory.
  ///
  /// Returns the number of files included in the backup.
  static Future<int> createBackup(String destinationPath) async {
    final support = await getApplicationSupportDirectory();
    final archive = Archive();

    // Files to back up (relative to support directory).
    final files = <String>[
      'settings.json',
      'prefs.json',
      'plan_tasks.json',
    ];

    // Add individual files.
    for (final relative in files) {
      final file = File(p.join(support.path, relative));
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(relative, bytes.length, bytes));
      }
    }

    // Add directories (workbench, sessions, skills).
    final dirs = <String>['workbench', 'sessions', 'skills'];
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
    var count = 0;

    for (final file in archive) {
      if (file.isFile) {
        final outPath = p.join(support.path, file.name);
        final outFile = File(outPath);
        // Ensure parent directory exists.
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
        count++;
      }
    }

    return count;
  }
}
