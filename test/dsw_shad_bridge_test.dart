// The claim this file holds: the shad theme is coloured entirely by the dsw
// alias layer, and it never crosses the two brightnesses. Every component
// swapped onto shad in later stages inherits its palette from here, so a
// wrong pairing (dark aliases under a light flag, or destructive wired to a
// hover token) would silently tint the whole component library — far cheaper
// to catch as a unit test than to spot in a screenshot.
//
// The widget half pins the one non-obvious wiring fact: main.dart mounts
// ShadTheme through MaterialApp.builder and reads the brightness back out of
// Theme.of(context), so `themeMode: dark` must reach ShadTheme as dark.

import 'package:agent_harness/theme/dsw_alias.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  group('colour mapping', () {
    test('light theme draws every shad role from the light aliases', () {
      final c = DswAlias.light;
      final s = dswShadColorScheme(c);
      expect(s.background, c.bgBase);
      expect(s.foreground, c.labelPrimary);
      expect(s.popover, c.menu);
      expect(s.primary, c.buttonPrimaryFill);
      expect(s.primaryForeground, c.labelPrimaryForeground);
      expect(s.muted, c.sidebarFill);
      expect(s.mutedForeground, c.labelSecondary);
      expect(s.destructive, c.stateErrorPrimary);
      expect(s.border, c.borderL2);
      expect(s.input, c.inputMajor);
      expect(s.ring, c.brandPrimary);
      expect(s.selection, c.bubbleHighlight);
    });

    test('dark theme never reuses a light value for a role it owns', () {
      final dark = dswShadColorScheme(DswAlias.dark);
      final light = dswShadColorScheme(DswAlias.light);
      // The two palettes are byte-identical only on the handful of shared
      // constants; the surfaces that define a theme must differ, or one of
      // the two brightnesses was built from the wrong alias instance.
      expect(dark.background, isNot(light.background));
      expect(dark.foreground, isNot(light.foreground));
      expect(dark.popover, isNot(light.popover));
      expect(dark.primary, isNot(light.primary));
      expect(dark.muted, isNot(light.muted));
    });
  });

  testWidgets('ShadTheme follows the MaterialApp brightness in the builder', (
    tester,
  ) async {
    late ShadThemeData captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        darkTheme: dswThemeData(Brightness.dark),
        themeMode: ThemeMode.dark,
        builder: (context, child) {
          captured = dswShadTheme(Theme.of(context).brightness);
          return ShadTheme(data: captured, child: child!);
        },
        home: const Scaffold(body: Center(child: Text('x'))),
      ),
    );
    expect(captured.brightness, Brightness.dark);
    // The dark scheme, not the light one: `bgBase` splits the two palettes.
    expect(
      captured.colorScheme.background,
      ShadThemeData(
        brightness: Brightness.dark,
        colorScheme: dswShadColorScheme(DswAlias.dark),
      ).colorScheme.background,
    );
  });
}
