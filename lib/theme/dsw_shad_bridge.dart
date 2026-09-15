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
//   * No radius/geometry. The ported shapes (capsule r18/r14, block radii)
//     are call-site facts, not palette facts; shad's default (6) is left
//     alone so a new component gets the library's own standard instead of a
//     guessed port.

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'dsw_alias.dart';

/// The shad theme for one brightness, coloured entirely by [DswAlias].
///
/// Brightness must match the `DswAlias` instance handed in — the palette is
/// half of a pair and a light alias under a dark flag would theme every
/// component backwards.
ShadThemeData dswShadTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final c = isDark ? DswAlias.dark : DswAlias.light;
  return ShadThemeData(
    brightness: brightness,
    colorScheme: dswShadColorScheme(c),
  );
}

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
  // Menus and popovers ride dsh's own menu surface, not a generic layer.
  popover: c.menu,
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
