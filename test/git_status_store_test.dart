// 本文件守住的那句话：一次 git status 只有一个持有者——两个读者来问，也只跑一次进程。
//
// ADR-0043 puts the file tree next to the source-control panel as a second
// reader of the same status. What makes that safe is not the shared type, it is
// these five facts: a cold cache runs one process for concurrent callers, a
// fresh reading answers without touching git, an action can owe the next reader
// a refresh, the window is one number that lives here rather than in whichever
// view got there first, and "this is not a repository" is itself a cached answer
// — otherwise a tree that rebuilds on hover would nag git forever.

import 'package:flutter_test/flutter_test.dart';

import 'package:planstar/state/git_status_store.dart';

import 'fake_git.dart';

void main() {
  const root = '/fake/repo';

  int statusCalls(FakeGit git) =>
      git.calls.where((call) => call.$2.first == 'status').length;

  FakeGit repo() => FakeGit()..stubRepo(root: root);

  test('two readers on a cold cache pay one process', () async {
    final git = repo();
    final store = GitStatusStore(runner: git.runner);

    final results = await Future.wait([store.read(root), store.read(root)]);

    expect(statusCalls(git), 1);
    expect(results.first.entries.map((entry) => entry.path), [
      'staged.txt',
      'unstaged.txt',
      'new.txt',
    ]);
    expect(
      results.last,
      same(results.first),
      reason: 'the same reading, not two',
    );
  });

  test('a fresh reading never re-asks git', () async {
    final git = repo();
    final store = GitStatusStore(runner: git.runner);

    await store.read(root);
    await store.read(root);

    expect(statusCalls(git), 1);
    expect(store.reading(root)?.isRepo, isTrue);
  });

  test(
    'the same repository asked about from inside it is still one reading',
    () async {
      // The panel asks about the top level; a file tree can be rooted at a
      // subfolder of the same repository. Keying the cache by whichever path
      // arrived first would give that repository two statuses and two answers
      // to "what is dirty" — the exact split this store exists to prevent.
      final git = repo();
      final store = GitStatusStore(runner: git.runner);

      await store.read('$root/packages/foo');
      final fromTop = await store.read(root);

      expect(
        statusCalls(git),
        1,
        reason: 'one repository, one process, whoever asks',
      );
      expect(store.reading('$root/packages/foo'), same(fromTop));
      expect(
        fromTop.root,
        root,
        reason: 'the answer is keyed by the repository, not by the question',
      );
    },
  );

  test(
    'an action invalidates, so the next reader sees the tree as it is now',
    () async {
      final git = repo();
      final store = GitStatusStore(runner: git.runner);

      await store.read(root);
      store.invalidate(root);
      await store.read(root);

      expect(statusCalls(git), 2);
    },
  );

  test(
    'the freshness window is one number and it lives in the store',
    () async {
      final git = repo();
      var now = DateTime(2026, 10, 2, 12);
      final store = GitStatusStore(runner: git.runner, clock: () => now);

      await store.read(root);
      now = now.add(GitStatusStore.freshness - const Duration(milliseconds: 1));
      await store.read(root);
      expect(statusCalls(git), 1, reason: 'still inside the window');

      now = now.add(const Duration(seconds: 2));
      await store.read(root);
      expect(
        statusCalls(git),
        2,
        reason: 'past it — and the panel pays the same price',
      );
    },
  );

  test('not a repository is an answer, not a retry', () async {
    final git = FakeGit(unknownResponse: '');
    final store = GitStatusStore(runner: git.runner);

    final first = await store.read('/nowhere');
    expect(first.isRepo, isFalse);

    final callsAfterFirst = git.calls.length;
    await store.read('/nowhere');
    expect(
      git.calls.length,
      callsAfterFirst,
      reason: 'one rev-parse decides it, once',
    );
  });

  test('a reader is told once per reading, not once per caller', () async {
    final git = repo();
    final store = GitStatusStore(runner: git.runner);
    var notices = 0;
    store.addListener(() => notices++);

    await Future.wait([store.read(root), store.read(root)]);
    expect(notices, 1);

    store.invalidate(root);
    await store.read(root);
    expect(notices, 2);
  });

  test(
    'a failing status is a cached no-status, not a thrown surprise',
    () async {
      final git = repo()
        ..failures.add('status --porcelain=v1 -z --untracked-files=all');
      final store = GitStatusStore(runner: git.runner);

      final result = await store.read(root);

      expect(result.isRepo, isFalse);
      expect(store.reading(root), same(result));
    },
  );
}
