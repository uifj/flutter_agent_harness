// One session's workbench layout, and every transition over it.
//
// A port of the state half of `DSH-better-sidebar/src/client/state.ts`. Every
// method here is a pure function of the receiver: no notifier, no store, no
// clock, so `test/sidebar_state_test.dart` drives the whole gesture vocabulary
// without a widget tree. The controller in `lib/sidebar/state/` is the only
// thing that owns one of these and the only thing that knows time exists.
//
// The state holds TWO trees — the right column's ([tree]) and the bottom
// panel's ([bottomTree]) — exactly as the source's `splits` / `bottomSplits`
// pair. Both mint their pane ids from one shared counter, so an id names a pane
// in at most one tree and every operation can dispatch by lookup alone (the
// source's `treeOf`); the drag gestures therefore need to know nothing about
// which panel a drop crosses.
//
// [activePane] is a single global, as in the source: the last pane the user
// touched, in either tree, receives new tabs. Which tree a pane lives in is
// derived, never stored.
//
// What the source has and this does not:
//
//   * `panelOpen` / `width` / `bottomOpen` / `bottomHeight`. `LayoutController`
//     owns the whole app's panel widths and openness, and a second copy would be
//     a second answer to the same question — the one that loses whenever the two
//     disagree is whichever the widget happens to read.
//   * `floats` / `nextBrowser`. There is no free-floating window and no embedded
//     browser tab.
//   * `revealed`. The source keeps a transient highlight set; [reveal] here only
//     expands ancestors, because the highlight it drove was never persisted and
//     a highlight is the renderer's business.

import 'package:path/path.dart' as p;

import 'sidebar_tab.dart';
import 'split_node.dart';

/// Where a dragged tab lands on a pane: an edge splits, the centre merges.
enum DropZone { left, right, up, down, center }

/// The layout of one session's workbench: one tree per panel.
class SidebarState {
  const SidebarState({
    required this.tree,
    required this.bottomTree,
    required this.activePane,
    required this.expanded,
    required this.nextTerminal,
    required this.nextId,
  });

  /// A fresh workbench: one empty pane per panel, each showing its welcome
  /// content.
  ///
  /// Seeded empty rather than with a file tree tab, unlike the source's
  /// `editor-home`: the workbench opens beside a conversation whose first act is
  /// usually to open something, and a tab the user did not ask for would be one
  /// they have to close.
  factory SidebarState.initial() {
    final minter = IdMinter(1);
    final pane = SidebarLeaf.empty(minter.mint('pane'));
    final bottomPane = SidebarLeaf.empty(minter.mint('pane'));
    return SidebarState(
      tree: pane,
      bottomTree: bottomPane,
      activePane: pane.id,
      expanded: const {},
      nextTerminal: 1,
      nextId: minter.next,
    );
  }

  /// The right column's tree.
  final SplitNode tree;

  /// The bottom panel's tree. Its panes and the right column's never share ids
  /// (one minter), which is what lets every operation below dispatch by lookup.
  final SplitNode bottomTree;

  /// The pane a new tab lands in — the last pane the user touched, in either
  /// tree. May be stale — a pane can be closed without this being updated by a
  /// reducer that did not need to look — so every read goes through [_target].
  final String activePane;

  /// Absolute paths of the directories the file tree shows expanded.
  final Set<String> expanded;

  /// The number the next terminal tab is named and keyed by. Monotonic even
  /// across closes, so a closed "Terminal 2" does not have its name and its pty
  /// session key handed to a different shell.
  final int nextTerminal;

  /// The counter [IdMinter] resumes from. See `split_node.dart`'s header for why
  /// this lives in the state rather than in a global.
  final int nextId;

  SidebarState copyWith({
    SplitNode? tree,
    SplitNode? bottomTree,
    String? activePane,
    Set<String>? expanded,
    int? nextTerminal,
    int? nextId,
  }) => SidebarState(
    tree: tree ?? this.tree,
    bottomTree: bottomTree ?? this.bottomTree,
    activePane: activePane ?? this.activePane,
    expanded: expanded ?? this.expanded,
    nextTerminal: nextTerminal ?? this.nextTerminal,
    nextId: nextId ?? this.nextId,
  );

  /// The right column's panes, in tree order.
  List<SidebarLeaf> get panes => allLeaves(tree);

  /// The bottom panel's panes, in tree order.
  List<SidebarLeaf> get bottomPanes => allLeaves(bottomTree);

  /// Every pane of both panels — one flat namespace of unique ids.
  List<SidebarLeaf> get allPanes => [...panes, ...bottomPanes];

