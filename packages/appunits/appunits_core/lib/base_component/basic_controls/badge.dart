import 'package:flutter/material.dart';
import '../theme/theme_state.dart';

enum BadgeType {
  text,
  dot,
}

class Badge extends StatelessWidget {
  final String? text;
  final BadgeType type;

  const Badge({
    super.key,
    this.text,
    this.type = BadgeType.text,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BaseThemeProvider.colorsOf(context);

    if (text?.isEmpty != false || type == BadgeType.dot) {
      return Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: colors.textColorError,
          shape: BoxShape.circle,
        ),
      );
    } else {
      return Container(
        height: 16,
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          color: colors.textColorError,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            text!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }
  }
} 