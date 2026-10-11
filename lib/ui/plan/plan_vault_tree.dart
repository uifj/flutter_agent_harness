// The plan mode's vault tree (ADR-0073): an Obsidian-style file explorer over
// the current workspace root, hosted by the sidebar's extension area so it
// persists across every plan screen — the collection and library views no
// longer take the tree away with the center column.
//
// Extracted verbatim from `plan_workspace.dart` (ADR-0037's tree): the state
// (md index, built tree, expanded set) and the create-note/folder flows are
// the same code; only the home changed. The header's collection grid menu is
// deliberately NOT carried over — the sidebar extension area already lists
// every collection, and a second entry to the same door is how menus rot.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadButton, ShadDialog, ShadInput, showShadDialog;

import '../../l10n/app_localizations.dart';
import '../../model/workspace_index.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/feedback.dart';
import '../primitives/tappable.dart';

/// One node in the vault tree: a directory (with children) or a leaf file.
class PlanTreeNode {
  PlanTreeNode({
    required this.name,
    required this.relativePath,
    required this.isDir,
    List<PlanTreeNode>? children,
  }) : children = children ?? <PlanTreeNode>[];

  final String name;
  final String relativePath;
  final bool isDir;
  final List<PlanTreeNode> children;
}

/// The workspace's markdown tree. [onOpenNote] receives the picked entry; the
/// host decides what opening means (the editor confirms unsaved edits first,
/// the mode controller switches the center back to the document view).
class PlanVaultTree extends StatefulWidget {
  const PlanVaultTree({
    super.key,
    required this.workspaceRoot,
    required this.onOpenNote,
    this.onPickWorkspace,
    this.selectedPath,
    this.width = 232,
  });

  final String? workspaceRoot;
  final void Function(FileEntry entry)? onOpenNote;
  final VoidCallback? onPickWorkspace;

  /// The currently open note's workspace-relative path — the tree highlights
  /// it. Owned by the host because the editor owns "what is open".
  final String? selectedPath;

  final double width;

  @override
  State<PlanVaultTree> createState() => _PlanVaultTreeState();
}

class _PlanVaultTreeState extends State<PlanVaultTree> {
  /// Every `*.md` in the vault, sorted by path — the index runs off the UI
  /// thread through the same `compute` the composer's mention menu uses.
  List<FileEntry> _notes = const [];

  /// The hierarchical tree built from [_notes] + directory entries.
  List<PlanTreeNode> _treeNodes = const [];

  /// Expanded directory paths in the tree.
  Set<String> _expandedDirs = <String>{};

  @override
  void initState() {
    super.initState();
    _reloadVault();
  }

  @override
  void didUpdateWidget(PlanVaultTree old) {
    super.didUpdateWidget(old);
    // A workspace adopted anywhere (hero, sidebar, settings) re-points the
    // vault; the tree cannot survive a root it is no longer under.
    if (widget.workspaceRoot != old.workspaceRoot) {
      setState(() {
        _notes = const [];
        _treeNodes = const [];
        _expandedDirs = <String>{};
      });
      _reloadVault();
    }
  }

  Future<void> _reloadVault() async {
    final root = widget.workspaceRoot;
    if (root == null) return;
    final index = await compute(indexWorkspace, root);
    if (!mounted) return;
    final mdFiles = [
      for (final entry in index.entries)
        if (entry.kind == 'file' &&
            entry.relative.toLowerCase().endsWith('.md'))
          entry,
    ]..sort((a, b) => a.relative.compareTo(b.relative));
    setState(() {
      _notes = mdFiles;
      _treeNodes = _buildTree(mdFiles, index.entries);
      // Default: expand all directories that contain markdown files.
      _expandedDirs = {
        for (final entry in index.entries)
          if (entry.kind == 'dir') entry.relative,
      };
    });
  }

