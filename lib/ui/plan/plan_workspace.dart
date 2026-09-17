// The 企划 (plan) workspace — the center pane's plan-mode face (ADR-0007).
//
// An Obsidian-style vault over the CURRENT workspace root: a tree of every
// `*.md` file on the left, and a markdown editor/preview for the selected note
// on the right. The tree lives HERE, in the center pane, rather than in the
// sidebar as starkins does it — the selection has to be shared between the tree
// and the editor, and keeping both under one widget makes that state local
// instead of threading it through the sidebar's collapse machinery.
//
// The vault is whatever folder the agent workspace already uses (the same
// `workspaceRoot` the file tools are confined to) — there is no separate vault
// picker, no second permission, and no way for the two to disagree.
//
// The editor is `re_editor` in source mode with a `gpt_markdown` preview toggle
// (ADR-0007 D3: no WYSIWYG, no appflowy). The save/dirty machinery follows
// `editor_tab`'s shapes — including the one-frame-late dirty bridge, for the
// reason its own doc comment spells out.

import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';

import '../../l10n/locales.dart';
import '../../model/workspace_index.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../conversation/assistant_markdown.dart';
import '../primitives/capsule_button.dart';
import '../primitives/confirm_dialog.dart';
import '../primitives/tappable.dart';

/// The plan workspace center pane. [workspaceRoot] is the current agent
/// workspace; null means there is no vault to read yet. [onPickWorkspace]
/// is the callback for the footer's workspace switcher (may be null when
/// the parent handles switching through a different path).
class PlanWorkspace extends StatefulWidget {
  const PlanWorkspace({super.key, this.workspaceRoot, this.onPickWorkspace});

  final String? workspaceRoot;
  final VoidCallback? onPickWorkspace;

  @override
  State<PlanWorkspace> createState() => _PlanWorkspaceState();
}

class _PlanWorkspaceState extends State<PlanWorkspace> {
  /// Every `*.md` in the vault, sorted by path — the index runs off the UI
  /// thread through the same `compute` the composer's mention menu uses.
  List<FileEntry> _notes = const [];

  /// The hierarchical tree built from [_notes] + directory entries.
  List<_TreeNode> _treeNodes = const [];

  /// The selected note's workspace-relative path, or null (nothing picked yet).
  String? _selected;

  CodeLineEditingController? _controller;
  bool _dirty = false;
  bool _saving = false;

  /// The Source/Preview toggle; preview renders with the transcript's own
  /// markdown renderer so a note and a chat reply read identically.
  bool _preview = false;

  /// Expanded directory paths in the tree.
  Set<String> _expandedDirs = <String>{};

  @override
  void initState() {
    super.initState();
    _reloadVault();
  }

