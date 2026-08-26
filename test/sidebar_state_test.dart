// The state reducers: the gesture vocabulary of the workbench, driven as plain
// values. Anything that needs a widget tree belongs in workbench_ui_test.dart.

import 'package:agent_harness/sidebar/model/sidebar_state.dart';
import 'package:agent_harness/sidebar/model/sidebar_tab.dart';
import 'package:agent_harness/sidebar/model/split_node.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

SidebarTab _tab(String id) =>
    SidebarTab(id: id, type: BuiltinTabType.editor, title: id);

/// A two-pane row: `a` alone on the left, `b` alone on the right, right active.
({SidebarState state, String left, String right}) _twoPanes() {
  var state = SidebarState.initial().openTab(_tab('a'));
  final left = state.activePane;
  state = state.splitPane(SplitDirection.row);
  final right = state.panes.last.id;
  // splitPane leaves the source pane active, so aim at the fresh one before
  // opening into it.
  state = state.focusPane(right).openTab(_tab('b'));
  return (state: state, left: left, right: right);
}

void main() {
  group('initial', () {
    test('is one empty pane which is the active one', () {
      final state = SidebarState.initial();
      expect(state.panes.length, 1);
      expect(state.tabs, isEmpty);
      expect(state.activePane, state.panes.single.id);
    });
  });

  group('openTab', () {
    test('lands the tab in the active pane and shows it', () {
      final state = SidebarState.initial().openTab(_tab('a'));
      expect(state.tabs.map((tab) => tab.id), ['a']);
      expect(state.panes.single.active, 'a');
    });

    test('focuses the existing instance instead of stacking a duplicate', () {
      var state = SidebarState.initial().openTab(_tab('a')).openTab(_tab('b'));
      state = state.openTab(_tab('a'));
      expect(state.tabs.map((tab) => tab.id), ['a', 'b']);
      expect(state.panes.single.active, 'a');
    });

    test('focuses an instance living in another pane, and follows it', () {
      final panes = _twoPanes();
      final state = panes.state.openTab(_tab('a'));
      expect(state.activePane, panes.left);
      expect(state.tabs.length, 2);
    });

    test('survives a stale active pane rather than swallowing the open', () {
      final panes = _twoPanes();
      // Close the pane the state points at, through the tree directly, to
      // reproduce the state.ts:559-564 hazard.
      final orphaned = SidebarState(
        tree: removeLeafAt(panes.state.tree, panes.right),
        activePane: panes.right,
        expanded: const {},
        nextTerminal: 1,
        nextId: panes.state.nextId,
      );
      final state = orphaned.openTab(_tab('c'));
      expect(state.tabs.map((tab) => tab.id), ['a', 'c']);
      expect(state.activePane, panes.left);
    });

    test('two files opened by path get two tabs, the same file one', () {
      var state = SidebarState.initial()
          .openTab(SidebarTab.editor('/w/one.dart'))
          .openTab(SidebarTab.editor('/w/two.dart'));
      expect(state.tabs.length, 2);
      state = state.openTab(SidebarTab.editor('/w/one.dart'));
      expect(state.tabs.length, 2);
      expect(state.panes.single.active, 'editor:/w/one.dart');
    });
  });

  group('openTerminal', () {
    test('stacks rather than dedupes, and never reuses a number', () {
      var state = SidebarState.initial().openTerminal().openTerminal();
      expect(state.tabs.map((tab) => tab.title), ['Terminal 1', 'Terminal 2']);
      state = state.closeTab(state.activePane, 'terminal:2').openTerminal();
      // "Terminal 2" keyed a pty session; handing the name to a third shell
      // would point the reopened tab at the dead one's scrollback.
      expect(state.tabs.map((tab) => tab.id), ['terminal:1', 'terminal:3']);
    });
  });

  group('closeTab', () {
    test('falls back to the last remaining tab', () {
      var state = SidebarState.initial().openTab(_tab('a')).openTab(_tab('b'));
      state = state.closeTab(state.activePane, 'b');
      expect(state.panes.single.active, 'a');
    });

    test('keeps the active tab when a different one closes', () {
      var state = SidebarState.initial().openTab(_tab('a')).openTab(_tab('b'));
      state = state.activateTab(state.activePane, 'b');
      state = state.closeTab(state.activePane, 'a');
      expect(state.panes.single.active, 'b');
    });

    test('empties the only pane rather than removing it', () {
      var state = SidebarState.initial().openTab(_tab('a'));
      state = state.closeTab(state.activePane, 'a');
      expect(state.panes.length, 1);
      expect(state.panes.single.active, isNull);
    });

    test('collapses an emptied pane and re-points a stale active pane', () {
      final panes = _twoPanes();
      final state = panes.state.closeTab(panes.right, 'b');
      expect(state.panes.length, 1);
      expect(state.activePane, panes.left);
    });

    test('is a no-op for a tab the pane does not hold', () {
      final state = SidebarState.initial().openTab(_tab('a'));
      expect(identical(state.closeTab(state.activePane, 'z'), state), isTrue);
    });
  });

  group('activateTab', () {
    test('shows the tab and makes its pane active', () {
      final panes = _twoPanes();
      final state = panes.state.activateTab(panes.left, 'a');
      expect(state.activePane, panes.left);
      expect(state.paneOf('a')!.active, 'a');
    });

    test('does not show a tab the pane does not hold', () {
      final panes = _twoPanes();
      final state = panes.state.activateTab(panes.left, 'b');
      expect(state.paneOf('a')!.active, 'a');
    });
  });

  group('focusPane', () {
    test('aims the next open at an empty pane', () {
      var state = SidebarState.initial().openTab(_tab('a'));
      final left = state.activePane;
      state = state.splitPane(SplitDirection.row);
      final right = state.panes.last.id;
      state = state.focusPane(right).openTab(_tab('b'));
      expect(state.paneOf('b')!.id, right);
      expect(state.paneOf('a')!.id, left);
    });

    test('ignores a pane that does not exist', () {
      final state = SidebarState.initial();
      expect(identical(state.focusPane('pane:404'), state), isTrue);
    });
  });

  group('patchTab', () {
    test('rewrites title, path and meta in place', () {
      var state = SidebarState.initial().openTab(_tab('a'));
      state = state.patchTab(
        'a',
        title: 'renamed',
        path: '/w/x.dart',
        meta: const {'scroll': 42},
      );
      final tab = state.tabById('a')!;
      expect(tab.title, 'renamed');
      expect(tab.path, '/w/x.dart');
      expect(tab.meta, const {'scroll': 42});
    });

    test('reaches a tab in a nested pane', () {
      final panes = _twoPanes();
      final state = panes.state.patchTab('a', title: 'renamed');
      expect(state.tabById('a')!.title, 'renamed');
      expect(state.tabById('b')!.title, 'b');
    });

    test('is a no-op for an unknown tab', () {
      final state = SidebarState.initial().openTab(_tab('a'));
      expect(identical(state.patchTab('z', title: 'x'), state), isTrue);
    });
  });

  group('splitPane', () {
    test('splits the active pane and advances the id counter', () {
      final before = SidebarState.initial().openTab(_tab('a'));
      final state = before.splitPane(SplitDirection.col);
      expect(state.panes.length, 2);
      expect((state.tree as SidebarSplit).dir, SplitDirection.col);
      expect(state.nextId, greaterThan(before.nextId));
    });
  });

  group('moveTab', () {
    test('reorders inside one pane without destroying it', () {
      var state = SidebarState.initial()
          .openTab(_tab('a'))
          .openTab(_tab('b'))
          .openTab(_tab('c'));
      final pane = state.activePane;
      state = state.moveTab(pane, 'a', pane, 2);
      expect(state.panes.single.tabs.map((tab) => tab.id), ['b', 'c', 'a']);
    });

    test('appends when the index is out of range', () {
      var state = SidebarState.initial().openTab(_tab('a')).openTab(_tab('b'));
      final pane = state.activePane;
      state = state.moveTab(pane, 'a', pane);
      expect(state.panes.single.tabs.map((tab) => tab.id), ['b', 'a']);
    });

    test('moving a pane\'s only tab back onto itself keeps the pane', () {
      var state = SidebarState.initial().openTab(_tab('a'));
      final pane = state.activePane;
      state = state.moveTab(pane, 'a', pane);
      expect(state.panes.length, 1);
      expect(state.tabs.map((tab) => tab.id), ['a']);
    });

    test('carries a tab across panes and collapses the emptied one', () {
      final panes = _twoPanes();
      final state = panes.state.moveTab(panes.right, 'b', panes.left, 0);
      expect(state.panes.length, 1);
      expect(state.panes.single.tabs.map((tab) => tab.id), ['b', 'a']);
      expect(state.activePane, panes.left);
    });

    test('is a no-op when the tab is not in the pane it was dragged from', () {
      final panes = _twoPanes();
      expect(
        identical(
          panes.state.moveTab(panes.left, 'b', panes.right),
          panes.state,
        ),
        isTrue,
      );
    });
  });

  group('moveTabToEdge', () {
    test('centre is a merge', () {
      final panes = _twoPanes();
      final state = panes.state.moveTabToEdge(
        panes.right,
        'b',
        panes.left,
        DropZone.center,
      );
      expect(state.panes.length, 1);
      expect(state.panes.single.tabs.map((tab) => tab.id), ['a', 'b']);
    });

    test('centre onto its own pane moves the tab to the end', () {
      var state = SidebarState.initial()
          .openTab(_tab('a'))
          .openTab(_tab('b'))
          .openTab(_tab('c'));
      final pane = state.activePane;
      state = state.moveTabToEdge(pane, 'a', pane, DropZone.center);
      expect(state.panes.single.tabs.map((tab) => tab.id), ['b', 'c', 'a']);
    });

    test('right splits horizontally with the tab in the trailing pane', () {
      var state = SidebarState.initial().openTab(_tab('a')).openTab(_tab('b'));
      final pane = state.activePane;
      state = state.moveTabToEdge(pane, 'b', pane, DropZone.right);
      final split = state.tree as SidebarSplit;
      expect(split.dir, SplitDirection.row);
      expect(split.children.first.id, pane);
      expect(state.activePane, split.children.last.id);
      expect((split.children.last as SidebarLeaf).tabs.single.id, 'b');
    });

    test('up splits vertically with the tab in the leading pane', () {
      var state = SidebarState.initial().openTab(_tab('a')).openTab(_tab('b'));
      final pane = state.activePane;
      state = state.moveTabToEdge(pane, 'b', pane, DropZone.up);
      final split = state.tree as SidebarSplit;
      expect(split.dir, SplitDirection.col);
      expect(split.children.first.id, state.activePane);
    });

    test('dragging a pane\'s last tab to that pane\'s edge changes nothing', () {
      final state = SidebarState.initial().openTab(_tab('a'));
      final pane = state.activePane;
      // Removing the source pane would take the drop target with it.
      expect(
        identical(state.moveTabToEdge(pane, 'a', pane, DropZone.left), state),
        isTrue,
      );
    });

    test('across panes: the source collapses and the target splits', () {
      final panes = _twoPanes();
      final state = panes.state.moveTabToEdge(
        panes.right,
        'b',
        panes.left,
        DropZone.down,
      );
      expect(state.panes.length, 2);
      final split = state.tree as SidebarSplit;
      expect(split.dir, SplitDirection.col);
      expect(split.children.first.id, panes.left);
    });
  });

  group('openDiffTab', () {
    final change = SidebarTab.diff(
      const WorktreeDiff(path: '/w/one.dart', staged: false),
    );
    final other = SidebarTab.diff(
      const WorktreeDiff(path: '/w/two.dart', staged: false),
    );

    test('the first diff splits the source pane downwards', () {
      var state = SidebarState.initial().openTab(SidebarTab.git);
      final source = state.activePane;
      state = state.openDiffTab(source, change);
      final split = state.tree as SidebarSplit;
      expect(split.dir, SplitDirection.col);
      expect(split.children.first.id, source);
      expect(state.activePane, split.children.last.id);
    });

    test('later diffs stack in the pane that already holds one', () {
      var state = SidebarState.initial().openTab(SidebarTab.git);
      final source = state.activePane;
      state = state.openDiffTab(source, change);
      final diffPane = state.activePane;
      state = state.openDiffTab(source, other);
      expect(state.panes.length, 2);
      expect(state.activePane, diffPane);
      expect(state.paneOf(other.id)!.id, diffPane);
    });

    test('a repeat click on the same change focuses it', () {
      var state = SidebarState.initial().openTab(SidebarTab.git);
      final source = state.activePane;
      state = state.openDiffTab(source, change);
      final after = state.openDiffTab(source, SidebarTab.diff(
        const WorktreeDiff(path: '/w/one.dart', staged: false),
      ));
      expect(after.tabs.where((tab) => tab.id == change.id).length, 1);
      expect(after.panes.length, 2);
    });

    test('staged and unstaged versions of one path are two tabs', () {
      var state = SidebarState.initial().openTab(SidebarTab.git);
      final source = state.activePane;
      state = state.openDiffTab(source, change);
      state = state.openDiffTab(
        source,
        SidebarTab.diff(const WorktreeDiff(path: '/w/one.dart', staged: true)),
      );
      expect(state.tabs.where((tab) => tab.type == BuiltinTabType.diff).length, 2);
    });

    test('a stale source pane degrades to a plain open', () {
      final state = SidebarState.initial().openTab(_tab('a'));
      final after = state.openDiffTab('pane:404', change);
      expect(after.panes.length, 1);
      expect(after.tabs.map((tab) => tab.id), ['a', change.id]);
    });
  });

  group('resize', () {
    test('moves the divider of the named split', () {
      final panes = _twoPanes();
      final splitId = (panes.state.tree as SidebarSplit).id;
      final state = panes.state.resize(splitId, 0, 0.1);
      expect((state.tree as SidebarSplit).sizes.first, closeTo(0.6, 1e-9));
    });
  });

  group('expanded', () {
    test('toggleExpanded flips one directory', () {
      var state = SidebarState.initial().toggleExpanded('/w/lib');
      expect(state.expanded, {'/w/lib'});
      state = state.toggleExpanded('/w/lib');
      expect(state.expanded, isEmpty);
    });

    test('reveal expands the ancestors of a file, not the file', () {
      final state = SidebarState.initial().reveal(
        '/w',
        [p.join('/w', 'lib', 'sidebar', 'model', 'x.dart')],
      );
      expect(state.expanded, {
        '/w',
        '/w/lib',
        '/w/lib/sidebar',
        '/w/lib/sidebar/model',
      });
    });

    test('reveal stops at the root for a path outside it', () {
      final state = SidebarState.initial().reveal('/w', ['/elsewhere/x.dart']);
      // The loop must not walk to '/': the tree would then be asked to list
      // directories the workspace guard would refuse anyway.
      expect(state.expanded, {'/w'});
    });

    test('reveal returns the same state when nothing is new', () {
      final state = SidebarState.initial().reveal('/w', ['/w/lib/x.dart']);
      expect(identical(state.reveal('/w', ['/w/lib/x.dart']), state), isTrue);
    });
  });

  group('persistence', () {
    test('round-trips a split layout with tabs and expansion', () {
      var before = _twoPanes().state.toggleExpanded('/w/lib');
      before = before.openTerminal();
      final after = SidebarState.fromJson(before.toJson());
      expect(after.panes.length, before.panes.length);
      expect(after.tabs.map((tab) => tab.id), before.tabs.map((tab) => tab.id));
      expect(after.activePane, before.activePane);
      expect(after.expanded, before.expanded);
      expect(after.nextTerminal, before.nextTerminal);
      expect(after.nextId, before.nextId);
    });

    test('restores a diff tab\'s change identity', () {
      final ref = const CommitDiff(hashFull: 'abcdef1234', subject: 'fix it');
      final before = SidebarState.initial().openTab(SidebarTab.diff(ref));
      final after = SidebarState.fromJson(before.toJson());
      expect(after.tabs.single.diff, ref);
    });

    test('falls back to a fresh layout for junk', () {
      expect(SidebarState.fromJson(null).tabs, isEmpty);
      expect(SidebarState.fromJson(const {'tree': 5}).panes.length, 1);
    });

    test('re-points an activePane that names no surviving pane', () {
      final json = SidebarState.initial().openTab(_tab('a')).toJson();
      json['activePane'] = 'pane:404';
      final after = SidebarState.fromJson(json);
      expect(after.activePane, after.panes.first.id);
    });

    test('lifts nextId past every id in the tree', () {
      // A file whose counter disagrees with its tree: the source's maxCounterId
      // scan, but as a repair on the way in rather than a global to seed.
      final json = SidebarState.initial().openTab(_tab('a')).toJson();
      json['nextId'] = 1;
      (json['tree'] as Map)['id'] = 'pane:12';
      final after = SidebarState.fromJson(json);
      expect(after.nextId, 13);
      expect(after.activePane, 'pane:12');
    });

    test('separates two panes that were persisted sharing an id', () {
      final json = _twoPanes().state.toJson();
      final children = (json['tree'] as Map)['children'] as List;
      (children.last as Map)['id'] = (children.first as Map)['id'];
      final after = SidebarState.fromJson(json);
      expect(after.panes.map((pane) => pane.id).toSet().length, 2);
      // Both panes keep their own tabs — the symptom of the collision was that
      // one open landed in both.
      expect(after.tabs.map((tab) => tab.id), ['a', 'b']);
    });
  });
}
