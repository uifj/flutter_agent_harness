// The locale has to be mounted where the overlays can see it. The sentence
// this file guards (ADR-0032, re-cut for ADR-0082): a menu or dialog the app
// opens translates its own labels, in the language the user picked.
//
// Why this needs a guard at all: an overlay route is pushed ABOVE `home:`, so a
// locale seat mounted inside `home:` never reaches it. A real window screenshot
// caught the result once — the model menu rendered 载入服务端的模型列表 next to an
// English `Retry`, both from the same dictionary (ADR-0017's lesson a second
// time, only the thing that leaked was copy rather than font size).
//
// The seat used to be an `AppLocaleScope` in `MaterialApp.builder`. ADR-0082
// retired it: the `MaterialApp`'s own `localizationsDelegates` + `locale` are
// the single seat now, and — being on the MaterialApp, above the Navigator —
// they reach every overlay route by construction. `AppLocalizations.of` no
// longer falls back to English when the seat is missing; it throws. So the two
// tests below guard, respectively, that the seat is wired in `main.dart` and
// that a seat above the Navigator really does reach a menu route.

import 'dart:io';

import 'package:planstar/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app localizes through the MaterialApp, above the Navigator', () {
    final source = File('lib/main.dart').readAsStringSync();
    // The single locale seat: the MaterialApp's own delegates + locale. On the
    // MaterialApp they sit above the Navigator, so overlay routes inherit them.
    expect(
      source,
      contains(
        'localizationsDelegates: AppLocalizations.localizationsDelegates',
      ),
      reason:
          'without the delegate, AppLocalizations.of throws and the localized '
          'system widgets (text-selection menu, date picker) stay English',
    );
    expect(
      source,
      contains('supportedLocales: AppLocalizations.supportedLocales'),
      reason: 'the delegate resolves the locale against supportedLocales',
    );
    // The old app-copy seat is fully retired: two seats would be two truths
    // about which language the app speaks (the reason this guard existed).
    expect(
      RegExp(r'AppLocaleScope\(').allMatches(source).length,
      0,
      reason:
          'AppLocaleScope was retired at the flip (ADR-0082); the MaterialApp '
          'delegate is the only seat left',
    );
  });

  testWidgets('a delegate above the Navigator reaches a menu route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: Center(
            child: PopupMenuButton<String>(
              onSelected: (_) {},
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'retry',
                  child: Text(AppLocalizations.of(context).retry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    // The menu route lives above `home:`; it has to read the app-wide zh locale
    // rather than fall back to English — the exact regression ADR-0032 caught.
    expect(
      find.text('重试'),
      findsOneWidget,
      reason: 'the overlay route must see the app-wide locale, not English',
    );
  });
}
