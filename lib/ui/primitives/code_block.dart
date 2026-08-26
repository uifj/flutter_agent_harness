// One code surface for every consumer, ported from `markdown/CodeBlock.tsx` and
// `CodeBlock.module.css`: a banner carrying the language and a copy control,
// over a pre-wrapped mono body.
//
// dsh highlights through shiki and keeps, in its own words, an
// "identical-geometry plain fallback" for grammars it has not registered. This
// port is that fallback. `re_highlight` is in the pubspec for the other arm, but
// a highlighter is a separate concern with its own grammar-loading lifecycle,
// and the geometry is what every caller depends on. A highlighted body drops in
// behind this same API without moving a pixel.

import 'package:flutter/material.dart';

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import 'copy_button.dart';

class CodeBlock extends StatefulWidget {
  const CodeBlock({
    super.key,
    required this.code,
    this.lang,
    this.copyLabel = 'Copy',
    this.copiedLabel = 'Copied',
  });

  /// The source text, rendered verbatim.
  final String code;

  /// Grammar hint, shown in the banner. dsh also feeds it to the highlighter;
  /// here it is the banner's label and nothing more.
  final String? lang;

  /// Idle and confirmed labels. dsh's prop defaults are the Chinese pair,
  /// hardcoded because that package is cordis-free and cannot reach a
  /// dictionary; every real call site passes `t('copy')` / `t('copied')`, whose
  /// `en` entries are these two. This build is English throughout, so the
  /// dictionary's values are the defaults here.
  final String copyLabel;
  final String copiedLabel;

  @override
  State<CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<CodeBlock> {
  /// The trailing newline is trimmed for display only — the copy carries what is
  /// shown, which is the same string.
  String get _trimmed => widget.code.endsWith('\n')
      ? widget.code.substring(0, widget.code.length - 1)
      : widget.code;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      // dsh deliberately keeps `overflow: hidden` off `.block` and puts the
      // bottom radii on the `<pre>` instead, because clipping the wrapper would
      // kill its sticky banner. Nothing here is sticky — the panel scrolls as a
      // whole — so the wrapper clips and the body stays a plain fill.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.markdownCodeBlock,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [_banner(color), _body(color)],
      ),
    );
  }

  Widget _banner(DswAlias color) => Container(
    color: color.markdownCodeBlockBanner,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            widget.lang ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DswType.markdownCodeBlockSmall.copyWith(
              color: color.labelPrimary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        CopyButton(
          text: _trimmed,
          label: widget.copyLabel,
          copiedLabel: widget.copiedLabel,
          // The banner's control is `font: inherit` and `color: inherit` off the
          // banner, so it is the 13px step in the primary label colour — one step
          // brighter than the floating control the block primitives carry.
          idleColor: color.labelPrimary,
          hoverColor: color.labelSecondary,
        ),
      ],
    ),
  );

  /// `white-space: pre-wrap` — the body wraps rather than scrolling sideways,
  /// which is why there is no horizontal scroller here. dsh pairs it with
  /// `word-break: break-all`; Flutter has no equivalent switch, so an unbroken
  /// token longer than the column is clipped instead of being split.
  Widget _body(DswAlias color) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      _trimmed,
      style: DswType.markdownCodeBlock.copyWith(color: color.labelPrimary),
    ),
  );
}