  /// The right column's open tabs, in tree order.
  List<SidebarTab> get tabs => [
    for (final pane in panes) ...pane.tabs,
  ];

  /// The bottom panel's open tabs, in tree order.
  List<SidebarTab> get bottomTabs => [
    for (final pane in bottomPanes) ...pane.tabs,
  ];

  /// The pane holding [tabId], in either tree, or null.
  SidebarLeaf? paneOf(String tabId) {
    for (final leaf in allPanes) {
      if (leaf.tabs.any((tab) => tab.id == tabId)) return leaf;
    }
    return null;
  }

  /// The open tab with [tabId], in either tree, or null.
  SidebarTab? tabById(String tabId) {
    for (final pane in allPanes) {
      for (final tab in pane.tabs) {
        if (tab.id == tabId) return tab;
      }
    }
    return null;
  }

  /// Whether [paneId] names a node of the bottom tree — the dispatch every
  /// pane-addressed operation starts with. An id in neither tree reads as the
  /// right column's, where tree operations no-op on a missing node.
  bool _isBottom(String paneId) => treeHasId(bottomTree, paneId);

  /// [activePane] if it still names a pane of either tree, else the right
  /// column's first pane.
  ///
  /// A stale active pane must not swallow an open — the source's
  /// `state.ts:559-564` note. Resolving it on read rather than repairing it on
  /// close means no reducer has to remember to.
  String get _target {
    for (final leaf in allPanes) {
      if (leaf.id == activePane) return leaf.id;
    }
    return panes.first.id;
  }

  /// Applies [visit] to the pane [paneId] in whichever tree holds it, passing
  /// the other tree through untouched. Returns the same instance when nothing
  /// matched, so callers keep their no-op-by-identity checks.
  SidebarState _mapPane(String paneId, SplitNode Function(SidebarLeaf) visit) {
    if (_isBottom(paneId)) {
      final next = mapLeaf(bottomTree, paneId, visit);
      return identical(next, bottomTree) ? this : copyWith(bottomTree: next);
    }
    final next = mapLeaf(tree, paneId, visit);
    return identical(next, tree) ? this : copyWith(tree: next);
  }

  // --- Tab lifecycle ---

  /// Lands [tab] in the active pane, or focuses the instance already open under
  /// the same id.
  ///
  /// The id check is the dedupe: `SidebarTab.editor` derives its id from the
  /// path, so opening one file twice focuses; `openTerminal` mints a fresh id
  /// every time, so terminals stack.
  SidebarState openTab(SidebarTab tab) {
    final existing = paneOf(tab.id);
    if (existing != null) return activateTab(existing.id, tab.id);
    final target = _target;
    return _mapPane(
      target,
      (leaf) => leaf.copyWith(tabs: [...leaf.tabs, tab], active: tab.id),
    ).copyWith(activePane: target);
  }

  /// Opens a fresh terminal tab, numbered from [nextTerminal].
  SidebarState openTerminal() {
    final tab = SidebarTab(
      id: 'terminal:$nextTerminal',
      type: BuiltinTabType.terminal,
      title: 'Terminal $nextTerminal',
    );
    return openTab(tab).copyWith(nextTerminal: nextTerminal + 1);
  }

  /// Closes [tabId] in [paneId]; a pane emptied by it is removed, unless it is
  /// its tree's only one.
  SidebarState closeTab(String paneId, String tabId) {
    var emptied = false;
    final next = _mapPane(paneId, (leaf) {
      if (!leaf.tabs.any((tab) => tab.id == tabId)) return leaf;
      final tabs = [
        for (final tab in leaf.tabs)
          if (tab.id != tabId) tab,
      ];
      emptied = tabs.isEmpty;
      return leaf.copyWith(
        tabs: tabs,
        active: leaf.active == tabId
            ? (tabs.isEmpty ? null : tabs.last.id)
            : leaf.active,
        clearActive: leaf.active == tabId && tabs.isEmpty,
      );
    });
    if (identical(next, this) || !emptied) return next;
    return next._withTrees(
      bottomTree: _isBottom(paneId)
          ? removeLeafAt(next.bottomTree, paneId)
          : next.bottomTree,
      tree: _isBottom(paneId)
          ? next.tree
          : removeLeafAt(next.tree, paneId),
    );
  }

  /// Makes [tabId] the visible tab of [paneId], and that pane active.
  SidebarState activateTab(String paneId, String tabId) =>
      _mapPane(
        paneId,
        (leaf) => leaf.tabs.any((tab) => tab.id == tabId)
            ? leaf.copyWith(active: tabId)
            : leaf,
      ).copyWith(activePane: paneId);

