// SearchBlock: the search surface for a completed content or path search, ported
// from `ui-primitives/src/SearchBlock.tsx` and its stylesheet.
//
// A banner (result summary that folds the pre-cap total in when the tool capped
// the result, plus a copy control), then either grep matches grouped by file
// (each file a bold path header with its `lineNumber: line` rows, the group
// collapsible) or a flat glob path list. Both shapes flatten to one list of rows
// the height cap slices head/tail over, and neither soft-wraps: a long match line
// or path scrolls horizontally instead of folding.

import 'package:flutter/material.dart';

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import 'block_chrome.dart';
import 'copy_button.dart';
import 'head_tail_cap.dart';

/// Result rows shown before the height cap collapses the middle. Matches the
/// terminal block's default so a search card and a terminal card cut a long
/// result at the same place.
const defaultSearchMaxLines = 16;

/// One matched line inside a [SearchFileGroup]: its 1-based line number and text.
class SearchBlockLineMatch {
  const SearchBlockLineMatch({required this.lineNumber, required this.line});

  final int lineNumber;

  /// The matched line text, as the tool surfaced it.
  final String line;
}

/// One file's grouped matches, in first-seen file order.
class SearchFileGroup {
  const SearchFileGroup({required this.path, required this.matches});

  /// The file the matches belong to (the display path).
  final String path;

  /// The file's matched lines, in output order.
  final List<SearchBlockLineMatch> matches;
}

/// One flattened render row.
///
/// A matches card produces a file header row per group followed by a match row
/// per retained line while the group is expanded; a paths card produces one path
/// row per path. The height cap counts these uniformly, so a file header costs
/// one row exactly as a match line or a path does.
sealed class _SearchRow {
  const _SearchRow();
}

class _FileRow extends _SearchRow {
  const _FileRow({
    required this.path,
    required this.count,
    required this.index,
    required this.collapsed,
  });

  final String path;
  final int count;
  final int index;
  final bool collapsed;
}

class _MatchRow extends _SearchRow {
  const _MatchRow({
    required this.lineNumber,
    required this.line,
    required this.fileIndex,
  });

  final int lineNumber;
  final String line;
  final int fileIndex;
}

class _PathRow extends _SearchRow {
  const _PathRow(this.path);

  final String path;
}

/// One card, two shapes. The source discriminates on a `kind` field; here the two
/// named constructors are the discriminant, and exactly one of [files] and [paths]
/// is non-null.
class SearchBlock extends StatefulWidget {
  /// The grouped-matches (`grep`) shape.
  //
  // Both constructors take a non-nullable parameter and assign it through,
  // rather than an initializing formal onto the nullable field, so that the
  // discriminant cannot be defeated: `SearchBlock.matches(files: null)` would
  // otherwise compile and then read as a paths card, drawing the wrong shape.
  const SearchBlock.matches({
    super.key,
    required List<SearchFileGroup> files,
    required this.truncated,
    required this.total,
    this.maxLines = defaultSearchMaxLines,
    // ignore: prefer_initializing_formals
  }) : files = files,
       paths = null;

  /// The flat-path (`glob`) shape.
  const SearchBlock.paths({
    super.key,
    required List<String> paths,
    required this.truncated,
    required this.total,
    this.maxLines = defaultSearchMaxLines,
    // ignore: prefer_initializing_formals
  }) : paths = paths,
       files = null;

  /// Matched lines grouped by file, in first-seen file order; null on a paths
  /// card.
  final List<SearchFileGroup>? files;

  /// The discovered paths, in the tool's result order (the retained page when
  /// [truncated]); null on a matches card.
  final List<String>? paths;

  /// Whether the tool capped the inline result: the shape carries only the
  /// retained results, not every result the search found. The banner summary folds
  /// the pre-cap [total] in so the card never presents a capped result as
  /// complete.
  final bool truncated;

  /// Total results the search found before capping (equals the retained count
  /// when not [truncated]).
  final int total;

  final int maxLines;

  @override
  State<SearchBlock> createState() => _SearchBlockState();
}

class _SearchBlockState extends State<SearchBlock> {
  bool _expanded = false;

  /// Collapsed file-group indices (matches cards only).
  final _collapsed = <int>{};

  List<String> get _paths => widget.paths ?? const [];
  List<SearchFileGroup> get _files => widget.files ?? const [];
  bool get _isPaths => widget.paths != null;

  /// Retained results the card holds: the matched-line count across all files, or
  /// the path count. This is what the banner reports against the pre-cap total.
  int get _shown => _isPaths
      ? _paths.length
      : _files.fold(0, (sum, file) => sum + file.matches.length);

  /// The whole structured result regardless of the height cap or which groups are
  /// collapsed, so the clipboard carries the result rather than what the card
  /// happens to be showing.
  String get _copyText => _isPaths
      ? _paths.join('\n')
      : _files
            .map(
              (file) => [
                file.path,
                ...file.matches.map((m) => '${m.lineNumber}: ${m.line}'),
              ].join('\n'),
            )
            .join('\n\n');

  /// The banner summary. When the search was capped it reads `Showing X / N …` so
  /// the retained count and the pre-cap total sit in one clause (mirroring the read
  /// card's `Showing X / Y lines`); when it was not capped it is a plain count of
  /// what the card holds. The unit trails the count either way.
  String get _summary {
    final count = widget.truncated ? 'Showing $_shown / ${widget.total}' : '$_shown';
    // The unit agrees with the number nearest it, which is the pre-cap total when
    // the clause carries one.
    final subject = widget.truncated ? widget.total : _shown;
    if (_isPaths) return '$count ${subject == 1 ? 'path' : 'paths'}';
    final files = _files.length;
    return '$count ${subject == 1 ? 'match' : 'matches'} · $files '
        '${files == 1 ? 'file' : 'files'}';
  }

