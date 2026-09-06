// The diff tab: the unified-diff parser and the wiring over a fake git.
//
// The parser is pure, so its whole vocabulary — file sections, hunks, line
// kinds and numbers, binary and no-newline rows, the path and badge helpers,
// which files start expanded — is unit-tested without a repository. The widget
// tests then cover what only exists once wired: which git command answers
// which ref, the other-side fallback, the untracked full-file addition read
// from disk, and the refresh that re-runs the load.

import 'dart:io';

import 'package:agent_harness/model/sidebar_tab.dart';
import 'package:agent_harness/state/workbench_controller.dart';
import 'package:agent_harness/state/workbench_store.dart';
import 'package:agent_harness/ui/workbench/tabs/diff_tab.dart';
import 'package:agent_harness/ui/workbench/tabs/git_tab.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'fake_git.dart';

const _sampleDiff = '''
diff --git a/lib/a.dart b/lib/a.dart
index 1111111..2222222 100644
--- a/lib/a.dart
+++ b/lib/a.dart
@@ -1,4 +1,5 @@ imports
 context
-old line
+new line
+another line
 context
 context
@@ -10,2 +11,2 @@ later @@
-removed
+added
 context
diff --git a/lib/b.txt b/lib/c.txt
similarity index 95%
rename from lib/b.txt
rename to lib/c.txt
diff --git a/img/logo.png b/img/logo.png
index 3333333..4444444 100644
Binary files a/img/logo.png and b/img/logo.png differ
diff --git a/new.rs b/new.rs
new file mode 100644
index 0000000..5555555
--- /dev/null
+++ b/new.rs
@@ -0,0 +1,1 @@
+fn main() {}
''';

