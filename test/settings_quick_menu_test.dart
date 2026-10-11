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

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/model/app_settings.dart' as settings;
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/settings/widgets/settings_quick_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'amplified_text_probe.dart';

void main() {
  /// Pumps a host with the menu opened after the first frame; returns the
  /// menu's overlay entry (the caller owns it — the audit-F2 contract) and
  /// funnels [onChanged] into [saved].
  Future<OverlayEntry> pumpMenu(
    WidgetTester tester, {
    void Function(settings.AppSettings)? onChanged,
    double step = 1.0,
  }) async {
    final link = LayerLink();
    OverlayEntry? entry;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),

        builder: (context, child) => amplifiedAppBuilder(step, child),
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
                      signedIn: false,
                      userDisplayName: null,
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
    // The help group (ADR-0045 PG) grew the menu past the default test
    // surface; a tall surface keeps every row mounted and traversable — the
    // scrolled-down composition is the amplified-text ruler's territory.
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpMenu(tester, onChanged: (next) => saved = next);

    // The menu's FocusScope autofocuses; the first focusable chip is the first
    // option of the first group. Tab reaches it, Enter activates it — no
    // pointer involved.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus;
    // ignore: avoid_print
    print('FOCUSED: $focused');
    // ignore: avoid_print
    focused?.debugLabel = 'primary';
    // ignore: avoid_print
    print(
      'CHILDREN: ${focused?.traversalDescendants.map((n) => '${n.debugLabel ?? n}').take(6).toList()}',
    );
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

  // The menu is anchored to the bottom-left and opens upward, so an amplified
  // text step stresses it in two ways at once: every chip's seat, and whether
  // the whole panel still fits above the edge it hangs from.
  group('amplified text', () {
    for (final (label, step) in const [
      ('1.8x', amplifiedTextStep),
      ('2.2x', nextTextStep),
    ]) {
      testWidgets('the cascade keeps its chips and stays on screen ($label)', (
        tester,
      ) async {
        // The menu's own height is the fact at stake, and a panel taller than
        // the window would be clipped rather than reported.
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pumpMenu(tester, step: step);
        expect(find.text('Open settings'), findsOneWidget);
        final panel = tester.getRect(find.text('Open settings'));
        expect(panel.top, greaterThanOrEqualTo(0), reason: 'the panel fits');
        expect(textDefects(tester), isEmpty, reason: 'the quick menu');
      });
    }
  });
}
