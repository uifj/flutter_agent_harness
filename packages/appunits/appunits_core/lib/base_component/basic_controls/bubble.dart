import 'package:flutter/material.dart';
import '../theme/theme_state.dart';

enum BubbleColorType {
  filled,
  outlined,
  both,
}

class RoundedCornerShape extends ShapeBorder {
  final List<double> radii; // [topLeft, topRight, bottomRight, bottomLeft]
  final BorderSide side;

  const RoundedCornerShape({
    required this.radii,
    this.side = BorderSide.none,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return getOuterPath(rect, textDirection: textDirection);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final topLeft = radii.isNotEmpty ? radii[0] : 0.0;
    final topRight = radii.length > 1 ? radii[1] : 0.0;
    final bottomRight = radii.length > 2 ? radii[2] : 0.0;
    final bottomLeft = radii.length > 3 ? radii[3] : 0.0;

    return Path()
      ..addRRect(RRect.fromLTRBAndCorners(
        rect.left,
        rect.top,
        rect.right,
        rect.bottom,
        topLeft: Radius.circular(topLeft),
        topRight: Radius.circular(topRight),
        bottomRight: Radius.circular(bottomRight),
        bottomLeft: Radius.circular(bottomLeft),
      ));
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style != BorderStyle.none) {
      final paint = Paint()
        ..color = side.color
        ..strokeWidth = side.width
        ..style = PaintingStyle.stroke;
      
      canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
    }
  }

  @override
  ShapeBorder scale(double t) => RoundedCornerShape(
    radii: radii.map((r) => r * t).toList(),
    side: side.scale(t),
  );

  RoundedCornerShape copyWith({
    List<double>? radii,
    BorderSide? side,
  }) {
    return RoundedCornerShape(
      radii: radii ?? this.radii,
      side: side ?? this.side,
    );
  }
}

class Bubble extends StatelessWidget {
  final BubbleColorType bubbleColorType;
  final Color backgroundColor;
  final List<Color>? highlightColors;
  final List<double> radii; // [topLeft, topRight, bottomRight, bottomLeft]
  final Color? borderColor;
  final double borderWidth;
  final Widget child;

  const Bubble({
    super.key,
    this.bubbleColorType = BubbleColorType.filled,
    required this.backgroundColor,
    this.highlightColors,
    this.radii = const [18, 18, 18, 0],
    this.borderColor,
    this.borderWidth = 1,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorsTheme = BaseThemeProvider.colorsOf(context);
    
    final shape = RoundedCornerShape(
      radii: radii,
      side: (bubbleColorType == BubbleColorType.outlined || 
             bubbleColorType == BubbleColorType.both)
          ? BorderSide(
              color: borderColor ?? colorsTheme.strokeColorPrimary,
              width: borderWidth,
            )
          : BorderSide.none,
    );
    
    return Container(
      constraints: const BoxConstraints(minWidth: 40),
      decoration: ShapeDecoration(
        shape: shape,
        color: bubbleColorType == BubbleColorType.outlined 
            ? Colors.transparent 
            : backgroundColor,
        gradient: highlightColors != null && highlightColors!.length > 1
            ? LinearGradient(
                colors: highlightColors!,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: child,
      ),
    );
  }
}

class LeftBottomSquareBubble extends StatelessWidget {
  final Color backgroundColor;
  final List<Color>? highlightColors;
  final Widget child;

  const LeftBottomSquareBubble({
    super.key,
    required this.backgroundColor,
    this.highlightColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Bubble(
      bubbleColorType: BubbleColorType.filled,
      backgroundColor: backgroundColor,
      highlightColors: highlightColors,
      radii: const [18, 18, 18, 0],
      child: child,
    );
  }
}

class RightBottomSquareBubble extends StatelessWidget {
  final Color backgroundColor;
  final List<Color>? highlightColors;
  final Widget child;

  const RightBottomSquareBubble({
    super.key,
    required this.backgroundColor,
    this.highlightColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Bubble(
      bubbleColorType: BubbleColorType.filled,
      backgroundColor: backgroundColor,
      highlightColors: highlightColors,
      radii: const [18, 18, 0, 18],
      child: child,
    );
  }
}

class AllRoundBubble extends StatelessWidget {
  final Color backgroundColor;
  final List<Color>? highlightColors;
  final Widget child;

  const AllRoundBubble({
    super.key,
    required this.backgroundColor,
    this.highlightColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Bubble(
      bubbleColorType: BubbleColorType.filled,
      backgroundColor: backgroundColor,
      highlightColors: highlightColors,
      radii: const [18, 18, 18, 18],
      child: child,
    );
  }
}

class LeftTopSquareBubble extends StatelessWidget {
  final Color backgroundColor;
  final List<Color>? highlightColors;
  final Widget child;

  const LeftTopSquareBubble({
    super.key,
    required this.backgroundColor,
    this.highlightColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Bubble(
      bubbleColorType: BubbleColorType.filled,
      backgroundColor: backgroundColor,
      highlightColors: highlightColors,
      radii: const [0, 18, 18, 18],
      child: child,
    );
  }
}

class RightTopSquareBubble extends StatelessWidget {
  final Color backgroundColor;
  final List<Color>? highlightColors;
  final Widget child;

  const RightTopSquareBubble({
    super.key,
    required this.backgroundColor,
    this.highlightColors,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Bubble(
      bubbleColorType: BubbleColorType.filled,
      backgroundColor: backgroundColor,
      highlightColors: highlightColors,
      radii: const [18, 0, 18, 18],
      child: child,
    );
  }
} 