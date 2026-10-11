// The sentence this file holds: importing a skill flattens its description to
// one line and inlines its references, so the skill survives genkit_middleware's
// single-line frontmatter parse and the workspace-relative read tool. Nothing
// else. See docs/flutter-website-agent-skills-integration-2026-10-11.md §2.2.
//
// The transforms are pure and tested directly; only the round-trip touches a
// real temp tree, because "the file it writes is the file the middleware reads"
// is a filesystem fact.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

// A relative import with `show`: `package:` URIs resolve only under `lib/`, and
// this tool is run by hand. `show` keeps the tool's `main`/`exit` out of scope.
import '../tool/import_agent_skill.dart'
    show
        ReferenceFile,
        buildImportedSkill,
        collectReferences,
        flattenScalar,
        importSkill,
        splitFrontmatter;

const _writeFlutterSkill = '''
---
name: write-flutter
description: >-
  Write, review, or refactor idiomatic Flutter code.
  Use for widgets, state and architecture, lifecycle, layout, theming,
  accessibility, performance, and tests.
---

# Write Flutter

Produce Flutter code that is composable.

## References

- **[Widgets](references/widgets.md)**: Composition and keys.
''';

void main() {
  group('flattenScalar', () {
    test('folds a >- block scalar onto one line', () {
      const fm =
          'name: write-flutter\n'
          'description: >-\n'
          '  Write, review, or refactor idiomatic Flutter code.\n'
          '  Use for widgets and tests.';
      expect(
        flattenScalar(fm, 'description'),
        'Write, review, or refactor idiomatic Flutter code. '
        'Use for widgets and tests.',
      );
    });

    test('flattens a literal | block scalar onto one line', () {
      const fm =
          'description: |\n'
          '  first line\n'
          '  second line\n'
          'name: x';
      expect(flattenScalar(fm, 'description'), 'first line second line');
    });

    test('stops the block at the next dedented key', () {
      const fm =
          'description: >-\n'
          '  only this\n'
          'name: after';
      expect(flattenScalar(fm, 'description'), 'only this');
      expect(flattenScalar(fm, 'name'), 'after');
    });

    test('keeps an inline scalar, unquoting it', () {
      expect(
        flattenScalar('description: plain text', 'description'),
        'plain text',
      );
      expect(
        flattenScalar('description: "quoted text"', 'description'),
        'quoted text',
      );
    });

    test('returns empty for an absent key', () {
      expect(flattenScalar('name: x', 'description'), '');
    });
  });

  group('splitFrontmatter', () {
    test('separates the fence from the body', () {
      final split = splitFrontmatter(_writeFlutterSkill);
      expect(split, isNotNull);
      expect(split!.$1, contains('name: write-flutter'));
      expect(split.$2.trimLeft(), startsWith('# Write Flutter'));
    });

    test('returns null without a leading fence', () {
      expect(splitFrontmatter('# just a body\n'), isNull);
    });
  });

  group('buildImportedSkill', () {
    test('emits a single-line description and no block indicator', () {
      final out = buildImportedSkill(
        skillMd: _writeFlutterSkill,
        dirName: 'write-flutter',
        references: const [],
        origin: 'github.com/flutter/website (CC-BY-3.0)',
      );
      final fm = splitFrontmatter(out)!.$1;
      final descLine = fm
          .split('\n')
          .firstWhere((l) => l.startsWith('description:'));
      expect(descLine, isNot(contains('>-')));
      expect(descLine, contains('idiomatic Flutter code.'));
      // The middleware regex reads the rest of this one physical line.
      expect(
        fm.split('\n').where((l) => l.startsWith('description:')),
        hasLength(1),
      );
    });

    test('falls back to the directory name when frontmatter has none', () {
      final out = buildImportedSkill(
        skillMd: '---\ndescription: hi\n---\n\nbody',
        dirName: 'my-skill',
        references: const [],
        origin: 'x',
      );
      expect(splitFrontmatter(out)!.$1, contains('name: my-skill'));
    });

    test('inlines each reference under a heading and stamps attribution', () {
      final out = buildImportedSkill(
        skillMd: _writeFlutterSkill,
        dirName: 'write-flutter',
        references: const [
          ReferenceFile('references/widgets.md', '# Widgets\n\nKeys matter.'),
        ],
        origin: 'github.com/flutter/website (CC-BY-3.0)',
      );
      expect(out, contains('## Reference: references/widgets.md'));
      expect(out, contains('Keys matter.'));
      expect(out, contains('github.com/flutter/website (CC-BY-3.0)'));
      expect(out, contains('# Write Flutter')); // original body preserved.
    });
  });

  group('importSkill round-trip', () {
    late Directory temp;
    setUp(() => temp = Directory.systemTemp.createTempSync('import_skill_'));
    tearDown(() => temp.deleteSync(recursive: true));

    test('writes <out>/<name>/SKILL.md with references inlined', () {
      final src = Directory(p.join(temp.path, 'write-flutter'))
        ..createSync(recursive: true);
      File(p.join(src.path, 'SKILL.md')).writeAsStringSync(_writeFlutterSkill);
      final refs = Directory(p.join(src.path, 'references'))..createSync();
      File(
        p.join(refs.path, 'widgets.md'),
      ).writeAsStringSync('# Widgets\n\nComposition.');

      final outRoot = Directory(p.join(temp.path, 'out'));
      final written = importSkill(src, outRoot, origin: 'test-origin');

      expect(written, p.join(outRoot.path, 'write-flutter', 'SKILL.md'));
      final text = File(written).readAsStringSync();
      expect(text, contains('## Reference: references/widgets.md'));
      expect(text, contains('Composition.'));
      expect(splitFrontmatter(text)!.$1, isNot(contains('>-')));
      // Only SKILL.md is written; references are inlined, not copied.
      expect(
        Directory(p.join(outRoot.path, 'write-flutter')).listSync(),
        hasLength(1),
      );
    });

    test('collectReferences labels paths relative to the skill dir', () {
      final src = Directory(p.join(temp.path, 's'))
        ..createSync(recursive: true);
      File(p.join(src.path, 'SKILL.md')).writeAsStringSync('---\n---\n');
      final refs = Directory(p.join(src.path, 'references'))..createSync();
      File(p.join(refs.path, 'a.md')).writeAsStringSync('A');

      final collected = collectReferences(src);
      expect(collected, hasLength(1));
      expect(collected.single.label, 'references/a.md');
    });

    test('throws when the source has no SKILL.md', () {
      final src = Directory(p.join(temp.path, 'empty'))..createSync();
      expect(
        () => importSkill(src, Directory(p.join(temp.path, 'o')), origin: 'x'),
        throwsStateError,
      );
    });
  });
}
