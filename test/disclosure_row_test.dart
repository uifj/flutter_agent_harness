// The one line a disclosure header is allowed to be.
//
// Every tool card and the reasoning row in the transcript is this header plus a
// body, and the title it renders is a model- or path-sized string — the longest
// text in the app that lands in a row whose width is whatever the centre column
// happens to be at the moment. So the contract is: one line, shortened, at any
// width.
//
// This file exists because of the mechanical fact the fix turns on: a `Text`
// that is NOT a flex child of a `Row` is measured with an unbounded main-axis
// width, which makes `overflow: ellipsis` on it a decoration rather than a
// guard. The same mistake overflowed the composer's workspace bar by 487 pixels
// and would have overflowed every tool card whose path is long enough.

import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/primitives/disclosure_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const title =
      'read /Users/uifj/Workspace/ActiveProjects/flutter_agent_harness/'
      'lib/ui/conversation/composer.dart';

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    Widget? collapsed,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: dswThemeData(Brightness.light),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: DisclosureRow(
              icon: const Icon(Icons.chevron_right),
              title: title,
              open: false,
              expandable: true,
              onToggle: () {},
              collapsed: collapsed,
            ),
          ),
        ),
      ),
    ),
  );

  testWidgets('a title longer than the row is shortened, not spilled', (
    tester,
  ) async {
    await pump(tester, width: 180);

    expect(tester.takeException(), isNull);
    final shown = tester.widget<Text>(find.text(title));
    expect(shown.overflow, TextOverflow.ellipsis);
    expect(shown.maxLines, 1);
    // One 24px line whatever the width — nothing under the header is pushed
    // aside by a title that ran over.
    expect(tester.getSize(find.byType(DisclosureRow)).height, 24);
    expect(tester.getSize(find.byType(DisclosureRow)).width, 180);
  });

  testWidgets('the collapsed preview shares the line instead of competing', (
    tester,
  ) async {
    await pump(tester, width: 180, collapsed: const Text('2 files changed'));

    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(DisclosureRow)).height, 24);
  });
}
