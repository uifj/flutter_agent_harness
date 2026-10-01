// The file tree tab.
//
// A port of `DSH-better-sidebar/src/client/FileTree.tsx`, reading the disk
// directly instead of `GET /sidebar/api/list`, and through the same [Workspace]
// guard the file tools use — a row the tree offers must be a path `read` will
// accept, or the tree is advertising files the agent then refuses.
//
// Two things the source does that this does not:
//
//   * A `showHidden` toggle. Dotfiles are shown, always. A tree that hides
//     `.gitignore` in a repository view is hiding the file most likely to be
//     the answer.
//   * Filesystem watching. The source subscribes to host-side watch events;
//     this takes agent-side refresh (the `fsRevision` counter, bumped by the
//     write/edit tools) plus a manual refresh control. A `Directory.watch`
//     per expanded folder is a real cost (one FSEvents stream each), and
//     getting invalidation subtly wrong is worse than a button.
//
// The expansion set lives in [SidebarState] rather than here, so it survives a
// tab moving between panes and a session reload. The listing cache does not: it
// is a mirror of the disk, and a stale mirror restored from a file would show
// files that were deleted while the app was closed.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadInput;
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:path/path.dart' as p;

import '../../../theme/dsw_shad_bridge.dart';
import '../../../../theme/dsw_shape.dart';
import '../../../l10n/locales.dart';
import '../../../host/git.dart';
import '../../../model/fs_revision.dart';
import '../../../model/workspace.dart';
import '../../../theme/dsw_alias.dart';
import '../../../theme/dsw_motion.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../../model/sidebar_tab.dart';
import '../../../state/git_status_store.dart';
import '../../../state/workbench_controller.dart';
import '../../primitives/icon_button.dart';
import '../../primitives/menu.dart';
import '../../primitives/reveal.dart';
import '../../primitives/tappable.dart';
import 'git_tab.dart' show GitHost;

/// Row height. 22px is the source's `--row-h`; it is also what fits a 13px label
/// with the 4px hit-target padding a click needs.
const _rowHeight = 22.0;

/// Indent per depth level.
const _indent = 12.0;

/// One visible row of the flattened tree.
class _Row {
  const _Row({
    required this.path,
    required this.isDirectory,
    required this.depth,
  });

  final String path;
  final bool isDirectory;
  final int depth;
}

class FileTreeTab extends StatefulWidget {
  const FileTreeTab({super.key, required this.workbench, required this.tab});

  final WorkbenchController workbench;
  final SidebarTab tab;

  @override
  State<FileTreeTab> createState() => _FileTreeTabState();
}

class _FileTreeTabState extends State<FileTreeTab> {
  /// Children per directory, sorted. Absent means "not read yet".
  final _children = <String, List<_Row>>{};

  /// Directories whose read failed, and why — a permission error has to be
  /// visible on the row that caused it, not swallowed into an empty folder.
  final _failed = <String, String>{};

  /// In-flight reads, so a rebuild while one is pending does not start a second.
  final _reading = <String>{};

  /// The header search box's query. Empty means the unfiltered tree; non-empty
  /// switches the flatten below to match-mode, where the expansion set is
  /// ignored (a search that respected it could not find anything).
  String _filter = '';

  /// The header's "changed files only" switch. Off by default: a tree that
  /// hides the unmodified majority unless you ask is a tree you cannot
  /// navigate (ADR-0043 D4).
  bool _onlyChanged = false;

  /// The shared git reading, resolved from [GitHost] on the first dependency
  /// pass. The tree never polls and never owns a status of its own.
  GitStatusStore? _store;

