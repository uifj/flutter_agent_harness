// The architecture gate: this repo's invariants, as a command.
//
// `AGENTS.md` §3 and `.qoder/rules/workflow.md` §0 state three hard invariants
// and a few weaker conventions, and until now the only way to check them was a
// person running grep. This makes the check executable, so a rule can fail a
// pull request instead of a code review.
//
//   dart tool/check_architecture.dart            # check (exit 1 on new violations)
//   dart tool/check_architecture.dart --update    # re-record the baseline
//   dart tool/check_architecture.dart --verbose   # list every finding
//
// Two design decisions, both taken from the ZCode evaluation
// (`docs/zcode-vs-agent-harness-2026-09.md` §6):
//
//   * **Ratchet, not rewrite.** A baseline file records today's violations and
//     only NEW ones fail. Rules 4 and 5 have real existing debt (UI files reach
//     for `dart:io`; the ratchet has to start from where the code is), and a
//     gate that fails on day one gets ignored. Deleting a violation shrinks the
//     baseline — run `--update` to bank it.
//   * **A fingerprint is rule + file + the matched line**, not the line number.
//     Moving an import does not look like fixing it, and editing the text does.
//
// The size ceiling is a warning on purpose: 35 files here are already over
// 400 lines, so a hard limit would be fiction. ZCode's own numbers (14 of 15
// modules unmanaged, one 6363-line file) are the cautionary tale for treating
// a size rule as a blocker.
//
// Only `dart:io` and `dart:convert` — no Flutter, so this runs in CI on any
// platform and inside `flutter test` as an ordinary test.

import 'dart:convert';
import 'dart:io';

/// A fingerprinted violation: the rule, the file, and the text that tripped it.
class Violation {
  const Violation(this.rule, this.path, this.line);

  final String rule;
  final String path;
  final String line;

  String get fingerprint => '$rule|$path|$line';
}

/// Which imports a directory may not contain.
///
/// [appliesTo] selects the files scanned (path prefixes under the repo root),
/// [pattern] matches the offending line, [skip] keeps a path out of the scan at
/// all, and [exempt] drops a path's findings as a documented exception. What is
/// merely tolerated today lives in the baseline file, not here.
class Rule {
  const Rule({
    required this.name,
    required this.description,
    required this.appliesTo,
    required this.pattern,
    this.skip = const [],
    this.exempt = const [],
  });

  final String name;
  final String description;

  /// Path prefixes scanned, relative to the repo root.
  final List<String> appliesTo;

  /// Matches a single line (already trimmed, separators normalised to `/`).
  final RegExp pattern;

  /// Paths never scanned — the generated `*.g.dart` files, this tool itself.
  final List<String> skip;

  /// Paths whose findings are dropped as documented exceptions.
  final List<String> exempt;

  bool _applies(String path) =>
      appliesTo.any(path.startsWith) && !skip.any(path.startsWith);
}

