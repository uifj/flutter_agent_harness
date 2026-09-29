// ADR-0019 ③: the system paints the bundle name in the title bar, which is the
// same two words the sidebar's brand row already shows about 40px below it. The
// fix in our control is to make that line carry the two facts a user reads it
// for — which conversation, which folder. Only this rule is testable; the OS
// call itself needs a real window.

import 'package:agent_harness/model/window_title.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('composeWindowTitle', () {
    test('the conversation and the folder it works in', () {
      expect(
        composeWindowTitle(
          sessionTitle: 'rename the log files',
          workspaceRoot: '/work/stow',
        ),
        'rename the log files — stow',
      );
    });

    test('a folder alone still beats the bundle name', () {
      expect(composeWindowTitle(workspaceRoot: '/work/stow/'), 'stow');
    });

    test('no workspace yet, so the conversation carries the line', () {
      expect(
        composeWindowTitle(sessionTitle: '  fix the gate  '),
        'fix the gate',
      );
    });

    test('nothing open says nothing, and the system keeps its own line', () {
      expect(composeWindowTitle(), isNull);
      expect(
        composeWindowTitle(sessionTitle: '   ', workspaceRoot: ''),
        isNull,
      );
    });

    test('a long first sentence yields so the folder survives', () {
      final title = composeWindowTitle(
        sessionTitle: 'x' * 200,
        workspaceRoot: '/work/stow',
      )!;
      expect(title.endsWith('— stow'), isTrue);
      expect(title.length, lessThan(60));
    });
  });
}
