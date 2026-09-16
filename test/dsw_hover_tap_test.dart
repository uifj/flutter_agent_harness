// The one runnable check behind the DswHoverTap primitive (ADR-0002 stage 5).
//
// DswHoverTap exists to turn the app's mouse-only `MouseRegion + GestureDetector`
// affordances into keyboard-reachable, screen-reader-labelled buttons without
// changing a single painted pixel. That is only true if three things actually
// hold, and each is asserted here rather than eyeballed:
//
//   1. a pointer tap still runs the action (the GestureDetector inside works),
//   2. the keyboard runs it too (FocusableActionDetector's default
//      Enter/Space -> ActivateIntent reaches the same callback), and
//   3. assistive tech sees a real button with a tap action and the name it was
//      given, not a bare text node.
//
// If a future edit drops the FocusableActionDetector or the Semantics wrapper,
// #2 and #3 fail and this file says so — the whole point of the primitive.

import 'package:agent_harness/ui/primitives/tappable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Directionality(textDirection: TextDirection.ltr, child: child),
);

void main() {
  testWidgets('a pointer tap runs the action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        DswHoverTap(
          onTap: () => taps++,
          semanticLabel: 'Copy',
          builder: (context, _, _) => const Text('Copy'),
        ),
      ),
    );
    await tester.tap(find.text('Copy'));
    expect(taps, 1);
  });

  testWidgets('the keyboard activates it once focused', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        DswHoverTap(
          autofocus: true,
          onTap: () => taps++,
          semanticLabel: 'Copy',
          builder: (context, _, _) => const Text('Copy'),
        ),
      ),
    );
    // Autofocus must actually land on the control, or the rest is vacuous.
    expect(Focus.of(tester.element(find.text('Copy'))).hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('assistive tech sees a named button with a tap action', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        DswHoverTap(
          onTap: () {},
          semanticLabel: 'Copy',
          // The visible label is a hint, not the name (as in block_chrome):
          // excluding the text child keeps the node's name exactly 'Copy'.
          excludeSemantics: true,
          builder: (context, _, _) => const Text('Copy'),
        ),
      ),
    );
    // Target the leaf: find.byType(DswHoverTap) resolves to the merged root,
    // which carries no actions. The Text's nearest semantics node IS the button.
    final node = tester.getSemantics(find.text('Copy'));
    expect(
      node,
      matchesSemantics(
        label: 'Copy',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('a secondary (right) tap reaches onSecondaryTapDown', (
    tester,
  ) async {
    var secondary = 0;
    await tester.pumpWidget(
      _host(
        DswHoverTap(
          onTap: () {},
          onSecondaryTapDown: (_) => secondary++,
          semanticLabel: 'Row',
          excludeSemantics: true,
          builder: (context, _, _) => const Text('Row'),
        ),
      ),
    );
    // The git file/log rows open a context menu on right-click; the primary
    // action must not swallow it.
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Row')),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await gesture.up();
    await tester.pump();
    expect(secondary, 1);
  });
}
