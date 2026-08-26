// The glob and grep engine. The pattern translation is unit-tested directly
// because every one of its rules is a promise the tool's own description makes to
// the model; the walk is tested against a real temp tree, since the things worth
// checking — ordering by mtime, skipping VCS metadata, bailing on binaries — are
// filesystem facts and not logic a fake could show.

import 'dart:io';

import 'package:agent_harness/genkit/file_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('the glob translation', () {
    /// Whether [pattern] matches [path], which is the only thing the walk asks.
    bool matches(String pattern, String path) =>
        globToRegExp(pattern).hasMatch(path);

    test('a pattern without a separator matches the basename at any depth', () {
      // The documented rule, and the difference between the tool working on the
      // first call and needing a second one.
      expect(matches('*.dart', 'main.dart'), isTrue);
      expect(matches('*.dart', 'lib/genkit/tools.dart'), isTrue);
      expect(matches('*.dart', 'main.txt'), isFalse);
    });

    test('a pattern with a separator is anchored at the root', () {
      expect(matches('lib/*.dart', 'lib/main.dart'), isTrue);
      expect(matches('lib/*.dart', 'lib/ui/main.dart'), isFalse);
      expect(matches('lib/*.dart', 'test/lib/main.dart'), isFalse);
    });

    test('`**/` matches no directories as well as many', () {
      // Without this, `**/*.dart` would silently skip every file at the root.
      expect(matches('**/*.dart', 'main.dart'), isTrue);
      expect(matches('**/*.dart', 'a/b/c/main.dart'), isTrue);
    });

    test('one star stays inside a segment', () {
      expect(matches('lib/*', 'lib/main.dart'), isTrue);
      expect(matches('lib/*', 'lib/ui/main.dart'), isFalse);
    });

    test('a brace group is an alternation', () {
      expect(matches('*.{dart,yaml}', 'pubspec.yaml'), isTrue);
      expect(matches('*.{dart,yaml}', 'main.dart'), isTrue);
      expect(matches('*.{dart,yaml}', 'main.json'), isFalse);
    });

    test('a comma outside a brace group is a comma', () {
      expect(matches('a,b.txt', 'a,b.txt'), isTrue);
      expect(matches('a,b.txt', 'a.txt'), isFalse);
    });

    test('a question mark is one character, not a separator', () {
      expect(matches('a?.txt', 'ab.txt'), isTrue);
      expect(matches('a?.txt', 'a/.txt'), isFalse);
    });

    test('a dot is a dot', () {
      expect(matches('a.txt', 'axtxt'), isFalse);
    });
  });

  group('against a real tree', () {
    late Directory root;

    /// Writes [text] to [relative] under the root, creating parents.
    File write(String relative, String text) {
      final file = File(p.join(root.path, relative));
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(text);
      return file;
    }

    setUp(() {
      root = Directory.systemTemp.createTempSync('dsh_search_test_');
    });

    tearDown(() => root.deleteSync(recursive: true));

    group('glob', () {
      test('finds files at every depth, hidden ones included', () async {
        write('a.txt', '');
        write('deep/b.txt', '');
        write('.hidden.txt', '');

        final found = await globFiles(root: root, pattern: '*.txt');

        // "including hidden and ignored files", as the tool's description says.
        expect(
          found.hits.map((h) => h.path).toSet(),
          {'a.txt', p.join('deep', 'b.txt'), '.hidden.txt'},
        );
        expect(found.capped, isFalse);
        expect(found.timedOut, isFalse);
      });

      test('never returns a directory', () async {
        Directory(p.join(root.path, 'src.txt')).createSync();
        write('real.txt', '');

        final found = await globFiles(root: root, pattern: '*.txt');

        // A directory named like the pattern is still not a readable path, and
        // the description promises "never directories".
        expect(found.hits.map((h) => h.path), ['real.txt']);
      });

      test('skips VCS metadata', () async {
        write('.git/objects/blob.txt', '');
        write('kept.txt', '');

        final found = await globFiles(root: root, pattern: '*.txt');

        expect(found.hits.map((h) => h.path), ['kept.txt']);
      });

      test('orders newest first', () async {
        write('old.txt', '')
            .setLastModifiedSync(DateTime(2020, 1, 1));
        write('new.txt', '')
            .setLastModifiedSync(DateTime(2024, 1, 1));
        write('middle.txt', '')
            .setLastModifiedSync(DateTime(2022, 1, 1));

        final found = await globFiles(root: root, pattern: '*.txt');

        expect(found.hits.map((h) => h.path), [
          'new.txt',
          'middle.txt',
          'old.txt',
        ]);
      });

      test('a capped page keeps the newest and admits the count', () async {
        write('old.txt', '').setLastModifiedSync(DateTime(2020, 1, 1));
        write('new.txt', '').setLastModifiedSync(DateTime(2024, 1, 1));

        final found =
            await globFiles(root: root, pattern: '*.txt', maxResults: 1);

        // The cap comes off the head, so what survives is the half the model
        // most likely wanted.
        expect(found.hits.map((h) => h.path), ['new.txt']);
        expect(found.total, 2);
        expect(found.capped, isTrue);
      });

      test('no match is an empty answer, not a failure', () async {
        write('a.txt', '');

        final found = await globFiles(root: root, pattern: '*.dart');

        expect(found.hits, isEmpty);
        expect(found.total, 0);
        expect(found.capped, isFalse);
      });
    });

    group('grep', () {
      test('reports path, line number and text, grouped across files', () async {
        write('a.txt', 'nothing\nneedle here\n');
        write('deep/b.txt', 'needle\n');

        final found = await grepFiles(
          target: root,
          pattern: RegExp('needle'),
        );

        expect(found.total, 2);
        expect(found.files, 2);
        final byPath = {for (final hit in found.hits) hit.path: hit};
        expect(byPath['a.txt']!.line, 2);
        expect(byPath['a.txt']!.text, 'needle here');
        expect(byPath[p.join('deep', 'b.txt')]!.line, 1);
      });

      test('the include filter narrows by glob', () async {
        write('a.dart', 'needle');
        write('b.txt', 'needle');

        final found = await grepFiles(
          target: root,
          pattern: RegExp('needle'),
          include: '*.dart',
        );

        expect(found.hits.map((h) => h.path), ['a.dart']);
      });

      test('a single file target searches just it', () async {
        write('other.txt', 'needle');
        final one = write('one.txt', 'needle');

        final found = await grepFiles(
          target: one,
          pattern: RegExp('needle'),
        );

        expect(found.files, 1);
        expect(found.hits.single.path, 'one.txt');
      });

      test('a binary file contributes nothing at all', () async {
        File(p.join(root.path, 'blob.bin'))
            .writeAsBytesSync([0x6e, 0x65, 0x00, 0x65, 0x64, 0x6c, 0x65]);
        write('text.txt', 'needle');

        final found = await grepFiles(
          target: root,
          pattern: RegExp('ne'),
        );

        // Not "nothing on the NUL line": a binary file's lines are arbitrary, so
        // its matches would be noise even where the regex hits.
        expect(found.hits.map((h) => h.path), ['text.txt']);
        expect(found.files, 1);
      });

      test('a long line comes back as a preview', () async {
        write('long.txt', 'needle${'x' * 50}');

        final found = await grepFiles(
          target: root,
          pattern: RegExp('needle'),
          maxLineBytes: 10,
        );

        expect(found.hits.single.text, 'needlexxxx… (line truncated)');
      });

      test('a capped page counts past what it kept', () async {
        write('many.txt', List.filled(10, 'needle').join('\n'));

        final found = await grepFiles(
          target: root,
          pattern: RegExp('needle'),
          maxMatches: 3,
        );

        expect(found.hits, hasLength(3));
        expect(found.total, 10, reason: 'the count is what says "too wide"');
        expect(found.capped, isTrue);
      });

      test('a regex is a regex, not a literal', () async {
        write('a.txt', 'foo123bar');

        final found = await grepFiles(
          target: root,
          pattern: RegExp(r'foo\d+bar'),
        );

        expect(found.hits, hasLength(1));
      });
    });
  });
}
