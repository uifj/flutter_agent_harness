// Layer 2 of the dsh design-token system: the semantic aliases.
//
// A 1:1 port of `--dsw-alias-*` and `--dsw-specific-*` from
// `deepseek-harness/packages/client/ui-theme/src/styles/design-platform.css`
// (lines 156-246 light, 248-338 dark).
//
// This is the ONLY colour surface `ui/` may consume. Layer 1
// (`dsw_static.dart`) is off limits to widgets, and literal colours are
// forbidden outright — the same rule dsh enforces in `docs/web-styling.md`.
// Theme switching is therefore a swap of one `DswAlias` instance.
//
// Field names are the CSS custom-property names minus the `--dsw-alias-` /
// `--dsw-specific-` prefix, lower-camelised, so a token can be grepped in
// either direction. `rgba()` values become `Color.fromRGBO` to keep the alpha
// visible as the fraction the source wrote.

import 'dart:ui';

import 'dsw_static.dart';

/// One resolved theme's worth of semantic colour tokens.
///
/// Reach for these through `Theme.of(context).extension<DswTheme>()!.color`,
/// never by naming [light] or [dark] directly in a widget.
final class DswAlias {
  const DswAlias({
    required this.bgBase,
    required this.bgLayer1,
    required this.bgLayer2,
    required this.bgLayer3,
    required this.bgMask1,
    required this.bgMask2,
    required this.bgMask3,
    required this.bgMaskPhoto,
    required this.bgMaskDrop,
    required this.bgModulePlatform,
    required this.bgMultiSelect,
    required this.bgOverlay,
    required this.bgSkeleton,
    required this.borderInverted,
    required this.borderInverted2,
    required this.borderL1,
    required this.borderL2,
    required this.borderL2DarkmodeThin,
    required this.borderL3,
    required this.borderL4,
    required this.brandPrimary,
    required this.brandPrimaryInvert,
    required this.brandPrimaryNewColor,
    required this.brandText,
    required this.buttonContrastFill,
    required this.buttonElevatedFill,
    required this.buttonFloatingFill,
    required this.buttonFloatingHover,
    required this.buttonGhostActiveBorder,
    required this.buttonGhostActiveFill,
    required this.buttonGhostActiveHover,
    required this.buttonInfoFill,
    required this.buttonInfoHover,
    required this.buttonPrimaryDimmed,
    required this.buttonPrimaryFill,
    required this.buttonPrimaryHover,
    required this.buttonToolBarFill,
    required this.buttonToolBarFillInvisible,
    required this.buttonToolBarHover,
    required this.interactiveBgActive,
    required this.interactiveBgHover,
    required this.interactiveBgHoverAccent,
    required this.interactiveBgHoverDanger,
    required this.interactiveBgHoverSolid,
    required this.labelCaption,
    required this.labelDimmed,
    required this.labelPrimary,
    required this.labelPrimaryBluish,
    required this.labelPrimaryDimmed,
    required this.labelPrimaryForeground,
    required this.labelPrimaryInverted,
    required this.labelSecondary,
    required this.labelTertiary,
    required this.markdownCitation,
    required this.markdownCodeBlock,
    required this.markdownCodeBlockBanner,
    required this.markdownCodeSegmentSelected,
    required this.markdownCodeSegmentUnselected,
    required this.markdownInlineCode,
    required this.markdownPlaceholder,
    required this.markdownTag,
    required this.scrollbarBgL1,
    required this.scrollbarBgL2,
    required this.scrollbarHoverL1,
    required this.scrollbarHoverL2,
    required this.stateBusinessPrimary,
    required this.stateBusinessTertiary,
    required this.stateErrorPrimary,
    required this.stateErrorSecondary,
    required this.stateSuccessPrimary,
    required this.stateSuccessSecondary,
    required this.stateSuccessTertiary,
    required this.stateWarnLabel,
    required this.stateWarnPrimary,
    required this.stateWarnSecondary,
    required this.stateWarnTertiary,
    required this.toastBg,
    required this.tooltipBg,
    required this.bubble,
    required this.bubbleHighlight,
    required this.inputMajor,
    required this.loginInput,
    required this.menu,
    required this.selector,
    required this.sidebarFill,
    required this.sidebarNavItemActive,
    required this.sidebarNavItemActiveAccent,
    required this.sidebarNavItemHover,
    required this.tip,
  });

