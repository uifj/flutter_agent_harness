// Import a third-party agent skill into PlanStar's skills directory.
//
// PlanStar's runtime agent loads skills through genkit_middleware's
// `SkillsPlugin`, whose contract is narrower than the format skill authors
// ship (see docs/flutter-website-agent-skills-integration-2026-10-11.md §2.2):
//
//   * it scans only the immediate sub-directories of each skill path, each
//     needing a `SKILL.md`;
//   * it parses `name` and `description` from the frontmatter with a
//     single-line regex, so a YAML folded/literal block (`description: >-`)
//     is captured as the literal indicator and the skill's description is
//     lost;
//   * `use_skill` returns the raw `SKILL.md` text, and the agent's read tool
//     resolves relative paths against the workspace — so a skill's
//     `references/*.md`, which live beside the skill outside the workspace,
//     are unreachable.
//
// This tool rewrites a source skill into that contract: it flattens the
// description onto one line, inlines every `references/**.md` into the body,
// and stamps an attribution line (skill content is commonly CC-BY). The
// transform is pure Dart so it is unit-testable; only `main` and `importSkill`
// touch the filesystem.
//
// Usage:
//   dart run tool/import_agent_skill.dart --out <skillsRoot> \
//       [--origin "<provenance label>"] <srcSkillDir> [<srcSkillDir> ...]

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:planstar/genkit/skill_frontmatter.dart';

// Re-exported so `test/import_agent_skill_test.dart` — which reaches this tool
// by relative path, since `package:` URIs resolve only under `lib/` — still gets
// the parser through it. One parser, two callers; see skill_frontmatter.dart.
export 'package:planstar/genkit/skill_frontmatter.dart'
    show flattenScalar, splitFrontmatter;

/// One inlined reference file: its workspace-relative label and its content.
class ReferenceFile {
  const ReferenceFile(this.label, this.content);

  /// e.g. `references/widgets.md`.
  final String label;
  final String content;
}

/// Builds the imported `SKILL.md`: single-line frontmatter, an attribution
/// comment, the original body, then every reference inlined under a heading.
///
/// [dirName] is the skill's directory name — the name the middleware keys the
/// skill by — used as a fallback when the frontmatter has no `name`.
String buildImportedSkill({
  required String skillMd,
  required String dirName,
  required List<ReferenceFile> references,
  required String origin,
}) {
  final split = splitFrontmatter(skillMd);
  final frontmatter = split?.$1 ?? '';
  final body = split?.$2 ?? skillMd;

  final name = flattenScalar(frontmatter, 'name');
  final resolvedName = name.isEmpty ? dirName : name;
  final description = flattenScalar(frontmatter, 'description');

  final buffer = StringBuffer()
    ..writeln('---')
    ..writeln('name: $resolvedName');
  if (description.isNotEmpty) {
    buffer.writeln('description: $description');
  }
  buffer
    ..writeln('---')
    ..writeln()
    ..writeln(
      '<!-- Imported by tool/import_agent_skill.dart from $origin. '
      'Description flattened to one line and references inlined below so '
      'the skill survives genkit_middleware\'s single-line frontmatter '
      'parse and workspace-relative read tool. -->',
    )
    ..writeln()
    ..writeln(body.trim());

  for (final reference in references) {
    buffer
      ..writeln()
      ..writeln('---')
      ..writeln()
      ..writeln('## Reference: ${reference.label}')
      ..writeln()
      ..writeln(reference.content.trim());
  }
  return buffer.toString();
}

/// Reads every `**.md` under `<src>/references`, labelled by its path relative
/// to [src], sorted for deterministic output. Empty when there are none.
List<ReferenceFile> collectReferences(Directory src) {
  final refDir = Directory(p.join(src.path, 'references'));
  if (!refDir.existsSync()) return const [];
  final files =
      refDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.md'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      ReferenceFile(
        p.relative(file.path, from: src.path).replaceAll(p.separator, '/'),
        file.readAsStringSync(),
      ),
  ];
}

/// Imports one source skill directory into [outRoot]. Returns the path written.
String importSkill(Directory src, Directory outRoot, {required String origin}) {
  final skillFile = File(p.join(src.path, 'SKILL.md'));
  if (!skillFile.existsSync()) {
    throw StateError('${src.path} has no SKILL.md');
  }
  final dirName = p.basename(src.path);
  final imported = buildImportedSkill(
    skillMd: skillFile.readAsStringSync(),
    dirName: dirName,
    references: collectReferences(src),
    origin: origin,
  );
  final target = Directory(p.join(outRoot.path, dirName))
    ..createSync(recursive: true);
  final out = File(p.join(target.path, 'SKILL.md'))
    ..writeAsStringSync(imported);
  return out.path;
}

void main(List<String> argv) {
  String? outPath;
  String? origin;
  final sources = <String>[];
  for (var i = 0; i < argv.length; i++) {
    final arg = argv[i];
    if (arg == '--out') {
      outPath = argv[++i];
    } else if (arg == '--origin') {
      origin = argv[++i];
    } else if (arg.startsWith('--')) {
      stderr.writeln('Unknown option: $arg');
      exit(64);
    } else {
      sources.add(arg);
    }
  }

  if (outPath == null || sources.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/import_agent_skill.dart --out <skillsRoot> '
      '[--origin "<label>"] <srcSkillDir> [<srcSkillDir> ...]',
    );
    exit(64);
  }

  final outRoot = Directory(outPath);
  var failed = 0;
  for (final source in sources) {
    final src = Directory(source);
    if (!src.existsSync()) {
      stderr.writeln('skip: $source is not a directory');
      failed++;
      continue;
    }
    final label = origin ?? p.absolute(source);
    try {
      final written = importSkill(src, outRoot, origin: label);
      final bytes = File(written).lengthSync();
      stdout.writeln(
        'imported ${p.basename(source)} → $written ($bytes bytes)',
      );
    } on StateError catch (e) {
      stderr.writeln('skip: ${e.message}');
      failed++;
    }
  }
  exit(failed == 0 ? 0 : 1);
}
