// One menu skin. The sentence this file guards: a Material menu and the app's
// own popover must not be two different surfaces.
//
// Before ADR-0028 the theme had no `popupMenuTheme` at all, so every `showMenu`
// and `PopupMenuButton` (13 entry points, 7 files) rendered Material's own
// chrome: a computed `colorScheme.surfaceContainer` — which measured exactly
// `bgLayer1` in both themes, i.e. the same colour as the page the menu floats
// over — and a 4px radius, while `DswShape.shell`'s own doc names "dropdown
// menu" as one of the surfaces it is for.
//
// The disabled label is asserted separately because `popup_menu.dart:417` gives
// the theme entry *full* responsibility for it: once `labelTextStyle` is set,
// Material's own dimming is never consulted.

import 'package:agent_harness/theme/dsw_alias.dart';
import 'package:agent_harness/theme/dsw_shape.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/theme/dsw_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    group('menu chrome in $brightness', () {
      final theme = dswThemeData(brightness);
      final color = brightness == Brightness.dark
          ? DswAlias.dark
          : DswAlias.light;
      final menu = theme.popupMenuTheme;

      test('the menu takes the popover surface, not a computed one', () {
        expect(menu.color, color.bgLayer2);
      });

      test('its edge is the shell radius plus the hairline the theme can paint', () {
        final shape = menu.shape;
        expect(shape, isA<RoundedRectangleBorder>());
        final border = shape! as RoundedRectangleBorder;
        expect(border.borderRadius, BorderRadius.circular(DswShape.shell));
        // Material's own default is a 4px radius and no border side at all; the
        // popover (`settings_quick_menu.dart:141-147`) is shell + borderL2, and
        // `_ShapeBorderPainter.paint` (material.dart:973) paints a shape's own
        // side, so the hairline is expressible here rather than lost.
        expect(border.side.color, color.borderL2);
        expect(border.side.width, lessThanOrEqualTo(1.0));
      });

      test('its rows read like the popover rows, and disabled still dims', () {
        final style = menu.labelTextStyle;
        expect(style, isNotNull);
        // 14 regular, the size ZCode's dropdown rows use (`--ui-font-size: 14px`
        // at styles.css:58, `text-ui-base` at dropdown-menu.tsx:82) and the size
        // the app's own popover hand-off row uses
        // (`settings_quick_menu.dart:361`). Material's M3 default is
        // `labelLarge`, which this theme maps to `sStrong14` — the same size but
        // weight 500, so menu labels came out heavier than every real row.
        expect(
          style!.resolve(const <WidgetState>{}),
          DswType.s14.copyWith(color: color.labelPrimary),
        );
        expect(
          style.resolve(const <WidgetState>{WidgetState.disabled}),
          DswType.s14.copyWith(color: color.labelTertiary),
        );
      });

      test('the hover wash is the one every other hover affordance uses', () {
        // Menu rows are `InkWell`s, and `ink_well.dart:1040` falls back to
        // `ThemeData.hoverColor` — Material's own value is black/white at ~4%,
        // not `interactiveBgHover`.
        expect(theme.hoverColor, color.interactiveBgHover);
      });
    });
  }

  testWidgets('an opened menu actually renders that skin', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.dark),
        home: Scaffold(
          body: PopupMenuButton<String>(
            child: const Text('open'),
            itemBuilder: (context) => const [
              PopupMenuItem<String>(value: 'a', child: Text('Alpha')),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The floating Material above the row — identified by carrying elevation,
    // since the Scaffold's Material sits at zero. A site that re-forked the skin
    // for this menu would land here with Material's own values and fail.
    final material = tester
        .widgetList<Material>(
          find.ancestor(
            of: find.text('Alpha'),
            matching: find.byType(Material),
          ),
        )
        .firstWhere((m) => m.elevation > 0);
    final shape = material.shape! as RoundedRectangleBorder;
    expect(material.color, DswAlias.dark.bgLayer2);
    expect(shape.borderRadius, BorderRadius.circular(DswShape.shell));
    expect(shape.side.color, DswAlias.dark.borderL2);
    expect(find.text('Alpha'), findsOneWidget);
  });
}
