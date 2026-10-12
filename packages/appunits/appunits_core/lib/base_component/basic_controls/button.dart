import 'package:flutter/material.dart' hide IconButton, OutlinedButton, FilledButton;
import 'package:flutter/material.dart' as material show IconButton, OutlinedButton, FilledButton;

import '../theme/color_scheme.dart';
import '../theme/font.dart';
import '../theme/theme_state.dart';

enum ButtonType {
  filled,
  outlined,
  noBorder,
}

enum ButtonColorType {
  primary,
  secondary,
  danger,
}

enum ButtonContentType {
  textOnly,
  iconOnly,
  iconWithText,
}

enum ButtonIconPosition {
  start,
  end,
}

enum ButtonSize {
  xs(24, 8, 48, 14),
  s(32, 12, 64, 16),
  m(40, 16, 80, 20),
  l(48, 20, 96, 20);

  const ButtonSize(this.height, this.horizontalPadding, this.minWidth, this.iconSize);

  final double height;
  final double horizontalPadding;
  final double minWidth;
  final double iconSize;
}

sealed class ButtonContent {
  final ButtonContentType buttonContentType;

  const ButtonContent(this.buttonContentType);
}

class TextOnlyContent extends ButtonContent {
  final String text;

  const TextOnlyContent(this.text) : super(ButtonContentType.textOnly);
}

class IconOnlyContent extends ButtonContent {
  final Widget icon;

  const IconOnlyContent(this.icon) : super(ButtonContentType.iconOnly);
}

class IconWithTextContent extends ButtonContent {
  final String text;
  final Widget icon;
  final ButtonIconPosition iconPosition;

  const IconWithTextContent({
    required this.text,
    required this.icon,
    this.iconPosition = ButtonIconPosition.start,
  }) : super(ButtonContentType.iconWithText);
}

class ButtonColors {
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final Color disabledBackgroundColor;
  final Color disabledTextColor;
  final Color disabledBorderColor;

  const ButtonColors({
    required this.backgroundColor,
    required this.textColor,
    required this.borderColor,
    required this.disabledBackgroundColor,
    required this.disabledTextColor,
    required this.disabledBorderColor,
  });
}

TextStyle _fontForButtonSize(ButtonSize size) {
  switch (size) {
    case ButtonSize.xs:
      return FontScheme.caption3Medium;
    case ButtonSize.s:
      return FontScheme.caption2Medium;
    case ButtonSize.m:
    case ButtonSize.l:
      return FontScheme.caption1Medium;
  }
}

ButtonColors _getButtonColors(ButtonType type, ButtonColorType colorType, SemanticColorScheme colors) {
  switch (type) {
    case ButtonType.filled:
      return _getFilledButtonColors(colorType, colors);
    case ButtonType.outlined:
      return _getOutlinedButtonColors(colorType, colors);
    case ButtonType.noBorder:
      return _getNoBorderButtonColors(colorType, colors);
  }
}

ButtonColors _getFilledButtonColors(ButtonColorType colorType, SemanticColorScheme colors) {
  switch (colorType) {
    case ButtonColorType.primary:
      return ButtonColors(
        backgroundColor: colors.buttonColorPrimaryDefault,
        textColor: colors.textColorButton,
        borderColor: Colors.transparent,
        disabledBackgroundColor: colors.buttonColorPrimaryDisabled,
        disabledTextColor: colors.textColorButtonDisabled,
        disabledBorderColor: Colors.transparent,
      );
    case ButtonColorType.secondary:
      return ButtonColors(
        backgroundColor: colors.buttonColorSecondaryDefault,
        textColor: colors.textColorPrimary,
        borderColor: Colors.transparent,
        disabledBackgroundColor: colors.buttonColorSecondaryDisabled,
        disabledTextColor: colors.textColorDisable,
        disabledBorderColor: Colors.transparent,
      );
    case ButtonColorType.danger:
      return ButtonColors(
        backgroundColor: colors.buttonColorHangupDefault,
        textColor: colors.textColorButton,
        borderColor: Colors.transparent,
        disabledBackgroundColor: colors.buttonColorHangupDisabled,
        disabledTextColor: colors.textColorButtonDisabled,
        disabledBorderColor: Colors.transparent,
      );
  }
}

