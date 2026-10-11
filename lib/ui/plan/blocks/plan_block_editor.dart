// The block editor scaffold (ADR-0037 P5): the toolbar, the slash menu — the
// only insertion path — and in-document search. The search enters read mode
// first, exactly as upstream does (`EVM:2896-2902`), and its six events are
// Query / Search / Next / Previous / Clear / Cancel (`SearchInDocEvent.kt`).
//
// Two honest scope lines for this increment, both registered in the parity
// ledger: the slash menu carries the Style / Media / Other sections — the
// Objects and Properties sections need the plan object library (P6), and the
// Alignment / Colour / Background sections are answered by the toolbar's
// selects; the Actions section is the per-block menu. The toolbar acts on the
// focused block.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadButton, ShadDialog, ShadInput, showShadDialog;

import '../../../l10n/app_localizations.dart';
import '../../../l10n/tr_key.dart';
import '../../../model/plan_block.dart';
import '../../../state/plan_block_document.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_shad_bridge.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/icon_button.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';
import 'package:plan_editor/plan_editor.dart';

import 'plan_block_drag.dart' show planAutoScrollStep;
import 'plan_block_view.dart';

class PlanBlockEditor extends StatefulWidget {
  const PlanBlockEditor({
    super.key,
    required this.document,
    required this.onSave,
    this.readOnly = false,
    this.onOpenLink,
  });

  final PlanBlockDocument document;
  final VoidCallback onSave;
  final bool readOnly;

  /// The link chip hands the URL here; the host decides how it opens
  /// (P10-d wires the system browser). Null = no chip.
  final void Function(String url)? onOpenLink;

  @override
  State<PlanBlockEditor> createState() => _PlanBlockEditorState();
}

class _PlanBlockEditorState extends State<PlanBlockEditor> {
  String? _activeBlockId;

  /// The focused field's non-empty selection — the stretch the toolbar's
  /// mark buttons act on; null once the caret collapses.
  PlanMarkRange? _activeSelection;

  /// Folded toggle blocks — session state, like upstream's `expandedToggles`:
  /// the document always carries the children, this only answers "draw them".
  final Set<String> _collapsedToggles = {};

  /// Applies a mark to the active selection, or reports there was none.
  void _applyMark(PlanMarkType type, {String? param}) {
    final blockId = _activeBlockId;
    final selection = _activeSelection;
    if (blockId == null || selection == null) return;
    widget.document.applyMark(blockId, type, selection, param: param);
  }

  /// Whether the selection already carries the mark, so a toolbar button can
  /// show the applied state (`outlined`).
  bool _hasMark(PlanMarkType type) {
    final blockId = _activeBlockId;
    final selection = _activeSelection;
    if (blockId == null || selection == null) return false;
    final content = widget.document.block(blockId)?.content;
    return content is PlanText &&
        content.marks.any(
          (mark) =>
              mark.type == type &&
              mark.range.start < selection.end &&
              selection.start < mark.range.end,
        );
  }

  /// The link URL under the selection (or the collapsed caret), if any —
  /// prefill for re-editing, the chip's target.
  String? _linkOverCaret() {
    final blockId = _activeBlockId;
    if (blockId == null) return null;
    final content = widget.document.block(blockId)?.content;
    if (content is! PlanText) return null;
    final controller = _controllers[blockId];
    final range =
        _activeSelection ??
        (controller == null || controller.value.selection.isCollapsed
            ? null
            : PlanMarkRange(
                controller.value.selection.baseOffset,
                controller.value.selection.extentOffset,
              ));
    if (range == null) return null;
    for (final mark in content.marks) {
      if (mark.type == PlanMarkType.link &&
          mark.param != null &&
          mark.param!.isNotEmpty &&
          mark.range.start < range.end &&
          range.start < mark.range.end) {
        return mark.param;
      }
    }
    return null;
  }

