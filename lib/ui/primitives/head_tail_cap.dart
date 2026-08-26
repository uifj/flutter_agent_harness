// Head/tail height-cap arithmetic shared by the block primitives, ported from
// `ui-primitives/src/head-tail-cap.ts`, so long results use consistent head and
// tail slices. The split is `ceil(maxLines / 2)` head rows and the remainder as
// tail rows; a result within the cap shows every row and hides none.
//
// dsh's module says it is shared by TerminalBlock and SearchBlock, and ReadBlock
// and DiffBlock then spell the same three lines inline. All four use it here:
// the arithmetic is why a long read, a long search, a long diff and a long
// command output all cut at the same place, and one copy is what keeps that
// true.

import 'dart:math' as math;

/// The head/tail split metrics for a capped list.
class HeadTailCap {
  const HeadTailCap({
    required this.hidden,
    required this.capped,
    required this.headLines,
    required this.tailLines,
  });

  /// Rows beyond the cap (list length − maxLines); <= 0 means nothing is hidden.
  ///
  /// Deliberately not clamped at zero, as in the source: every caller guards on
  /// `hidden > 0` before drawing the toggle, and clamping would hide the
  /// distinction between "exactly at the cap" and "well under it" from anything
  /// that wants it later.
  final int hidden;

  /// Whether the list is over the cap and not expanded, so it shows a head/tail
  /// slice.
  final bool capped;

  /// Head-slice row count: `ceil(maxLines / 2)`.
  final int headLines;

  /// Tail-slice row count: the remainder after the head.
  final int tailLines;
}

/// Computes the head/tail cap metrics for a list of [total] rows against
/// [maxLines], given whether the surface is [expanded].
///
/// Pure arithmetic; the caller slices its own rows with [HeadTailCap.headLines]
/// and [HeadTailCap.tailLines] so a block can layer its own concerns (the search
/// block restores a tail file header) on top.
HeadTailCap headTailCap(int total, int maxLines, bool expanded) {
  final hidden = total - maxLines;
  final headLines = (maxLines / 2).ceil();
  return HeadTailCap(
    hidden: hidden,
    capped: hidden > 0 && !expanded,
    headLines: headLines,
    tailLines: maxLines - headLines,
  );
}

/// Clamped slice helpers, because Dart's [List.sublist] throws where JavaScript's
/// `slice` clamps.
///
/// The blocks call these with counts straight off [headTailCap], which can
/// exceed the list on a caller-supplied `maxLines` larger than the content — the
/// `capped` guard covers the drawing path, and these keep the arithmetic itself
/// from being the thing that throws.
extension HeadTailSlice<T> on List<T> {
  List<T> head(int count) => sublist(0, math.min(math.max(count, 0), length));

  List<T> tail(int count) =>
      sublist(length - math.min(math.max(count, 0), length));
}