  @override
  void initState() {
    super.initState();
    widget.workbench.addListener(_onWorkbench);
    // The agent's writes announce themselves through the revision counter
    // (see `fsRevision`): the tree re-lists what is open, without a watcher
    // and without the user pressing anything. This is the ONE refresh path
    // that is not the user's — the header control stays for everything else
    // the disk does behind the app's back.
    fsRevision.addListener(_onFsRevision);
    _read(_root);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store != null) return;
    _store = GitHost.statusOf(context)
      // The panel can be the one that asks; when it does, this tree repaints
      // from the same reading instead of showing its own last-known copy.
      ..addListener(_onGitStatus);
    _askGit();
  }

  void _onGitStatus() {
    if (mounted) setState(() {});
  }

  /// The root the cache was last asked about, so moving to another folder asks
  /// once rather than on every notification.
  String? _askedRoot;

  /// One question to the cache. A reading that is not there yet is simply no
  /// badge on screen — the tree does not nag git, and says nothing when git
  /// says nothing (that failure is the panel's to report).
  void _askGit() {
    final root = _root;
    if (root.isEmpty || root == _askedRoot) return;
    _askedRoot = root;
    _store?.read(root);
  }

  @override
  void dispose() {
    widget.workbench.removeListener(_onWorkbench);
    fsRevision.removeListener(_onFsRevision);
    _store?.removeListener(_onGitStatus);
    super.dispose();
  }

  /// The agent wrote something: drop every listing and re-read what is open —
  /// the same walk as the refresh control, arrived at from the other side.
  void _onFsRevision() {
    _refresh();
    // The cached status is now the old world; asking again is what puts a
    // letter on the file that was just created.
    final root = _root;
    if (root.isEmpty) return;
    _store?.invalidate(root);
    _store?.read(root);
    _askedRoot = root;
  }

  /// The folder this tab is rooted at, falling back to the workspace.
  String get _root => widget.tab.path ?? widget.workbench.workspaceRoot ?? '';

  /// The shared reading, or null when git has nothing to say about this root.
  GitStatusResult? get _git {
    final store = _store;
    final root = _root;
    if (store == null || root.isEmpty) return null;
    final reading = store.reading(root);
    return reading == null || !reading.isRepo ? null : reading;
  }

  /// Absolute path of every changed file. Keyed off the repository's top level,
  /// which is what `status --porcelain` counts from — the tree can be rooted
  /// anywhere below it.
  Map<String, GitStatusEntry> get _changed {
    final reading = _git;
    final top = reading?.root;
    if (top == null) return const {};
    return {
      for (final entry in reading!.entries) p.join(top, entry.path): entry,
    };
  }

  /// Directories with a change below them — the tree's answer to the source's
  /// per-directory dot (`WorkspaceFileTreeRowView.tsx:307`).
  Set<String> get _changedDirs {
    final result = <String>{};
    for (final path in _changed.keys) {
      var directory = p.dirname(path);
      while (directory.isNotEmpty && directory != p.dirname(directory)) {
        result.add(directory);
        directory = p.dirname(directory);
      }
    }
    return result;
  }

  /// A newly expanded directory has to be read, and the expansion set is in the
  /// controller — so the read is triggered from the notification rather than from
  /// the tap handler, which keeps it working when something else expands a path
  /// (the git panel's "expand in file tree" arrives through exactly this door).
  void _onWorkbench() {
    _askGit();
    for (final path in widget.workbench.state.expanded) {
      if (!_children.containsKey(path) &&
          !_failed.containsKey(path) &&
          p.isWithin(_root, path)) {
        _read(path);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _read(String directory) async {
    if (directory.isEmpty || _reading.contains(directory)) return;
    _reading.add(directory);
    final workspace = widget.workbench.workspace;
    try {
      // Resolved even though the path came from a previous listing: a symlink
      // planted between the two would otherwise be a way out of the workspace.
      final resolved = workspace == null
          ? directory
          : workspace.resolve(directory);
      final entries = await Directory(
        resolved,
      ).list(followLinks: false).toList();
      final rows = <_Row>[
        for (final entry in entries)
          _Row(
            path: p.join(directory, p.basename(entry.path)),
            isDirectory: entry is Directory,
            depth: 0,
          ),
      ]..sort(_byKind);
      if (!mounted) return;
      setState(() {
        _children[directory] = rows;
        _failed.remove(directory);
      });
    } on WorkspaceDenied catch (denied) {
      if (mounted) setState(() => _failed[directory] = denied.message);
    } on FileSystemException catch (error) {
      if (mounted) {
        setState(
          () => _failed[directory] = error.osError?.message ?? 'unreadable',
        );
      }
    } finally {
      _reading.remove(directory);
    }
  }

  /// Folders first, then by name, case-insensitively — the ordering every file
  /// browser uses, and the one that makes a deep tree scannable.
  static int _byKind(_Row a, _Row b) {
    if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
    return a.path.toLowerCase().compareTo(b.path.toLowerCase());
  }

  /// Drops every listing and re-reads what is open. The refresh control, and the
  /// reason there is no watcher.
  void _refresh() {
    setState(() {
      _children.clear();
      _failed.clear();
    });
    _read(_root);
    for (final path in widget.workbench.state.expanded) {
      if (p.isWithin(_root, path)) _read(path);
    }
  }

  /// The visible rows, depth-first, in one flat list so the whole tree scrolls
  /// through a single [ListView.builder] rather than nesting a scroll view per
  /// level.
  List<_Row> _flatten() {
    final query = _filter.toLowerCase();
    if (query.isEmpty && !_onlyChanged) {
      final expanded = widget.workbench.state.expanded;
      final rows = <_Row>[];
      void walk(String directory, int depth) {
        for (final row in _children[directory] ?? const <_Row>[]) {
          rows.add(
            _Row(path: row.path, isDirectory: row.isDirectory, depth: depth),
          );
          if (row.isDirectory && expanded.contains(row.path)) {
            walk(row.path, depth + 1);
          }
        }
      }

      walk(_root, 0);
      return rows;
    }

    // Either filter is the same shape: a file shows when it qualifies, a
    // directory when it or any descendant does — ancestors of a match are the
    // only way a deep match is reachable, so they ride along at their own
    // depth. The expansion set is ignored, which is why directories in a
    // filtered tree draw expanded.
    if (query.isNotEmpty) {
      return _matchingRows(
        _root,
        0,
        (row) => p.basename(row.path).toLowerCase().contains(query),
      );
    }
    final changed = _changed;
    // A toggle that is on while nothing is changed shows an empty tree, not the
    // whole one: the switch would be lying about what it filtered.
    if (changed.isEmpty) return const [];
    return _matchingRows(_root, 0, (row) => changed.containsKey(row.path));
  }

  /// The rows under [directory] at [depth] that [qualifies], plus the ancestors
  /// that make a deep one reachable.
  List<_Row> _matchingRows(
    String directory,
    int depth,
    bool Function(_Row row) qualifies,
  ) {
    final rows = <_Row>[];
    for (final row in _children[directory] ?? const <_Row>[]) {
      if (row.isDirectory) {
        // Reads the folder even when it is collapsed: a match below a collapsed
        // directory is the whole point of filtering.
        _read(row.path);
        final descendants = _matchingRows(row.path, depth + 1, qualifies);
        if (qualifies(row) || descendants.isNotEmpty) {
          rows.add(_Row(path: row.path, isDirectory: true, depth: depth));
          rows.addAll(descendants);
        }
      } else if (qualifies(row)) {
        rows.add(_Row(path: row.path, isDirectory: false, depth: depth));
      }
    }
    return rows;
  }

  /// The file the workbench is currently showing, so the tree can say where the
  /// editor is. Null when the focused tab is not an editor.
  String? get _currentFile {
    final state = widget.workbench.state;
    final pane = state.panes.where((pane) => pane.id == state.activePane);
    if (pane.isEmpty) return null;
    final active = pane.first.active;
    if (active == null) return null;
    final tab = state.tabById(active);
    return tab?.type == BuiltinTabType.editor ? tab?.path : null;
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    if (_root.isEmpty) {
      return _Empty(message: context.tr('noWorkspaceNothingToList'));
    }
    final rows = _flatten();
    final current = _currentFile;
    // Built once per frame for the whole list: both are derived from the one
    // shared reading, and per row they would be O(rows × entries).
    final changed = _changed;
    final changedDirs = _changedDirs;
    return Column(
      children: [
        _header(color),
        _searchBox(color),
        Expanded(
          child: rows.isEmpty
              ? _Empty(
                  message: switch ((_filter.isNotEmpty, _onlyChanged)) {
                    (true, _) => context.tr('noMatches', {'query': _filter}),
                    (_, true) => context.tr('nothingChanged'),
                    _ => context.tr('folderEmpty'),
                  },
                )
              : ListView.builder(
                  primary: false,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  // The extent is one row of labels, so it scales with them -
                  // `itemExtent` clips whatever the row wants to be taller.
                  itemExtent:
                      _rowHeight * MediaQuery.textScalerOf(context).scale(1),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final filtering = _filter.isNotEmpty || _onlyChanged;
                    final entry = changed[row.path];
                    return DswContextMenu(
                      items: (context) => _rowMenuItems(context, row),
                      child: _TreeRow(
                        row: row,
                        expanded:
                            filtering ||
                            widget.workbench.state.expanded.contains(row.path),
                        selected: row.path == current,
                        error: _failed[row.path],
                        badge: entry == null ? null : badgeOf(entry),
                        hasChanges: row.isDirectory
                            ? changedDirs.contains(row.path)
                            : entry != null,
                        onTap: () => row.isDirectory
                            ? widget.workbench.toggleExpanded(row.path)
                            : widget.workbench.openFile(row.path),
                      ),
                    );
                  },
                ),
        ),
        if (_failed[_root] != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _failed[_root]!,
              style: DswType.xxs12.copyWith(color: color.stateErrorPrimary),
            ),
          ),
      ],
    );
  }

  /// The header search box. Filter-only: it never navigates, because a tree
  /// that jumps while being filtered is a tree whose rows cannot be clicked
  /// mid-thought.
  Widget _searchBox(DswAlias color) => Container(
    // A one-line seat, so it rides the text step: at the system's 1.8x the hint
    // needed 32.0 and got 29.0.
    height: 30 * MediaQuery.textScalerOf(context).scale(1),
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
    decoration: BoxDecoration(
      color: color.bgLayer1,
      border: Border(bottom: BorderSide(color: color.borderL1)),
    ),
    child: Row(
      children: [
        Icon(
          LucideIcons.search,
          size: DswShape.iconTiny,
          color: color.labelTertiary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: dswEnsureShadTheme(
            context,
            ShadInput(
              onChanged: (value) => setState(() => _filter = value.trim()),
              style: DswType.xs13.copyWith(color: color.labelPrimary),
              // This field is a hole cut in a toolbar row, not a box: the row is
              // the surface, so the field draws no frame and no padding of its own.
              decoration: dswBareInput,
              padding: EdgeInsets.zero,
              placeholder: dswInputHint(context.tr('searchFiles')),
              placeholderStyle: DswType.xxs12.copyWith(
                color: color.labelCaption,
              ),
            ),
          ),
        ),
        if (_filter.isNotEmpty)
          DswIconButton(
            icon: LucideIcons.x,
            tooltip: context.tr('cancel'),
            onTap: () => setState(() => _filter = ''),
            size: 20,
            iconSize: DswShape.iconTiny,
          ),
      ],
    ),
  );

  /// The row's right-click menu: open, copy paths, and — for a directory — a
  /// tree tab rooted there. [DswContextMenu] opens it at the pointer.
  List<DswMenuEntry> _rowMenuItems(BuildContext context, _Row row) {
    final root = widget.workbench.workspaceRoot;
    final relative = root != null && p.isWithin(root, row.path)
        ? p.relative(row.path, from: root)
        : row.path;
    return [
      DswMenuEntry(
        icon: row.isDirectory ? LucideIcons.chevron_right : LucideIcons.file,
        label: context.tr('open'),
        onTap: () => row.isDirectory
            ? widget.workbench.toggleExpanded(row.path)
            : widget.workbench.openFile(row.path),
      ),
      DswMenuEntry(
        icon: LucideIcons.copy,
        label: context.tr('copyRelative'),
        onTap: () => Clipboard.setData(ClipboardData(text: relative)),
      ),
      DswMenuEntry(
        icon: LucideIcons.file_symlink,
        label: context.tr('copyAbsolute'),
        onTap: () => Clipboard.setData(ClipboardData(text: row.path)),
      ),
      // The same glyph the history uses for the same action: "where is this on
      // disk" is one question no matter which list asked it (ADR-0041).
      DswMenuEntry(
        icon: LucideIcons.external_link,
        label: context.tr('revealInFiles'),
        onTap: () => revealInFilesOrReport(context, row.path),
      ),
      if (row.isDirectory)
        DswMenuEntry(
          icon: LucideIcons.list_tree,
          label: context.tr('openInTreeTab'),
          onTap: () => widget.workbench.openFolder(row.path),
        ),
    ];
  }

  Widget _header(DswAlias color) => Container(
    // One line of chrome, so the seat rides the text step: pinned at 28 the
    // workspace name wanted 31.0 of the 27.0 left inside it at 2.2x.
    height: 28 * MediaQuery.textScalerOf(context).scale(1),
    padding: const EdgeInsets.only(left: 10, right: 4),
    decoration: BoxDecoration(
      color: color.bgLayer1,
      border: Border(bottom: BorderSide(color: color.borderL1)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            p.basename(_root).toUpperCase(),
            style: DswType.xxxsStrong11.copyWith(color: color.labelTertiary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Offered only when git has something to filter to — the source gates
        // the same control on `gitStatusAvailable` (`WorkspaceFileTree.tsx:693`).
        if (_changed.isNotEmpty)
          DswIconButton(
            icon: LucideIcons.list_filter,
            tooltip: context.tr('showOnlyChanged'),
            selected: _onlyChanged,
            onTap: () => setState(() => _onlyChanged = !_onlyChanged),
            size: 20,
            iconSize: DswShape.iconTiny,
          ),
        DswIconButton(
          icon: LucideIcons.refresh_cw,
          tooltip: context.tr('refresh'),
          onTap: _refresh,
          size: 20,
          iconSize: DswShape.iconTiny,
        ),
      ],
    ),
  );
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.row,
    required this.expanded,
    required this.selected,
    required this.error,
    required this.onTap,
    this.badge,
    this.hasChanges = false,
  });

  final _Row row;
  final bool expanded;
  final bool selected;

  /// Why this directory could not be read, shown as a tooltip on the row rather
  /// than as an alert: the row is where the user can act on it.
  final String? error;

  /// The XY letter for a changed file, from the shared reading (ADR-0043). Null
  /// means git has nothing to say about this path — including "not a repository".
  final String? badge;

  /// A directory with a change somewhere below it. The source marks the same
  /// fact with a dot (`WorkspaceFileTreeRowView.tsx:307`).
  final bool hasChanges;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final content = Row(
      children: [
        SizedBox(width: 6 + row.depth * _indent),
        SizedBox.square(
          dimension: 14,
          child: Center(
            child: row.isDirectory
                ? AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: DswMotion.respecting(context, DswMotion.fast),
                    curve: DswMotion.easeInOut,
                    child: Icon(
                      LucideIcons.chevron_right,
                      size: DswShape.iconSm,
                      color: color.labelTertiary,
                    ),
                  )
                : Icon(
                    LucideIcons.file,
                    size: DswShape.iconTiny,
                    color: color.labelTertiary,
                  ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            p.basename(row.path),
            style: DswType.xs13.copyWith(
              color: error != null
                  ? color.stateErrorPrimary
                  : selected
                  ? color.labelPrimary
                  : color.labelSecondary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 6),
        // A margin note, not the panel's boxed badge: in the git panel the
        // change is the row's subject, here the row's subject is the file. Same
        // letter from the same function either way.
        if (badge case final mark?) ...[
          Text(
            mark,
            style: DswType.xxxs11.copyWith(color: color.labelTertiary),
          ),
          const SizedBox(width: 6),
        ] else if (hasChanges) ...[
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.brandPrimary,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 6),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );

    // No secondary tap here on purpose: the row's `DswContextMenu` claims the
    // right button, and the deeper recognizer would win the arena instead.
    return DswHoverTap(
      onTap: onTap,
      semanticLabel: row.path,
      excludeSemantics: true,
      builder: (context, hovered, _) => Tooltip(
        // Only the failing rows and the truncated ones need a tooltip, but
        // deciding which are truncated needs a layout pass; the full path is
        // useful on every row anyway.
        message: error == null ? row.path : '${row.path}\n$error',
        child: ColoredBox(
          color: selected
              ? color.sidebarNavItemActive
              : hovered
              ? color.sidebarNavItemHover
              : Colors.transparent,
          child: content,
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: DswType.xs13.copyWith(color: color.labelTertiary),
        ),
      ),
    );
  }
}