  /// The link mark needs a URL: one small dialog, then the mark. An existing
  /// link prefills the field; an emptied field removes the link (clearMarks,
  /// AC3-3's removal half).
  Future<void> _applyLink() async {
    final blockId = _activeBlockId;
    final selection = _activeSelection;
    if (blockId == null || selection == null || !mounted) return;
    final url = await showShadDialog<String>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        title: Text(
          AppLocalizations.of(context).planLinkPrompt,
          style: DswType.sStrong14,
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context).planCancel),
          ),
        ],
        child: _LinkInput(
          initial: _linkOverCaret(),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
      ),
    );
    if (url == null || !mounted) return;
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      widget.document.clearMarks(blockId, PlanMarkType.link, selection);
      return;
    }
    _applyMark(PlanMarkType.link, param: trimmed);
  }

  bool _searching = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<String, GlobalKey> _rowKeys = {};
  int _matchIndex = -1;
  List<String> _matches = const [];

  // The editing machinery the fields rent from the editor (ADR-0044 P10-b):
  // one plan_editor controller and one focus node per text block, owned here
  // so Enter/Backspace can move the caret ACROSS blocks. Table cells keep
  // their own plain fields — they are not part of this registry.
  final Map<String, PlanEditorController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};

  // Auto-scroll during a drag (AC3-18): the pointer position the grip
  // reports, ticked at 60ms against the viewport's edges.
  final GlobalKey _viewportKey = GlobalKey();
  Offset? _dragPosition;
  Timer? _dragTicker;

  @override
  void initState() {
    super.initState();
    widget.document.addListener(_onDocumentChanged);
    _syncEditState();
  }

  @override
  void didUpdateWidget(PlanBlockEditor old) {
    super.didUpdateWidget(old);
    if (widget.document != old.document) {
      old.document.removeListener(_onDocumentChanged);
      widget.document.addListener(_onDocumentChanged);
      _syncEditState();
    }
  }

  @override
  void dispose() {
    widget.document.removeListener(_onDocumentChanged);
    _dragTicker?.cancel();
    _searchController.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onDocumentChanged() {
    // Every document change can have minted or removed blocks (slash
    // inserts, split, merge): the rental registry follows here, outside the
    // build, so the fields always rent a controller the editor knows.
    _syncEditState();
    if (mounted) setState(() {});
  }

  void _syncEditState() {
    // Keys and rentals are kept per id: recreating them on every edit would
    // tear the fields down mid-session (new elements never see the document
    // push, and the IME would churn on every keystroke).
    final ids = _flattenedIds();
    _rowKeys.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      _rowKeys.putIfAbsent(id, () => GlobalKey(debugLabel: 'plan-row-$id'));
    }
    final textIds = _visibleTextIds().toSet();
    _controllers.removeWhere((id, controller) {
      if (textIds.contains(id)) return false;
      controller.dispose();
      return true;
    });
    _focusNodes.removeWhere((id, focusNode) {
      if (textIds.contains(id)) return false;
      focusNode.dispose();
      return true;
    });
    for (final id in textIds) {
      _controllers.putIfAbsent(id, () {
        final content = widget.document.block(id)?.content;
        return content is PlanText
            ? planFieldController(content)
            : PlanEditorController();
      });
      _focusNodes.putIfAbsent(
        id,
        () => FocusNode(debugLabel: 'plan-field-$id'),
      );
    }
  }

  List<String> _flattenedIds() => [
    for (final block in widget.document.blocks) ...block.flattenedIds,
  ];

  /// The text blocks that render a plan_editor field, in visible order —
  /// table cells are plain fields of their own and collapsed toggles hide
  /// their children.
  List<String> _visibleTextIds() {
    final ids = <String>[];
    void walk(List<PlanBlock> blocks) {
      for (final block in blocks) {
        final content = block.content;
        if (content is PlanTableBlock) continue;
        final collapsed =
            content is PlanText &&
            content.style == PlanTextStyle.toggle &&
            _collapsedToggles.contains(block.id);
        if (content is PlanText) ids.add(block.id);
        if (!collapsed) walk(block.children);
      }
    }

    walk(widget.document.blocks);
    return ids;
  }

  // ---- cross-block keyboard semantics (P10-b) ------------------------------

  /// The key events reach this handler on their way UP from the focused
  /// field, before the app-level text-editing shortcuts — so returning
  /// [KeyEventResult.handled] takes the key from the field, and `.ignored`
  /// lets the field do its default thing.
  KeyEventResult _onBlockKey(FocusNode node, KeyEvent event) {
    if (widget.readOnly || _searching) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final blockId = _activeBlockId;
    if (blockId == null) return KeyEventResult.ignored;
    final controller = _controllers[blockId];
    if (controller == null) return KeyEventResult.ignored;
    final value = controller.value;
    final composing = value.composing.isValid && !value.composing.isCollapsed;
    final key = event.logicalKey;
    final command =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;

    // The toolbar's mark set, on the keyboard (E18). K opens the link dialog.
    if (command && !composing) {
      if (key == LogicalKeyboardKey.keyB && _activeSelection != null) {
        _applyMark(PlanMarkType.bold);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyI && _activeSelection != null) {
        _applyMark(PlanMarkType.italic);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyU && _activeSelection != null) {
        _applyMark(PlanMarkType.underline);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyK && _activeSelection != null) {
        _applyLink();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyZ) {
        HardwareKeyboard.instance.isShiftPressed
            ? widget.document.redo()
            : widget.document.undo();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // An IME composition owns the field; every block-level key defers.
    if (composing) return KeyEventResult.ignored;

    final collapsedCaret = value.selection.isCollapsed
        ? value.selection.baseOffset
        : -1;
    final textLength = controller.text.length;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (!value.selection.isCollapsed) return KeyEventResult.ignored;
      final newId = widget.document.splitTextBlock(blockId, collapsedCaret);
      if (newId.isEmpty) return KeyEventResult.ignored;
      _syncEditState();
      setState(() {});
      _focusBlock(newId, 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      if (!value.selection.isCollapsed || collapsedCaret != 0) {
        return KeyEventResult.ignored;
      }
      final merged = widget.document.mergeIntoPrevious(blockId);
      if (merged == null) return KeyEventResult.ignored;
      _syncEditState();
      setState(() {});
      _focusBlock(merged.id, merged.offset);
      return KeyEventResult.handled;
    }

    final ids = _visibleTextIds();
    final index = ids.indexOf(blockId);
    if (key == LogicalKeyboardKey.arrowLeft &&
        collapsedCaret == 0 &&
        index > 0) {
      final previous = _controllers[ids[index - 1]];
      if (previous != null) _focusBlock(ids[index - 1], previous.text.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight &&
        collapsedCaret == textLength &&
        index >= 0 &&
        index < ids.length - 1) {
      _focusBlock(ids[index + 1], 0);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp && collapsedCaret == 0 && index > 0) {
      final previous = _controllers[ids[index - 1]];
      if (previous != null) _focusBlock(ids[index - 1], previous.text.length);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown &&
        collapsedCaret == textLength &&
        index >= 0 &&
        index < ids.length - 1) {
      _focusBlock(ids[index + 1], 0);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Moves the caret into [id] at [offset] once the field exists. Insert
  /// paths run ahead of the build that mints the block's controller, and a
  /// just-closed dialog's focus restoration can steal the focus back for a
  /// few frames — so the attempt sets the caret and asks for focus on every
  /// pass, retrying (bounded) until the field reports focus or the block is
  /// gone. The document's deferred sync push lands between passes; the last
  /// pass's caret wins.
  void _focusBlock(String id, int offset) {
    var attempts = 0;
    void attempt() {
      if (!mounted) return;
      final controller = _controllers[id];
      final focusNode = _focusNodes[id];
      final stillThere = widget.document.block(id) != null;
      if (controller == null || focusNode == null || !stillThere) {
        if (stillThere && attempts < 10) {
          attempts++;
          WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        }
        return;
      }
      if (focusNode.context == null && attempts < 10) {
        attempts++;
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      controller.value = TextEditingValue(
        text: controller.text,
        selection: TextSelection.collapsed(
          offset: offset.clamp(0, controller.text.length),
        ),
      );
      focusNode.requestFocus();
      if (!focusNode.hasFocus && attempts < 10) {
        attempts++;
        WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
        return;
      }
      final rowContext = _rowKeys[id]?.currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          duration: const Duration(milliseconds: 120),
          alignment: 0.2,
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => attempt());
  }

  // ---- search (the six events) --------------------------------------------

  void _searchQuery(String text) {
    _query = text.trim().toLowerCase();
    _matches = _query.isEmpty
        ? const []
        : [
            for (final id in _flattenedIds())
              if (_blockText(id).toLowerCase().contains(_query)) id,
          ];
    _matchIndex = _matches.isEmpty ? -1 : 0;
    setState(() {});
  }

  void _searchNext() => _cycle(1);

  void _searchPrevious() => _cycle(-1);

  void _cycle(int delta) {
    if (_matches.isEmpty) return;
    _matchIndex = (_matchIndex + delta) % _matches.length;
    final key = _rowKeys[_matches[_matchIndex]];
    final target = key?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 120),
        alignment: 0.2,
      );
    }
    setState(() {});
  }

  void _searchCancel() {
    _searching = false;
    _searchClear();
  }

  void _searchClear() {
    _query = '';
    _searchController.clear();
    _matches = const [];
    _matchIndex = -1;
    setState(() {});
  }

  String _blockText(String id) {
    final content = widget.document.block(id)?.content;
    return content is PlanText ? content.text : '';
  }

  // ---- drag auto-scroll (AC3-18) ------------------------------------------

  void _onDragMove(Offset globalPosition) {
    _dragPosition = globalPosition;
    _dragTicker ??= Timer.periodic(
      const Duration(milliseconds: 60),
      (_) => _tickAutoScroll(),
    );
  }

  void _onDragEnd() {
    _dragPosition = null;
    _dragTicker?.cancel();
    _dragTicker = null;
  }

  void _tickAutoScroll() {
    final position = _dragPosition;
    if (position == null) return;
    final box = _viewportKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final local = box.globalToLocal(position);
    double? scrollBy;
    if (local.dy < 0) {
      scrollBy = planAutoScrollStep(local.dy);
    } else if (local.dy > box.size.height) {
      scrollBy = -planAutoScrollStep(local.dy - box.size.height);
    } else if (local.dy <= 350) {
      scrollBy = planAutoScrollStep(local.dy);
    } else if (box.size.height - local.dy <= 350) {
      scrollBy = -planAutoScrollStep(box.size.height - local.dy);
    }
    if (scrollBy == null || scrollBy == 0) return;
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    controller.jumpTo(
      (controller.offset + scrollBy).clamp(
        controller.position.minScrollExtent,
        controller.position.maxScrollExtent,
      ),
    );
  }

  ScrollController? _scrollController;

  // ---- insertion (the slash menu) -----------------------------------------

  Future<void> _openSlash(String? afterBlockId) async {
    // The slash panel floats near the caret upstream; a centred dialog is the
    // same command-palette shape on a desktop pointer surface, and it rides
    // the dialog skin the app already themes.
    final name = await showShadDialog<String>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        title: Text(
          AppLocalizations.of(context).planAddBlock,
          style: DswType.sStrong14,
        ),
        child: SizedBox(width: 520, child: _SlashSheet()),
      ),
    );
    if (name == null || !mounted) return;
    // A typed `table(RxC)` answers with a table of that size — the pattern
    // the filter field carries, parsed and clamped by the model.
    final pattern = RegExp(r'^table\(\d+x\d+\)$').hasMatch(name.trim());
    if (pattern) {
      final size = PlanSlashItem.parseTablePattern(name);
      final id = widget.document.insertTable(
        rows: size.rows,
        columns: size.columns,
      );
      setState(() => _activeBlockId = id);
      _focusBlock(id, 0);
      return;
    }
    final item = PlanSlashItem.values
        .where((entry) => entry.name == name)
        .first;
    // The Simple table item lands a real table run — the default 3×3
    // (CreateTable's DEFAULT_ROW/COLUMN_COUNT upstream).
    if (item == PlanSlashItem.table) {
      final id = widget.document.insertTable(rows: 3, columns: 3);
      setState(() => _activeBlockId = id);
      _focusBlock(id, 0);
      return;
    }
    final id = widget.document.insertBelow(
      afterBlockId,
      _SlashSheetState.contentFor(item),
    );
    setState(() => _activeBlockId = id);
    _focusBlock(id, 0);
    // An empty bookmark is a dead card: the URL dialog is part of the same
    // insertion, the way upstream walks `SetupBookmark` right after the block
    // exists (`Orchestrator.kt:525-546`).
    if (item == PlanSlashItem.bookmark) await _editBookmarkUrl(id);
  }

  /// The bookmark's URL dialog — set on insert, re-opened from the card.
  Future<void> _editBookmarkUrl(String blockId) async {
    if (!mounted) return;
    final content = widget.document.block(blockId)?.content;
    final current = content is PlanBookmark ? content.url : null;
    final url = await showShadDialog<String>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        title: Text(
          AppLocalizations.of(context).planBookmarkPrompt,
          style: DswType.sStrong14,
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppLocalizations.of(context).planCancel),
          ),
        ],
        child: _LinkInput(
          initial: current,
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
      ),
    );
    if (url == null || !mounted) return;
    widget.document.setBookmarkUrl(blockId, url);
  }

  /// The callout's emoji picker — a curated set (the full upstream emoji.json
  /// is a registered scale difference), one dialog, write-through on tap.
  Future<void> _pickCalloutIcon(String blockId) async {
    if (!mounted) return;
    final content = widget.document.block(blockId)?.content;
    final current = content is PlanText ? content.iconEmoji : null;
    final emoji = await showShadDialog<String>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        title: Text(
          AppLocalizations.of(context).planCalloutIcon,
          style: DswType.sStrong14,
        ),
        child: SizedBox(
          width: 320,
          child: _EmojiGrid(
            current: current,
            onPick: (value) => Navigator.of(dialogContext).pop(value),
          ),
        ),
      ),
    );
    if (emoji == null || !mounted) return;
    widget.document.setCalloutIcon(blockId, emoji);
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          document: doc,
          canUndo: doc.canUndo,
          canRedo: doc.canRedo,
          activeBlockId: _activeBlockId,
          selection: _activeSelection,
          hasMark: _hasMark,
          onApplyMark: _applyMark,
          onApplyLink: _applyLink,
          searching: _searching,
          matchCount: _matches.length,
          matchIndex: _matchIndex,
          searchController: _searchController,
          onUndo: doc.undo,
          onRedo: doc.redo,
          onSearchToggle: () => _searching
              ? _searchCancel()
              : setState(() {
                  _searching = true;
                }),
          onQuery: _searchQuery,
          onNext: _searchNext,
          onPrevious: _searchPrevious,
          onCancel: _searchCancel,
          onTurnInto: (style) {
            if (_activeBlockId != null) doc.turnInto(_activeBlockId!, style);
          },
          onTextColor: (name) {
            final selection = _activeSelection;
            if (_activeBlockId != null && selection != null) {
              doc.applyMark(
                _activeBlockId!,
                PlanMarkType.textColor,
                selection,
                param: name,
              );
            } else if (_activeBlockId != null) {
              doc.setTextColor(_activeBlockId!, name);
            }
          },
          onBackground: (name) {
            final selection = _activeSelection;
            if (_activeBlockId != null && selection != null) {
              doc.applyMark(
                _activeBlockId!,
                PlanMarkType.backgroundColor,
                selection,
                param: name,
              );
            } else if (_activeBlockId != null) {
              doc.setTextBackground(_activeBlockId!, name);
            }
          },
          onAlign: (align) {
            if (_activeBlockId != null) doc.setAlign(_activeBlockId!, align);
          },
          onInsert: _openSlash,
          linkUrl: _linkOverCaret(),
          onOpenLink: widget.onOpenLink,
        ),
        Expanded(
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onBlockKey,
            child: SizedBox.expand(
              key: _viewportKey,
              child: SingleChildScrollView(
                controller: _scrollController ??= ScrollController(),
                padding: const EdgeInsets.all(DswShape.md),
                child: PlanBlockView(
                  document: doc,
                  readOnly: widget.readOnly || _searching,
                  controllerFor: (id) => _controllers[id],
                  focusNodeFor: (id) => _focusNodes[id],
                  onInsertSlash: _openSlash,
                  onFocusedBlock: (id) => setState(() => _activeBlockId = id),
                  onSelectionChanged: (id, selection) {
                    if (_activeBlockId == id || selection != null) {
                      setState(() {
                        _activeBlockId = id;
                        _activeSelection = selection;
                      });
                    }
                  },
                  keyFor: (id) => _rowKeys[id],
                  onDragMove: _onDragMove,
                  onDragEnd: _onDragEnd,
                  searchQuery: _query,
                  collapsedToggles: _collapsedToggles,
                  onToggleCollapse: (id) => setState(() {
                    if (!_collapsedToggles.remove(id)) {
                      _collapsedToggles.add(id);
                    }
                  }),
                  onEditBookmark: _editBookmarkUrl,
                  onPickCalloutIcon: _pickCalloutIcon,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.document,
    required this.canUndo,
    required this.canRedo,
    required this.activeBlockId,
    required this.selection,
    required this.hasMark,
    required this.onApplyMark,
    required this.onApplyLink,
    required this.searching,
    required this.matchCount,
    required this.matchIndex,
    required this.searchController,
    required this.onUndo,
    required this.onRedo,
    required this.onSearchToggle,
    required this.onQuery,
    required this.onNext,
    required this.onPrevious,
    required this.onCancel,
    required this.onTurnInto,
    required this.onTextColor,
    required this.onBackground,
    required this.onAlign,
    required this.onInsert,
    required this.linkUrl,
    required this.onOpenLink,
  });

  final PlanBlockDocument document;
  final bool canUndo;
  final bool canRedo;
  final String? activeBlockId;
  final PlanMarkRange? selection;
  final bool Function(PlanMarkType type) hasMark;
  final void Function(PlanMarkType type, {String? param}) onApplyMark;
  final Future<void> Function() onApplyLink;
  final bool searching;
  final int matchCount;
  final int matchIndex;
  final TextEditingController searchController;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSearchToggle;
  final void Function(String) onQuery;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onCancel;
  final void Function(PlanTextStyle) onTurnInto;
  final void Function(String?) onTextColor;
  final void Function(String?) onBackground;
  final void Function(PlanAlign) onAlign;
  final void Function(String? afterBlockId) onInsert;
  final String? linkUrl;
  final void Function(String url)? onOpenLink;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DswShape.md,
        vertical: DswShape.xs,
      ),
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(bottom: BorderSide(color: color.borderL2)),
      ),
      child: Wrap(
        spacing: DswShape.sm,
        runSpacing: DswShape.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DswIconButton(
            icon: LucideIcons.undo_2,
            tooltip: AppLocalizations.of(context).planEditorUndo,
            onTap: canUndo ? onUndo : null,
          ),
          DswIconButton(
            icon: LucideIcons.redo_2,
            tooltip: AppLocalizations.of(context).planEditorRedo,
            onTap: canRedo ? onRedo : null,
          ),
          DswIconButton(
            icon: LucideIcons.plus,
            tooltip: AppLocalizations.of(context).planAddBlock,
            onTap: () => onInsert(activeBlockId),
          ),
          if (searching) ...[
            SizedBox(
              width: 220,
              child: dswEnsureShadTheme(
                context,
                ShadInput(
                  controller: searchController,
                  autofocus: true,
                  placeholder: Text(
                    AppLocalizations.of(context).planSearchInDoc,
                    style: DswType.xs13.copyWith(color: color.labelTertiary),
                  ),
                  style: DswType.xs13,
                  onChanged: onQuery,
                ),
              ),
            ),
            Text(
              matchCount == 0 ? '0' : '${matchIndex + 1} / $matchCount',
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
            DswIconButton(
              icon: LucideIcons.chevron_up,
              tooltip: AppLocalizations.of(context).planSearchPrevious,
              onTap: matchCount > 0 ? onPrevious : null,
            ),
            DswIconButton(
              icon: LucideIcons.chevron_down,
              tooltip: AppLocalizations.of(context).planSearchNext,
              onTap: matchCount > 0 ? onNext : null,
            ),
            DswIconButton(
              icon: LucideIcons.x,
              tooltip: AppLocalizations.of(context).planSearchCancel,
              onTap: onCancel,
            ),
          ] else
            DswIconButton(
              icon: LucideIcons.search,
              tooltip: AppLocalizations.of(context).planSearchInDoc,
              onTap: onSearchToggle,
            ),
          if (!searching && activeBlockId != null && selection != null) ...[
            for (final (type, icon, tip, _) in const [
              (PlanMarkType.bold, LucideIcons.bold, 'planMarkBold', false),
              (
                PlanMarkType.italic,
                LucideIcons.italic,
                'planMarkItalic',
                false,
              ),
              (
                PlanMarkType.strikethrough,
                LucideIcons.strikethrough,
                'planMarkStrike',
                false,
              ),
              (
                PlanMarkType.underline,
                LucideIcons.underline,
                'planMarkUnderline',
                false,
              ),
              (PlanMarkType.keyboard, LucideIcons.code, 'planMarkCode', false),
              (PlanMarkType.link, LucideIcons.link, 'planMarkLink', false),
            ])
              // Applied marks read as ghost buttons; the outlined frame is
              // the "not yet on this stretch" state.
              hasMark(type)
                  ? DswIconButton(
                      icon: icon,
                      tooltip: trKey(AppLocalizations.of(context), tip),
                      onTap: type == PlanMarkType.link
                          ? onApplyLink
                          : () => onApplyMark(type),
                    )
                  : DswIconButton.outlined(
                      icon: icon,
                      tooltip: trKey(AppLocalizations.of(context), tip),
                      onTap: type == PlanMarkType.link
                          ? onApplyLink
                          : () => onApplyMark(type),
                    ),
          ],
          if (!searching &&
              activeBlockId != null &&
              selection != null &&
              onOpenLink != null &&
              linkUrl != null)
            DswHoverTap(
              onTap: () => onOpenLink!(linkUrl!),
              semanticLabel: AppLocalizations.of(context).planLinkOpen,
              builder: (context, hovered, focused) => Container(
                height: DswShape.controlMd,
                padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: hovered ? color.interactiveBgHover : color.bgLayer2,
                  borderRadius: BorderRadius.circular(DswShape.inner),
                  border: Border.all(color: color.borderL2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.external_link,
                      size: DswShape.iconTiny,
                      color: color.labelSecondary,
                    ),
                    const SizedBox(width: DswShape.xs),
                    Text(
                      AppLocalizations.of(context).planLinkOpen,
                      style: DswType.xs13.copyWith(color: color.labelSecondary),
                    ),
                  ],
                ),
              ),
            ),
          if (!searching && activeBlockId != null) ...[
            SizedBox(
              width: 132,
              child: dswEnsureShadTheme(
                context,
                _StyleSelect(
                  document: document,
                  blockId: activeBlockId!,
                  onTurnInto: onTurnInto,
                ),
              ),
            ),
            SizedBox(
              width: 116,
              child: dswEnsureShadTheme(
                context,
                _ColorSelect(
                  label: AppLocalizations.of(context).planColourLabel,
                  onPick: onTextColor,
                ),
              ),
            ),
            SizedBox(
              width: 116,
              child: dswEnsureShadTheme(
                context,
                _ColorSelect(
                  label: AppLocalizations.of(context).planColourBackground,
                  onPick: onBackground,
                ),
              ),
            ),
            for (final (align, icon, label) in const [
              (
                PlanAlign.start,
                LucideIcons.align_start_horizontal,
                'planAlignLeft',
              ),
              (
                PlanAlign.center,
                LucideIcons.align_center_horizontal,
                'planAlignCenter',
              ),
              (
                PlanAlign.end,
                LucideIcons.align_end_horizontal,
                'planAlignRight',
              ),
            ])
              DswIconButton(
                icon: icon,
                tooltip: trKey(AppLocalizations.of(context), label),
                onTap: () => onAlign(align),
              ),
          ],
        ],
      ),
    );
  }
}

