// The sentences this file holds: no user-visible Chinese copy may bypass
// localization — `Text('确定')` renders identically in every locale and the
// ARB's compile-time key safety can never see it, because it has no key
// (ADR-0080).
//
// Zero tolerance, by measurement: the whole of lib/ scanned clean on
// 2026-10-07, so there is no baseline file to negotiate — any hit is a
// regression. The known blind spots are self-declared, not patched over:
// the pattern only sees a UI keyword followed by a string literal ON THE SAME
// LINE. `Text(` split from its literal, custom wrappers (`_header('中文')`),
// CJK inside an interpolation, and trKey() with a dynamic key all pass unseen.
// A new shape needs the pattern widened first — and if widening trips over
// existing violations, those get an ADR before the guard goes back on.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no hardcoded user-visible Chinese in lib/', () {
    final cjk = RegExp(r'[\u4e00-\u9fff]');
    final patterns = <String, RegExp>{
      'Text(': RegExp("Text\\(\\s*(['\"])(.*?)\\1"),
      'label:': RegExp("label:\\s*(['\"])(.*?)\\1"),
      'tooltip:': RegExp("tooltip:\\s*(['\"])(.*?)\\1"),
      'hint:': RegExp("hint:\\s*(['\"])(.*?)\\1"),
      'title:': RegExp("title:\\s*(['\"])(.*?)\\1"),
      'description:': RegExp("description:\\s*(['\"])(.*?)\\1"),
      'message:': RegExp("message:\\s*(['\"])(.*?)\\1"),
    };

    final hits = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//') || trimmed.startsWith('*')) continue;
        for (final entry in patterns.entries) {
          for (final match in entry.value.allMatches(line)) {
            if (cjk.hasMatch(match.group(2)!)) {
              hits.add(
                '${entity.path}:${i + 1} ${entry.key}'
                '${match.group(2)!.trim()}',
              );
            }
          }
        }
      }
    }

    expect(
      hits,
      isEmpty,
      reason:
          'user-visible copy must go through AppLocalizations (the ARB); '
          'these literals render the same in every locale:\n'
          '${hits.join('\n')}',
    );
  });
}
