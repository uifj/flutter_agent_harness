// The two ways a shell fails when the system amplifies text, both measured.
//
// Every other widget test in this repo runs under `TextScaler.noScaling`, so
// none of them shows the UI at a larger step. Two failure modes exist and only
// one of them announces itself:
//
//   * a horizontal `RenderFlex` that overflows is *itself* sized to its
//     constraint, so the only way to see the spill is to add its children up;
//   * a paragraph clipped by a fixed-height seat throws no error at all - the
//     framework says nothing, and the label is just cut. Its intrinsic height
//     has to be compared against the box it was handed.
//
// Both need the render tree rather than a screenshot, so both live here and a
// host test only asserts the returned list is empty. The list carries the
// numbers and the owner's creator chain, because a guard that cannot name the
// widget it rejected is a guard nobody can act on.

import 'package:planstar/ui/primitives/tappable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// macOS's largest step short of XXL - the one that breaks chrome.
const double amplifiedTextStep = 1.8;

/// The step above it, because one step does not certify a seat.
///
/// A 36px line is exactly one line of 14/20 at 1.8 - the guard passes and says
/// nothing. At this step the same seat cuts the label and the time next to it
/// (`44.0 vs 36.0`, measured on the session row), which is how the seat law got
/// its second number.
const double nextTextStep = 2.2;

/// Pumps [child] under [step] of the platform's own scaler.
///
/// It is a `StatelessWidget` rather than a `Builder` assigned to the variable it
/// reads: a closure that captures the variable it is assigning to builds itself
/// forever, and the frame dies with a StackOverflowError.
class AmplifiedText extends StatelessWidget {
  const AmplifiedText({
    super.key,
    required this.child,
    this.step = amplifiedTextStep,
  });

  final Widget child;
  final double step;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(step)),
    child: child,
  );
}

/// A host's `MaterialApp.builder` for a walk at [step].
///
/// The step has to be composed **above the Navigator** - which is exactly where
/// `main.dart` composes the user's font step - because a `MediaQuery` under the
/// Navigator does not reach an overlay route. Measured: a `PopupMenuButton`
/// opened from a subtree wrapped in [AmplifiedText] still read 1.0, so a host
/// that wraps inside `home:` has been measuring every popup, menu and drag
/// feedback at the designed step and calling that a pass.
Widget amplifiedAppBuilder(double step, Widget? child) =>
    AmplifiedText(step: step, child: child!);

/// Rows whose children together want more width than the row was given.
List<String> spillDefects(WidgetTester tester) {
  final found = <String>[];
  for (final ro in tester.allRenderObjects.whereType<RenderFlex>()) {
    if (ro.direction != Axis.horizontal) continue;
    // An overlay entry that is mounted but not shown is still in
    // `allRenderObjects`, and nothing in its subtree has ever been laid out:
    // `size` and `constraints` both assert there. shad keeps a closed popover or
    // select popup mounted this way (`OverlayPortal`), so without this line a
    // host that merely contains a menu measures nothing and throws instead.
    if (!ro.hasSize) continue;
    final max = ro.constraints.maxWidth;
    if (max >= double.infinity) continue;
    final children = ro
        .getChildrenAsList()
        .whereType<RenderBox>()
        .where((b) => b.hasSize)
        .toList();
    final sum = children.fold<double>(0, (a, b) => a + b.size.width);
    if (sum <= max + 0.5) continue;
    // The row alone is not actionable: which child would not yield is the
    // difference between "give the label a Flexible" and "the fixed cell is
    // too narrow for the step".
    found.add(
      '${sum.toStringAsFixed(1)} vs ${max.toStringAsFixed(1)} '
      '[${children.map(_describe).join(' + ')}] '
      ':: ${_owner(tester, ro, 8)}',
    );
  }
  return found;
}

String _describe(RenderBox box) {
  final ro = box;
  final label = ro is RenderParagraph
      ? '"${ro.text.toPlainText()}"'
      : ro.toStringShort();
  return '$label ${box.size.width.toStringAsFixed(1)}';
}

/// Labels the seat they sit in is too short to show.
List<String> clipDefects(WidgetTester tester) {
  final found = <String>[];
  for (final el in tester.allElements) {
    final ro = el.renderObject;
    if (ro is! RenderParagraph || !ro.hasSize) continue;
    // Nothing is lost when an empty paragraph is squeezed - and xterm draws one
    // per cell, so counting them would drown the real findings.
    if (ro.text.toPlainText().isEmpty) continue;
    final needed = ro.getMaxIntrinsicHeight(ro.size.width);
    if (needed <= ro.size.height + 0.5) continue;
    found.add(
      '${needed.toStringAsFixed(1)} vs ${ro.size.height.toStringAsFixed(1)} '
      ':: "${ro.text.toPlainText()}" <- ${_owner(tester, ro, 6)}',
    );
  }
  return found;
}

/// Both axes at once - what a host test asserts is empty.
List<String> textDefects(WidgetTester tester) => [
  ...spillDefects(tester),
  ...clipDefects(tester),
];

String _owner(WidgetTester tester, RenderObject ro, int depth) {
  for (final el in tester.allElements) {
    if (el.renderObject == ro) return el.debugGetCreatorChain(depth);
  }
  return ro.toStringShort();
}

/// The other ruler: not geometry but **names**. An icon-only control says
/// nothing to a screen reader unless it carries a label, a tooltip or a visible
/// word, and nothing about a fixed-height seat proves that. Returns one entry
/// per icon-only control that names itself with nothing, tagged with the icon's
/// codepoint so the report survives the control moving in the tree.
List<String> unlabelledIconControls(WidgetTester tester) {
  final offenders = <String>[];
  void check(String kind, Finder finder, String? Function(Finder) label) {
    for (var i = 0; i < finder.evaluate().length; i++) {
      final at = finder.at(i);
      if (label(at) != null) continue;
      bool any(Finder f) => f.evaluate().isNotEmpty;
      if (any(find.descendant(of: at, matching: find.byType(Tooltip))) ||
          any(find.ancestor(of: at, matching: find.byType(Tooltip)))) {
        continue;
      }
      final iconOnly =
          any(find.descendant(of: at, matching: find.byType(Icon))) &&
          !any(find.descendant(of: at, matching: find.byType(Text)));
      if (!iconOnly) continue;
      final code = tester
          .widgetList<Icon>(
            find.descendant(of: at, matching: find.byType(Icon)),
          )
          .map((w) => w.icon?.codePoint.toRadixString(16))
          .join('+');
      offenders.add('$kind#$i u$code');
    }
  }

  check(
    'tap',
    find.byType(DswHoverTap),
    (f) => tester.widget<DswHoverTap>(f).semanticLabel,
  );
  check(
    'iconButton',
    find.byType(IconButton),
    (f) => tester.widget<IconButton>(f).tooltip,
  );
  return offenders;
}
