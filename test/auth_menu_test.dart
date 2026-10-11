// ADR-0045 PF-1: the quick menu answers the auth state — signed-out shows a
// Sign in row, signed-in shows Sign out, and both rows hand off to the
// callbacks the sidebar threaded in. The menu is an OverlayEntry inserted
// into the root overlay, so the host mounts the show call inside a real
// overlay and lets the entry live for the assertions.

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/l10n/locales.dart';
import 'package:planstar/model/app_settings.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/settings/widgets/settings_quick_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class _MenuHost extends StatefulWidget {
  const _MenuHost({
    required this.link,
    required this.signedIn,
    required this.userDisplayName,
    required this.onLogin,
    required this.onLogout,
    required this.onOpenSettings,
    required this.onEntryReady,
  });

  final LayerLink link;
  final bool signedIn;
  final String? userDisplayName;
  final VoidCallback? onLogin;
  final VoidCallback? onLogout;
  final VoidCallback onOpenSettings;
  final void Function(OverlayEntry entry) onEntryReady;

  @override
  State<_MenuHost> createState() => _MenuHostState();
}

class _MenuHostState extends State<_MenuHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final entry = showSettingsQuickMenu(
        context: context,
        link: widget.link,
        initial: const AppSettings(),
        onChanged: (_) {},
        onOpenSettings: widget.onOpenSettings,
        signedIn: widget.signedIn,
        userDisplayName: widget.userDisplayName,
        onLogin: widget.onLogin,
        onLogout: widget.onLogout,
      );
      widget.onEntryReady(entry);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  OverlayEntry? entry;
  bool entryRemoved = false;

  Future<void> pumpMenu(
    WidgetTester tester, {
    required bool signedIn,
    VoidCallback? onLogin,
    VoidCallback? onLogout,
  }) async {
    entry = null;
    entryRemoved = false;
    final link = LayerLink();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: ProviderContainer(),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),

          theme: dswThemeData(Brightness.light),
          builder: (context, child) => ShadTheme(
            data: dswShadTheme(Theme.of(context).brightness),
            child: AppLocaleScope(locale: AppLocaleId.en, child: child!),
          ),
          home: Scaffold(
            body: Center(
              child: CompositedTransformTarget(
                link: link,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: _MenuHost(
                    link: link,
                    signedIn: signedIn,
                    userDisplayName: signedIn ? 'Demo' : null,
                    onLogin: onLogin,
                    onLogout: onLogout,
                    onOpenSettings: () {},
                    onEntryReady: (e) => entry = e,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void safeRemove() {
    if (entryRemoved) return;
    entryRemoved = true;
    entry?.remove();
    entry = null;
  }

  testWidgets('signed out shows a Sign in row that calls onLogin', (
    tester,
  ) async {
    var loggedIn = false;
    await pumpMenu(tester, signedIn: false, onLogin: () => loggedIn = true);
    expect(find.text('Sign in'), findsOne);
    expect(find.text('Sign out'), findsNothing);
    // The help group grew the menu; the auth rows live near its bottom.
    await tester.ensureVisible(find.text('Sign in'));
    await tester.pump();
    await tester.tap(find.text('Sign in'));
    expect(loggedIn, isTrue);
    // The wrapper removed the entry as part of the hand-off.
    entryRemoved = true;
    safeRemove();
  });

  testWidgets('signed in shows Sign out instead', (tester) async {
    var loggedOut = false;
    await pumpMenu(tester, signedIn: true, onLogout: () => loggedOut = true);
    expect(find.text('Sign out'), findsOne);
    expect(find.text('Sign in'), findsNothing);
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pump();
    await tester.tap(find.text('Sign out'));
    expect(loggedOut, isTrue);
    // The wrapper removed the entry as part of the hand-off.
    entryRemoved = true;
    safeRemove();
  });

  testWidgets('no callbacks, no rows — the menu stays preference-only', (
    tester,
  ) async {
    await pumpMenu(tester, signedIn: false);
    expect(find.text('Sign in'), findsNothing);
    expect(find.text('Sign out'), findsNothing);
    safeRemove();
  });
}
