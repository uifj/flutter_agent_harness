// The controls the four screenshots disagree about, once each.
//
// ADR-0036 decision 1 again, applied to the second batch: `shadcn_ui` ships an
// Input, a Switch and a Badge, and the surfaces the user compares side by side
// — the composer's draft field next to the settings folder field next to the
// side-chat and browser address fields; the settings toggles next to every
// other on/off — were drawing those three states by hand. A hand-drawn control
// re-answers focus, disabled, keyboard and semantics per file, which is the
// same defect ADR-0021 closed for buttons and ADR-0036 closed for menus.
//
// Three claims, all counts, all zero-tolerance: a bare Material `TextField`
// (the widget, not `ShadInput`), a private switch class, and a pill that is not
// a badge. Zero rather than an allow-list because unlike a raw gesture detector
// — which can have a reason (see `tap_affordance_test.dart`) — a Material field
// in this app has none: it is the same input with a second, unfocusable answer
// to "where is the keyboard".
//
// Structural, not behavioural: what each converted control must still *do*
// (type into it, toggle it with Enter, read out its name) is asserted at the
// surface that owns it — `composer_test`, `settings_test`, `file_tree_tab`'s
// rename case — so a failure names the feature that broke rather than a count.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> get _uiFiles => Directory('lib/ui')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'))
    .toList();

/// Occurrences of [pattern] in `lib/ui`, skipping whole-line comments, as
/// `path -> count`.
Map<String, int> _scan(RegExp pattern) {
  final found = <String, int>{};
  for (final file in _uiFiles) {
    var count = 0;
    for (final raw in file.readAsLinesSync()) {
      final text = raw.trim();
      if (text.startsWith('//')) continue;
      count += pattern.allMatches(text).length;
    }
    if (count > 0) found[file.path.replaceAll(r'\', '/')] = count;
  }
  return found;
}

Map<String, int> materialFields() => _scan(RegExp(r'[^A-Za-z]TextField\('));

Map<String, int> privateSwitches() => _scan(RegExp(r'class _\w*Switch\b'));

Map<String, int> shadControls() =>
    _scan(RegExp('ShadInput|ShadSwitch|ShadBadge'));

void main() {
  test('no hand-drawn Material field is left in lib/ui', () {
    final found = materialFields();
    expect(
      found,
      isEmpty,
      reason:
          'ADR-0036: a field is a ShadInput, skinned once by the bridge\'s '
          'inputTheme. Offenders: '
          '${found.entries.map((e) => '${e.key} (${e.value})').join(', ')}',
    );
  });

  test('no file draws its own switch', () {
    final found = privateSwitches();
    expect(
      found,
      isEmpty,
      reason:
          'ADR-0036: an on/off is a ShadSwitch, which is already focusable, '
          'already dimmed by `disabledOpacity` and already announced. '
          'Offenders: '
          '${found.entries.map((e) => '${e.key} (${e.value})').join(', ')}',
    );
  });

  test('a label pill is a badge', () {
    final pill = File('lib/ui/primitives/pill.dart').readAsStringSync();
    expect(
      pill.contains('ShadBadge'),
      isTrue,
      reason:
          'ADR-0036 row 33: the static pill renders a ShadBadge; its geometry '
          'stays the primitive\'s business, its surface stops being a second '
          'answer to "a small rounded label".',
    );
  });

  test('the scan is looking at a tree that has these controls in it', () {
    // The positive control: without it, a wrong working directory or a typo in
    // a pattern would satisfy the three claims above by finding nothing.
    expect(_uiFiles.length, greaterThan(20));
    expect(shadControls(), isNotEmpty);
  });
}