/// The rules. Numbers refer to `AGENTS.md` §3 and `workflow.md` §0 / §2.
/// (`RegExp` is a factory, not a const constructor, so this is `final`.)
final rules = [
  Rule(
    name: 'genkit-stays-in-lib-genkit',
    description:
        'Genkit is confined to lib/genkit/ (invariant 1) — a breaking 0.x '
        'change should hit two files, not the widget tree',
    appliesTo: ['lib/'],
    skip: ['lib/genkit/'],
    pattern: RegExp(r"^import 'package:genkit"),
  ),
  Rule(
    name: 'model-stays-framework-free',
    description:
        'lib/model/ imports no Flutter (invariant 2) — it is the only '
        'vocabulary between the runtime and the UI',
    appliesTo: ['lib/model/'],
    pattern: RegExp(r"^import 'package:flutter"),
  ),
  Rule(
    name: 'state-does-not-import-ui',
    description:
        'lib/state/ reaches no lib/ui/ (invariant 3); the one known exception '
        'is layout_controller reading the column constraints',
    appliesTo: ['lib/state/'],
    exempt: ['lib/state/layout_controller.dart'],
    pattern: RegExp(r"^import '\.\./ui/"),
  ),
  Rule(
    name: 'ui-owns-no-direct-io',
    description:
        'host I/O belongs to lib/host/ and lib/state/ — a widget that '
        'spawns or reads the disk directly cannot be tested as a widget',
    appliesTo: ['lib/ui/'],
    pattern: RegExp(r"^import 'dart:io'"),
  ),
  Rule(
    name: 'riverpod-stays-in-the-assembly-root',
    description:
        'riverpod imports live in main.dart and state/app_providers.dart '
        '(ADR-0002) — everywhere else reads through a provider, not a container',
    appliesTo: ['lib/'],
    skip: ['lib/main.dart', 'lib/state/app_providers.dart'],
    pattern: RegExp(r"^import 'package:flutter_riverpod"),
  ),
  Rule(
    name: 'one-feedback-strip',
    description:
        'feedback is raised through ui/primitives/feedback.dart on shad\'s '
        'Sonner, never a Material SnackBar or ScaffoldMessenger (ADR-0020) — '
        'the strip a user meets most was the one surface outside the bridged '
        'palette, the shape tiers and the text scaler',
    appliesTo: ['lib/'],
    pattern: RegExp(r'ScaffoldMessenger\.|SnackBar\('),
  ),
  Rule(
    name: 'runtime-reaches-neither-flutter-nor-state',
    description:
        "lib/genkit/ imports neither package:flutter nor lib/state/ (ADR-0015) "
        '— a Flutter import is invisible until the one gate that needs no '
        'Flutter (`dart run spike/runtime_smoke.dart`) stops compiling',
    appliesTo: ['lib/genkit/'],
    pattern: RegExp(
      r"^import '(?:package:flutter|package:planstar/state|\.\./state)",
    ),
  ),
  Rule(
    name: 'drift-stays-in-lib-state',
    description:
        'drift imports live in lib/state/ (ADR-0060) — the database is '
        'assembled beside the stores; the vocabulary and the UI never see it',
    appliesTo: ['lib/'],
    skip: ['lib/state/'],
    pattern: RegExp(r"^import '(?:package:drift|package:sqlite3)"),
  ),
];

/// Files past this line count are reported as a warning, never a failure.
const maxFileLines = 400;

const baselinePath = 'tool/architecture_baseline.json';

void main(List<String> args) {
  final update = args.contains('--update');
  final verbose = args.contains('--verbose');

  final report = checkRepo();
  final found = report.found;

  if (update) {
    writeBaseline(found);
    stdout.writeln(
      'baseline written: ${found.length} recorded violation(s) '
      'across ${rules.length} rules',
    );
    return;
  }

  if (verbose) {
    for (final violation in found) {
      stdout.writeln('  recorded  ${violation.fingerprint}');
    }
  }
  for (final violation in report.fresh) {
    stderr.writeln('NEW VIOLATION ${violation.rule}: ${violation.path}');
    stderr.writeln('  ${violation.line}');
    stderr.writeln('  ${_describe(violation.rule)}');
  }
  if (report.long.isNotEmpty) {
    stdout.writeln(
      'warning: ${report.long.length} file(s) over $maxFileLines lines '
      '(not blocking): ${report.long.take(5).join(', ')}'
      '${report.long.length > 5 ? ', …' : ''}',
    );
  }
  if (report.stale.isNotEmpty) {
    stdout.writeln(
      'baseline can shrink: ${report.stale.length} recorded violation(s) are '
      'gone — re-run with --update to bank it',
    );
  }
  if (report.fresh.isEmpty) {
    stdout.writeln(
      'architecture OK: ${found.length} recorded, 0 new '
      '(${report.files} files, ${rules.length} rules)',
    );
    return;
  }
  exitCode = 1;
}

/// The `.dart` files under the directories the rules scan, as repo-relative
/// paths with forward slashes. Generated `*.g.dart` files are left out: they
/// are what build_runner writes, not what a person chose to import.
List<String> sourceFiles() {
  final scanned = <String>{
    for (final rule in rules)
      for (final prefix in rule.appliesTo) ..._dartFiles(prefix),
  }..removeWhere((path) => path.endsWith('.g.dart'));
  final sorted = scanned.toList()..sort();
  return sorted;
}

