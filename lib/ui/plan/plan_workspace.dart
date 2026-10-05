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

import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/plan_block_document.dart';
import 'blocks/plan_block_editor.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:path/path.dart' as p;
import 'package:re_editor/re_editor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/locales.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../conversation/assistant_markdown.dart';
import '../primitives/capsule_button.dart';
import '../primitives/confirm_dialog.dart';
import '../primitives/feedback.dart';

/// The plan workspace center pane. [workspaceRoot] is the current agent
/// workspace; null means there is no vault to read yet. [onPickWorkspace]
/// is the callback for the footer's workspace switcher (may be null when
/// the parent handles switching through a different path).
class PlanWorkspace extends StatefulWidget {
  const PlanWorkspace({
    super.key,
    this.workspaceRoot,
    this.onPickWorkspace,
    this.initialNote,
    this.onNoteConsumed,
  });

  /// The note the sidebar's vault tree asked to open (ADR-0073), consumed via
  /// [onNoteConsumed] once the editor has it. Null = keep whatever is open.
  final String? initialNote;
  final VoidCallback? onNoteConsumed;

  final String? workspaceRoot;
  final VoidCallback? onPickWorkspace;

  @override
  State<PlanWorkspace> createState() => _PlanWorkspaceState();
}

class _PlanWorkspaceState extends State<PlanWorkspace> {
  /// The selected note's workspace-relative path, or null (nothing picked yet).
  String? _selected;

  CodeLineEditingController? _controller;

  /// The block document the Edit mode draws — the codec's takeover of the
  /// note, decoded once on open and re-encoded on save (ADR-0037 P5).
  PlanBlockDocument? _document;
  bool _dirty = false;
  bool _saving = false;

  /// Edit draws the block editor, Source the raw markdown, Preview the
  /// transcript's own markdown renderer.
  _PlanNoteMode _mode = _PlanNoteMode.edit;

  @override
  void initState() {
    super.initState();
    _openInitialNote();
  }

  /// Opens [widget.initialNote] if one is pending (ADR-0073), then hands the
  /// token back so a later request re-triggers.
  Future<void> _openInitialNote() async {
    final note = widget.initialNote;
    if (note == null || note == _selected) return;
    await _openPath(note);
    widget.onNoteConsumed?.call();
  }

