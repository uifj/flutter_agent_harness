// Window geometry persistence (ADR-0062): the shape the window comes back
// in, and the clamp that keeps a restored rectangle on a screen that may
// have changed since. Pure Dart — the store reads and writes the file, the
// composition root talks to window_manager.

import 'dart:math' as math;
import 'dart:ui';

/// One persisted window rectangle: top-left position and size, in logical
/// pixels.
class WindowGeometry {
  const WindowGeometry({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  factory WindowGeometry.fromJson(Map<String, Object?> json) => WindowGeometry(
    x: (json['x'] as num?)?.toDouble() ?? 0,
    y: (json['y'] as num?)?.toDouble() ?? 0,
    width: (json['width'] as num?)?.toDouble() ?? 0,
    height: (json['height'] as num?)?.toDouble() ?? 0,
  );

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, Object?> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };

  /// How much of a restored window's edge must stay inside the visible area
  /// for the window to be reachable at all.
  static const edgeRescue = 80.0;

  /// [visible] is the primary display's visible rectangle. The size is clamped
  /// into it first, then the position is kept such that at least [edgeRescue]
  /// pixels of the window stay on screen in both axes — a window the pointer
  /// can never reach again is a lost window.
  WindowGeometry clampedTo(Rect visible) {
    final clampedWidth = math.min(math.max(width, 1.0), visible.width);
    final clampedHeight = math.min(math.max(height, 1.0), visible.height);
    final clampedX = _clampAxis(x, clampedWidth, visible.left, visible.right);
    final clampedY = _clampAxis(y, clampedHeight, visible.top, visible.bottom);
    return WindowGeometry(
      x: clampedX,
      y: clampedY,
      width: clampedWidth,
      height: clampedHeight,
    );
  }

  static double _clampAxis(
    double position,
    double extent,
    double min,
    double max,
  ) {
    // The window's leading edge may sit anywhere from `min - extent +
    // edgeRescue` (trailing edge just on screen) to `max - edgeRescue`
    // (leading edge just on screen).
    final lower = min - extent + edgeRescue;
    final upper = max - edgeRescue;
    if (upper < lower) return min; // Screen narrower than the rescue band.
    return math.min(math.max(position, lower), upper);
  }
}
