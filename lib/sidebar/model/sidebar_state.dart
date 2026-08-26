// One session's workbench layout, and every transition over it.
//
// A port of the state half of `DSH-better-sidebar/src/client/state.ts`. Every
// method here is a pure function of the receiver: no notifier, no store, no
// clock, so `test/sidebar_state_test.dart` drives the whole gesture vocabulary
// without a widget tree. The controller in `lib/sidebar/state/` is the only
// thing that owns one of these and the only thing that knows time exists.
//
// What the source has and this does not:
//
//   * `panelOpen` / `width`. `LayoutController` already owns the details
//     column's width and openness for the whole app, and a second copy would be
//     a second answer to the same question — the one that loses whenever the two
//     disagree is whichever the widget happens to read.
//   * `bottomSplits` / `floats` / `nextBrowser`. There is no bottom panel and no
//     free-floating window in a single-column details pane, and no embedded
//     browser tab. `treeOf` goes with them: with one tree there is nothing to
//     dispatch between.
//   * `revealed`. The source keeps a transient highlight set; [reveal] here only
//     expands ancestors, because the highlight it drove was never persisted and
//     a highlight is the renderer's business.

import 'package:path/path.dart' as p;

import 'sidebar_tab.dart';
import 'split_node.dart';

/// Where a dragged tab lands on a pane: an edge splits, the centre merges.
enum DropZone { left, right, up, down, center }

/// The layout of one session's workbench.
class SidebarState {
  const SidebarState({
    required this.tree,
    required this.activePane,
    required this.expanded,
    required this.nextTerminal,
    required this.nextId,
  });

  /// A fresh workbench: one empty pane, showing its welcome content.
  ///
  /// Seeded empty rather than with a file tree tab, unlike the source's
  /// `editor-home`: the workbench opens beside a conversation whose first act is
  /// usually to open something, and a tab the user did not ask for would be one
  /// they have to close.
  factory SidebarState.initial() {
    final minter = IdMinter(1);
    final pane = SidebarLeaf.empty(minter.mint('pane'));
    return SidebarState(
      tree: pane,
      activePane: pane.id,
      expanded: const {},
      nextTerminal: 1,
      nextId: minter.next,
    );
  }

  final SplitNode tree;

