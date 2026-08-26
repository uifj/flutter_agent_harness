// The recursive split tree, and every pure operation over it.
//
// A port of the tree half of `DSH-better-sidebar/src/client/state.ts` — the
// `mapLeaf` / `splitLeafAt` / `insertLeafAt` / `removeLeafAt` / `resizeSplit`
// family. Nothing here touches Flutter, dart:io or the clock, so
// `test/split_node_test.dart` can cover the whole file as plain functions; that
// is the reason the tree lives apart from the controller that drives it.
//
// Two structural departures from the source, both deliberate:
//
//   * The source mutates a cloned leaf in place (`Object.assign(leaf, split)`)
//     to turn a leaf into a split. Dart has no equivalent, and would not want
//     one: [mapLeaf] here takes a function from the found leaf to its
//     *replacement node*, which expresses leaf→split promotion without anybody
//     mutating anything.
//   * Ids are minted from an [IdMinter] the caller threads through, not a
//     module-global counter. The source's counter resets on reload while the
//     persisted ids do not, and `state.ts:150-158` documents the bug that
//     followed: a fresh `pane:1` colliding with a persisted `pane:1`, after
//     which `mapLeaf` visits both leaves and every open lands in two panes. The
//     source patches it by scanning the persisted state for the highest suffix
//     (`maxCounterId`). Carrying the counter inside the state it belongs to
//     removes the desync that made the scan necessary, and makes tests
//     deterministic for free.

import 'sidebar_tab.dart';

/// Which way a split divides its children.
enum SplitDirection {
  /// Side by side.
  row,

  /// Stacked.
  col,
}

/// A split child may not be squeezed below this fraction of its parent, or
/// past its complement. Matches `state.ts:751-752`: a pane with no width left
/// cannot be grabbed to undo the drag that took it.
const splitMinFraction = 0.08;

/// The complement of [splitMinFraction].
const splitMaxFraction = 0.92;

/// Hands out ids that are unique within one state.
///
/// Mutable and short-lived: a reducer builds one from the state's counter, mints
/// what it needs, and writes [next] back into the state it returns. See the file
/// header for why the counter is not global.
class IdMinter {
  IdMinter(this._next);

  int _next;

  /// The value to persist, so the next reducer resumes where this one stopped.
  int get next => _next;

  String mint(String prefix) => '$prefix:${_next++}';
}

/// A node of the workbench tree: a tab group, or a division of the space.
sealed class SplitNode {
  const SplitNode({required this.id});

  /// Unique across the whole tree, panes and splits alike, so one id resolves
  /// without the caller having to say which kind it expects.
  final String id;

  Map<String, Object?> toJson();
}

/// A tab group: one tab bar and one visible tab.
class SidebarLeaf extends SplitNode {
  const SidebarLeaf({required super.id, required this.tabs, required this.active});

  /// An empty pane. Legal, and reachable: closing the last tab of the only pane
  /// leaves one, and it shows the welcome content.
  SidebarLeaf.empty(String id) : this(id: id, tabs: const [], active: null);

  final List<SidebarTab> tabs;

  /// Id of the visible tab, or null when [tabs] is empty.
  final String? active;

  SidebarLeaf copyWith({List<SidebarTab>? tabs, String? active, bool clearActive = false}) =>
      SidebarLeaf(
        id: id,
        tabs: tabs ?? this.tabs,
        active: clearActive ? null : (active ?? this.active),
      );

  @override
  Map<String, Object?> toJson() => {
    'kind': 'leaf',
    'id': id,
    'tabs': [for (final tab in tabs) tab.toJson()],
    'active': active,
  };

  @override
  String toString() => 'SidebarLeaf($id, ${tabs.length} tabs, active: $active)';
}

/// A division of the space between two or more children.
class SidebarSplit extends SplitNode {
  const SidebarSplit({
    required super.id,
    required this.dir,
    required this.sizes,
    required this.children,
  });

  final SplitDirection dir;

  /// Fractions of the parent, one per child, summing to 1.
  final List<double> sizes;

  final List<SplitNode> children;

  SidebarSplit copyWith({List<double>? sizes, List<SplitNode>? children}) =>
      SidebarSplit(
        id: id,
        dir: dir,
        sizes: sizes ?? this.sizes,
        children: children ?? this.children,
      );

  @override
  Map<String, Object?> toJson() => {
    'kind': 'split',
    'id': id,
    'dir': dir.name,
    'sizes': sizes,
    'children': [for (final child in children) child.toJson()],
  };

  @override
  String toString() => 'SidebarSplit($id, ${dir.name}, ${children.length} children)';
}

/// Rebuilds [node] with the leaf identified by [paneId] replaced by
/// `visit(leaf)`.
///
/// Returns the same instance when nothing matched, which lets callers detect a
/// no-op by identity. [visit] may return a split, which is how a pane becomes
/// two.
SplitNode mapLeaf(
  SplitNode node,
  String paneId,
  SplitNode Function(SidebarLeaf leaf) visit,
) {
  switch (node) {
    case SidebarLeaf():
      return node.id == paneId ? visit(node) : node;
    case SidebarSplit():
      var changed = false;
      final children = <SplitNode>[];
      for (final child in node.children) {
        final next = mapLeaf(child, paneId, visit);
        if (!identical(next, child)) changed = true;
        children.add(next);
      }
      return changed ? node.copyWith(children: children) : node;
  }
}