  /// Builds a hierarchical tree from [mdFiles] (the leaves) and [allEntries]
  /// (which includes directories). Directories that contain no `.md` files
  /// (recursively) are omitted — the tree shows only the structure needed to
  /// reach markdown files.
  List<PlanTreeNode> _buildTree(
    List<FileEntry> mdFiles,
    List<FileEntry> allEntries,
  ) {
    final root = PlanTreeNode(name: '', relativePath: '', isDir: true);

    for (final file in mdFiles) {
      final parts = file.relative.split('/');
      var current = root;
      var pathSoFar = '';
      for (var i = 0; i < parts.length - 1; i++) {
        pathSoFar = pathSoFar.isEmpty ? parts[i] : '$pathSoFar/${parts[i]}';
        var child = current.children.cast<PlanTreeNode?>().firstWhere(
          (c) => c != null && c.name == parts[i] && c.isDir,
          orElse: () => null,
        );
        if (child == null) {
          child = PlanTreeNode(
            name: parts[i],
            relativePath: pathSoFar,
            isDir: true,
          );
          current.children.add(child);
        }
        current = child;
      }
      current.children.add(
        PlanTreeNode(
          name: parts.last,
          relativePath: file.relative,
          isDir: false,
        ),
      );
    }

    // Sort: directories first (alphabetical), then files (alphabetical).
    void sortChildren(PlanTreeNode node) {
      node.children.sort((a, b) {
        if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      for (final child in node.children) {
        if (child.isDir) sortChildren(child);
      }
    }

    sortChildren(root);
    return root.children;
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(right: BorderSide(color: color.borderL1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _treeHeader(color),
          Expanded(
            child: _treeNodes.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    child: Text(
                      AppLocalizations.of(context).planNoNotes,
                      style: DswType.xxs12.copyWith(color: color.labelTertiary),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                    children: [
                      for (final node in _treeNodes)
                        _renderNode(node, depth: 0, color: color),
                    ],
                  ),
          ),
          if (widget.workspaceRoot != null) _treeFooter(color),
        ],
      ),
    );
  }

  /// The tree header: "Notes" label + new-note / new-folder icon buttons.
  Widget _treeHeader(DswAlias color) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            AppLocalizations.of(context).planNotes,
            style: DswType.xxsStrong12.copyWith(color: color.labelSecondary),
          ),
        ),
        _treeHeaderButton(
          icon: LucideIcons.file_plus,
          tooltip: AppLocalizations.of(context).planNewNote,
          onTap: _onCreateNote,
          color: color,
        ),
        const SizedBox(width: 2),
        _treeHeaderButton(
          icon: LucideIcons.folder_plus,
          tooltip: AppLocalizations.of(context).planNewFolder,
          onTap: _onCreateFolder,
          color: color,
        ),
      ],
    ),
  );

  Widget _treeHeaderButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required DswAlias color,
  }) {
    return Tooltip(
      message: tooltip,
      child: DswHoverTap(
        onTap: onTap,
        builder: (context, hovered, _) => Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: hovered ? color.interactiveBgHover : null,
            borderRadius: BorderRadius.circular(DswShape.inset),
          ),
          child: Icon(icon, size: DswShape.iconSm, color: color.labelSecondary),
        ),
      ),
    );
  }

  /// The tree footer: current workspace name + optional switch button.
  Widget _treeFooter(DswAlias color) {
    final root = widget.workspaceRoot!;
    final name = p.basename(root);
    final onPick = widget.onPickWorkspace;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.folder,
            size: DswShape.iconSm,
            color: color.labelTertiary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xxxs11.copyWith(color: color.labelTertiary),
            ),
          ),
          if (onPick != null)
            Tooltip(
              message: AppLocalizations.of(context).planSwitchWorkspace,
              child: DswHoverTap(
                onTap: onPick,
                semanticLabel: AppLocalizations.of(context).planSwitchWorkspace,
                excludeSemantics: true,
                builder: (context, hovered, focused) => Icon(
                  LucideIcons.switch_camera,
                  size: DswShape.iconSm,
                  color: hovered || focused
                      ? color.labelPrimary
                      : color.labelTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Recursively renders a tree node with indentation.
  Widget _renderNode(
    PlanTreeNode node, {
    required int depth,
    required DswAlias color,
  }) {
    final indent = 6.0 + depth * 12;
    if (node.isDir) {
      final expanded = _expandedDirs.contains(node.relativePath);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DirRow(
            name: node.name,
            expanded: expanded,
            depth: depth,
            onToggle: () => _onToggleDir(node.relativePath),
            color: color,
          ),
          if (expanded)
            for (final child in node.children)
              _renderNode(child, depth: depth + 1, color: color),
        ],
      );
    }
    final entry = FileEntry(relative: node.relativePath, kind: 'file');
    return Padding(
      padding: EdgeInsets.only(left: indent),
      child: _NoteRow(
        entry: entry,
        selected: node.relativePath == widget.selectedPath,
        onTap: () => widget.onOpenNote?.call(entry),
      ),
    );
  }

  void _onToggleDir(String path) {
    setState(() {
      if (_expandedDirs.contains(path)) {
        _expandedDirs.remove(path);
      } else {
        _expandedDirs.add(path);
      }
    });
  }

  Future<void> _onCreateNote() async {
    final root = widget.workspaceRoot;
    if (root == null) return;
    final name = await _showNameDialog(
      AppLocalizations.of(context).planNewNote,
      AppLocalizations.of(context).planNewNoteHint,
    );
    if (name == null || name.isEmpty) return;
    final fileName = name.endsWith('.md') ? name : '$name.md';
    final relativePath = fileName;
    final fullPath = p.join(root, relativePath);
    if (await File(fullPath).exists()) {
      if (!mounted) return;
      showFeedback(
        context,
        AppLocalizations.of(context).planFileNameExists,
        destructive: true,
      );
      return;
    }
    await File(fullPath).writeAsString('');
    await _reloadVault();
    if (!mounted) {
      // ignore: avoid_print
      print('DEBUG create: unmounted after reload');
      return;
    }
    // ignore: avoid_print
    print(
      'DEBUG create: notes=${_notes.length} entry=${_notes.any((e) => e.relative == relativePath)}',
    );
    final entry = _notes.cast<FileEntry?>().firstWhere(
      (e) => e != null && e.relative == relativePath,
      orElse: () => null,
    );
    if (entry != null) widget.onOpenNote?.call(entry);
  }

  Future<void> _onCreateFolder() async {
    final root = widget.workspaceRoot;
    if (root == null) return;
    final name = await _showNameDialog(
      AppLocalizations.of(context).planNewFolder,
      AppLocalizations.of(context).planNewFolderHint,
    );
    if (name == null || name.isEmpty) return;
    final fullPath = p.join(root, name);
    if (await Directory(fullPath).exists()) {
      if (!mounted) return;
      showFeedback(
        context,
        AppLocalizations.of(context).planFolderNameExists,
        destructive: true,
      );
      return;
    }
    await Directory(fullPath).create(recursive: true);
    await _reloadVault();
  }

  /// The shell is the one ADR-0002 Stage 5b mapped `showDialog`/`AlertDialog`
  /// onto: `ShadDialog` for the box, `ShadInput` for the field, `ShadButton`
  /// for both actions — outline for Cancel, filled for Create, so the two are
  /// distinguishable by weight and not only by text.
  Future<String?> _showNameDialog(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showShadDialog<String>(
      context: context,
      builder: (context) => ShadDialog(
        // The `float` tier, same reason as `primitives/confirm_dialog.dart`
        // (ADR-0029): shad's one knob carries the control tier, so a dialog has
        // to name its own.
        radius: BorderRadius.circular(DswShape.float),
        title: Text(title, style: DswType.sStrong14),
        actions: [
          ShadButton.outline(
            height: 24 * MediaQuery.textScalerOf(context).scale(1),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context).planCancel),
          ),
          ShadButton(
            height: 24 * MediaQuery.textScalerOf(context).scale(1),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(AppLocalizations.of(context).planCreate),
          ),
        ],
        child: ShadInput(
          controller: controller,
          placeholder: Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DswType.xs13.copyWith(color: context.dsw.labelTertiary),
          ),
          style: DswType.s14,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
      ),
    );
    controller.dispose();
    return result;
  }
}

