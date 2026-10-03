// The one sentence this file holds: the transcript's own blocks - code,
// terminal, diff, search, pill, copy - survive the two things real agent output
// does to them: a 90-character path in a 260px column, and the system's largest
// text step.
//
// Why this file exists: `ui/primitives/` renders inside BOTH the conversation
// and the workbench's diff/search tabs, so one clipped row is paid for twice -
// and none of these six had a test that named it. The audit's "文字墙" complaint
// is about hierarchy, which is a taste call; this guard is about the part that is
// not a taste call: content that cannot fit is cut with no error (ADR-0017 S3's
// measurement, ADR-0013-era narrow-column law from `composer_test.dart`).

import 'package:planstar/ui/primitives/code_block.dart';
import 'package:planstar/ui/primitives/copy_button.dart';
import 'package:planstar/ui/primitives/diff_block.dart';
import 'package:planstar/ui/primitives/pill.dart';
import 'package:planstar/ui/primitives/search_block.dart';
import 'package:planstar/ui/primitives/terminal_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'amplified_text_probe.dart';

/// A path long enough that the row has to choose: shorten it, scroll it, or lose
/// it. Every block here gets the third option checked for.
const longPath =
    '/Users/uifj/Workspace/ActiveProjects/flutter_agent_harness/'
    'lib/ui/conversation/composer.dart';

/// One unbreakable token: no whitespace for `softWrap` to find.
const oneToken =
    'https://internal.example.invalid/api/v2/threads/'
    '01J8ZQ0M7T4VW6XK9YNB2CDF5P/messages?expand=blobs%5B%5D&cursor=eyJvZmZzZXQiOjMxfQ';

const longLine =
    'final resolution = await workspace.resolve(relativePath).then((value) => value.toString());';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget block, {
    required double width,
    double scale = 1.0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => amplifiedAppBuilder(scale, child),
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: block),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Both regimes the audit named: the narrowest column the workbench can hand a
  /// block, and the two largest text steps. Measured, not looked at - a cut label
  /// and a spilled row are silent, and one step does not certify a seat.
  Future<void> fits(WidgetTester tester, Widget block, String reason) async {
    for (final (width, scale) in const [
      (260.0, 1.0),
      (420.0, amplifiedTextStep),
      (420.0, nextTextStep),
    ]) {
      final label = '$reason at ${width.toInt()}px, step $scale';
      await pump(tester, block, width: width, scale: scale);
      // Measured BEFORE the exception is drained: the probe names the row and the
      // child that would not yield, while the framework only says "overflowed by
      // 12 pixels".
      final defects = textDefects(tester);
      final error = tester.takeException();
      expect(defects, isEmpty, reason: label);
      expect(error, isNull, reason: label);
    }
  }

  testWidgets('a code block holds a path, a token and a long line', (
    tester,
  ) async {
    await fits(
      tester,
      CodeBlock(
        code: 'import "$longPath";\n\nconst url = "$oneToken";\n$longLine',
        lang: 'dart',
      ),
      'a code block',
    );
  });

  testWidgets('a terminal block holds a long command, cwd and output', (
    tester,
  ) async {
    await fits(
      tester,
      TerminalBlock(
        command: 'git -C $longPath log --oneline --decorate --graph',
        cwd: '/Users/uifj/Workspace/ActiveProjects/flutter_agent_harness',
        home: '/Users/uifj',
        output: List.generate(
          12,
          (index) => 'commit ${oneToken.substring(0, 20)}$index  $longLine',
        ).join('\n'),
        exitCode: 1,
      ),
      'a terminal block',
    );
  });

  testWidgets('a diff block holds a long path and long rows', (tester) async {
    await fits(
      tester,
      DiffBlock(
        diffs: [
          DiffHunk(
            path: longPath,
            oldText: 'const limit = 120;\n$oneToken',
            newText: 'const limit = 420;\n${longLine * 2}',
          ),
        ],
      ),
      'a diff block',
    );
  });

  testWidgets('a grep card holds a long path and a long matched line', (
    tester,
  ) async {
    await fits(
      tester,
      SearchBlock.matches(
        files: [
          SearchFileGroup(
            path: longPath,
            matches: const [
              SearchBlockLineMatch(lineNumber: 128, line: longLine),
              SearchBlockLineMatch(lineNumber: 129, line: oneToken),
            ],
          ),
        ],
        truncated: true,
        total: 42,
      ),
      'a grep card',
    );
  });

  testWidgets('a glob card holds long paths', (tester) async {
    await fits(
      tester,
      SearchBlock.paths(
        paths: [longPath, '$longPath/../assistant_markdown.dart', oneToken],
        truncated: false,
        total: 3,
      ),
      'a glob card',
    );
  });

  testWidgets('a pill keeps its label on one line', (tester) async {
    await fits(
      tester,
      const Pill(label: 'review the quarterly report'),
      'a pill',
    );
    await fits(
      tester,
      const Pill(label: longPath, height: 22),
      'a pill capped to the terminal line',
    );
  });

  testWidgets('a copy button keeps its label beside a long path', (
    tester,
  ) async {
    await fits(
      tester,
      Builder(
        builder: (context) {
          final color = context.dsw;
          return Row(
            children: [
              Expanded(child: Text(longPath)),
              CopyButton(
                text: oneToken,
                idleColor: color.labelTertiary,
                hoverColor: color.labelPrimary,
              ),
            ],
          );
        },
      ),
      'a copy button',
    );
  });
}
