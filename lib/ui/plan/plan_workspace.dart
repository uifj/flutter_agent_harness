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
/// workspace; null means there is no vault to read yet.
class PlanWorkspace extends StatefulWidget {
  const PlanWorkspace({super.key, this.workspaceRoot});

  final String? workspaceRoot;

  @override
  State<PlanWorkspace> createState() => _PlanWorkspaceState();
}

class _PlanWorkspaceState extends State<PlanWorkspace> {
  /// Every `*.md` in the vault, sorted by path — the index runs off the UI
  /// thread through the same `compute` the composer's mention menu uses.
  List<FileEntry> _notes = const [];

  /// The selected note's workspace-relative path, or null (nothing picked yet).
  String? _selected;

  CodeLineEditingController? _controller;
  bool _dirty = false;
  bool _saving = false;

  /// The Source/Preview toggle; preview renders with the transcript's own
  /// markdown renderer so a note and a chat reply read identically.
  bool _preview = false;

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
    setState(() {
      _notes = [
        for (final entry in index.entries)
          if (entry.kind == 'file' &&
              entry.relative.toLowerCase().endsWith('.md'))
            entry,
      ]..sort((a, b) => a.relative.compareTo(b.relative));
    });
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
          child: Text(
            context.tr('planNotes'),
            style: DswType.xxsStrong12.copyWith(color: color.labelSecondary),
          ),
        ),
        Expanded(
          child: _notes.isEmpty
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
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return _NoteRow(
                      entry: note,
                      selected: note.relative == _selected,
                      onTap: () => _open(note),
                    );
                  },
                ),
        ),
      ],
    ),
  );

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
