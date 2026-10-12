/// 全局骨架屏组件。
///
/// 提供 Shimmer 动画占位符，支持矩形、圆形、卡片等多种形状，
/// 用于页面/列表首次加载时的内容占位。
library;

import 'package:flutter/material.dart';

/// 骨架屏动画模式。
enum SkeletonAnimation {
  /// 从左到右波浪闪光（默认）。
  shimmer,

  /// 脉冲明暗。
  pulse,

  /// 无动画静态。
  none,
}

/// 骨架屏容器。
///
/// 包裹子组件并施加骨架屏动画效果。
///
/// ```dart
/// SkeletonScreen(
///   child: Column(
///     children: [
///       SkeletonBlock(width: double.infinity, height: 200.0),
///       SizedBox(height: 12.0),
///       SkeletonBlock(width: 200.0, height: 16.0),
///     ],
///   ),
/// )
/// ```
class SkeletonScreen extends StatefulWidget {
  const SkeletonScreen({
    super.key,
    required this.child,
    this.animation = SkeletonAnimation.shimmer,
    this.baseColor,
    this.highlightColor,
  });

  /// 骨架屏内容（由 [SkeletonBlock] 、 [SkeletonCircle] 等组成）。
  final Widget child;

  /// 动画模式。
  final SkeletonAnimation animation;

  /// 基础颜色。
  final Color? baseColor;

  /// 高亮颜色（shimmer 模式光带颜色）。
  final Color? highlightColor;

  @override
  State<SkeletonScreen> createState() => _SkeletonScreenState();
}

class _SkeletonScreenState extends State<SkeletonScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.baseColor ?? Theme.of(context).colorScheme.surfaceContainerHigh;
    final highlightColor =
        widget.highlightColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;

    switch (widget.animation) {
      case SkeletonAnimation.shimmer:
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, child) => ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  baseColor,
                  highlightColor,
                  baseColor,
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(
                Rect.fromLTWH(
                  -bounds.width + bounds.width * 2.0 * _controller.value,
                  0,
                  bounds.width,
                  bounds.height,
                ),
              );
            },
            blendMode: BlendMode.srcATop,
            child: widget.child,
          ),
        );
      case SkeletonAnimation.pulse:
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, child) => Opacity(
            opacity: 0.4 + 0.6 * _controller.value,
            child: widget.child,
          ),
        );
      case SkeletonAnimation.none:
        return widget.child;
    }
  }
}

/// 矩形骨架占位块。
class SkeletonBlock extends StatelessWidget {
  const SkeletonBlock({
    super.key,
    this.width,
    this.height = 16.0,
    this.borderRadius = 4.0,
    this.color,
  });

  /// 宽度。`null` 表示自适应父级。
  final double? width;

  /// 高度。
  final double height;

  /// 圆角。
  final double borderRadius;

  /// 占位颜色。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        color ?? Theme.of(context).colorScheme.surfaceContainerHigh;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// 圆形骨架占位（常用于头像）。
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({
    super.key,
    this.size = 48.0,
    this.color,
  });

  /// 直径。
  final double size;

  /// 占位颜色。
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fillColor =
        color ?? Theme.of(context).colorScheme.surfaceContainerHigh;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 骨架屏卡片（矩形 + 内容行组合）。
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.lines = 3,
    this.padding = const EdgeInsets.all(16.0),
    this.spacing = 12.0,
  });

  /// 文本行数。
  final int lines;

  /// 卡片内间距。
  final EdgeInsetsGeometry padding;

  /// 行间距。
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBlock(width: double.infinity, height: 160.0),
          SizedBox(height: spacing),
          for (var i = 0; i < lines; i++) ...[
            SkeletonBlock(
              width: i == lines - 1 ? 120.0 : double.infinity,
              height: 14.0,
            ),
            if (i < lines - 1) SizedBox(height: spacing),
          ],
        ],
      ),
    );
  }
}
