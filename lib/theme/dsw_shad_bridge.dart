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
    // A field's frame. `ShadInput` reads `inputTheme.decoration`, and the
    // library's default is an empty `ShadDecoration` — which paints nothing —
    // so every shad field has been drawing without the hairline the Material
    // field it replaced had. Rest `borderL2`, focus `brandPrimary`: the same two
    // steps the composer card's three-state stroke answers with, because a field
    // and a card are asked the same question — where is the keyboard (ADR-0017
    // S2b). Radius comes from the knob (`control`), so it is not restated here.
    inputTheme: ShadInputTheme(
      style: DswType.s14.copyWith(color: c.labelPrimary),
      placeholderStyle: DswType.s14.copyWith(color: c.labelTertiary),
      cursorColor: c.stateBusinessPrimary,
      decoration: ShadDecoration(
        border: ShadBorder.all(color: c.borderL2, width: 1),
        focusedBorder: ShadBorder.all(color: c.brandPrimary, width: 1),
        errorBorder: ShadBorder.all(color: c.stateErrorPrimary, width: 1),
        // The second outline. `ShadDecorator` merges the *variant's*
        // `decorationTheme()` before this decoration (`decorator.dart:120`), and
        // that one carries `secondaryFocusedBorder = 2px ring, offset 4`
        // (`default_theme_variant.dart:362`) — so a focused field painted our
        // hairline with the library's ring four pixels outside it, which is the
        // doubled frame in the settings screenshot. A field answers "where is the
        // keyboard" with one stroke, so the ring is said off here rather than at
        // the five call sites that wanted no frame anyway (`dswBareInput`).
        secondaryBorder: ShadBorder.none,
        secondaryFocusedBorder: ShadBorder.none,
        secondaryErrorBorder: ShadBorder.none,
      ),
    ),
    // The on/off (ADR-0036 row 25). Geometry first: this design's pill is
    // 36x20 with a 2px gutter and so a 16px thumb, not shad's 44x24.
    switchTheme: ShadSwitchTheme(
      width: 36,
      height: 20,
      margin: 2,
      checkedTrackColor: c.brandPrimary,
      uncheckedTrackColor: c.bgLayer1,
    ),
    // A section card (ADR-0036 rows 18/23): the fill, the hairline and the
    // corner of every grouped surface, said here rather than per panel. `shell`
    // because a card sits on the page, not inside a control.
    cardTheme: ShadCardTheme(
      backgroundColor: c.bgLayer1,
      border: ShadBorder.all(color: c.borderL2, width: 1),
      radius: BorderRadius.circular(DswShape.shell),
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

/// The frameless field: an input that lives *inside* another surface — the
/// composer card, a search row, an address bar — has no border of its own, and
/// the surface around it is what says where the keyboard is.
///
/// Five call sites used to answer that by hand with an
/// `InputDecoration(border: InputBorder.none)`, which is the same sentence said
/// five ways; and because the bridge now gives a field a frame, a shad field
/// that wants none has to say so. Every side is named, not just the resting
/// one — the focus border resolves separately, and a bare field that lights up
/// a ring on focus has grown a frame the card already draws.
const ShadDecoration dswBareInput = ShadDecoration(
  border: ShadBorder.none,
  focusedBorder: ShadBorder.none,
  errorBorder: ShadBorder.none,
  secondaryBorder: ShadBorder.none,
  secondaryFocusedBorder: ShadBorder.none,
);

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

/// A field's placeholder, on one line and ellipsised.
///
/// shad paints a placeholder *over* the field rather than inside its layout, so
/// a hint that wraps is measured against a one-line box and gets cut mid-glyph —
/// at the amplified text steps a three-word hint is a two-line hint. The hint is
/// the thing that yields, never the text being typed (the same call ADR-0017 S3
/// made about the commit box's own placeholder).
Widget dswInputHint(String text, {TextStyle? style}) =>
    Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);

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
