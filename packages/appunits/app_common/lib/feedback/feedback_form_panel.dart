/// 用户反馈表单面板（legacy: UserAdvice + FeedbackFormSection +
/// ActionButtonsSection 的通用化重写）。
///
/// 行为保真：
/// - 反馈类型固定二选一：1=问题 / 3=建议（legacy: _feedbackTypes = [1, 3]）；
/// - 内容 300 字上限、非法字符过滤正则逐字保真（feedback_form_section L124-130）；
/// - 提交禁用逻辑逐字保真（action_buttons_section L662-667）：
///   内容非空 && 类型已选 && (companyId 非空 || 已登录 || 个人版)；
/// - 未登录且非个人版时显示企业 ID 必填项（L42）。
///
/// 去宿主化：截图/录音/图片挑选等设备能力经 [attachmentArea] 插槽出让；
/// 历史记录跳转、二维码群组等宿主能力不纳入。提交动作经 [onSubmit] 出让
/// （宿主组装 FeedbackDraft 交给自己的反馈通道）。文案不再由宿主注入：面板
/// 直接读本包 gen-l10n 的 `AppCommonLocalizations.of(context)`（镜像
/// appunits_core 的 `AtomicLocalizations`，ADR-0084 D4 Tier A）——宿主须在
/// `MaterialApp.localizationsDelegates` 注册 `AppCommonLocalizations.delegate`。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../localizations/app_common_localizations.dart';

/// 表单产出（宿主转换为 FeedbackDraft）。
class FeedbackFormData {
  const FeedbackFormData({
    required this.fbType,
    required this.description,
    this.contact = '',
    this.companyId = '',
    this.uploadLog = true,
  });

  /// 1 = 问题反馈，3 = 产品建议。
  final int fbType;
  final String description;
  final String contact;
  final String companyId;
  final bool uploadLog;
}

class FeedbackFormPanel extends StatefulWidget {
  const FeedbackFormPanel({
    super.key,
    required this.onSubmit,
    this.isLogin = false,
    this.isPersonal = false,
    this.submitting = false,
    this.attachmentArea,
    this.onCancel,
  });

  final void Function(FeedbackFormData data) onSubmit;

  /// 已登录（legacy: account.login.state == '1'）。
  final bool isLogin;

  /// 个人版（legacy: isPersonal）。
  final bool isPersonal;

  /// 提交中：按钮禁用（legacy: controller.isLoading）。
  final bool submitting;

  /// 附件区插槽（截图/录音/图片挑选属宿主设备能力）。
  final Widget? attachmentArea;

  final VoidCallback? onCancel;

  @override
  State<FeedbackFormPanel> createState() => _FeedbackFormPanelState();
}

class _FeedbackFormPanelState extends State<FeedbackFormPanel> {
  /// 非法字符过滤（legacy 正则逐字保真）。
  static final RegExp _illegalChars = RegExp(
    '[^\\u0020-\\u007E\\u00A0-\\u00BE\\u2E80-\\uA4CF\\uF900-\\uFAFF'
    '\\uFE30-\\uFE4F\\uFF00-\\uFFEF\\u0080-\\u009F\\u2000-\\u201f\r\n]',
  );

  /// legacy: _feedbackTypes = [1, 3]。
  static const List<int> _feedbackTypes = [1, 3];

  final _contentController = TextEditingController();
  final _contactController = TextEditingController();
  final _companyIdController = TextEditingController();

  int? _fbType;
  bool _uploadLog = true;

  @override
  void dispose() {
    _contentController.dispose();
    _contactController.dispose();
    _companyIdController.dispose();
    super.dispose();
  }

  bool get _showCompanyId => !widget.isLogin && !widget.isPersonal;

  /// 提交禁用逻辑（legacy action_buttons_section L662-667 逐字保真）。
  bool get _submitEnabled =>
      !widget.submitting &&
      _contentController.text.isNotEmpty &&
      _fbType != null &&
      (_companyIdController.text.isNotEmpty ||
          widget.isLogin ||
          widget.isPersonal);

  String _typeLabel(AppCommonLocalizations l10n, int value) => value == 1
      ? l10n.feedbackTypeIssue
      : value == 3
          ? l10n.feedbackTypeAdvice
          : l10n.feedbackTypeHint;

  String _contentHint(AppCommonLocalizations l10n) => _fbType == 1
      ? l10n.feedbackContentHintIssue
      : _fbType == 3
          ? l10n.feedbackContentHintAdvice
          : '';

  void _submit() {
    widget.onSubmit(
      FeedbackFormData(
        fbType: _fbType!,
        description: _contentController.text,
        contact: _contactController.text,
        companyId: _companyIdController.text,
        uploadLog: _uploadLog,
      ),
    );
  }

  Widget _requiredLabel(BuildContext context, String text) {
    final shad = ShadTheme.maybeOf(context);
    final destructive =
        shad?.colorScheme.destructive ?? Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Text('*', style: TextStyle(color: destructive)),
          const SizedBox(width: 2),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppCommonLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.feedbackTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        if (_showCompanyId) ...[
          _requiredLabel(context, l10n.feedbackCompanyIdLabel),
          ShadInput(
            controller: _companyIdController,
            placeholder: Text(l10n.feedbackCompanyIdHint),
            inputFormatters: [
              FilteringTextInputFormatter(_illegalChars, allow: false),
            ],
            onChanged: (_) => setState(() {}),
          ),
        ],
        _requiredLabel(context, l10n.feedbackTypeLabel),
        ShadSelect<int>(
          placeholder: Text(l10n.feedbackTypeHint),
          options: [
            for (final type in _feedbackTypes)
              ShadOption(value: type, child: Text(_typeLabel(l10n, type))),
          ],
          selectedOptionBuilder: (context, value) =>
              Text(_typeLabel(l10n, value)),
          onChanged: (value) => setState(() => _fbType = value),
        ),
        _requiredLabel(context, l10n.feedbackContentLabel),
        ShadInput(
          controller: _contentController,
          placeholder: Text(_contentHint(l10n)),
          minLines: 5,
          maxLines: 9,
          maxLength: 300,
          inputFormatters: [
            FilteringTextInputFormatter(_illegalChars, allow: false),
          ],
          onChanged: (_) => setState(() {}),
        ),
        if (widget.attachmentArea != null) ...[
          const SizedBox(height: 12),
          widget.attachmentArea!,
        ],
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            l10n.feedbackContactLabel,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        ShadInput(
          controller: _contactController,
          placeholder: Text(l10n.feedbackContactHint),
          inputFormatters: [
            FilteringTextInputFormatter(_illegalChars, allow: false),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ShadCheckbox(
              value: _uploadLog,
              onChanged: (value) => setState(() => _uploadLog = value),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.feedbackUploadLogLabel)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ShadButton.outline(
              onPressed: widget.onCancel,
              child: Text(l10n.feedbackCancel),
            ),
            const SizedBox(width: 12),
            ShadButton(
              onPressed: _submitEnabled ? _submit : null,
              child: Text(
                widget.submitting
                    ? l10n.feedbackSubmitting
                    : l10n.feedbackSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
