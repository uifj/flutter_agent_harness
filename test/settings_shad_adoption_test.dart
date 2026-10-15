// The settings page wears one skin, and a focused field has one edge.
//
// The screenshot that opened this batch (`b4c94cbd`, 设置 · 模型) showed the API
// key field with *two* concentric outlines while the cursor was in it. The cause
// was not a call site: `ShadDecorator` merges the colour variant's own
// `decorationTheme()` before anything the bridge says
// (`theme/components/decorator.dart:120`), and that theme carries
// `secondaryFocusedBorder = 2px ring, offset 4`
// (`theme/themes/default_theme_variant.dart:362`). The bridge had named three
// sides of a field and left the fourth question — what happens on the outside on
// focus — to the library, so a field answered "where is the keyboard" twice.
//
// The other half of this file is the count that keeps the rest of the page from
// drifting back: the five hand-drawn icon buttons, the row capsule, the search
// box's second frame, the three cards, the Material `Divider` and the panel's own
// `<details>` boolean all moved onto shad components (ADR-0036 §1B), and a scan
// is what stops the sixth copy of any of them appearing.

import 'dart:io';

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/theme/dsw_alias.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Every outline this tree actually paints under [root], labelled by who draws
/// it: `frame` is a `BoxDecoration`'s border, `ring` is shad's outward painter —
/// which is the one a call site never restates, and the one that doubled the
/// field in the screenshot.
List<String> paintedStrokes(WidgetTester tester, Finder root) {
  final found = <String>[];
  for (final box in tester.widgetList<DecoratedBox>(
    find.descendant(of: root, matching: find.byType(DecoratedBox)),
  )) {
    final decoration = box.decoration;
    if (decoration is! BoxDecoration || decoration.border is! Border) continue;
    final border = decoration.border as Border;
    final visible = _visibleSides(border);
    // One entry per box, not per side: a frame has four sides and the question
    // this asks is how many frames are drawn.
    if (visible.isNotEmpty) {
      found.add('frame ${visible.first.width}: ${visible.first.color}');
    }
  }
  for (final paint in tester.widgetList<CustomPaint>(
    find.descendant(of: root, matching: find.byType(CustomPaint)),
  )) {
    final painter = paint.foregroundPainter;
    if (painter is! ShadOutwardBorderPainter) continue;
    final visible = _visibleSides(painter.border);
    if (visible.isNotEmpty) {
      found.add(
        'ring ${visible.first.width}: ${visible.first.color} '
        '+${painter.offset.toStringAsFixed(0)}',
      );
    }
  }
  return found;
}

List<BorderSide> _visibleSides(Border border) => [
  border.top,
  border.right,
  border.bottom,
  border.left,
].where((side) => side.width > 0).toList();

/// The settings page's own source, minus comments — the shapes that left the
/// page must not come back one file at a time. Since ADR-0085 D7 the page is
/// one library spread over part files, so the scan walks the entry file plus
/// whatever it declares as a part.
List<String> _pageLines() {
  const entry = 'lib/ui/settings/model_settings.dart';
  final dir = entry.substring(0, entry.lastIndexOf('/') + 1);
  final head = File(entry).readAsLinesSync();
  final files = [
    entry,
    for (final line in head)
      if (RegExp(r"^part '(.+)';").firstMatch(line) case final part?)
        dir + part.group(1)!,
  ];
  return [
    for (final path in files) ...File(path).readAsLinesSync(),
  ].where((line) => !line.trimLeft().startsWith('//')).toList();
}

void main() {
  group('a field has one edge', () {
    test('the bridge says the ring off, not just the resting border', () {
      for (final brightness in Brightness.values) {
        final decoration = dswShadTheme(brightness).inputTheme.decoration!;
        // Named, not merely absent: leaving one null hands the answer back to
        // the library, whose default is the 2px ring drawn four pixels out —
        // which is what doubled the frame here in the first place.
        for (final side in [
          decoration.secondaryBorder,
          decoration.secondaryFocusedBorder,
          decoration.secondaryErrorBorder,
        ]) {
          expect(
            side,
            isNotNull,
            reason: '$brightness: an unset side is the library answering',
          );
          expect(
            side!.hasBorder,
            isFalse,
            reason:
                '$brightness: a second outline on a field is the doubled '
                'frame in the screenshot',
          );
        }
      }
    });

    testWidgets('and a focused field renders exactly one stroke', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'sk-…');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),

          theme: dswThemeData(Brightness.light),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 260,
                // The bridge is mounted by `main` in the app; a bare host needs
                // the same helper the primitives use.
                child: Builder(
                  builder: (context) => dswEnsureShadTheme(
                    context,
                    ShadInput(controller: controller, autofocus: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final strokes = paintedStrokes(tester, find.byType(ShadInput));
      expect(
        strokes,
        hasLength(1),
        reason: 'one focused field painted ${strokes.length} strokes: $strokes',
      );
      expect(
        strokes.single,
        'frame 1.0: ${DswAlias.light.borderL2}',
        reason:
            'ADR-0038: focus keeps the resting hairline — the caret already '
            'says where the keyboard is. A brand stroke here would be the '
            'recoloured frame the walkthrough rejected; a second entry would '
            'be the library ring, the doubled frame in the screenshot.',
      );
    });
  });

  group('the page is built from the components', () {
    test('no hand-drawn frame or Material divider is left on the page', () {
      final offenders = <String, int>{
        // `ShadBorder.all(` shares the substring, so the Material spelling is
        // matched as "not preceded by Shad".
        'Material Border.all': _pageLines()
            .where((l) => RegExp(r'(?<!Shad)Border\.all\(').hasMatch(l))
            .length,
        'Material Divider': _pageLines()
            .where((l) => l.contains('Divider('))
            .length,
        'Material TextField': _pageLines()
            .where((l) => RegExp(r'(?<!Shad)TextField\(').hasMatch(l))
            .length,
      }..removeWhere((_, count) => count == 0);
      expect(
        offenders,
        isEmpty,
        reason:
            'ADR-0036 §1B put these on components; a second spelling of '
            'the same shape is what the audit filed. Offenders: $offenders',
      );
    });

    test('the scan is looking at a page that has the components in it', () {
      // Zero is only evidence if the walk saw the conversions.
      expect(_pageLines(), hasLength(greaterThan(500)));
      for (final id in [
        'ShadCard(',
        'DswIconButton',
        'ShadSeparator',
        'ShadAccordion<',
        'ShadInput(',
      ]) {
        expect(
          _pageLines().where((l) => l.contains(id)).length,
          greaterThan(0),
          reason: '$id should be in use on this page',
        );
      }
    });
  });
}