  @override
  void didUpdateWidget(PlanWorkspace old) {
    super.didUpdateWidget(old);
    // A workspace adopted anywhere (hero, settings) re-points the vault; the
    // selection cannot survive a root it is no longer under.
    if (widget.workspaceRoot != old.workspaceRoot) {
      _controller?.dispose();
      _controller = null;
      setState(() {
        _selected = null;
        _notes = const [];
        _treeNodes = const [];
        _expandedDirs = <String>{};
      });
      _reloadVault();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
  List<_TreeNode> _buildTree(
    List<FileEntry> mdFiles,
    List<FileEntry> allEntries,
  ) {
    final root = _TreeNode(name: '', relativePath: '', isDir: true);

    for (final file in mdFiles) {
      final parts = file.relative.split('/');
      var current = root;
      var pathSoFar = '';
      for (var i = 0; i < parts.length - 1; i++) {
        pathSoFar = pathSoFar.isEmpty ? parts[i] : '$pathSoFar/${parts[i]}';
        var child = current.children.cast<_TreeNode?>().firstWhere(
          (c) => c != null && c.name == parts[i] && c.isDir,
          orElse: () => null,
        );
        if (child == null) {
          child = _TreeNode(
            name: parts[i],
            relativePath: pathSoFar,
            isDir: true,
          );
          current.children.add(child);
        }
        current = child;
      }
      current.children.add(
        _TreeNode(name: parts.last, relativePath: file.relative, isDir: false),
      );
    }

    // Sort: directories first (alphabetical), then files (alphabetical).
    void sortChildren(_TreeNode node) {
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

  /// Selects a note, confirming away unsaved edits first — switching notes is
  /// the same cliff as the editor tab's reload: the buffer is the only copy.
  Future<void> _open(FileEntry note) async {
    if (note.relative == _selected) return;
    if (_dirty) {
      final discard = await showConfirmDialog(
        context,
        title: context.tr('planDiscardTitle'),
        description: context.tr('planDiscardDesc', {'path': note.relative}),
        confirmLabel: context.tr('discardChanges'),
      );
      if (!discard) return;
    }
    final root = widget.workspaceRoot;
    if (root == null) return;
    final text = await File(p.join(root, note.relative)).readAsString();
    if (!mounted) return;
    final old = _controller;
    setState(() {
      _selected = note.relative;
      _dirty = false;
      _preview = false;
      _controller = CodeLineEditingController.fromText(text);
    });
    old?.dispose();
  }

  Future<void> _save() async {
    final root = widget.workspaceRoot;
    final controller = _controller;
    final selected = _selected;
    if (root == null || controller == null || selected == null) return;
    setState(() => _saving = true);
    try {
      await File(p.join(root, selected)).writeAsString(controller.text);
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _dirty = false;
        });
      }
    }
  }

  void _onBufferEdited() {
    if (_dirty || _saving) return;
    setState(() => _dirty = true);
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final root = widget.workspaceRoot;
    if (root == null) {
      return _centered(
        icon: LucideIcons.book_open,
        message: context.tr('planNoWorkspace'),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _treePane(color),
        Expanded(child: _notePane(color)),
      ],
    );
  }

  Widget _centered({required IconData icon, required String message}) {
    final color = context.dsw;
    return ColoredBox(
      color: color.bgBase,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: color.labelTertiary),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: DswType.base16.copyWith(color: color.labelSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ---- The vault tree ------------------------------------------------------

  Widget _treePane(DswAlias color) => Container(
    width: 232,
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
                    context.tr('planNoNotes'),
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

  /// The tree header: "Notes" label + new-note / new-folder icon buttons.
  Widget _treeHeader(DswAlias color) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            context.tr('planNotes'),
            style: DswType.xxsStrong12.copyWith(color: color.labelSecondary),
          ),
        ),
        _treeHeaderButton(
          icon: LucideIcons.file_plus,
          tooltip: context.tr('planNewNote'),
          onTap: _onCreateNote,
          color: color,
        ),
        const SizedBox(width: 2),
        _treeHeaderButton(
          icon: LucideIcons.folder_plus,
          tooltip: context.tr('planNewFolder'),
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
      waitDuration: const Duration(milliseconds: 500),
      child: DswHoverTap(
        onTap: onTap,
        builder: (context, hovered, _) => Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: hovered ? color.interactiveBgHover : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 14, color: color.labelSecondary),
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
          Icon(LucideIcons.folder, size: 13, color: color.labelTertiary),
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
            GestureDetector(
              onTap: onPick,
              child: Tooltip(
                message: context.tr('planSwitchWorkspace'),
                waitDuration: const Duration(milliseconds: 500),
                child: Icon(
                  LucideIcons.switch_camera,
                  size: 13,
                  color: color.labelTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Recursively renders a tree node with indentation.
  Widget _renderNode(
    _TreeNode node, {
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
        selected: node.relativePath == _selected,
        onTap: () => _open(entry),
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
      context.tr('planNewNote'),
      context.tr('planNewNoteHint'),
    );
    if (name == null || name.isEmpty) return;
    final fileName = name.endsWith('.md') ? name : '$name.md';
    final relativePath = fileName;
    final fullPath = p.join(root, relativePath);
    if (await File(fullPath).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr('planFileNameExists'))));
      return;
    }
    await File(fullPath).writeAsString('');
    await _reloadVault();
    if (!mounted) return;
    final entry = _notes.cast<FileEntry?>().firstWhere(
      (e) => e != null && e.relative == relativePath,
      orElse: () => null,
    );
    if (entry != null) _open(entry);
  }

  Future<void> _onCreateFolder() async {
    final root = widget.workspaceRoot;
    if (root == null) return;
    final name = await _showNameDialog(
      context.tr('planNewFolder'),
      context.tr('planNewFolderHint'),
    );
    if (name == null || name.isEmpty) return;
    final fullPath = p.join(root, name);
    if (await Directory(fullPath).exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('planFolderNameExists'))),
      );
      return;
    }
    await Directory(fullPath).create(recursive: true);
    await _reloadVault();
  }

