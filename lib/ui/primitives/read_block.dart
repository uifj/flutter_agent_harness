// ReadBlock: the file surface for a read tool result, ported from
// `ui-primitives/src/ReadBlock.tsx` and its stylesheet.
//
// A banner (label + language + a "showing N of M" note when the read is a window
// + a copy control) over line-numbered source. Each row carries the file's OWN
// line number in a gutter, so a windowed read past an offset keeps its file
// numbering rather than re-counting from 1. Long content is height-capped with
// the same head/tail arithmetic every other block uses, so the cards collapse a
// long body at the same place.
//
// dsh highlights through shiki at per-line granularity and falls back to plain
// monospace for a grammar it has not registered. This port is that fallback, for
// the reason `code_block.dart` gives: `re_highlight` is in the pubspec, but a
// highlighter is a separate concern with its own grammar-loading lifecycle, and
// the geometry is what callers depend on. A highlighted body drops in behind this
// same API without moving a pixel.

import 'package:flutter/material.dart';

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import 'block_chrome.dart';
import 'copy_button.dart';
import 'head_tail_cap.dart';

/// Content lines shown before the height cap collapses the middle. Matches the
/// terminal block's default so a long read and a long command output cut at the
/// same place in the same flow.
const defaultReadMaxLines = 16;

/// Fixed-width gutter column (`--dsl-read-gutter`), so the content edge stays put
/// down the whole window regardless of how wide the numbers grow.
const _gutter = 48.0;

/// One line of the read window: its file line number and its text (no trailing
/// newline).
class ReadBlockLine {
  const ReadBlockLine({required this.number, required this.text});

  /// 1-based line number in the file. A window past an offset keeps the file's
  /// own numbering.
  final int number;

  /// The line's text, already truncated to the read tool's per-line cap.
  final String text;
}

class ReadBlock extends StatefulWidget {
  const ReadBlock({
    super.key,
    this.label,
    required this.lines,
    required this.totalLines,
    this.lang,
    this.maxLines = defaultReadMaxLines,
  });

  /// Banner label (the file path, or a tool-supplied replacement title); null
  /// draws an empty label rather than a shorter banner, so a card with a label
  /// and one without are the same height.
  final String? label;

  /// The returned window's lines, in file order, each keeping its file line
  /// number.
  final List<ReadBlockLine> lines;

  /// Exact total line count in the file, for the "showing N of M" note when the
  /// read is a window.
  final int totalLines;

  /// Grammar hint, shown in the banner. dsh also feeds it to the highlighter;
  /// here it is the banner's label and nothing more.
  final String? lang;

  final int maxLines;

  @override
  State<ReadBlock> createState() => _ReadBlockState();
}

class _ReadBlockState extends State<ReadBlock> {
  bool _expanded = false;

  /// What the copy control writes: the window's lines joined by newlines, without
  /// the gutter numbers or any of the banner — chrome the file does not contain.
  String get _raw => widget.lines.map((line) => line.text).join('\n');

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
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

  Widget _banner(DswAlias color) {
    // A read is a window when its returned lines are fewer than the file's total;
    // the note states that so a reader is not misled that the file ends here.
    final windowed = widget.lines.length < widget.totalLines;
    final lang = widget.lang ?? '';
    return Container(
      color: color.markdownCodeBlockBanner,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: DswType.markdownCodeBlockSmall.copyWith(
                color: color.labelPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (windowed) ...[
            Text(
              'Showing ${widget.lines.length} / ${widget.totalLines} lines',
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
            const SizedBox(width: 12),
          ],
          // The source renders this span unconditionally, so an absent language
          // still costs the banner one flex gap. Skipped here: reproducing a
          // spacing artifact is not the same as reproducing the design.
          if (lang.isNotEmpty) ...[
            Text(
              lang,
              style: DswType.markdownCodeBlockSmall.copyWith(
                color: color.labelTertiary,
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Hidden on an empty window, matching the terminal block's empty-output
          // guard: a successful read of an empty file returns no lines at all, and
          // copying then would wipe the clipboard with an empty string.
          if (widget.lines.isNotEmpty)
            CopyButton(
              text: _raw,
              idleColor: color.labelSecondary,
              hoverColor: color.labelPrimary,
            ),
        ],
      ),
    );
  }

  Widget _body(DswAlias color) {
    final cap = headTailCap(widget.lines.length, widget.maxLines, _expanded);
    final shown = cap.capped
        ? widget.lines.head(cap.headLines)
        : widget.lines;
    return Padding(
      // `padding: 12px 0` — the gutter is the body's left inset, so the rows own
      // the horizontal space.
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: BlockScroller(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in shown) _line(color, line),
            if (cap.hidden > 0)
              BlockExpandToggle(
                expanded: _expanded,
                hidden: cap.hidden,
                onToggle: () => setState(() => _expanded = !_expanded),
                textStyle: DswType.markdownCodeBlock,
                expandSemantics: 'Expand the remaining ${cap.hidden} lines',
                collapseSemantics: 'Collapse content',
                padding: const EdgeInsets.only(left: _gutter),
              ),
            if (cap.capped)
              for (final line in widget.lines.tail(cap.tailLines))
                _line(color, line),
          ],
        ),
      ),
    );
  }

  Widget _line(DswAlias color, ReadBlockLine line) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: _gutter,
        child: Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Text(
            '${line.number}',
            textAlign: TextAlign.right,
            style: DswType.markdownCodeBlock.copyWith(
              color: color.labelTertiary,
            ),
          ),
        ),
      ),
      Text(
        line.text,
        // `white-space: pre`: the line keeps its indentation and runs off the
        // side, which the scroller above is there to reach.
        softWrap: false,
        style: DswType.markdownCodeBlock.copyWith(color: color.labelPrimary),
      ),
    ],
  );
}
