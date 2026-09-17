// Verifies that LaTeX and Mermaid rendering in AssistantMarkdown
// does not throw — the two features added for the P0 batch.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/conversation/assistant_markdown.dart';

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
}
