// The security-scoped bookmark lifecycle: what a pick records, what a
// restart restores, and what a typed path must not inherit.
//
// The platform channel itself cannot be exercised here — no window, no
// NSOpenPanel — so these tests drive the `ProjectFolderOps` interface with
// a fake, the same seam the app code reads. What is under test is the
// contract: the bookmark is only a permission while it names the folder
// that is the workspace.

import 'package:agent_harness/host/project_folder_ops.dart';
import 'package:agent_harness/model/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records every call; answers are scripted per test.
class FakeFolderOps implements ProjectFolderOps {
  FakeFolderOps({this.pickResult, this.accessResult = true});

  final ({String path, String bookmark})? pickResult;
  final bool accessResult;

  final started = <String>[];
  final stopped = <String>[];

  @override
  Future<({String path, String bookmark})?> pickDirectory() async =>
      pickResult;

  @override
  Future<bool> startAccessing(String bookmark) async {
    started.add(bookmark);
    return accessResult;
  }

  @override
  Future<void> stopAccessing(String bookmark) async => stopped.add(bookmark);
}

void main() {
  group('AppSettings.workspaceBookmark', () {
    test('a pick with a bookmark round-trips through JSON', () {
      const settings = AppSettings(
        workspaceRoot: '/tmp/work',
        workspaceBookmark: 'bm=',
      );
      final decoded = AppSettings.fromJson(settings.toJson());
      expect(decoded, settings);
      expect(decoded.workspaceBookmark, 'bm=');
    });

    test('withWorkspace keeps the pick-backed bookmark', () {
      const settings = AppSettings();
      final next = settings.withWorkspace('/tmp/work', bookmark: 'bm=');
      expect(next.workspaceRoot, '/tmp/work');
      expect(next.workspaceBookmark, 'bm=');
    });

    test("adopting a typed path clears a previous pick's bookmark", () {
      // A recent entry or a hand-typed path has no bookmark of its own. The
      // old one is for the OLD folder — restoring it would claim a
      // permission for a workspace that is no longer the root.
      const settings = AppSettings(
        workspaceRoot: '/tmp/old',
        workspaceBookmark: 'bm-old',
      );
      final next = settings.withWorkspace('/tmp/new');
      expect(next.workspaceBookmark, isNull);
    });

    test('revoking the workspace drops the bookmark with it', () {
      const settings = AppSettings(
        workspaceRoot: '/tmp/work',
        workspaceBookmark: 'bm=',
      );
      expect(settings.withoutWorkspace().workspaceBookmark, isNull);
    });
  });

  group('restoreWorkspaceAccess', () {
    test('resolves the stored bookmark once', () async {
      final ops = FakeFolderOps();
      final ok = await restoreWorkspaceAccess(bookmark: 'bm=', ops: ops);
      expect(ok, isTrue);
      expect(ops.started, ['bm=']);
    });

    test('no bookmark, nothing claimed', () async {
      final ops = FakeFolderOps();
      expect(await restoreWorkspaceAccess(bookmark: null, ops: ops), isFalse);
      expect(await restoreWorkspaceAccess(bookmark: '', ops: ops), isFalse);
      expect(ops.started, isEmpty);
    });

    test('a stale bookmark reports no access rather than throwing', () async {
      final ops = FakeFolderOps(accessResult: false);
      expect(
          await restoreWorkspaceAccess(bookmark: 'bm-stale', ops: ops),
          isFalse);
    });

    test('a channel that throws is a failed restore, not a crash', () async {
      final ops = _ThrowingOps();
      expect(await restoreWorkspaceAccess(bookmark: 'bm=', ops: ops), isFalse);
    });
  });
}

class _ThrowingOps implements ProjectFolderOps {
  @override
  Future<({String path, String bookmark})?> pickDirectory() async => null;

  @override
  Future<bool> startAccessing(String bookmark) async =>
      throw StateError('channel gone');

  @override
  Future<void> stopAccessing(String bookmark) async {}
}
