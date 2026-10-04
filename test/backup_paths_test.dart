// 本文件守住的那句话：备份归档里的一个条目名，走不出它自己的目录（ADR-0042）。
//
// `restoreBackup` used to write `p.join(supportPath, entry.name)` for every entry
// in a zip the user picked in a file dialog, so an archive naming an entry
// `../../.ssh/authorized_keys` could put bytes anywhere the app could reach. That
// is the classic zip-slip, and the fix is one pure function — which is testable
// here precisely because the service itself cannot be: `getApplicationSupportDirectory()`
// has no answer under `flutter test`, so the only part of this contract that can
// be proven on this machine is the one that has no plugin in it.
//
// Paths are compared through `package:path` against a real temp directory because
// the separators are not portable and this suite runs on three desktops.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:planstar/state/backup_service.dart';

void main() {
  _preRestoreGroup();

  late Directory temp;
  late String support;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('backup_paths');
    // Resolved, because macOS hands out a symlinked temp root and the two spellings
    // must not be compared against each other.
    support = temp.resolveSymbolicLinksSync();
  });

  tearDown(() => temp.deleteSync(recursive: true));

  test('what the app itself writes still lands inside', () {
    expect(
      resolveBackupEntry(support, 'settings.json'),
      p.join(support, 'settings.json'),
    );
    expect(
      resolveBackupEntry(support, 'sessions/sessions.json'),
      p.join(support, 'sessions', 'sessions.json'),
    );
    expect(
      resolveBackupEntry(support, 'sessions/global/.pointers/a.json'),
      p.join(support, 'sessions', 'global', '.pointers', 'a.json'),
    );
  });

  test('a name that climbs out is refused', () {
    expect(resolveBackupEntry(support, '../authorized_keys'), isNull);
    expect(resolveBackupEntry(support, '../../etc/passwd'), isNull);
    expect(
      resolveBackupEntry(support, 'sessions/../../../Library/etc/passwd'),
      isNull,
      reason: 'a climb hidden under a real-looking prefix',
    );
  });

  test('a climb that comes back inside is still inside', () {
    // Not a hole: `..` only matters when it exits the fence, and refusing it
    // would refuse archives the app writes for itself.
    expect(
      resolveBackupEntry(support, 'sessions/../workbench/layout.json'),
      p.join(support, 'workbench', 'layout.json'),
    );
  });

  test('the folder itself is not an entry', () {
    expect(resolveBackupEntry(support, '.'), isNull);
    expect(resolveBackupEntry(support, ''), isNull);
    expect(
      resolveBackupEntry(support, 'sessions'),
      p.join(support, 'sessions'),
      reason: 'a directory entry is still inside the fence',
    );
  });
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async => _fakeSupportPath;
}

String? _fakeSupportPath;

void _preRestoreGroup() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // ADR-0065 guards: the restore's third line of defence — the files it is
  // about to overwrite are copied aside first, kept to the newest three.
  group('pre-restore snapshots', () {
    late Directory root;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('pre_restore');
      // The restore reads its support root through path_provider; the fake
      // points it at this test's own temp dir.
      _fakeSupportPath = root.path;
      PathProviderPlatform.instance = _FakePathProviderPlatform();
    });

    tearDown(() async {
      if (await root.exists()) await root.delete(recursive: true);
    });

    test('touched files are copied aside with their layout', () async {
      // Existing live data the restore will overwrite.
      final existing = File('${root.path}/sessions/sessions.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"old": true}');
      expect(existing.readAsStringSync(), '{"old": true}');
      // A file outside the restore's plan entirely.
      final untouched = File('${root.path}/skills/a/SKILL.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('untouched');
      // A file the restore will create: in the target list, not on disk.
      final absent = '${root.path}/workbench/tree.json';

      await BackupService.snapshotBeforeRestore(root.path, [
        '${root.path}/sessions/sessions.json',
        absent,
      ]);

      final snapshotRoot = Directory('${root.path}/pre-restore');
      final snapshots = snapshotRoot.listSync();
      expect(snapshots, hasLength(1));
      final copied = File('${snapshots.single.path}/sessions/sessions.json');
      expect(copied.readAsStringSync(), '{"old": true}');
      // A file the restore will CREATE (not overwrite) has no "before" —
      // the snapshot mirrors the old world, not the restore's plan.
      expect(
        File('${snapshots.single.path}/workbench/tree.json').existsSync(),
        isFalse,
      );
      // A file outside the plan is untouched on both sides.
      expect(untouched.readAsStringSync(), 'untouched');
      expect(
        File('${snapshots.single.path}/skills/a/SKILL.md').existsSync(),
        isFalse,
      );
    });

    test('a real restore leaves the old bytes under pre-restore', () async {
      // The whole path: the live sessions.json exists, the archive overwrites
      // it, and the old bytes survive in the snapshot.
      final support = await getApplicationSupportDirectory();
      final live = File('${support.path}/sessions/sessions.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"old": true}');
      final zip = File('${root.path}/backup.zip');
      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'sessions/sessions.json',
            13,
            utf8.encode('{"new": true}'),
          ),
        );
      zip.writeAsBytesSync(ZipEncoder().encode(archive)!);
      addTearDown(() async {
        // The restore wrote into the REAL support directory; remove what we
        // brought so the shared fixture stays clean.
        await live.delete();
      });

      await BackupService.restoreBackup(zip.path);
      expect(live.readAsStringSync(), '{"new": true}');
      final snapshots = Directory('${support.path}/pre-restore').listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      expect(snapshots, isNotEmpty);
      expect(
        File(
          '${snapshots.last.path}/sessions/sessions.json',
        ).readAsStringSync(),
        '{"old": true}',
      );
    });

    test('nothing touched means no snapshot folder', () async {
      await BackupService.snapshotBeforeRestore(root.path, [
        '${root.path}/absent.json',
      ]);
      expect(Directory('${root.path}/pre-restore').existsSync(), isFalse);
    });

    test('the fourth snapshot prunes the first', () async {
      for (var i = 0; i < 4; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        // The file must exist each round: a snapshot of nothing is no
        // snapshot (the empty-folder rule above).
        File('${root.path}/sessions/sessions.json')
          ..createSync(recursive: true)
          ..writeAsStringSync('round $i');
        await BackupService.snapshotBeforeRestore(root.path, [
          '${root.path}/sessions/sessions.json',
        ]);
      }
      final snapshots = Directory('${root.path}/pre-restore').listSync()
        ..sort((a, b) => a.path.compareTo(b.path));
      expect(snapshots, hasLength(BackupService.preRestoreRetained));
    });
  });
}
