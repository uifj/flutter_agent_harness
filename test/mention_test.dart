// The `@` mention pipeline — a port of dsh-at-file (FSMargoo/dsh-at-file),
// pinned at its three pure seams: the workspace index that walks the tree,
// the ranking that orders the picker, and the expansion that turns `@path`
// prose into references the model sees.
//
// The index and the expansion are tested against a real temp tree because
// their contracts are filesystem facts — ignore rules, symlink cycles,
// existence probes — that a fake could not vouch for. The ranking is pure
// functions over lists, so it is pinned with no filesystem at all.

import 'dart:io';

import 'package:agent_harness/model/file_search_rank.dart';
import 'package:agent_harness/model/mention_expansion.dart';
import 'package:agent_harness/model/workspace.dart';
import 'package:agent_harness/model/workspace_index.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

FileEntry file(String relative) => FileEntry(relative: relative, kind: 'file');
FileEntry dir(String relative) => FileEntry(relative: relative, kind: 'dir');

void main() {
  group('scanMentions', () {
    test('extracts every @token, deduplicated in first-seen order', () {
      expect(
        scanMentions('look at @src/main.dart and @pubspec.yaml then @src/main.dart again'),
        ['src/main.dart', 'pubspec.yaml'],
      );
    });

    test('a trailing slash — the directory-pick form — is stripped', () {
      expect(scanMentions('check @src/ and @src'), ['src']);
    });

    test('text without an @ scans to nothing', () {
      expect(scanMentions('just words'), isEmpty);
    });

    test('a token closes at whitespace or another @', () {
      // The pattern is `@` then a run of non-space non-@, so 'a@b c@d' scans
      // 'b' and 'c@d' never merges the two.
      expect(scanMentions('a@b c@d'), ['b', 'd']);
    });
  });

  group('resolveMentions', () {
    late Directory temp;
    late Directory root;
    late Workspace workspace;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('dsh_mention_test_');
      root = Directory(p.join(temp.path, 'root'))..createSync();
      File(p.join(root.path, 'main.dart')).writeAsStringSync('void main() {}');
      Directory(p.join(root.path, 'src')).createSync();
      File(p.join(root.path, 'src', 'util.dart')).writeAsStringSync('util');
      workspace = Workspace.of(root.path);
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('a file mention resolves as a file', () {
      expect(
        resolveMentions('see @main.dart', workspace),
        [const Mention(relative: 'main.dart', isDirectory: false)],
      );
    });

    test('a directory mention resolves as a directory, slash or not', () {
      expect(
        resolveMentions('see @src/ please', workspace),
        [const Mention(relative: 'src', isDirectory: true)],
      );
      expect(
        resolveMentions('see @src please', workspace),
        [const Mention(relative: 'src', isDirectory: true)],
      );
    });

    test('a nested path mentions fine', () {
      expect(
        resolveMentions('see @src/util.dart', workspace),
        [const Mention(relative: 'src/util.dart', isDirectory: false)],
      );
    });

    test('an unknown path stays plain prose — no mention, no error', () {
      // The plugin's rule: a false mention must not become an error the user
      // has to fix before their question goes out.
      expect(resolveMentions('email me at @nowhere', workspace), isEmpty);
    });

    test('an escape outside the workspace is refused', () {
      expect(resolveMentions('see @../outside', workspace), isEmpty);
      expect(resolveMentions('see @/etc/hosts', workspace), isEmpty);
    });
  });

  group('referenceForm', () {
    test('a file reference carries path and kind', () {
      expect(
        referenceForm(const Mention(relative: 'src/main.dart', isDirectory: false)),
        '<workspace-reference path="src/main.dart" kind="file" />',
      );
    });

    test('a directory reference says directory', () {
      expect(
        referenceForm(const Mention(relative: 'src', isDirectory: true)),
        '<workspace-reference path="src" kind="directory" />',
      );
    });

    test('a path with markup cannot break out of the attribute', () {
      expect(
        referenceForm(const Mention(relative: 'a&b<c>"d"', isDirectory: false)),
        '<workspace-reference path="a&amp;b&lt;c&gt;&quot;d&quot;" kind="file" />',
      );
    });
  });

  group('indexWorkspace', () {
    late Directory temp;
    late Directory root;

    File write(String relative) {
      final f = File(p.join(root.path, relative));
      f.parent.createSync(recursive: true);
      return f..writeAsStringSync('');
    }

    setUp(() {
      temp = Directory.systemTemp.createTempSync('dsh_index_test_');
      root = Directory(p.join(temp.path, 'root'))..createSync();
    });

    tearDown(() => temp.deleteSync(recursive: true));

    test('collects files and directories, sorted by path', () {
      write('a.txt');
      write('src/main.dart');

      final index = indexWorkspace(root.path);

      expect(index.truncated, isFalse);
      expect(index.entries, [
        file('a.txt'),
        dir('src'),
        file('src/main.dart'),
      ]);
    });

    test('skips the well-known ignore dirs and OS metadata files', () {
      write('kept.txt');
      write('node_modules/buried.js');
      write('.git/objects/pack');
      write('.DS_Store');

      final index = indexWorkspace(root.path);

      expect(
        index.entries.map((e) => e.relative).toSet(),
        {'kept.txt'},
      );
    });

    test('a cap past the tree is admitted by the truncated flag', () {
      write('a.txt');
      write('b.txt');

      final index = indexWorkspace(root.path, maxEntries: 1);

      expect(index.entries, hasLength(1));
      expect(index.truncated, isTrue);
    });

    test('a root that does not exist is an empty index, not a throw', () {
      final index = indexWorkspace(p.join(temp.path, 'nope'));

      expect(index.entries, isEmpty);
      expect(index.truncated, isFalse);
    });

    test('a symlinked file is indexed by its target kind', () {
      write('real.txt');
      Link(p.join(root.path, 'alias.txt'))
          .createSync(p.join(root.path, 'real.txt'));

      final index = indexWorkspace(root.path);

      expect(index.entries.map((e) => e.kind), everyElement('file'));
      expect(
        index.entries.map((e) => e.relative).toSet(),
        {'alias.txt', 'real.txt'},
      );
    }, skip: Platform.isWindows ? 'symlinks need privileges on Windows' : null);

    test('a symlink cycle terminates', () {
      write('src/main.dart');
      // The classic loop: a link back to the root, inside the root.
      Link(p.join(root.path, 'src', 'loop'))
          .createSync(root.path);

      final index = indexWorkspace(root.path);

      expect(index.truncated, isFalse);
      expect(
        index.entries.map((e) => e.relative),
        containsAll(['src', 'src/main.dart', 'src/loop']),
      );
    }, skip: Platform.isWindows ? 'symlinks need privileges on Windows' : null);
  });

  group('rankFiles', () {
    final workspaceFiles = [
      file('README.md'),
      dir('src'),
      file('src/main.dart'),
      file('src/manager.dart'),
      file('lib/main.dart'),
      file('lib/manuscript.tex'),
    ];

    test('an empty query browses: shallow first, dirs before files, then name', () {
      expect(
        rankFiles(workspaceFiles, '', 50).map((e) => e.relative),
        ['src', 'README.md', 'lib/main.dart', 'lib/manuscript.tex',
         'src/main.dart', 'src/manager.dart'],
      );
    });

    test('a plain query matches basenames only', () {
      // 'main' must not match 'src/manager.dart' via a path spread: the rule
      // is basename scoring for a separator-less query.
      final ranked = rankFiles(workspaceFiles, 'main', 50);
      expect(
        ranked.map((e) => e.relative),
        containsAll(['src/main.dart', 'lib/main.dart']),
      );
      expect(ranked.map((e) => e.relative), isNot(contains('src/manager.dart')));
    });

    test('an exact basename outranks a prefix which outranks a substring', () {
      final files = [
        file('src/man.dart'),
        file('man.dart'),
        file('manual.dart'),
      ];
      // 'src/man.dart' outranks 'manual.dart': the path query's penalty is
      // length alone, so a basename-exact hit deep in the tree still beats a
      // fuzzy hit at the root — the plugin's own arithmetic.
      expect(
        rankFiles(files, 'man.dart', 50).map((e) => e.relative),
        ['man.dart', 'src/man.dart', 'manual.dart'],
      );
    });

    test('a query with separators matches ordered path segments', () {
      final ranked = rankFiles(workspaceFiles, 'src/ma', 50);
      expect(
        ranked.map((e) => e.relative),
        containsAll(['src/main.dart', 'src/manager.dart']),
      );
      // A 'ma' basename in another directory is not a 'src/ma' match.
      expect(ranked.map((e) => e.relative), isNot(contains('lib/manuscript.tex')));
    });

    test('a trailing-slash query is a directory-prefix browse', () {
      final ranked = rankFiles(workspaceFiles, 'src/', 50);
      expect(
        ranked.map((e) => e.relative),
        containsAll(['src/main.dart', 'src/manager.dart']),
      );
      expect(ranked.map((e) => e.relative), isNot(contains('lib/main.dart')));
    });

    test('matching is case-insensitive', () {
      expect(
        rankFiles(workspaceFiles, 'README', 50).map((e) => e.relative),
        ['README.md'],
      );
    });

    test('no match is empty, and the limit caps the list', () {
      expect(rankFiles(workspaceFiles, 'zzz', 50), isEmpty);
      expect(rankFiles(workspaceFiles, '', 2), hasLength(2));
    });

    test('the query is trimmed', () {
      expect(
        rankFiles(workspaceFiles, ' main ', 50).map((e) => e.relative),
        containsAll(['src/main.dart', 'lib/main.dart']),
      );
    });
  });

  group('basenameOf / dirnameOf', () {
    test('root-level files have an empty directory', () {
      expect(basenameOf('main.dart'), 'main.dart');
      expect(dirnameOf('main.dart'), '');
    });

    test('nested paths split at the last slash', () {
      expect(basenameOf('src/ui/main.dart'), 'main.dart');
      expect(dirnameOf('src/ui/main.dart'), 'src/ui');
    });
  });
}
