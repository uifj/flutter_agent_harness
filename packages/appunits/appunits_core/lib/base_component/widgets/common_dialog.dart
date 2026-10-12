/// 全局通用弹窗组件。
///
/// 统一 Alert、Confirm、BottomSheet 三种弹窗风格，
/// 提供一致的视觉规范和交互行为。
library;

import 'package:flutter/material.dart';

/// 弹窗操作按钮。
final class DialogAction {
  const DialogAction({
    required this.label,
    this.onPressed,
    this.isDestructive = false,
    this.isPrimary = true,
  });

  /// 按钮文案。
  final String label;

  /// 点击回调。
  final VoidCallback? onPressed;

  /// 是否是破坏性操作（红色）。
  final bool isDestructive;

  /// 是否是主操作（填充按钮）。
  final bool isPrimary;
}

/// 通用弹窗入口。
///
/// ```dart
/// // Alert 提示
/// CommonDialog.alert(context, title: '提示', message: '操作成功');
///
/// // Confirm 确认
/// final confirmed = await CommonDialog.confirm(
///   context,
///   title: '确认删除',
///   message: '删除后无法恢复',
/// );
///
/// // Bottom Sheet
/// CommonDialog.showBottomSheet(
///   context,
///   actions: [
///     DialogAction(label: '拍照', onPressed: () {}),
///     DialogAction(label: '从相册选择', onPressed: () {}),
///   ],
/// );
/// ```
final class CommonDialog {
  CommonDialog._();

  /// 显示 Alert 提示弹窗（单按钮）。
  static Future<void> alert(
    BuildContext context, {
    String? title,
    required String message,
    String confirmLabel = '确定',
    VoidCallback? onConfirm,
    bool barrierDismissible = true,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AlertDialog(
        title: title != null ? Text(title) : null,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              onConfirm?.call();
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  /// 显示确认弹窗（双按钮：取消 + 确认）。
  ///
  /// 返回 `true` 表示用户点击了确认。
  static Future<bool> confirm(
    BuildContext context, {
    String? title,
    required String message,
    String confirmLabel = '确认',
    String cancelLabel = '取消',
    bool isDestructive = false,
    bool barrierDismissible = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => AlertDialog(
        title: title != null ? Text(title) : null,
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              confirmLabel,
              style: TextStyle(
                color: isDestructive ? Colors.red : null,
              ),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 显示底部操作列表。
  static Future<void> showBottomSheet(
    BuildContext context, {
    String? title,
    required List<DialogAction> actions,
    String cancelLabel = '取消',
  }) async {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 16.0,
                ),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const Divider(height: 1.0),
            ],
            for (final action in actions)
              ListTile(
                title: Text(
                  action.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: action.isDestructive ? Colors.red : null,
                    fontWeight: action.isPrimary
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  action.onPressed?.call();
                },
              ),
            const Divider(height: 1.0),
            ListTile(
              title: const Text(
                '取消',
                textAlign: TextAlign.center,
              ),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