ButtonColors _getOutlinedButtonColors(ButtonColorType colorType, SemanticColorScheme colors) {
  switch (colorType) {
    case ButtonColorType.primary:
      return ButtonColors(
        backgroundColor: Colors.transparent,
        textColor: colors.buttonColorPrimaryDefault,
        borderColor: colors.buttonColorPrimaryDefault,
        disabledBackgroundColor: Colors.transparent,
        disabledTextColor: colors.buttonColorPrimaryDisabled,
        disabledBorderColor: colors.buttonColorPrimaryDisabled,
      );
    case ButtonColorType.secondary:
      return ButtonColors(
        backgroundColor: Colors.transparent,
        textColor: colors.textColorPrimary,
        borderColor: colors.strokeColorPrimary,
        disabledBackgroundColor: Colors.transparent,
        disabledTextColor: colors.textColorDisable,
        disabledBorderColor: colors.strokeColorSecondary,
      );
    case ButtonColorType.danger:
      return ButtonColors(
        backgroundColor: Colors.transparent,
        textColor: colors.buttonColorHangupDefault,
        borderColor: colors.buttonColorHangupDefault,
        disabledBackgroundColor: Colors.transparent,
        disabledTextColor: colors.buttonColorHangupDisabled,
        disabledBorderColor: colors.buttonColorHangupDisabled,
      );
  }
}

ButtonColors _getNoBorderButtonColors(ButtonColorType colorType, SemanticColorScheme colors) {
  switch (colorType) {
    case ButtonColorType.primary:
      return ButtonColors(
        backgroundColor: Colors.transparent,
        textColor: colors.buttonColorPrimaryDefault,
        borderColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        disabledTextColor: colors.buttonColorPrimaryDisabled,
        disabledBorderColor: Colors.transparent,
      );
    case ButtonColorType.secondary:
      return ButtonColors(
        backgroundColor: Colors.transparent,
        textColor: colors.textColorPrimary,
        borderColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        disabledTextColor: colors.textColorDisable,
        disabledBorderColor: Colors.transparent,
      );
    case ButtonColorType.danger:
      return ButtonColors(
        backgroundColor: Colors.transparent,
        textColor: colors.buttonColorHangupDefault,
        borderColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        disabledTextColor: colors.buttonColorHangupDisabled,
        disabledBorderColor: Colors.transparent,
      );
  }
}

Color _getPressedBackgroundColor(ButtonType type, ButtonColorType colorType, SemanticColorScheme colors) {
  switch (type) {
    case ButtonType.filled:
      switch (colorType) {
        case ButtonColorType.primary:
          return colors.buttonColorPrimaryActive;
        case ButtonColorType.secondary:
          return colors.buttonColorSecondaryActive;
        case ButtonColorType.danger:
          return colors.buttonColorHangupActive;
      }
    case ButtonType.outlined:
    case ButtonType.noBorder:
      return Colors.transparent;
  }
}

Color _getHoverBackgroundColor(ButtonType type, ButtonColorType colorType, SemanticColorScheme colors) {
  switch (type) {
    case ButtonType.filled:
      switch (colorType) {
        case ButtonColorType.primary:
          return colors.buttonColorPrimaryHover;
        case ButtonColorType.secondary:
          return colors.buttonColorSecondaryHover;
        case ButtonColorType.danger:
          return colors.buttonColorHangupHover;
      }
    case ButtonType.outlined:
    case ButtonType.noBorder:
      return Colors.transparent;
  }
}

Color _getPressedTextColor(ButtonType type, ButtonColorType colorType, SemanticColorScheme colors) {
  switch (type) {
    case ButtonType.filled:
      return colors.textColorButton;
    case ButtonType.outlined:
    case ButtonType.noBorder:
      switch (colorType) {
        case ButtonColorType.primary:
          return colors.buttonColorPrimaryActive;
        case ButtonColorType.secondary:
          return colors.textColorTertiary;
        case ButtonColorType.danger:
          return colors.buttonColorHangupActive;
      }
  }
}