  /// The pane a new tab lands in. May be stale — a pane can be closed without
  /// this being updated by a reducer that did not need to look — so every read
  /// goes through [_target].
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
    String? activePane,
    Set<String>? expanded,
    int? nextTerminal,
    int? nextId,
  }) => SidebarState(
    tree: tree ?? this.tree,
    activePane: activePane ?? this.activePane,
    expanded: expanded ?? this.expanded,
    nextTerminal: nextTerminal ?? this.nextTerminal,
    nextId: nextId ?? this.nextId,
  );

  /// Every pane, in tree order.
  List<SidebarLeaf> get panes => allLeaves(tree);

  /// Every open tab, in tree order.
  List<SidebarTab> get tabs => [
    for (final pane in panes) ...pane.tabs,
  ];

  /// The pane holding [tabId], or null.
  SidebarLeaf? paneOf(String tabId) => leafWithTab(tree, tabId);

  /// The open tab with [tabId], or null.
  SidebarTab? tabById(String tabId) {
    for (final pane in panes) {
      for (final tab in pane.tabs) {
        if (tab.id == tabId) return tab;
      }
    }
    return null;
  }

  /// [activePane] if it still names a pane, else the first pane.
  ///
  /// A stale active pane must not swallow an open — the source's
  /// `state.ts:559-564` note. Resolving it on read rather than repairing it on
  /// close means no reducer has to remember to.
  String get _target {
    final leaves = panes;
    for (final leaf in leaves) {
      if (leaf.id == activePane) return leaf.id;
    }
    return leaves.first.id;
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
    return copyWith(
      activePane: target,
      tree: mapLeaf(
        tree,
        target,
        (leaf) => leaf.copyWith(tabs: [...leaf.tabs, tab], active: tab.id),
      ),
    );
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
  /// the only one.
  SidebarState closeTab(String paneId, String tabId) {
    var emptied = false;
    final next = mapLeaf(tree, paneId, (leaf) {
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
    if (identical(next, tree)) return this;
    return _withTree(emptied ? removeLeafAt(next, paneId) : next);
  }

  /// Makes [tabId] the visible tab of [paneId], and that pane active.
  SidebarState activateTab(String paneId, String tabId) {
    final next = mapLeaf(
      tree,
      paneId,
      (leaf) => leaf.tabs.any((tab) => tab.id == tabId)
          ? leaf.copyWith(active: tabId)
          : leaf,
    );
    return copyWith(tree: next, activePane: paneId);
  }

  /// Makes [paneId] the pane the next tab lands in.
  ///
  /// [activateTab] covers the usual case, but a pane with no tabs has none to
  /// activate, and clicking its welcome content still has to aim the next open
  /// at it. An unknown pane is a no-op rather than a stale pointer.
  SidebarState focusPane(String paneId) =>
      panes.any((pane) => pane.id == paneId) ? copyWith(activePane: paneId) : this;

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
    var changed = false;
    SplitNode walk(SplitNode node) {
      switch (node) {
        case SidebarLeaf():
          if (!node.tabs.any((tab) => tab.id == tabId)) return node;
          changed = true;
          return node.copyWith(
            tabs: [
              for (final tab in node.tabs)
                if (tab.id == tabId)
                  tab.copyWith(title: title, path: path, meta: meta)
                else
                  tab,
            ],
          );
        case SidebarSplit():
          return node.copyWith(
            children: [for (final child in node.children) walk(child)],
          );
      }
    }

    final next = walk(tree);
    return changed ? copyWith(tree: next) : this;
  }

  // --- Layout gestures ---

  /// Splits the active pane, leaving the new pane empty.
  SidebarState splitPane(SplitDirection dir) {
    final minter = IdMinter(nextId);
    return copyWith(
      tree: splitLeafAt(tree, _target, dir, minter),
      nextId: minter.next,
    );
  }

  /// Moves [tabId] from [fromPane] into [toPane] at [index] (-1 appends).
  ///
  /// Reordering inside one pane is the same operation with `fromPane == toPane`,
  /// which is why the removal happens before the insertion: the index the drop
  /// reported is an index into the list without the dragged tab.
  SidebarState moveTab(
    String fromPane,
    String tabId,
    String toPane, [
    int index = -1,
  ]) {
    final source = paneOf(tabId);
    if (source == null || source.id != fromPane) return this;
    final moved = source.tabs.firstWhere((tab) => tab.id == tabId);
    var emptied = false;
    var next = mapLeaf(tree, fromPane, (leaf) {
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
    return copyWith(tree: next, activePane: toPane);
  }

  /// The VSCode drag gesture: [zone] `center` merges [tabId] into [toPane],
  /// an edge splits [toPane] with the tab alone in the new pane.
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
    final moved = source.tabs.firstWhere((tab) => tab.id == tabId);
    var emptied = false;
    var next = mapLeaf(tree, fromPane, (leaf) {
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
    // Dragging a pane's last tab to that same pane's edge is a no-op the source
    // does not special-case: removing the pane would take the drop target with
    // it. Nothing about the layout changes, so return unchanged.
    if (emptied && fromPane == toPane) return this;
    if (emptied) next = removeLeafAt(next, fromPane);
    final minter = IdMinter(nextId);
    final result = insertLeafAt(
      next,
      toPane,
      zone == DropZone.left || zone == DropZone.right
          ? SplitDirection.row
          : SplitDirection.col,
      moved,
      zone == DropZone.left || zone == DropZone.up,
      minter,
    );
    return copyWith(
      tree: result.$1,
      activePane: result.$2,
      nextId: minter.next,
    );
  }

  /// Opens a diff tab the way VSCode does.
  ///
  /// Three cases, in order: an open tab for the same change is focused; else the
  /// tab joins the first pane that already holds diffs (diff panes are sticky,
  /// so a run of clicks through the git view stacks in one place instead of
  /// shredding the layout); else the first diff of a layout splits [sourcePaneId]
  /// downwards and lands below it.
  SidebarState openDiffTab(String sourcePaneId, SidebarTab tab) {
    final existing = paneOf(tab.id);
    if (existing != null) return activateTab(existing.id, tab.id);
    for (final pane in panes) {
      if (pane.tabs.any((open) => open.type == BuiltinTabType.diff)) {
        return copyWith(
          activePane: pane.id,
          tree: mapLeaf(
            tree,
            pane.id,
            (leaf) => leaf.copyWith(tabs: [...leaf.tabs, tab], active: tab.id),
          ),
        );
      }
    }
    if (!panes.any((pane) => pane.id == sourcePaneId)) return openTab(tab);
    final minter = IdMinter(nextId);
    final result = insertLeafAt(
      tree,
      sourcePaneId,
      SplitDirection.col,
      tab,
      false,
      minter,
    );
    return copyWith(
      tree: result.$1,
      activePane: result.$2,
      nextId: minter.next,
    );
  }

  /// Moves the divider at [index] of split [splitId] by [delta] fractions.
  SidebarState resize(String splitId, int index, double delta) =>
      copyWith(tree: resizeSplit(tree, splitId, index, delta));

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
    'activePane': activePane,
    'expanded': expanded.toList(),
    'nextTerminal': nextTerminal,
    'nextId': nextId,
  };

  /// Reads a layout back, falling back to [SidebarState.initial] for anything
  /// that does not read as one.
  ///
  /// The hydration does two repairs the writer cannot: duplicate node ids are
  /// re-minted (see [dedupeNodeIds] — the bug `state.ts:150-158` describes), and
  /// [nextId] is lifted past every id actually present, so a file whose counter
  /// disagrees with its tree cannot hand out an id already in use.
  static SidebarState fromJson(Object? raw) {
    if (raw is! Map) return SidebarState.initial();
    final tree = splitNodeFromJson(raw['tree']);
    if (tree == null) return SidebarState.initial();
    final persisted = raw['nextId'];
    final minter = IdMinter(
      [
        persisted is int ? persisted : 1,
        maxCounterSuffix(tree) + 1,
      ].reduce((a, b) => a > b ? a : b),
    );
    final deduped = dedupeNodeIds(tree, minter);
    final leaves = allLeaves(deduped);
    final active = raw['activePane'];
    final terminal = raw['nextTerminal'];
    return SidebarState(
      tree: deduped,
      activePane: active is String && leaves.any((leaf) => leaf.id == active)
          ? active
          : leaves.first.id,
      expanded: {
        if (raw['expanded'] case final List paths)
          for (final path in paths)
            if (path is String) path,
      },
      nextTerminal: terminal is int && terminal > 0 ? terminal : 1,
      nextId: minter.next,
    );
  }

  /// [tree] replaced, with [activePane] re-pointed when the pane it named is
  /// gone.
  SidebarState _withTree(SplitNode next) {
    final leaves = allLeaves(next);
    return copyWith(
      tree: next,
      activePane: leaves.any((leaf) => leaf.id == activePane)
          ? activePane
          : leaves.first.id,
    );
  }
}
