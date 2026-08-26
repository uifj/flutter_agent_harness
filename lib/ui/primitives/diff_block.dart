// DiffBlock: the file-mutation surface, ported from
// `ui-primitives/src/DiffBlock.tsx` and its stylesheet.
//
// One or more per-file hunks, each a bold path header followed by the removed
// block (`-`, error colour) and the added block (`+`, success colour), with a dim
// `└ +A -R · N file(s)` footer. Unlike the TUI's exact changed-row comparison,
// this block renders the old and new sides in full — which is also why nothing
// here computes a line diff, and why this port needs no diffing dependency.
// Output never soft-wraps: an aligned source line keeps its indentation and
// scrolls horizontally instead of folding.

import 'package:flutter/material.dart';

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import 'block_chrome.dart';
import 'copy_button.dart';
import 'head_tail_cap.dart';

/// Output lines shown before the height cap collapses the middle. Matches the
/// terminal block's default so a diff card and a terminal card cut a long body at
/// the same place.
const defaultDiffMaxLines = 16;

/// One file's change, in the shape [DiffBlock] draws.
class DiffHunk {
  const DiffHunk({required this.path, this.oldText, required this.newText});

  /// The changed file's path, drawn verbatim as the hunk's header (the tool's
  /// model-facing path).
  final String path;

  /// Prior content, or null for a new file / an overwrite (nothing on the removed
  /// side).
  final String? oldText;

  /// Content after the change (the added side).
  final String newText;
}

/// A single rendered body line and its role, so the height cap slices a flat list.
enum DiffRowKind { path, del, add, gap }

class DiffRow {
  const DiffRow(this.kind, this.text);

  final DiffRowKind kind;
  final String text;
}

/// The flattened body plus the footer counts.
class DiffBody {
  const DiffBody({
    required this.rows,
    required this.added,
    required this.removed,
    required this.files,
  });

  final List<DiffRow> rows;
  final int added;
  final int removed;
  final int files;
}

/// Splits a side's text into its content lines.
///
/// Empty text is zero lines (a full deletion's `newText` or a create's absent
/// `oldText` side draws nothing), and a single trailing newline is a line
/// terminator rather than an extra empty line — the same terminator rule the
/// terminal block applies to command output. An interior blank line (a genuine
/// `\n\n`) survives.
List<String> contentLines(String text) {
  if (text.isEmpty) return const [];
  final body = text.endsWith('\n')
      ? text.substring(0, text.length - 1)
      : text;
  return body.split('\n');
}

/// Flattens the hunks into the body's rows plus the footer counts.
///
/// A path header opens each new file; a same-file second hunk (a scattered edit)
/// opens with a `⋯` gap instead of repeating the path. Every old-side line counts
/// toward `removed` and every new-side line toward `added`. The file count is of
/// DISTINCT paths, matching the TUI diff card's footer, so two hunks in one file
/// read as `1 file` on both front ends.
DiffBody buildDiffBody(List<DiffHunk> diffs) {
  final rows = <DiffRow>[];
  final paths = <String>{};
  var added = 0;
  var removed = 0;
  String? prevPath;
  for (final diff in diffs) {
    paths.add(diff.path);
    rows.add(
      diff.path != prevPath
          ? DiffRow(DiffRowKind.path, diff.path)
          : const DiffRow(DiffRowKind.gap, '⋯'),
    );
    prevPath = diff.path;
    final oldText = diff.oldText;
    if (oldText != null) {
      for (final line in contentLines(oldText)) {
        rows.add(DiffRow(DiffRowKind.del, line));
        removed++;
      }
    }
    for (final line in contentLines(diff.newText)) {
      rows.add(DiffRow(DiffRowKind.add, line));
      added++;
    }
  }
  return DiffBody(
    rows: rows,
    added: added,
    removed: removed,
    files: paths.length,
  );
}

