/// 全局空状态页面组件。
///
/// 提供列表空数据、搜索无结果、网络异常等场景的统一空状态
/// 展示，支持图标、文案、操作按钮自定义。
library;

import 'package:flutter/material.dart';

/// 空状态配置。
final class EmptyStateConfig {
  const EmptyStateConfig({
    this.icon,
    this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconSize = 80.0,
    this.spacing = 16.0,
  });

  /// 顶部图标。
  final Widget? icon;

  /// 主标题。
  final String? title;

  /// 副标题 / 补充说明。
  final String? subtitle;

  /// 操作按钮文案。
  final String? actionLabel;

  /// 操作按钮回调。
  final VoidCallback? onAction;

  /// 图标区域大小。
  final double iconSize;

  /// 元素间距。
  final double spacing;
}

/// 全局空状态页面 Widget。
///
/// 支持全屏居中或列表内嵌使用。
///
/// ```dart
/// EmptyStateWidget(
///   config: EmptyStateConfig.defaultNoData(
///     onAction: () => refresh(),
///   ),
/// )
/// ```
class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({
    super.key,
    required this.config,
    this.padding = const EdgeInsets.all(32.0),
  });

  /// 空状态配置。
  final EmptyStateConfig config;

  /// 外间距。
  final EdgeInsetsGeometry padding;

  /// 快捷构造：暂无数据。
  factory EmptyStateWidget.noData({
    VoidCallback? onAction,
    String? title,
    String? subtitle,
  }) => EmptyStateWidget(
    config: DefaultEmptyState.noData(
      onAction: onAction,
      title: title,
      subtitle: subtitle,
    ),
  );

  /// 快捷构造：网络异常。
  factory EmptyStateWidget.networkError({
    VoidCallback? onAction,
    String? title,
    String? subtitle,
  }) => EmptyStateWidget(
    config: DefaultEmptyState.networkError(
      onAction: onAction,
      title: title,
      subtitle: subtitle,
    ),
  );

  /// 快捷构造：搜索无结果。
  factory EmptyStateWidget.searchEmpty({
    VoidCallback? onAction,
    String? title,
    String? subtitle,
  }) => EmptyStateWidget(
    config: DefaultEmptyState.searchEmpty(
      onAction: onAction,
      title: title,
      subtitle: subtitle,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (config.icon != null) ...[
              SizedBox(
                width: config.iconSize,
                height: config.iconSize,
                child: config.icon,
              ),
              SizedBox(height: config.spacing),
            ],
            if (config.title != null) ...[
              Text(
                config.title!,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: config.spacing / 2),
            ],
            if (config.subtitle != null) ...[
              Text(
                config.subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: config.spacing),
            ],
            if (config.actionLabel != null && config.onAction != null)
              ElevatedButton(
                onPressed: config.onAction,
                child: Text(config.actionLabel!),
              ),
          ],
        ),
      ),
    );
  }
}

/// 预设空状态配置工厂。
extension DefaultEmptyState on EmptyStateConfig {
  /// 暂无数据预设。
  static EmptyStateConfig noData({
    VoidCallback? onAction,
    String? title,
    String? subtitle,
  }) => EmptyStateConfig(
    icon: const Icon(Icons.inbox_outlined, size: 64.0),
    title: title ?? '暂无数据',
    subtitle: subtitle,
    actionLabel: onAction != null ? '刷新' : null,
    onAction: onAction,
  );

  /// 网络异常预设。
  static EmptyStateConfig networkError({
    VoidCallback? onAction,
    String? title,
    String? subtitle,
  }) => EmptyStateConfig(
    icon: const Icon(Icons.wifi_off_rounded, size: 64.0),
    title: title ?? '网络异常',
    subtitle: subtitle ?? '请检查网络连接后重试',
    actionLabel: onAction != null ? '重试' : null,
    onAction: onAction,
  );

  /// 搜索无结果预设。
  static EmptyStateConfig searchEmpty({
    VoidCallback? onAction,
    String? title,
    String? subtitle,
  }) => EmptyStateConfig(
    icon: const Icon(Icons.search_off_rounded, size: 64.0),
    title: title ?? '未找到相关内容',
    subtitle: subtitle ?? '试试调整搜索关键词',
    actionLabel: null,
    onAction: null,
  );
}
