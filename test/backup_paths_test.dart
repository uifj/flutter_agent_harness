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

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:agent_harness/state/backup_service.dart';

void main() {
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
