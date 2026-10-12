/// 全局通用加载指示器。
///
/// 提供全屏遮罩加载、内联加载、下拉刷新加载三种模式，
/// 统一全应用加载态视觉风格。
library;

import 'package:flutter/material.dart';

/// 加载样式枚举。
enum LoadingStyle {
  /// 全屏遮罩 + 半透明背景 + 居中 spinner。
  overlay,

  /// 内联小尺寸加载（适合按钮内、列表底部等）。
  inline,

  /// 页面级加载骨架（伴随 [SkeletonScreen] 使用）。
  skeleton,
}

/// 加载指示器统一入口。
///
/// 支持文本提示、遮罩透明度、自定义颜色等配置。
///
/// ```dart
/// // 全屏加载
/// LoadingOverlay.show(context, message: '加载中...');
///
/// // 内联加载
/// LoadingOverlay.inline(color: Colors.blue);
/// ```
final class LoadingOverlay {
  LoadingOverlay._();

  /// 显示全屏加载遮罩。
  ///
  /// 返回一个 [OverlayEntry] 可供调用方手动关闭。
  static OverlayEntry show(
    BuildContext context, {
    String? message,
    Color? backgroundColor,
    Color? indicatorColor,
    double indicatorSize = 48.0,
  }) {
    final entry = OverlayEntry(
      builder: (_) => _FullScreenLoading(
        message: message,
        backgroundColor: backgroundColor,
        indicatorColor: indicatorColor,
        indicatorSize: indicatorSize,
      ),
    );
    Overlay.of(context).insert(entry);
    return entry;
  }

  /// 隐藏指定的加载遮罩。
  static void hide(OverlayEntry entry) {
    entry.remove();
  }

  /// 内联小尺寸加载指示器 Widget。
  static Widget inline({
    double size = 24.0,
    Color? color,
    double strokeWidth = 3.0,
  }) => SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(
      strokeWidth: strokeWidth,
      valueColor: AlwaysStoppedAnimation<Color>(
        color ?? Colors.blue,
      ),
    ),
  );
}

/// 全屏加载 Widget（内部使用）。
class _FullScreenLoading extends StatelessWidget {
  const _FullScreenLoading({
    this.message,
    this.backgroundColor,
    this.indicatorColor,
    this.indicatorSize = 48.0,
  });

  final String? message;
  final Color? backgroundColor;
  final Color? indicatorColor;
  final double indicatorSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? Colors.black26,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: indicatorSize,
              height: indicatorSize,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  indicatorColor ?? Colors.white,
                ),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16.0),
              Text(
                message!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.0,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
