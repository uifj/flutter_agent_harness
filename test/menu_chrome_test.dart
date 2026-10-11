// One menu skin. The sentence this file guards has not changed since ADR-0028 —
// a floating list of actions is one surface in this app, whatever draws it — but
// the seam moved: ADR-0036 took the last Material menu out of `lib/ui`, so the
// skin now lives in `dsw_shad_bridge.dart` and every dropdown, popover and
// right-click menu reads it through shad's `popoverTheme`.
//
// Before ADR-0028 the theme had no menu entry at all and each of the 13 Material
// entry points rendered Material's own chrome: a computed `surfaceContainer`
// that measured exactly `bgLayer1` — the same colour as the page the menu floats
// over — a 4px radius while `DswShape.shell`'s own doc names "dropdown menu" as
// one of the surfaces it is for, and `labelLarge` (weight 500) while every real
// row is regular.
//
// Two of those measurements are now asserted as one sentence said once: the
// selected row's style is checked against the unselected one because shad
// resolves them through two separate fields, and a bridge that only fills one
// hands the chosen row `textTheme.muted` — a typography this bridge deliberately
// does not map, so it would fork a second ramp the moment a row became live.
//
// That the *count* of Material menus is zero is `test/shad_menu_adoption_test.dart`'s
// job; this file is about what the surfaces that remain are painted with.

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/theme/dsw_alias.dart';
import 'package:planstar/theme/dsw_shape.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/theme/dsw_typography.dart';
import 'package:planstar/ui/primitives/menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  for (final brightness in Brightness.values) {
    group('the overlay skin in $brightness', () {
      final color = brightness == Brightness.dark
          ? DswAlias.dark
          : DswAlias.light;
      final theme = dswShadTheme(brightness);
      final popover = theme.popoverTheme.decoration!;
      final option = theme.optionTheme;

      test('a menu fills with the raised layer, not the page behind it', () {
        // `menu` and `bgLayer1` are the same colour in the light palette, which
        // is why the fill is `bgLayer2` and why the hairline below is load-bearing.
        expect(theme.colorScheme.popover, color.bgLayer2);
      });

      test('its edge is the shell radius plus a hairline', () {
        final border = popover.border!;
        expect(
          border.radius,
          BorderRadius.circular(DswShape.shell),
          reason: '$brightness: an overlay is a `shell` surface, not a control',
        );
        // `ShadBorder.all` fans one side out to four, so any side answers.
        expect(border.top!.color, color.borderL2);
        expect(border.top!.width, lessThanOrEqualTo(1.0));
      });

      test('its rows read like the app, and picking one changes no type', () {
        expect(
          option.textStyle,
          DswType.s14.copyWith(color: color.labelPrimary),
        );
        // The fork this guards is a field shad resolves separately, not a state.
        expect(
          option.selectedTextStyle,
          option.textStyle,
          reason: 'a live row must not be a different typography',
        );
        expect(option.hoveredBackgroundColor, color.interactiveBgHover);
        // A row highlight nested inside a `shell` surface is `inner` decoration.
        expect(option.radius, BorderRadius.circular(DswShape.inner));
      });

      test('the right-click shape answers for the same rows', () {
        final menu = theme.contextMenuTheme;
        // Field by field, not whole-style: shad merges its own defaults into
        // this one, so an `==` would compare `TextDecoration.none` against a
        // null decoration and fail on the bookkeeping rather than the type.
        final style = menu.textStyle!;
        expect(style.color, color.labelPrimary);
        expect(style.fontSize, 14);
        expect(style.fontWeight, FontWeight.w400);
        expect(menu.selectedBackgroundColor, color.interactiveBgHover);
        // One seat for both shapes, so an action menu and a right-click menu are
        // the same height (ADR-0017 S3: it rides the text step).
        expect(menu.height, DswShape.rowMenu);
      });

      test('a disabled row dims to the one number', () {
        // `DswMenuRow` has to dim itself — shad keeps its `ShadDisabled` private —
        // and it reads this field rather than a literal, so the value is said once.
        expect(theme.disabledOpacity, 0.4);
      });
    });
  }

  testWidgets('an opened menu actually renders that skin', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),

        theme: dswThemeData(Brightness.dark),
        home: Scaffold(
          body: DswMenu(
            label: 'open',
            items: (context) => [
              DswMenuEntry(label: 'Alpha', onTap: () {}),
              const DswMenuEntry.divider(),
              DswMenuEntry(label: 'Beta'),
            ],
            trigger: (context) => const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Alpha'), findsOneWidget);
    // The surface the decorator paints around the rows. A call site that
    // re-forked the skin would land here with shad's own values and fail.
    final decorator = tester.widget<ShadDecorator>(
      find.ancestor(
        of: find.text('Alpha'),
        matching: find.byType(ShadDecorator),
      ),
    );
    final border = decorator.decoration!.border!;
    expect(border.radius, BorderRadius.circular(DswShape.shell));
    expect(border.top!.color, DswAlias.dark.borderL2);
  });

  testWidgets('a destructive row is red text, not a red block', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),

        theme: dswThemeData(Brightness.dark),
        home: Scaffold(
          body: DswMenu(
            label: 'open',
            items: (context) => [
              DswMenuEntry(
                label: 'Discard changes',
                destructive: true,
                onTap: () {},
              ),
              DswMenuEntry(label: 'Copy path', onTap: () {}),
            ],
            trigger: (context) => const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    Color painted(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;
    expect(painted('Discard changes'), DswAlias.dark.stateErrorPrimary);
    expect(painted('Copy path'), DswAlias.dark.labelPrimary);
  });
}
