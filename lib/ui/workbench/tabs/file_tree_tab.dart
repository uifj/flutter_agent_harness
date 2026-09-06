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
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:path/path.dart' as p;

import '../../../l10n/locales.dart';
import '../../../model/workspace.dart';
import '../../../state/fs_revision.dart';
import '../../../theme/dsw_alias.dart';
import '../../../theme/dsw_motion.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../../model/sidebar_tab.dart';
import '../../../state/workbench_controller.dart';

/// Row height. 22px is the source's `--row-h`; it is also what fits a 13px label
/// with the 4px hit-target padding a click needs.
const _rowHeight = 22.0;

/// Indent per depth level.
const _indent = 12.0;

/// One visible row of the flattened tree.
class _Row {
  const _Row({required this.path, required this.isDirectory, required this.depth});

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
  void dispose() {
    widget.workbench.removeListener(_onWorkbench);
    fsRevision.removeListener(_onFsRevision);
    super.dispose();
  }

  /// The agent wrote something: drop every listing and re-read what is open —
  /// the same walk as the refresh control, arrived at from the other side.
  void _onFsRevision() => _refresh();

  /// The folder this tab is rooted at, falling back to the workspace.
  String get _root => widget.tab.path ?? widget.workbench.workspaceRoot ?? '';

  /// A newly expanded directory has to be read, and the expansion set is in the
  /// controller — so the read is triggered from the notification rather than from
  /// the tap handler, which keeps it working when something else expands a path
  /// (`reveal`, from a tool call).
  void _onWorkbench() {
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
      final entries = await Directory(resolved).list(followLinks: false).toList();
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
        setState(() => _failed[directory] = error.osError?.message ?? 'unreadable');
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
    if (_filter.isEmpty) {
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

    // Match-mode: a file shows when its basename matches, a directory when it
    // or any descendant does — ancestors of a match are the only way a deep
    // match is reachable, so they ride along at their own depth. The expansion
    // set is ignored, which is why directories in match-mode draw expanded.
    return _matchRows(_root, 0, _filter.toLowerCase());
  }

  /// The matching rows under [directory] at [depth]: files whose basename
  /// contains [query], directories that match or contain a match.
  List<_Row> _matchRows(String directory, int depth, String query) {
    final rows = <_Row>[];
    for (final row in _children[directory] ?? const <_Row>[]) {
      final name = p.basename(row.path).toLowerCase();
      if (row.isDirectory) {
        // Reads the folder even when it is collapsed: a match below a
        // collapsed directory is the whole point of the search box.
        _read(row.path);
        final descendants = _matchRows(row.path, depth + 1, query);
        if (name.contains(query) || descendants.isNotEmpty) {
          rows.add(_Row(path: row.path, isDirectory: true, depth: depth));
          rows.addAll(descendants);
        }
      } else if (name.contains(query)) {
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
      return _Empty(
        message: context.tr('noWorkspaceNothingToList'),
      );
    }
    final rows = _flatten();
    final current = _currentFile;
    return Column(
      children: [
        _header(color),
        _searchBox(color),
        Expanded(
          child: rows.isEmpty
              ? _Empty(
                  message:
                      _filter.isEmpty
                          ? context.tr('folderEmpty')
                          : context.tr('noMatches', {
                              'query': _filter,
                            }),
                )
              : ListView.builder(
                  primary: false,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemExtent: _rowHeight,
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final filtering = _filter.isNotEmpty;
                    return _TreeRow(
                      row: row,
                      expanded:
                          filtering ||
                          widget.workbench.state.expanded.contains(row.path),
                      selected: row.path == current,
                      error: _failed[row.path],
                      onTap: () => row.isDirectory
                          ? widget.workbench.toggleExpanded(row.path)
                          : widget.workbench.openFile(row.path),
                      onSecondaryTap: (position) =>
                          _showRowMenu(context, row, position),
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
    height: 30,
    padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
    decoration: BoxDecoration(
      color: color.bgLayer1,
      border: Border(bottom: BorderSide(color: color.borderL1)),
    ),
    child: Row(
      children: [
        Icon(LucideIcons.search, size: 12, color: color.labelTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            onChanged: (value) => setState(() => _filter = value.trim()),
            style: DswType.xs13.copyWith(color: color.labelPrimary),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              hintText: context.tr('searchFiles'),
              hintStyle: DswType.xxs12.copyWith(color: color.labelCaption),
            ),
          ),
        ),
        if (_filter.isNotEmpty)
          _IconButton(
            icon: LucideIcons.x,
            tooltip: context.tr('cancel'),
            onTap: () => setState(() => _filter = ''),
          ),
      ],
    ),
  );

  /// The row's right-click menu: open, copy paths, and — for a directory — a
  /// tree tab rooted there. Menu position comes from the tap so the menu lands
  /// under the cursor, not under the row's corner.
  Future<void> _showRowMenu(
    BuildContext context,
    _Row row,
    Offset position,
  ) async {
    final overlay = Overlay.of(context).context.findRenderObject()
        as RenderBox;
    final color = context.dsw;
    final root = widget.workbench.workspaceRoot;
    final relative = root != null && p.isWithin(root, row.path)
        ? p.relative(row.path, from: root)
        : row.path;
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      color: color.bgLayer2,
      items: [
        PopupMenuItem(
          value: 'open',
          height: 34,
          child: Row(
            children: [
              Icon(
                row.isDirectory
                    ? LucideIcons.chevron_right
                    : LucideIcons.file,
                size: 13,
                color: color.labelSecondary,
              ),
              const SizedBox(width: 8),
              Text(context.tr('open')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copyRelative',
          height: 34,
          child: Row(
            children: [
              Icon(
                LucideIcons.copy,
                size: 13,
                color: color.labelSecondary,
              ),
              const SizedBox(width: 8),
              Text(context.tr('copyRelative')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copyAbsolute',
          height: 34,
          child: Row(
            children: [
              Icon(
                LucideIcons.file_symlink,
                size: 13,
                color: color.labelSecondary,
              ),
              const SizedBox(width: 8),
              Text(context.tr('copyAbsolute')),
            ],
          ),
        ),
        if (row.isDirectory)
          PopupMenuItem(
            value: 'treeTab',
            height: 34,
            child: Row(
              children: [
                Icon(
                  LucideIcons.list_tree,
                  size: 13,
                  color: color.labelSecondary,
                ),
                const SizedBox(width: 8),
                Text(context.tr('openInTreeTab')),
              ],
            ),
          ),
      ],
    );
    if (choice == null) return;
    switch (choice) {
      case 'open':
        if (row.isDirectory) {
          widget.workbench.toggleExpanded(row.path);
        } else {
          widget.workbench.openFile(row.path);
        }
      case 'copyRelative':
        await Clipboard.setData(ClipboardData(text: relative));
      case 'copyAbsolute':
        await Clipboard.setData(ClipboardData(text: row.path));
      case 'treeTab':
        widget.workbench.openFolder(row.path);
    }
  }

  Widget _header(DswAlias color) => Container(
    height: 28,
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
        _IconButton(
          icon: LucideIcons.refresh_cw,
          tooltip: 'Refresh',
          onTap: _refresh,
        ),
      ],
    ),
  );
}

class _TreeRow extends StatefulWidget {
  const _TreeRow({
    required this.row,
    required this.expanded,
    required this.selected,
    required this.error,
    required this.onTap,
    this.onSecondaryTap,
  });

  final _Row row;
  final bool expanded;
  final bool selected;

  /// Why this directory could not be read, shown as a tooltip on the row rather
  /// than as an alert: the row is where the user can act on it.
  final String? error;

  final VoidCallback onTap;

  /// Right-click. Null disables the menu — the plain builder rows pass it, the
  /// tests stub it out.
  final void Function(Offset position)? onSecondaryTap;

  @override
  State<_TreeRow> createState() => _TreeRowState();
}

class _TreeRowState extends State<_TreeRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final row = widget.row;
    final fill = widget.selected
        ? color.sidebarNavItemActive
        : _hovered
        ? color.sidebarNavItemHover
        : Colors.transparent;

    final content = Row(
      children: [
        SizedBox(width: 6 + row.depth * _indent),
        SizedBox.square(
          dimension: 14,
          child: Center(
            child: row.isDirectory
                ? AnimatedRotation(
                    turns: widget.expanded ? 0.25 : 0,
                    duration: DswMotion.respecting(context, DswMotion.fast),
                    curve: DswMotion.easeInOut,
                    child: Icon(
                      LucideIcons.chevron_right,
                      size: 14,
                      color: color.labelTertiary,
                    ),
                  )
                : Icon(
                    LucideIcons.file,
                    size: 11,
                    color: color.labelTertiary,
                  ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            p.basename(row.path),
            style: DswType.xs13.copyWith(
              color: widget.error != null
                  ? color.stateErrorPrimary
                  : widget.selected
                  ? color.labelPrimary
                  : color.labelSecondary,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
        const SizedBox(width: 6),
      ],
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onSecondaryTap == null
            ? null
            : (details) => widget.onSecondaryTap!(details.globalPosition),
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          // Only the failing rows and the truncated ones need a tooltip, but
          // deciding which are truncated needs a layout pass; the full path is
          // useful on every row anyway.
          message: widget.error == null
              ? row.path
              : '${row.path}\n${widget.error}',
          waitDuration: const Duration(milliseconds: 600),
          child: ColoredBox(color: fill, child: content),
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

/// A 20px square icon affordance, hover-tinted. Small enough that the shared
/// button primitives in `lib/ui/primitives/` would be more configuration than
/// code.
class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: _hovered
                  ? color.interactiveBgHover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: 13,
                color: _hovered ? color.labelSecondary : color.labelTertiary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