Color _getHoverTextColor(ButtonType type, ButtonColorType colorType, SemanticColorScheme colors) {
  switch (type) {
    case ButtonType.filled:
      return colors.textColorButton;
    case ButtonType.outlined:
    case ButtonType.noBorder:
      switch (colorType) {
        case ButtonColorType.primary:
          return colors.buttonColorPrimaryHover;
        case ButtonColorType.secondary:
          return colors.textColorSecondary;
        case ButtonColorType.danger:
          return colors.buttonColorHangupHover;
      }
  }
}

Color _getPressedBorderColor(ButtonType type, ButtonColorType colorType, SemanticColorScheme colors) {
  switch (type) {
    case ButtonType.filled:
    case ButtonType.noBorder:
      return Colors.transparent;
    case ButtonType.outlined:
      switch (colorType) {
        case ButtonColorType.primary:
          return colors.buttonColorPrimaryActive;
        case ButtonColorType.secondary:
          return colors.strokeColorModule;
        case ButtonColorType.danger:
          return colors.buttonColorHangupActive;
      }
  }
}

Color _getHoverBorderColor(ButtonType type, ButtonColorType colorType, SemanticColorScheme colors) {
  switch (type) {
    case ButtonType.filled:
    case ButtonType.noBorder:
      return Colors.transparent;
    case ButtonType.outlined:
      switch (colorType) {
        case ButtonColorType.primary:
          return colors.buttonColorPrimaryHover;
        case ButtonColorType.secondary:
          return colors.strokeColorSecondary;
        case ButtonColorType.danger:
          return colors.buttonColorHangupHover;
      }
  }
}

class _AtomicxButton extends StatelessWidget {
  final ButtonType type;
  final ButtonContent content;
  final ButtonSize size;
  final VoidCallback? onClick;
  final bool enabled;
  final ButtonColorType colorType;

  const _AtomicxButton({
    super.key,
    required this.type,
    required this.content,
    this.size = ButtonSize.l,
    this.onClick,
    this.enabled = true,
    this.colorType = ButtonColorType.primary,
  });

