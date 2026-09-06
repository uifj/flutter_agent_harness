// One session's workbench layout, and every transition over it.
//
// A port of the state half of `DSH-better-sidebar/src/client/state.ts`. Every
// method here is a pure function of the receiver: no notifier, no store, no
// clock, so `test/sidebar_state_test.dart` drives the whole gesture vocabulary
// without a widget tree. The controller in `lib/state/` is the only
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
//   * `nextBrowser`. There is no embedded browser tab.
//   * `revealed`. The source keeps a transient highlight set; [reveal] here only
//     expands ancestors, because the highlight it drove was never persisted and
//     a highlight is the renderer's business.

import 'dart:math' as math;

import 'package:path/path.dart' as p;

import 'sidebar_tab.dart';
import 'split_node.dart';

/// Where a dragged tab lands on a pane: an edge splits, the centre merges.
enum DropZone { left, right, up, down, center }

/// The contract sizes for a free window — the source's `FLOAT_MIN` and
/// `FLOAT_DEFAULT` (`state.ts:127-134`).
const floatMinW = 320.0;
const floatMinH = 200.0;
const floatDefaultW = 390.0;
const floatDefaultH = 780.0;

/// One free window: a tab dragged out of the workbench, floating over the
/// conversation area at viewport coordinates.
///
/// The floats array's order IS the stacking order — the last window is the
/// topmost — which is why raising is a splice-to-end and nothing keeps a
/// separate z-index.
class FloatWindow {
  const FloatWindow({
    required this.id,
    required this.tab,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final String id;
  final SidebarTab tab;

  /// Viewport coordinates of the window's top-left corner.
  final double x;
  final double y;
  final double w;
  final double h;

  FloatWindow copyWith({
    SidebarTab? tab,
    double? x,
    double? y,
    double? w,
    double? h,
  }) => FloatWindow(
    id: id,
    tab: tab ?? this.tab,
    x: x ?? this.x,
    y: y ?? this.y,
    w: w ?? this.w,
    h: h ?? this.h,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'tab': tab.toJson(),
    'x': x,
    'y': y,
    'w': w,
    'h': h,
  };
}

/// The layout of one session's workbench: one tree per panel.
class SidebarState {
  const SidebarState({
    required this.tree,
    required this.bottomTree,
    required this.activePane,
    required this.expanded,
    required this.nextTerminal,
    required this.nextId,
    this.nextBrowser = 1,
    this.floats = const [],
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

  /// The number the next untitled browser tab is keyed by — the browser's own
  /// [nextTerminal], with the same monotonic-across-closes economy.
  final int nextBrowser;

  /// The free windows, in stacking order — the last is the topmost. A floated
  /// tab is OWNED by its window: it is in neither tree, so [paneOf] does not
  /// see it and every dedupe consults [floatWithTab] as well.
  final List<FloatWindow> floats;

  SidebarState copyWith({
    SplitNode? tree,
    SplitNode? bottomTree,
    String? activePane,
    Set<String>? expanded,
    int? nextTerminal,
    int? nextId,
    int? nextBrowser,
    List<FloatWindow>? floats,
  }) => SidebarState(
    tree: tree ?? this.tree,
    bottomTree: bottomTree ?? this.bottomTree,
    activePane: activePane ?? this.activePane,
    expanded: expanded ?? this.expanded,
    nextTerminal: nextTerminal ?? this.nextTerminal,
    nextId: nextId ?? this.nextId,
    nextBrowser: nextBrowser ?? this.nextBrowser,
    floats: floats ?? this.floats,
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
  /// every time, so terminals stack. A floated tab is raised rather than
  /// re-opened — it already has a window, and a second one would be a second
  /// answer to where the tab lives.
  SidebarState openTab(SidebarTab tab) {
    final existing = paneOf(tab.id);
    if (existing != null) return activateTab(existing.id, tab.id);
    final floated = floatWithTab(tab.id);
    if (floated != null) return raiseFloat(floated.id);
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

  /// Opens a fresh terminal tab in [paneId] rather than the active pane.
  ///
  /// The bottom panel's first expansion wants its terminal THERE, not wherever
  /// the user happened to have focus — `openTerminal` targets the active pane,
  /// which at that moment is usually a right-column pane the user was reading.
  SidebarState openTerminalIn(String paneId) {
    if (!allPanes.any((pane) => pane.id == paneId)) return openTerminal();
    final tab = SidebarTab(
      id: 'terminal:$nextTerminal',
      type: BuiltinTabType.terminal,
      title: 'Terminal $nextTerminal',
    );
    return _mapPane(
      paneId,
      (leaf) => leaf.copyWith(tabs: [...leaf.tabs, tab], active: tab.id),
    ).copyWith(activePane: paneId, nextTerminal: nextTerminal + 1);
  }

  /// Opens the single side-chat tab, or focuses it.
  SidebarState openSideChat() => openTab(SidebarTab.sidechat);

  /// Opens a browser tab at [url], or focuses the one already on it.
  SidebarState openBrowser(String url) => openTab(SidebarTab.browser(url));

  /// A fresh browser tab with no address yet — the `+` menu's browser entry
  /// has no url to derive an id from, and the tab's id must not change when
  /// one is typed.
  SidebarState openBrowserUntitled() {
    final tab = SidebarTab(
      id: 'browser:$nextBrowser',
      type: BuiltinTabType.browser,
      title: 'Browser',
    );
    return openTab(tab).copyWith(nextBrowser: nextBrowser + 1);
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

  /// Closes every tab of [paneId] but [keepId] — the strip's right-click
  /// "close others".
  ///
  /// The kept tab becomes the pane's visible one, wherever in the strip it was:
  /// the pane is about to hold it alone, so whatever showed before is going.
  SidebarState closeOtherTabs(String paneId, String keepId) {
    var emptied = false;
    final next = _mapPane(paneId, (leaf) {
      final keep = leaf.tabs.where((tab) => tab.id == keepId).toList();
      if (keep.length == leaf.tabs.length) return leaf;
      emptied = keep.isEmpty;
      return leaf.copyWith(tabs: keep, active: keep.isEmpty ? null : keep.last.id);
    });
    if (identical(next, this) || !emptied) return next;
    return next._withTrees(
      bottomTree: _isBottom(paneId)
          ? removeLeafAt(next.bottomTree, paneId)
          : next.bottomTree,
      tree: _isBottom(paneId) ? next.tree : removeLeafAt(next.tree, paneId),
    );
  }

  /// Closes every tab of [paneId] — the strip's right-click "close all". Same
  /// collapse rule as one close: an emptied pane leaves its tree when it has
  /// siblings, and stays as the welcome pane when it does not.
  SidebarState closeAllTabs(String paneId) {
    var emptied = false;
    final next = _mapPane(paneId, (leaf) {
      if (leaf.tabs.isEmpty) return leaf;
      emptied = true;
      return leaf.copyWith(tabs: const [], active: null, clearActive: true);
    });
    if (identical(next, this) || !emptied) return next;
    return next._withTrees(
      bottomTree: _isBottom(paneId)
          ? removeLeafAt(next.bottomTree, paneId)
          : next.bottomTree,
      tree: _isBottom(paneId) ? next.tree : removeLeafAt(next.tree, paneId),
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
    // The same patch reaches a floating window's tab — a retitled terminal
    // follows its window out of the pane.
    for (var i = 0; i < floats.length; i++) {
      if (floats[i].tab.id != tabId) continue;
      return copyWith(
        floats: [
          for (var j = 0; j < floats.length; j++)
            if (j == i)
              floats[j].copyWith(
                tab: floats[j].tab.copyWith(
                  title: title,
                  path: path,
                  meta: meta,
                ),
              )
            else
              floats[j],
        ],
      );
    }
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

  // --- Free windows ---

  /// The free window holding [tabId], or null.
  FloatWindow? floatWithTab(String tabId) {
    for (final float in floats) {
      if (float.tab.id == tabId) return float;
    }
    return null;
  }

  /// The free window with [floatId], or null.
  FloatWindow? floatById(String floatId) {
    for (final float in floats) {
      if (float.id == floatId) return float;
    }
    return null;
  }

  /// Geometry every free window is held to: the sizes never fall below the
  /// floors, and the window never leaves the viewport — a title bar stranded
  /// off-screen is a window the user cannot reach to drag back.
  static ({double x, double y, double w, double h}) _clampGeometry(
    double x,
    double y,
    double w,
    double h,
    double vw,
    double vh,
  ) {
    final width = math.min(math.max(w, floatMinW), math.max(floatMinW, vw));
    final height = math.min(math.max(h, floatMinH), math.max(floatMinH, vh));
    return (
      x: math.min(math.max(x, 0), math.max(0, vw - width)),
      y: math.min(math.max(y, 0), math.max(0, vh - height)),
      w: width,
      h: height,
    );
  }

  /// Floats [tabId]: removes it from its pane (an emptied pane collapses like
  /// any move) and appends a window centred on the drop point, default size
  /// clamped to the viewport. A fresh window is born topmost — the array's end.
  ///
  /// An unknown tab id, or one already floating, is a strict no-op.
  SidebarState floatTab(String tabId, double x, double y, double vw, double vh) {
    final source = paneOf(tabId);
    if (source == null) return this;
    final tab = source.tabs.firstWhere((candidate) => candidate.id == tabId);
    var emptied = false;
    final mapped = _mapPane(source.id, (leaf) {
      final tabs = [
        for (final candidate in leaf.tabs)
          if (candidate.id != tabId) candidate,
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
    final bottom = _isBottom(source.id);
    // The pane the user was working in may have just collapsed with the tab;
    // _withTrees re-points a stale active pane the same way closeTab does.
    final pruned = emptied
        ? mapped._withTrees(
            bottomTree: bottom
                ? removeLeafAt(mapped.bottomTree, source.id)
                : null,
            tree: bottom ? null : removeLeafAt(mapped.tree, source.id),
          )
        : mapped;

    // Phone-ratio default, capped to the viewport before centering so the
    // clamped position never leaves the window's bottom past the fold.
    final width = math.min(floatDefaultW, math.max(floatMinW, vw - 24));
    final height = math.min(floatDefaultH, math.max(floatMinH, vh - 24));
    final geo = _clampGeometry(
      x - width / 2,
      y - height / 2,
      width,
      height,
      vw,
      vh,
    );
    final minter = IdMinter(nextId);
    return pruned.copyWith(
      floats: [
        ...floats,
        FloatWindow(
          id: minter.mint('float'),
          tab: tab,
          x: geo.x,
          y: geo.y,
          w: geo.w,
          h: geo.h,
        ),
      ],
      nextId: minter.next,
    );
  }

  /// Moves a free window (clamped to the viewport); unknown ids are a no-op.
  SidebarState moveFloat(String floatId, double x, double y, double vw, double vh) {
    final float = floatById(floatId);
    if (float == null) return this;
    final geo = _clampGeometry(x, y, float.w, float.h, vw, vh);
    if (geo.x == float.x && geo.y == float.y) return this;
    return copyWith(
      floats: [
        for (final other in floats)
          if (other.id == floatId)
            other.copyWith(x: geo.x, y: geo.y)
          else
            other,
      ],
    );
  }

  /// Resizes a free window from its SE corner: the top-left stays anchored,
  /// sizes clamp to the floor and to the viewport's remaining room.
  SidebarState resizeFloat(String floatId, double w, double h, double vw, double vh) {
    final float = floatById(floatId);
    if (float == null) return this;
    final width = math.min(
      math.max(w, floatMinW),
      math.max(floatMinW, vw - float.x),
    );
    final height = math.min(
      math.max(h, floatMinH),
      math.max(floatMinH, vh - float.y),
    );
    if (width == float.w && height == float.h) return this;
    return copyWith(
      floats: [
        for (final other in floats)
          if (other.id == floatId)
            other.copyWith(w: width, h: height)
          else
            other,
      ],
    );
  }

  /// Brings a free window to the top. Already topmost (or the only window)
  /// returns the same reference — no persist churn on every click.
  SidebarState raiseFloat(String floatId) {
    if (floats.length < 2) return this;
    final index = floats.indexWhere((float) => float.id == floatId);
    if (index < 0 || index == floats.length - 1) return this;
    return copyWith(
      floats: [
        for (var i = 0; i < floats.length; i++)
          if (i != index) floats[i],
        floats[index],
      ],
    );
  }

  /// Docks a free window back into a pane (centre merge): the tab joins the
  /// target pane and activates. [toPane] defaults to the active pane.
  SidebarState dockFloat(String floatId, [String? toPane]) {
    final float = floatById(floatId);
    if (float == null) return this;
    var targetId = toPane ?? _target;
    if (!allPanes.any((pane) => pane.id == targetId)) {
      targetId = panes.first.id;
    }
    return _mapPane(targetId, (leaf) {
      // An already-docked tab with the same id keeps its pane: the dock is a
      // move, not a duplicate.
      if (leaf.tabs.any((tab) => tab.id == float.tab.id)) return leaf;
      return leaf.copyWith(tabs: [...leaf.tabs, float.tab], active: float.tab.id);
    }).copyWith(
      floats: [
        for (final other in floats)
          if (other.id != floatId) other,
      ],
      activePane: targetId,
    );
  }

  /// Closes the free window holding [tabId] — the tab closes WITH the window.
  SidebarState closeFloatByTab(String tabId) {
    if (!floats.any((float) => float.tab.id == tabId)) return this;
    return copyWith(
      floats: [
        for (final float in floats)
          if (float.tab.id != tabId) float,
      ],
    );
  }

  /// The mobile merge: every bottom-panel tab moves to the right tree's first
  /// leaf, the bottom tree is emptied, and [activePane] is re-pointed so the
  /// next open lands in the one visible panel.
  ///
  /// The migration is PERMANENT — going back to a wide viewport does not undo
  /// it. The tabs really live in the right tree now, so every gesture (close,
  /// activate, drag, dock) keeps working through the ordinary paths, and the
  /// bottom panel comes back as the empty welcome it was on a fresh session.
  ///
  /// Idempotent by construction: with nothing in the bottom tree and
  /// [activePane] not pointing into it, the receiver is returned untouched —
  /// which is what lets the caller run this on every breakpoint-crossing and
  /// session bind without converging loops.
  SidebarState migrateBottomTabs() {
    final bottomTabs = [
      for (final pane in bottomPanes) ...pane.tabs,
    ];
    final activeInBottom = _isBottom(activePane);
    if (bottomTabs.isEmpty && !activeInBottom) return this;

    final target = panes.first;
    var next = _mapPane(target.id, (leaf) {
      if (bottomTabs.isEmpty) return leaf;
      return leaf.copyWith(
        tabs: [...leaf.tabs, ...bottomTabs],
        active: leaf.active ?? bottomTabs.first.id,
      );
    });
    // The bottom tree keeps its structure and loses its tabs — a pane with no
    // tabs is the welcome card, which is exactly what a re-widened desktop
    // should find there.
    for (final pane in bottomPanes) {
      next = next._mapPane(pane.id, (leaf) {
        if (leaf.tabs.isEmpty) return leaf;
        return leaf.copyWith(tabs: const [], clearActive: true);
      });
    }
    return next.copyWith(activePane: target.id);
  }

  // --- Persistence ---

  Map<String, Object?> toJson() => {
    'tree': tree.toJson(),
    'bottomTree': bottomTree.toJson(),
    'activePane': activePane,
    'expanded': expanded.toList(),
    'nextTerminal': nextTerminal,
    'nextId': nextId,
    'nextBrowser': nextBrowser,
    if (floats.isNotEmpty) 'floats': [for (final float in floats) float.toJson()],
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
    final browser = raw['nextBrowser'];
    // The floats read back clamped, and their ids' numeric suffixes join the
    // counter lift so a restored window can never collide with a minted one.
    final floats = <FloatWindow>[];
    if (raw['floats'] case final List windowList) {
      for (final entry in windowList) {
        if (entry is! Map) continue;
        final id = entry['id'];
        final tab = SidebarTab.fromJson(entry['tab']);
        final xRaw = entry['x'];
        final yRaw = entry['y'];
        final wRaw = entry['w'];
        final hRaw = entry['h'];
        if (id is! String ||
            tab == null ||
            xRaw is! num ||
            yRaw is! num ||
            wRaw is! num ||
            hRaw is! num) {
          continue;
        }
        final suffix = int.tryParse(id.split(':').last);
        if (suffix != null) minter.lift(suffix + 1);
        floats.add(
          FloatWindow(
            id: id,
            tab: tab,
            x: xRaw.toDouble(),
            y: yRaw.toDouble(),
            w: wRaw.toDouble(),
            h: hRaw.toDouble(),
          ),
        );
      }
    }
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
      nextBrowser: browser is int && browser > 0 ? browser : 1,
      nextId: minter.next,
      floats: floats,
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