class DiffBlock extends StatefulWidget {
  const DiffBlock({
    super.key,
    required this.diffs,
    this.maxLines = defaultDiffMaxLines,
  });

  /// One entry per applied hunk, in file order; empty renders nothing.
  final List<DiffHunk> diffs;

  final int maxLines;

  @override
  State<DiffBlock> createState() => _DiffBlockState();
}

class _DiffBlockState extends State<DiffBlock> {
  bool _expanded = false;

  /// The diff text a reader copies: each row's `-`/`+`/path/gap prefix and its
  /// content, exactly what the card shows. The removed and added blocks are the
  /// change; the path headers keep a multi-file copy attributable.
  String _copyText(List<DiffRow> rows) => rows
      .map(
        (row) => switch (row.kind) {
          DiffRowKind.del => '- ${row.text}',
          DiffRowKind.add => '+ ${row.text}',
          DiffRowKind.path => row.text,
          DiffRowKind.gap => row.text,
        },
      )
      .join('\n');

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final body = buildDiffBody(widget.diffs);
    if (body.rows.isEmpty) return const SizedBox.shrink();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.markdownCodeBlock,
        borderRadius: BorderRadius.circular(12),
      ),
      // The copy control floats in the top-right corner over the body, so the card
      // has no empty banner row above its first diff line — the TUI diff card has
      // no banner either, only the footer.
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [_body(color, body), _footer(color, body)],
          ),
          Positioned(
            top: 8,
            right: 12,
            child: CopyButton(
              text: _copyText(body.rows),
              idleColor: color.labelSecondary,
              hoverColor: color.labelPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(DswAlias color, DiffBody body) {
    final cap = headTailCap(body.rows.length, widget.maxLines, _expanded);
    final shown = cap.capped ? body.rows.head(cap.headLines) : body.rows;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: BlockScroller(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in shown) _line(color, row),
            if (cap.hidden > 0)
              BlockExpandToggle(
                expanded: _expanded,
                hidden: cap.hidden,
                onToggle: () => setState(() => _expanded = !_expanded),
                textStyle: DswType.markdownCodeBlock,
                expandSemantics:
                    'Expand the remaining ${cap.hidden} diff lines',
                collapseSemantics: 'Collapse diff',
              ),
            if (cap.capped)
              for (final row in body.rows.tail(cap.tailLines))
                _line(color, row),
          ],
        ),
      ),
    );
  }

  /// One body row. The `- `/`+ ` prefix is drawn here, as the source draws it
  /// through `::before`, so a copied line and the shown line agree and the sign
  /// reads without relying on colour alone.
  Widget _line(DswAlias color, DiffRow row) {
    final text = switch (row.kind) {
      DiffRowKind.del => '- ${row.text}',
      DiffRowKind.add => '+ ${row.text}',
      DiffRowKind.path || DiffRowKind.gap => row.text,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        // The copy control floats over this first row's top-right corner, so the
        // path row ends short of it: a long path would otherwise scroll under the
        // button, whose hit area would then eat clicks on the path's tail.
        padding: EdgeInsets.only(right: row.kind == DiffRowKind.path ? 56 : 0),
        child: Text(
          text,
          softWrap: false,
          style: DswType.markdownCodeBlock.copyWith(
            color: switch (row.kind) {
              DiffRowKind.path => color.labelPrimary,
              DiffRowKind.gap => color.labelTertiary,
              DiffRowKind.del => color.stateErrorPrimary,
              DiffRowKind.add => color.stateSuccessPrimary,
            },
            fontWeight: row.kind == DiffRowKind.path
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  /// The change summary, dim under the body: the same footer the TUI transcript's
  /// diff card draws.
  Widget _footer(DswAlias color, DiffBody body) => Padding(
    padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
    child: Text(
      '└ +${body.added} -${body.removed} · ${body.files} '
      '${body.files == 1 ? 'file' : 'files'}',
      style: DswType.markdownCodeBlock.copyWith(color: color.labelTertiary),
    ),
  );
}
