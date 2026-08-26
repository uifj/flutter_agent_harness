// The Think disclosure, ported from `ReasoningRow.module.css` and its component.
//
// Reasoning arrives on its own channel and is shown collapsed by default: one
// 24px row with a live one-line summary, expanding to the full text. While the
// model is still thinking, a pale wash sweeps across the row — the only motion
// in the transcript, and the reason the header primitive accepts an overlay.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/disclosure_row.dart';
import '../primitives/row_sweep.dart';

class ReasoningRow extends StatefulWidget {
  const ReasoningRow({super.key, required this.text, required this.running});

  final String text;

  /// Whether this block is the streaming tail. It decides both the sweep and
  /// which line the summary shows.
  final bool running;

  @override
  State<ReasoningRow> createState() => _ReasoningRowState();
}

class _ReasoningRowState extends State<ReasoningRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DisclosureRow(
      // 14px think glyph, matching the source's IconThinkOutline14 seat.
      icon: Icon(
        LucideIcons.brain,
        size: 14,
        color: color.labelTertiary,
      ),
      title: 'Think',
      // The title drops to weight 400 here: the summary beside it is the content
      // and the label is only a marker.
      titleStyle: DswType.s14.copyWith(
        height: 24 / 14,
        fontWeight: FontWeight.w400,
        color: color.labelSecondary,
      ),
      open: _expanded,
      expandable: true,
      onToggle: () => setState(() => _expanded = !_expanded),
      rowOverlay: widget.running ? RowSweep(base: color.bgBase) : null,
      collapsed: _summary(color),
      child: _body(color),
    );
  }

  /// A 2px dot, then the summary line: the newest line while running, the first
  /// line once settled.
  Widget _summary(DswAlias color) {
    final summary = widget.running
        ? _latestLine(widget.text)
        : _firstLine(widget.text);
    final style = DswType.s14.copyWith(
      height: 24 / 14,
      color: color.labelTertiary,
    );
    return Row(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 2,
          height: 2,
          decoration: BoxDecoration(
            color: color.labelCaption,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        Expanded(
          child: widget.running
              // `data-follow-end`: while running the interesting end is the
              // right one, so the line is anchored there and clipped on the
              // left. A reversed scroll view parks at the end by construction —
              // no measuring, and it stays parked as the line grows.
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Text(summary, softWrap: false, style: style),
                )
              : Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
        ),
      ],
    );
  }

  Widget _body(DswAlias color) => Padding(
    // 22px of indent lines the text up under the title, past the 16px leading
    // and its 6px gap.
    padding: const EdgeInsets.fromLTRB(22, 4, 0, 4),
    child: Text(
      widget.text,
      style: DswType.s14.copyWith(height: 24 / 14, color: color.labelTertiary),
    ),
  );

  static String _firstLine(String text) {
    final newline = text.indexOf('\n');
    return newline == -1 ? text : text.substring(0, newline);
  }

  static String _latestLine(String text) {
    final visible = text.trimRight();
    final newline = visible.lastIndexOf('\n');
    return newline == -1 ? visible : visible.substring(newline + 1);
  }
}
