// The sentences this file holds: `enStrings` and `zhStrings` declare exactly the
// same keys, and the one tooltip whose placeholder IS its discoverability keeps
// it in both languages.
//
// `locales.dart`'s header claims "en is checked against it at test time", and
// `translate()` resolves zh -> en -> the key itself, so a key added on one
// side only is silent: the UI shows English copy inside a Chinese frame
// instead of failing. Until this file existed no test referenced either
// dictionary, so the alignment was held by eye alone (ADR-0008).
//
// The key *sets* are the invariant; the key *count* deliberately is not — a
// hardcoded total rots the moment anyone adds a string.

import 'dart:io';

import 'package:planstar/l10n/locales.dart';
import 'package:planstar/state/hotkey_service.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> _sortedDiff(Set<String> a, Set<String> b) {
  final diff = a.difference(b).toList()..sort();
  return diff;
}

void main() {
  test('en and zh carry the same keys', () {
    final enKeys = enStrings.keys.toSet();
    final zhKeys = zhStrings.keys.toSet();

    expect(
      _sortedDiff(enKeys, zhKeys),
      isEmpty,
      reason: 'keys in enStrings with no zhStrings entry fall back to English',
    );
    expect(
      _sortedDiff(zhKeys, enKeys),
      isEmpty,
      reason: 'keys in zhStrings absent from enStrings render as the raw key',
    );
  });

  test('the sidebar tooltips say which key opens them', () {
    // The accelerator is the only way anyone learns the shortcut exists —
    // dropping it in one language is a silent regression. The general
    // placeholder rule is the test below; these two keep value-level
    // assertions on top.
    final accel = HotkeyService.sidebarAccelerator;
    expect(accel, endsWith('B'), reason: 'the toggle is registered on key B');
    expect(
      translate(AppLocaleId.en, 'collapseSidebar', {'accel': accel}),
      'Collapse sidebar ($accel)',
    );
    expect(
      translate(AppLocaleId.en, 'openSidebar', {'accel': accel}),
      'Open sidebar ($accel)',
    );
    for (final key in ['openSidebar', 'collapseSidebar']) {
      expect(
        translate(AppLocaleId.zh, key, {'accel': accel}),
        contains(accel),
        reason: '$key lost the accelerator in zh',
      );
    }
  });

  test('every key the code uses exists in the dictionaries', () {
    // `.tr('key')` with an unknown key falls through translate()'s chain to
    // the key itself — the user reads "planLinkPrompt" as a dialog title,
    // in both languages (that shipped once; ADR-0078). The scan is textual
    // on purpose: it covers exactly the call shape the codebase uses and
    // needs no imports from the callers.
    final re = RegExp(r"\.tr\(\s*'([a-zA-Z0-9_]+)'");
    final missing = <String, List<String>>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final match in re.allMatches(lines[i])) {
          final key = match.group(1)!;
          if (!enStrings.containsKey(key)) {
            missing.putIfAbsent(key, () => []).add('${entity.path}:${i + 1}');
          }
        }
      }
    }
    expect(
      missing,
      isEmpty,
      reason: 'a used key missing from the dictionaries renders as the raw key',
    );
  });

  test('placeholders agree across the two dictionaries', () {
    // `translate` replaces `{token}` by name: a placeholder dropped on the
    // zh side leaves the literal `{name}` in the copy; an extra one on the
    // zh side is dead. The general rule (ADR-0078) replaces ADR-0008's
    // two-key special case above.
    final re = RegExp(r'\{(\w+)\}');
    final offenders = <String, List<String>>{};
    for (final key in enStrings.keys) {
      final enPlaceholders = re
          .allMatches(enStrings[key]!)
          .map((m) => m.group(1)!)
          .toSet();
      final zhPlaceholders = re
          .allMatches(zhStrings[key] ?? '')
          .map((m) => m.group(1)!)
          .toSet();
      final diff = {
        ...enPlaceholders.difference(zhPlaceholders),
        ...zhPlaceholders.difference(enPlaceholders),
      };
      if (diff.isNotEmpty) {
        offenders[key] = diff.toList()..sort();
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'placeholder sets must match between en and zh',
    );
  });
}