class _StyleSelect extends StatelessWidget {
  const _StyleSelect({
    required this.document,
    required this.blockId,
    required this.onTurnInto,
  });

  final PlanBlockDocument document;
  final String blockId;
  final void Function(PlanTextStyle) onTurnInto;

  @override
  Widget build(BuildContext context) {
    return DswContextMenu(
      items: (_) => [
        for (final style in PlanTextStyle.insertable)
          DswMenuEntry(label: style.code, onTap: () => onTurnInto(style)),
      ],
      child: _ToolbarChip(label: AppLocalizations.of(context).planStyleLabel),
    );
  }
}

class _ColorSelect extends StatelessWidget {
  const _ColorSelect({required this.label, required this.onPick});

  final String label;
  final void Function(String?) onPick;

  @override
  Widget build(BuildContext context) {
    return DswContextMenu(
      items: (_) => [
        DswMenuEntry(
          label: AppLocalizations.of(context).planLayoutNone,
          onTap: () => onPick(null),
        ),
        for (final name in PlanThemeColors.names)
          DswMenuEntry(label: name, onTap: () => onPick(name)),
      ],
      child: _ToolbarChip(label: label),
    );
  }
}

/// A small toolbar chip that opens a context menu; icon-free on purpose, so
/// the label is its own accessible name. One line of chrome: the height
/// follows the text step (ADR-0017 S3), or the label gets cut when it grows.
class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final step = MediaQuery.textScalerOf(context).scale(1);
    return Container(
      height: DswShape.controlMd * step,
      padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.bgLayer2,
        borderRadius: BorderRadius.circular(DswShape.inner),
        border: Border.all(color: color.borderL2),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DswType.xs13.copyWith(color: color.labelSecondary),
      ),
    );
  }
}

