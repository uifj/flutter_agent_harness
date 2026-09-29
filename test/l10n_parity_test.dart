// The one sentence this file holds: `enStrings` and `zhStrings` declare
// exactly the same keys.
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
}
