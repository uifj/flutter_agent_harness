// A tooltip's wait must be one number, in the theme, not thirty.
//
// `lib/ui` held 30 `Tooltip(` sites: 19 set their own `waitDuration` (fifteen
// at 500ms, four at 600ms) and eleven set none. Flutter resolves that as
// `widget.waitDuration ?? tooltipTheme.waitDuration ?? _defaultWaitDuration`
// (`material/tooltip.dart:542`) and its default is `Duration.zero`
// (`:394`) — and this repo's `tooltipTheme` carried only colours, so the
// eleven bare sites popped the instant the pointer crossed them. Those eleven
// are exactly the surfaces a mouse sweeps sideways: the tab strip, file-tree
// rows, git and diff rows, the editor's icon row. Same shape of control, two
// different speeds (ADR-0023).
//
// The delay now lives once, as `DswMotion.tooltipDelay`, and rides the theme.
// Three checks keep it there: nobody re-adds a per-site override, the theme
// carries the token for both brightnesses, and the token is not zeroed —
// zeroing it would pass the first two while restoring the exact complaint.
//
// Why there is no "hover and measure the bubble" half: it cannot be written in
// this harness, and a test that looks behavioural here would be vacuous. A
// probe run with the theme value deliberately removed (so Material was back to
// `Duration.zero`) counted the bubble's `Text` after every step —
// `after startGesture: 0`, `after 1 frame: 0`, `after 400ms: 0`,
// `after settle: 1`. A synthetic pointer does not drive `Tooltip`'s hover
// timer, so "not visible yet" could never fail. The arithmetic is the SDK code
// cited above; the felt effect is a real-mouse walkthrough.

import 'dart:io';

import 'package:planstar/theme/dsw_motion.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('one tooltip delay', () {
    test('no lib/ui site sets its own waitDuration', () {
      final offenders = <String>[];
      for (final file in Directory('lib/ui').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('waitDuration')) {
            offenders.add('${file.path}:${i + 1}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the hover delay has one value (DswMotion.tooltipDelay, applied '
            'in dsw_theme.dart). A per-site waitDuration is a second truth '
            '— see ADR-0023. If a surface genuinely needs a different wait, '
            'name it as a constant in that file and record why in an ADR.',
      );
    });

    test('both brightnesses carry the token, not a literal', () {
      for (final brightness in Brightness.values) {
        expect(
          dswThemeData(brightness).tooltipTheme.waitDuration,
          DswMotion.tooltipDelay,
          reason: '$brightness lost the theme-level delay',
        );
      }
    });

    test('the delay is a delay', () {
      expect(
        DswMotion.tooltipDelay,
        greaterThan(Duration.zero),
        reason:
            'zero is what Material falls back to, and a sweep across the tab '
            'strip flashing one bubble per row is the defect ADR-0023 fixed',
      );
    });
  });
}
