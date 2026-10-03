// Two sentences.
//
// 1. LaTeX and Mermaid rendering in `AssistantMarkdown` must not throw — the
//    two features added for the P0 batch.
// 2. A heading must be separated from its neighbours by MORE than a paragraph
//    break is. Audit item 3 ("缺乏视觉层级；段落间距模糊") measured the failure
//    exactly: every gap in a reply was the same 18.4px the renderer puts between
//    two paragraphs, so `## Section` carried no more weight than an empty line.
//    The assertions below are deltas, not absolutes: they say a heading buys
//    `DswShape.xl` above and `DswShape.lg` below *on top of* the paragraph
//    break, which is ZCode's `mt-6 mb-4` law (`message.tsx:442-449`) translated
//    into a box model that collapses nothing.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planstar/theme/dsw_shape.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/conversation/assistant_markdown.dart';

void main() {
  testWidgets('LaTeX inline and block formulas render without error', (
    tester,
  ) async {
    const latex = r'''
Euler's identity: $e^{i\pi} + 1 = 0$

The quadratic formula:

$$x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}$$
''';
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: AssistantMarkdown(latex)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AssistantMarkdown), findsOneWidget);
  });

  testWidgets('Mermaid flowchart renders without error', (tester) async {
    const mermaid = r'''
```mermaid
graph TD
    A[Start] --> B{Decision}
    B -->|Yes| C[OK]
    B -->|No| D[Cancel]
```
''';
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: const Scaffold(
          body: SingleChildScrollView(child: AssistantMarkdown(mermaid)),
        ),
      ),
    );
    // Let the Mermaid parser finish its async work.
    await tester.pumpAndSettle();
    expect(find.byType(AssistantMarkdown), findsOneWidget);
  });

  testWidgets('a heading buys more air than a paragraph break does', (
    tester,
  ) async {
    // Four single-line blocks: two paragraphs to measure the plain break
    // against, then the same paragraph -> heading -> paragraph run the reader
    // actually sees. One line each, so a box's bottom is its text's bottom.
    const source = '''
A paragraph.

B paragraph.

## Heading

C paragraph.
''';
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const AssistantMarkdown(source),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final a = _lineBox(tester, 'A paragraph.');
    final b = _lineBox(tester, 'B paragraph.');
    final h = _lineBox(tester, 'Heading');
    final c = _lineBox(tester, 'C paragraph.');

    // The renderer separates two blocks by one blank line of its own. Nothing
    // here asserts its size on purpose: it is a package internal, and the law
    // below is about the heading being *above* it.
    final plainBreak = _gap(a, b);
    expect(plainBreak, greaterThan(0));

    expect(
      _gap(b, h) - plainBreak,
      moreOrLessEquals(DswShape.xl, epsilon: 0.01),
      reason: 'the space before a title is one paragraph break plus mt-6',
    );
    expect(
      _gap(h, c) - plainBreak,
      moreOrLessEquals(DswShape.lg, epsilon: 0.01),
      reason: 'the space after a title is one paragraph break plus mb-4',
    );
    // The law in the shape the complaint was made in: a title must not sit at
    // the same distance as an empty line.
    expect(_gap(b, h), greaterThan(plainBreak));
    expect(_gap(h, c), greaterThan(plainBreak));
  });
}

/// The painted box of the paragraph that renders exactly [text].
///
/// The renderer draws through `SelectableText`, so `find.text` never matches;
/// the render tree is the only place the words exist.
Rect _lineBox(WidgetTester tester, String text) {
  RenderParagraph? found;
  void visit(Element element) {
    if (found != null) {
      return;
    }
    final render = element.renderObject;
    if (render is RenderParagraph && render.text.toPlainText() == text) {
      found = render;
      return;
    }
    element.visitChildren(visit);
  }

  visit(tester.element(find.byType(AssistantMarkdown)));
  expect(found, isNotNull, reason: 'the fixture stopped rendering "$text"');
  final box = found!;
  final origin = box.localToGlobal(Offset.zero);
  return Rect.fromLTWH(origin.dx, origin.dy, box.size.width, box.size.height);
}

/// The empty space between two stacked boxes.
double _gap(Rect above, Rect below) => below.top - above.bottom;