  /// Flattens the card's shape into its render rows, dropping a collapsed file
  /// group's match rows.
  List<_SearchRow> get _rows {
    if (_isPaths) return [for (final path in _paths) _PathRow(path)];
    final rows = <_SearchRow>[];
    for (var index = 0; index < _files.length; index++) {
      final file = _files[index];
      final collapsed = _collapsed.contains(index);
      rows.add(
        _FileRow(
          path: file.path,
          count: file.matches.length,
          index: index,
          collapsed: collapsed,
        ),
      );
      if (collapsed) continue;
      for (final match in file.matches) {
        rows.add(
          _MatchRow(
            lineNumber: match.lineNumber,
            line: match.line,
            fileIndex: index,
          ),
        );
      }
    }
    return rows;
  }

  void _toggleFile(int index) => setState(() {
    if (!_collapsed.remove(index)) _collapsed.add(index);
  });

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final rows = _rows;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.markdownCodeBlock,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _banner(color, empty: rows.isEmpty),
          if (rows.isEmpty) _empty(color) else _body(color, rows),
        ],
      ),
    );
  }

  Widget _banner(DswAlias color, {required bool empty}) => Container(
    color: color.markdownCodeBlockBanner,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DswType.xs13.copyWith(color: color.labelSecondary),
          ),
        ),
        if (!empty) ...[
          const SizedBox(width: 12),
          CopyButton(
            text: _copyText,
            idleColor: color.labelSecondary,
            hoverColor: color.labelPrimary,
          ),
        ],
      ],
    ),
  );

  Widget _empty(DswAlias color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Text(
      'No results',
      style: DswType.markdownCodeBlock.copyWith(color: color.labelTertiary),
    ),
  );

  Widget _body(DswAlias color, List<_SearchRow> rows) {
    final cap = headTailCap(rows.length, widget.maxLines, _expanded);
    final head = cap.capped ? rows.head(cap.headLines) : rows;
    final naturalTail = cap.capped ? rows.tail(cap.tailLines) : const <_SearchRow>[];

    // When the tail slice begins inside a file's matches, its own header sits
    // above the cut and is not shown, so those rows could not be attributed to a
    // file. Restore the owning header at the top of the tail — unless the head
    // slice already carries it (a single large file), where it would duplicate.
    final lead = naturalTail.isEmpty ? null : naturalTail.first;
    final orphan = lead is _MatchRow ? lead.fileIndex : null;
    final tailHeader =
        orphan == null ||
            head.any((row) => row is _FileRow && row.index == orphan)
        // Never absent: a match row is only ever emitted after its own header.
        ? null
        : rows.whereType<_FileRow>().firstWhere((row) => row.index == orphan);
    // The restored header is itself a row. Left extra it would push the card to
    // maxLines + 1 and overstate `hidden` by one, so it consumes a tail slot: drop
    // the tail's first row (the match whose header this is) for it. Visible rows
    // hold at maxLines and `hidden` stays exact; the dropped match joins the
    // hidden middle.
    final tail = tailHeader == null ? naturalTail : naturalTail.sublist(1);

    return Padding(
      padding: const EdgeInsets.only(top: 8, right: 14, bottom: 12),
      child: BlockScroller(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final row in head) _row(color, row),
            if (cap.hidden > 0)
              BlockExpandToggle(
                expanded: _expanded,
                hidden: cap.hidden,
                onToggle: () => setState(() => _expanded = !_expanded),
                textStyle: DswType.markdownCodeBlock,
                expandSemantics:
                    'Expand the remaining ${cap.hidden} result lines',
                collapseSemantics: 'Collapse results',
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            if (tailHeader != null) _row(color, tailHeader),
            for (final row in tail) _row(color, row),
          ],
        ),
      ),
    );
  }

  Widget _row(DswAlias color, _SearchRow row) => switch (row) {
    _PathRow(path: final path) => _line(
      Text(
        path,
        softWrap: false,
        style: DswType.markdownCodeBlock.copyWith(color: color.labelPrimary),
      ),
    ),
    _MatchRow(lineNumber: final number, line: final line) => _line(
      Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$number: ',
              style: TextStyle(color: color.labelTertiary),
            ),
            TextSpan(text: line),
          ],
        ),
        softWrap: false,
        style: DswType.markdownCodeBlock.copyWith(color: color.labelPrimary),
      ),
    ),
    _FileRow() => _fileHeader(color, row),
  };

  /// `.line`: one row, its 14px left inset, no wrapping.
  Widget _line(Widget child) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: Align(alignment: Alignment.centerLeft, child: child),
  );

  /// `.fileHeader`: a bold path label plus its match count, the whole row the
  /// collapse control.
  Widget _fileHeader(DswAlias color, _FileRow row) => Semantics(
    button: true,
    expanded: !row.collapsed,
    child: MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _toggleFile(row.index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                row.path,
                softWrap: false,
                style: DswType.markdownCodeBlock.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color.labelPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${row.count}',
                style: DswType.markdownCodeBlock.copyWith(
                  color: color.labelTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
