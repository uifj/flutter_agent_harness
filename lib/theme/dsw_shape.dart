// Shape tokens: radius, spacing rhythm and control sizes.
//
// The first non-colour token file in `lib/theme/`. `DswStatic`'s rule — "feature
// code must not use this directly" — does NOT apply here: these constants exist
// to be used by widgets. It is separate from `DswAlias` for a real reason
// (ADR-0017): the alias layer declares every field twice because colour changes
// with brightness, and radius does not. Putting shape in `DswAlias` would create
// two fields that must always be equal, which is the failure mode ADR-0014
// already rejects elsewhere.
//
// ## The radius law
//
// Radius follows nesting depth and decreases inwards. A value that does not
// match its container's depth is a bug, not a new size — and there is no
// seventh tier: adding one means amending ADR-0017.
//
//   float     16  a surface that sits above the page rather than inside it:
//                 the composer card, a dialog, a full-screen settings card.
//                 ZCode's own composer is `rounded-2xl` = 16px, so this tier is
//                 what keeps that look without a bespoke number.
//   shell     12  the outermost in-page container: workbench panel, dropdown
//                 menu, popover
//   card      10  a card inside a shell: composer container, message block,
//                 code block
//   control    8  anything you click: button, field, session row, chip
//   inner      6  decoration inside a control: row highlight, small badge
//   inset      4  the innermost: tab corner, a box around a status dot
//   pill     999 fully round. Also the right answer for dots and avatars —
//                 Flutter clamps radius to half the box, so a 2px dot and a 44px
//                 avatar both come out circular without a bespoke value.

import 'package:flutter/painting.dart';

/// Radius, spacing and size constants (ADR-0017).
abstract final class DswShape {
  // --- radius ---------------------------------------------------------------

  static const float = 16.0;
  static const shell = 12.0;
  static const card = 10.0;
  static const control = 8.0;
  static const inner = 6.0;
  static const inset = 4.0;
  static const pill = 999.0;

  /// Radius as a `BorderRadius`, which is what every call site actually wants.
  static BorderRadius radius(double tier) => BorderRadius.circular(tier);

  // --- spacing --------------------------------------------------------------
  //
  // Base 4px, and only these steps. A gap that is not on this scale is a
  // rounding accident waiting to be read as a decision.

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;

  static const gapXs = EdgeInsets.all(xs);
  static const gapSm = EdgeInsets.all(sm);
  static const gapMd = EdgeInsets.all(md);
  static const gapLg = EdgeInsets.all(lg);

  /// The sidebar's single horizontal inset. Every row — brand, mode toggle,
  /// new-session, the session list — starts on this line because the whole
  /// column is padded by it once. It was 12 on the column plus 4 more on the
  /// brand row, which is how a logo ended up not lining up with its own list.
  static const sidebarInset = 12.0;

  static const rowInset = EdgeInsets.symmetric(horizontal: sm, vertical: xs);

  // --- sizes ----------------------------------------------------------------
  //
  // Clickables that sit on one line must be the same height; that invariant is
  // what "the controls do not line up" was really reporting.

  /// A session row in the sidebar.
  static const rowSession = 36.0;

  /// A standard icon button.
  static const controlMd = 28.0;

  /// A small glyph inside a chip or status row.
  static const iconSm = 14.0;

  /// A dot that marks state (running, unread, waiting).
  static const dot = 6.0;

  /// Extra transparent hit area around a small control, so a 14px icon is still
  /// a target a person can aim at.
  static const hitSlop = 4.0;
}
