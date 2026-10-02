// The block renderer (ADR-0037 P5). It draws `PlanBlock` the way Anytype's
// Android client answers for each shape, not the way the wire vocabulary
// wishes:
//
// - `H4` renders as H3 (upstream falls through to `headerThree`);
// - `QUOTE` renders as the highlighted block the slash menu inserts;
// - `ROW`/`COLUMN` flatten to the same indent (mobile renders no side-by-side);
// - embeds render as placeholder cards, LaTeX renders but is not insertable;
// - a `DESCRIPTION` row renders only when the text is non-empty (a system row);
// - table rows are the markdown codec's consecutive `PlanTableBlock` run.
//
// Text fields own their controllers: the document notifies on every edit, and
// the field syncs from the tree only when it is not the origin of the change —
// otherwise typing fights the rebuild.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'package:shadcn_ui/shadcn_ui.dart' show ShadInput;

import 'package:plan_editor/plan_editor.dart';

import '../../../l10n/locales.dart';
import '../../../model/plan_block.dart';

import '../../../state/plan_block_document.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_shad_bridge.dart'
    show dswBareInput, dswEnsureShadTheme;
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';
import '../dataview/plan_cell_value.dart' show planLadderColor;
import '../dataview/plan_viewers.dart' show PlanCheckbox;
import 'plan_block_actions.dart';

/// The indentation step for one nesting level — the visual answer to
/// `SupportNesting` upstream, one shape for every list style.
const _kIndentStep = 18.0;

class PlanBlockView extends StatelessWidget {
  const PlanBlockView({
    super.key,
    required this.document,
    required this.readOnly,
    this.onInsertSlash,
    this.onFocusedBlock,
    this.onSelectionChanged,
    this.keyFor,
    this.searchQuery,
    this.collapsedToggles = const {},
    this.onToggleCollapse,
    this.onEditBookmark,
    this.onPickCalloutIcon,
  });

  final PlanBlockDocument document;

  /// Read mode (and the locked answer): blocks draw, affordances go.
  final bool readOnly;

  /// Opens the slash menu for an insertion anchored at [afterBlockId].
  final void Function(String? afterBlockId)? onInsertSlash;

  /// The editor learns which block the caret is in, so the toolbar's
  /// style/colour/alignment controls answer the block being edited.
  final void Function(String blockId)? onFocusedBlock;

  /// A text field's non-empty selection bubbles up here so the toolbar's
  /// mark buttons can act on the highlighted stretch.
  final void Function(String blockId, PlanMarkRange? selection)?
  onSelectionChanged;

  /// Stable row keys the editor's search scrolls to; null draws keyless.
  final Key? Function(String blockId)? keyFor;

  /// In-document search: the active query (already lowercased).
  final String? searchQuery;

  /// Toggle blocks whose children are folded away. Session state of the
  /// editor, not of the document — upstream keeps the same split
  /// (the tree always carries the children; folding is view state).
  final Set<String> collapsedToggles;
  final void Function(String blockId)? onToggleCollapse;

  /// Opens the URL dialog for a bookmark block (edit face only).
  final void Function(String blockId)? onEditBookmark;

  /// Opens the emoji picker for a callout block (edit face only).
  final void Function(String blockId)? onPickCalloutIcon;

  @override
  Widget build(BuildContext context) {
    final blocks = document.blocks;
    final headings = [
      for (final block in blocks)
        if (block.content is PlanText &&
            (block.content as PlanText).style.isHeading)
          block,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, block) in blocks.indexed) ...[
          PlanBlockRow(
            key: keyFor?.call(block.id),
            document: document,
            block: block,
            indent: 0,
            ordinal: planNumberedOrdinal(blocks, index),
            readOnly: readOnly,
            onInsertSlash: onInsertSlash,
            onFocusedBlock: onFocusedBlock,
            onSelectionChanged: onSelectionChanged,
            headings: headings,
            searchQuery: searchQuery,
            collapsedToggles: collapsedToggles,
            onToggleCollapse: onToggleCollapse,
            onEditBookmark: onEditBookmark,
            onPickCalloutIcon: onPickCalloutIcon,
          ),
        ],
        if (!readOnly) _AddBlockRow(onTap: () => onInsertSlash?.call(null)),
      ],
    );
  }
}

/// The 1-based position of a numbered block inside its run of consecutive
/// numbered siblings. The model stores no counter (the disk form is a plain
/// `1. ` line anyway), so the renderer counts — an interrupted run restarts.
int planNumberedOrdinal(List<PlanBlock> siblings, int index) {
  var ordinal = 1;
  for (var i = index - 1; i >= 0; i--) {
    final content = siblings[i].content;
    if (content is PlanText && content.style == PlanTextStyle.numbered) {
      ordinal++;
    } else {
      break;
    }
  }
  return ordinal;
}

/// One block: the hover gutter (add below, actions), the body by content type,
/// then the nested children at one step deeper.
class PlanBlockRow extends StatelessWidget {
  const PlanBlockRow({
    super.key,
    required this.document,
    required this.block,
    required this.indent,
    required this.readOnly,
    required this.headings,
    this.ordinal,
    this.onInsertSlash,
    this.onFocusedBlock,
    this.onSelectionChanged,
    this.keyFor,
    this.searchQuery,
    this.collapsedToggles = const {},
    this.onToggleCollapse,
    this.onEditBookmark,
    this.onPickCalloutIcon,
  });

