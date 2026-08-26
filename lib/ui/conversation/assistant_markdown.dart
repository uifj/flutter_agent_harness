// Assistant prose.
//
// The one place in the app that talks to the markdown renderer, so the styling
// contract with dsh lives in a single table. Values come from
// `ui-primitives/src/markdown/MarkdownText.module.css` and `CodeBlock.module.css`
// — the sheet the web build actually renders through, not the chat feature's
// wrapper.
//
// One deviation to know about: dsh renders headings from its own
// `--dsw-font-markdown-h*` ramp with 32px/16px margins. The renderer here takes a
// heading text style but owns the spacing, so heading rhythm is the package's and
// only the type is dsh's.

import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';

class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown(this.text, {super.key, this.streaming = false});

  final String text;

  /// Whether more of this message may still arrive.
  ///
  /// This is what buys the incremental rebuild: the renderer only splits the
  /// source into a cached settled prefix and a live tail while it is animating.
  /// A settled message opts out entirely and builds no ticker at all.
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return GptMarkdownTheme(
      gptThemeData: dswMarkdownTheme(context),
      child: GptMarkdown(
        text,
        style: DswType.markdownBase.copyWith(color: color.labelPrimary),
        animation: streaming
            ? GptMarkdownAnimation.fade
            : GptMarkdownAnimation.none,
        // The reveal outruns this floor whenever it would otherwise fall behind
        // the incoming text, so it never trails the model.
        isStreaming: streaming,
      ),
    );
  }
}

/// The dsh markdown table, resolved against the current theme.
///
/// Built per call rather than cached: the alias layer differs between light and
/// dark, and the two are separate `DswAlias` instances.
GptMarkdownThemeData dswMarkdownTheme(BuildContext context) {
  final color = context.dsw;
  final brightness = Theme.of(context).brightness;
  return GptMarkdownThemeData(
    brightness: brightness,
    h1: DswType.markdownH1.copyWith(color: color.labelPrimary),
    h2: DswType.markdownH2.copyWith(color: color.labelPrimary),
    h3: DswType.markdownH3.copyWith(color: color.labelPrimary),
    h4: DswType.markdownH4.copyWith(color: color.labelPrimary),
    // h5 and h6 share the base-strong step upstream.
    h5: DswType.markdownBaseStrong.copyWith(color: color.labelPrimary),
    h6: DswType.markdownBaseStrong.copyWith(color: color.labelPrimary),
    // dsh draws no rule under an h1.
    autoAddDividerLineAfterH1: false,
    hrLineThickness: 1,
    hrLineColor: color.borderL2,
    linkColor: color.stateBusinessPrimary,
    linkHoverColor: color.stateBusinessPrimary,
    inlineCode: _inlineCode(color),
    styleSheet: _styleSheet(color),
  );
}

/// `MarkdownText.module.css:146-155`: a 6px chip at 0.875em of the surrounding
/// text, so it keeps its proportion inside a heading too.
InlineCodeStyle _inlineCode(DswAlias color) => InlineCodeStyle(
  fontFamily: dswFontFamilyCode,
  fontFamilyFallback: dswFontFamilyCodeFallback,
  fontSizeFactor: 0.875,
  color: color.labelPrimary,
  backgroundColor: color.markdownInlineCode,
  borderRadius: const Radius.circular(6),
  padding: const EdgeInsets.symmetric(horizontal: 5),
);

GptMarkdownStyleSheet _styleSheet(DswAlias color) => GptMarkdownStyleSheet(
  // `CodeBlock.module.css:4-40`: a 12px-radius block with a banner strip
  // carrying the language and the copy control.
  codeBlock: CodeBlockStyle(
    backgroundColor: color.markdownCodeBlock,
    borderRadius: const Radius.circular(12),
    borderWidth: 0,
    padding: const EdgeInsets.all(14),
    headerPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    fontFamily: dswFontFamilyCode,
    fontSize: 13,
    textColor: color.labelPrimary,
    showLanguageLabel: true,
    showCopyButton: true,
    languageStyle: DswType.markdownCodeBlockSmall.copyWith(
      color: color.labelPrimary,
    ),
  ),
  // `:134-138`: a 2px caption-grey bar, 14px of indent, no fill.
  blockQuote: BlockQuoteStyle(
    barWidth: 2,
    barColor: color.labelCaption,
    barRadius: Radius.zero,
    padding: const EdgeInsets.only(left: 14),
  ),
  // `:85-91`: 18px of indent, a 6px gap between items.
  list: ListStyle(
    indent: 18,
    bulletColor: color.labelSecondary,
    markerTextStyle: DswType.markdownBase.copyWith(
      color: color.labelSecondary,
    ),
  ),
  // `:225-243`: 10x16 cells, an l3 rule under the head and l2 between rows.
  table: TableStyle(
    borderColor: color.borderL2,
    borderWidth: 1,
    cellPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    headerTextStyle: DswType.markdownTableHead.copyWith(
      color: color.labelPrimary,
    ),
  ),
  hr: HrStyle(thickness: 1, color: color.borderL2),
  link: LinkStyle(
    color: color.stateBusinessPrimary,
    decoration: TextDecoration.none,
  ),
  // `:169-172`: a secondary-grey accent, 8px before the label, and disabled —
  // a task list in a reply is a report, not a control.
  checkbox: CheckboxStyle(
    checkedColor: color.labelSecondary,
    gapAfterBox: 8,
    interactive: false,
  ),
);
