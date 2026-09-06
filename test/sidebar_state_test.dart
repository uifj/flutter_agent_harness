// The state reducers: the gesture vocabulary of the workbench, driven as plain
// values. Anything that needs a widget tree belongs in workbench_ui_test.dart.

import 'package:agent_harness/model/sidebar_state.dart';
import 'package:agent_harness/model/sidebar_tab.dart';
import 'package:agent_harness/model/split_node.dart';
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

/// A layout with 'a' in the right column and 'b' in the bottom panel —
/// the two panels each holding one tab, the right one active.
({SidebarState state, String right, String bottom}) _twoPanels() {
  var state = SidebarState.initial().openTab(_tab('a'));
  final right = state.activePane;
  state = state.focusPane(state.bottomPanes.single.id).openTab(_tab('b'));
  final bottom = state.bottomPanes.single.id;
  // Right active again, so the openers' landing pane is unambiguous in the
  // assertions that follow.
  state = state.focusPane(right);
  return (state: state, right: right, bottom: bottom);
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
        bottomTree: panes.state.bottomTree,
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

  group('closeOtherTabs', () {
    test('keeps the named tab and shows it', () {
      var state = SidebarState.initial()
          .openTab(_tab('a'))
          .openTab(_tab('b'))
          .openTab(_tab('c'));
      final pane = state.activePane;
      // 'b' showing, 'a' kept — the kept tab wins the pane either way.
      state = state.activateTab(pane, 'b').closeOtherTabs(pane, 'a');
      expect(state.panes.single.tabs.map((tab) => tab.id), ['a']);
      expect(state.panes.single.active, 'a');
    });

    test('in a pane with siblings, collapses it to nothing but the kept tab', () {
      final panes = _twoPanes();
      final state = panes.state
          .openTab(_tab('c'))
          .closeOtherTabs(panes.right, 'c');
      // The right pane's other tab ('b') closed; the pane survives holding 'c'.
      expect(state.panes.length, 2);
      expect(state.paneOf('c')!.id, panes.right);
      expect(state.paneOf('c')!.tabs.map((tab) => tab.id), ['c']);
    });

    test('a keep-id the pane does not hold empties and collapses it', () {
      final panes = _twoPanes();
      final state = panes.state.closeOtherTabs(panes.right, 'z');
      expect(state.panes.length, 1);
      expect(state.panes.single.tabs.map((tab) => tab.id), ['a']);
    });

    test('a lone pane keeps its only tab as a no-op', () {
      final state = SidebarState.initial().openTab(_tab('a'));
      expect(
        identical(state.closeOtherTabs(state.activePane, 'a'), state),
        isTrue,
      );
    });

    test('works on the bottom tree\'s panes too', () {
      final panels = _twoPanels();
      var state = panels.state.focusPane(panels.bottom).openTab(_tab('c'));
      state = state.closeOtherTabs(panels.bottom, 'b');
      expect(state.bottomTabs.map((tab) => tab.id), ['b']);
      expect(state.bottomPanes.single.active, 'b');
    });
  });

  group('closeAllTabs', () {
    test('empties a lone pane in place', () {
      var state = SidebarState.initial()
          .openTab(_tab('a'))
          .openTab(_tab('b'));
      state = state.closeAllTabs(state.activePane);
      expect(state.panes.length, 1);
      expect(state.panes.single.tabs, isEmpty);
      expect(state.panes.single.active, isNull);
    });

    test('collapses a pane that has siblings', () {
      final panes = _twoPanes();
      final state = panes.state.closeAllTabs(panes.right);
      expect(state.panes.length, 1);
      expect(state.panes.single.tabs.map((tab) => tab.id), ['a']);
      expect(state.activePane, panes.left);
    });

    test('an already-empty pane is a no-op', () {
      final state = SidebarState.initial();
      expect(identical(state.closeAllTabs(state.activePane), state), isTrue);
    });

    test('works on the bottom tree\'s panes too', () {
      final panels = _twoPanels();
      final state = panels.state.closeAllTabs(panels.bottom);
      expect(state.bottomPanes.single.tabs, isEmpty);
      expect(state.activePane, panels.right);
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

  group('cross-panel moves', () {
    test('moveTab crosses panels: the tab leaves its tree for the other', () {
      final panels = _twoPanels();
      final state = panels.state.moveTab(
        panels.right,
        'a',
        panels.bottom,
      );
      expect(state.tabs, isEmpty);
      expect(state.bottomTabs.map((tab) => tab.id), ['b', 'a']);
      expect(state.panes.single.tabs, isEmpty);
      // The drop target becomes active, wherever it lives.
      expect(state.activePane, panels.bottom);
    });

    test('moveTab back works the same way in reverse', () {
      final panels = _twoPanels();
      final state = panels.state.moveTab(
        panels.bottom,
        'b',
        panels.right,
      );
      expect(state.bottomTabs, isEmpty);
      expect(state.tabs.map((tab) => tab.id), ['a', 'b']);
      expect(state.activePane, panels.right);
    });

    test('moveTabToEdge splits a pane of the OTHER tree', () {
      final panels = _twoPanels();
      final state = panels.state.moveTabToEdge(
        panels.right,
        'a',
        panels.bottom,
        DropZone.right,
      );
      expect(state.tabs, isEmpty);
      // The bottom tree went from one pane to a horizontal split; the tab is
      // alone in the trailing pane, which is now active.
      final split = state.bottomTree as SidebarSplit;
      expect(split.dir, SplitDirection.row);
      expect((split.children.last as SidebarLeaf).tabs.single.id, 'a');
      expect(state.activePane, split.children.last.id);
      expect(state.bottomPanes.length, 2);
    });

    test('the emptied source pane of a lone tree survives as an empty pane', () {
      final panels = _twoPanels();
      final state = panels.state.moveTab(panels.right, 'a', panels.bottom);
      // A tree always keeps somewhere to put the next tab.
      expect(state.panes.length, 1);
      expect(state.panes.single.tabs, isEmpty);
    });

    test('an open lands in the bottom pane while it is the active one', () {
      final panels = _twoPanels();
      final state = panels.state.focusPane(panels.bottom).openTab(_tab('c'));
      expect(state.bottomTabs.map((tab) => tab.id), ['b', 'c']);
      expect(state.tabs.map((tab) => tab.id), ['a']);
    });

    test('openTab dedupes across panels: the instance is focused, not copied', () {
      final panels = _twoPanels();
      final state = panels.state.openTab(_tab('b'));
      expect(state.bottomTabs.map((tab) => tab.id), ['b']);
      expect(state.activePane, panels.bottom);
    });

    test('moveTabToOtherTree stacks into the other tree\'s first pane', () {
      final panels = _twoPanels();
      final state = panels.state.moveTabToOtherTree(panels.right, 'a');
      expect(state.tabs, isEmpty);
      expect(state.bottomTabs.map((tab) => tab.id), ['b', 'a']);
      expect(state.activePane, panels.bottom);
    });

    test('closing the bottom pane the state points at re-points to the right column', () {
      // A pane only leaves the tree when it has siblings — closing the last
      // tab of a lone pane empties it in place, and the pointer stays valid.
      final panels = _twoPanels();
      var state = panels.state.focusPane(panels.bottom).splitPane(
        SplitDirection.row,
      );
      final fresh = state.bottomPanes.last.id;
      state = state.focusPane(fresh).openTab(_tab('c'));
      expect(state.bottomPanes.length, 2);

      state = state.closeTab(fresh, 'c');
      expect(state.bottomPanes.length, 1);
      // The removed pane was the active one; the pointer falls back to the
      // right column's first pane — the primary surface.
      expect(state.activePane, panels.right);
    });

    test('the layout round-trips with its bottom tree', () {
      final panels = _twoPanels();
      final back = SidebarState.fromJson(panels.state.toJson());
      expect(back.tabs.map((tab) => tab.id), ['a']);
      expect(back.bottomTabs.map((tab) => tab.id), ['b']);
      expect(back.activePane, panels.state.activePane);
    });

    test('a document with no bottom tree gets a fresh empty one', () {
      var state = SidebarState.initial().openTab(_tab('a'));
      // Strip the bottom tree, as a pre-dual-tree document would be.
      final legacy = SidebarState.fromJson({
        ...state.toJson()..remove('bottomTree'),
      });
      expect(legacy.tabs.map((tab) => tab.id), ['a']);
      expect(legacy.bottomTabs, isEmpty);
      expect(legacy.bottomPanes.length, 1);
      // And the fresh pane's id cannot collide with the right tree's.
      expect(legacy.bottomPanes.single.id == legacy.panes.single.id, isFalse);
    });

    test('a pane id shared by both trees is re-minted on load', () {
      // Hand-build the ambiguity: the same pane id in both trees. Loading must
      // repair it, or every operation would dispatch to the bottom tree.
      final state = SidebarState.fromJson({
        'tree': {'kind': 'leaf', 'id': 'pane:1', 'tabs': [], 'active': null},
        'bottomTree': {
          'kind': 'leaf',
          'id': 'pane:1',
          'tabs': [],
          'active': null,
        },
        'activePane': 'pane:1',
        'expanded': [],
        'nextTerminal': 1,
        'nextId': 1,
      });
      expect(state.panes.single.id, 'pane:1');
      expect(state.bottomPanes.single.id, isNot('pane:1'));
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

  group('mobile merge', () {
    test('moves the bottom tabs into the right tree\'s first leaf', () {
      final panels = _twoPanels();
      final merged = panels.state.migrateBottomTabs();

      expect(merged.bottomTabs, isEmpty);
      expect(merged.tabs.map((tab) => tab.id), ['a', 'b']);
      // The bottom tree keeps its structure — a re-widened desktop finds the
      // welcome card there, not a collapsed layout.
      expect(merged.bottomPanes, isNotEmpty);
      expect(merged.activePane, panels.right);
    });

    test('a split bottom tree contributes its tabs in tree order', () {
      final panels = _twoPanels();
      final split = panels.state.moveTabToEdge(
        panels.bottom,
        'b',
        panels.bottom,
        DropZone.right,
      );
      final merged = split.migrateBottomTabs();
      expect(merged.tabs.map((tab) => tab.id), ['a', 'b']);
      expect(merged.bottomPanes.every((pane) => pane.tabs.isEmpty), isTrue);
    });

    test('a right split still lands the tabs in its leftmost leaf', () {
      final panels = _twoPanels();
      final split = panels.state.moveTabToEdge(
        panels.right,
        'a',
        panels.right,
        DropZone.right,
      );
      final merged = split.migrateBottomTabs();
      expect(merged.panes.first.tabs.map((tab) => tab.id), ['a', 'b']);
    });

    test('is idempotent once the bottom is empty and unpointed', () {
      final panels = _twoPanels();
      final once = panels.state.migrateBottomTabs();
      expect(identical(once.migrateBottomTabs(), once), isTrue);
    });

    test('a stale activePane in the bottom tree is re-pointed alone', () {
      final panels = _twoPanels();
      // Empty the bottom without migrating: point activePane at a bottom pane
      // whose tabs have gone.
      final emptied = panels.state.moveTab(panels.bottom, 'b', panels.right);
      final stale = emptied.focusPane(panels.bottom);
      final merged = stale.migrateBottomTabs();
      expect(merged.activePane, merged.panes.first.id);
      expect(merged.tabs.map((tab) => tab.id), ['a', 'b']);
    });
  });

  group('free windows', () {
    // A viewport the default window comfortably fits in.
    const vw = 1200.0;
    const vh = 800.0;

    test('floatTab takes the tab out of its pane and centres a window', () {
      final before = SidebarState.initial().openTab(_tab('a')).openTab(
        _tab('b'),
      );
      final after = before.floatTab('a', 600, 400, vw, vh);

      expect(after.tabs.map((tab) => tab.id), ['b']);
      final float = after.floatWithTab('a')!;
      expect(float.tab.id, 'a');
      // Centred on the point, at the default size.
      expect(float.x, 600 - float.w / 2);
      expect(float.y, 400 - float.h / 2);
      expect(float.w, floatDefaultW);
    });

    test('floatTab collapses a pane it empties', () {
      final before = _twoPanes().state; // one tab per pane
      final after = before.floatTab('a', 600, 400, vw, vh);
      expect(after.panes.length, 1);
      expect(after.tabs.map((tab) => tab.id), ['b']);
    });

    test('floatTab on an unknown or floating tab is a strict no-op', () {
      final before = SidebarState.initial().openTab(_tab('a'));
      expect(identical(before.floatTab('nope', 1, 1, vw, vh), before), isTrue);
      final floated = before.floatTab('a', 600, 400, vw, vh);
      expect(
        identical(floated.floatTab('a', 50, 50, vw, vh), floated),
        isTrue,
      );
    });

    test('moveFloat clamps to the viewport', () {
      final before = SidebarState.initial()
          .openTab(_tab('a'))
          .floatTab('a', 600, 400, vw, vh);
      final float = before.floatWithTab('a')!;
      final after = before.moveFloat(float.id, -500, 9999, vw, vh);
      expect(after.floatWithTab('a')!.x, 0);
      expect(
        after.floatWithTab('a')!.y,
        vh - after.floatWithTab('a')!.h,
      );
    });

    test('resizeFloat anchors the top-left and floors the size', () {
      final before = SidebarState.initial()
          .openTab(_tab('a'))
          .floatTab('a', 100, 100, vw, vh);
      final float = before.floatWithTab('a')!;
      final after = before.resizeFloat(float.id, 40, 40, vw, vh);
      final resized = after.floatWithTab('a')!;
      expect(resized.w, floatMinW);
      expect(resized.h, floatMinH);
      expect(resized.x, float.x);
      expect(resized.y, float.y);
    });

    test('raiseFloat moves a window to the top; topmost is identity', () {
      var state = SidebarState.initial().openTab(_tab('a')).openTab(_tab('b'));
      state = state.floatTab('a', 100, 100, vw, vh);
      state = state.floatTab('b', 200, 200, vw, vh);
      expect(state.floats.map((float) => float.tab.id), ['a', 'b']);

      final first = state.floatWithTab('a')!;
      final raised = state.raiseFloat(first.id);
      expect(raised.floats.map((float) => float.tab.id), ['b', 'a']);
      expect(identical(raised.raiseFloat(first.id), raised), isTrue);
    });

    test('dockFloat returns the tab to a pane and activates it', () {
      var state = SidebarState.initial().openTab(_tab('a'));
      state = state.splitPane(SplitDirection.row);
      state = state.floatTab('a', 600, 400, vw, vh);
      expect(state.tabs, isEmpty);

      final float = state.floatWithTab('a')!;
      final docked = state.dockFloat(float.id);
      expect(docked.floats, isEmpty);
      final home = docked.paneOf('a')!;
      expect(home.tabs.single.id, 'a');
      expect(home.active, 'a');
    });

    test('openTab raises a floated tab instead of docking a second one', () {
      var state = SidebarState.initial().openTab(_tab('a'));
      state = state.floatTab('a', 600, 400, vw, vh);
      final reopened = state.openTab(_tab('a'));
      expect(reopened.tabs, isEmpty);
      expect(reopened.floats.single.tab.id, 'a');
    });

    test('patchTab reaches a floated tab', () {
      var state = SidebarState.initial().openTab(_tab('a'));
      state = state.floatTab('a', 600, 400, vw, vh);
      final patched = state.patchTab('a', title: 'Renamed');
      expect(patched.floats.single.tab.title, 'Renamed');
    });

    test('floats persist, and the counter lifts past a restored window id', () {
      final before = SidebarState.initial()
          .openTab(_tab('a'))
          .floatTab('a', 600, 400, vw, vh);
      final after = SidebarState.fromJson(before.toJson());
      expect(after.floats.single.tab.id, 'a');
      expect(after.floats.single.x, before.floats.single.x);

      // A mint right after restore cannot collide with the restored id.
      final minted = after.floatTab('a', 1, 1, 1, 1); // no-op: already floating
      expect(identical(minted, after), isTrue);
      var fresh = after.dockFloat(after.floats.single.id);
      fresh = fresh.floatTab('a', 600, 400, vw, vh);
      expect(
        fresh.floats.single.id,
        isNot(after.floats.single.id),
      );
    });
  });
}
