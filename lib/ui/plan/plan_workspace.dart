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
// (ADR-0007 D3: no WYSIWYG, no appflowy). Saving is silent autosave (ADR-0075):
// the dirty bridges keep editor_tab's shapes, but the write is a 1s trailing
// debounce plus explicit flush points — there is no save button, and the file
// on disk is the single truth both editor faces are views of.

import 'dart:io';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../model/fs_revision.dart';
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
    this.onRegisterFlush,
    this.autosaveDebounce = defaultAutosaveDebounce,
  });

  /// How long the editor waits for the next edit before the note hits the
  /// disk (ADR-0075 ①). Injectable so tests don't wait a real second.
  static const defaultAutosaveDebounce = Duration(seconds: 1);

  /// The note the sidebar's vault tree asked to open (ADR-0073), consumed via
  /// [onNoteConsumed] once the editor has it. Null = keep whatever is open.
  final String? initialNote;
  final VoidCallback? onNoteConsumed;

  /// Registers the mounted workspace's flush (immediate write) with the host:
  /// the window-close gate awaits it before destroying the window (ADR-0075 ②).
  /// Called with null on dispose. Null in tests that drive flush directly.
  final ValueChanged<Future<void> Function()?>? onRegisterFlush;

  final String? workspaceRoot;
  final VoidCallback? onPickWorkspace;

  /// Overrides [defaultAutosaveDebounce]; tests only.
  final Duration autosaveDebounce;

  @override
  State<PlanWorkspace> createState() => _PlanWorkspaceState();
}