  final PlanBlockDocument document;
  final PlanBlock block;
  final double indent;

  /// Set when this block is a numbered run member; null renders no counter.
  final int? ordinal;
  final bool readOnly;
  final void Function(String? afterBlockId)? onInsertSlash;
  final void Function(String blockId)? onFocusedBlock;
  final void Function(String blockId, PlanMarkRange? selection)?
  onSelectionChanged;

  /// Passed down so a match at any depth has a context the search can scroll
  /// to.
  final Key? Function(String blockId)? keyFor;
  final List<PlanBlock> headings;
  final String? searchQuery;
  final Set<String> collapsedToggles;
  final void Function(String blockId)? onToggleCollapse;
  final void Function(String blockId)? onEditBookmark;
  final void Function(String blockId)? onPickCalloutIcon;

  @override
  Widget build(BuildContext context) {
    final content = block.content;
    final isCollapsedToggle =
        content is PlanText &&
        content.style == PlanTextStyle.toggle &&
        collapsedToggles.contains(block.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: _BlockBody(
            document: document,
            block: block,
            ordinal: ordinal,
            readOnly: readOnly,
            onInsertSlash: onInsertSlash,
            onFocusedBlock: onFocusedBlock,
            onSelectionChanged: onSelectionChanged,
            headings: headings,
            searchQuery: searchQuery,
            collapsed: isCollapsedToggle,
            onToggleCollapse: onToggleCollapse,
            onEditBookmark: onEditBookmark,
            onPickCalloutIcon: onPickCalloutIcon,
          ),
        ),
        // Layout containers carry no view of their own (the client flattens
        // them — `DefaultBlockViewRenderer.kt:660-684`): the children draw at
        // the same visual level, one step in.
        if (content is PlanLayout)
          for (final (index, child) in block.children.indexed)
            PlanBlockRow(
              key: keyFor?.call(child.id),
              document: document,
              block: child,
              indent: indent + _kIndentStep,
              ordinal: planNumberedOrdinal(block.children, index),
              readOnly: readOnly,
              onInsertSlash: onInsertSlash,
              onFocusedBlock: onFocusedBlock,
              onSelectionChanged: onSelectionChanged,
              headings: headings,
              searchQuery: searchQuery,
              collapsedToggles: collapsedToggles,
              onToggleCollapse: onToggleCollapse,
              onEditBookmark: onEditBookmark,
              onPickCalloutIcon: onPickCalloutIcon,
            ),
        if (content is! PlanLayout &&
            content is! PlanTableBlock &&
            !isCollapsedToggle)
          for (final (index, child) in block.children.indexed)
            PlanBlockRow(
              key: keyFor?.call(child.id),
              document: document,
              block: child,
              indent: indent + _kIndentStep,
              ordinal: planNumberedOrdinal(block.children, index),
              readOnly: readOnly,
              onInsertSlash: onInsertSlash,
              onFocusedBlock: onFocusedBlock,
              onSelectionChanged: onSelectionChanged,
              headings: headings,
              searchQuery: searchQuery,
              collapsedToggles: collapsedToggles,
              onToggleCollapse: onToggleCollapse,
              onEditBookmark: onEditBookmark,
              onPickCalloutIcon: onPickCalloutIcon,
            ),
      ],
    );
  }
}

class _BlockBody extends StatelessWidget {
  const _BlockBody({
    required this.document,
    required this.block,
    required this.readOnly,
    required this.headings,
    this.ordinal,
    this.onInsertSlash,
    this.onFocusedBlock,
    this.onSelectionChanged,
    this.searchQuery,
    this.collapsed = false,
    this.onToggleCollapse,
    this.onEditBookmark,
    this.onPickCalloutIcon,
  });

  final PlanBlockDocument document;
  final PlanBlock block;
  final int? ordinal;
  final bool readOnly;
  final void Function(String? afterBlockId)? onInsertSlash;
  final void Function(String blockId)? onFocusedBlock;
  final void Function(String blockId, PlanMarkRange? selection)?
  onSelectionChanged;
  final List<PlanBlock> headings;
  final String? searchQuery;

  /// A collapsed toggle hides its children (the row above skips them); the
  /// chevron reads it, the tap bubbles to the editor.
  final bool collapsed;
  final void Function(String blockId)? onToggleCollapse;
  final void Function(String blockId)? onEditBookmark;
  final void Function(String blockId)? onPickCalloutIcon;

