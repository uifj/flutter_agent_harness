// Pure concession-chain column solver for the five-region app frame.
//
// A 1:1 port of `deepseek-harness/packages/client/ui-layout/src/client/columns.ts`
// extended with the workbench column and bottom row DSH-better-sidebar adds
// (`src/client/state.ts:117-124`). The semantics that are easy to lose in
// translation, and are therefore covered by `test/columns_test.dart`:
//
//   1. The sidebar never concedes. Its rendered width is always the drag
//      preference (or the collapsed rail); the center absorbs the last-resort
//      deficit and may drop below [centerMin].
//   2. Auto-closing a panel is a derived output, not a preference write. Nothing
//      here mutates state, so re-widening the window restores the panel by
//      itself.
//   3. The workbench concedes last: details shrinks, details closes, then the
//      workbench shrinks, then the workbench closes. The tool surface is the
//      app's reason for existing; the transcript's inspection pane gives way
//      first.
//
// The bottom row is height, not width: it never competes with the columns, so
// it is solved separately by [computeBottom] and clamped only against the
// viewport's height.
//
// The solver is pure and hysteresis-free: output is a function of (viewport,
// preferences) only. It is also breakpoint-free — [sidebarAutoCollapse] is
// applied by the caller via [effectiveSidebarPreference] before solving.

import 'dart:math' as math;

/// Resolved widths for one frame.
///
/// [details] or [workbench] of 0 means visually closed (panels are never
/// unmounted in dsh); a closed sidebar still keeps its compact rail.
class Columns {
  const Columns({
    required this.sidebar,
    required this.center,
    required this.details,
    this.workbench = 0,
  });

  final double sidebar;
  final double center;
  final double details;
  final double workbench;

  @override
  bool operator ==(Object other) =>
      other is Columns &&
      other.sidebar == sidebar &&
      other.center == center &&
      other.details == details &&
      other.workbench == workbench;

  @override
  int get hashCode => Object.hash(sidebar, center, details, workbench);

  @override
  String toString() =>
      'Columns(sidebar: $sidebar, center: $center, details: $details, '
      'workbench: $workbench)';
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

/// Viewport width below which the workbench and the bottom panel merge into
/// one full-width drawer — better-sidebar's `NARROW_MAX_WIDTH`
/// (`breakpoints.ts`).
///
/// Deliberately NOT [sidebarAutoCollapse]: a 900px window (small laptop,
/// split screen) keeps the desktop two-panel layout, and only a
/// phone/portrait-tablet width enters the mobile form. The two breakpoints
/// answer different questions — "does the sidebar need the rail?" and "is
/// there room for two panels?" — and only coincide by accident.
const mobileMergeViewport = 768.0;

/// Details drag clamp floor.
const detailsMin = 300.0;

/// Details drag clamp ceiling.
const detailsMax = 520.0;

/// Details width before any user drag.
const detailsDefault = 360.0;

/// Workbench drag clamp floor — better-sidebar's `PANEL_MIN` (`state.ts:117`).
const workbenchMin = 280.0;

/// Workbench drag clamp ceiling — better-sidebar's `PANEL_MAX` (`state.ts:118`).
const workbenchMax = 640.0;

/// Workbench width before any user drag — better-sidebar's `PANEL_DEFAULT`
/// (`state.ts:119`); the right panel starts open at it.
const workbenchDefault = 400.0;

/// Bottom row drag clamp floor — better-sidebar's `BOTTOM_MIN`
/// (`state.ts:123`).
const bottomMin = 120.0;

/// Bottom row height before any user drag — better-sidebar's `BOTTOM_DEFAULT`
/// (`state.ts:124`); the panel starts closed at it.
const bottomDefault = 220.0;

/// The height the region above the bottom row always keeps. The source clamps
/// the bottom to `viewport - PANEL_MIN` (`state.ts:702`) — its `PANEL_MIN`
/// doing double duty as "the least height worth having" — so this port names
/// the role rather than the reuse.
const bottomKeepAbove = 280.0;

/// Clamps a panel width into its contract range.
///
/// Rounds before clamping, matching the source — the bounds are therefore hit
/// exactly rather than fractionally.
double clampWidth(double px, double min, double max) =>
    math.min(max, math.max(min, px.roundToDouble()));

/// Solves the four column widths for one viewport frame.
///
/// [sidebar], [details] and [workbench] are width preferences in px, where 0
/// means closed. They are re-clamped here because they cross the state-layer
/// boundary and callers may still hold a stale range.
Columns computeColumns(
  double viewport,
  double sidebar,
  double details,
  double workbench,
) {
  // The sidebar is fixed at its preference (or the rail) — it never concedes.
  final s = sidebar == 0
      ? sidebarCollapsed
      : clampWidth(sidebar, sidebarMin, sidebarMax);
  final d0 = details == 0 ? 0.0 : clampWidth(details, detailsMin, detailsMax);
  final w0 = workbench == 0
      ? 0.0
      : clampWidth(workbench, workbenchMin, workbenchMax);

  // Step 1: everything fits at preferred widths.
  if (s + d0 + w0 + centerMin <= viewport) {
    return Columns(
      sidebar: s,
      center: viewport - s - d0 - w0,
      details: d0,
      workbench: w0,
    );
  }

  // Step 2: shrink details toward its minimum.
  final d1 = d0 == 0 ? 0.0 : math.max(detailsMin, viewport - s - w0 - centerMin);
  if (s + d1 + w0 + centerMin <= viewport) {
    return Columns(sidebar: s, center: centerMin, details: d1, workbench: w0);
  }

  // Step 3: auto-close details (derived — preferences untouched).
  if (s + w0 + centerMin <= viewport) {
    return Columns(
      sidebar: s,
      center: viewport - s - w0,
      details: 0,
      workbench: w0,
    );
  }

  // Step 4: the workbench concedes last — shrink it toward its minimum.
  final w1 = w0 == 0
      ? 0.0
      : math.max(workbenchMin, viewport - s - centerMin);
  if (s + w1 + centerMin <= viewport) {
    return Columns(sidebar: s, center: centerMin, details: 0, workbench: w1);
  }

  // Step 5: auto-close the workbench; center absorbs any remaining deficit
  // (may drop below centerMin).
  return Columns(
    sidebar: s,
    center: math.max(0, viewport - s),
    details: 0,
    workbench: 0,
  );
}

/// Solves the bottom row's height for one frame; 0 means closed.
///
/// The ceiling is the viewport less [bottomKeepAbove] — the columns above keep
/// enough height to stay a layout rather than a stack of headers — floored at
/// [bottomMin] so a short viewport still shows a usable panel rather than none.
double computeBottom(double preference, double viewportHeight) {
  if (preference == 0) return 0;
  final max = math.max(bottomMin, viewportHeight - bottomKeepAbove);
  return math.min(max, math.max(bottomMin, preference.roundToDouble()));
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
