// The read window. Its three caps and its footer are what the model uses to
// decide whether to read again, so each cap is asserted through the footer text
// as well as the window — a correct window under a footer that says "end of
// file" would silently lose the rest of a file.

import 'dart:convert';

import 'package:agent_harness/genkit/read_window.dart';
import 'package:flutter_test/flutter_test.dart';

/// A line stream from literal lines, which is what `decodeLines` produces.
Stream<String> lines(List<String> of) => Stream.fromIterable(of);

void main() {
  group('the window', () {
    test('numbers from one and reports the whole file', () async {
      final outcome = await readWindowOf(lines(['a', 'b', 'c']));

      expect(numberedLines(outcome), '1: a\n2: b\n3: c');
      expect(outcome.totalLines, 3);
      expect(outcome.endLine, 3);
      expect(outcome.hasMore, isFalse);
      expect(readFooter(outcome), '(End of file - total 3 lines)');
    });

    test('starts at the offset, numbering by file position', () async {
      final outcome = await readWindowOf(
        lines(['a', 'b', 'c', 'd']),
        offset: 3,
      );

      // The numbers are the file's, not the window's — the model quotes them
      // back at us.
      expect(numberedLines(outcome), '3: c\n4: d');
      expect(outcome.totalLines, 4);
    });

    test('keeps counting past the limit so the footer can say how far',
        () async {
      final outcome = await readWindowOf(
        lines(['a', 'b', 'c', 'd', 'e']),
        limit: 2,
      );

      expect(outcome.lines, hasLength(2));
      expect(outcome.totalLines, 5, reason: 'the scan does not stop at the cap');
      expect(outcome.hasMore, isTrue);
      expect(
        readFooter(outcome),
        '(Showing lines 1-2 of 5. Use offset=3 to continue.)',
      );
    });

    test('an offset past the end returns nothing and admits the file is short',
        () async {
      final outcome = await readWindowOf(lines(['a', 'b']), offset: 9);

      expect(outcome.lines, isEmpty);
      expect(outcome.totalLines, 2);
      // Not "use offset=10 to continue": there is nothing to continue into, and
      // saying so is what stops the model from paging forever.
      expect(readFooter(outcome), '(End of file - total 2 lines)');
    });
  });

  group('the caps', () {
    test('a long line is cut with a marker, not dropped', () async {
      final outcome = await readWindowOf(
        lines(['x' * 40, 'short']),
        maxLineChars: 10,
      );

      expect(
        outcome.lines.first.text,
        '${'x' * 10}... (line truncated to 10 chars)',
      );
      expect(outcome.lines.last.text, 'short');
    });

    test('the byte budget stops the window and says it was capped', () async {
      // Each line is 4 bytes, plus one for the newline joining it to the last.
      final outcome = await readWindowOf(
        lines(['aaaa', 'bbbb', 'cccc', 'dddd']),
        maxBytes: 10,
      );

      expect(outcome.lines.map((l) => l.text), ['aaaa', 'bbbb']);
      expect(outcome.truncatedByBytes, isTrue);
      expect(outcome.hasMore, isTrue);
      expect(
        readFooter(outcome),
        '(Output capped. Showing lines 1-2. Use offset=3 to continue.)',
      );
    });

    test('a first line over budget still comes back', () async {
      final outcome = await readWindowOf(lines(['x' * 100]), maxBytes: 10);

      // Returning an empty window here would look to the model like an empty
      // file, which is a worse lie than an over-budget line.
      expect(outcome.lines, hasLength(1));
      expect(outcome.lines.single.text, 'x' * 100);
      expect(outcome.truncatedByBytes, isFalse);
    });

    test('bytes are counted as bytes, not characters', () async {
      // Three characters, nine bytes: two such lines overrun a 10-byte budget
      // that six ASCII characters would sit well inside.
      final outcome = await readWindowOf(
        lines(['日本語', '日本語']),
        maxBytes: 10,
      );

      expect(outcome.lines, hasLength(1));
      expect(outcome.truncatedByBytes, isTrue);
    });
  });

  group('decoding', () {
    test('splits on both line endings', () async {
      final outcome = await readWindowOf(
        decodeLines(Stream.value(utf8.encode('a\nb\r\nc'))),
      );

      expect(outcome.lines.map((l) => l.text), ['a', 'b', 'c']);
    });

    test('a malformed byte reads as a replacement, not a failure', () async {
      final outcome = await readWindowOf(
        decodeLines(Stream.value([0x61, 0xff, 0x62])),
      );

      // The alternative is throwing, which would send the model looking for
      // another way to read a file it is already holding correctly.
      expect(outcome.lines.single.text, contains('a'));
      expect(outcome.lines.single.text, contains('b'));
    });
  });
}
