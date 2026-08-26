// The split tree's pure operations. Everything here is plain function calls —
// no widgets, no filesystem — because that is the point of keeping the tree in
// its own file.

import 'package:agent_harness/sidebar/model/sidebar_tab.dart';
import 'package:agent_harness/sidebar/model/split_node.dart';
import 'package:flutter_test/flutter_test.dart';

SidebarTab _tab(String id) =>
    SidebarTab(id: id, type: BuiltinTabType.editor, title: id);

SidebarLeaf _leaf(String id, List<String> tabIds) => SidebarLeaf(
  id: id,
  tabs: [for (final tabId in tabIds) _tab(tabId)],
  active: tabIds.isEmpty ? null : tabIds.last,
);

void main() {
  group('IdMinter', () {
    test('mints sequentially and reports where to resume', () {
      final minter = IdMinter(3);
      expect(minter.mint('pane'), 'pane:3');
      expect(minter.mint('split'), 'split:4');
      expect(minter.next, 5);
    });
  });

  group('mapLeaf', () {
    test('replaces the matching leaf', () {
      final tree = _leaf('pane:1', ['a']);
      final next = mapLeaf(tree, 'pane:1', (leaf) => leaf.copyWith(active: 'a'));
      expect((next as SidebarLeaf).active, 'a');
    });

    test('returns the same instance when nothing matched', () {
      final tree = SidebarSplit(
        id: 'split:1',
        dir: SplitDirection.row,
        sizes: const [0.5, 0.5],
        children: [_leaf('pane:1', ['a']), _leaf('pane:2', ['b'])],
      );
      expect(identical(mapLeaf(tree, 'pane:9', (leaf) => leaf), tree), isTrue);
    });

    test('reaches a leaf nested two splits deep', () {
      final tree = SidebarSplit(
        id: 'split:1',
        dir: SplitDirection.row,
        sizes: const [0.5, 0.5],
        children: [
          _leaf('pane:1', ['a']),
          SidebarSplit(
            id: 'split:2',
            dir: SplitDirection.col,
            sizes: const [0.5, 0.5],
            children: [_leaf('pane:2', ['b']), _leaf('pane:3', ['c'])],
          ),
        ],
      );
      final next = mapLeaf(
        tree,
        'pane:3',
        (leaf) => leaf.copyWith(tabs: [...leaf.tabs, _tab('d')]),
      );
      expect(leafWithTab(next, 'd')!.id, 'pane:3');
      // Untouched branches keep their identity, which is what lets the widget
      // layer skip rebuilding them.
      expect(
        identical(
          (next as SidebarSplit).children.first,
          tree.children.first,
        ),
        isTrue,
      );
    });

    test('promotes a leaf into a split when visit returns one', () {
      final tree = _leaf('pane:1', ['a']);
      final next = mapLeaf(
        tree,
        'pane:1',
        (leaf) => SidebarSplit(
          id: 'split:1',
          dir: SplitDirection.row,
          sizes: const [0.5, 0.5],
          children: [leaf, SidebarLeaf.empty('pane:2')],
        ),
      );
      expect(next, isA<SidebarSplit>());
      expect(allLeaves(next).map((leaf) => leaf.id), ['pane:1', 'pane:2']);
    });
  });

  group('queries', () {
    final tree = SidebarSplit(
      id: 'split:1',
      dir: SplitDirection.col,
      sizes: const [0.5, 0.5],
      children: [
        _leaf('pane:1', ['a', 'b']),
        SidebarSplit(
          id: 'split:2',
          dir: SplitDirection.row,
          sizes: const [0.5, 0.5],
          children: [_leaf('pane:2', ['c']), _leaf('pane:3', [])],
        ),
      ],
    );

    test('treeHasId sees panes and splits alike', () {
      expect(treeHasId(tree, 'split:2'), isTrue);
      expect(treeHasId(tree, 'pane:3'), isTrue);
      expect(treeHasId(tree, 'pane:4'), isFalse);
    });

    test('firstLeaf walks down the leading edge', () {
      expect(firstLeaf(tree).id, 'pane:1');
    });

    test('allLeaves is in tree order', () {
      expect(allLeaves(tree).map((leaf) => leaf.id), [
        'pane:1',
        'pane:2',
        'pane:3',
      ]);
    });

    test('allSplits is in tree order', () {
      expect(allSplits(tree).map((split) => split.id), ['split:1', 'split:2']);
    });

    test('leafWithTab finds the owner, null for a stranger', () {
      expect(leafWithTab(tree, 'c')!.id, 'pane:2');
      expect(leafWithTab(tree, 'z'), isNull);
    });
  });

  group('splitLeafAt', () {
    test('replaces the pane with a split of it plus an empty pane', () {
      final minter = IdMinter(2);
      final next = splitLeafAt(
        _leaf('pane:1', ['a']),
        'pane:1',
        SplitDirection.row,
        minter,
      );
      final split = next as SidebarSplit;
      expect(split.dir, SplitDirection.row);
      expect(split.sizes, [0.5, 0.5]);
      expect(split.children.map((child) => child.id), ['pane:1', 'pane:2']);
      expect((split.children.last as SidebarLeaf).tabs, isEmpty);
    });

    test('burns the same ids whether or not the pane was found', () {
      final hit = IdMinter(1);
      splitLeafAt(_leaf('pane:1', ['a']), 'pane:1', SplitDirection.row, hit);
      final miss = IdMinter(1);
      splitLeafAt(_leaf('pane:1', ['a']), 'pane:9', SplitDirection.row, miss);
      // Deliberate: id consumption must not depend on the shape of the input,
      // or two clients replaying the same gestures would diverge.
      expect(miss.next, hit.next);
    });
  });

  group('insertLeafAt', () {
    test('places the new pane second when front is false', () {
      final minter = IdMinter(2);
      final (node, leafId) = insertLeafAt(
        _leaf('pane:1', ['a']),
        'pane:1',
        SplitDirection.col,
        _tab('b'),
        false,
        minter,
      );
      final split = node as SidebarSplit;
      expect(split.children.map((child) => child.id), ['pane:1', leafId]);
      expect((split.children.last as SidebarLeaf).active, 'b');
    });

    test('places the new pane first when front is true', () {
      final minter = IdMinter(2);
      final (node, leafId) = insertLeafAt(
        _leaf('pane:1', ['a']),
        'pane:1',
        SplitDirection.row,
        _tab('b'),
        true,
        minter,
      );
      expect((node as SidebarSplit).children.first.id, leafId);
    });
  });

  group('removeLeafAt', () {
    test('promotes the surviving child of a two-way split', () {
      final tree = SidebarSplit(
        id: 'split:1',
        dir: SplitDirection.row,
        sizes: const [0.5, 0.5],
        children: [_leaf('pane:1', ['a']), _leaf('pane:2', ['b'])],
      );
      final next = removeLeafAt(tree, 'pane:2');
      expect(next, isA<SidebarLeaf>());
      expect(next.id, 'pane:1');
    });

    test('redistributes the removed fraction across survivors', () {
      final tree = SidebarSplit(
        id: 'split:1',
        dir: SplitDirection.row,
        sizes: const [0.5, 0.25, 0.25],
        children: [
          _leaf('pane:1', ['a']),
          _leaf('pane:2', ['b']),
          _leaf('pane:3', ['c']),
        ],
      );
      final next = removeLeafAt(tree, 'pane:3') as SidebarSplit;
      expect(next.children.length, 2);
      // Not the source's behaviour: it leaves sizes summing to 0.75, and the
      // renderer hands the shortfall to the last pane on every frame.
      expect(next.sizes.reduce((a, b) => a + b), closeTo(1.0, 1e-9));
      expect(next.sizes.first, closeTo(2 / 3, 1e-9));
    });

    test('empties the only pane rather than deleting it', () {
      final next = removeLeafAt(_leaf('pane:1', ['a']), 'pane:1');
      expect(next.id, 'pane:1');
      expect((next as SidebarLeaf).tabs, isEmpty);
      expect(next.active, isNull);
    });

    test('reaches a pane nested inside another split', () {
      final tree = SidebarSplit(
        id: 'split:1',
        dir: SplitDirection.row,
        sizes: const [0.5, 0.5],
        children: [
          _leaf('pane:1', ['a']),
          SidebarSplit(
            id: 'split:2',
            dir: SplitDirection.col,
            sizes: const [0.5, 0.5],
            children: [_leaf('pane:2', ['b']), _leaf('pane:3', ['c'])],
          ),
        ],
      );
      final next = removeLeafAt(tree, 'pane:3') as SidebarSplit;
      expect(next.children.map((child) => child.id), ['pane:1', 'pane:2']);
    });
  });

  group('resizeSplit', () {
    final tree = SidebarSplit(
      id: 'split:1',
      dir: SplitDirection.row,
      sizes: const [0.5, 0.5],
      children: [_leaf('pane:1', ['a']), _leaf('pane:2', ['b'])],
    );

    test('moves the divider', () {
      final next = resizeSplit(tree, 'split:1', 0, 0.2) as SidebarSplit;
      expect(next.sizes, [closeTo(0.7, 1e-9), closeTo(0.3, 1e-9)]);
    });

    test('clamps so a pane cannot be dragged to nothing', () {
      final next = resizeSplit(tree, 'split:1', 0, 5.0) as SidebarSplit;
      expect(next.sizes.first, splitMaxFraction);
      expect(next.sizes.last, splitMinFraction);
    });

    test('ignores an out-of-range divider index', () {
      expect(resizeSplit(tree, 'split:1', 1, 0.2), tree);
      expect(resizeSplit(tree, 'split:1', -1, 0.2), tree);
    });
  });

  group('hydration', () {
    test('round-trips a nested tree', () {
      final tree = SidebarSplit(
        id: 'split:1',
        dir: SplitDirection.col,
        sizes: const [0.4, 0.6],
        children: [
          _leaf('pane:1', ['a', 'b']),
          _leaf('pane:2', ['c']),
        ],
      );
      final back = splitNodeFromJson(tree.toJson()) as SidebarSplit;
      expect(back.dir, SplitDirection.col);
      expect(back.sizes, [closeTo(0.4, 1e-9), closeTo(0.6, 1e-9)]);
      expect(allLeaves(back).map((leaf) => leaf.id), ['pane:1', 'pane:2']);
      expect(allLeaves(back).first.active, 'b');
    });

    test('rejects a node with no usable id', () {
      expect(splitNodeFromJson(const {'kind': 'leaf'}), isNull);
      expect(splitNodeFromJson('not a node'), isNull);
    });

    test('repairs an active id that names no tab', () {
      final leaf = splitNodeFromJson({
        'kind': 'leaf',
        'id': 'pane:1',
        'tabs': [_tab('a').toJson()],
        'active': 'gone',
      }) as SidebarLeaf;
      expect(leaf.active, 'a');
    });

    test('replaces a sizes list of the wrong length with equal fractions', () {
      final split = splitNodeFromJson({
        'kind': 'split',
        'id': 'split:1',
        'dir': 'row',
        'sizes': [0.5],
        'children': [
          _leaf('pane:1', ['a']).toJson(),
          _leaf('pane:2', ['b']).toJson(),
        ],
      }) as SidebarSplit;
      expect(split.sizes, [0.5, 0.5]);
    });

    test('collapses a split whose children did not survive', () {
      final node = splitNodeFromJson({
        'kind': 'split',
        'id': 'split:1',
        'dir': 'row',
        'sizes': [0.5, 0.5],
        'children': [
          _leaf('pane:1', ['a']).toJson(),
          const {'kind': 'leaf'},
        ],
      });
      expect(node, isA<SidebarLeaf>());
      expect(node!.id, 'pane:1');
    });

    test('drops a duplicated tab id inside one pane', () {
      final leaf = splitNodeFromJson({
        'kind': 'leaf',
        'id': 'pane:1',
        'tabs': [_tab('a').toJson(), _tab('a').toJson()],
        'active': 'a',
      }) as SidebarLeaf;
      expect(leaf.tabs.length, 1);
    });
  });

  group('maxCounterSuffix', () {
    test('spans pane, split and tab ids', () {
      final tree = SidebarSplit(
        id: 'split:7',
        dir: SplitDirection.row,
        sizes: const [0.5, 0.5],
        children: [_leaf('pane:2', ['tab:11']), _leaf('pane:3', [])],
      );
      expect(maxCounterSuffix(tree), 11);
    });

    test('ignores ids that are not counter ids', () {
      expect(maxCounterSuffix(_leaf('pane:1', ['editor:/tmp/x.dart'])), 1);
    });
  });

  group('mintTakenIds', () {
    test('re-mints the second pane sharing an id, keeping the first', () {
      // The state.ts:150-158 bug: mapLeaf would otherwise visit both panes and
      // every open would land in two places.
      final tree = SidebarSplit(
        id: 'split:1',
        dir: SplitDirection.row,
        sizes: const [0.5, 0.5],
        children: [_leaf('pane:1', ['a']), _leaf('pane:1', ['b'])],
      );
      final minter = IdMinter(9);
      final next = mintTakenIds(tree, <String>{}, minter);
      final ids = allLeaves(next).map((leaf) => leaf.id).toList();
      expect(ids.first, 'pane:1');
      expect(ids.last, 'pane:9');
      expect(ids.toSet().length, 2);
      expect(minter.next, 10);
    });

    test('leaves an already-unique tree untouched', () {
      final tree = _leaf('pane:1', ['a']);
      final minter = IdMinter(5);
      expect(identical(mintTakenIds(tree, <String>{}, minter), tree), isTrue);
      expect(minter.next, 5);
    });

    test('one shared set across two trees keeps their ids disjoint', () {
      // A pane id in both trees would make dispatch-by-id ambiguous — the
      // bottom tree would always win, whoever asked.
      final right = _leaf('pane:1', ['a']);
      final bottom = _leaf('pane:1', ['b']);
      final minter = IdMinter(3);
      final taken = <String>{};
      final dedupedRight = mintTakenIds(right, taken, minter);
      final dedupedBottom = mintTakenIds(bottom, taken, minter);
      expect(identical(dedupedRight, right), isTrue);
      expect((dedupedBottom as SidebarLeaf).id, 'pane:3');
      expect(minter.next, 4);
    });
  });

  group('takeTabFrom', () {
    test('removes the tab and reports the pane it emptied', () {
      final tree = _leaf('pane:1', ['a', 'b']);
      final taken = takeTabFrom(tree, 'pane:1', 'a');
      expect(taken, isNotNull);
      final (next, tab, emptied) = taken!;
      expect(tab.id, 'a');
      expect(emptied, isFalse);
      final leaf = next as SidebarLeaf;
      expect(leaf.tabs.map((t) => t.id), ['b']);
      // The pane's active tab hands over.
      expect(leaf.active, 'b');
    });

    test('reports the emptied pane but leaves it in place', () {
      // Collapsing is the caller's call: a move whose target is the same pane
      // must not.
      final tree = _leaf('pane:1', ['a']);
      final result = takeTabFrom(tree, 'pane:1', 'a')!;
      expect(result.$3, isTrue);
      expect((result.$1 as SidebarLeaf).tabs, isEmpty);
    });

    test('a pane not holding the tab is untouched', () {
      final tree = _leaf('pane:1', ['a']);
      expect(takeTabFrom(tree, 'pane:2', 'a'), isNull);
      expect(takeTabFrom(tree, 'pane:1', 'z'), isNull);
    });
  });

  group('moveTabBetweenTrees', () {
    test('stacks the tab into the target pane of the other tree', () {
      final from = _leaf('pane:1', ['a', 'b']);
      final to = _leaf('pane:2', ['c']);
      final moved = moveTabBetweenTrees(from, to, 'pane:1', 'b', 'pane:2');
      expect(moved, isNotNull);
      final (source, target) = moved!;
      expect((source as SidebarLeaf).tabs.map((t) => t.id), ['a']);
      expect((target as SidebarLeaf).tabs.map((t) => t.id), ['c', 'b']);
      expect(target.active, 'b');
    });

    test('the source pane collapses when the tab was its last', () {
      final from = _leaf('pane:1', ['a']);
      final to = _leaf('pane:2', ['c']);
      final (source, target) =
          moveTabBetweenTrees(from, to, 'pane:1', 'a', 'pane:2')!;
      expect((source as SidebarLeaf).tabs, isEmpty);
      expect((target as SidebarLeaf).tabs.map((t) => t.id), ['c', 'a']);
    });

    test('a missing target pane leaves both trees alone', () {
      final from = _leaf('pane:1', ['a']);
      final to = _leaf('pane:2', ['c']);
      expect(moveTabBetweenTrees(from, to, 'pane:1', 'a', 'pane:9'), isNull);
    });
  });

  group('moveTabBetweenTreesToEdge', () {
    test('lands the tab alone in a fresh pane of the other tree', () {
      final from = _leaf('pane:1', ['a', 'b']);
      final to = _leaf('pane:2', ['c']);
      final minter = IdMinter(7);
      final moved = moveTabBetweenTreesToEdge(
        from,
        to,
        'pane:1',
        'b',
        'pane:2',
        SplitDirection.row,
        false,
        minter,
      );
      expect(moved, isNotNull);
      final (source, target, fresh) = moved!;
      expect((source as SidebarLeaf).tabs.map((t) => t.id), ['a']);
      // The target tree split into [old, fresh]; the tab is alone in the fresh.
      final split = target as SidebarSplit;
      expect(split.dir, SplitDirection.row);
      expect((split.children.last as SidebarLeaf).tabs.single.id, 'b');
      expect(fresh, split.children.last.id);
      expect(minter.next, 9); // one pane, one split
    });
  });
}
