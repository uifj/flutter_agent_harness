// The one sentence this file holds: the footer quick-menu writes the shared
// document live AND is operable from the keyboard — tapping or focusing+Enter on
// a chip calls onChanged with exactly that field changed and accumulates, and
// Escape closes the menu.
//
// This is the ADR-0006 S3 guard plus the 2026-09-16 audit F1/F3 guards: the
// chips and the open-settings row are DswHoverTaps (focusable, Enter-activated),
// and the menu binds Escape to dismiss, so a keyboard user can neither get
// trapped nor be locked out. The trigger is pinned to the bottom-left so the
// menu, which opens upward, is on-screen.

import 'package:agent_harness/model/app_settings.dart' as settings;
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/settings/widgets/settings_quick_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Pumps a host with the menu opened after the first frame; returns the
  /// menu's overlay entry (the caller owns it — the audit-F2 contract) and
  /// funnels [onChanged] into [saved].
  Future<OverlayEntry> pumpMenu(
    WidgetTester tester, {
    void Function(settings.AppSettings)? onChanged,
  }) async {
    final link = LayerLink();
    OverlayEntry? entry;
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
                    if (!context.mounted || entry != null) return;
                    entry = showSettingsQuickMenu(
                      context: context,
                      link: link,
                      initial: const settings.AppSettings(),
                      onChanged: onChanged ?? (_) {},
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
    return entry!;
  }

  testWidgets('a chip writes the shared document live', (tester) async {
    settings.AppSettings? saved;
    await pumpMenu(tester, onChanged: (next) => saved = next);

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

  testWidgets('a chip activates from the keyboard (audit F1)', (tester) async {
    settings.AppSettings? saved;
    await pumpMenu(tester, onChanged: (next) => saved = next);

    // The menu's FocusScope autofocuses; the first focusable chip is the first
    // option of the first group. Tab reaches it, Enter activates it — no
    // pointer involved.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    // The first group is Theme and its first option is 'Follow system'; the
    // document changed through the keyboard path.
    expect(saved, isNotNull);
    expect(saved?.theme.name, 'system');
  });

  testWidgets('Escape dismisses the menu (audit F3)', (tester) async {
    final entry = await pumpMenu(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(entry.mounted, isFalse);
    expect(find.text('Open settings'), findsNothing);
  });
}