  @override
  void didUpdateWidget(PlanWorkspace old) {
    super.didUpdateWidget(old);
    // A workspace adopted anywhere (hero, settings) re-points the vault; the
    // selection cannot survive a root it is no longer under.
    if (widget.workspaceRoot != old.workspaceRoot) {
      _controller?.dispose();
      _controller = null;
      _document?.dispose();
      _document = null;
      setState(() => _selected = null);
    }
    // The sidebar tree (or a remount) asked for a note: open it, then hand
    // the token back so the next request re-triggers (ADR-0073). Deferred to
    // a post-frame callback: didUpdateWidget runs inside build, and an open
    // with unsaved edits raises the confirm dialog — an overlay insertion is
    // illegal mid-build.
    if (widget.initialNote != null &&
        widget.initialNote != _selected &&
        widget.initialNote != old.initialNote) {
      final note = widget.initialNote!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPath(note));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Selects a note, confirming away unsaved edits first — switching notes is
  /// the same cliff as the editor tab's reload: the buffer is the only copy.
  Future<void> _openPath(String relative) async {
    if (relative == _selected) return;
    if (_dirty) {
      final discard = await showConfirmDialog(
        context,
        title: context.tr('planDiscardTitle'),
        description: context.tr('planDiscardDesc', {'path': relative}),
        confirmLabel: context.tr('discardChanges'),
      );
      if (!discard) return;
    }
    final root = widget.workspaceRoot;
    if (root == null) return;
    final text = await File(p.join(root, relative)).readAsString();
    if (!mounted) return;
    final old = _controller;
    final oldDocument = _document;
    setState(() {
      _selected = relative;
      _dirty = false;
      _mode = _PlanNoteMode.edit;
      _controller = CodeLineEditingController.fromText(text);
      _document = PlanBlockDocument.fromMarkdown(text);
    });
    // Dispose AFTER the frame that swapped the editors: the CodeEditor's
    // cursor-blink timer belongs to the OLD controller and its last tick can
    // land inside the swap frame — disposing synchronously here makes the
    // timer fire on a dead object (the switching test caught it).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old?.dispose();
      oldDocument?.dispose();
    });
  }

  Future<void> _save() async {
    final root = widget.workspaceRoot;
    final controller = _controller;
    final selected = _selected;
    if (root == null || controller == null || selected == null) return;
    // Edit mode saves the block tree's encoding — the codec guarantees the
    // round trip; Source saves the raw buffer as before.
    final text = _mode == _PlanNoteMode.edit
        ? _document?.encode()
        : controller.text;
    if (text == null) return;
    setState(() => _saving = true);
    try {
      await File(p.join(root, selected)).writeAsString(text);
      if (_mode == _PlanNoteMode.source) {
        _document?.dispose();
        _document = PlanBlockDocument.fromMarkdown(text);
      }
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
    return _notePane(color);
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
            child: switch (_mode) {
              _PlanNoteMode.preview => _NotePreview(text: controller.text),
              _PlanNoteMode.edit => CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                      _save,
                  const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                      _save,
                },
                child: _DocumentBridge(
                  document: _document!,
                  onDirty: _onBufferEdited,
                  child: PlanBlockEditor(
                    document: _document!,
                    onSave: _save,
                    onOpenLink: (url) async {
                      final parsed = Uri.tryParse(url);
                      if (parsed == null || !parsed.isAbsolute) {
                        showFeedback(
                          context,
                          context.tr('planLinkFailed'),
                          destructive: true,
                        );
                        return;
                      }
                      try {
                        await launchUrl(
                          parsed,
                          mode: LaunchMode.externalApplication,
                        );
                      } catch (_) {
                        if (mounted) {
                          showFeedback(
                            context,
                            context.tr('planLinkFailed'),
                            destructive: true,
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
              _PlanNoteMode.source => CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                      _save,
                  const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                      _save,
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
            },
          ),
        ],
      ),
    );
  }

  /// Filename, the unsaved chip, the Source/Preview toggle, and Save.
  Widget _toolbar(DswAlias color, String selected) {
    return SizedBox(
      // Holds the scale's tallest button, so the bar scales with it: the sm
      // capsule is 28 at the designed step and 50.4 at 1.8x, which a fixed 44
      // would have cut in half.
      height: 44 * MediaQuery.textScalerOf(context).scale(1),
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
            // One capsule cycles the three faces and shows the current one —
            // the title bar's width budget (tree pane + filename + Save)
            // cannot carry a three-cell segmented control, and the cycle is
            // the shape the old Preview/Source toggle already had.
            CapsuleButton(
              label: switch (_mode) {
                _PlanNoteMode.edit => context.tr('planEditorEdit'),
                _PlanNoteMode.source => context.tr('planEditorSource'),
                _PlanNoteMode.preview => context.tr('planEditorPreview'),
              },
              size: CapsuleSize.sm,
              onTap: () => setState(() {
                _mode = _PlanNoteMode
                    .values[(_mode.index + 1) % _PlanNoteMode.values.length];
              }),
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

/// The block editor's dirty bridge: re-renders on every document revision and
/// raises the dirty flag once per open — undo/redo and structure edits both
/// notify, text edits notify too, and the first one after an open marks it.
class _DocumentBridge extends StatefulWidget {
  const _DocumentBridge({
    required this.document,
    required this.onDirty,
    required this.child,
  });

  final PlanBlockDocument document;
  final VoidCallback onDirty;
  final Widget child;

  @override
  State<_DocumentBridge> createState() => _DocumentBridgeState();
}

class _DocumentBridgeState extends State<_DocumentBridge> {
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    widget.document.addListener(_onDocumentChanged);
  }

  @override
  void didUpdateWidget(_DocumentBridge old) {
    super.didUpdateWidget(old);
    if (old.document != widget.document) {
      old.document.removeListener(_onDocumentChanged);
      widget.document.addListener(_onDocumentChanged);
      _seen = 0;
    }
  }

  @override
  void dispose() {
    widget.document.removeListener(_onDocumentChanged);
    super.dispose();
  }

  void _onDocumentChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.document.revision != _seen) {
      _seen = widget.document.revision;
      // Out of build first: the flag lives on PlanWorkspace, and a setState
      // during this build phase is the exception the framework forbids.
      scheduleMicrotask(widget.onDirty);
    }
    return widget.child;
  }
}

/// A directory row in the vault tree: chevron + folder icon + name.
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

/// The note surface's three faces; Edit is the block editor, Source keeps the
/// raw markdown the file actually stores, Preview reads like a chat reply.
enum _PlanNoteMode { edit, source, preview }