  @override
  Widget build(BuildContext context) {
    final content = block.content;
    switch (content) {
      case PlanText():
        return _TextBlock(
          document: document,
          block: block,
          content: content,
          ordinal: ordinal,
          readOnly: readOnly,
          onFocusedBlock: onFocusedBlock,
          onSelectionChanged: onSelectionChanged,
          searchQuery: searchQuery,
          collapsed: collapsed,
          onToggleCollapse: onToggleCollapse,
          onPickCalloutIcon: onPickCalloutIcon,
        );
      case PlanLayout():
        // Flattened by the row above; nothing to draw here.
        return const SizedBox.shrink();
      case PlanDivider(:final style):
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: DswShape.sm),
          child: style == PlanDividerStyle.dots
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < 5; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: DswShape.xs),
                        child: Icon(
                          LucideIcons.circle,
                          size: DswShape.iconCaption,
                          color: context.dsw.labelTertiary,
                        ),
                      ),
                  ],
                )
              : ColoredBox(
                  color: context.dsw.borderL2,
                  child: const SizedBox(height: 1, width: double.infinity),
                ),
        );
      case PlanFile(:final kind, :final state, :final name):
        return _FileBlock(kind: kind, state: state, name: name);
      case PlanBookmark(:final url, :final state):
        return _BookmarkBlock(
          url: url,
          state: state,
          readOnly: readOnly,
          onTap: readOnly ? null : () => onEditBookmark?.call(block.id),
        );
      case PlanLink(:final target, :final cardStyle, :final description):
        return _LinkBlock(
          document: document,
          target: target,
          cardStyle: cardStyle,
          description: description,
        );
      case PlanLatex(:final source):
        return _LatexBlock(source: source);
      case PlanEmbed(:final processor, :final target):
        return _EmbedBlock(processor: processor, target: target);
      case PlanRelationBlock(:final key):
        return _ChipBlock(
          icon: LucideIcons.link,
          label: context.tr('planBlockRelation'),
          detail: key ?? '',
        );
      case PlanFeaturedRelations():
        return _ChipBlock(
          icon: LucideIcons.list,
          label: context.tr('planBlockFeatured'),
          detail: '',
        );
      case PlanTableOfContents():
        return _TocBlock(headings: headings);
      case PlanTableBlock():
        return _TableRowBlock(
          document: document,
          block: block,
          readOnly: readOnly,
        );
      case PlanWidgetBlock(:final layout):
        return _ChipBlock(
          icon: LucideIcons.layout_dashboard,
          label: context.tr('planBlockWidget'),
          detail: layout.name,
        );
      case PlanUnsupported(:final reason):
        return _ChipBlock(
          icon: LucideIcons.circle_alert,
          label: context.tr('planBlockUnsupported'),
          detail: reason,
        );
      case PlanRawLine(:final source):
        // Lossless passthrough: the source line as it was read, verbatim.
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
          child: Text(
            source,
            style: DswType.xs13.copyWith(
              color: context.dsw.labelTertiary,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
    }
  }
}

// ---- text ----------------------------------------------------------------

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.document,
    required this.block,
    required this.content,
    required this.readOnly,
    this.ordinal,
    this.onFocusedBlock,
    this.onSelectionChanged,
    this.searchQuery,
    this.collapsed = false,
    this.onToggleCollapse,
    this.onPickCalloutIcon,
  });

  final PlanBlockDocument document;
  final PlanBlock block;
  final PlanText content;
  final int? ordinal;
  final bool readOnly;
  final void Function(String blockId)? onFocusedBlock;
  final void Function(String blockId, PlanMarkRange? selection)?
  onSelectionChanged;
  final String? searchQuery;
  final bool collapsed;
  final void Function(String blockId)? onToggleCollapse;
  final void Function(String blockId)? onPickCalloutIcon;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final step = MediaQuery.textScalerOf(context).scale(1);
    // H4 renders as H3 — upstream falls through to headerThree
    // (`DefaultBlockViewRenderer.kt:308-347`).
    final effectiveStyle = content.style == PlanTextStyle.h4
        ? PlanTextStyle.h3
        : content.style;

    if (readOnly) {
      return _TextReadView(
        content: content,
        style: effectiveStyle,
        ordinal: ordinal,
        collapsed: collapsed,
        onToggleCollapse: onToggleCollapse,
        blockId: block.id,
        searchQuery: searchQuery,
      );
    }

    Widget? prefix;
    if (effectiveStyle == PlanTextStyle.checkbox) {
      prefix = Padding(
        padding: const EdgeInsets.only(top: 2, right: DswShape.xs),
        child: PlanCheckbox(
          checked: content.checked ?? false,
          onTap: () => document.toggleCheckbox(block.id),
        ),
      );
    } else if (effectiveStyle == PlanTextStyle.bullet) {
      prefix = Padding(
        padding: EdgeInsets.only(top: 10 * step, right: DswShape.sm),
        child: Icon(
          LucideIcons.circle,
          size: DswShape.iconCaption,
          color: color.labelTertiary,
        ),
      );
    } else if (effectiveStyle == PlanTextStyle.numbered && ordinal != null) {
      prefix = Padding(
        padding: EdgeInsets.only(top: 3 * step, right: DswShape.sm),
        child: Text(
          '$ordinal.',
          style: DswType.xs13.copyWith(color: color.labelTertiary),
        ),
      );
    } else if (effectiveStyle == PlanTextStyle.toggle) {
      prefix = DswHoverTap(
        onTap: () => onToggleCollapse?.call(block.id),
        semanticLabel: context.tr('planBlockToggle'),
        builder: (context, hovered, focused) => Padding(
          padding: const EdgeInsets.only(top: 3, right: DswShape.xs),
          child: Icon(
            collapsed ? LucideIcons.chevron_right : LucideIcons.chevron_down,
            size: DswShape.iconSm,
            color: color.labelTertiary,
          ),
        ),
      );
    }

    final fieldChild = _BlockTextField(
      document: document,
      blockId: block.id,
      content: content,
      style: effectiveStyle,
      onFocusedBlock: onFocusedBlock,
      onSelectionChanged: onSelectionChanged,
    );

    Widget field;
    // The callout is a container block: tinted card, the emoji as a leading
    // chip the user can tap to change (upstream edits it through the block
    // menu; the chip is the same command, one surface earlier).
    if (effectiveStyle == PlanTextStyle.callout) {
      field = Container(
        padding: const EdgeInsets.all(DswShape.sm),
        decoration: BoxDecoration(
          color: color.bgLayer2,
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: _FieldRow(
          prefix: DswHoverTap(
            onTap: () => onPickCalloutIcon?.call(block.id),
            semanticLabel: context.tr('planCalloutIcon'),
            builder: (context, hovered, focused) => Padding(
              padding: const EdgeInsets.only(right: DswShape.sm),
              child: SizedBox(
                width: DswShape.iconLg,
                child: Text(
                  content.iconEmoji ?? '＋',
                  textAlign: TextAlign.center,
                  style: DswType.base16.copyWith(color: color.labelPrimary),
                ),
              ),
            ),
          ),
          child: fieldChild,
        ),
      );
    } else {
      field = _FieldRow(prefix: prefix, child: fieldChild);
      // HIGHLIGHT (quote) draws a brand rule along the row — the one visual
      // answer a non-WYSIWYG field can still give the style.
      if (effectiveStyle == PlanTextStyle.quote) {
        field = DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: color.brandPrimary, width: 2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: DswShape.sm),
            child: field,
          ),
        );
      }
    }

    return _BlockChrome(
      document: document,
      block: block,
      readOnly: readOnly,
      child: field,
    );
  }
}