  // Surfaces. `bgBase` is the window, layers 1-3 stack on top of it; in light
  // they all collapse to white and only dark pulls them apart.
  final Color bgBase;
  final Color bgLayer1;
  final Color bgLayer2;
  final Color bgLayer3;
  final Color bgMask1;
  final Color bgMask2;
  final Color bgMask3;
  final Color bgMaskPhoto;
  final Color bgMaskDrop;
  final Color bgModulePlatform;
  final Color bgMultiSelect;
  final Color bgOverlay;
  final Color bgSkeleton;

  // Hairlines. All translucent, so they compose over whatever surface is
  // underneath rather than being tuned per layer.
  final Color borderInverted;
  final Color borderInverted2;
  final Color borderL1;
  final Color borderL2;
  final Color borderL2DarkmodeThin;
  final Color borderL3;
  final Color borderL4;

  // Brand.
  final Color brandPrimary;
  final Color brandPrimaryInvert;

  /// `--dsw-alias-brand-primary-new-colorprimary-new-color`, de-stuttered. The
  /// source name is a token-pipeline accident; the value is real.
  final Color brandPrimaryNewColor;
  final Color brandText;

  // Buttons.
  final Color buttonContrastFill;
  final Color buttonElevatedFill;
  final Color buttonFloatingFill;
  final Color buttonFloatingHover;
  final Color buttonGhostActiveBorder;
  final Color buttonGhostActiveFill;
  final Color buttonGhostActiveHover;
  final Color buttonInfoFill;
  final Color buttonInfoHover;
  final Color buttonPrimaryDimmed;
  final Color buttonPrimaryFill;
  final Color buttonPrimaryHover;
  final Color buttonToolBarFill;
  final Color buttonToolBarFillInvisible;
  final Color buttonToolBarHover;

  // Interaction washes, painted over a surface rather than replacing it.
  final Color interactiveBgActive;
  final Color interactiveBgHover;
  final Color interactiveBgHoverAccent;
  final Color interactiveBgHoverDanger;
  final Color interactiveBgHoverSolid;

  // Text.
  final Color labelCaption;
  final Color labelDimmed;
  final Color labelPrimary;
  final Color labelPrimaryBluish;
  final Color labelPrimaryDimmed;
  final Color labelPrimaryForeground;
  final Color labelPrimaryInverted;
  final Color labelSecondary;
  final Color labelTertiary;

  // Markdown rendering.
  final Color markdownCitation;
  final Color markdownCodeBlock;
  final Color markdownCodeBlockBanner;
  final Color markdownCodeSegmentSelected;
  final Color markdownCodeSegmentUnselected;
  final Color markdownInlineCode;
  final Color markdownPlaceholder;
  final Color markdownTag;

  // Scrollbars.
  final Color scrollbarBgL1;
  final Color scrollbarBgL2;
  final Color scrollbarHoverL1;
  final Color scrollbarHoverL2;

  // Status. `primary` is the strong fill, `secondary` the softer one,
  // `tertiary` the tinted background.
  final Color stateBusinessPrimary;
  final Color stateBusinessTertiary;
  final Color stateErrorPrimary;
  final Color stateErrorSecondary;
  final Color stateSuccessPrimary;
  final Color stateSuccessSecondary;
  final Color stateSuccessTertiary;
  final Color stateWarnLabel;
  final Color stateWarnPrimary;
  final Color stateWarnSecondary;
  final Color stateWarnTertiary;

  final Color toastBg;
  final Color tooltipBg;

  // The `--dsw-specific-*` group: one named place in the product, not a
  // reusable role. `bubble` is the user message bubble.
  final Color bubble;
  final Color bubbleHighlight;
  final Color inputMajor;
  final Color loginInput;
  final Color menu;
  final Color selector;
  final Color sidebarFill;
  final Color sidebarNavItemActive;
  final Color sidebarNavItemActiveAccent;
  final Color sidebarNavItemHover;
  final Color tip;

