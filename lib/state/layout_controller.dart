// Panel geometry: width preferences, drags, and the narrow-viewport override.
//
// A 1:1 port of dsh's `ui-layout/src/client/stores.ts`. The preference IS the
// width, so closing a panel forgets its drag width and reopening restores the
// contract default. Nothing here derives layout — that is `computeColumns`'s job,
// and it is a pure function of these values plus the viewport.

import 'package:flutter/foundation.dart';

import '../ui/layout/columns.dart';

class LayoutController extends ChangeNotifier {
  /// Sidebar width preference in px; 0 means closed.
  double get sidebar => _sidebar;
  double _sidebar = sidebarDefault;

  /// Details width preference in px; 0 means closed. Starts closed.
  double get details => _details;
  double _details = 0;

  /// Mirrors the frame's breakpoint reading, so [toggleSidebar] can pick its
  /// semantics. The frame solves its geometry from the viewport directly — this
  /// flag decides what a toggle *means*, never how wide anything is.
  bool get narrow => _narrow;
  bool _narrow = false;

  /// The manual override that re-expands an auto-collapsed sidebar over the
  /// squeezed center, without rewriting the width preference.
  bool get narrowExpanded => _narrowExpanded;
  bool _narrowExpanded = false;

  /// Drag write. Clamped into the contract range, which is why a drag can never
  /// cross the open/closed line — the minimum is well above zero.
  void setSidebar(double px) {
    final next = clampWidth(px, sidebarMin, sidebarMax);
    if (next == _sidebar) return;
    _sidebar = next;
    notifyListeners();
  }

  void setDetails(double px) {
    final next = clampWidth(px, detailsMin, detailsMax);
    if (next == _details) return;
    _details = next;
    notifyListeners();
  }

  /// While narrow, flips only the override: the width preference survives
  /// untouched, so re-widening the window restores the pre-squeeze layout.
  void toggleSidebar() {
    if (_narrow) {
      _narrowExpanded = !_narrowExpanded;
    } else {
      _sidebar = _sidebar == 0 ? sidebarDefault : 0;
    }
    notifyListeners();
  }

  /// Fed by the frame on every viewport change.
  ///
  /// Crossing the breakpoint in either direction drops the override: narrow
  /// defaults to auto-collapsed, wide defaults to the preference.
  void setNarrow(bool value) {
    if (_narrow == value) return;
    _narrow = value;
    _narrowExpanded = false;
    notifyListeners();
  }

  void openDetails() {
    if (_details != 0) return;
    _details = detailsDefault;
    notifyListeners();
  }

  void closeDetails() {
    if (_details == 0) return;
    _details = 0;
    notifyListeners();
  }

  void toggleDetails() => _details == 0 ? openDetails() : closeDetails();

  /// True while a divider is being dragged. Column animations are suppressed for
  /// the duration, matching `.frame[data-dragging] { transition: none }` — an
  /// animated column cannot follow the pointer.
  bool get isDragging => _isDragging;
  bool _isDragging = false;

  set isDragging(bool value) {
    if (_isDragging == value) return;
    _isDragging = value;
    notifyListeners();
  }
}
