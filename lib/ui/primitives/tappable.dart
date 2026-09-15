// The bare clickable affordance shared by the block primitives.
//
// Before this, every hover-and-tap control (the copy label, the disclosure
// header, the "… N more lines" toggle, a search result's file row) hand-rolled
// the same `MouseRegion` + `GestureDetector` + `setState(_hovered)` triple.
// That triple is mouse-only: it adds nothing to the focus traversal order, so
// Space/Enter never reach it, and VoiceOver sees a plain text node with no
// button role. The 2026-09 audit filed that as the blocker (A1: keyboard
// cannot operate the app; A3: no semantics on the custom controls).
//
// `FocusableActionDetector` is the framework's own answer and — like the
// `ShadFocusable` shad uses inside its buttons — it paints nothing, so the
// visuals stay exactly the [builder]'s: block geometry, the row's 24px height,
// the hover cross-fade, all unchanged. Pointer taps keep working through the
// `GestureDetector` inside; keyboard activation reaches [onTap] through the
// detector's activation intent and `onActivate`.
//
// CapsuleButton went to `ShadButton` outright because it IS a decorated button
// and gains shad's variant/state machinery for free. These four are bare
// affordances embedded in ported chrome where a decorated button would shift
// pixels, so they take the minimal focusable wrapper instead. Both routes end
// at the same place: keyboard-reachable, semantically a button.

import 'package:flutter/material.dart';

/// Builds the affordance's visuals from its interaction state.
///
/// [hovered] replaces the old `_hovered`; [focused] is new — a keyboard user
/// gets the same brightening a mouse hover does, since that is the only
/// affordance the ported chrome has.
typedef DswHoverTapBuilder =
    Widget Function(BuildContext context, bool hovered, bool focused);

/// A hover/pointer/keyboard/semantics clickable that draws nothing itself.
class DswHoverTap extends StatefulWidget {
  const DswHoverTap({
    super.key,
    required this.onTap,
    required this.builder,
    this.semanticLabel,
    this.expanded,
    this.excludeSemantics = false,
    this.enabled = true,
    this.autofocus = false,
  });

  /// The action both a tap and a keyboard activation run. Null disables it.
  final VoidCallback? onTap;

  final DswHoverTapBuilder builder;

  /// The button's accessible name. When null, the label comes from the
  /// rendered text subtree instead (fine for a "Copy" label, wrong for an
  /// icon-only or stateful control whose visible text is not its name).
  final String? semanticLabel;

  /// Set on an expand/collapse control so the state is announced.
  final bool? expanded;

  /// Hides the descendant text from accessibility, so only [semanticLabel] is
  /// read. The block toggle sets this because its label text ("… 3 more lines")
  /// is a hint, not a name.
  final bool excludeSemantics;

  final bool enabled;

  /// Steals focus on first build. Not set by any current call site; it exists
  /// so a widget test can focus the control and drive it from the keyboard
  /// without hand-building a focus traversal order around it.
  final bool autofocus;

  bool get _interactive => enabled && onTap != null;

  @override
  State<DswHoverTap> createState() => _DswHoverTapState();
}

class _DswHoverTapState extends State<DswHoverTap> {
  bool _hovered = false;
  bool _focused = false;

  void _activate() => widget.onTap?.call();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: widget.enabled,
    expanded: widget.expanded,
    label: widget.semanticLabel,
    // The tap action has to be declared here: a bare `Semantics(button: true)`
    // exposes no `SemanticsAction.tap`, so a screen reader's double-tap would
    // announce a button that does nothing. Wiring `onTap` makes activate-from-
    // accessibility reach the same callback a pointer or Enter does.
    onTap: widget._interactive ? _activate : null,
    excludeSemantics: widget.excludeSemantics,
    child: FocusableActionDetector(
      enabled: widget._interactive,
      autofocus: widget.autofocus,
      mouseCursor: widget._interactive
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onShowHoverHighlight: (hovering) => setState(() => _hovered = hovering),
      onFocusChange: (focused) => setState(() => _focused = focused),
      actions: <Type, Action<Intent>>{
        // Enter/Space (and a screen-reader's activate gesture) arrive here.
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget._interactive ? _activate : null,
        behavior: HitTestBehavior.opaque,
        child: Builder(
          builder: (context) =>
              widget.builder(context, _hovered || _focused, _focused),
        ),
      ),
    ),
  );
}