  @override
  Widget build(BuildContext context) {
    final colorsTheme = BaseThemeProvider.colorsOf(context);
    final colors = _getButtonColors(type, colorType, colorsTheme);

    if (content is IconOnlyContent && type == ButtonType.filled) {
      return material.IconButton(
        onPressed: enabled ? onClick : null,
        icon: (content as IconOnlyContent).icon,
        iconSize: size.iconSize,
        style: material.IconButton.styleFrom(
          minimumSize: Size(size.height, size.height),
          maximumSize: Size(size.height, size.height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(size.height / 2),
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return colors.disabledBackgroundColor;
              }
              if (states.contains(WidgetState.pressed)) {
                return _getPressedBackgroundColor(type, colorType, colorsTheme);
              }
              if (states.contains(WidgetState.hovered)) {
                return _getHoverBackgroundColor(type, colorType, colorsTheme);
              }
              return colors.backgroundColor;
            },
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return colors.disabledTextColor;
              }
              return colors.textColor;
            },
          ),
        ),
      );
    }

    if (content is IconOnlyContent && type == ButtonType.noBorder) {
      return material.IconButton(
        onPressed: enabled ? onClick : null,
        icon: (content as IconOnlyContent).icon,
        iconSize: size.iconSize,
        style: material.IconButton.styleFrom(
          minimumSize: Size(size.height, size.height),
          maximumSize: Size(size.height, size.height),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(size.height / 2),
          ),
        ).copyWith(
          backgroundColor: WidgetStateProperty.all(Colors.transparent),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.disabled)) {
                return colors.disabledTextColor;
              }
              if (states.contains(WidgetState.pressed)) {
                return _getPressedTextColor(type, colorType, colorsTheme);
              }
              if (states.contains(WidgetState.hovered)) {
                return _getHoverTextColor(type, colorType, colorsTheme);
              }
              return colors.textColor;
            },
          ),
        ),
      );
    }

    Widget button;
    switch (type) {
      case ButtonType.filled:
        button = material.FilledButton(
          onPressed: enabled ? onClick : null,
          style: _buildFilledButtonStyle(colors, colorsTheme),
          child: _buildContent(colors),
        );
        break;
      case ButtonType.outlined:
        button = material.OutlinedButton(
          onPressed: enabled ? onClick : null,
          style: _buildOutlinedButtonStyle(colors, colorsTheme),
          child: _buildContent(colors),
        );
        break;
      case ButtonType.noBorder:
        button = TextButton(
          onPressed: enabled ? onClick : null,
          style: _buildTextButtonStyle(colors, colorsTheme),
          child: _buildContent(colors),
        );
        break;
    }

    return button;
  }

  ButtonStyle _buildFilledButtonStyle(ButtonColors colors, SemanticColorScheme colorsTheme) {
    return material.FilledButton.styleFrom(
      minimumSize: Size(_getMinWidth(), size.height),
      maximumSize: Size(double.infinity, size.height),
      padding: EdgeInsets.symmetric(horizontal: _getHorizontalPadding()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size.height / 2),
      ),
      textStyle: _fontForButtonSize(size),
    ).copyWith(
      backgroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledBackgroundColor;
          }
          if (states.contains(WidgetState.pressed)) {
            return _getPressedBackgroundColor(type, colorType, colorsTheme);
          }
          if (states.contains(WidgetState.hovered)) {
            return _getHoverBackgroundColor(type, colorType, colorsTheme);
          }
          return colors.backgroundColor;
        },
      ),
      foregroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledTextColor;
          }
          return colors.textColor;
        },
      ),
    );
  }

  ButtonStyle _buildOutlinedButtonStyle(ButtonColors colors, SemanticColorScheme colorsTheme) {
    return material.OutlinedButton.styleFrom(
      minimumSize: Size(_getMinWidth(), size.height),
      maximumSize: Size(double.infinity, size.height),
      padding: EdgeInsets.symmetric(horizontal: _getHorizontalPadding()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size.height / 2),
      ),
      textStyle: _fontForButtonSize(size),
    ).copyWith(
      foregroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledTextColor;
          }
          if (states.contains(WidgetState.pressed)) {
            return _getPressedTextColor(type, colorType, colorsTheme);
          }
          if (states.contains(WidgetState.hovered)) {
            return _getHoverTextColor(type, colorType, colorsTheme);
          }
          return colors.textColor;
        },
      ),
      side: WidgetStateProperty.resolveWith<BorderSide>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return BorderSide(color: colors.disabledBorderColor, width: 1);
          }
          if (states.contains(WidgetState.pressed)) {
            return BorderSide(color: _getPressedBorderColor(type, colorType, colorsTheme), width: 1);
          }
          if (states.contains(WidgetState.hovered)) {
            return BorderSide(color: _getHoverBorderColor(type, colorType, colorsTheme), width: 1);
          }
          return BorderSide(color: colors.borderColor, width: 1);
        },
      ),
    );
  }

  ButtonStyle _buildTextButtonStyle(ButtonColors colors, SemanticColorScheme colorsTheme) {
    return TextButton.styleFrom(
      minimumSize: Size(_getMinWidth(), size.height),
      maximumSize: Size(double.infinity, size.height),
      padding: EdgeInsets.symmetric(horizontal: _getHorizontalPadding()),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size.height / 2),
      ),
      textStyle: _fontForButtonSize(size),
    ).copyWith(
      backgroundColor: type == ButtonType.noBorder 
          ? WidgetStateProperty.all(Colors.transparent)
          : null,
      overlayColor: type == ButtonType.noBorder
          ? WidgetStateProperty.all(Colors.transparent)
          : null,
      foregroundColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.disabledTextColor;
          }
          if (states.contains(WidgetState.pressed)) {
            return _getPressedTextColor(type, colorType, colorsTheme);
          }
          if (states.contains(WidgetState.hovered)) {
            return _getHoverTextColor(type, colorType, colorsTheme);
          }
          return colors.textColor;
        },
      ),
    );
  }

  Widget _buildContent(ButtonColors colors) {
    switch (content) {
      case TextOnlyContent textContent:
        return Text(textContent.text);
      case IconOnlyContent iconContent:
        return SizedBox(
          width: size.iconSize,
          height: size.iconSize,
          child: IconTheme(
            data: IconThemeData(
              color: colors.textColor,
              size: size.iconSize,
            ),
            child: iconContent.icon,
          ),
        );
      case IconWithTextContent iconTextContent:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconTextContent.iconPosition == ButtonIconPosition.start) ...[
              SizedBox(
                width: size.iconSize,
                height: size.iconSize,
                child: IconTheme(
                  data: IconThemeData(
                    color: colors.textColor,
                    size: size.iconSize,
                  ),
                  child: iconTextContent.icon,
                ),
              ),
              const SizedBox(width: 4),
            ],
            Text(iconTextContent.text),
            if (iconTextContent.iconPosition == ButtonIconPosition.end) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: size.iconSize,
                height: size.iconSize,
                child: IconTheme(
                  data: IconThemeData(
                    color: colors.textColor,
                    size: size.iconSize,
                  ),
                  child: iconTextContent.icon,
                ),
              ),
            ],
          ],
        );
    }
  }

  double _getMinWidth() {
    switch (content) {
      case IconOnlyContent():
        return size.height;
      default:
        return size.minWidth;
    }
  }

  double _getHorizontalPadding() {
    switch (content) {
      case IconOnlyContent():
        return 0;
      default:
        return size.horizontalPadding;
    }
  }
}

