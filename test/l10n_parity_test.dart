// What this file holds after ADR-0082 retired the dictionary-parity guards.
//
// The old file asserted `enStrings`/`zhStrings` carried the same keys, that
// every `.tr('key')` in `lib/` existed, and that placeholders matched across the
// two dictionaries. `gen-l10n` makes most of that a compile error: a typo'd
// literal key is now `AppLocalizations.of(context).typoKey`, which does not
// compile, and the template ARB (`app_en.arb`) is the single declaration of each
// message's placeholder signature. Three things the compiler does NOT catch are
// what remains here:
//
//   * a key present in the template but missing from `app_zh.arb` silently falls
//     back to English inside a zh frame — `gen-l10n` reports it in
//     `untranslated.json`, so the guard asserts that file stays empty;
//   * the dynamic keys `lib/model` hands back as strings resolve through the
//     generated `trKey` bridge, and a bridge that drifts from the ARB (someone
//     edited the ARB and forgot to re-run `tool/gen_tr_key.dart`) would send a
//     key to `trKey`'s raw-key default — so the guard asserts the bridge's cases
//     are exactly the ARB's keys;
//   * the one tooltip whose placeholder IS its discoverability keeps the
//     accelerator visible in both languages — a value-level check no compiler
//     makes.
//
// The key *sets* are still the invariant; a hardcoded key *count* deliberately is
// not — it rots the moment anyone adds a string.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Locale;

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/state/hotkey_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no message is left untranslated (zh never falls back to en)', () {
    final untranslated =
        jsonDecode(File('lib/l10n/untranslated.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(
      untranslated,
      isEmpty,
      reason:
          'a key in app_en.arb missing from app_zh.arb renders English inside a '
          'zh frame; fill app_zh.arb and re-run `flutter gen-l10n`',
    );
  });

  test('the sidebar tooltips say which key opens them', () {
    // The accelerator is the only way anyone learns the shortcut exists —
    // dropping it in one language is a silent regression no compiler catches.
    final accel = HotkeyService.sidebarAccelerator;
    expect(accel, endsWith('B'), reason: 'the toggle is registered on key B');

    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.collapseSidebar(accel), 'Collapse sidebar ($accel)');
    expect(en.openSidebar(accel), 'Open sidebar ($accel)');

    final zh = lookupAppLocalizations(const Locale('zh'));
    for (final label in [zh.openSidebar(accel), zh.collapseSidebar(accel)]) {
      expect(
        label,
        contains(accel),
        reason: 'the sidebar tooltip lost the accelerator in zh',
      );
    }
  });

  test('the trKey bridge covers exactly the ARB keys', () {
    // The dynamic-key path (lib/model hands back a string key; trKey resolves
    // it) is the one place a key is not compile-checked. tr_key.dart is
    // GENERATED from app_en.arb by tool/gen_tr_key.dart; if the two drift, a
    // dynamic key falls to trKey's raw-key default and renders as itself.
    // Assert they are the same set, so editing the ARB without regenerating the
    // bridge fails here.
    final arb =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final arbKeys = arb.keys.where((k) => !k.startsWith('@')).toSet();

    final bridge = File('lib/l10n/tr_key.dart').readAsStringSync();
    final bridgeKeys = RegExp(
      r"case '([^']+)':",
    ).allMatches(bridge).map((m) => m.group(1)!).toSet();

    expect(
      bridgeKeys.difference(arbKeys),
      isEmpty,
      reason: 'tr_key.dart has cases with no ARB key — regenerate the bridge',
    );
    expect(
      arbKeys.difference(bridgeKeys),
      isEmpty,
      reason:
          'ARB keys missing from tr_key.dart — a dynamic key would render raw; '
          're-run tool/gen_tr_key.dart',
    );
  });
}