  /// `design-platform.css:156-246`.
  static const light = DswAlias(
    bgBase: DswStatic.neutralBluish00,
    bgLayer1: DswStatic.neutralBluish00,
    bgLayer2: DswStatic.neutralBluish00,
    bgLayer3: DswStatic.neutralBluish00,
    bgMask1: Color.fromRGBO(0, 0, 0, 0.24),
    bgMask2: Color.fromRGBO(0, 0, 0, 0.12),
    bgMask3: Color.fromRGBO(0, 0, 0, 0.48),
    bgMaskPhoto: Color.fromRGBO(0, 0, 0, 0.88),
    bgMaskDrop: Color.fromRGBO(255, 255, 255, 0.7),
    bgModulePlatform: DswStatic.neutralBluish60Light,
    bgMultiSelect: DswStatic.neutralBluish60Light,
    bgOverlay: DswStatic.neutralBluish150,
    bgSkeleton: Color.fromRGBO(0, 0, 0, 0.04),
    borderInverted: Color.fromRGBO(0, 0, 0, 0),
    borderInverted2: Color.fromRGBO(0, 0, 0, 0),
    borderL1: Color.fromRGBO(0, 0, 0, 0.04),
    borderL2: Color.fromRGBO(0, 0, 0, 0.1),
    borderL2DarkmodeThin: Color.fromRGBO(0, 0, 0, 0.1),
    borderL3: Color.fromRGBO(0, 0, 0, 0.12),
    borderL4: Color.fromRGBO(0, 0, 0, 0.16),
    brandPrimary: DswStatic.neutralBluish1000,
    brandPrimaryInvert: DswStatic.neutralBluish1000,
    brandPrimaryNewColor: Color.fromARGB(255, 65, 118, 230),
    brandText: DswStatic.neutralBluish1000,
    buttonContrastFill: DswStatic.neutralBluish700,
    buttonElevatedFill: DswStatic.neutralBluish00,
    buttonFloatingFill: DswStatic.neutralBluish00,
    buttonFloatingHover: DswStatic.neutralBluish75,
    buttonGhostActiveBorder: DswStatic.neutralBluish500,
    buttonGhostActiveFill: DswStatic.neutralBluish100,
    buttonGhostActiveHover: DswStatic.neutralBluish150,
    buttonInfoFill: DswStatic.deepseek500,
    buttonInfoHover: DswStatic.deepseek400,
    buttonPrimaryDimmed: DswStatic.neutralBluish100,
    // Source aliases this to `--dsw-alias-brand-primary`.
    buttonPrimaryFill: DswStatic.neutralBluish1000,
    buttonPrimaryHover: DswStatic.neutralBluish750,
    buttonToolBarFill: Color.fromRGBO(84, 85, 87, 0.5),
    buttonToolBarFillInvisible: Color.fromRGBO(31, 31, 31, 0.36),
    buttonToolBarHover: Color.fromRGBO(84, 85, 87, 0.6),
    interactiveBgActive: Color.fromRGBO(38, 49, 72, 0.1),
    interactiveBgHover: Color.fromRGBO(38, 49, 72, 0.06),
    interactiveBgHoverAccent: Color.fromRGBO(38, 49, 72, 0.14),
    interactiveBgHoverDanger: Color.fromRGBO(236, 19, 19, 0.05),
    interactiveBgHoverSolid: DswStatic.neutralBluish75,
    labelCaption: DswStatic.neutralBluish400,
    labelDimmed: DswStatic.neutralBluish200,
    labelPrimary: DswStatic.neutralBluish1000,
    labelPrimaryBluish: DswStatic.blue900,
    labelPrimaryDimmed: DswStatic.neutralBluish950,
    labelPrimaryForeground: DswStatic.neutralBluish00,
    labelPrimaryInverted: DswStatic.neutralBluish00,
    labelSecondary: DswStatic.neutralBluish700,
    labelTertiary: DswStatic.neutralBluish600,
    markdownCitation: DswStatic.neutralBluish100,
    markdownCodeBlock: DswStatic.neutralBluish50,
    markdownCodeBlockBanner: DswStatic.neutralBluish50,
    markdownCodeSegmentSelected: DswStatic.neutralBluish00,
    markdownCodeSegmentUnselected: DswStatic.neutralBluish75,
    markdownInlineCode: DswStatic.neutralBluish100,
    markdownPlaceholder: DswStatic.neutralBluish60Light,
    markdownTag: DswStatic.neutralBluish75,
    scrollbarBgL1: DswStatic.neutral200,
    scrollbarBgL2: DswStatic.neutral200,
    scrollbarHoverL1: DswStatic.neutral300,
    scrollbarHoverL2: DswStatic.neutral300,
    stateBusinessPrimary: DswStatic.deepseek500,
    stateBusinessTertiary: DswStatic.deepseek100,
    stateErrorPrimary: DswStatic.red600,
    stateErrorSecondary: DswStatic.red400,
    stateSuccessPrimary: DswStatic.green500,
    stateSuccessSecondary: DswStatic.green400,
    stateSuccessTertiary: DswStatic.green100,
    stateWarnLabel: DswStatic.amber600,
    stateWarnPrimary: DswStatic.amber500,
    stateWarnSecondary: DswStatic.amber400,
    stateWarnTertiary: DswStatic.amber100,
    toastBg: DswStatic.neutralBluish800,
    tooltipBg: DswStatic.neutralBluish850,
    bubble: DswStatic.deepseek50,
    bubbleHighlight: DswStatic.deepseek200,
    inputMajor: DswStatic.neutralBluish00,
    loginInput: DswStatic.neutralBluish50,
    // Source aliases this to `--dsw-alias-bg-layer-3`.
    menu: DswStatic.neutralBluish00,
    selector: DswStatic.neutralBluish60Light,
    sidebarFill: DswStatic.neutralBluish50,
    sidebarNavItemActive: DswStatic.neutralBluish100,
    sidebarNavItemActiveAccent: DswStatic.deepseek100,
    sidebarNavItemHover: DswStatic.neutralBluish75,
    tip: DswStatic.neutralBluish60Light,
  );

