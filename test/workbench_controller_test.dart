// The controller and its store: per-session isolation, the debounce, and the
// one transition neither the reducers nor the store can express on their own —
// a conversation acquiring an id after files were already opened into it.

import 'dart:convert';
import 'dart:io';

import 'package:agent_harness/model/workbench.dart';
import 'package:agent_harness/model/workspace.dart';
import 'package:agent_harness/model/sidebar_state.dart';
import 'package:agent_harness/model/sidebar_tab.dart';
import 'package:agent_harness/model/split_node.dart';
import 'package:agent_harness/state/workbench_controller.dart';
import 'package:agent_harness/state/workbench_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Long enough for the store's debounce to have fired. Only used where the
/// assertion is that something did *not* happen — a fixed sleep waiting for a
/// real disk write is a flaky test on a loaded machine, so [_awaitWrite] is what
/// the positive cases use.
Future<void> _settle() =>
    Future<void>.delayed(WorkbenchStore.debounce + const Duration(milliseconds: 60));

/// Waits for the debounced write to [file] to land.
Future<void> _awaitWrite(File file) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!file.existsSync()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('the debounced write to ${file.path} never landed');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  late Directory support;
  late WorkbenchStore store;
  late WorkbenchController controller;

  setUp(() {
    support = Directory.systemTemp.createTempSync('dsh_workbench_test_');
    store = WorkbenchStore.open(support);
    controller = WorkbenchController(store: store, workspaceRoot: '/w');
  });

  tearDown(() {
    controller.dispose();
    support.deleteSync(recursive: true);
  });

  File fileFor(String session) =>
      File('${support.path}/workbench/$session.json');

  group('store', () {
    test('creates its directory under support', () {
      expect(Directory('${support.path}/workbench').existsSync(), isTrue);
    });

    test('load is null for a session that has none', () {
      expect(store.load('nope'), isNull);
    });

    test('writes after the debounce, not before', () async {
      store.save('s1', SidebarState.initial());
      expect(fileFor('s1').existsSync(), isFalse);
      await _awaitWrite(fileFor('s1'));
    });

    test('collapses a burst into the last value', () async {
      var state = SidebarState.initial();
      for (var i = 0; i < 5; i++) {
        state = state.openTab(
          SidebarTab(id: 'tab:$i', type: BuiltinTabType.editor, title: 'x'),
        );
        store.save('s1', state);
      }
      // Each save restarts the timer, so the intermediate four never reach the
      // disk at all — the file is still absent right after the burst.
      expect(fileFor('s1').existsSync(), isFalse);
      await _awaitWrite(fileFor('s1'));
      final decoded = jsonDecode(fileFor('s1').readAsStringSync());
      expect(SidebarState.fromJson(decoded).tabs.length, 5);
    });

    test('flush writes immediately and clears the pending timer', () async {
      store.save('s1', SidebarState.initial());
      await store.flush();
      expect(fileFor('s1').existsSync(), isTrue);
      fileFor('s1').deleteSync();
      // Nothing pending, so the debounce window passing must not resurrect it.
      await _settle();
      expect(fileFor('s1').existsSync(), isFalse);
    });

    test('keeps sessions in separate files', () async {
      store.save('s1', SidebarState.initial().openTerminal());
      store.save('s2', SidebarState.initial());
      await store.flush();
      expect(store.load('s1')!.tabs.length, 1);
      expect(store.load('s2')!.tabs, isEmpty);
    });

    test('a corrupt file reads as absent', () async {
      Directory('${support.path}/workbench').createSync(recursive: true);
      fileFor('s1').writeAsStringSync('{not json');
      expect(store.load('s1'), isNull);
    });

    test('a session id with separators cannot name a file elsewhere', () async {
      store.save('../escape', SidebarState.initial());
      await store.flush();
      expect(File('${support.path}/escape.json').existsSync(), isFalse);
      expect(store.load('../escape'), isNotNull);
    });

    test('delete drops the file and any pending write', () async {
      store.save('s1', SidebarState.initial());
      await store.flush();
      store.save('s1', SidebarState.initial().openTerminal());
      store.delete('s1');
      await _settle();
      expect(fileFor('s1').existsSync(), isFalse);
    });
  });

  group('notification', () {
    test('a real change notifies once', () {
      var notified = 0;
      controller.addListener(() => notified++);
      controller.openFile('/w/a.dart');
      expect(notified, 1);
    });

    test('a no-op gesture does not notify', () {
      controller.openFile('/w/a.dart');
      var notified = 0;
      controller.addListener(() => notified++);
      // The reducers return the receiver for these, and a notification would
      // rebuild the whole workbench for nothing.
      controller.closeTab(controller.state.activePane, 'no-such-tab');
      controller.focusPane('pane:404');
      controller.patchTab('no-such-tab', title: 'x');
      expect(notified, 0);
    });
  });

  group('opens', () {
    test('openFile dedupes by path and carries a line through', () {
      controller.openFile('/w/a.dart');
      controller.openFile('/w/b.dart', line: 12);
      expect(controller.state.tabs.length, 2);
      expect(controller.state.tabById('editor:/w/b.dart')!.meta, {'line': 12});
    });

    test('reopening an open file at a new line moves the caret', () {
      controller.openFile('/w/a.dart', line: 3);
      controller.openFile('/w/a.dart', line: 40);
      expect(controller.state.tabs.length, 1);
      // Focusing an already-open editor has to still honour the line, or the
      // model pointing at one is a no-op.
      expect(controller.state.tabs.single.meta, {'line': 40});
    });

    test('openFolder expands the root it just showed', () {
      controller.openFolder('/w/lib');
      expect(controller.state.tabs.single.type, BuiltinTabType.explorer);
      expect(controller.state.expanded, contains('/w/lib'));
    });

    test('openGit and openSubagents are single-instance', () {
      controller.openGit();
      controller.openGit();
      controller.openSubagents();
      controller.openSubagents();
      expect(controller.state.tabs.length, 2);
    });

    test('openDiff splits off a diff pane, then stacks in it', () {
      controller.openGit();
      controller.openDiff(const WorktreeDiff(path: '/w/a.dart', staged: false));
      expect(controller.state.panes.length, 2);
      final diffPane = controller.state.activePane;
      controller.openDiff(const WorktreeDiff(path: '/w/b.dart', staged: false));
      expect(controller.state.panes.length, 2);
      expect(controller.state.activePane, diffPane);
    });

    test('gestures reach the reducers', () {
      controller.openFile('/w/a.dart');
      controller.splitPane(SplitDirection.row);
      expect(controller.state.panes.length, 2);
      final split = controller.state.tree as SidebarSplit;
      controller.resize(split.id, 0, 0.1);
      expect((controller.state.tree as SidebarSplit).sizes.first, closeTo(0.6, 1e-9));
      controller.toggleExpanded('/w/lib');
      expect(controller.state.expanded, {'/w/lib'});
    });

    test('a disabled type refuses its opens', () {
      controller.setDisabledTabs({BuiltinTabType.terminal});
      controller.openTerminal();
      controller.openGit();
      controller.openSubagents();
      controller.openFolder('/w/lib');
      // The disabled type refused; everything the user did not switch off
      // still opens.
      expect(controller.state.tabs.map((tab) => tab.type), containsAll([
        BuiltinTabType.git,
        BuiltinTabType.subagent,
        BuiltinTabType.explorer,
      ]));
      expect(
        controller.state.tabs.any((tab) => tab.type == BuiltinTabType.terminal),
        isFalse,
      );
    });

    test('openTerminalInBottom lands a terminal in the bottom panel', () {
      controller.openTerminalInBottom();
      final bottom = controller.state.bottomPanes;
      expect(bottom, isNotEmpty);
      final terminal = bottom.expand((pane) => pane.tabs).single;
      expect(terminal.type, BuiltinTabType.terminal);
      // And not a second one in the right column, where openTerminal would
      // have put it.
      expect(controller.state.panes.first.tabs, isEmpty);
    });

    test('the seed respects a disabled terminal type', () {
      controller.setDisabledTabs({BuiltinTabType.terminal});
      controller.openTerminalInBottom();
      expect(controller.state.tabs, isEmpty);
    });
  });

  group('mobile merge', () {
    test('setMobileMerge folds the bottom tabs into the right tree', () {
      controller.openGit();
      controller.sendTabToOtherPanel(controller.state.panes.first.id, 'git');
      expect(controller.state.bottomTabs, isNotEmpty);

      controller.setMobileMerge(true);
      expect(controller.state.bottomTabs, isEmpty);
      expect(controller.state.tabs.map((tab) => tab.id), ['git']);
      expect(controller.state.activePane, controller.state.panes.first.id);
    });

    test('bindSession migrates a restored layout while merged', () async {
      var stored = SidebarState.initial().openTab(
        const SidebarTab(id: 'tab:x', type: BuiltinTabType.editor, title: 'x'),
      );
      stored = stored.moveTabToOtherTree(stored.panes.single.id, 'tab:x');
      store.save('s1', stored);
      await store.flush();

      controller.setMobileMerge(true);
      await controller.bindSession('s1');
      expect(controller.state.bottomTabs, isEmpty);
      expect(controller.state.tabs.map((tab) => tab.id), ['tab:x']);
    });

    test('turning the merge off again changes nothing', () {
      controller.openGit();
      controller.setMobileMerge(true);
      final merged = controller.state;
      controller.setMobileMerge(false);
      expect(controller.state, same(merged));
    });
  });

  group('workspace', () {
    test('exposes the guard for the granted root', () {
      final temp = Directory.systemTemp.createTempSync('dsh_ws_');
      addTearDown(() => temp.deleteSync(recursive: true));
      controller.workspaceRoot = temp.path;
      expect(controller.workspace, isNotNull);
      expect(
        () => controller.workspace!.resolve('../outside'),
        throwsA(isA<WorkspaceDenied>()),
      );
    });

    test('is null with no workspace granted, and reveal is then a no-op', () {
      final bare = WorkbenchController(store: store);
      addTearDown(bare.dispose);
      expect(bare.workspace, isNull);
      bare.reveal(['/w/lib/a.dart']);
      expect(bare.state.expanded, isEmpty);
    });

    test('changing the root notifies', () {
      var notified = 0;
      controller.addListener(() => notified++);
      controller.workspaceRoot = '/other';
      controller.workspaceRoot = '/other';
      expect(notified, 1);
    });
  });

  group('WorkbenchSink', () {
    test('a file open succeeds and shows an editor', () {
      final reason = controller.open(
        const OpenTarget(kind: OpenKind.file, target: '/w/a.dart', line: 7),
      );
      expect(reason, isNull);
      expect(controller.state.tabs.single.type, BuiltinTabType.editor);
      expect(controller.state.tabs.single.meta, {'line': 7});
    });

    test('a folder open succeeds and shows a tree', () {
      final reason = controller.open(
        const OpenTarget(kind: OpenKind.folder, target: '/w/lib'),
      );
      expect(reason, isNull);
      expect(controller.state.tabs.single.type, BuiltinTabType.explorer);
    });

    test('a url opens the browser tab, not an exception', () {
      final reason = controller.open(
        const OpenTarget(kind: OpenKind.url, target: 'https://example.com'),
      );
      // The tool turns a non-null reason into `{ok: false, error}`; throwing
      // would make it a crash the model cannot act on. A url is not refused
      // anymore — it is where the browser tab's address came from.
      expect(reason, isNull);
      final tab = controller.state.tabs.single;
      expect(tab.type, BuiltinTabType.browser);
      expect(tab.path, 'https://example.com');
    });

    test('reveal expands ancestors without opening anything', () {
      controller.reveal(['/w/lib/sidebar/a.dart']);
      expect(controller.state.expanded, {'/w', '/w/lib', '/w/lib/sidebar'});
      expect(controller.state.tabs, isEmpty);
    });
  });

  group('bindSession', () {
    test('nothing is written while the conversation has no id', () async {
      controller.openFile('/w/a.dart');
      await _settle();
      expect(Directory('${support.path}/workbench').listSync(), isEmpty);
    });

    test('a first id adopts the layout built before it existed', () async {
      controller.openFile('/w/a.dart');
      await controller.bindSession('s1');
      expect(controller.sessionId, 's1');
      // The whole point: the files opened while composing the first turn belong
      // to the session that turn created.
      expect(controller.state.tabs.map((tab) => tab.id), ['editor:/w/a.dart']);
      await store.flush();
      expect(store.load('s1')!.tabs.length, 1);
    });

    test('binding to an id with a stored layout loads it, not the current one',
        () async {
      await controller.bindSession('s1');
      controller.openFile('/w/one.dart');
      await controller.bindSession('s2');
      expect(controller.state.tabs, isEmpty);
      controller.openFile('/w/two.dart');
      await controller.bindSession('s1');
      expect(controller.state.tabs.map((tab) => tab.id), ['editor:/w/one.dart']);
    });

    test('a layout survives a round trip through disk', () async {
      await controller.bindSession('s1');
      controller.openFile('/w/one.dart');
      controller.splitPane(SplitDirection.col);
      await controller.flush();

      final reopened = WorkbenchController(
        store: WorkbenchStore.open(support),
        workspaceRoot: '/w',
      );
      addTearDown(reopened.dispose);
      await reopened.bindSession('s1');
      expect(reopened.state.panes.length, 2);
      expect(reopened.state.tabs.map((tab) => tab.id), ['editor:/w/one.dart']);
    });

    test('binding flushes the outgoing session rather than losing it', () async {
      await controller.bindSession('s1');
      controller.openFile('/w/one.dart');
      // No settle: the debounce is still open, and the bind is the last chance.
      await controller.bindSession('s2');
      expect(store.load('s1')!.tabs.length, 1);
    });

    test('rebinding the same id is a no-op', () async {
      await controller.bindSession('s1');
      controller.openFile('/w/one.dart');
      await controller.bindSession('s1');
      expect(controller.state.tabs.length, 1);
    });

    test('going back to the unsaved conversation shows an empty workbench',
        () async {
      await controller.bindSession('s1');
      controller.openFile('/w/one.dart');
      await controller.bindSession(null);
      expect(controller.sessionId, isNull);
      expect(controller.state.tabs, isEmpty);
    });

    test('an adopted layout is not handed to the next new conversation',
        () async {
      controller.openFile('/w/a.dart');
      await controller.bindSession('s1');
      await controller.bindSession(null);
      expect(controller.state.tabs, isEmpty);
      await controller.bindSession('s2');
      expect(controller.state.tabs, isEmpty);
      expect(store.load('s1')!.tabs.length, 1);
    });
  });

  group('forgetSession', () {
    test('drops the layout of a deleted session', () async {
      await controller.bindSession('s1');
      controller.openFile('/w/one.dart');
      await controller.flush();
      controller.forgetSession('s1');
      expect(store.load('s1'), isNull);
      // It was the bound one, so the workbench falls back to unsaved-and-empty
      // rather than showing a session that no longer exists.
      expect(controller.sessionId, isNull);
      expect(controller.state.tabs, isEmpty);
    });

    test('leaves the bound session alone when another is forgotten', () async {
      await controller.bindSession('s1');
      controller.openFile('/w/one.dart');
      await controller.flush();
      await controller.bindSession('s2');
      controller.openFile('/w/two.dart');
      controller.forgetSession('s1');
      expect(controller.sessionId, 's2');
      expect(controller.state.tabs.length, 1);
    });
  });
}
