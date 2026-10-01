// 本文件守住的那句话：会话的工作区归属、置顶、墓碑与改名存在一份 sidecar 里，
// 重启读得回来，坏文件不砖，而取消置顶/撤销改名会把条目整个收干净。
//
// 跑真实临时目录，因为这里要验的是文件系统事实（tmp+rename 之后旧内容不会残留、
// 坏 JSON 退空表而不是抛），fake 证不出来。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_harness/state/session_registry.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('sessions_sidecar');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File document() => File('${root.path}/${SessionRegistry.fileName}');

  test('a workspace recorded once survives a reopen', () {
    final registry = SessionRegistry.open(root);
    registry.noteWorkspace('a', '/Users/me/project');

    final reopened = SessionRegistry.open(root);
    expect(reopened.metaOf('a').workspaceRoot, '/Users/me/project');
    expect(reopened.knownWorkspaces, {'/Users/me/project'});
  });

  test('the first folder wins: a session does not move with the workspace', () {
    final registry = SessionRegistry.open(root)
      ..noteWorkspace('a', '/one')
      ..noteWorkspace('a', '/two');
    expect(registry.metaOf('a').workspaceRoot, '/one');
  });

  test('a tombstone is not a removal', () {
    final registry = SessionRegistry.open(root)..noteWorkspace('a', '/one');
    registry.markDeleted('a', now: DateTime(2026, 10, 2));

    expect(registry.isDeleted('a'), isTrue);
    expect(registry.metaOf('a').workspaceRoot, '/one');
    expect(
      SessionRegistry.open(root).isDeleted('a'),
      isTrue,
      reason: 'the list must still refuse this row after a relaunch',
    );
  });

  test(
    'undoing every change drops the row instead of writing an empty shell',
    () {
      final registry = SessionRegistry.open(root)
        ..setPinned('a', true, now: DateTime(2026));
      registry.setPinned('a', false, now: DateTime(2026));

      expect(jsonDecode(document().readAsStringSync()), isEmpty);
    },
  );

  test('an empty rename cannot hide the derived title', () {
    final registry = SessionRegistry.open(root)
      ..rename('a', '   ')
      ..rename('b', '  重命名  ');

    expect(registry.titleOf('a'), isNull);
    expect(registry.titleOf('b'), '重命名');
  });

  test('a corrupt document reads as absent rather than bricking the app', () {
    document().writeAsStringSync('not json at all');
    expect(SessionRegistry.open(root).knownWorkspaces, isEmpty);
    expect(SessionRegistry.open(root).errorMessage, isNull);
  });

  test('one malformed row drops, the rest of the file still counts', () {
    document().writeAsStringSync(
      jsonEncode({
        'good': {'workspaceRoot': '/one'},
        'bad': 'not an object',
      }),
    );

    final registry = SessionRegistry.open(root);
    expect(registry.metaOf('good').workspaceRoot, '/one');
    expect(registry.knownWorkspaces, {'/one'});
  });

  test('a failed write is said out loud, not swallowed', () {
    root.deleteSync(recursive: true);
    final registry = SessionRegistry.open(root)..noteWorkspace('a', '/one');

    expect(registry.errorMessage, isNotNull);
    expect(
      registry.metaOf('a').workspaceRoot,
      '/one',
      reason: 'the live map still answers; only persistence failed',
    );
  });
}