/// The upstream label for each item (`SlashConst.kt`), through the
/// dictionaries like every other user-facing string.
String slashLabel(BuildContext context, PlanSlashItem item) => switch (item) {
  PlanSlashItem.styleText => AppLocalizations.of(context).planSlashText,
  PlanSlashItem.styleTitle => AppLocalizations.of(context).planSlashTitle,
  PlanSlashItem.styleHeading => AppLocalizations.of(context).planSlashHeading,
  PlanSlashItem.styleSubheading => AppLocalizations.of(
    context,
  ).planSlashSubheading,
  PlanSlashItem.styleHighlighted => AppLocalizations.of(
    context,
  ).planSlashHighlighted,
  PlanSlashItem.styleCallout => AppLocalizations.of(context).planSlashCallout,
  PlanSlashItem.styleCheckbox => AppLocalizations.of(context).planSlashCheckbox,
  PlanSlashItem.styleBulleted => AppLocalizations.of(context).planSlashBulleted,
  PlanSlashItem.styleNumbered => AppLocalizations.of(context).planSlashNumbered,
  PlanSlashItem.styleToggle => AppLocalizations.of(context).planSlashToggle,
  PlanSlashItem.file => AppLocalizations.of(context).planSlashFile,
  PlanSlashItem.picture => AppLocalizations.of(context).planSlashPicture,
  PlanSlashItem.video => AppLocalizations.of(context).planSlashVideo,
  PlanSlashItem.bookmark => AppLocalizations.of(context).planSlashBookmark,
  PlanSlashItem.code => AppLocalizations.of(context).planSlashCode,
  PlanSlashItem.line => AppLocalizations.of(context).planSlashLine,
  PlanSlashItem.dots => AppLocalizations.of(context).planSlashDots,
  PlanSlashItem.tableOfContents => AppLocalizations.of(context).planSlashToc,
  PlanSlashItem.table => AppLocalizations.of(context).planSlashTable,
  _ => item.name,
};

