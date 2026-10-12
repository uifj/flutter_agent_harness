/// 升级 UI 文案（默认中文；宿主整体替换实现 i18n）。
///
/// legacy 文案经 applic.intl(key) 取自宿主语言包（upgrade.* / forceupgrade.*），
/// 通用组件不绑定任何 app 的 intl 体系，改为数据类注入。
/// 含版本/进度参数的条目使用 `{version}` / `{progress}` 占位符。
library;

class UpgradeUiLabels {
  const UpgradeUiLabels({
    this.titleUpgrade = '发现新版本',
    this.titleLatest = '当前版本 {version}',
    this.tipDownloading = '新版本 {version} 正在下载',
    this.tipDownloaded = '新版本 {version} 已就绪，重启后完成升级',
    this.tipForceDownloading = '重要更新 {version} 正在下载，完成后需立即升级',
    this.tipForceDownloaded = '重要更新 {version} 已就绪，需立即升级',
    this.downloadingText = '下载中 {progress}',
    this.unzipText = '正在解压升级包…',
    this.checkMd5Text = '正在校验安装包…',
    this.downloadedText = '下载完成',
    this.downloadFailedText = '下载失败，请重试',
    this.buttonInstall = '重启并安装',
    this.buttonRetry = '重新下载',
    this.buttonCancel = '取消',
    this.imagesEmptyText = '数据获取失败，请稍后再试',
  });

  final String titleUpgrade;
  final String titleLatest;
  final String tipDownloading;
  final String tipDownloaded;
  final String tipForceDownloading;
  final String tipForceDownloaded;
  final String downloadingText;
  final String unzipText;
  final String checkMd5Text;
  final String downloadedText;
  final String downloadFailedText;
  final String buttonInstall;
  final String buttonRetry;
  final String buttonCancel;
  final String imagesEmptyText;

  /// 填充 `{version}` / `{progress}` 占位符。
  static String fill(String template, {String? version, String? progress}) {
    var result = template;
    if (version != null) {
      // 与 legacy 一致：展示号截去构建后缀（'7.1.0-beta' → '7.1.0'）。
      result = result.replaceAll('{version}', version.split('-')[0]);
    }
    if (progress != null) result = result.replaceAll('{progress}', progress);
    return result;
  }
}