class FilledButton extends StatelessWidget {
  final ButtonContent content;
  final ButtonSize size;
  final VoidCallback? onClick;
  final bool enabled;
  final ButtonColorType colorType;

  FilledButton({
    super.key,
    required String text,
    this.size = ButtonSize.l,
    this.onClick,
    this.enabled = true,
    this.colorType = ButtonColorType.primary,
  }) : content = TextOnlyContent(text);

  static Widget buttonContent({
    Key? key,
    required ButtonContent content,
    ButtonType type = ButtonType.filled,
    ButtonSize size = ButtonSize.l,
    VoidCallback? onClick,
    bool enabled = true,
    ButtonColorType colorType = ButtonColorType.primary,
  }) {
    return _AtomicxButton(
      key: key,
      type: type,
      content: content,
      size: size,
      onClick: onClick,
      enabled: enabled,
      colorType: colorType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AtomicxButton(
      type: ButtonType.filled,
      content: content,
      size: size,
      onClick: onClick,
      enabled: enabled,
      colorType: colorType,
    );
  }
}

class OutlinedButton extends StatelessWidget {
  final ButtonContent content;
  final ButtonSize size;
  final VoidCallback? onClick;
  final bool enabled;
  final ButtonColorType colorType;

  OutlinedButton({
    super.key,
    required String text,
    this.size = ButtonSize.l,
    this.onClick,
    this.enabled = true,
    this.colorType = ButtonColorType.primary,
  }) : content = TextOnlyContent(text);

  static Widget buttonContent({
    Key? key,
    required ButtonContent content,
    ButtonType type = ButtonType.outlined,
    ButtonSize size = ButtonSize.l,
    VoidCallback? onClick,
    bool enabled = true,
    ButtonColorType colorType = ButtonColorType.primary,
  }) {
    return _AtomicxButton(
      key: key,
      type: type,
      content: content,
      size: size,
      onClick: onClick,
      enabled: enabled,
      colorType: colorType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AtomicxButton(
      type: ButtonType.outlined,
      content: content,
      size: size,
      onClick: onClick,
      enabled: enabled,
      colorType: colorType,
    );
  }
}

class IconButton extends StatelessWidget {
  final ButtonContent content;
  final ButtonSize size;
  final VoidCallback? onClick;
  final bool enabled;
  final ButtonColorType colorType;

  IconButton({
    super.key,
    required Widget icon,
    this.size = ButtonSize.l,
    this.onClick,
    this.enabled = true,
    this.colorType = ButtonColorType.primary,
  }) : content = IconOnlyContent(icon);

  static Widget buttonContent({
    Key? key,
    required ButtonContent content,
    ButtonType type = ButtonType.filled,
    ButtonSize size = ButtonSize.l,
    VoidCallback? onClick,
    bool enabled = true,
    ButtonColorType colorType = ButtonColorType.primary,
  }) {
    return _AtomicxButton(
      key: key,
      type: type,
      content: content,
      size: size,
      onClick: onClick,
      enabled: enabled,
      colorType: colorType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return _AtomicxButton(
      type: ButtonType.filled,
      content: content,
      size: size,
      onClick: onClick,
      enabled: enabled,
      colorType: colorType,
    );
  }
}