  /// `design-platform.css:248-338`.
  static const dark = DswAlias(
    bgBase: DswStatic.neutralBluish950,
    bgLayer1: DswStatic.neutralBluish875,
    bgLayer2: DswStatic.neutralBluish850,
    bgLayer3: DswStatic.neutralBluish800,
    bgMask1: Color.fromRGBO(0, 0, 0, 0.5),
    bgMask2: Color.fromRGBO(0, 0, 0, 0.2),
    bgMask3: Color.fromRGBO(0, 0, 0, 0.48),
    bgMaskPhoto: Color.fromRGBO(0, 0, 0, 0.88),
    bgMaskDrop: Color.fromRGBO(39, 39, 48, 0.7),
    bgModulePlatform: DswStatic.neutralBluish800,
    bgMultiSelect: DswStatic.neutral850,
    bgOverlay: DswStatic.neutralBluish700,
    bgSkeleton: Color.fromRGBO(255, 255, 255, 0.08),
    borderInverted: Color.fromRGBO(255, 255, 255, 0.06),
    borderInverted2: Color.fromRGBO(255, 255, 255, 0.08),
    borderL1: Color.fromRGBO(255, 255, 255, 0.06),
    borderL2: Color.fromRGBO(255, 255, 255, 0.12),
    borderL2DarkmodeThin: Color.fromRGBO(255, 255, 255, 0.06),
    borderL3: Color.fromRGBO(255, 255, 255, 0.16),
    borderL4: Color.fromRGBO(255, 255, 255, 0.2),
    brandPrimary: DswStatic.neutralBluish50,
    brandPrimaryInvert: DswStatic.neutralBluish50,
    brandPrimaryNewColor: DswStatic.deepseek450,
    brandText: DswStatic.neutralBluish50,
    buttonContrastFill: DswStatic.neutralBluish50,
    buttonElevatedFill: DswStatic.neutralBluish750,
    buttonFloatingFill: DswStatic.neutralBluish850,
    buttonFloatingHover: DswStatic.neutralBluish800,
    buttonGhostActiveBorder: DswStatic.neutralBluish600,
    buttonGhostActiveFill: DswStatic.neutralBluish750,
    buttonGhostActiveHover: DswStatic.neutralBluish700,
    buttonInfoFill: DswStatic.deepseek400,
    buttonInfoHover: DswStatic.deepseek500,
    buttonPrimaryDimmed: DswStatic.neutralBluish750,
    // Source aliases this to `--dsw-alias-brand-primary`.
    buttonPrimaryFill: DswStatic.neutralBluish50,
    buttonPrimaryHover: DswStatic.neutralBluish100,
    buttonToolBarFill: Color.fromRGBO(84, 85, 87, 0.5),
    buttonToolBarFillInvisible: Color.fromRGBO(31, 31, 31, 0.36),
    buttonToolBarHover: Color.fromRGBO(84, 85, 87, 0.6),
    interactiveBgActive: Color.fromRGBO(255, 255, 255, 0.14),
    interactiveBgHover: Color.fromRGBO(255, 255, 255, 0.08),
    interactiveBgHoverAccent: Color.fromRGBO(255, 255, 255, 0.24),
    interactiveBgHoverDanger: Color.fromRGBO(242, 90, 90, 0.15),
    interactiveBgHoverSolid: DswStatic.neutralBluish800,
    labelCaption: DswStatic.neutralBluish600,
    labelDimmed: DswStatic.neutralBluish750,
    labelPrimary: DswStatic.neutralBluish50,
    labelPrimaryBluish: DswStatic.neutralBluish50,
    labelPrimaryDimmed: DswStatic.neutralBluish100,
    labelPrimaryForeground: DswStatic.neutralBluish1000,
    labelPrimaryInverted: DswStatic.neutralBluish800,
    labelSecondary: DswStatic.neutralBluish300,
    labelTertiary: DswStatic.neutralBluish400,
    markdownCitation: DswStatic.neutralBluish800,
    markdownCodeBlock: DswStatic.neutralBluish900,
    markdownCodeBlockBanner: DswStatic.neutralBluish850,
    markdownCodeSegmentSelected: DswStatic.neutralBluish800,
    markdownCodeSegmentUnselected: DswStatic.neutralBluish900,
    markdownInlineCode: DswStatic.neutralBluish850,
    markdownPlaceholder: DswStatic.neutralBluish850,
    markdownTag: DswStatic.neutralBluish850,
    scrollbarBgL1: DswStatic.neutral700,
    scrollbarBgL2: DswStatic.neutral600,
    scrollbarHoverL1: DswStatic.neutral600,
    scrollbarHoverL2: DswStatic.neutral550,
    stateBusinessPrimary: DswStatic.deepseek400,
    stateBusinessTertiary: DswStatic.deepseek800,
    stateErrorPrimary: DswStatic.red400,
    stateErrorSecondary: DswStatic.red400,
    stateSuccessPrimary: DswStatic.green500,
    stateSuccessSecondary: DswStatic.green400,
    stateSuccessTertiary: DswStatic.green900,
    stateWarnLabel: DswStatic.amber600,
    stateWarnPrimary: DswStatic.amber500,
    stateWarnSecondary: DswStatic.amber400,
    stateWarnTertiary: DswStatic.amber900,
    toastBg: DswStatic.neutralBluish750,
    tooltipBg: DswStatic.neutralBluish750,
    bubble: DswStatic.neutralBluish850,
    bubbleHighlight: DswStatic.neutralBluish750,
    inputMajor: DswStatic.neutralBluish850,
    loginInput: DswStatic.neutralBluish900,
    // Source aliases this to `--dsw-alias-bg-layer-3`.
    menu: DswStatic.neutralBluish800,
    selector: DswStatic.neutralBluish800,
    sidebarFill: DswStatic.neutralBluish900,
    sidebarNavItemActive: DswStatic.neutralBluish750,
    sidebarNavItemActiveAccent: DswStatic.neutralBluish800,
    sidebarNavItemHover: DswStatic.neutralBluish850,
    tip: DswStatic.neutralBluish800,
  );
}
