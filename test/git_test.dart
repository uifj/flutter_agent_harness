// The git wrapper, without a repository.
//
// The porcelain and log parsers, the XY-letter vocabulary the panel renders
// with, and [GitRepo]'s command shapes over a fake runner — the parts that
// decide what the panel says. The real spawn (timeouts, pipe draining) is
// exercised by the app itself, where a stalled git is a support ticket rather
// than a unit under test.

import 'package:agent_harness/host/git.dart';
import 'package:agent_harness/sidebar/ui/tabs/git_tab.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_git.dart';

void main() {
  group('parsePorcelainZ', () {
    test('splits plain entries', () {
      final entries = parsePorcelainZ('M  a.txt\x00 M b.txt\x00?? c.txt\x00');
      expect(entries.map((e) => e.xy), ['M ', ' M', '??']);
      expect(entries.map((e) => e.path), ['a.txt', 'b.txt', 'c.txt']);
    });

    test('collapses rename pairs to the new path', () {
      // `R  new\x00old\x00` — the row worth showing is the file as it exists
      // now; the origin is the trailing field the parser has to skip.
      final entries = parsePorcelainZ('R  new.txt\x00old.txt\x00M  other.txt\x00');
      expect(entries, hasLength(2));
      expect(entries.first.path, 'new.txt');
      expect(entries.first.xy, 'R ');
      expect(entries.last.path, 'other.txt');
    });

    test('ignores the trailing NUL and short tokens', () {
      expect(parsePorcelainZ(''), isEmpty);
      expect(parsePorcelainZ('M \x00'), isEmpty);
    });
  });

  group('parseLogLines', () {
    test('reads every field', () {
      final rows = parseLogLines(
        'abc1234\x1fsubject\x1fauthor\x1f2024-01-01 10:00:00 +0800'
        '\x1fabc1234defg...\x1fHEAD -> main, origin/main\n'
        'def5678\x1fother\x1fme\x1f2024-01-02\x1fdef5678abcd\x1f\n',
      );
      expect(rows, hasLength(2));
      expect(rows.first.hash, 'abc1234');
      expect(rows.first.subject, 'subject');
      expect(rows.first.author, 'author');
      expect(rows.first.date, '2024-01-01 10:00:00 +0800');
      expect(rows.first.hashFull, 'abc1234defg...');
      expect(rows.first.refs, 'HEAD -> main, origin/main');
      // A row with no decorations keeps an empty refs rather than null —
      // refNames has an empty vocabulary to read, not a branch to take.
      expect(rows.last.refs, '');
    });

    test('skips blank and malformed rows', () {
      expect(parseLogLines('\n\n'), isEmpty);
      expect(parseLogLines('onlyonefield\n'), isEmpty);
    });
  });

  group('the XY vocabulary', () {
    test('badgeOf prefers the index letter, then the worktree letter', () {
      expect(badgeOf(const GitStatusEntry(path: 'a', xy: 'M ')), 'M');
      expect(badgeOf(const GitStatusEntry(path: 'a', xy: ' M')), 'M');
      expect(badgeOf(const GitStatusEntry(path: 'a', xy: 'MM')), 'M');
      expect(badgeOf(const GitStatusEntry(path: 'a', xy: '??')), '?');
    });

    test('isStagedEntry is the X letter', () {
      expect(isStagedEntry(const GitStatusEntry(path: 'a', xy: 'M ')), isTrue);
      expect(isStagedEntry(const GitStatusEntry(path: 'a', xy: 'MM')), isTrue);
      expect(isStagedEntry(const GitStatusEntry(path: 'a', xy: ' M')), isFalse);
      expect(isStagedEntry(const GitStatusEntry(path: 'a', xy: '??')), isFalse);
    });

    test('isUnstagedEntry is the Y letter, untracked included', () {
      expect(isUnstagedEntry(const GitStatusEntry(path: 'a', xy: ' M')), isTrue);
      // 'MM' lands in BOTH sections — staged and unstaged are two diffs.
      expect(isUnstagedEntry(const GitStatusEntry(path: 'a', xy: 'MM')), isTrue);
      expect(isUnstagedEntry(const GitStatusEntry(path: 'a', xy: 'M ')), isFalse);
      expect(isUnstagedEntry(const GitStatusEntry(path: 'a', xy: '??')), isTrue);
    });

    test('isUntracked is exactly ??', () {
      expect(isUntracked(const GitStatusEntry(path: 'a', xy: '??')), isTrue);
      expect(isUntracked(const GitStatusEntry(path: 'a', xy: 'A ')), isFalse);
    });
  });

  group('refNames', () {
    test('resolves decorations to plain names, deduped', () {
      expect(
        refNames('HEAD -> main, origin/main, tag: v1.0'),
        ['main', 'origin/main', 'v1.0'],
      );
      // `HEAD -> main` and a bare `main` are the same ref shown twice.
      expect(refNames('HEAD -> main, main'), ['main']);
      expect(refNames(''), isEmpty);
    });
  });

  group('parseGitDate', () {
    test('reads the space-separated offset git writes', () {
      final date = parseGitDate('2024-01-01 10:00:00 +0800');
      expect(date, isNotNull);
      // Normalised to UTC: 10:00 at +0800 is 02:00 Z.
      expect(date!.toUtc(), DateTime.utc(2024, 1, 1, 2));
    });

    test('reads the offset-less shape as local, and rejects garbage', () {
      expect(parseGitDate('2024-01-01 10:00:00'), isNotNull);
      expect(parseGitDate('not a date'), isNull);
    });
  });

  group('relativeTime', () {
    final now = DateTime(2026, 1, 2, 12, 0, 0);

    test('buckets as the source does', () {
      String at(int secondsAgo) => relativeTime(
        now.subtract(Duration(seconds: secondsAgo)).toIso8601String(),
        now: () => now,
      );
      expect(at(30), 'just now');
      expect(at(120), '2 min ago');
      expect(at(7200), '2 h ago');
      expect(at(90000), 'yesterday');
      expect(at(3 * 86400), '2025-12-30');
    });

    test('passes through what it cannot parse', () {
      expect(relativeTime('garbage', now: () => now), 'garbage');
    });
  });

  group('GitRepo over a fake runner', () {
    late FakeGit fake;

    // The direct calls assert the commands sent, not their responses, so an
    // unstubbed command answering '' is the right default here.
    setUp(() => fake = FakeGit(unknownResponse: ''));

    test('status resolves the branch and truncates past the cap', () async {
      fake.responses['rev-parse --abbrev-ref HEAD'] = 'main\n';
      fake.responses['status --porcelain=v1 -z --untracked-files=all'] =
          List.generate(gitStatusLimit + 5, (i) => '?? f$i').join('\x00');
      final repo = GitRepo('/repo', runner: fake.runner);

      final status = await repo.status();
      expect(status.isRepo, isTrue);
      expect(status.branch, 'main');
      expect(status.entries, hasLength(gitStatusLimit));
      expect(status.truncated, isTrue);
      // Branch resolution is part of one status call.
      expect(
        fake.calls.map((call) => call.$2.join(' ')),
        containsAllInOrder([
          'status --porcelain=v1 -z --untracked-files=all',
          'rev-parse --abbrev-ref HEAD',
        ]),
      );
    });

    test('status keeps HEAD when the branch cannot resolve', () async {
      // A repository with no commits yet has no branch name.
      fake.responses['status --porcelain=v1 -z --untracked-files=all'] =
          '?? a.txt\x00';
      fake.failures.add('rev-parse --abbrev-ref HEAD');
      final status = await GitRepo('/repo', runner: fake.runner).status();
      expect(status.branch, 'HEAD');
      expect(status.truncated, isFalse);
    });

    test('branches keeps local order, and prepends only a non-local HEAD', () async {
      fake.responses['rev-parse --abbrev-ref HEAD'] = 'feature\n';
      fake.responses['for-each-ref --format=%(refname:short) refs/heads'] =
          'main\nfeature\nother\n';
      // The source leaves the locals as git listed them when the current one
      // is among them: the selector shows the current through its value, not
      // through its position.
      expect(
        await GitRepo('/repo', runner: fake.runner).branches(),
        ['main', 'feature', 'other'],
      );

      // Detached HEAD is not a local, but must still be selectable.
      fake.responses['rev-parse --abbrev-ref HEAD'] = 'HEAD\n';
      expect(
        await GitRepo('/repo', runner: fake.runner).branches(),
        ['HEAD', 'main', 'feature', 'other'],
      );
    });

    test('stage, unstage, commit and the history verbs send their shapes',
        () async {
      final repo = GitRepo('/repo', runner: fake.runner);
      await repo.stage('a.txt');
      await repo.stage(null);
      await repo.unstage('a.txt');
      await repo.commit('a message');
      await repo.discard('a.txt');
      await repo.revert('fullhash');
      await repo.cherryPick('fullhash');
      expect(
        fake.calls.map((call) => call.$2.join(' ')),
        containsAllInOrder([
          'add -A -- a.txt',
          'add -A',
          'reset -q -- a.txt',
          'commit -m a message',
          'checkout -- a.txt',
          'revert --no-edit fullhash',
          'cherry-pick fullhash',
        ]),
      );
      // Every call is rooted at the repository, never the caller's cwd.
      expect(fake.calls.map((call) => call.$1), everyElement('/repo'));
    });

    test('diff addresses one path on one side', () async {
      final repo = GitRepo('/repo', runner: fake.runner);
      await repo.diff('a.txt', staged: true);
      await repo.diff(null, staged: false);
      expect(
        fake.calls.map((call) => call.$2.join(' ')),
        containsAllInOrder([
          'diff --no-ext-diff --no-color -U3 --cached -- a.txt',
          'diff --no-ext-diff --no-color -U3',
        ]),
      );
    });

    test('log pages by skip', () async {
      final repo = GitRepo('/repo', runner: fake.runner);
      await repo.log(count: 20, skip: 40);
      expect(fake.commands.single, fakeLogKey(skip: 40));
    });

    test('a failed command rejects with its stderr', () async {
      fake.failures.add('status --porcelain=v1 -z --untracked-files=all');
      await expectLater(
        GitRepo('/repo', runner: fake.runner).status(),
        throwsA(isA<GitCommandError>()),
      );
    });
  });

  group('openRepo', () {
    late FakeGit fake;

    setUp(() => fake = FakeGit());

    test('resolves the toplevel of a work tree', () async {
      fake.responses['rev-parse --show-toplevel'] = '/repo\n';
      final repo = await openRepo('/repo/sub', runner: fake.runner);
      expect(repo?.root, '/repo');
    });

    test('null outside a work tree', () async {
      fake.failures.add('rev-parse --show-toplevel');
      expect(await openRepo('/nowhere', runner: fake.runner), isNull);
    });
  });
}
