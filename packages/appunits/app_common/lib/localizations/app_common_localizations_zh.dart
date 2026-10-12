// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_common_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppCommonLocalizationsZh extends AppCommonLocalizations {
  AppCommonLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get feedbackTitle => '问题反馈与建议';

  @override
  String get feedbackTypeLabel => '反馈类型';

  @override
  String get feedbackTypeHint => '请选择反馈类型';

  @override
  String get feedbackTypeIssue => '问题反馈';

  @override
  String get feedbackTypeAdvice => '产品建议';

  @override
  String get feedbackContentLabel => '问题描述';

  @override
  String get feedbackContentHintIssue => '请描述遇到的问题、发生时间及复现步骤';

  @override
  String get feedbackContentHintAdvice => '请描述你的建议';

  @override
  String get feedbackCompanyIdLabel => '企业 ID';

  @override
  String get feedbackCompanyIdHint => '请输入企业 ID';

  @override
  String get feedbackContactLabel => '联系方式（选填）';

  @override
  String get feedbackContactHint => '请输入邮箱或手机号，便于我们联系你';

  @override
  String get feedbackUploadLogLabel => '在反馈中附上应用版本与平台信息';

  @override
  String get feedbackSubmit => '提交';

  @override
  String get feedbackCancel => '取消';

  @override
  String get feedbackSubmitting => '提交中…';

  @override
  String get feedbackSuccessTitle => '提交成功';

  @override
  String get feedbackSuccessTip => '请提供此反馈 ID 给客服人员，我们将尽快为你处理。';

  @override
  String get feedbackSuccessIdCaption => '反馈 ID';

  @override
  String get feedbackCopy => '复制';

  @override
  String get feedbackCopied => '已复制';

  @override
  String get feedbackConfirm => '知道了';

  @override
  String get upgradeTitleUpgrade => '发现新版本';

  @override
  String upgradeTitleLatest(String version) {
    return '当前版本 $version';
  }

  @override
  String upgradeTipDownloading(String version) {
    return '新版本 $version 正在下载';
  }

  @override
  String upgradeTipDownloaded(String version) {
    return '新版本 $version 已就绪，重启后完成升级';
  }

  @override
  String upgradeTipForceDownloading(String version) {
    return '重要更新 $version 正在下载，完成后需立即升级';
  }

  @override
  String upgradeTipForceDownloaded(String version) {
    return '重要更新 $version 已就绪，需立即升级';
  }

  @override
  String upgradeDownloadingText(String progress) {
    return '下载中 $progress';
  }

  @override
  String get upgradeUnzipText => '正在解压升级包…';

  @override
  String get upgradeCheckMd5Text => '正在校验安装包…';

  @override
  String get upgradeDownloadedText => '下载完成';

  @override
  String get upgradeDownloadFailedText => '下载失败，请重试';

  @override
  String get upgradeButtonInstall => '重启并安装';

  @override
  String get upgradeButtonRetry => '重新下载';

  @override
  String get upgradeButtonCancel => '取消';
}
