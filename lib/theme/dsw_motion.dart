// dsh motion, ported from `base.css:11-14`.
//
//   --ds-ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
//   --ds-transition-duration: 0.2s;
//   --ds-transition-duration-fast: 0.1s;
//   --ds-transition-duration-slow: 0.3s;
//
// One curve, three durations — dsh does not vary the easing per property, and
// neither should this port.

import 'package:flutter/animation.dart' show Cubic;
import 'package:flutter/widgets.dart' show BuildContext, MediaQuery;

abstract final class DswMotion {
  /// `--ds-ease-in-out`. Identical to Material's `easeInOut` numerically, but
  /// spelled out so the tie to the CSS token stays visible.
  static const easeInOut = Cubic(0.4, 0, 0.2, 1);

  /// `--ds-transition-duration-fast`. Hover and press feedback.
  static const fast = Duration(milliseconds: 100);

  /// `--ds-transition-duration`. The default.
  static const normal = Duration(milliseconds: 200);

  /// `--ds-transition-duration-slow`. Column width changes in `app_frame.dart`.
  static const slow = Duration(milliseconds: 300);

  /// How long the pointer must rest before a tooltip appears. Deliberately not
  /// run through [respecting]: a delay is not an animation, and collapsing it
  /// to zero is what made a sweep across the tab strip flash one bubble per
  /// tab (ADR-0023).
  static const tooltipDelay = Duration(milliseconds: 500);

  /// Collapses [duration] to zero when the user has asked for reduced motion,
  /// the Flutter counterpart of `@media (prefers-reduced-motion: reduce)`.
  ///
  /// Zero is safe to hand to `AnimatedContainer` and friends — they simply jump
  /// to the target value.
  static Duration respecting(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
