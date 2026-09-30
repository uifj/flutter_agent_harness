// One radius ramp, including the shad surfaces. The sentence this file guards:
// a dialog is 16 and a field is 8, whatever library draws them.
//
// `DswShape`'s own header (`dsw_shape.dart:17-22`) names "a dialog" as a job of
// the `float` tier and cites ZCode's `rounded-2xl` = 16px as the reason the tier
// exists — while both dialogs in this app are shad's, and shad's single radius
// knob (`ShadThemeData.radius`, defaulting to 6 in the library's `data.dart:114`)
// was deliberately left unset by the bridge. So the same concept carried two
// numbers: 16 on the ramp, 6 on the screen.
//
// shad has ONE knob where the ramp has tiers, which is why the split below is
// not symmetric: the knob answers for the surfaces that are actually the
// majority (fields, toasts, cards -> `control`), and a surface that means a
// different tier has to say so itself. The scan is the guard for "says so".

import 'dart:io';

import 'package:agent_harness/theme/dsw_shape.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/ui/primitives/confirm_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  group('the shad radius knob sits on the ramp', () {
    test('it is the control tier, not the library default', () {
      for (final brightness in Brightness.values) {
        expect(
          dswShadTheme(brightness).radius,
          BorderRadius.circular(DswShape.control),
          reason: '$brightness: 6 is not a tier in this design system',
        );
      }
    });

    test('every dialog names its own tier instead of inheriting the knob', () {
      final dialog = RegExp(r'\bShadDialog(?:\.\w+)?\(');
      final offenders = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (!dialog.hasMatch(line) || line.trimLeft().startsWith('//')) {
            continue;
          }
          final statement = lines.skip(i).take(20).join('\n');
          if (!statement.contains('radius:')) {
            offenders.add('${file.path}: ${i + 1}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'a ShadDialog left without `radius:` '
            'renders the control tier, but a dialog is the `float` tier',
      );
    });
  });

  testWidgets('the shared confirm dialog actually renders 16', (tester) async {
    await tester.pumpWidget(
      ShadTheme(
        data: dswShadTheme(Brightness.light),
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showConfirmDialog(
                    context,
                    title: 'Discard',
                    description: 'This throws work away.',
                    confirmLabel: 'Discard',
                  ),
                  child: const Text('ask'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ask'));
    await tester.pumpAndSettle();

    final dialog = tester.widget<ShadDialog>(find.byType(ShadDialog));
    expect(dialog.radius, BorderRadius.circular(DswShape.float));
  });
}
