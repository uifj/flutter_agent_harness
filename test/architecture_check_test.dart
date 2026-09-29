// The sentence this file holds: the invariants that carry no accepted debt hold
// today, and the ratchet only ever fails on something new.
//
// `tool/check_architecture.dart` is the executable form of `AGENTS.md` §3. The
// invariants themselves are asserted against the real tree (that is what makes
// CI check them — `pr-check.yml` already runs `flutter test`), while the
// baseline arithmetic is asserted against hand-made findings: a fingerprint the
// baseline does not carry must fail, and one it carries but the tree no longer
// has must not.

import 'package:flutter_test/flutter_test.dart';

// A relative import on purpose: `package:` URIs resolve only under `lib/`, and
// the checker is a `tool/` script — the same reason `tool/contrast_check.dart`
// is run by hand rather than imported.
import '../tool/check_architecture.dart';

Violation _finding(String rule, String path, String line) =>
    Violation(rule, path, line);

void main() {
  group('the ratchet', () {
    test('a fingerprint the baseline does not carry is new', () {
      final found = [
        _finding(
          'model-stays-framework-free',
          'lib/model/x.dart',
          "import 'a';",
        ),
      ];
      expect(newViolations(found, const <String>{}), hasLength(1));
      expect(newViolations(found, {found.single.fingerprint}), isEmpty);
    });

    test('moving the line does not look like fixing it', () {
      // The fingerprint is rule + file + text, never the line number.
      final violation = _finding(
        'state-does-not-import-ui',
        'lib/state/y.dart',
        "import '../ui/z.dart';",
      );
      expect(newViolations([violation], {violation.fingerprint}), isEmpty);
    });

    test('a violation that disappears is stale, never fatal', () {
      final stale = staleFingerprints(const [], {'ui-owns-no-direct-io|a|b'});
      expect(stale, ['ui-owns-no-direct-io|a|b']);
    });
  });

  group('the repo as it stands', () {
    final report = checkRepo();

    test('the invariants with no accepted debt have no findings to launder', () {
      const invariants = {
        'genkit-stays-in-lib-genkit',
        'model-stays-framework-free',
        'state-does-not-import-ui',
        // ADR-0015: a Flutter import in the runtime is invisible until the one
        // gate that needs no Flutter stops compiling, so it stays at zero.
        'runtime-reaches-neither-flutter-nor-state',
      };
      final tripped = report.found
          .map((violation) => violation.rule)
          .toSet()
          .intersection(invariants);
      expect(tripped, isEmpty, reason: '$tripped is recorded in the baseline');
    });

    test('nothing new since the baseline was recorded', () {
      expect(
        report.fresh.map((violation) => violation.fingerprint).toList(),
        isEmpty,
      );
    });

    test('the scan sees the tree, not an empty directory', () {
      // Guards the other two from passing vacuously.
      expect(report.files, greaterThan(100));
    });
  });
}
