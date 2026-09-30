// The bridge from the dsw token layer to shadcn_ui's theme (ADR-0002,
// decision 4: route A).
//
// shadcn_ui supplies component architecture — focus, semantics, states, the
// variant system — and the dsw alias layer keeps supplying every colour, so
// the app's dsh visual identity does not move. This file is the one place the
// two systems meet: it maps a [DswAlias] instance onto a `ShadColorScheme`
// field by field. Nothing else may construct a `ShadThemeData`, and no
// feature code may read `ShadTheme.of` for colour — tokens still come from
// `context.dsw`, exactly as before.
//
// Two deliberate omissions:
//   * No text theme mapping. DSW type scale (`DswType`) stays authoritative;
//     components that need it pass a DSW style at the call site rather than
//     inheriting shad's default ramp, which would fork a second typography.
//
// Radius is NOT omitted any more (ADR-0029, which supersedes this file's earlier
// "shad's default (6) is left alone"). shad has a single `radius` knob where
// `DswShape` has a ramp, so the knob can only answer for one tier, and it takes
// the one most shad surfaces here actually are: `control` (fields, toasts, the
// card inside a dialog). A surface that means another tier says so itself — the
// two dialogs pass `float`, and `test/shad_radius_test.dart` fails any new
// `ShadDialog` that forgets to.
//
// The overlay family is the third thing this file says (ADR-0036 decision 4,
// which re-seams ADR-0028): a select's dropdown, a popover and a context menu
// all read `popoverTheme.decoration`, so one skin here replaces the one
// `popupMenuTheme` used to give Material's menus. The law is unchanged — one
// skin, said once, in the theme — only the seam moved.

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'dsw_alias.dart';
import 'dsw_shape.dart';
import 'dsw_typography.dart';

/// The shad theme for one brightness, coloured entirely by [DswAlias].
///
/// Brightness must match the `DswAlias` instance handed in — the palette is
/// half of a pair and a light alias under a dark flag would theme every
/// component backwards.
///
/// [textScale] is the composed text scaler the tree under this theme will see
/// (`MediaQuery.textScalerOf(context).scale(1)`), and it exists because shad
/// sizes some seats with a plain double: `ShadContextMenuItem` hands its height
/// to `ShadButton.raw(height:)`, which clamps min AND max, so a constant would
/// silently cut a scaled label (ADR-0017 S3).
ShadThemeData dswShadTheme(Brightness brightness, {double textScale = 1}) {
  final isDark = brightness == Brightness.dark;
  final c = isDark ? DswAlias.dark : DswAlias.light;
  return ShadThemeData(
    brightness: brightness,
    colorScheme: dswShadColorScheme(c),
    // dsh dims a disabled control to 40%, not shad's 50% default. Every shad
    // component expresses "off" through `ShadDisabled`, so unlike Material's
    // `labelTextStyle` this needs no disabled branch written by hand.
    disabledOpacity: 0.4,
    // One knob for every shad surface, so it answers for the tier most of them
    // are: a field, a toast, the card inside a dialog. `control` is that tier —
    // shad's own 6 is not a number this design system uses anywhere
    // (`test/shad_radius_test.dart`, ADR-0029).
    radius: BorderRadius.circular(DswShape.control),
    // shad's own popover skin already fills from `colorScheme.popover` and
    // draws a hairline from `colorScheme.border`; the only thing off-ramp is
    // the corner, because it rounds an overlay with the same global knob that
    // answers for a field, and an overlay is a `shell` surface.
    popoverTheme: ShadPopoverTheme(
      decoration: ShadDecoration(
        border: ShadBorder.all(
          radius: BorderRadius.circular(DswShape.shell),
          color: c.borderL2,
          width: 1,
        ),
      ),
    ),
    // Rows inside those overlays. The type scale is DSW's, not shad's
    // `textTheme.small` — this bridge deliberately maps no text theme, and a
    // menu that inherited shad's ramp would fork a second typography.
    optionTheme: ShadOptionTheme(
      textStyle: DswType.s14.copyWith(color: c.labelPrimary),
      // shad resolves the selected row's style separately, and falls back to
      // its own `textTheme.muted` — which this bridge deliberately does not
      // map. Saying it here is what keeps one row from forking a second
      // typography the moment it becomes the chosen one.
      selectedTextStyle: DswType.s14.copyWith(color: c.labelPrimary),
      // The tick that says "this one is live" was brand blue before shad drew
      // it, and brand is still the one place `stateBusinessPrimary` marks a
      // selection rather than an error.
      selectedIconColor: c.stateBusinessPrimary,
      // dsh's own hover wash, not `colorScheme.accent`.
      hoveredBackgroundColor: c.interactiveBgHover,
      // A row highlight nested inside a `shell` surface is `inner` decoration.
      radius: BorderRadius.circular(DswShape.inner),
    ),
    selectTheme: ShadSelectTheme(
      placeholderStyle: DswType.s14.copyWith(color: c.labelTertiary),
    ),
    contextMenuTheme: ShadContextMenuTheme(
      textStyle: DswType.s14.copyWith(color: c.labelPrimary),
      trailingTextStyle: DswType.xs13.copyWith(color: c.labelTertiary),
      selectedBackgroundColor: c.interactiveBgHover,
      height: DswShape.rowMenu * textScale,
    ),
  );
}