/// The hover chrome a block carries in edit mode: a plus that opens the slash
/// menu below this block, and the actions menu.
class _BlockChrome extends StatefulWidget {
  const _BlockChrome({
    required this.document,
    required this.block,
    required this.readOnly,
    required this.child,
  });

  final PlanBlockDocument document;
  final PlanBlock block;
  final bool readOnly;
  final Widget child;

  @override
  State<_BlockChrome> createState() => _BlockChromeState();
}

class _BlockChromeState extends State<_BlockChrome> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.readOnly) return widget.child;
    final color = context.dsw;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: widget.child),
          if (_hovered)
            DswContextMenu(
              items: (menuContext) =>
                  planBlockActions(menuContext, widget.document, widget.block),
              child: DswHoverTap(
                onTap: null,
                semanticLabel: context.tr('planBlockMenu'),
                builder: (context, hovered, focused) => Padding(
                  padding: const EdgeInsets.only(left: DswShape.xs),
                  child: Icon(
                    LucideIcons.ellipsis_vertical,
                    size: DswShape.iconTiny,
                    color: color.labelTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({this.prefix, required this.child});

  final Widget? prefix;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (prefix == null) return child;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        prefix!,
        Expanded(child: child),
      ],
    );
  }
}

/// One text field per block. Marks render through the field's styling of the
/// current text is out of scope for a TextField — the read view shows them;
/// the edit view keeps the plain text and the toolbar writes ranges.
class _BlockTextField extends StatefulWidget {
  const _BlockTextField({
    required this.document,
    required this.blockId,
    required this.content,
    required this.style,
    this.onFocusedBlock,
    this.onSelectionChanged,
  });

  final PlanBlockDocument document;
  final String blockId;
  final PlanText content;
  final PlanTextStyle style;
  final void Function(String blockId)? onFocusedBlock;

  /// The caret's non-empty selection, so the toolbar's mark buttons can act
  /// on the highlighted stretch; null when the caret is collapsed.
  final void Function(String blockId, PlanMarkRange? selection)?
  onSelectionChanged;

  @override
  State<_BlockTextField> createState() => _BlockTextFieldState();
}

class _BlockTextFieldState extends State<_BlockTextField> {
  // The plan_editor field controller (ADR-0044): it carries the block's
  // marks and renders them while the caret is inside. Typing flows out
  // through `editTextWithMarks` (the controller is the shift engine);
  // document-driven changes flow back in through `sync`.
  late final PlanEditorController _controller = PlanEditorController(
    text: widget.content.text,
    marks: _marksFor(widget.content),
  )..styleResolver = _resolveEditorStyle;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_reportSelection);
  }

  void _reportSelection() {
    final callback = widget.onSelectionChanged;
    if (callback == null) return;
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) {
      callback(widget.blockId, null);
    } else {
      callback(widget.blockId, PlanMarkRange(selection.start, selection.end));
    }
  }

  @override
  void didUpdateWidget(_BlockTextField old) {
    super.didUpdateWidget(old);
    // The document notifies on every edit; a rebuild that did not come from
    // this field's own typing (undo, toolbar, another field) mirrors the
    // document back in. `sync` keeps the caret on a marks-only push and
    // no-ops when the content already agrees.
    _controller.sync(_attributedOf(widget.content));
  }

  @override
  void dispose() {
    _controller.removeListener(_reportSelection);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final align = switch (widget.content.align) {
      PlanAlign.center => TextAlign.center,
      PlanAlign.end => TextAlign.right,
      _ => TextAlign.start,
    };
    return Focus(
      onFocusChange: (focused) {
        if (focused) widget.onFocusedBlock?.call(widget.blockId);
      },
      child: dswEnsureShadTheme(
        context,
        ShadInput(
          controller: _controller,
          maxLines: null,
          textAlign: align,
          style: _textStyle(context, widget.style).copyWith(
            color: widget.content.color != null
                ? planLadderColor(color, _ladderIndex(widget.content.color!))
                : null,
          ),
          decoration: dswBareInput,
          padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
          onChanged: (text) => widget.document.editTextWithMarks(
            widget.blockId,
            text,
            _planMarksOf(_controller),
          ),
        ),
      ),
    );
  }
}

