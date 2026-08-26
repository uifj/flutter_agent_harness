// The read card.
//
// Three things carry contracts worth pinning. The gutter shows the FILE's line
// numbers, so a window read past an offset must not re-number from 1 — a reader
// who copies a number out of this card has to be able to jump to it. The banner's
// "showing N of M" note is what distinguishes a window from a whole file, so it
// appears exactly when the read is one. And the copy payload is the file's text
// without the gutter, because the numbers are the card's chrome, not the file's
// content.

import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/primitives/read_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'clipboard_probe.dart';

void main() {
  /// The card at a column width a details panel would give it.
  Future<void> pump(
    WidgetTester tester, {
    String? label,
    required List<ReadBlockLine> lines,
    required int totalLines,
    String? lang,
    int maxLines = defaultReadMaxLines,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: dswThemeData(Brightness.light),
      home: Scaffold(
        body: SizedBox(
          width: 420,
          child: ReadBlock(
            label: label,
            lines: lines,
            totalLines: totalLines,
            lang: lang,
            maxLines: maxLines,
          ),
        ),
      ),
    ),
  );

  /// A window of [count] lines starting at file line [from].
  List<ReadBlockLine> window(int from, int count) => [
    for (var i = 0; i < count; i++)
      ReadBlockLine(number: from + i, text: 'line ${from + i}'),
  ];

  testWidgets('the gutter keeps the file\'s own numbering', (tester) async {
    await pump(tester, lines: window(40, 3), totalLines: 120);

    expect(find.text('40'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    // The window's first row is file line 40, so nothing here is row 1.
    expect(find.text('1'), findsNothing);
  });

  testWidgets('the banner states a window, and stays quiet on a whole file', (
    tester,
  ) async {
    await pump(tester, lines: window(1, 3), totalLines: 120);
    expect(find.text('Showing 3 / 120 lines'), findsOneWidget);

    await pump(tester, lines: window(1, 3), totalLines: 3);
    expect(find.textContaining('Showing'), findsNothing);
  });

  testWidgets('the language is shown when there is one, and skipped when not', (
    tester,
  ) async {
    await pump(tester, lines: window(1, 2), totalLines: 2, lang: 'dart');
    expect(find.text('dart'), findsOneWidget);

    // The source renders the span unconditionally and pays a flex gap for an
    // absent language; this port draws nothing, which is what is pinned here.
    // A label is passed so the banner's deliberately-empty label slot (kept for
    // a constant banner height) is not what this assertion sees.
    await pump(tester, label: 'main.dart', lines: window(1, 2), totalLines: 2);
    expect(find.text(''), findsNothing);
  });

  testWidgets('a long body caps head-heavy and expands to the whole window', (
    tester,
  ) async {
    await pump(tester, lines: window(1, 20), totalLines: 20, maxLines: 8);

    // head 4 / tail 4 of 20, so rows 1-4 and 17-20 survive and the middle does
    // not.
    expect(find.text('line 4'), findsOneWidget);
    expect(find.text('line 5'), findsNothing);
    expect(find.text('line 17'), findsOneWidget);
    expect(find.text('… 12 more lines'), findsOneWidget);

    await tester.tap(find.text('… 12 more lines'));
    await tester.pump();

    expect(find.text('line 5'), findsOneWidget);
    expect(find.text('Collapse'), findsOneWidget);
  });

  testWidgets('the copy control carries the lines without the gutter', (
    tester,
  ) async {
    final clipboard = ClipboardProbe(tester.binding.defaultBinaryMessenger);
    await pump(tester, lines: window(40, 3), totalLines: 120);

    await tester.tap(find.text('Copy'));
    await tester.pump();

    expect(clipboard.text, 'line 40\nline 41\nline 42');
    expect(find.text('Copied'), findsOneWidget);
  });

  testWidgets('an empty read offers nothing to copy', (tester) async {
    // A successful read of an empty file returns no lines; a copy control there
    // would wipe the clipboard with an empty string.
    await pump(tester, lines: const [], totalLines: 0);

    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('a line longer than the card scrolls instead of wrapping', (
    tester,
  ) async {
    await pump(
      tester,
      lines: [ReadBlockLine(number: 1, text: 'x' * 400)],
      totalLines: 1,
    );

    // No overflow: the body's scroller is what a long line runs into, and the
    // indentation a wrapped line would lose is the content of a source line.
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
