import 'dart:ui';
import 'colors.dart';

class SemanticColorScheme {
  // text & icon
  final Color textColorPrimary;
  final Color textColorSecondary;
  final Color textColorTertiary;
  final Color textColorDisable;
  final Color textColorButton;
  final Color textColorButtonDisabled;
  final Color textColorLink;
  final Color textColorLinkHover;
  final Color textColorLinkActive;
  final Color textColorLinkDisabled;
  final Color textColorAntiPrimary;
  final Color textColorAntiSecondary;
  final Color textColorWarning;
  final Color textColorSuccess;
  final Color textColorError;

  // background
  final Color bgColorTopBar;
  final Color bgColorOperate;
  final Color bgColorDialog;
  final Color bgColorDialogModule;
  final Color bgColorEntryCard;
  final Color bgColorFunction;
  final Color bgColorBottomBar;
  final Color bgColorInput;
  final Color bgColorBubbleReciprocal;
  final Color bgColorBubbleOwn;
  final Color bgColorDefault;
  final Color bgColorTagMask;
  final Color bgColorElementMask;
  final Color bgColorMask;
  final Color bgColorMaskDisappeared;
  final Color bgColorMaskBegin;
  final Color bgColorAvatar;

  // border
  final Color strokeColorPrimary;
  final Color strokeColorSecondary;
  final Color strokeColorModule;

  // shadow
  final Color shadowColor;

  // status
  final Color listColorDefault;
  final Color listColorHover;
  final Color listColorFocused;

  // button
  final Color buttonColorPrimaryDefault;
  final Color buttonColorPrimaryHover;
  final Color buttonColorPrimaryActive;
  final Color buttonColorPrimaryDisabled;
  final Color buttonColorSecondaryDefault;
  final Color buttonColorSecondaryHover;
  final Color buttonColorSecondaryActive;
  final Color buttonColorSecondaryDisabled;
  final Color buttonColorAccept;
  final Color buttonColorHangupDefault;
  final Color buttonColorHangupDisabled;
  final Color buttonColorHangupHover;
  final Color buttonColorHangupActive;
  final Color buttonColorOn;
  final Color buttonColorOff;

  // dropdown
  final Color dropdownColorDefault;
  final Color dropdownColorHover;
  final Color dropdownColorActive;

  // scrollbar
  final Color scrollbarColorDefault;
  final Color scrollbarColorHover;

  // floating
  final Color floatingColorDefault;
  final Color floatingColorOperate;

  // checkbox
  final Color checkboxColorSelected;

  // toast
  final Color toastColorWarning;
  final Color toastColorSuccess;
  final Color toastColorError;
  final Color toastColorDefault;

  // tag
  final Color tagColorLevel1;
  final Color tagColorLevel2;
  final Color tagColorLevel3;
  final Color tagColorLevel4;

  // switch
  final Color switchColorOff;
  final Color switchColorOn;
  final Color switchColorButton;

  // slider
  final Color sliderColorFilled;
  final Color sliderColorEmpty;
  final Color sliderColorButton;

  // tab
  final Color tabColorSelected;
  final Color tabColorUnselected;
  final Color tabColorOption;

  // clear
  final Color clearColor;

