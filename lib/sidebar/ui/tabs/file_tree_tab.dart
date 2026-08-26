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
//   * Filesystem watching. The source subscribes to host-side watch events; this
//     has a refresh control instead. A `Directory.watch` per expanded folder is a
//     real cost (one FSEvents stream each) for a panel whose staleness the user
//     can see and fix, and getting invalidation subtly wrong is worse than a
//     button.
//
// The expansion set lives in [SidebarState] rather than here, so it survives a
// tab moving between panes and a session reload. The listing cache does not: it
// is a mirror of the disk, and a stale mirror restored from a file would show
// files that were deleted while the app was closed.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:path/path.dart' as p;

import '../../../model/workspace.dart';
import '../../../theme/dsw_alias.dart';
import '../../../theme/dsw_motion.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../model/sidebar_tab.dart';
import '../../state/workbench_controller.dart';

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

  @override
  void initState() {
    super.initState();
    widget.workbench.addListener(_onWorkbench);
    _read(_root);
  }

  @override
  void dispose() {
    widget.workbench.removeListener(_onWorkbench);
    super.dispose();
  }

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
        message: 'No workspace folder is set, so there is nothing to list.',
      );
    }
    final rows = _flatten();
    final current = _currentFile;
    return Column(
      children: [
        _header(color),
        Expanded(
          child: rows.isEmpty && _failed[_root] == null
              ? _Empty(message: 'This folder is empty.')
              : ListView.builder(
                  primary: false,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemExtent: _rowHeight,
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    return _TreeRow(
                      row: row,
                      expanded: widget.workbench.state.expanded.contains(
                        row.path,
                      ),
                      selected: row.path == current,
                      error: _failed[row.path],
                      onTap: () => row.isDirectory
                          ? widget.workbench.toggleExpanded(row.path)
                          : widget.workbench.openFile(row.path),
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
  });

  final _Row row;
  final bool expanded;
  final bool selected;

  /// Why this directory could not be read, shown as a tooltip on the row rather
  /// than as an alert: the row is where the user can act on it.
  final String? error;

  final VoidCallback onTap;

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