  /// Makes [paneId] the pane the next tab lands in.
  ///
  /// [activateTab] covers the usual case, but a pane with no tabs has none to
  /// activate, and clicking its welcome content still has to aim the next open
  /// at it. An unknown pane is a no-op rather than a stale pointer.
  SidebarState focusPane(String paneId) =>
      allPanes.any((pane) => pane.id == paneId)
          ? copyWith(activePane: paneId)
          : this;

  /// Rewrites the display fields of one open tab without reopening it.
  ///
  /// This is how a tab persists its own view state: an editor records the file
  /// it was retargeted to, a terminal its title. A missing [tabId] is a no-op.
  SidebarState patchTab(
    String tabId, {
    String? title,
    String? path,
    Map<String, Object?>? meta,
  }) {
    SplitNode? patch(SplitNode node) {
      var changed = false;
      SplitNode walk(SplitNode current) {
        switch (current) {
          case SidebarLeaf():
            if (!current.tabs.any((tab) => tab.id == tabId)) return current;
            changed = true;
            return current.copyWith(
              tabs: [
                for (final tab in current.tabs)
                  if (tab.id == tabId)
                    tab.copyWith(title: title, path: path, meta: meta)
                  else
                    tab,
              ],
            );
          case SidebarSplit():
            return current.copyWith(
              children: [for (final child in current.children) walk(child)],
            );
        }
      }

      final next = walk(node);
      return changed ? next : null;
    }

    final right = patch(tree);
    if (right != null) return copyWith(tree: right);
    final bottom = patch(bottomTree);
    if (bottom != null) return copyWith(bottomTree: bottom);
    return this;
  }

  // --- Layout gestures ---

  /// Splits the active pane, leaving the new pane empty.
  SidebarState splitPane(SplitDirection dir) {
    final minter = IdMinter(nextId);
    final target = _target;
    return copyWith(
      tree: _isBottom(target)
          ? tree
          : splitLeafAt(tree, target, dir, minter),
      bottomTree: _isBottom(target)
          ? splitLeafAt(bottomTree, target, dir, minter)
          : bottomTree,
      nextId: minter.next,
    );
  }

  /// Moves [tabId] from [fromPane] into [toPane] at [index] (-1 appends).
  ///
  /// The panes may live in different trees — dragging a tab between the two
  /// panels: the tab then leaves its own tree and lands in the other one, which
  /// is the source's own reading of this gesture (`state.ts:587-631`). The
  /// [index] is a position within the target strip; a cross-panel drop appends.
  ///
  /// Reordering inside one pane is the same operation with `fromPane == toPane`,
  /// which is why the removal leaves an emptied pane in place: the index the
  /// drop reported is an index into the list without the dragged tab.
  SidebarState moveTab(
    String fromPane,
    String tabId,
    String toPane, [
    int index = -1,
  ]) {
    final source = paneOf(tabId);
    if (source == null || source.id != fromPane) return this;
    final fromBottom = _isBottom(fromPane);

    if (fromBottom != _isBottom(toPane)) {
      // Cross-panel: remove from one tree, append into the other. The source
      // pane collapses when emptied — its target is in the other tree, so
      // collapsing can never take the drop target with it.
      final moved = moveTabBetweenTrees(
        fromBottom ? bottomTree : tree,
        fromBottom ? tree : bottomTree,
        fromPane,
        tabId,
        toPane,
      );
      if (moved == null) return this;
      return _withTrees(
        tree: fromBottom ? moved.$2 : moved.$1,
        bottomTree: fromBottom ? moved.$1 : moved.$2,
      ).copyWith(activePane: toPane);
    }

    final taken = takeTabFrom(fromBottom ? bottomTree : tree, fromPane, tabId);
    if (taken == null) return this;
    var (next, moved, emptied) = taken;
    // An emptied source pane collapses — but not when it is the drop target
    // itself, or the reorder would delete the pane it is reordering.
    if (emptied && fromPane != toPane) next = removeLeafAt(next, fromPane);
    next = mapLeaf(next, toPane, (leaf) {
      final at = index >= 0 && index <= leaf.tabs.length
          ? index
          : leaf.tabs.length;
      return leaf.copyWith(
        tabs: [...leaf.tabs.take(at), moved, ...leaf.tabs.skip(at)],
        active: moved.id,
      );
    });
    return (fromBottom ? copyWith(bottomTree: next) : copyWith(tree: next))
        .copyWith(activePane: toPane);
  }