  const SemanticColorScheme({
    // text & icon
    this.textColorPrimary = BaseColors.black2,
    this.textColorSecondary = BaseColors.black4,
    this.textColorTertiary = BaseColors.black5,
    this.textColorDisable = BaseColors.black6,
    this.textColorButton = BaseColors.white1,
    this.textColorButtonDisabled = BaseColors.white1,
    this.textColorLink = BaseColors.themeLight6,
    this.textColorLinkHover = BaseColors.themeLight5,
    this.textColorLinkActive = BaseColors.themeLight7,
    this.textColorLinkDisabled = BaseColors.themeLight2,
    this.textColorAntiPrimary = BaseColors.black2,
    this.textColorAntiSecondary = BaseColors.black4,
    this.textColorWarning = BaseColors.orangeLight6,
    this.textColorSuccess = BaseColors.greenLight6,
    this.textColorError = BaseColors.redLight6,
    // background
    this.bgColorTopBar = BaseColors.grayLight1,
    this.bgColorOperate = BaseColors.white1,
    this.bgColorDialog = BaseColors.white1,
    this.bgColorDialogModule = BaseColors.grayLight2,
    this.bgColorEntryCard = BaseColors.grayLight2,
    this.bgColorFunction = BaseColors.grayLight2,
    this.bgColorBottomBar = BaseColors.white1,
    this.bgColorInput = BaseColors.grayLight2,
    this.bgColorBubbleReciprocal = BaseColors.grayLight2,
    this.bgColorBubbleOwn = BaseColors.themeLight2,
    this.bgColorDefault = BaseColors.grayLight2,
    this.bgColorTagMask = BaseColors.white4,
    this.bgColorElementMask = BaseColors.black6,
    this.bgColorMask = BaseColors.black4,
    this.bgColorMaskDisappeared = BaseColors.white7,
    this.bgColorMaskBegin = BaseColors.white1,
    this.bgColorAvatar = BaseColors.themeLight2,

    // border
    this.strokeColorPrimary = BaseColors.grayLight3,
    this.strokeColorSecondary = BaseColors.grayLight2,
    this.strokeColorModule = BaseColors.grayLight3,

    // shadow
    this.shadowColor = BaseColors.black8,

    // status
    this.listColorDefault = BaseColors.white1,
    this.listColorHover = BaseColors.grayLight1,
    this.listColorFocused = BaseColors.themeLight1,

    // button
    this.buttonColorPrimaryDefault = BaseColors.themeLight6,
    this.buttonColorPrimaryHover = BaseColors.themeLight5,
    this.buttonColorPrimaryActive = BaseColors.themeLight7,
    this.buttonColorPrimaryDisabled = BaseColors.themeLight2,
    this.buttonColorSecondaryDefault = BaseColors.grayLight2,
    this.buttonColorSecondaryHover = BaseColors.grayLight1,
    this.buttonColorSecondaryActive = BaseColors.grayLight3,
    this.buttonColorSecondaryDisabled = BaseColors.grayLight1,
    this.buttonColorAccept = BaseColors.greenLight6,
    this.buttonColorHangupDefault = BaseColors.redLight6,
    this.buttonColorHangupDisabled = BaseColors.redLight2,
    this.buttonColorHangupHover = BaseColors.redLight5,
    this.buttonColorHangupActive = BaseColors.redLight7,
    this.buttonColorOn = BaseColors.white1,
    this.buttonColorOff = BaseColors.black5,

    // dropdown
    this.dropdownColorDefault = BaseColors.white1,
    this.dropdownColorHover = BaseColors.grayLight1,
    this.dropdownColorActive = BaseColors.themeLight1,

    // scrollbar
    this.scrollbarColorDefault = BaseColors.black7,
    this.scrollbarColorHover = BaseColors.black6,

    // floating
    this.floatingColorDefault = BaseColors.white1,
    this.floatingColorOperate = BaseColors.grayLight2,

    // checkbox
    this.checkboxColorSelected = BaseColors.themeLight6,

    // toast
    this.toastColorWarning = BaseColors.orangeLight1,
    this.toastColorSuccess = BaseColors.greenLight1,
    this.toastColorError = BaseColors.redLight1,
    this.toastColorDefault = BaseColors.themeLight1,

    // tag
    this.tagColorLevel1 = BaseColors.accentTurquoiseLight,
    this.tagColorLevel2 = BaseColors.themeLight5,
    this.tagColorLevel3 = BaseColors.accentPurpleLight,
    this.tagColorLevel4 = BaseColors.accentMagentaLight,

    // switch
    this.switchColorOff = BaseColors.grayLight4,
    this.switchColorOn = BaseColors.themeLight6,
    this.switchColorButton = BaseColors.white1,

    // slider
    this.sliderColorFilled = BaseColors.themeLight6,
    this.sliderColorEmpty = BaseColors.grayLight3,
    this.sliderColorButton = BaseColors.white1,

    // tab
    this.tabColorSelected = BaseColors.themeLight2,
    this.tabColorUnselected = BaseColors.grayLight2,
    this.tabColorOption = BaseColors.grayLight3,

    this.clearColor = BaseColors.transparent,
  });
}

const LightSemanticScheme = SemanticColorScheme();

