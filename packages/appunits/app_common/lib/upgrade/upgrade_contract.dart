/// 升级编排契约（引擎无关）——ADR-0084 D4 Tier A。
///
/// 这些类型原属 cloudspace 内部包 `package:upgrade`（coreops/upgrade），未随
/// app_common vendored（幽灵包，同 ADR-0083 内联的 `stone_domain`/`logger_core`）。
/// 按用户裁决（保留自绘面板 + 内联引擎无关契约），在此定义 `UpgradeVersionPanel`
/// 消费的最小契约形状，使面板脱离幽灵包即可编译——形状逐点由面板消费处反推，
/// 非自由设计。
///
/// 边界：本文件只定义**契约**（状态机 + 快照值类型 + 编排接口），不含任何
/// 下载/解压/校验/安装的实现。那是宿主在「搭后端」时提供的 `UpgradeController`
/// 具体实现（GitHub-Releases 下载式 / 自建更新服务 / 桌面原生引擎皆可），故
/// app_common 不绑定任何升级引擎。`auto_updater`（Sparkle/WinSparkle 原生 UI）
/// 不暴露本状态机、且不支持 Linux，与此面板不兼容，见 ADR-0084 D4。
library;

/// 升级状态机（legacy cloudspace `UpgradeState` 逐值保真；大写命名随之保留，
/// 故本包 analysis_options 关闭 `constant_identifier_names`）。
enum UpgradeState {
  /// 已是最新版本。
  LATEST,

  /// 发现新版本、待开始下载。
  UPDATE,

  /// 升级包下载中（`UpgradeSnapshot.progress` 有意义）。
  DOWNLOADING,

  /// 下载完成、解压升级包中。
  UNZIP,

  /// 解压完成、校验安装包中（MD5）。
  CHECKMD5,

  /// 校验通过、待安装（面板显示「重启并安装」）。
  DONE,

  /// 任一阶段失败（`UpgradeSnapshot.errorMessage` 有意义）。
  FAILED,
}

/// 命中的可升级版本。
class UpgradeCheck {
  const UpgradeCheck({required this.version});

  /// 版本号（legacy 形如 '7.1.0-beta'；面板展示时经 `UpgradeVersionPanel`
  /// 的 `_displayVersion` 截去构建后缀）。
  final String version;
}

/// 升级编排快照（值类型）：`UpgradeController.watch()` 的事件、
/// `UpgradeController.snapshot` 的当前值。面板纯由此驱动，不含行为。
class UpgradeSnapshot {
  const UpgradeSnapshot({
    required this.state,
    this.progress = '',
    this.check,
    this.errorMessage,
  });

  /// 当前状态。
  final UpgradeState state;

  /// 下载进度文本（legacy 形如 '37%'；面板 `_progressValue()` 解析为 0..1，
  /// 非法输入回退 0）。
  final String progress;

  /// 命中的新版本（`LATEST` 时为 null）。
  final UpgradeCheck? check;

  /// 失败原因（`FAILED` 时非空）。
  final String? errorMessage;
}

/// 升级编排接口（引擎无关）。
///
/// 宿主在「搭后端」时提供具体实现；`UpgradeVersionPanelHost` 只依赖此接口
/// （订阅 `watch()`、把动作转发到 `startDownload`/`install`/`cancel`）。
abstract class UpgradeController {
  /// 当前快照（`UpgradeVersionPanelHost` 的 `StreamBuilder.initialData`）。
  UpgradeSnapshot get snapshot;

  /// 快照事件流（面板 `StreamBuilder` 订阅）。
  Stream<UpgradeSnapshot> watch();

  /// 开始下载升级包。返回 `void`：面板把本方法直接当 `onRetry` 的
  /// `VoidCallback` 传（`UpgradeVersionPanel.onRetry`），签名必须是 `void Function()`。
  void startDownload();

  /// 安装已下载并校验通过的升级包；返回是否成功——宿主据此决定是否退出/重启
  /// 进程（legacy `installAndExitApp` 的宿主段）。
  Future<bool> install();

  /// 取消当前升级流程（下载/解压/校验）。
  Future<void> cancel();
}
