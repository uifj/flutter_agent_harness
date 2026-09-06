// WorkbenchPrefs: what the side card remembers, and what the panel does with
// it.
//
// The model is worth testing for its two deliberate economies: the
// absent-means-enabled tab switches (a document from another build must not
// lose a type it never mentioned) and the clamped font size (the terminal
// renders whatever lands here, so an out-of-range value would be a layout
// bug, not a settings bug). The store is worth testing for the same reason
// every store here is: a corrupt file must not stop the app from launching.

import 'dart:convert';
import 'dart:io';

import 'package:agent_harness/model/workbench_prefs.dart';
import 'package:agent_harness/state/prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkbenchPrefs', () {
    test('round-trips through JSON', () {
      const prefs = WorkbenchPrefs(
        bottomPanelAutoTerminal: false,
        terminalFontFamily: "'JetBrains Mono', monospace",
        terminalFontSize: 15,
        tabsEnabled: {'git': false},
      );
      final decoded = WorkbenchPrefs.fromJson(
        jsonDecode(jsonEncode(prefs.toJson())) as Map<String, dynamic>,
      );
      expect(decoded, prefs);
    });

    test('reads an absent document as the defaults', () {
      final decoded = WorkbenchPrefs.fromJson(const {});
      expect(decoded.bottomPanelAutoTerminal, isTrue);
      expect(decoded.terminalFontFamily, '');
      expect(decoded.terminalFontSize, terminalFontSizeDefault);
      expect(decoded.tabEnabled('terminal'), isTrue);
    });

    test('absent means enabled; only an explicit false disables', () {
      const prefs = WorkbenchPrefs(tabsEnabled: {'git': false, 'subagent': true});
      expect(prefs.tabEnabled('explorer'), isTrue);
      expect(prefs.tabEnabled('subagent'), isTrue);
      expect(prefs.tabEnabled('git'), isFalse);
    });

    test('withTabEnabled re-enables by dropping the key', () {
      const prefs = WorkbenchPrefs(tabsEnabled: {'git': false});
      final enabled = prefs.withTabEnabled('git', true);
      expect(enabled.tabEnabled('git'), isTrue);
      // No redundant true is stored — the document stays the economy it read.
      expect(enabled.toJson().containsKey('tabsEnabled'), isFalse);
    });

    test('the font size is clamped at every read', () {
      final fromJson = WorkbenchPrefs.fromJson(
        const {'terminalFontSize': 99},
      );
      expect(fromJson.terminalFontSize, terminalFontSizeMax);
      final fromJsonLow = WorkbenchPrefs.fromJson(
        const {'terminalFontSize': 1},
      );
      expect(fromJsonLow.terminalFontSize, terminalFontSizeMin);
    });
  });

  group('PrefsStore', () {
    late Directory root;

    setUp(() => root = Directory.systemTemp.createTempSync('dsh-prefs'));
    tearDown(() => root.deleteSync(recursive: true));

    test('starts at the defaults when nothing is stored', () async {
      final store = await PrefsStore.open(root);
      expect(store.value, const WorkbenchPrefs());
    });

    test('a saved document survives a reopen', () async {
      final store = await PrefsStore.open(root);
      const next = WorkbenchPrefs(
        bottomPanelAutoTerminal: false,
        terminalFontSize: 16,
        tabsEnabled: {'terminal': false},
      );
      await store.save(next);

      final reopened = await PrefsStore.open(root);
      expect(reopened.value, next);
    });

    test('a corrupt file reads as absent rather than throwing', () async {
      File('${root.path}/prefs.json').writeAsStringSync('{not json');
      final store = await PrefsStore.open(root);
      expect(store.value, const WorkbenchPrefs());
    });

    test('notifies once per accepted save, and not for a no-op', () async {
      final store = await PrefsStore.open(root);
      var notifications = 0;
      store.addListener(() => notifications++);

      await store.save(const WorkbenchPrefs(bottomPanelAutoTerminal: false));
      await store.save(const WorkbenchPrefs(bottomPanelAutoTerminal: false));
      expect(notifications, 1);
    });
  });
}