class _PlanWorkspaceState extends State<PlanWorkspace>
    with WidgetsBindingObserver {
  /// The selected note's workspace-relative path, or null (nothing picked yet).
  String? _selected;

  CodeLineEditingController? _controller;

  /// The block document the Edit mode draws — the codec's takeover of the
  /// note, decoded once on open and re-encoded on save (ADR-0037 P5).
  PlanBlockDocument? _document;

  /// There are edits the disk has not received yet. Internal only — no chip,
  /// no button (ADR-0075 ⑥); it gates the debounce and the leave dialogs.
  bool _dirty = false;

  /// A write could not land: the external-change gate blocked it (the file
  /// was modified outside — the agent, git, another editor) or the write
  /// itself failed. The only state the chip ever shows (ADR-0075 ④).
  bool _stuck = false;

  /// One write at a time; a flush arriving mid-write re-runs once (the second
  /// edit during an in-flight write must not be lost).
  bool _persisting = false;
  bool _persistAgain = false;

  /// Set first thing in dispose: the unmount window still answers
  /// `mounted == true`, and the fire-and-forget persist must not rebuild the
  /// dying element.
  bool _disposed = false;

  /// Single-flight for the fsRevision sync (and a requeue for the bumps that
  /// landed mid-flight — same shape as the persist's rerun flag).
  bool _syncing = false;
  bool _syncQueued = false;

  /// The trailing debounce (ADR-0075 ①); null = nothing pending.
  Timer? _autosave;

  /// The disk fact at open / after our last successful write — the baseline
  /// the external-change gate compares against (ADR-0075 ④).
  FileStat? _savedStat;

  /// The bytes the disk is known to hold — the file text at open, then every
  /// text this state wrote. A persist whose text matches skips the write
  /// entirely: a mode handoff or an undo that re-derives the same content
  /// must not rewrite the file (spurious git diffs on a merely-opened note).
  String? _lastWritten;

  /// Edit draws the block editor, Source the raw markdown, Preview the
  /// transcript's own markdown renderer.
  _PlanNoteMode _mode = _PlanNoteMode.edit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fsRevision.addListener(_onFsRevision);
    widget.onRegisterFlush?.call(_flush);
    _openInitialNote();
  }

  /// The tools bump [fsRevision] after every write (and a rewind after it
  /// restores): the open note may have changed under us. Coalescing is not
  /// needed — the check is a stat — only single-flight, which [syncWithDisk]
  /// owns.
  void _onFsRevision() {
    if (_disposed || _selected == null) return;
    unawaited(_syncWithDisk());
  }

  /// Window blur / minimize on desktop lands here as a non-resumed state
  /// (ADR-0075 ②): flush. A clean buffer makes it a no-op.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_flush());
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
    // selection cannot survive a root it is no longer under. The old note's
    // pending edits leave with the old root: the persist captures its own
    // locals, so the in-flight write survives the buffers dying below.
    if (widget.workspaceRoot != old.workspaceRoot) {
      unawaited(_flush());
      _controller?.dispose();
      _controller = null;
      _document?.dispose();
      _document = null;
      setState(() => _selected = null);
    }
    if (widget.onRegisterFlush != old.onRegisterFlush) {
      widget.onRegisterFlush?.call(_flush);
    }
    // The sidebar tree (or a remount) asked for a note: open it, then hand
    // the token back so the next request re-triggers (ADR-0073). Deferred to
    // a post-frame callback: didUpdateWidget runs inside build, and opening
    // is an async swap that must not race the frame.
    if (widget.initialNote != null &&
        widget.initialNote != _selected &&
        widget.initialNote != old.initialNote) {
      final note = widget.initialNote!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPath(note));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    widget.onRegisterFlush?.call(null);
    WidgetsBinding.instance.removeObserver(this);
    fsRevision.removeListener(_onFsRevision);
    _autosave?.cancel();
    // The widget dies before the write does: the persist carries its own
    // locals, and its setState is _disposed-guarded. The window-close path
    // never lands here (close awaits the registered flush first).
    if (_dirty) unawaited(_persist(quiet: true));
    _controller?.dispose();
    super.dispose();
  }

  /// Selects a note. The current one flushes first — silently, unless the
  /// write is stuck (external change / IO failure), where a confirm dialog is
  /// the price of discarding (ADR-0075 ②④). Routine switching never asks.
  Future<void> _openPath(String relative) async {
    if (relative == _selected) return;
    if (!await _settleForLeave()) return;
    final root = widget.workspaceRoot;
    if (root == null) return;
    final text = await File(p.join(root, relative)).readAsString();
    if (!mounted) return;
    final old = _controller;
    final oldDocument = _document;
    setState(() {
      _selected = relative;
      _dirty = false;
      _stuck = false;
      _mode = _PlanNoteMode.edit;
      _autosave?.cancel();
      _autosave = null;
      _controller = CodeLineEditingController.fromText(text);
      _document = PlanBlockDocument.fromMarkdown(text);
      _savedStat = File(p.join(root, relative)).statSync();
      _lastWritten = text;
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

  /// True when it is safe to abandon the current note: flushed clean, or the
  /// user chose to discard what could not be written. A clean buffer never
  /// asks (the confirm dialog is the conflict path, not the daily one).
  Future<bool> _settleForLeave() async {
    if (!_dirty) return true;
    await _flush();
    if (!_dirty) return true;
    if (!mounted) return false;
    final proceed = await showConfirmDialog(
      context,
      title: context.tr('planStuckTitle'),
      description: context.tr('planStuckDesc', {'path': _selected ?? ''}),
      confirmLabel: context.tr('planStuckConfirm'),
    );
    if (proceed) {
      setState(() {
        _dirty = false;
        _stuck = false;
      });
    }
    return proceed;
  }

  /// Writes immediately, bypassing the debounce: the flush points of
  /// ADR-0075 ② (mode switch, note switch, blur, unmount, window close, and
  /// the Cmd+S muscle memory).
  Future<void> _flush() async {
    _autosave?.cancel();
    _autosave = null;
    if (!_dirty) return;
    await _persist();
  }

  /// The one write path (ADR-0075 ④⑤): external-change gate, then tmp+rename.
  /// Everything it touches is captured before the first await, so an in-flight
  /// write survives the note swapping underneath it.
  Future<void> _persist({bool quiet = false}) async {
    final root = widget.workspaceRoot;
    final selected = _selected;
    final document = _document;
    final controller = _controller;
    final mode = _mode;
    if (root == null ||
        selected == null ||
        document == null ||
        controller == null) {
      return;
    }
    if (_persisting) {
      _persistAgain = true;
      return;
    }
    _persisting = true;
    try {
      final text = mode == _PlanNoteMode.edit
          ? document.encode()
          : controller.text;
      if (text == _lastWritten) {
        // Nothing the disk lacks: a mode handoff or an undo re-derived the
        // same content — rewriting it would only churn the file (spurious
        // git diffs on a merely-opened note).
        _markClean();
        return;
      }
      final file = File(p.join(root, selected));
      final stat = file.existsSync() ? file.statSync() : null;
      final saved = _savedStat;
      if (stat?.modified != saved?.modified || stat?.size != saved?.size) {
        // The external-change gate: never overwrite bytes we did not write.
        // The agent, git, or another editor may own the file now.
        if (_markStuck() && !quiet && mounted) {
          showFeedback(
            context,
            context.tr('planExternalChanged'),
            destructive: true,
          );
        }
        return;
      }
      final tmp = File('${file.path}.tmp');
      await tmp.writeAsString(text, flush: true);
      // The gate is check-then-write and the write took real time — re-stat
      // before the rename. An external write that landed mid-flight must not
      // be clobbered: bail before the rename and let the fsRevision sync
      // surface it. (The rename itself stays a gap no stat can close; the
      // window is now microseconds, not the whole write.)
      final latest = file.existsSync() ? file.statSync() : null;
      if (latest?.modified != saved?.modified || latest?.size != saved?.size) {
        unawaited(tmp.delete().then((_) {}, onError: (_) {}));
        if (_markStuck() && !quiet && mounted) {
          showFeedback(
            context,
            context.tr('planExternalChanged'),
            destructive: true,
          );
        }
        return;
      }
      await tmp.rename(file.path);
      _savedStat = file.statSync();
      _lastWritten = text;
      _markClean();
    } on FileSystemException {
      if (_markStuck() && !quiet && mounted) {
        showFeedback(context, context.tr('planSaveFailed'), destructive: true);
      }
    } finally {
      _persisting = false;
    }
    // A flush that arrived while this write ran gets its own turn — the
    // second edit during an in-flight write must not be lost.
    if (_persistAgain) {
      _persistAgain = false;
      await _persist(quiet: quiet);
    }
    // Same for a revision bump the sync skipped during the write.
    if (_syncQueued && !_disposed) {
      _syncQueued = false;
      await _syncWithDisk();
    }
  }

  /// Enters the stuck state; answers whether this call was the transition —
  /// only the edge may toast (ADR-0075 ④: retries while the user keeps
  /// typing must not re-toast).
  bool _markStuck() {
    if (_stuck) return false;
    _stuck = true;
    if (!_disposed && mounted) setState(() {});
    return true;
  }

  /// The write's bookkeeping: the disk has what the buffers hold.
  void _markClean() {
    _dirty = false;
    _stuck = false;
    if (!_disposed && mounted) setState(() {});
  }

  /// The live half of the external-change story (ADR-0075 ④): the tools bump
  /// [fsRevision] after every write, so the open note may have changed under
  /// us — the AppFlowy editor's remote-apply path, localized to one file.
  /// Clean buffer → reload silently (the editor stays a live view of the
  /// file); pending edits → straight to stuck, without waiting for the
  /// debounce; vanished file → close the note instead of resurrecting it on
  /// the next write.
  Future<void> _syncWithDisk() async {
    final root = widget.workspaceRoot;
    final selected = _selected;
    if (root == null || selected == null) return;
    if (_persisting || _syncing) {
      _syncQueued = true;
      return;
    }
    _syncing = true;
    try {
      final file = File(p.join(root, selected));
      final stat = file.existsSync() ? file.statSync() : null;
      final saved = _savedStat;
      if (stat?.modified == saved?.modified && stat?.size == saved?.size) {
        return;
      }
      if (_dirty) {
        if (_markStuck() && mounted) {
          showFeedback(
            context,
            context.tr('planExternalChanged'),
            destructive: true,
          );
        }
        return;
      }
      if (stat == null) {
        // Vanished under a clean buffer: close instead of resurrecting the
        // file on the next write.
        if (!mounted || _disposed) return;
        _autosave?.cancel();
        final old = _controller;
        final oldDocument = _document;
        setState(() {
          _selected = null;
          _controller = null;
          _document = null;
          _dirty = false;
          _stuck = false;
          _savedStat = null;
          _lastWritten = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          old?.dispose();
          oldDocument?.dispose();
        });
        showFeedback(context, context.tr('planNoteVanished'));
        return;
      }
      final text = await file.readAsString();
      if (_disposed) return;
      if (text == _lastWritten) {
        // Touched, not changed: adopt the new stat so the gate stays quiet.
        _savedStat = stat;
        return;
      }
      // Raced a user edit while reading: the write gate owns the conflict.
      if (_dirty || !mounted) return;
      final old = _controller;
      final oldDocument = _document;
      setState(() {
        _controller = CodeLineEditingController.fromText(text);
        _document = PlanBlockDocument.fromMarkdown(text);
        _savedStat = stat;
        _lastWritten = text;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        old?.dispose();
        oldDocument?.dispose();
      });
    } finally {
      _syncing = false;
    }
    if (_syncQueued && !_disposed) {
      _syncQueued = false;
      await _syncWithDisk();
    }
  }

  /// The dirty edge from either bridge: shows nothing, just arms the debounce
  /// (ADR-0075 ⑥ — the pending state is internal-only). Handoff notifications
  /// that re-derive the same content are filtered by the persist's
  /// content-skip, not here — the Source face's bridge attaches a frame late,
  /// so "who heard the notification" is not knowable at this end.
  void _onBufferEdited() {
    if (!_dirty) setState(() => _dirty = true);
    _autosave?.cancel();
    _autosave = Timer(widget.autosaveDebounce, _persist);
  }

  /// The capsule cycles the three faces; each hop flushes, and the
  /// destination face rebuilds from the current truth (ADR-0075 ③) — the file
  /// is the single truth, the faces are views of it.
  Future<void> _cycleMode() async {
    await _flush();
    if (!mounted) return;
    setState(() {
      final next =
          _PlanNoteMode.values[(_mode.index + 1) % _PlanNoteMode.values.length];
      if (_mode == _PlanNoteMode.edit && next == _PlanNoteMode.source) {
        _controller!.text = _document!.encode();
      } else if (_mode == _PlanNoteMode.preview && next == _PlanNoteMode.edit) {
        if (_controller!.text == _document!.encode()) {
          // The buffer is still the document's own encoding — a glance at
          // the other faces is not an edit. Keep the instance: rebuilding
          // would throw away the undo stack for nothing.
        } else {
          // The Source face changed the text: the document re-derives from
          // the buffer, and its undo stack resets with it.
          final old = _document;
          _document = PlanBlockDocument.fromMarkdown(_controller!.text);
          WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
        }
      }
      _mode = next;
    });
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
            // The flush shortcut wraps ALL three faces: there is never
            // anything pending in Preview (the mode hop flushes), but a
            // shortcut that silently dies on one face is how muscle memory
            // learns to distrust the keyboard.
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
                    _flush,
                const SingleActivator(LogicalKeyboardKey.keyS, control: true):
                    _flush,
              },
              child: switch (_mode) {
                _PlanNoteMode.preview => _NotePreview(text: controller.text),
                _PlanNoteMode.edit => _DocumentBridge(
                  document: _document!,
                  onDirty: _onBufferEdited,
                  child: PlanBlockEditor(
                    document: _document!,
                    onSave: _flush,
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
                _PlanNoteMode.source =>
                  // The one-frame-late dirty bridge: re_editor notifies from
                  // inside build on mount, and a plain listener would
                  // false-positive the flag on every open. See
                  // `editor_tab.dart`'s _DirtyBridge doc for the full story.
                  _DirtyBridge(
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
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Filename, the stuck chip (only when a write could not land), and the
  /// mode capsule. There is no save button (ADR-0075 ⑥).
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
                  if (_stuck) ...[
                    const SizedBox(width: 8),
                    Text(
                      context.tr('planStuckChip'),
                      style: DswType.xxxs11.copyWith(
                        color: color.stateWarnLabel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // One capsule cycles the three faces and shows the current one —
            // the title bar's width budget (tree pane + filename) cannot
            // carry a three-cell segmented control, and the cycle is the
            // shape the old Preview/Source toggle already had. Each hop
            // flushes and hands the truth across (ADR-0075 ②③).
            CapsuleButton(
              label: switch (_mode) {
                _PlanNoteMode.edit => context.tr('planEditorEdit'),
                _PlanNoteMode.source => context.tr('planEditorSource'),
                _PlanNoteMode.preview => context.tr('planEditorPreview'),
              },
              size: CapsuleSize.sm,
              onTap: _cycleMode,
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
  void didUpdateWidget(_DirtyBridge old) {
    super.didUpdateWidget(old);
    // The fsRevision sync swaps in a fresh controller on reload; the listener
    // must follow it or Source-mode edits go unsaved after an agent write.
    if (widget.controller != old.controller) {
      old.controller.removeListener(_listen);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.addListener(_listen);
      });
    }
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
