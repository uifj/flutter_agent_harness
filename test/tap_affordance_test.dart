// A tap affordance must be able to be tapped without a mouse.
//
// `DswHoverTap` exists because the repo used to hand-roll the same
// `MouseRegion` + `GestureDetector` + `setState(_hovered)` triple in every
// hover control; the primitive carries pointer, keyboard, semantics and
// right-click, and `dsw_hover_tap_test.dart` proves those four once — which is
// why converting a site needs no per-site keyboard test.
//
// Five controls had nevertheless grown the triple again (the shell's round
// toggle, the free window's close, an empty pane's welcome action, the plan
// header's workspace switch, a document chip's remove). Each was mouse-only:
// outside the focus traversal order, so Enter and Space never reached it, and
// with no button role for a screen reader.
//
// So this file holds one structural claim: a raw `GestureDetector` that carries
// a tap is either the primitive itself or one of the reviewed sites below. The
// allow-list is deliberately file-keyed rather than line-keyed, because a line
// number moves the moment anything above it changes; the reason each entry is
// legal is written next to it and belongs in the file.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every raw detector in `lib/ui` that claims a tap, as `path -> count`.
Map<String, int> rawTapDetectors() {
  final found = <String, int>{};
  for (final file
      in Directory('lib/ui')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      final text = lines[i].trim();
      if (text.startsWith('//') || !text.contains('GestureDetector(')) continue;
      if (_topLevelTapArg(lines, i)) {
        found.update(
          file.path.replaceAll(r'\', '/'),
          (v) => v + 1,
          ifAbsent: () => 1,
        );
      }
    }
  }
  return found;
}

/// Whether `onTap`/`onTapDown` is an argument of the detector opened on
/// [startLine], as opposed to one of its children's. Depth is tracked over the
/// parentheses and braces, so a callback belonging to a nested widget does not
/// count against its ancestor.
bool _topLevelTapArg(List<String> lines, int startLine) {
  // Depth is counted from the detector's own opening bracket, not from the
  // start of the line: `builder: (context, …) => GestureDetector(` would
  // otherwise carry the enclosing `builder(` as a level of its own, and the
  // pane body — one of the reviewed sites — reads as depth 2 instead of 1.
  final opened = lines[startLine].indexOf('GestureDetector(');
  var depth = _delta(lines[startLine].substring(opened));
  for (var i = startLine + 1; i < lines.length && i < startLine + 40; i++) {
    if (depth == 1 && RegExp(r'\bonTap(Down|Up)?\s*:').hasMatch(lines[i])) {
      return true;
    }
    depth += _delta(lines[i]);
    if (depth <= 0) return false;
  }
  return false;
}

int _delta(String line) {
  var depth = 0;
  for (final char in line.split('')) {
    if (char == '(' || char == '{' || char == '[') {
      depth++;
    } else if (char == ')' || char == '}' || char == ']') {
      depth--;
    }
  }
  return depth;
}

void main() {
  test('a raw tap detector is the primitive or a reviewed exception', () {
    const allowed = {
      // The primitive itself: this is where the pointer half of the affordance
      // has to live.
      'lib/ui/primitives/tappable.dart': 1,
      // Tap-away scrim for the footer's cascading menu. A scrim is not a
      // control; the keyboard way out is the menu's own `CallbackShortcuts`
      // Escape, which is what the audit's F3 item installed.
      'lib/ui/settings/widgets/settings_quick_menu.dart': 1,
      // The gesture that aims the next open at this pane, on the pane BODY
      // (translucent hit test). Activating a pane by clicking its middle is a
      // pointer gesture for a region, not an action for a control; tab
      // activation already moves focus.
      'lib/ui/workbench/pane.dart': 1,
      // The tab chip: tap-to-activate, right-click menu, middle-click close,
      // drag-reorder. It deliberately wraps its OWN `FocusableActionDetector`
      // plus `Semantics(selected:)` rather than `DswHoverTap`, because the
      // screen-reader role a tab needs is `selected`, not `button`
      // (`workbench_tab_bar.dart:415-419`). Keyboard parity is there, just not
      // through this primitive.
      'lib/ui/workbench/workbench_tab_bar.dart': 1,
    };
    expect(rawTapDetectors(), allowed, reason: 'a new mouse-only tap');
  });
}