/// Whether [node] or any descendant carries [id].
bool treeHasId(SplitNode node, String id) => switch (node) {
  SidebarLeaf() => node.id == id,
  SidebarSplit() =>
    node.id == id || node.children.any((child) => treeHasId(child, id)),
};

/// The first pane in tree order — the fallback target when an id has gone
/// stale.
SidebarLeaf firstLeaf(SplitNode node) => switch (node) {
  SidebarLeaf() => node,
  // A split always has children, so this cannot walk off the end.
  SidebarSplit() => firstLeaf(node.children.first),
};

/// Every pane, in tree order.
List<SidebarLeaf> allLeaves(SplitNode node) => switch (node) {
  SidebarLeaf() => [node],
  SidebarSplit() => [
    for (final child in node.children) ...allLeaves(child),
  ],
};

/// The pane holding the tab with [tabId], or null.
SidebarLeaf? leafWithTab(SplitNode node, String tabId) {
  for (final leaf in allLeaves(node)) {
    if (leaf.tabs.any((tab) => tab.id == tabId)) return leaf;
  }
  return null;
}

/// Every split, in tree order — the dividers a renderer has to draw.
List<SidebarSplit> allSplits(SplitNode node) => switch (node) {
  SidebarLeaf() => const [],
  SidebarSplit() => [
    node,
    for (final child in node.children) ...allSplits(child),
  ],
};

/// Replaces the pane [paneId] with a split of it plus a fresh empty pane.
SplitNode splitLeafAt(
  SplitNode node,
  String paneId,
  SplitDirection dir,
  IdMinter minter,
) {
  // Minted before the walk so an unmatched paneId does not silently burn an id
  // in one branch and not another — the walk visits at most one leaf, but the
  // closure would otherwise run zero times or once depending on the input.
  final freshId = minter.mint('pane');
  final splitId = minter.mint('split');
  return mapLeaf(
    node,
    paneId,
    (leaf) => SidebarSplit(
      id: splitId,
      dir: dir,
      sizes: const [0.5, 0.5],
      children: [leaf, SidebarLeaf.empty(freshId)],
    ),
  );
}

/// Splits the pane [paneId], putting [tab] alone in the new pane — the
/// drag-to-edge gesture.
///
/// [front] places the new pane first (left/up) rather than second (right/down).
/// Returns the new tree and the new pane's id, which the caller makes active.
(SplitNode node, String leafId) insertLeafAt(
  SplitNode node,
  String paneId,
  SplitDirection dir,
  SidebarTab tab,
  bool front,
  IdMinter minter,
) {
  final leafId = minter.mint('pane');
  final splitId = minter.mint('split');
  final fresh = SidebarLeaf(id: leafId, tabs: [tab], active: tab.id);
  final next = mapLeaf(
    node,
    paneId,
    (leaf) => SidebarSplit(
      id: splitId,
      dir: dir,
      sizes: const [0.5, 0.5],
      children: front ? [fresh, leaf] : [leaf, fresh],
    ),
  );
  return (next, leafId);
}

/// Removes the pane [paneId].
///
/// A split left with one child promotes that child, so closing panes never
/// leaves a split with nothing to divide. Removing the only pane yields that
/// pane emptied rather than nothing: the workbench always has somewhere to put
/// the next tab.
SplitNode removeLeafAt(SplitNode node, String paneId) {
  switch (node) {
    case SidebarLeaf():
      return node.id == paneId
          ? SidebarLeaf(id: node.id, tabs: const [], active: null)
          : node;
    case SidebarSplit():
      final keep = <int>[];
      for (var i = 0; i < node.children.length; i++) {
        final child = node.children[i];
        if (child is SidebarLeaf && child.id == paneId) continue;
        keep.add(i);
      }
      if (keep.length == node.children.length) {
        return node.copyWith(
          children: [
            for (final child in node.children) removeLeafAt(child, paneId),
          ],
        );
      }
      if (keep.length == 1) return node.children[keep.single];
      // The removed child's fraction is redistributed rather than dropped, or
      // the survivors would no longer sum to 1 and the last pane would be
      // handed the rounding error every frame.
      final kept = [for (final i in keep) node.sizes[i]];
      final total = kept.fold(0.0, (sum, size) => sum + size);
      return node.copyWith(
        sizes: total <= 0
            ? [for (final _ in keep) 1 / keep.length]
            : [for (final size in kept) size / total],
        children: [for (final i in keep) node.children[i]],
      );
  }
}

