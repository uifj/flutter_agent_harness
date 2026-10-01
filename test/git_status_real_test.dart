// 本文件守住的那句话：真 git 报回的路径拼法，走到这个 store 与文件树所用的那串路径上，还对得上。
//
// ADR-0043 其余部分都由假 runner 守着：假串能证解析器与缓存，证不了
// `git rev-parse --show-toplevel` **真的**回答解析过的路径。而文件树那套"把 entry 重锚到
// 自己的根上"的写法正是压在这一点上——它错了，徽标就静默不画。这里用真 git、真临时目录、
// 且**经一个符号链接**去问，把那件假设量成事实（`/tmp` 与 `/var` 在这台机器上都是软链）。
//
// 真进程所以真事件循环：这个文件全是普通 `test()`，没有 widget、没有 FakeAsync，
// 因此也不会把 `runGit` 那道 30s 超时计时器带进任何 pump（workflow.md §4 记过那类坑）。

import 'dart:io';

import 'package:agent_harness/host/git.dart';
import 'package:agent_harness/state/git_status_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory scratch;
  late String real;
  late String link;

  setUp(() async {
    scratch = Directory.systemTemp.createTempSync('dsh_git_real_');
    final work = Directory('${scratch.path}/real')..createSync();
    // The repository's own top level, as the filesystem resolves it: git answers
    // this spelling no matter which path the caller came in through.
    real = work.resolveSymbolicLinksSync();
    Link('${scratch.path}/link').createSync(work.path);
    link = '${scratch.path}/link';

    await runGit(real, const ['init', '-q']);
    await runGit(real, const ['config', 'user.email', 'guard@example']);
    await runGit(real, const ['config', 'user.name', 'guard']);
    File('$real/a.md').writeAsStringSync('first\n');
    File('$real/b.md').writeAsStringSync('first\n');
    File('$real/d.md').writeAsStringSync('first\n');
    Directory('$real/sub').createSync();
    File('$real/sub/e.md').writeAsStringSync('first\n');
    await runGit(real, const ['add', 'a.md', 'b.md', 'd.md', 'sub/e.md']);
    await runGit(real, const ['commit', '-m', 'init']);

    // One of each shape the tree has to spell: a staged rename, an unstaged
    // edit, a staged edit, a change below a subfolder, an untracked file.
    await runGit(real, const ['mv', 'a.md', 'c.md']);
    File('$real/b.md').writeAsStringSync('edited outside the index\n');
    File('$real/d.md').writeAsStringSync('edited then staged\n');
    File('$real/sub/e.md').writeAsStringSync('deep edit\n');
    await runGit(real, const ['add', 'd.md']);
    File('$real/new.md').writeAsStringSync('untracked\n');
  });

  tearDown(() => scratch.deleteSync(recursive: true));

  /// XY keyed by path, so a shape can be named rather than counted.
  Map<String, String> letters(GitStatusResult status) => {
    for (final entry in status.entries) entry.path: entry.xy,
  };

  GitStatusEntry entryFor(GitStatusResult status, String path) =>
      status.entries.firstWhere(
        (entry) => entry.path == path,
        orElse: () => throw StateError('git did not report $path'),
      );

  test('the top level is reported resolved, asked through a link', () async {
    final repo = await openRepo(link);

    expect(repo, isNotNull, reason: 'git must be on PATH for this guard');
    expect(
      repo!.root,
      real,
      reason:
          'asked from /link, git answers the resolved /real — the '
          'assumption the tree rebase depends on',
    );
  });

  test('real porcelain carries the shapes the parser claims to know', () async {
    final status = await (await openRepo(link))!.status();

    expect(status.root, real);
    expect(letters(status), {
      'c.md': 'R ',
      'b.md': ' M',
      'd.md': 'M ',
      'sub/e.md': ' M',
      'new.md': '??',
    });
    expect(isStagedEntry(entryFor(status, 'c.md')), isTrue);
    expect(badgeOf(entryFor(status, 'c.md')), 'R');
    expect(isUnstagedEntry(entryFor(status, 'b.md')), isTrue);
    expect(isStagedEntry(entryFor(status, 'b.md')), isFalse);
    expect(badgeOf(entryFor(status, 'd.md')), 'M');
    expect(isUntracked(entryFor(status, 'new.md')), isTrue);
    expect(badgeOf(entryFor(status, 'new.md')), '?');
  });

  test(
    'the shared reading spells every change onto a path the tree lists',
    () async {
      final store = GitStatusStore(runner: runGit);
      final status = await store.read(link);

      // What the tree's rows actually are: names under the root the user picked.
      // `changedPaths` is production code here, not a formula restated in the
      // test — the claim is that the one answer lands on the listing.
      final listed = {
        for (final entity in Directory(
          link,
        ).listSync(recursive: true, followLinks: false))
          p.relative(entity.path, from: link),
      };
      final changed = changedPaths(
        status,
        root: link,
        resolvedRoot: Directory(link).resolveSymbolicLinksSync(),
      );

      expect(changed.keys, isNotEmpty);
      for (final row in changed.keys) {
        expect(
          listed,
          contains(p.relative(row, from: link)),
          reason: '$row is a row the tree can build',
        );
        expect(p.isWithin(link, row), isTrue);
        expect(File(row).existsSync(), isTrue, reason: 'the bytes are there');
      }
      // The pre-fix spelling is what this replaces: git's own top level cannot
      // name a row in a tree reached through a link.
      expect(
        p.isWithin(link, p.join(real, 'b.md')),
        isFalse,
        reason: 'the bug this guard exists to keep out',
      );
    },
  );

  test(
    'a subfolder and the top level get one reading, not a second run',
    () async {
      final store = GitStatusStore(runner: runGit);
      await store.read('$real/sub');
      final first = store.reading(real);

      expect(
        first,
        isNotNull,
        reason:
            'asked about a folder inside the repository, the answer is '
            'filed under the repository',
      );

      // The worktree moves between the two asks. If the second one re-ran git,
      // the new file would appear in the answer it gets from the cache.
      File('$real/late.md').writeAsStringSync('after the reading\n');
      final second = await store.read(real);

      expect(second, same(first));
      expect(
        letters(second).containsKey('late.md'),
        isFalse,
        reason: 'inside the freshness window — a shared reading, not a re-run',
      );

      // And the action's own word reaches both spellings.
      store.invalidate('$real/sub');
      await store.read(real);
      expect(letters(store.reading(real)!).containsKey('late.md'), isTrue);
    },
  );

  test(
    'a directory that is not a repository is an answer, not a retry',
    () async {
      final plain = Directory('${scratch.path}/plain')..createSync();
      File('${plain.path}/only.txt').writeAsStringSync('x\n');

      final status = await GitStatusStore(runner: runGit).read(plain.path);

      expect(status.isRepo, isFalse);
      expect(status.root, isNull, reason: 'nothing to be relative to');
      expect(status.entries, isEmpty);
    },
  );
}