/// The slash sheet: the sections the client actually answers in this
/// increment, each item mapped onto the block it inserts.
class _SlashSheet extends StatefulWidget {
  const _SlashSheet();

  @override
  State<_SlashSheet> createState() => _SlashSheetState();
}

class _SlashSheetState extends State<_SlashSheet> {
  final _filterController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  /// The block a chosen slash item inserts. Style items answer through the
  /// model's own mapping — the single source of truth that already records
  /// "Title is H1, Highlighted is QUOTE" (the audit caught this sheet
  /// drifting from it).
  static PlanBlockContent contentFor(PlanSlashItem item) => switch (item) {
    PlanSlashItem.styleText ||
    PlanSlashItem.styleTitle ||
    PlanSlashItem.styleHeading ||
    PlanSlashItem.styleSubheading ||
    PlanSlashItem.styleHighlighted ||
    PlanSlashItem.styleCallout ||
    PlanSlashItem.styleCheckbox ||
    PlanSlashItem.styleBulleted ||
    PlanSlashItem.styleNumbered ||
    PlanSlashItem.styleToggle ||
    PlanSlashItem.code => PlanText(
      text: '',
      style: PlanSlashItem.textStyleFor(item),
      checked: item == PlanSlashItem.styleCheckbox ? false : null,
      iconEmoji: item == PlanSlashItem.styleCallout ? '💡' : null,
    ),
    PlanSlashItem.file => const PlanFile(kind: PlanFileKind.file),
    PlanSlashItem.picture => const PlanFile(kind: PlanFileKind.image),
    PlanSlashItem.video => const PlanFile(kind: PlanFileKind.video),
    PlanSlashItem.bookmark => const PlanBookmark(),
    PlanSlashItem.line => const PlanDivider(PlanDividerStyle.line),
    PlanSlashItem.dots => const PlanDivider(PlanDividerStyle.dots),
    PlanSlashItem.tableOfContents => const PlanTableOfContents(),
    PlanSlashItem.table => const PlanUnsupported('table(NxM) opens the grid'),
    _ => const PlanUnsupported(),
  };

