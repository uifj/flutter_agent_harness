// The read tool's window: which lines of a file come back, and how they read.
//
// A port of `tool-fs/src/read-render.ts`. It is a separate file for the reason
// that one is: the windowing arithmetic (offset, three independent caps, the
// footer that tells the model how to continue) is the part worth testing on its
// own, and none of it needs a file, a tool registration, or Genkit. `tools.dart`
// supplies the text and turns the outcome into a tool result.
//
// It lives in `lib/genkit/` next to its only caller rather than in `lib/model/`,
// and imports nothing from Genkit — the import fence in `agent_runtime.dart` is
// about which files may reach for `package:genkit`, not about which directory
// pure code sits in.

import 'dart:async';
import 'dart:convert';

/// `READ_LIMIT`: default and maximum lines one read returns.
const readLimit = 2000;

/// `READ_MAX_LINE_LENGTH`: a single line is cut here, with a suffix saying so, so
/// one minified bundle line cannot flood the window.
const readMaxLineChars = 2000;

/// `READ_MAX_BYTES`: the whole window's budget. Reached mid-window, it stops the
/// scan and the footer switches to the capped wording.
const readMaxBytes = 50 * 1024;

/// One returned line, numbered as it is in the file.
class ReadLine {
  const ReadLine(this.number, this.text);

  /// 1-based line number in the file, not an index into [ReadOutcome.lines].
  final int number;
  final String text;
}

/// What [readWindow] produces: the window, plus the two facts the footer needs.
class ReadOutcome {
  const ReadOutcome({
    required this.offset,
    required this.lines,
    required this.totalLines,
    required this.truncatedByBytes,
  });

  /// The 1-based first line asked for, kept even when nothing came back — an
  /// offset past the end still has to report where it looked.
  final int offset;

  final List<ReadLine> lines;

  /// Exact count for the whole file, which is why the scan runs past the window
  /// instead of stopping at it: without the total, the footer cannot tell the
  /// model whether there is more.
  final int totalLines;

  final bool truncatedByBytes;

  int get endLine => lines.isEmpty ? offset - 1 : lines.last.number;

  /// Whether the file continues past what came back.
  bool get hasMore => truncatedByBytes || endLine < totalLines;
}

/// Windows [lines] — a stream so a large file costs its window, not its size.
///
/// The three caps are checked in the order they can each stop the scan: line
/// count, per-line length, total bytes. Byte accounting counts the newline that
/// joins each line to the previous one, so the budget matches the text the model
/// will actually receive.
Future<ReadOutcome> readWindowOf(
  Stream<String> lines, {
  int offset = 1,
  int limit = readLimit,
  int maxLineChars = readMaxLineChars,
  int maxBytes = readMaxBytes,
}) async {
  final window = <ReadLine>[];
  var total = 0;
  var bytes = 0;
  var truncatedByBytes = false;

  await for (final raw in lines) {
    total++;
    // Past the window, or already stopped: keep counting, collect nothing. The
    // count is the whole reason this loop does not `break`.
    if (truncatedByBytes || total < offset || window.length >= limit) continue;

    final text = raw.length > maxLineChars
        ? '${raw.substring(0, maxLineChars)}'
              '... (line truncated to $maxLineChars chars)'
        : raw;
    final cost = utf8.encode(text).length + (window.isEmpty ? 0 : 1);
    if (bytes + cost > maxBytes && window.isNotEmpty) {
      // Stop before the line that would overflow, so the window never exceeds
      // the budget. The `isNotEmpty` guard is what keeps a single over-budget
      // first line from returning nothing at all.
      truncatedByBytes = true;
      continue;
    }
    bytes += cost;
    window.add(ReadLine(total, text));
  }

  return ReadOutcome(
    offset: offset,
    lines: window,
    totalLines: total,
    truncatedByBytes: truncatedByBytes,
  );
}

/// The window as the model reads it: `N: text` per line.
///
/// dsh's own gutter format, and the reason it is a prefix rather than a separate
/// numbers array is that the model quotes line numbers back — it has to see them
/// beside the text, not have to count.
String numberedLines(ReadOutcome outcome) =>
    outcome.lines.map((line) => '${line.number}: ${line.text}').join('\n');

/// The parenthesised trailer: where the window landed, and how to continue.
///
/// Verbatim from `formatReadOutput`, including the three-way split — a capped
/// window and a short window both continue from the same place, but only one of
/// them was the caller's own choice, and the model behaves differently if it
/// cannot tell which happened.
String readFooter(ReadOutcome outcome) {
  final end = outcome.endLine;
  if (outcome.truncatedByBytes) {
    return '(Output capped. Showing lines ${outcome.offset}-$end. '
        'Use offset=${end + 1} to continue.)';
  }
  if (end < outcome.totalLines) {
    return '(Showing lines ${outcome.offset}-$end of ${outcome.totalLines}. '
        'Use offset=${end + 1} to continue.)';
  }
  return '(End of file - total ${outcome.totalLines} lines)';
}

/// Decodes a byte stream into lines, malformed input included.
///
/// `allowMalformed` on purpose: a file with one bad byte should read with a
/// replacement character in it, not fail. A refusal here would send the model
/// looking for another way to read a file it is holding correctly.
Stream<String> decodeLines(Stream<List<int>> bytes) => bytes
    .transform(const Utf8Decoder(allowMalformed: true))
    .transform(const LineSplitter());
