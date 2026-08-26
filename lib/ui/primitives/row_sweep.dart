// The running wash shared by the reasoning row and the tool row.
//
// Both spell the same rule — `ReasoningRow.module.css` and
// `ToolRow.module.css` carry byte-identical keyframes and gradient — so it lives
// here once. A 300px band of the page background at 60% travels across the row
// and holds off its right edge for the last tenth of the cycle, which gives each
// pass a beat before the next.
//
// It is a `DisclosureRow.rowOverlay`, clipped to the header by that primitive.

import 'package:flutter/material.dart';

class RowSweep extends StatefulWidget {
  const RowSweep({super.key, required this.base});

  /// The page background. The band washes glyphs *toward* the page rather than
  /// tinting them, so this is the only colour involved.
  final Color base;

  @override
  State<RowSweep> createState() => _RowSweepState();
}

class _RowSweepState extends State<RowSweep>
    with SingleTickerProviderStateMixin {
  static const _width = 300.0;

  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 2600),
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `prefers-reduced-motion` stops the sweep outright — the row is still
    // marked running by its state dot and summary, so nothing is lost.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      return const SizedBox.shrink();
    }
    if (!_controller.isAnimating) _controller.repeat();

    final wash = widget.base;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) => AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            // The keyframes travel over the first 90% and hold at `left: 100%`
            // for the rest, so the gap between passes is part of the cycle.
            final travel = (_controller.value / 0.9).clamp(0.0, 1.0);
            final left =
                -_width +
                Curves.easeOut.transform(travel) *
                    (constraints.maxWidth + _width);
            return Stack(
              children: [
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: _width,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          wash.withValues(alpha: 0),
                          wash.withValues(alpha: wash.a * 0.6),
                          wash.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.55, 1],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
