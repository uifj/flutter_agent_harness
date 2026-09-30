// The locale has to be mounted where the overlays can see it. The sentence this
// file guards (ADR-0032): a menu or dialog opened by the app translates its own
// labels, in the language the user picked.
//
// Why this needs a guard at all: `context.tr` falls back to English key-by-key
// when there is no `AppLocaleScope` above it (`lib/l10n/locales.dart:928-939`),
// and an overlay route is not under `home:`. A real window screenshot caught the
// result — the model menu rendered 载入服务端的模型列表 next to an English
// `Retry`, both from the same dictionary. This is ADR-0017's lesson a second
// time ("a `MediaQuery` written in `home:` never reaches an overlay route; every
// menu we had measured open was measured un-amplified"), only the thing that
// leaked was copy rather than font size.
//
// Two tests, guarding different things on purpose. The first is structural and is
// the one that can catch a regression in the app: it reads `lib/main.dart` and
// requires the scope to sit between `builder:` and `home:`. The second is the
// mechanism the first assumes — that a scope above the Navigator really does
// reach a menu route — because a structural rule nobody checked against the
// framework is only a guess about it.

import 'dart:io';

import 'package:agent_harness/l10n/locales.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the app mounts the locale above the Navigator, not inside home', () {
    final source = File('lib/main.dart').readAsStringSync();
    // Anchored on the frame's own two seams, not on the bare words: `builder:`
    // also appears in `itemBuilder:` and in prose, and a guard that latches onto
    // the first such hit would pass or fail for the wrong reason. The arrow is
    // deliberately not part of the anchor: that builder now has a body, because
    // the composed text step is read once and handed to both `MediaQuery` and
    // the shad bridge (ADR-0017 S3), and how it opens says nothing about where
    // the locale sits.
    final builder = source.indexOf('builder: (context, child)');
    final home = source.indexOf('home: Scaffold(');
    final scope = source.indexOf('AppLocaleScope(');

    expect(
      builder,
      greaterThan(-1),
      reason: 'the seam this guard names is gone',
    );
    expect(
      home,
      greaterThan(builder),
      reason: 'home: must come after builder:',
    );
    expect(
      scope,
      inInclusiveRange(builder, home),
      reason:
          'an AppLocaleScope below `home:` is invisible to every overlay '
          'route, so their `context.tr` silently falls back to English',
    );
    expect(
      RegExp(r'AppLocaleScope\(').allMatches(source).length,
      1,
      reason:
          'two locale seats is two truths about which language the app speaks',
    );
  });

  testWidgets('a scope above the Navigator reaches a menu route', (
    tester,
  ) async {
    Future<String?> openMenu(Widget Function(Widget) mount) async {
      await tester.pumpWidget(
        mount(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: PopupMenuButton<String>(
                  onSelected: (_) {},
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      value: 'retry',
                      child: Text(context.tr('retry')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      final labels = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((r) => r.text.toPlainText())
          .toSet();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      return labels.intersection({'重试', 'Retry'}).firstOrNull;
    }

    expect(
      await openMenu(
        (child) => AppLocaleScope(locale: AppLocaleId.zh, child: child),
      ),
      '重试',
      reason:
          'the menu route has to read the app-wide locale, not the fallback',
    );
  });
}