  Future<String?> _showNameDialog(String title, String hint) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: DswType.sStrong14),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: DswType.xxs12.copyWith(color: context.dsw.labelTertiary),
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          style: DswType.s14,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('planCancel'), style: DswType.s14),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.tr('planCreate'), style: DswType.sStrong14),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  // ---- The note editor -----------------------------------------------------

  Widget _notePane(DswAlias color) {
    final controller = _controller;
    final selected = _selected;
    if (controller == null || selected == null) {
      return _centered(
        icon: LucideIcons.file_text,
        message: context.tr('planNoNoteSelected'),
      );
    }
    return ColoredBox(
      color: color.bgBase,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(color, selected),
          Expanded(
            child: _preview
                ? _NotePreview(text: controller.text)
                : CallbackShortcuts(
                    bindings: {
                      const SingleActivator(
                        LogicalKeyboardKey.keyS,
                        meta: true,
                      ): _save,
                      const SingleActivator(
                        LogicalKeyboardKey.keyS,
                        control: true,
                      ): _save,
                    },
                    // The one-frame-late dirty bridge: re_editor notifies from
                    // inside build on mount, and a plain listener would
                    // false-positive the flag on every open. See
                    // `editor_tab.dart`'s _DirtyBridge doc for the full story.
                    child: _DirtyBridge(
                      controller: controller,
                      onDirty: _onBufferEdited,
                      child: CodeEditor(
                        controller: controller,
                        wordWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        style: CodeEditorStyle(
                          fontSize: 13,
                          fontHeight: 22 / 13,
                          fontFamily: dswFontFamilyCode,
                          fontFamilyFallback: dswFontFamilyCodeFallback,
                          textColor: color.labelPrimary,
                          backgroundColor: color.bgBase,
                          selectionColor: color.bubbleHighlight,
                          cursorColor: color.labelPrimary,
                          cursorLineColor: color.interactiveBgHover,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Filename, the unsaved chip, the Source/Preview toggle, and Save.
  Widget _toolbar(DswAlias color, String selected) {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      selected,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DswType.xs13.copyWith(
                        color: color.labelPrimary,
                        fontFamily: dswFontFamilyCode,
                        fontFamilyFallback: dswFontFamilyCodeFallback,
                      ),
                    ),
                  ),
                  if (_dirty) ...[
                    const SizedBox(width: 8),
                    Text(
                      context.tr('planUnsaved'),
                      style: DswType.xxxs11.copyWith(
                        color: color.stateWarnLabel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            CapsuleButton(
              label: _preview
                  ? context.tr('planSource')
                  : context.tr('planPreview'),
              size: CapsuleSize.sm,
              onTap: () => setState(() => _preview = !_preview),
            ),
            const SizedBox(width: 8),
            CapsuleButton(
              label: _saving ? context.tr('saving') : context.tr('save'),
              variant: CapsuleVariant.primary,
              size: CapsuleSize.sm,
              enabled: _dirty && !_saving,
              onTap: _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// A directory row in the vault tree: chevron + folder icon + name.
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
        height: 28,
        padding: EdgeInsets.only(left: indent, right: 8),
        decoration: BoxDecoration(
          color: hovered ? color.interactiveBgHover : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              expanded ? LucideIcons.chevron_down : LucideIcons.chevron_right,
              size: 12,
              color: color.labelTertiary,
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.folder, size: 13, color: color.labelTertiary),
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
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: widget.selected || hovered ? color.interactiveBgHover : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.file_text,
              size: 13,
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

/// The rendered note — the transcript's renderer, so a preview and a chat reply
/// read identically.
class _NotePreview extends StatelessWidget {
  const _NotePreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ColoredBox(
      color: color.bgBase,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: AssistantMarkdown(text),
      ),
    );
  }
}

/// The one-frame-late dirty bridge, same reason as `editor_tab`'s: re_editor
/// notifies the controller from inside build on mount, so a listener attached
/// immediately would false-positive the dirty flag on every open.
class _DirtyBridge extends StatefulWidget {
  const _DirtyBridge({
    required this.controller,
    required this.onDirty,
    required this.child,
  });

  final CodeLineEditingController controller;
  final VoidCallback onDirty;
  final Widget child;

  @override
  State<_DirtyBridge> createState() => _DirtyBridgeState();
}

class _DirtyBridgeState extends State<_DirtyBridge> {
  void _listen() => widget.onDirty();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.addListener(_listen);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// One node in the vault tree: a directory (with children) or a leaf file.
class _TreeNode {
  _TreeNode({
    required this.name,
    required this.relativePath,
    required this.isDir,
    List<_TreeNode>? children,
  }) : children = children ?? <_TreeNode>[];

  final String name;
  final String relativePath;
  final bool isDir;
  final List<_TreeNode> children;
}
