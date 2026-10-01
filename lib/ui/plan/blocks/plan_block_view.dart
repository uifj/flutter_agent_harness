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
    this.keyFor,
    this.searchQuery,
  });

  final PlanBlockDocument document;

  /// Read mode (and the locked answer): blocks draw, affordances go.
  final bool readOnly;

  /// Opens the slash menu for an insertion anchored at [afterBlockId].
  final void Function(String? afterBlockId)? onInsertSlash;

  /// The editor learns which block the caret is in, so the toolbar's
  /// style/colour/alignment controls answer the block being edited.
  final void Function(String blockId)? onFocusedBlock;

  /// Stable row keys the editor's search scrolls to; null draws keyless.
  final Key? Function(String blockId)? keyFor;

  /// In-document search: the active query (already lowercased).
  final String? searchQuery;

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
        for (final block in blocks) ...[
          PlanBlockRow(
            key: keyFor?.call(block.id),
            document: document,
            block: block,
            indent: 0,
            readOnly: readOnly,
            onInsertSlash: onInsertSlash,
            onFocusedBlock: onFocusedBlock,
            headings: headings,
            searchQuery: searchQuery,
          ),
        ],
        if (!readOnly) _AddBlockRow(onTap: () => onInsertSlash?.call(null)),
      ],
    );
  }
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
    this.onInsertSlash,
    this.onFocusedBlock,
    this.keyFor,
    this.searchQuery,
  });

  final PlanBlockDocument document;
  final PlanBlock block;
  final double indent;
  final bool readOnly;
  final void Function(String? afterBlockId)? onInsertSlash;
  final void Function(String blockId)? onFocusedBlock;

  /// Passed down so a match at any depth has a context the search can scroll
  /// to.
  final Key? Function(String blockId)? keyFor;
  final List<PlanBlock> headings;
  final String? searchQuery;

  @override
  Widget build(BuildContext context) {
    final content = block.content;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: _BlockBody(
            document: document,
            block: block,
            readOnly: readOnly,
            onInsertSlash: onInsertSlash,
            onFocusedBlock: onFocusedBlock,
            headings: headings,
            searchQuery: searchQuery,
          ),
        ),
        // Layout containers carry no view of their own (the client flattens
        // them — `DefaultBlockViewRenderer.kt:660-684`): the children draw at
        // the same visual level, one step in.
        if (content is PlanLayout)
          for (final child in block.children)
            PlanBlockRow(
              key: keyFor?.call(child.id),
              document: document,
              block: child,
              indent: indent + _kIndentStep,
              readOnly: readOnly,
              onInsertSlash: onInsertSlash,
              onFocusedBlock: onFocusedBlock,
              headings: headings,
              searchQuery: searchQuery,
            ),
        if (content is! PlanLayout && content is! PlanTableBlock)
          for (final child in block.children)
            PlanBlockRow(
              key: keyFor?.call(child.id),
              document: document,
              block: child,
              indent: indent + _kIndentStep,
              readOnly: readOnly,
              onInsertSlash: onInsertSlash,
              onFocusedBlock: onFocusedBlock,
              headings: headings,
              searchQuery: searchQuery,
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
    this.onInsertSlash,
    this.onFocusedBlock,
    this.searchQuery,
  });

  final PlanBlockDocument document;
  final PlanBlock block;
  final bool readOnly;
  final void Function(String? afterBlockId)? onInsertSlash;
  final void Function(String blockId)? onFocusedBlock;
  final List<PlanBlock> headings;
  final String? searchQuery;

  @override
  Widget build(BuildContext context) {
    final content = block.content;
    switch (content) {
      case PlanText():
        return _TextBlock(
          document: document,
          block: block,
          content: content,
          readOnly: readOnly,
          onFocusedBlock: onFocusedBlock,
          searchQuery: searchQuery,
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
        return _BookmarkBlock(url: url, state: state, readOnly: readOnly);
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
    this.onFocusedBlock,
    this.searchQuery,
  });

  final PlanBlockDocument document;
  final PlanBlock block;
  final PlanText content;
  final bool readOnly;
  final void Function(String blockId)? onFocusedBlock;
  final String? searchQuery;

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
    }

    return _BlockChrome(
      document: document,
      block: block,
      readOnly: readOnly,
      child: _FieldRow(
        prefix: prefix,
        child: _BlockTextField(
          document: document,
          blockId: block.id,
          content: content,
          style: effectiveStyle,
          onFocusedBlock: onFocusedBlock,
        ),
      ),
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
  });

  final PlanBlockDocument document;
  final String blockId;
  final PlanText content;
  final PlanTextStyle style;
  final void Function(String blockId)? onFocusedBlock;

  @override
  State<_BlockTextField> createState() => _BlockTextFieldState();
}

class _BlockTextFieldState extends State<_BlockTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.content.text,
  );

  @override
  void didUpdateWidget(_BlockTextField old) {
    super.didUpdateWidget(old);
    // The document notifies on every edit; a rebuild that did not come from
    // this field's own typing (undo, toolbar, another field) resyncs the text.
    if (widget.content.text != _controller.text &&
        widget.content.text != old.content.text) {
      _controller.value = TextEditingValue(
        text: widget.content.text,
        selection: TextSelection.collapsed(
          offset: widget.content.text.length.clamp(
            0,
            widget.content.text.length,
          ),
        ),
      );
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
          onChanged: (text) => widget.document.editText(widget.blockId, text),
        ),
      ),
    );
  }
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
/// bold/italic/links/mentions finally look like themselves.
class _TextReadView extends StatelessWidget {
  const _TextReadView({
    required this.content,
    required this.style,
    this.searchQuery,
  });

  final PlanText content;
  final PlanTextStyle style;
  final String? searchQuery;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
      child: Text.rich(
        TextSpan(children: spans, style: base),
        textAlign: switch (content.align) {
          PlanAlign.center => TextAlign.center,
          PlanAlign.end => TextAlign.right,
          _ => TextAlign.start,
        },
      ),
    );
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
  });

  final String? url;
  final PlanBookmarkState state;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final label = switch (state) {
      PlanBookmarkState.fetching => context.tr('planBookmarkFetching'),
      PlanBookmarkState.done => url ?? '',
      PlanBookmarkState.error => context.tr('planBookmarkError'),
      _ => context.tr('planBookmarkEmpty'),
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
          for (final cell in block.children)
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
                    : _CellField(
                        document: document,
                        cell: cell,
                        isHeader: isHeader,
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