const DarkSemanticScheme = SemanticColorScheme(
  // text & icon
  textColorPrimary: BaseColors.white2,
  textColorSecondary: BaseColors.white4,
  textColorTertiary: BaseColors.white6,
  textColorDisable: BaseColors.white7,
  textColorButton: BaseColors.white1,
  textColorButtonDisabled: BaseColors.white5,
  textColorLink: BaseColors.themeDark6,
  textColorLinkHover: BaseColors.themeDark5,
  textColorLinkActive: BaseColors.themeDark7,
  textColorLinkDisabled: BaseColors.themeDark2,
  textColorAntiPrimary: BaseColors.black2,
  textColorAntiSecondary: BaseColors.black4,
  textColorWarning: BaseColors.orangeDark6,
  textColorSuccess: BaseColors.greenDark6,
  textColorError: BaseColors.redDark6,

  // background
  bgColorTopBar: BaseColors.grayDark1,
  bgColorOperate: BaseColors.grayDark2,
  bgColorDialog: BaseColors.grayDark2,
  bgColorDialogModule: BaseColors.grayDark3,
  bgColorEntryCard: BaseColors.grayDark3,
  bgColorFunction: BaseColors.grayDark4,
  bgColorBottomBar: BaseColors.grayDark3,
  bgColorInput: BaseColors.grayDark3,
  bgColorBubbleReciprocal: BaseColors.grayDark3,
  bgColorBubbleOwn: BaseColors.themeDark7,
  bgColorDefault: BaseColors.grayDark1,
  bgColorTagMask: BaseColors.black4,
  bgColorElementMask: BaseColors.black6,
  bgColorMask: BaseColors.black4,
  bgColorMaskDisappeared: BaseColors.black8,
  bgColorMaskBegin: BaseColors.black2,
  bgColorAvatar: BaseColors.themeDark2,

  // border
  strokeColorPrimary: BaseColors.grayDark4,
  strokeColorSecondary: BaseColors.grayDark3,
  strokeColorModule: BaseColors.grayDark5,

  // shadow
  shadowColor: BaseColors.black8,

  // status
  listColorDefault: BaseColors.grayDark2,
  listColorHover: BaseColors.grayDark3,
  listColorFocused: BaseColors.themeDark2,

  // button
  buttonColorPrimaryDefault: BaseColors.themeDark6,
  buttonColorPrimaryHover: BaseColors.themeDark5,
  buttonColorPrimaryActive: BaseColors.themeDark7,
  buttonColorPrimaryDisabled: BaseColors.themeDark2,
  buttonColorSecondaryDefault: BaseColors.grayDark4,
  buttonColorSecondaryHover: BaseColors.grayDark3,
  buttonColorSecondaryActive: BaseColors.grayDark5,
  buttonColorSecondaryDisabled: BaseColors.grayDark3,
  buttonColorAccept: BaseColors.greenDark6,
  buttonColorHangupDefault: BaseColors.redDark6,
  buttonColorHangupDisabled: BaseColors.redDark2,
  buttonColorHangupHover: BaseColors.redDark5,
  buttonColorHangupActive: BaseColors.redDark7,
  buttonColorOn: BaseColors.white1,
  buttonColorOff: BaseColors.black5,

  // dropdown
  dropdownColorDefault: BaseColors.grayDark3,
  dropdownColorHover: BaseColors.grayDark4,
  dropdownColorActive: BaseColors.grayDark2,

  // scrollbar
  scrollbarColorDefault: BaseColors.white7,
  scrollbarColorHover: BaseColors.white6,

  // floating
  floatingColorDefault: BaseColors.grayDark3,
  floatingColorOperate: BaseColors.grayDark4,

  // checkbox
  checkboxColorSelected: BaseColors.themeDark5,

  // toast
  toastColorWarning: BaseColors.orangeDark2,
  toastColorSuccess: BaseColors.greenDark2,
  toastColorError: BaseColors.redDark2,
  toastColorDefault: BaseColors.themeDark2,

  // tag
  tagColorLevel1: BaseColors.accentTurquoiseDark,
  tagColorLevel2: BaseColors.themeDark5,
  tagColorLevel3: BaseColors.accentPurpleDark,
  tagColorLevel4: BaseColors.accentMagentaDark,

  // switch
  switchColorOff: BaseColors.grayDark4,
  switchColorOn: BaseColors.themeDark5,
  switchColorButton: BaseColors.white1,

  // slider
  sliderColorFilled: BaseColors.themeDark5,
  sliderColorEmpty: BaseColors.grayDark5,
  sliderColorButton: BaseColors.white1,

  // tab
  tabColorSelected: BaseColors.grayDark5,
  tabColorUnselected: BaseColors.grayDark4,
  tabColorOption: BaseColors.grayDark4,
);
