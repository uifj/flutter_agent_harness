// Pure concession-chain column solver for the three-column app frame.
//
// A 1:1 port of `deepseek-harness/packages/client/ui-layout/src/client/columns.ts`,
// whose header marks the geometry contract-frozen. The two semantics that are
// easy to lose in translation, and are therefore covered by
// `test/columns_test.dart`:
//
//   1. The sidebar never concedes. Its rendered width is always the drag
//      preference (or the collapsed rail); the center absorbs the last-resort
//      deficit and may drop below [centerMin].
//   2. Auto-closing details is a derived output, not a preference write. Nothing
//      here mutates state, so re-widening the window restores the panel by
//      itself.
//
// The solver is pure and hysteresis-free: output is a function of (viewport,
// preferences) only. It is also breakpoint-free — [sidebarAutoCollapse] is
// applied by the caller via [effectiveSidebarPreference] before solving.

import 'dart:math' as math;

/// Resolved widths for one frame.
///
/// [details] of 0 means visually closed (the panel is never unmounted in dsh);
/// a closed sidebar still keeps its compact rail.
class Columns {
  const Columns({
    required this.sidebar,
    required this.center,
    required this.details,
  });

  final double sidebar;
  final double center;
  final double details;

  @override
  bool operator ==(Object other) =>
      other is Columns &&
      other.sidebar == sidebar &&
      other.center == center &&
      other.details == details;

  @override
  int get hashCode => Object.hash(sidebar, center, details);

  @override
  String toString() =>
      'Columns(sidebar: $sidebar, center: $center, details: $details)';
}

/// Center column floor; only the final fallback may go below it.
const centerMin = 640.0;

/// Sidebar drag clamp floor.
const sidebarMin = 264.0;

/// Sidebar drag clamp ceiling.
const sidebarMax = 420.0;

/// Sidebar width before any user drag.
const sidebarDefault = 280.0;

/// Closed-sidebar rail: a 24px icon column between 16px horizontal paddings.
const sidebarCollapsed = 56.0;

/// Viewport width below which the sidebar auto-collapses to the rail (deepsuite
/// LG breakpoint). A manual toggle below it re-expands over the squeezed center
/// — see [effectiveSidebarPreference].
const sidebarAutoCollapse = 1024.0;

/// Details drag clamp floor.
const detailsMin = 300.0;

/// Details drag clamp ceiling.
const detailsMax = 520.0;

/// Details width before any user drag.
const detailsDefault = 360.0;

/// Clamps a panel width into its contract range.
///
/// Rounds before clamping, matching the source — the bounds are therefore hit
/// exactly rather than fractionally.
double clampWidth(double px, double min, double max) =>
    math.min(max, math.max(min, px.roundToDouble()));

/// Solves the three column widths for one viewport frame.
///
/// [sidebar] and [details] are width preferences in px, where 0 means closed.
/// They are re-clamped here because they cross the state-layer boundary and
/// callers may still hold a stale range.
Columns computeColumns(double viewport, double sidebar, double details) {
  // The sidebar is fixed at its preference (or the rail) — it never concedes.
  final s = sidebar == 0
      ? sidebarCollapsed
      : clampWidth(sidebar, sidebarMin, sidebarMax);
  final d0 = details == 0 ? 0.0 : clampWidth(details, detailsMin, detailsMax);

  // Step 1: everything fits at preferred widths.
  if (s + d0 + centerMin <= viewport) {
    return Columns(sidebar: s, center: viewport - s - d0, details: d0);
  }

  // Step 2: shrink details toward its minimum.
  final d1 = d0 == 0 ? 0.0 : math.max(detailsMin, viewport - s - centerMin);
  if (s + d1 + centerMin <= viewport) {
    return Columns(sidebar: s, center: centerMin, details: d1);
  }

  // Step 3: auto-close details (derived — preferences untouched); center
  // absorbs any remaining deficit (may drop below centerMin).
  return Columns(
    sidebar: s,
    center: math.max(0, viewport - s),
    details: 0,
  );
}

/// Resolves the sidebar preference to hand [computeColumns], applying the
/// [sidebarAutoCollapse] breakpoint that the solver itself stays free of.
///
/// Ported from `AppFrame.tsx:136-141`. Below the breakpoint the sidebar is
/// collapsed unless [narrowExpanded] overrides it, and a narrow re-expand whose
/// wide preference happens to be closed falls back to [sidebarDefault] so the
/// panel has a width to show.
double effectiveSidebarPreference({
  required double viewport,
  required double sidebarPreference,
  required bool narrowExpanded,
}) {
  final narrow = viewport < sidebarAutoCollapse;
  final collapsed = narrow ? !narrowExpanded : sidebarPreference == 0;
  if (collapsed) return 0;
  return sidebarPreference == 0 ? sidebarDefault : sidebarPreference;
}
