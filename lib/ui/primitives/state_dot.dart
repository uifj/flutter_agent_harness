// The state indicator, ported from `ui-primitives/src/StateDot.tsx` and its
// stylesheet.
//
// Three of the four states are a 10px halo at 10% opacity around a 6px solid
// core, all in one colour. The fourth is a pixel-art chase: the eight outer
// cells of a 3x3 matrix light up clockwise with a stepped trail, held flat
// rather than tweened — the retro feel is the point, so the steps are copied
// exactly.

import 'package:flutter/material.dart';

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_static.dart';
import '../../theme/dsw_theme.dart';

enum StateDotState { done, warning, ongoing, error }

class StateDot extends StatelessWidget {
  const StateDot({super.key, required this.state, this.size = 10});

  final StateDotState state;

  /// Outer diameter. 10 is the Figma size and the grid the chase is drawn on.
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    if (state == StateDotState.ongoing) {
      return _Chase(size: size, color: _ongoing);
    }
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SolidPainter(_solidColor(color))),
    );
  }

  /// The running blue has no alias token: `state-business-primary` is the 500
  /// step and this is the 450, so the source pins it to the static scale and so
  /// does this port.
  static const _ongoing = DswStatic.deepseek450;

  Color _solidColor(DswAlias color) => switch (state) {
    StateDotState.done => color.stateSuccessPrimary,
    StateDotState.warning => color.stateWarnPrimary,
    StateDotState.error => color.stateErrorPrimary,
    StateDotState.ongoing => _ongoing,
  };
}

class _SolidPainter extends CustomPainter {
  const _SolidPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = color.withValues(alpha: color.a * 0.1),
    );
    // `inset: 20%` of the box, so a 6px core on the 10px dot.
    canvas.drawCircle(centre, radius * 0.6, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SolidPainter old) => old.color != color;
}

/// The eight outer cells of the 3x3 matrix, clockwise from the top left, on the
/// 10px grid the source draws them on.
const _cells = <Offset>[
  Offset(0, 0),
  Offset(4, 0),
  Offset(8, 0),
  Offset(8, 4),
  Offset(8, 8),
  Offset(4, 8),
  Offset(0, 8),
  Offset(0, 4),
];

class _Chase extends StatefulWidget {
  const _Chase({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  State<_Chase> createState() => _ChaseState();
}

class _ChaseState extends State<_Chase> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(seconds: 1),
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // An indicator that never settles is exactly what reduced motion is asking
    // about. The source has no rule for this one, so the port freezes the chase
    // at its first frame rather than dropping the dot.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ChasePainter(color: widget.color, phase: _controller.value),
        ),
      ),
    );
  }
}

class _ChasePainter extends CustomPainter {
  const _ChasePainter({required this.color, required this.phase});

  final Color color;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 10;
    // `shapeRendering: crispEdges`: 2px cells on a 10px grid only read as pixels
    // if their edges stay hard.
    final paint = Paint()..isAntiAlias = false;
    for (var index = 0; index < _cells.length; index++) {
      // The source phases the cells with `animation-delay: (index - 8) * 125ms`,
      // a negative delay that starts each one partway through its own cycle.
      final progress = (phase + (_cells.length - index) * 0.125) % 1;
      paint.color = color.withValues(alpha: color.a * _step(progress));
      final cell = _cells[index];
      canvas.drawRect(
        Rect.fromLTWH(cell.dx * scale, cell.dy * scale, 2 * scale, 2 * scale),
        paint,
      );
    }
  }

  /// The four flat holds of `dsh-state-dot-chase`: peak as the chase arrives,
  /// then three decaying steps.
  static double _step(double progress) {
    if (progress < 0.125) return 1;
    if (progress < 0.25) return 0.6;
    if (progress < 0.375) return 0.35;
    return 0.15;
  }

  @override
  bool shouldRepaint(_ChasePainter old) =>
      old.phase != phase || old.color != color;
}