// ---- PlanMark ⇄ EditorMark (the app side of ADR-0044's mapping) ----------

AttributedText _attributedOf(PlanText content) {
  final attributed = AttributedText(content.text);
  for (final mark in content.marks) {
    final editor = _editorMarkOf(mark);
    if (editor == null || mark.range.end <= mark.range.start) continue;
    attributed.addAttribution(
      editor,
      SpanRange(mark.range.start, mark.range.end - 1),
      overwriteConflictingSpans: true,
    );
  }
  return attributed;
}

List<EditorMarkRange> _marksFor(PlanText content) => [
  for (final mark in content.marks)
    if (_editorMarkOf(mark) case final EditorMark editor)
      if (mark.range.end > mark.range.start)
        EditorMarkRange(editor, mark.range.start, mark.range.end),
];

EditorMark? _editorMarkOf(PlanMark mark) => switch (mark.type) {
  PlanMarkType.bold => EditorMark.bold,
  PlanMarkType.italic => EditorMark.italic,
  PlanMarkType.underline => EditorMark.underline,
  PlanMarkType.strikethrough => EditorMark.strikethrough,
  PlanMarkType.keyboard => EditorMark.keyboard,
  PlanMarkType.link =>
    mark.param == null || mark.param!.isEmpty
        ? null
        : EditorMark.link(mark.param!),
  PlanMarkType.textColor =>
    mark.param == null ? null : EditorMark.textColor(mark.param!),
  PlanMarkType.backgroundColor =>
    mark.param == null ? null : EditorMark.background(mark.param!),
  // Mention/emoji/object are the renderer's marks; the field carries none.
  _ => null,
};

List<PlanMark> _planMarksOf(PlanEditorController controller) {
  final marks = <PlanMark>[];
  for (final range in controller.marks) {
    final mark = range.mark;
    final PlanMarkType type;
    if (mark == EditorMark.bold) {
      type = PlanMarkType.bold;
    } else if (mark == EditorMark.italic) {
      type = PlanMarkType.italic;
    } else if (mark == EditorMark.underline) {
      type = PlanMarkType.underline;
    } else if (mark == EditorMark.strikethrough) {
      type = PlanMarkType.strikethrough;
    } else if (mark == EditorMark.keyboard) {
      type = PlanMarkType.keyboard;
    } else if (mark.id == EditorMark.linkId) {
      type = PlanMarkType.link;
    } else if (mark.id == 'textColor') {
      type = PlanMarkType.textColor;
    } else if (mark.id == 'background') {
      type = PlanMarkType.backgroundColor;
    } else {
      continue;
    }
    marks.add(
      PlanMark(
        range: PlanMarkRange(range.start, range.end),
        type: type,
        param: mark.param,
      ),
    );
  }
  marks.sort((a, b) => a.range.start.compareTo(b.range.start));
  return marks;
}

/// The host's style answer for the field (ADR-0044: the package stays
/// colour-blind). Mirrors the read view's `_markSpan` choices.
TextStyle _resolveEditorStyle(BuildContext context, Set<Attribution> marks) {
  final dsw = context.dsw;
  var style = const TextStyle();
  final decorations = <TextDecoration>[];
  void addDecoration(TextDecoration line) {
    if (!decorations.contains(line)) decorations.add(line);
  }

  for (final mark in marks) {
    if (mark is! EditorMark) continue;
    if (mark == EditorMark.bold) {
      style = style.copyWith(fontWeight: FontWeight.w600);
    }
    if (mark == EditorMark.italic) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    if (mark == EditorMark.underline) addDecoration(TextDecoration.underline);
    if (mark == EditorMark.strikethrough) {
      addDecoration(TextDecoration.lineThrough);
    }
    if (mark == EditorMark.keyboard) {
      style = style.copyWith(
        fontFamily: 'SF Mono',
        fontFamilyFallback: const ['JetBrains Mono', 'Menlo', 'monospace'],
      );
    }
    if (mark.id == EditorMark.linkId) {
      style = style.copyWith(color: dsw.brandPrimary);
      addDecoration(TextDecoration.underline);
    }
    if (mark.id == 'textColor') {
      style = style.copyWith(
        color: planLadderColor(
          dsw,
          PlanThemeColors.names.indexOf(mark.param ?? ''),
        ),
      );
    }
    if (mark.id == 'background') {
      style = style.copyWith(
        background: Paint()
          ..color = planLadderColor(
            dsw,
            PlanThemeColors.names.indexOf(mark.param ?? ''),
          ),
      );
    }
  }
  if (decorations.isNotEmpty) {
    style = style.copyWith(decoration: TextDecoration.combine(decorations));
  }
  return style;
}

