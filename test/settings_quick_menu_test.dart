// The one sentence this file holds: the footer quick-menu writes the shared
// document live — tapping a chip calls onChanged with that field changed and
// accumulates, and the selection moves without a provider round-trip.
//
// This is the ADR-0006 S3 guard. The menu is the fast-path alternative to the
// full settings view, so what matters is that a chip tap produces exactly the
// right `AppSettings` delta (theme, then width) through `onChanged`. The trigger
// is pinned to the bottom-left so the menu, which opens upward, is on-screen.

import 'package:agent_harness/model/app_settings.dart' as settings;
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/settings/widgets/settings_quick_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a chip writes the shared document live', (tester) async {
    settings.AppSettings? saved;
    final link = LayerLink();
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: CompositedTransformTarget(
              link: link,
              child: Builder(
                builder: (context) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!context.mounted) return;
                    showSettingsQuickMenu(
                      context: context,
                      link: link,
                      initial: const settings.AppSettings(),
                      onChanged: (next) => saved = next,
                      onOpenSettings: () {},
                    );
                  });
                  return const SizedBox(width: 120, height: 40);
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(); // run the post-frame callback (insert the overlay)
    await tester.pump(); // build the menu

    // English copy — no AppLocaleScope mounted (the deterministic fallback).
    expect(find.text('Dark'), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pump();
    expect(saved?.theme.name, 'dark');

    // A second chip accumulates on the live mirror, not a fresh document.
    await tester.tap(find.text('Wide'));
    await tester.pump();
    expect(saved?.conversationWidth.name, 'wide');
    expect(saved?.theme.name, 'dark');
  });
}