class _DirRow extends StatelessWidget {
  const _DirRow({
    required this.name,
    required this.expanded,
    required this.depth,
    required this.onToggle,
    required this.color,
  });

  final String name;
  final bool expanded;
  final int depth;
  final VoidCallback onToggle;
  final DswAlias color;

  @override
  Widget build(BuildContext context) {
    final indent = 6.0 + depth * 12;
    return DswHoverTap(
      onTap: onToggle,
      builder: (context, hovered, _) => Container(
        // One label per row, so the row rides the text step: at 1.8x the folder
        // name wanted 36.0 and got 28.0.
        height: 28 * MediaQuery.textScalerOf(context).scale(1),
        padding: EdgeInsets.only(left: indent, right: 8),
        decoration: BoxDecoration(
          color: hovered ? color.interactiveBgHover : null,
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: Row(
          children: [
            Icon(
              expanded ? LucideIcons.chevron_down : LucideIcons.chevron_right,
              size: DswShape.iconTiny,
              color: color.labelTertiary,
            ),
            const SizedBox(width: 4),
            Icon(
              LucideIcons.folder,
              size: DswShape.iconSm,
              color: color.labelTertiary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.xs13.copyWith(color: color.labelSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One note in the vault tree: the basename as the row, the folder as the
/// quieter second line — the composer mention row's shape.
class _NoteRow extends StatefulWidget {
  const _NoteRow({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final FileEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NoteRow> createState() => _NoteRowState();
}

class _NoteRowState extends State<_NoteRow> {
  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final name = p.basename(widget.entry.relative);
    final directory = p.dirname(widget.entry.relative);
    return DswHoverTap(
      onTap: widget.onTap,
      toggled: widget.selected ? true : null,
      builder: (context, hovered, _) => Container(
        // Two label lines per row, so the row is sized by what they need with 34
        // as the floor rather than a pinned seat: at the system's 1.8x a pinned
        // pair overflowed its box, and scaling that box still came out 0.2 short
        // at 2.2x because the scaled line heights round up.
        constraints: BoxConstraints(
          minHeight: 34 * MediaQuery.textScalerOf(context).scale(1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: widget.selected || hovered ? color.interactiveBgHover : null,
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.file_text,
              size: DswShape.iconSm,
              color: widget.selected ? color.labelPrimary : color.labelTertiary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.xs13.copyWith(
                      color: widget.selected
                          ? color.labelPrimary
                          : color.labelSecondary,
                    ),
                  ),
                  if (directory != '.')
                    Text(
                      directory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DswType.xxxs11.copyWith(
                        color: color.labelTertiary,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