  bool _matches(PlanSlashItem item) =>
      _query.isEmpty ||
      slashLabel(context, item).toLowerCase().contains(_query);

  /// A typed `table(RxC)` in the filter surfaces a size chip — the same
  /// command-palette answer upstream's `table(NxM)` parse feeds
  /// (`SlashExtensions.kt:308-325`).
  bool get _hasTablePattern =>
      RegExp(r'^table\(\d+x\d+\)$').hasMatch(_query.trim());

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final sections = <(String, List<PlanSlashItem>)>[
      (AppLocalizations.of(context).planSlashStyle, PlanSlashItem.styleSection),
      (AppLocalizations.of(context).planSlashMedia, PlanSlashItem.mediaSection),
      (AppLocalizations.of(context).planSlashOther, PlanSlashItem.otherSection),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dswEnsureShadTheme(
          context,
          ShadInput(
            controller: _filterController,
            autofocus: true,
            placeholder: dswInputHint(
              AppLocalizations.of(context).planSlashPlaceholder,
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
            style: DswType.s14,
            onChanged: (text) => setState(() => _query = text.toLowerCase()),
          ),
        ),
        const SizedBox(height: DswShape.sm),
        if (_hasTablePattern)
          Padding(
            padding: const EdgeInsets.only(bottom: DswShape.sm),
            child: Wrap(
              spacing: DswShape.xs,
              runSpacing: DswShape.xs,
              children: [
                DswHoverTap(
                  onTap: () => Navigator.of(context).pop(_query.trim()),
                  semanticLabel: AppLocalizations.of(context).planSlashTable,
                  builder: (context, hovered, focused) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DswShape.sm,
                      vertical: DswShape.xs,
                    ),
                    decoration: BoxDecoration(
                      color: hovered
                          ? color.interactiveBgHover
                          : color.bgLayer2,
                      borderRadius: BorderRadius.circular(DswShape.inner),
                      border: Border.all(color: color.borderL2),
                    ),
                    child: Text(
                      _query.trim(),
                      style: DswType.xs13.copyWith(
                        color: color.labelPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        for (final (title, items) in sections) ...[
          if (items.any(_matches)) ...[
            Text(
              title,
              style: DswType.xxsStrong12.copyWith(color: color.labelTertiary),
            ),
            const SizedBox(height: DswShape.xs),
            Wrap(
              spacing: DswShape.xs,
              runSpacing: DswShape.xs,
              children: [
                for (final item in items)
                  if (_matches(item))
                    DswHoverTap(
                      onTap: () => Navigator.of(context).pop(item.name),
                      semanticLabel: slashLabel(context, item),
                      builder: (context, hovered, focused) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DswShape.sm,
                          vertical: DswShape.xs,
                        ),
                        decoration: BoxDecoration(
                          color: hovered
                              ? color.interactiveBgHover
                              : color.bgLayer2,
                          borderRadius: BorderRadius.circular(DswShape.inner),
                          border: Border.all(color: color.borderL2),
                        ),
                        child: Text(
                          slashLabel(context, item),
                          style: DswType.xs13.copyWith(
                            color: color.labelPrimary,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: DswShape.md),
          ],
        ],
        if (_query.isEmpty) ...[
          Text(
            AppLocalizations.of(context).planSlashObjectsEmpty,
            style: DswType.xs13.copyWith(color: color.labelTertiary),
          ),
          const SizedBox(height: DswShape.xs),
          Text(
            AppLocalizations.of(context).planSlashPropertiesEmpty,
            style: DswType.xs13.copyWith(color: color.labelTertiary),
          ),
        ],
      ],
    );
  }
}

/// The URL field behind the link mark and the bookmark card: one input,
/// submit or button confirms.
class _LinkInput extends StatelessWidget {
  const _LinkInput({required this.onSubmitted, this.initial});

  final ValueChanged<String> onSubmitted;
  final String? initial;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final controller = TextEditingController(text: initial);
    return dswEnsureShadTheme(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadInput(
            controller: controller,
            autofocus: true,
            placeholder: dswInputHint(
              'https://',
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
            style: DswType.s14,
            onSubmitted: onSubmitted,
          ),
          const SizedBox(height: DswShape.sm),
          ShadButton(
            onPressed: () => onSubmitted(controller.text.trim()),
            child: Text(AppLocalizations.of(context).planSave),
          ),
        ],
      ),
    );
  }
}

/// The callout's emoji picker: a curated grid, not the upstream emoji.json —
/// the scale difference is registered in the parity table (🔁).
class _EmojiGrid extends StatelessWidget {
  const _EmojiGrid({required this.current, required this.onPick});

  final String? current;
  final ValueChanged<String> onPick;

  /// Cover the everyday annotation cases; order is presentation only.
  static const _emoji = [
    '💡',
    '📌',
    '📎',
    '📝',
    '✅',
    '⚠️',
    '🔥',
    '⭐',
    '❤️',
    '🎯',
    '📅',
    '🕐',
    '🚀',
    '🧠',
    '🎨',
    '📊',
    '🔗',
    '💬',
    '🏷️',
    '⚙️',
    '🧩',
    '🗂️',
    '🌱',
    '🧭',
  ];

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // The tile holds one glyph of text, so the seat grows with the text step.
    final size = 44.0 * MediaQuery.textScalerOf(context).scale(1);
    return Wrap(
      spacing: DswShape.xs,
      runSpacing: DswShape.xs,
      children: [
        for (final emoji in _emoji)
          DswHoverTap(
            onTap: () => onPick(emoji),
            semanticLabel: emoji,
            builder: (context, hovered, focused) => Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: emoji == current
                    ? color.interactiveSelected
                    : hovered
                    ? color.interactiveBgHover
                    : color.bgLayer2,
                borderRadius: BorderRadius.circular(DswShape.inner),
                border: Border.all(color: color.borderL2),
              ),
              child: Text(
                emoji,
                style: DswType.base16.copyWith(color: color.labelPrimary),
              ),
            ),
          ),
      ],
    );
  }
}