TextStyle _textStyle(BuildContext context, PlanTextStyle style) {
  final dsw = context.dsw;
  return switch (style) {
    PlanTextStyle.title => DswType.heroTitle26.copyWith(
      color: dsw.labelPrimary,
    ),
    PlanTextStyle.h1 => DswType.l20.copyWith(color: dsw.labelPrimary),
    PlanTextStyle.h2 ||
    PlanTextStyle.h4 => DswType.brand18.copyWith(color: dsw.labelPrimary),
    PlanTextStyle.h3 => DswType.panelHeadline15.copyWith(
      color: dsw.labelPrimary,
    ),
    PlanTextStyle.codeSnippet => DswType.markdownCodeBlockSmall.copyWith(
      color: dsw.labelPrimary,
    ),
    PlanTextStyle.description => DswType.xs13.copyWith(
      color: dsw.labelTertiary,
    ),
    _ => DswType.base16.copyWith(color: dsw.labelPrimary),
  };
}

int? _ladderIndex(String name) => PlanThemeColors.names.indexOf(name);

/// The read answer of one text block: full mark rendering — this is where
/// bold/italic/links/mentions finally look like themselves. The row prefixes
/// (checkbox, bullet, counter, toggle chevron) draw here too: search flips
/// the whole document read-only and the rows must not lose who they are.
class _TextReadView extends StatelessWidget {
  const _TextReadView({
    required this.content,
    required this.style,
    required this.blockId,
    this.ordinal,
    this.collapsed = false,
    this.onToggleCollapse,
    this.searchQuery,
  });

  final PlanText content;
  final PlanTextStyle style;
  final String blockId;
  final int? ordinal;
  final bool collapsed;
  final void Function(String blockId)? onToggleCollapse;
  final String? searchQuery;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final step = MediaQuery.textScalerOf(context).scale(1);
    final base = _textStyle(context, style);

    if (style == PlanTextStyle.codeSnippet) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(DswShape.sm),
        decoration: BoxDecoration(
          color: color.bgLayer2,
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: Text(
          content.text,
          style: DswType.markdownCodeBlockSmall.copyWith(
            color: dswCodeColor(context),
          ),
        ),
      );
    }

    Widget body = Padding(
      padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
      child: Text.rich(
        TextSpan(children: _spans(context, base)),
        textAlign: switch (content.align) {
          PlanAlign.center => TextAlign.center,
          PlanAlign.end => TextAlign.right,
          _ => TextAlign.start,
        },
      ),
    );

    if (style == PlanTextStyle.quote) {
      body = DecoratedBox(
        decoration: BoxDecoration(
          color: color.bgLayer2,
          border: Border(left: BorderSide(color: color.brandPrimary, width: 2)),
        ),
        child: Padding(padding: const EdgeInsets.all(DswShape.sm), child: body),
      );
    }

    if (style == PlanTextStyle.callout && content.iconEmoji != null) {
      body = Container(
        padding: const EdgeInsets.all(DswShape.sm),
        decoration: BoxDecoration(
          color: color.bgLayer2,
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: _FieldRow(
          prefix: Padding(
            padding: const EdgeInsets.only(right: DswShape.sm),
            child: SizedBox(
              width: DswShape.iconLg,
              child: Text(
                content.iconEmoji!,
                textAlign: TextAlign.center,
                style: DswType.base16.copyWith(color: color.labelPrimary),
              ),
            ),
          ),
          child: body,
        ),
      );
    }

    Widget? prefix;
    if (style == PlanTextStyle.checkbox) {
      prefix = Padding(
        padding: const EdgeInsets.only(top: 2, right: DswShape.xs),
        child: PlanCheckbox(checked: content.checked ?? false),
      );
    } else if (style == PlanTextStyle.bullet) {
      prefix = Padding(
        padding: EdgeInsets.only(top: 10 * step, right: DswShape.sm),
        child: Icon(
          LucideIcons.circle,
          size: DswShape.iconCaption,
          color: color.labelTertiary,
        ),
      );
    } else if (style == PlanTextStyle.numbered && ordinal != null) {
      prefix = Padding(
        padding: EdgeInsets.only(top: 3 * step, right: DswShape.sm),
        child: Text(
          '$ordinal.',
          style: DswType.xs13.copyWith(color: color.labelTertiary),
        ),
      );
    } else if (style == PlanTextStyle.toggle) {
      prefix = Padding(
        padding: const EdgeInsets.only(top: 3, right: DswShape.xs),
        child: Icon(
          collapsed ? LucideIcons.chevron_right : LucideIcons.chevron_down,
          size: DswShape.iconSm,
          color: color.labelTertiary,
        ),
      );
    }
    if (prefix != null) {
      body = _FieldRow(prefix: prefix, child: body);
    }

    return body;
  }

  List<InlineSpan> _spans(BuildContext context, TextStyle base) {
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final mark in content.marks) {
      final start = mark.range.start.clamp(0, content.text.length);
      final end = mark.range.end.clamp(0, content.text.length);
      if (start > cursor) {
        spans.add(_plainSpan(context, content.text.substring(cursor, start)));
      }
      if (end > start) {
        spans.add(_markSpan(context, content.text.substring(start, end), mark));
      }
      cursor = end > cursor ? end : cursor;
    }
    if (cursor < content.text.length) {
      spans.add(_plainSpan(context, content.text.substring(cursor)));
    }
    return spans;
  }

  TextSpan _plainSpan(BuildContext context, String text) {
    var face = _textStyle(context, style);
    if (searchQuery != null &&
        searchQuery!.isNotEmpty &&
        text.toLowerCase().contains(searchQuery!)) {
      face = face.copyWith(
        background: Paint()..color = context.dsw.bubbleHighlight,
      );
    }
    return TextSpan(text: text, style: face);
  }

  TextSpan _markSpan(BuildContext context, String text, PlanMark mark) {
    final color = context.dsw;
    var face = _textStyle(context, style);
    switch (mark.type) {
      case PlanMarkType.bold:
        face = face.copyWith(fontWeight: FontWeight.w600);
      case PlanMarkType.italic:
        face = face.copyWith(fontStyle: FontStyle.italic);
      case PlanMarkType.strikethrough:
        face = face.copyWith(decoration: TextDecoration.lineThrough);
      case PlanMarkType.underline:
        face = face.copyWith(decoration: TextDecoration.underline);
      case PlanMarkType.keyboard:
        face = DswType.markdownCodeBlockSmall.copyWith(
          color: color.labelPrimary,
        );
      case PlanMarkType.link:
      case PlanMarkType.object:
        face = face.copyWith(
          color: color.brandPrimary,
          decoration: TextDecoration.underline,
        );
      case PlanMarkType.textColor:
        face = face.copyWith(
          color: planLadderColor(
            color,
            PlanThemeColors.names.indexOf(mark.param ?? ''),
          ),
        );
      case PlanMarkType.backgroundColor:
        face = face.copyWith(
          background: Paint()
            ..color = planLadderColor(
              color,
              PlanThemeColors.names.indexOf(mark.param ?? ''),
            ),
        );
      case PlanMarkType.mention:
      case PlanMarkType.emoji:
        face = face.copyWith(color: color.brandPrimary);
    }
    return TextSpan(text: text, style: face);
  }
}