  /// The VSCode drag gesture: [zone] `center` merges [tabId] into [toPane], an
  /// edge splits [toPane] with the tab alone in the new pane. The panes may
  /// live in different trees — see [moveTab].
  SidebarState moveTabToEdge(
    String fromPane,
    String tabId,
    String toPane,
    DropZone zone,
  ) {
    if (fromPane == toPane && zone == DropZone.center) {
      // Dropped back on its own pane: read as "move to the end".
      return moveTab(fromPane, tabId, toPane);
    }
    if (zone == DropZone.center) return moveTab(fromPane, tabId, toPane);
    final source = paneOf(tabId);
    if (source == null || source.id != fromPane) return this;
    final fromBottom = _isBottom(fromPane);
    final dir = zone == DropZone.left || zone == DropZone.right
        ? SplitDirection.row
        : SplitDirection.col;
    final front = zone == DropZone.left || zone == DropZone.up;

    if (fromBottom != _isBottom(toPane)) {
      final minter = IdMinter(nextId);
      final moved = moveTabBetweenTreesToEdge(
        fromBottom ? bottomTree : tree,
        fromBottom ? tree : bottomTree,
        fromPane,
        tabId,
        toPane,
        dir,
        front,
        minter,
      );
      if (moved == null) return this;
      return _withTrees(
        tree: fromBottom ? moved.$2 : moved.$1,
        bottomTree: fromBottom ? moved.$1 : moved.$2,
      ).copyWith(activePane: moved.$3, nextId: minter.next);
    }

    final taken = takeTabFrom(fromBottom ? bottomTree : tree, fromPane, tabId);
    if (taken == null) return this;
    var (next, moved, emptied) = taken;
    // Dragging a pane's last tab to that same pane's edge is a no-op the source
    // does not special-case: removing the pane would take the drop target with
    // it. Nothing about the layout changes, so return unchanged.
    if (emptied && fromPane == toPane) return this;
    if (emptied) next = removeLeafAt(next, fromPane);
    final minter = IdMinter(nextId);
    final result = insertLeafAt(next, toPane, dir, moved, front, minter);
    return (fromBottom
            ? copyWith(bottomTree: result.$1)
            : copyWith(tree: result.$1))
        .copyWith(activePane: result.$2, nextId: minter.next);
  }

  /// The keyboard-reachable twin of the cross-panel drag: [tabId] leaves its
  /// tree and stacks into the other tree's first pane.
  ///
  /// The header buttons call this so a tab can change panels without a pointer —
  /// the drag already covers the rest.
  SidebarState moveTabToOtherTree(String fromPane, String tabId) {
    final source = paneOf(tabId);
    if (source == null || source.id != fromPane) return this;
    final target = _isBottom(fromPane) ? firstLeaf(tree) : firstLeaf(bottomTree);
    return moveTab(fromPane, tabId, target.id);
  }

  /// Opens a diff tab the way VSCode does.
  ///
  /// Three cases, in order: an open tab for the same change is focused; else the
  /// tab joins the first pane that already holds diffs — in either tree, since a
  /// run of clicks should stack wherever the diffs already live; else the first
  /// diff of a layout splits [sourcePaneId] downwards and lands below it.
  SidebarState openDiffTab(String sourcePaneId, SidebarTab tab) {
    final existing = paneOf(tab.id);
    if (existing != null) return activateTab(existing.id, tab.id);
    for (final pane in allPanes) {
      if (pane.tabs.any((open) => open.type == BuiltinTabType.diff)) {
        return _mapPane(
          pane.id,
          (leaf) => leaf.copyWith(tabs: [...leaf.tabs, tab], active: tab.id),
        ).copyWith(activePane: pane.id);
      }
    }
    if (!allPanes.any((pane) => pane.id == sourcePaneId)) return openTab(tab);
    final bottom = _isBottom(sourcePaneId);
    final minter = IdMinter(nextId);
    final result = insertLeafAt(
      bottom ? bottomTree : tree,
      sourcePaneId,
      SplitDirection.col,
      tab,
      false,
      minter,
    );
    return (bottom
            ? copyWith(bottomTree: result.$1)
            : copyWith(tree: result.$1))
        .copyWith(activePane: result.$2, nextId: minter.next);
  }

  /// Moves the divider at [index] of split [splitId] by [delta] fractions.
  SidebarState resize(String splitId, int index, double delta) => _isBottom(splitId)
      ? copyWith(bottomTree: resizeSplit(bottomTree, splitId, index, delta))
      : copyWith(tree: resizeSplit(tree, splitId, index, delta));