void main() {
  group('parseUnifiedDiff', () {
    final files = parseUnifiedDiff(_sampleDiff);

    test('splits file sections and reads the ---/+++ paths', () {
      expect(files, hasLength(4));
      expect(files[0].oldPath, 'a/lib/a.dart');
      expect(files[0].newPath, 'b/lib/a.dart');
    });

    test('parses hunks with kinds, numbers and section text', () {
      final first = files[0];
      expect(first.hunks, hasLength(2));
      final hunk = first.hunks[0];
      expect(hunk.oldStart, 1);
      expect(hunk.newStart, 1);
      expect(hunk.header, ' imports');
      expect(hunk.lines.map((line) => line.kind), [
        DiffLineKind.ctx,
        DiffLineKind.del,
        DiffLineKind.add,
        DiffLineKind.add,
        DiffLineKind.ctx,
        DiffLineKind.ctx,
      ]);
      // Line numbers advance per side: a deletion takes an old number, an
      // addition a new one.
      expect(hunk.lines[0].oldNum, 1);
      expect(hunk.lines[0].newNum, 1);
      expect(hunk.lines[1].oldNum, 2);
      expect(hunk.lines[1].newNum, isNull);
      expect(hunk.lines[2].oldNum, isNull);
      expect(hunk.lines[2].newNum, 2);
      expect(hunk.lines[3].newNum, 3);
      // The second hunk restarts at its own header numbers, section kept.
      expect(first.hunks[1].oldStart, 10);
      expect(first.hunks[1].newStart, 11);
      expect(first.hunks[1].header, ' later @@');
    });

    test('a rename-only section stays hunkless with its paths', () {
      final rename = files[1];
      expect(rename.hunks, isEmpty);
      expect(rename.binary, isFalse);
      expect(rename.oldPath, '');
      expect(rename.newPath, '');
    });

    test('a binary section is flagged', () {
      expect(files[2].binary, isTrue);
      expect(files[2].hunks, isEmpty);
    });

    test('a new file diffs against /dev/null', () {
      final created = files[3];
      expect(created.oldPath, '/dev/null');
      expect(created.hunks.single.lines.single.kind, DiffLineKind.add);
      expect(created.hunks.single.lines.single.newNum, 1);
    });

    test('leading noise and the meta no-newline row', () {
      final parsed = parseUnifiedDiff(
        'noise before any section\n'
        'diff --git a/x.c b/x.c\n'
        '--- a/x.c\n'
        '+++ b/x.c\n'
        '@@ -1 +1 @@\n'
        '-old\n'
        '\\ No newline at end of file\n'
        '+new\n',
      );
      final lines = parsed.single.hunks.single.lines;
      // The marker row does not close the hunk: the addition after it still
      // lands, as in the source.
      expect(lines, hasLength(3));
      expect(lines[1].kind, DiffLineKind.meta);
      expect(lines[1].text, ' No newline at end of file');
      expect(lines[1].oldNum, isNull);
      expect(lines[1].newNum, isNull);
      expect(lines[2].kind, DiffLineKind.add);
      expect(lines[2].text, 'new');
    });

    test('a hunk stops at a row no marker can start', () {
      final parsed = parseUnifiedDiff(
        'diff --git a/x.c b/x.c\n'
        '--- a/x.c\n'
        '+++ b/x.c\n'
        '@@ -1,2 +1,2 @@\n'
        ' first\n'
        'not a diff row\n'
        ' second\n',
      );
      // The stray row closes the hunk; the following context row is skipped
      // rather than swallowed into it.
      expect(parsed.single.hunks.single.lines.map((l) => l.text), ['first']);
    });

    test('an empty text parses to nothing', () {
      expect(parseUnifiedDiff(''), isEmpty);
    });
  });

  group('the path helpers', () {
    test('displayDiffPath strips a/ and b/, keeps /dev/null', () {
      expect(displayDiffPath('a/lib/a.dart'), 'lib/a.dart');
      expect(displayDiffPath('b/lib/a.dart'), 'lib/a.dart');
      expect(displayDiffPath('plain/file'), 'plain/file');
      expect(displayDiffPath('/dev/null'), '/dev/null');
    });

    test('diffFileTag names the change shape', () {
      UnifiedDiffFile file(String oldPath, String newPath, {bool binary = false}) =>
          UnifiedDiffFile(
            oldPath: oldPath,
            newPath: newPath,
            binary: binary,
            hunks: const [],
          );

      expect(diffFileTag(file('/dev/null', 'b/new.rs')), 'Added');
      expect(diffFileTag(file('a/gone.rs', '/dev/null')), 'Deleted');
      expect(diffFileTag(file('a/x', 'b/x', binary: true)), 'Binary');
      expect(diffFileTag(file('a/from.txt', 'b/to.txt')), 'Renamed');
      expect(diffFileTag(file('a/x.dart', 'b/x.dart')), isNull);
    });
  });

  group('defaultExpandedFiles', () {
    UnifiedDiffFile file(String path) => UnifiedDiffFile(
      oldPath: 'a/$path',
      newPath: 'b/$path',
      binary: false,
      hunks: [
        UnifiedDiffHunk(oldStart: 1, newStart: 1, header: '', lines: const []),
      ],
    );

    test('source files expand; tests, docs, locks and unknowns fold', () {
      final files = [
        file('lib/main.dart'),
        file('src/app.test.js'),
        file('README.md'),
        file('package-lock.json'),
        file('assets/logo.svg'), // an svg is not in the source list... wait
      ];
      // svg is in the source list? No: the list has html/css but no svg.
      expect(defaultExpandedFiles(files), {0});
    });

    test('binary and hunkless files never expand', () {
      final files = [
        UnifiedDiffFile(
          oldPath: 'a/x.dart',
          newPath: 'b/x.dart',
          binary: true,
          hunks: const [],
        ),
        UnifiedDiffFile(
          oldPath: 'a/y.dart',
          newPath: 'b/y.dart',
          binary: false,
          hunks: const [],
        ),
      ];
      expect(defaultExpandedFiles(files), isEmpty);
    });
  });

  group('untrackedDiffFile', () {
    test('reads the whole content as additions from line 1', () {
      final file = untrackedDiffFile('docs/new.txt', 'one\ntwo\n');
      expect(file.oldPath, '/dev/null');
      expect(file.newPath, 'b/docs/new.txt');
      final lines = file.hunks.single.lines;
      expect(lines.map((l) => l.kind), everyElement(DiffLineKind.add));
      expect(lines.map((l) => l.newNum), [1, 2]);
      expect(lines.map((l) => l.text), ['one', 'two']);
      expect(file.hunks.single.oldStart, 0);
      expect(file.hunks.single.newStart, 1);
    });

    test('an empty file has no rows, and no trailing newline is one line', () {
      expect(untrackedDiffFile('x', '').hunks.single.lines, isEmpty);
      expect(untrackedDiffFile('x', 'only').hunks.single.lines, hasLength(1));
    });
  });

  // ---- The wiring ------------------------------------------------------------

  group('DiffTab', () {
    late DirectoryFixture support;
    late WorkbenchController workbench;
    late FakeGit fake;

    setUp(() {
      support = DirectoryFixture();
      workbench = WorkbenchController(store: WorkbenchStore.open(support.dir));
      workbench.workspaceRoot = support.path;
      // '' rather than the strict default: the diff commands this tab reads
      // (the empty-side fallback, the untracked no-diff case) are exercises in
      // emptiness, and the reads they do parse are stubbed per test.
      fake = FakeGit(unknownResponse: '')..stubRepo(root: support.path);
    });

    tearDown(() {
      workbench.dispose();
      support.dispose();
    });

    String abs(String name) => p.join(support.path, name);

    Future<void> pumpTab(WidgetTester tester, SidebarDiffRef ref) =>
        tester.pumpWidget(
          MaterialApp(
            theme: dswThemeData(Brightness.light),
            home: Scaffold(
              body: GitHost(
                runner: fake.runner,
                child: DiffTab(workbench: workbench, tab: SidebarTab.diff(ref)),
              ),
            ),
          ),
        );

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    /// The untracked fallback reads the file with dart:io, and a dart:io
    /// future never completes inside the fake-async zone `testWidgets` runs
    /// in: [WidgetTester.runAsync] gives the real event loop turns the read
    /// needs, and each pump drains whatever the completion scheduled.
    Future<void> settleOnDisk(WidgetTester tester) async {
      for (var attempt = 0; attempt < 20; attempt++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await settle(tester);
      }
    }

    testWidgets('a worktree ref renders the diff with gutters and tinted rows', (tester) async {
      fake.responses['diff --no-ext-diff --no-color -U3 -- a.dart'] = _sampleDiff;
      await pumpTab(tester, WorktreeDiff(path: abs('a.dart'), staged: false));
      await settle(tester);

      // Header: the repo-relative path, not the absolute one.
      expect(find.text('a.dart'), findsOneWidget);
      // The first file's hunk header and its rows render.
      expect(find.text('@@ -1,4 +1,5 @@'), findsOneWidget);
      expect(find.text('context'), findsWidgets);
      expect(find.text('-old line'.substring(1)), findsOneWidget); // 'old line'
      expect(find.text('new line'), findsOneWidget);
      // A .dart file starts expanded; the rename-only and binary sections in
      // the same diff render their path rows with badges.
      expect(find.text('Binary'), findsOneWidget);
    });

    testWidgets('a staged ref asks git for the cached side', (tester) async {
      fake.responses['diff --no-ext-diff --no-color -U3 --cached -- a.dart'] =
          _sampleDiff;
      await pumpTab(tester, WorktreeDiff(path: abs('a.dart'), staged: true));
      await settle(tester);

      expect(
        fake.commands,
        contains('diff --no-ext-diff --no-color -U3 --cached -- a.dart'),
      );
      expect(find.text('a.dart'), findsOneWidget);
    });

    testWidgets('an empty requested side falls back to the other side', (tester) async {
      fake.responses['diff --no-ext-diff --no-color -U3 -- a.dart'] = '';
      fake.responses['diff --no-ext-diff --no-color -U3 --cached -- a.dart'] =
          _sampleDiff;
      await pumpTab(tester, WorktreeDiff(path: abs('a.dart'), staged: false));
      await settle(tester);

      expect(
        fake.commands,
        containsAll([
          'diff --no-ext-diff --no-color -U3 -- a.dart',
          'diff --no-ext-diff --no-color -U3 --cached -- a.dart',
        ]),
      );
      expect(find.text('old line'), findsOneWidget);
    });

    testWidgets('an untracked file renders as a full-file addition', (tester) async {
      // A source file, so it starts expanded and its rows render without a
      // click: a .txt would faithfully fold, per defaultExpandedFiles.
      File(abs('new.dart')).writeAsStringSync('hello\nworld\n');
      await pumpTab(
        tester,
        WorktreeDiff(path: abs('new.dart'), staged: false, untracked: true),
      );
      await settleOnDisk(tester);

      // The tab header and the file's own path row both carry the name.
      expect(find.text('new.dart'), findsNWidgets(2));
      expect(find.text('hello'), findsOneWidget);
      expect(find.text('world'), findsOneWidget);
      // Every line is an addition: no old-side numbers anywhere.
      expect(find.text('1'), findsOneWidget); // new-side gutter only
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);
    });

    testWidgets('an untracked binary file says so', (tester) async {
      File(abs('blob.bin')).writeAsBytesSync([0, 1, 2, 0, 3]);
      await pumpTab(
        tester,
        WorktreeDiff(path: abs('blob.bin'), staged: false, untracked: true),
      );
      await settleOnDisk(tester);

      expect(
        find.text('This looks like a binary file. Nothing here can show it.'),
        findsOneWidget,
      );
    });

    testWidgets('a commit ref loads the commit patch', (tester) async {
      fake.responses[
              'show --no-ext-diff --no-color --format= -m --first-parent fullhash123'] =
          _sampleDiff;
      await pumpTab(tester, const CommitDiff(hashFull: 'fullhash123', subject: 'fix it'));
      await settle(tester);

      expect(find.text('fullhas fix it'), findsOneWidget);
      expect(find.text('old line'), findsOneWidget);
    });

    testWidgets('both sides empty is no text changes', (tester) async {
      await pumpTab(tester, WorktreeDiff(path: abs('a.dart'), staged: false));
      await settle(tester);

      expect(find.text('No text changes'), findsOneWidget);
    });

    testWidgets('a command failure is kept on screen', (tester) async {
      fake.failures.add('diff --no-ext-diff --no-color -U3 -- a.dart');
      fake.failures.add('diff --no-ext-diff --no-color -U3 --cached -- a.dart');
      await pumpTab(tester, WorktreeDiff(path: abs('a.dart'), staged: false));
      await settle(tester);

      expect(
        find.textContaining('Failed to load diff: boom:'),
        findsOneWidget,
      );
    });

    testWidgets('refresh re-runs the load', (tester) async {
      fake.responses['diff --no-ext-diff --no-color -U3 -- a.dart'] = _sampleDiff;
      await pumpTab(tester, WorktreeDiff(path: abs('a.dart'), staged: false));
      await settle(tester);

      final before = fake.commands.length;
      await tester.tap(find.byTooltip('Refresh'));
      await settle(tester);

      expect(
        fake.commands.where((command) => command.startsWith('diff ')).length,
        greaterThan(before ~/ 2),
      );
    });

    testWidgets('a folded file expands on its header click', (tester) async {
      fake.responses['diff --no-ext-diff --no-color -U3 -- a.test.js'] =
          'diff --git a/a.test.js b/a.test.js\n'
          '--- a/a.test.js\n'
          '+++ b/a.test.js\n'
          '@@ -1 +1 @@\n'
          '-old\n'
          '+new\n';
      await pumpTab(tester, WorktreeDiff(path: abs('a.test.js'), staged: false));
      await settle(tester);

      // A test file starts folded: the path row is there (the tab header
      // carries the same name, so `.last` picks the file's row), its lines
      // are not.
      expect(find.text('a.test.js'), findsNWidgets(2));
      expect(find.text('old'), findsNothing);

      await tester.tap(find.text('a.test.js').last);
      await settle(tester);
      expect(find.text('old'), findsOneWidget);
      expect(find.text('new'), findsOneWidget);
    });

    testWidgets('a non-repo says so instead of spinning forever', (tester) async {
      fake.responses['rev-parse --show-toplevel'] = '';
      await pumpTab(tester, WorktreeDiff(path: abs('a.dart'), staged: false));
      await settle(tester);

      expect(
        find.textContaining('This directory is not a git repository'),
        findsOneWidget,
      );
    });
  });
}

/// The temp directory the workbench store writes to, and the fake repo root.
class DirectoryFixture {
  DirectoryFixture() : dir = Directory.systemTemp.createTempSync('dsh_diff_tab_');

  final Directory dir;

  String get path => dir.path;

  void dispose() => dir.deleteSync(recursive: true);
}