Color dswCodeColor(BuildContext context) => context.dsw.labelPrimary;

// ---- media / link / embed ------------------------------------------------

class _FileBlock extends StatelessWidget {
  const _FileBlock({required this.kind, required this.state, this.name});

  final PlanFileKind kind;
  final PlanFileState state;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final icon = switch (kind) {
      PlanFileKind.image => LucideIcons.image,
      PlanFileKind.video => LucideIcons.clapperboard,
      PlanFileKind.audio => LucideIcons.music,
      PlanFileKind.pdf => LucideIcons.file_text,
      _ => LucideIcons.file,
    };
    final label = switch (state) {
      PlanFileState.uploading => context.tr('planFileUploading'),
      PlanFileState.error => context.tr('planFileError'),
      _ => name ?? context.tr('planFileEmpty'),
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: DswShape.xs),
      padding: const EdgeInsets.all(DswShape.sm),
      decoration: BoxDecoration(
        color: color.bgLayer2,
        borderRadius: BorderRadius.circular(DswShape.inner),
        border: Border.all(color: color.borderL2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DswShape.iconSm, color: color.labelTertiary),
          const SizedBox(width: DswShape.sm),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xs13.copyWith(color: color.labelSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkBlock extends StatelessWidget {
  const _BookmarkBlock({
    required this.url,
    required this.state,
    required this.readOnly,
    this.onTap,
  });

  final String? url;
  final PlanBookmarkState state;
  final bool readOnly;

  /// Edit face only: the card is the "set or change the URL" affordance —
  /// upstream opens `OpenBookmarkSetter` the same way (`Command.kt:27`).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final label = switch (state) {
      PlanBookmarkState.fetching => context.tr('planBookmarkFetching'),
      PlanBookmarkState.done => url ?? '',
      PlanBookmarkState.error => context.tr('planBookmarkError'),
      _ => context.tr('planBookmarkEmpty'),
    };
    return DswHoverTap(
      onTap: onTap,
      semanticLabel: context.tr('planBookmarkPrompt'),
      builder: (context, hovered, focused) => Container(
        margin: const EdgeInsets.symmetric(vertical: DswShape.xs),
        padding: const EdgeInsets.all(DswShape.sm),
        decoration: BoxDecoration(
          color: hovered && onTap != null
              ? color.interactiveBgHover
              : color.bgLayer2,
          borderRadius: BorderRadius.circular(DswShape.inner),
          border: Border.all(color: color.borderL2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.bookmark,
              size: DswShape.iconSm,
              color: color.brandPrimary,
            ),
            const SizedBox(width: DswShape.sm),
            Flexible(
              child: Text(
                label,
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

class _LinkBlock extends StatelessWidget {
  const _LinkBlock({
    required this.document,
    required this.target,
    required this.cardStyle,
    required this.description,
  });

  final PlanBlockDocument document;
  final String target;
  final PlanLinkCardStyle cardStyle;
  final PlanLinkDescription description;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final named = document.block(target)?.content;
    final title = named is PlanText ? named.text : target;
    if (cardStyle == PlanLinkCardStyle.text) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
        child: Text.rich(
          TextSpan(
            text: title,
            style: DswType.base16.copyWith(
              color: color.brandPrimary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: DswShape.xs),
      padding: const EdgeInsets.all(DswShape.sm),
      decoration: BoxDecoration(
        color: color.bgLayer2,
        borderRadius: BorderRadius.circular(DswShape.card),
        border: Border.all(color: color.borderL2),
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.link,
            size: DswShape.iconSm,
            color: color.brandPrimary,
          ),
          const SizedBox(width: DswShape.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xxsStrong12.copyWith(color: color.labelPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LatexBlock extends StatelessWidget {
  const _LatexBlock({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    // The client renders LaTeX (KaTeX upstream, gpt_markdown here) but has no
    // insert path — this block only arrives from a document that had one.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
      child: GptMarkdown('\$\$ $source \$\$'),
    );
  }
}

class _EmbedBlock extends StatelessWidget {
  const _EmbedBlock({required this.processor, required this.target});

  final PlanEmbedProcessor processor;
  final String? target;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final openable = target != null && target!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: DswShape.xs),
      padding: const EdgeInsets.all(DswShape.sm),
      decoration: BoxDecoration(
        color: color.bgLayer2,
        borderRadius: BorderRadius.circular(DswShape.card),
        border: Border.all(color: color.borderL2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.puzzle,
            size: DswShape.iconSm,
            color: color.labelTertiary,
          ),
          const SizedBox(width: DswShape.sm),
          Flexible(
            child: Text(
              '${processor.name}${openable ? ' · ${context.tr('planEmbedOpen')}' : ' · ${context.tr('planEmbedUnavailable')}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xs13.copyWith(color: color.labelSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- chrome blocks -------------------------------------------------------

class _ChipBlock extends StatelessWidget {
  const _ChipBlock({
    required this.icon,
    required this.label,
    required this.detail,
  });

  final IconData icon;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DswShape.iconTiny, color: color.labelTertiary),
          const SizedBox(width: DswShape.xs),
          Flexible(
            child: Text(
              detail.isEmpty ? label : '$label · $detail',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _TocBlock extends StatelessWidget {
  const _TocBlock({required this.headings});

  final List<PlanBlock> headings;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: DswShape.xs),
      padding: const EdgeInsets.all(DswShape.sm),
      decoration: BoxDecoration(
        color: color.bgLayer2,
        borderRadius: BorderRadius.circular(DswShape.inner),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('planBlockToc'),
            style: DswType.xxsStrong12.copyWith(color: color.labelTertiary),
          ),
          for (final heading in headings)
            Padding(
              padding: const EdgeInsets.only(top: DswShape.xs),
              child: Text(
                (heading.content as PlanText).text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.xs13.copyWith(color: color.labelSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

// ---- table ---------------------------------------------------------------

class _TableRowBlock extends StatelessWidget {
  const _TableRowBlock({
    required this.document,
    required this.block,
    required this.readOnly,
  });

  final PlanBlockDocument document;
  final PlanBlock block;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final isHeader = (block.content as PlanTableBlock).isHeader;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, cell) in block.children.indexed)
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: DswShape.xs,
                  vertical: DswShape.xs,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: color.borderL2, width: 0.5),
                  color: isHeader ? color.bgLayer2 : null,
                ),
                child: readOnly
                    ? Text(
                        cell.content is PlanText
                            ? (cell.content as PlanText).text
                            : '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: isHeader
                            ? DswType.xxsStrong12.copyWith(
                                color: color.labelPrimary,
                              )
                            : DswType.xs13.copyWith(color: color.labelPrimary),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _CellField(
                              document: document,
                              cell: cell,
                              isHeader: isHeader,
                            ),
                          ),
                          // The Column tab of upstream's table menu lives on
                          // the header cells here — the row tab stays on the
                          // row trigger at the right edge.
                          if (isHeader)
                            Builder(
                              builder: (menuContext) => PlanMenuTrigger(
                                semanticLabel: context.tr('planColumnMenu'),
                                items: planTableColumnActions(
                                  menuContext,
                                  document,
                                  block.id,
                                  index,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          if (!readOnly)
            Builder(
              builder: (menuContext) => PlanMenuTrigger(
                semanticLabel: context.tr('planTableActions'),
                items: planTableRowActions(menuContext, document, block.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _CellField extends StatefulWidget {
  const _CellField({
    required this.document,
    required this.cell,
    required this.isHeader,
  });

  final PlanBlockDocument document;
  final PlanBlock cell;
  final bool isHeader;

  @override
  State<_CellField> createState() => _CellFieldState();
}

class _CellFieldState extends State<_CellField> {
  late final TextEditingController _controller = TextEditingController(
    text: (widget.cell.content as PlanText).text,
  );

  @override
  void didUpdateWidget(_CellField old) {
    super.didUpdateWidget(old);
    final text = (widget.cell.content as PlanText).text;
    final oldText = (old.cell.content as PlanText).text;
    if (text != _controller.text && text != oldText) {
      _controller.value = TextEditingValue(text: text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return dswEnsureShadTheme(
      context,
      ShadInput(
        controller: _controller,
        maxLines: 1,
        style: widget.isHeader
            ? DswType.xxsStrong12.copyWith(color: color.labelPrimary)
            : DswType.xs13.copyWith(color: color.labelPrimary),
        decoration: dswBareInput,
        padding: EdgeInsets.zero,
        onChanged: (text) => widget.document.editText(widget.cell.id, text),
      ),
    );
  }
}

class _AddBlockRow extends StatelessWidget {
  const _AddBlockRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: onTap,
      semanticLabel: context.tr('planAddBlock'),
      builder: (context, hovered, focused) => Padding(
        padding: const EdgeInsets.symmetric(vertical: DswShape.sm),
        child: Row(
          children: [
            Icon(
              LucideIcons.plus,
              size: DswShape.iconTiny,
              color: color.labelTertiary,
            ),
            const SizedBox(width: DswShape.xs),
            Text(
              context.tr('planAddBlock'),
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