/// Wraps [child] in a [ShadTheme] unless an ancestor already provides one.
///
/// The app mounts the theme once, in `main`'s `MaterialApp.builder`. A
/// primitive that renders under a bare `MaterialApp` — a widget test, a
/// preview — would otherwise trip shad's `debugCheckHasShadTheme` assert,
/// and making every one of those pump trees mount the theme by hand is churn
/// that adds no guarantee. The fallback is this same bridge's output, so
/// there is exactly one palette either way and a self-contained primitive
/// simply declares its own dependency.
Widget dswEnsureShadTheme(BuildContext context, Widget child) =>
    ShadTheme.maybeOf(context, listen: false) != null
    ? child
    : ShadTheme(
        data: dswShadTheme(
          Theme.of(context).brightness,
          textScale: MediaQuery.textScalerOf(context).scale(1),
        ),
        child: child,
      );

/// The colour half of the bridge, exposed separately so a test can assert
/// the mapping without a widget tree.
///
/// The comments name the dsh role each pairing stands in for, so a future
/// rename of an alias has to be reconciled with this list rather than
/// silently drift.
ShadColorScheme dswShadColorScheme(DswAlias c) => ShadColorScheme(
  // Windows and sheets.
  background: c.bgBase,
  foreground: c.labelPrimary,
  card: c.bgLayer1,
  cardForeground: c.labelPrimary,
  // Every shad overlay — select dropdown, popover, context menu — fills from
  // this slot. It is `bgLayer2` and not the `menu` alias for a measured reason
  // (ADR-0028): in the light palette `menu` and `bgLayer1` are the same colour,
  // so a menu would be separated from the surface it floats over by its shadow
  // alone.
  popover: c.bgLayer2,
  popoverForeground: c.labelPrimary,
  // The strong action: dsh paints its primary buttons with `button-primary-*`
  // and the label is the document's foreground, not a fixed white.
  primary: c.buttonPrimaryFill,
  primaryForeground: c.labelPrimaryForeground,
  // The quiet active surface (`.ghost` pressed/active fill).
  secondary: c.buttonGhostActiveFill,
  secondaryForeground: c.labelPrimary,
  // De-emphasised chrome: sidebar wells and tertiary labels.
  muted: c.sidebarFill,
  mutedForeground: c.labelSecondary,
  // Hover washes on otherwise bare surfaces (floating button hover).
  accent: c.buttonFloatingHover,
  accentForeground: c.labelPrimary,
  // Destructive actions: dsh's error red with the foreground inverted.
  destructive: c.stateErrorPrimary,
  destructiveForeground: c.labelPrimaryForeground,
  // Hairlines and control outlines share dsh's level-2 border and the major
  // input surface.
  border: c.borderL2,
  input: c.inputMajor,
  // Focus rings: brand blue, the only place `brandPrimary` paints a ring.
  ring: c.brandPrimary,
  // Text selection highlight, from the message bubble's own token.
  selection: c.bubbleHighlight,
);
