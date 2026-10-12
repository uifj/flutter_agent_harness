/// 反馈提交成功弹窗（legacy: SubmitSuccessDialog 的通用化重写）。
///
/// 行为保真：提示语 + 大号反馈 ID + 可复制 + 单确认按钮。
/// 去宿主化：反馈记录 webview 跳转（authCode 拼接、launchWebView）与
/// 客服会话链接均属宿主能力，经 [onSecondaryAction] 出让。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import './feedback_ui_labels.dart';

class FeedbackSuccessDialog extends StatefulWidget {
  const FeedbackSuccessDialog({
    super.key,
    required this.issueId,
    this.labels = const FeedbackUiLabels(),
    this.onConfirm,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  /// 服务端返回的反馈单号。
  final String issueId;

  final FeedbackUiLabels labels;

  final VoidCallback? onConfirm;

  /// 次要动作（宿主可挂"反馈记录"/"联系客服"）。
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  State<FeedbackSuccessDialog> createState() => _FeedbackSuccessDialogState();
}

class _FeedbackSuccessDialogState extends State<FeedbackSuccessDialog> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.issueId));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.maybeOf(context);
    final theme = Theme.of(context);
    final primary = shad?.colorScheme.primary ?? theme.colorScheme.primary;
    final muted =
        shad?.colorScheme.mutedForeground ?? theme.colorScheme.outline;
    final labels = widget.labels;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            labels.successTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(LucideIcons.info, size: 18, color: primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  labels.successTip,
                  style: TextStyle(color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            widget.issueId,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            labels.successIdCaption,
            textAlign: TextAlign.center,
            style: TextStyle(color: muted),
          ),
          const SizedBox(height: 8),
          Center(
            child: ShadButton.ghost(
              onPressed: _copy,
              leading: Icon(
                _copied ? LucideIcons.check : LucideIcons.copy,
                size: 16,
              ),
              child: Text(_copied ? labels.copiedText : labels.copyText),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (widget.onSecondaryAction != null)
                ShadButton.outline(
                  onPressed: widget.onSecondaryAction,
                  child: Text(widget.secondaryActionLabel ?? ''),
                ),
              if (widget.onSecondaryAction != null) const SizedBox(width: 12),
              ShadButton(
                onPressed: widget.onConfirm,
                child: Text(labels.confirmText),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
