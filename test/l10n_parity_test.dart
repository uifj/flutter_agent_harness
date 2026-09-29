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

import 'package:agent_harness/l10n/locales.dart';
import 'package:agent_harness/state/hotkey_service.dart';
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
    // Deliberately narrow: `{name}` parity across the two dictionaries is still
    // unchecked as a rule (ADR-0008 left it out). These two keys get an explicit
    // assertion because the placeholder is the only way anyone learns the
    // shortcut exists — dropping it in one language is a silent regression that
    // no other test would notice.
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
}