  // --- File tree ---

  /// Flips one directory's expansion.
  SidebarState toggleExpanded(String path) => copyWith(
    expanded: expanded.contains(path)
        ? {
            for (final open in expanded)
              if (open != path) open,
          }
        : {...expanded, path},
  );

  /// Expands one directory, idempotently — the half of [toggleExpanded] a caller
  /// that knows which way it wants it needs.
  SidebarState expand(String path) =>
      expanded.contains(path) ? this : copyWith(expanded: {...expanded, path});

  /// Expands every directory between [root] and each of [paths], so a lazily
  /// built tree actually renders the rows leading to them.
  ///
  /// The files themselves are not added: a file is not a directory, and an
  /// expanded set holding one would ask the tree to list it.
  SidebarState reveal(String root, Iterable<String> paths) {
    final next = {...expanded};
    for (final path in paths) {
      var dir = p.dirname(path);
      // Bounded by root so a path outside the workspace cannot walk to `/`,
      // and by the fixed point of dirname so an unrooted one still terminates.
      while (p.isWithin(root, dir)) {
        if (!next.add(dir)) break;
        final parent = p.dirname(dir);
        if (parent == dir) break;
        dir = parent;
      }
      next.add(root);
    }
    return next.length == expanded.length ? this : copyWith(expanded: next);
  }

  // --- Persistence ---

  Map<String, Object?> toJson() => {
    'tree': tree.toJson(),
    'bottomTree': bottomTree.toJson(),
    'activePane': activePane,
    'expanded': expanded.toList(),
    'nextTerminal': nextTerminal,
    'nextId': nextId,
  };

  /// Reads a layout back, falling back to [SidebarState.initial] for anything
  /// that does not read as one.
  ///
  /// The hydration does two repairs the writer cannot: duplicate node ids are
  /// re-minted (see `mintTakenIds` — the bug `state.ts:150-158` describes), and
  /// [nextId] is lifted past every id actually present, so a file whose counter
  /// disagrees with its tree cannot hand out an id already in use. A document
  /// with no `bottomTree` (written before there were two) gets a fresh empty
  /// one.
  static SidebarState fromJson(Object? raw) {
    if (raw is! Map) return SidebarState.initial();
    final tree = splitNodeFromJson(raw['tree']);
    if (tree == null) return SidebarState.initial();
    final bottomRaw = splitNodeFromJson(raw['bottomTree']);
    final persisted = raw['nextId'];
    final minter = IdMinter(
      [
        persisted is int ? persisted : 1,
        maxCounterSuffix(tree) + 1,
        if (bottomRaw != null) maxCounterSuffix(bottomRaw) + 1,
      ].reduce((a, b) => a > b ? a : b),
    );
    // One taken-set across both trees: a pane id in both would make the
    // dispatch ambiguous, so the second tree re-mints the clash.
    final taken = <String>{};
    final right = mintTakenIds(tree, taken, minter);
    final bottom = bottomRaw == null
        ? SidebarLeaf.empty(minter.mint('pane'))
        : mintTakenIds(bottomRaw, taken, minter);
    final leaves = [...allLeaves(right), ...allLeaves(bottom)];
    final active = raw['activePane'];
    final terminal = raw['nextTerminal'];
    return SidebarState(
      tree: right,
      bottomTree: bottom,
      activePane: active is String && leaves.any((leaf) => leaf.id == active)
          ? active
          : allLeaves(right).first.id,
      expanded: {
        if (raw['expanded'] case final List paths)
          for (final path in paths)
            if (path is String) path,
      },
      nextTerminal: terminal is int && terminal > 0 ? terminal : 1,
      nextId: minter.next,
    );
  }

  /// One tree replaced, with [activePane] re-pointed when the pane it named is
  /// gone from both trees — it is a global, so either tree losing it matters.
  ///
  /// The fallback is the right column's first pane: the primary surface, and
  /// the one a fresh layout starts on.
  SidebarState _withTrees({SplitNode? tree, SplitNode? bottomTree}) {
    final nextTree = tree ?? this.tree;
    final nextBottom = bottomTree ?? this.bottomTree;
    final stillThere =
        treeHasId(nextTree, activePane) || treeHasId(nextBottom, activePane);
    return copyWith(
      tree: nextTree,
      bottomTree: nextBottom,
      activePane: stillThere ? activePane : firstLeaf(nextTree).id,
    );
  }
}
