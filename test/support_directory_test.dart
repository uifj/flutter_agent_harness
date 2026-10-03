// 本文件守住一句话：改了应用身份之后，上一次安装留下的应用数据必须还在原处可读，
// 而且盘上只许存在一份。
//
// path_provider 用应用身份给支持目录命名，所以换 bundle id 等于把所有自有文件
// 留在另一个目录里。一个空目录和一个全新安装长得一模一样，只有真目录能证伪这件事
// —— fake 证不了 rename、嵌套子目录和"目标已有数据就不许动"这三条文件系统事实。

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/host/support_directory.dart';

void main() {
  late Directory root;
  late Directory current;
  late Directory legacy;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('planstar_support');
    // The two directories must be siblings: that is how path_provider lays out
    // one support root per application identity.
    current = Directory('${root.path}/top.planstar.desktop');
    legacy = Directory('${root.path}/com.stow.agentHarness');
    await legacy.create(recursive: true);
  });
  tearDown(() async => root.delete(recursive: true));

  Future<void> write(Directory dir, String rel, String body) async {
    final f = File('${dir.path}/$rel');
    await f.parent.create(recursive: true);
    await f.writeAsString(body);
  }

  test('a legacy sibling moves wholesale onto the current identity', () async {
    await write(legacy, 'settings.json', '{"a":1}');
    await write(legacy, 'sessions/sessions.json', '[]');
    await write(legacy, 'checkpoints/blob/deadbeef', 'x');

    final moved = await migrateSupportDirectory(current);

    expect(moved, 'com.stow.agentHarness');
    expect(File('${current.path}/settings.json').readAsStringSync(), '{"a":1}');
    expect(File('${current.path}/sessions/sessions.json').existsSync(), isTrue);
    expect(
      File('${current.path}/checkpoints/blob/deadbeef').existsSync(),
      isTrue,
    );
    // One truth: the old directory is gone, not a second copy of the same state.
    expect(legacy.existsSync(), isFalse);
  });

  test('data already in place is never touched', () async {
    await current.create(recursive: true);
    await write(current, 'settings.json', '{"new":true}');
    await write(legacy, 'settings.json', '{"old":true}');

    expect(await migrateSupportDirectory(current), isNull);
    expect(
      File('${current.path}/settings.json').readAsStringSync(),
      '{"new":true}',
    );
    expect(File('${legacy.path}/settings.json').existsSync(), isTrue);
  });

  test('nothing to migrate answers null and creates no directory', () async {
    expect(await migrateSupportDirectory(current), isNull);
    expect(current.existsSync(), isFalse);
  });

  test('an empty legacy sibling is skipped, not renamed', () async {
    expect(await migrateSupportDirectory(current), isNull);
    expect(legacy.existsSync(), isTrue);
  });

  test('the current identity is never treated as legacy', () async {
    // A run whose support dir *is* com.stow.agentHarness must not move itself
    // away and leave the app with nothing.
    final old = Directory('${root.path}/com.stow.agentHarness');
    await write(old, 'settings.json', 'keep');
    expect(await migrateSupportDirectory(old), isNull);
    expect(File('${old.path}/settings.json').existsSync(), isTrue);
  });
}
