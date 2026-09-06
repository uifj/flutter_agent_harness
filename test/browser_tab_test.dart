// The browser tab: the address bar's rules, the fresh tab, and the controller
// plumbing that makes a typed address survive.
//
// The URL rules are pure functions, so they get the exhaustive table — a rule
// that only lives behind a web view would be a rule nobody could check. The
// widget tests stay on the fresh tab and the refusal paths, which is the whole
// bar interaction short of loading a page: the view itself is a platform view,
// and mounting one in a widget test would test the plugin, not this tab.

import 'dart:io';

import 'package:agent_harness/model/sidebar_tab.dart';
import 'package:agent_harness/state/workbench_controller.dart';
import 'package:agent_harness/state/workbench_store.dart';
import 'package:agent_harness/ui/workbench/tabs/browser_tab.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeBrowserUrl', () {
    test('promotes a bare host to https', () {
      final result = normalizeBrowserUrl('example.com');
      expect(result.isOk, isTrue);
      expect(result.url, 'https://example.com');
    });

    test('keeps an explicit scheme', () {
      expect(normalizeBrowserUrl('http://example.com').url, 'http://example.com');
      expect(
        normalizeBrowserUrl('https://example.com/a?b=c').url,
        'https://example.com/a?b=c',
      );
    });

    test('trims before deciding anything', () {
      expect(normalizeBrowserUrl('  example.com  ').url, 'https://example.com');
    });

    test('empty and hostless text is invalid', () {
      expect(normalizeBrowserUrl('').verdict, BrowserUrlVerdict.invalid);
      // A url with no host at all — `Uri.tryParse` accepts it, the bar must
      // not: there is nothing to load.
      expect(
        normalizeBrowserUrl('https:///oops').verdict,
        BrowserUrlVerdict.invalid,
      );
    });

    test('schemes beyond http and https are refused', () {
      expect(
        normalizeBrowserUrl('ftp://example.com').verdict,
        BrowserUrlVerdict.blockedScheme,
      );
      expect(
        normalizeBrowserUrl('file://example.com').verdict,
        BrowserUrlVerdict.blockedScheme,
      );
    });

    test('loopback is refused, however it is spelled', () {
      const refused = [
        'http://localhost',
        'http://localhost.',
        'http://127.0.0.1:8080',
        'http://[::1]/',
        'http://0.0.0.0',
      ];
      for (final raw in refused) {
        expect(
          normalizeBrowserUrl(raw).verdict,
          BrowserUrlVerdict.blockedLoopback,
          reason: '$raw should be refused as loopback',
        );
      }
    });

    test('a host that merely mentions loopback is fine', () {
      expect(normalizeBrowserUrl('https://localhost.example.com').isOk, isTrue);
    });
  });

  group('browserHostOf', () {
    test('is the host of a parsable url', () {
      expect(browserHostOf('https://example.com/a'), 'example.com');
    });

    test('is the whole text when it does not parse', () {
      expect(browserHostOf('::not a url'), '::not a url');
    });
  });

  group('the fresh tab', () {
    late Directory support;
    late WorkbenchController workbench;

    setUp(() {
      support = Directory.systemTemp.createTempSync('dsh_browser_tab_');
      workbench = WorkbenchController(store: WorkbenchStore.open(support));
    });

    tearDown(() {
      workbench.dispose();
      support.deleteSync(recursive: true);
    });

    Future<void> pumpTab(WidgetTester tester, {String? path}) =>
        tester.pumpWidget(
          MaterialApp(
            theme: dswThemeData(Brightness.light),
            home: Scaffold(
              body: BrowserTab(
                workbench: workbench,
                tab: SidebarTab(
                  id: 'browser:1',
                  type: BuiltinTabType.browser,
                  title: 'Browser',
                  path: path,
                ),
              ),
            ),
          ),
        );

    testWidgets('says how to start, with no view mounted', (tester) async {
      await pumpTab(tester);
      expect(
        find.text('Enter an address above to start browsing.'),
        findsOneWidget,
      );
      expect(find.byType(InAppWebView), findsNothing);
    });

    testWidgets('an invalid address gets the refusal bar, not a page', (
      tester,
    ) async {
      await pumpTab(tester);
      await tester.enterText(find.byType(TextField), 'https:///oops');
      await tester.tap(find.byIcon(LucideIcons.arrow_right));
      await tester.pump();

      expect(find.text('That is not a valid address.'), findsOneWidget);
      expect(find.byType(InAppWebView), findsNothing);
    });

    testWidgets('a non-http scheme is refused with its own words', (
      tester,
    ) async {
      await pumpTab(tester);
      await tester.enterText(find.byType(TextField), 'ftp://example.com');
      await tester.tap(find.byIcon(LucideIcons.arrow_right));
      await tester.pump();

      expect(
        find.text('Only http and https addresses can be opened.'),
        findsOneWidget,
      );
    });

    testWidgets('loopback is refused with its own words', (tester) async {
      await pumpTab(tester);
      await tester.enterText(find.byType(TextField), 'http://127.0.0.1:8080');
      await tester.tap(find.byIcon(LucideIcons.arrow_right));
      await tester.pump();

      expect(find.text('Local addresses are refused.'), findsOneWidget);
    });

    testWidgets('a fresh tab has nothing to reload or hand out', (
      tester,
    ) async {
      await pumpTab(tester);
      // Both buttons render dimmed rather than hidden; their gestures are
      // simply absent, which tap-with-no-crash cannot show — but the start
      // hint standing in for a page does.
      expect(find.byIcon(LucideIcons.refresh_cw), findsOneWidget);
      expect(find.byIcon(LucideIcons.external_link), findsOneWidget);
    });
  });

  group('the controller', () {
    late Directory support;
    late WorkbenchController workbench;

    setUp(() {
      support = Directory.systemTemp.createTempSync('dsh_browser_ctrl_');
      workbench = WorkbenchController(store: WorkbenchStore.open(support));
    });

    tearDown(() {
      workbench.dispose();
      support.deleteSync(recursive: true);
    });

    List<SidebarTab> tabs() => workbench.state.panes
        .expand((pane) => pane.tabs)
        .toList();

    test('opening the same url twice focuses the one tab', () {
      workbench.openBrowser('https://example.com');
      workbench.openBrowser('https://example.com');

      expect(
        tabs().where((tab) => tab.type == BuiltinTabType.browser),
        hasLength(1),
      );
      expect(
        workbench.state.panes.first.active,
        'browser:https://example.com',
      );
    });

    test('fresh tabs mint fresh ids', () {
      workbench.openBrowserUntitled();
      workbench.openBrowserUntitled();

      expect(
        tabs().map((tab) => tab.id),
        containsAll(['browser:1', 'browser:2']),
      );
    });

    test('the address bar writes the path and title onto the tab', () {
      workbench.openBrowserUntitled();
      workbench.patchTab(
        'browser:1',
        path: 'https://example.com/a',
        title: 'example.com',
      );

      final tab = tabs().single;
      expect(tab.path, 'https://example.com/a');
      expect(tab.title, 'example.com');
    });

    test('a disabled browser type opens nothing', () {
      workbench.setDisabledTabs({BuiltinTabType.browser});
      workbench.openBrowser('https://example.com');
      workbench.openBrowserUntitled();

      expect(tabs(), isEmpty);
    });

    test('the side chat is a single tab', () {
      workbench.openSideChat();
      workbench.openSideChat();

      expect(
        tabs().where((tab) => tab.type == BuiltinTabType.sidechat),
        hasLength(1),
      );
    });

    test('a disabled side chat opens nothing', () {
      workbench.setDisabledTabs({BuiltinTabType.sidechat});
      workbench.openSideChat();

      expect(tabs(), isEmpty);
    });
  });
}