Iterable<String> _dartFiles(String relativeDir) {
  final dir = Directory(relativeDir);
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => _posix(file.path));
}

/// Every rule's findings over [files], sorted by fingerprint.
List<Violation> collectViolations(List<String> files) {
  final linesCache = <String, List<String>>{};
  List<String> linesOf(String path) =>
      linesCache.putIfAbsent(path, () => File(path).readAsLinesSync());

  final found = <Violation>[];
  for (final rule in rules) {
    for (final path in files) {
      if (!rule._applies(path) || rule.exempt.contains(path)) continue;
      for (final line in linesOf(path)) {
        final text = line.trim();
        if (rule.pattern.hasMatch(text)) {
          found.add(Violation(rule.name, path, text));
        }
      }
    }
  }
  found.sort((a, b) => a.fingerprint.compareTo(b.fingerprint));
  return found;
}

/// Paths over [maxFileLines], longest first, excluding tests' own fixtures.
List<String> longFiles(List<String> files) {
  final long = <String, int>{};
  for (final path in files) {
    if (path.startsWith('spike/')) continue;
    final count = linesCountOf(path);
    if (count > maxFileLines) long[path] = count;
  }
  final sorted = long.keys.toList()
    ..sort((a, b) => long[b]!.compareTo(long[a]!));
  return sorted;
}

int linesCountOf(String path) => File(path).readAsLinesSync().length;

/// The findings absent from [baseline] — the only thing that fails the gate.
List<Violation> newViolations(
  Iterable<Violation> found,
  Set<String> baseline,
) => [
  for (final violation in found)
    if (!baseline.contains(violation.fingerprint)) violation,
];

/// Recorded fingerprints that no longer exist: debt repaid, the baseline can
/// shrink. Reported, never fatal — a ratchet must not punish an improvement.
List<String> staleFingerprints(
  Iterable<Violation> found,
  Set<String> baseline,
) {
  final present = {for (final violation in found) violation.fingerprint};
  return [
    for (final fingerprint in baseline)
      if (!present.contains(fingerprint)) fingerprint,
  ]..sort();
}

/// The repo as it stands, read from the current directory. The test entry point
/// is the same computation the command prints, so CI checks the architecture by
/// running `flutter test`.
ArchReport checkRepo() {
  final files = sourceFiles();
  final found = collectViolations(files);
  final recorded = readBaseline();
  return ArchReport(
    files: files.length,
    found: found,
    fresh: newViolations(found, recorded),
    stale: staleFingerprints(found, recorded),
    long: longFiles(files),
  );
}

/// What one architecture scan says about the repo.
class ArchReport {
  const ArchReport({
    required this.files,
    required this.found,
    required this.fresh,
    required this.stale,
    required this.long,
  });

  final int files;
  final List<Violation> found;
  final List<Violation> fresh;
  final List<String> stale;
  final List<String> long;
}

String _describe(String rule) =>
    rules.firstWhere((candidate) => candidate.name == rule).description;

Set<String> readBaseline() {
  final file = File(baselinePath);
  if (!file.existsSync()) return {};
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return (json['violations'] as List).cast<String>().toSet();
}

void writeBaseline(List<Violation> violations) {
  final json = {
    '_comment':
        'Today\'s accepted architecture violations. check_architecture fails '
        'only on a fingerprint absent here, so a rule cannot be re-broken. '
        'Shrink it with: dart tool/check_architecture.dart --update',
    'violations': [for (final v in violations) v.fingerprint],
  };
  final encoder = const JsonEncoder.withIndent('  ');
  // Same tmp + rename discipline the app's own stores use: an interrupted run
  // must not leave a half-written baseline behind.
  final tmp = File('$baselinePath.tmp');
  tmp.writeAsStringSync('${encoder.convert(json)}\n');
  tmp.renameSync(baselinePath);
}

String _posix(String path) => path.replaceAll(r'\', '/');