/// Moves the divider at [index] of the split [splitId] by [delta] fractions.
///
/// [index] is the child on the leading side. Both neighbours are clamped, so a
/// drag past the floor stops instead of pushing the deficit down the row.
SplitNode resizeSplit(
  SplitNode node,
  String splitId,
  int index,
  double delta,
) {
  switch (node) {
    case SidebarLeaf():
      return node;
    case SidebarSplit():
      if (node.id != splitId) {
        return node.copyWith(
          children: [
            for (final child in node.children)
              resizeSplit(child, splitId, index, delta),
          ],
        );
      }
      if (index < 0 || index + 1 >= node.sizes.length) return node;
      final sizes = [...node.sizes];
      sizes[index] = _clampFraction(sizes[index] + delta);
      sizes[index + 1] = _clampFraction(sizes[index + 1] - delta);
      return node.copyWith(sizes: sizes);
  }
}

double _clampFraction(double value) =>
    value.clamp(splitMinFraction, splitMaxFraction);

/// Reads a tree back from persisted JSON, or null when [raw] is not one.
///
/// Repairs rather than rejects wherever a repair is unambiguous: an `active` id
/// naming no tab falls back to the last tab, a `sizes` list of the wrong length
/// is replaced by equal fractions, a split left with one child is collapsed, and
/// tabs that fail to parse are dropped individually. A session file is written
/// by a version of this app that may not be the one reading it, so the strict
/// alternative — discard the layout — would be the harsher bug.
SplitNode? splitNodeFromJson(Object? raw) {
  if (raw is! Map) return null;
  final id = raw['id'];
  if (id is! String || id.isEmpty) return null;
  if (raw['kind'] == 'split') {
    final children = <SplitNode>[];
    final rawChildren = raw['children'];
    if (rawChildren is List) {
      for (final child in rawChildren) {
        final parsed = splitNodeFromJson(child);
        if (parsed != null) children.add(parsed);
      }
    }
    if (children.isEmpty) return null;
    if (children.length == 1) return children.single;
    final rawSizes = raw['sizes'];
    var sizes = <double>[];
    if (rawSizes is List && rawSizes.length == children.length) {
      sizes = [
        for (final size in rawSizes)
          if (size is num) size.toDouble() else -1.0,
      ];
      final total = sizes.fold(0.0, (sum, size) => sum + size);
      if (sizes.any((size) => size <= 0) || total <= 0) {
        sizes = [];
      } else {
        sizes = [for (final size in sizes) size / total];
      }
    }
    return SidebarSplit(
      id: id,
      dir: raw['dir'] == 'col' ? SplitDirection.col : SplitDirection.row,
      sizes: sizes.isEmpty
          ? [for (final _ in children) 1 / children.length]
          : sizes,
      children: children,
    );
  }
  final tabs = <SidebarTab>[];
  final seen = <String>{};
  final rawTabs = raw['tabs'];
  if (rawTabs is List) {
    for (final entry in rawTabs) {
      final tab = SidebarTab.fromJson(entry);
      // A duplicated tab id inside one pane would make the tab bar unclickable:
      // activating either row would resolve to the first.
      if (tab != null && seen.add(tab.id)) tabs.add(tab);
    }
  }
  final active = raw['active'];
  return SidebarLeaf(
    id: id,
    tabs: tabs,
    active: active is String && seen.contains(active)
        ? active
        : (tabs.isEmpty ? null : tabs.last.id),
  );
}

/// The largest `prefix:N` suffix anywhere in [node], so a minter can resume past
/// every persisted id.
///
/// The counter travels with the state, but a session file written before that
/// was true — or hand-edited — may carry ids beyond it, and a minter that
/// restarted below them would hand out an id already in the tree.
int maxCounterSuffix(SplitNode node) {
  var max = 0;
  void consider(String id) {
    final match = RegExp(r'^(?:pane|tab|split):(\d+)$').firstMatch(id);
    if (match != null) {
      final value = int.tryParse(match.group(1)!) ?? 0;
      if (value > max) max = value;
    }
  }

  void walk(SplitNode current) {
    consider(current.id);
    switch (current) {
      case SidebarLeaf():
        for (final tab in current.tabs) {
          consider(tab.id);
        }
      case SidebarSplit():
        for (final child in current.children) {
          walk(child);
        }
    }
  }

  walk(node);
  return max;
}

/// Re-mints any node id that appears twice in [node].
///
/// This is the repair `state.ts:150-158` describes the symptom of: two panes
/// sharing an id make [mapLeaf] visit both, so every open lands in two places at
/// once. The source prevents the collision by seeding its global counter;
/// preventing it is not enough for a file that already has one, which is what
/// this pass is for. The first occurrence keeps the id so a stable `activePane`
/// still resolves.
SplitNode dedupeNodeIds(SplitNode node, IdMinter minter) {
  final seen = <String>{};
  SplitNode walk(SplitNode current) {
    final id = seen.add(current.id)
        ? current.id
        : minter.mint(current is SidebarSplit ? 'split' : 'pane');
    switch (current) {
      case SidebarLeaf():
        return id == current.id
            ? current
            : SidebarLeaf(id: id, tabs: current.tabs, active: current.active);
      case SidebarSplit():
        final children = [for (final child in current.children) walk(child)];
        return SidebarSplit(
          id: id,
          dir: current.dir,
          sizes: current.sizes,
          children: children,
        );
    }
  }

  return walk(node);
}
