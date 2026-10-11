// Generates lib/l10n/tr_key.dart — the runtime string-key -> typed-getter bridge
// (ADR-0082 §4) — from the template ARB. Pure Dart (reads JSON, writes Dart):
//
//   dart run tool/gen_tr_key.dart && dart format lib/l10n/tr_key.dart
//
// Re-run whenever lib/l10n/app_en.arb changes. The bridge covers EVERY ARB key so
// it is total (any valid key resolves; an unknown key falls through to the same
// visible `return key` the retired translate() used) and needs zero hand-maintenance.
import 'dart:convert';
import 'dart:io';

void main() {
  const arbPath = 'lib/l10n/app_en.arb';
  const outFile = 'lib/l10n/tr_key.dart';
  final map =
      jsonDecode(File(arbPath).readAsStringSync()) as Map<String, Object?>;

  final keys = map.keys.where((k) => !k.startsWith('@')).toList();
  final cases = <String>[];
  var methodCount = 0;
  for (final key in keys) {
    final meta = map['@$key'];
    final ph = (meta is Map && meta['placeholders'] is Map)
        ? (meta['placeholders'] as Map).keys.cast<String>().toList()
        : const <String>[];
    if (ph.isEmpty) {
      cases.add("    case '$key':\n      return l10n.$key;");
    } else {
      methodCount++;
      final args = ph.map((p) => "s('$p')").join(', ');
      cases.add("    case '$key':\n      return l10n.$key($args);");
    }
  }

  final out = <String>[
    '// GENERATED from lib/l10n/app_en.arb by tool/gen_tr_key.dart — do not edit.',
    '//',
    '// The runtime string-key -> typed-getter bridge for the dynamic keys that',
    '// lib/model hands back as strings (RelativeTime.key, ShortcutDef.labelKey,',
    '// plan_all_content group codes). Invariant 2 keeps lib/model off the locale',
    '// table, so those keys arrive as strings and resolve here (ADR-0082 §4).',
    "import 'app_localizations.dart';",
    '',
    '/// Resolves [key] against [l10n], interpolating `{token}`s from [params].',
    '///',
    '/// An unknown key renders as the key itself and a missing param as its literal',
    '/// `{token}` — the same visible fallback the retired `translate()` used, so a',
    '/// gap shows rather than blanks.',
    'String trKey(',
    '  AppLocalizations l10n,',
    '  String key, [',
    '  Map<String, Object>? params,',
    ']) {',
    r"  String s(String name) => params?[name]?.toString() ?? '{$name}';",
    '  switch (key) {',
    ...cases,
    '    default:',
    '      return key;',
    '  }',
    '}',
    '',
  ];

  File(outFile).writeAsStringSync(out.join('\n'));
  stdout.writeln(
    'wrote $outFile: ${keys.length} cases ($methodCount with params)',
  );
}
