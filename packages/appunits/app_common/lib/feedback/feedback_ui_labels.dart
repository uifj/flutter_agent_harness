/// 用户反馈 UI 文案（默认中文；宿主整体替换实现 i18n）。
///
/// legacy 文案来自 ComponentsLocalizations（feedback* / useradvice* 键），
/// 通用组件不绑定宿主 intl 体系，改为数据类注入。
library;

class FeedbackUiLabels {
  const FeedbackUiLabels({
    this.title = '问题反馈与建议',
    this.typeLabel = '反馈类型',
    this.typeHint = '请选择反馈类型',
    this.typeIssue = '问题反馈',
    this.typeAdvice = '产品建议',
    this.contentLabel = '问题描述',
    this.contentHintIssue = '请描述遇到的问题、发生时间及复现步骤',
    this.contentHintAdvice = '请描述你的建议',
    this.companyIdLabel = '企业 ID',
    this.companyIdHint = '请输入企业 ID',
    this.contactLabel = '联系方式',
    this.contactHint = '请输入邮箱或手机号，便于我们联系你',
    this.uploadLogLabel = '同时上传本地日志（有助于定位问题）',
    this.attachmentLabel = '附件',
    this.attachmentHint = '最多 3 张图片',
    this.submitText = '提交',
    this.cancelText = '取消',
    this.submittingText = '正在提交，请稍候…',
    this.successTitle = '提交成功',
    this.successTip = '请提供此反馈 ID 给客服人员，我们将尽快为你处理。',
    this.successIdCaption = '反馈 ID',
    this.copyText = '复制',
    this.copiedText = '已复制',
    this.confirmText = '知道了',
  });

  final String title;
  final String typeLabel;
  final String typeHint;
  final String typeIssue;
  final String typeAdvice;
  final String contentLabel;
  final String contentHintIssue;
  final String contentHintAdvice;
  final String companyIdLabel;
  final String companyIdHint;
  final String contactLabel;
  final String contactHint;
  final String uploadLogLabel;
  final String attachmentLabel;
  final String attachmentHint;
  final String submitText;
  final String cancelText;
  final String submittingText;
  final String successTitle;
  final String successTip;
  final String successIdCaption;
  final String copyText;
  final String copiedText;
  final String confirmText;
}
