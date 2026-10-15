/// 升级版本面板（legacy: cloudspace versionInfo.dart 的通用化重写）。
///
/// 拆为两层：
/// - [UpgradeVersionPanel]：纯展示（快照驱动），标题/提示/截图区/进度条/
///   动作按钮的状态映射逐段保真 legacy（tipText L493-508、
///   getUpgradeTitleTip L510-524、按钮三分支 L654-704、强更可见性 L650-653）；
/// - [UpgradeVersionPanelHost]：绑定 coreops/upgrade 的 [UpgradeController]
///   （订阅 watch()，动作转发 startDownload/cancel/install）。
///
/// 去宿主化：MultiWindowManager 多窗口、installAndExitApp 退出进程、
/// bugle 灰度标记均属宿主职责，经回调出让。
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../localizations/app_common_localizations.dart';
import './upgrade_contract.dart';

/// 纯展示升级面板。
class UpgradeVersionPanel extends StatelessWidget {
  const UpgradeVersionPanel({
    super.key,
    required this.snapshot,
    this.isForce = false,
    this.releaseContent,
    this.onInstall,
    this.onRetry,
    this.onCancel,
  });

  /// 升级编排快照（[UpgradeController.snapshot] / watch() 事件）。
  final UpgradeSnapshot snapshot;

  /// 强制升级：下载期间隐藏取消按钮（legacy L650-653 可见性语义）。
  final bool isForce;

  /// 发布说明内容区（通常为 [UpgradeReleaseImages]）。
  final Widget? releaseContent;

  final VoidCallback? onInstall;
  final VoidCallback? onRetry;
  final VoidCallback? onCancel;

  String get _version => snapshot.check?.version ?? '';

  /// 展示号截去构建后缀（'7.1.0-beta' → '7.1.0'，与 legacy `UpgradeUiLabels.fill`
  /// 同义）；填入 `AppCommonLocalizations` 的 `{version}` 占位符。
  String get _displayVersion => _version.split('-')[0];

  /// 提示文案（legacy: tipText L493-508）。
  String _tipText(AppCommonLocalizations l10n) {
    return switch (snapshot.state) {
      UpgradeState.DOWNLOADING ||
      UpgradeState.UPDATE => l10n.upgradeDownloadingText(snapshot.progress),
      UpgradeState.UNZIP => l10n.upgradeUnzipText,
      UpgradeState.CHECKMD5 => l10n.upgradeCheckMd5Text,
      UpgradeState.FAILED =>
        snapshot.errorMessage ?? l10n.upgradeDownloadFailedText,
      _ => l10n.upgradeDownloadedText,
    };
  }

  /// 标题下提示（legacy: getUpgradeTitleTip L510-524）。
  String _titleTip(AppCommonLocalizations l10n) {
    final done = snapshot.state == UpgradeState.DONE;
    return isForce
        ? (done
              ? l10n.upgradeTipForceDownloaded(_displayVersion)
              : l10n.upgradeTipForceDownloading(_displayVersion))
        : (done
              ? l10n.upgradeTipDownloaded(_displayVersion)
              : l10n.upgradeTipDownloading(_displayVersion));
  }

  /// 进度值：'37%' → 0.37；非法输入回退 0（legacy int.parse 会直接崩溃）。
  double _progressValue() {
    final parsed = int.tryParse(snapshot.progress.replaceAll('%', '').trim());
    return ((parsed ?? 0) / 100).clamp(0.0, 1.0);
  }

  /// 按钮三分支（legacy: onTap L654-704）。
  (String, VoidCallback?) _action(AppCommonLocalizations l10n) {
    return switch (snapshot.state) {
      UpgradeState.DONE => (l10n.upgradeButtonInstall, onInstall),
      UpgradeState.FAILED => (l10n.upgradeButtonRetry, onRetry),
      _ => (l10n.upgradeButtonCancel, onCancel),
    };
  }

  /// 强更时仅 DONE/FAILED 显示按钮（legacy L650-653）。
  bool get _actionVisible =>
      !isForce ||
      snapshot.state == UpgradeState.DONE ||
      snapshot.state == UpgradeState.FAILED;

  @override
  Widget build(BuildContext context) {
    final l10n = AppCommonLocalizations.of(context);
    final shad = ShadTheme.maybeOf(context);
    final theme = Theme.of(context);
    final foreground =
        shad?.colorScheme.foreground ?? theme.colorScheme.onSurface;
    final destructive =
        shad?.colorScheme.destructive ?? theme.colorScheme.error;
    final primary = shad?.colorScheme.primary ?? theme.colorScheme.primary;
    final track =
        shad?.colorScheme.accent ?? theme.colorScheme.surfaceContainerHighest;
    final failed = snapshot.state == UpgradeState.FAILED;
    final (actionLabel, actionCallback) = _action(l10n);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            snapshot.state == UpgradeState.LATEST
                ? l10n.upgradeTitleLatest(_displayVersion)
                : l10n.upgradeTitleUpgrade,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: foreground,
            ),
          ),
          if (snapshot.state != UpgradeState.LATEST) ...[
            const SizedBox(height: 10),
            Text(_titleTip(l10n), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: releaseContent ?? const SizedBox.expand(),
            ),
          ),
          if (snapshot.state != UpgradeState.LATEST) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tipText(l10n),
                      style: TextStyle(
                        color: failed ? destructive : foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: SizedBox(
                        height: 8,
                        width: 200,
                        child: LinearProgressIndicator(
                          value: _progressValue(),
                          backgroundColor: track,
                          valueColor: AlwaysStoppedAnimation<Color>(primary),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_actionVisible)
                  ShadButton(
                    onPressed: actionCallback,
                    child: Text(actionLabel),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 绑定 [UpgradeController] 的面板宿主。
class UpgradeVersionPanelHost extends StatefulWidget {
  const UpgradeVersionPanelHost({
    super.key,
    required this.controller,
    this.isForce = false,
    this.autoStart = true,
    this.releaseContent,
    this.onInstallRequested,
    this.onCancelled,
  });

  final UpgradeController controller;
  final bool isForce;

  /// 挂载即开始下载（legacy: VersionInfo initState → updateVersion）。
  final bool autoStart;

  final Widget? releaseContent;

  /// 安装完成后的宿主收尾（退出进程/关窗，legacy installAndExitApp 的宿主段）。
  final void Function(bool installed)? onInstallRequested;

  /// 取消后的宿主收尾（关窗，legacy callback）。
  final VoidCallback? onCancelled;

  @override
  State<UpgradeVersionPanelHost> createState() =>
      _UpgradeVersionPanelHostState();
}

class _UpgradeVersionPanelHostState extends State<UpgradeVersionPanelHost> {
  @override
  void initState() {
    super.initState();
    if (widget.autoStart) widget.controller.startDownload();
  }

  Future<void> _install() async {
    final ok = await widget.controller.install();
    widget.onInstallRequested?.call(ok);
  }

  Future<void> _cancel() async {
    await widget.controller.cancel();
    widget.onCancelled?.call();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UpgradeSnapshot>(
      stream: widget.controller.watch(),
      initialData: widget.controller.snapshot,
      builder: (context, async) {
        return UpgradeVersionPanel(
          snapshot: async.data ?? widget.controller.snapshot,
          isForce: widget.isForce,
          releaseContent: widget.releaseContent,
          onInstall: _install,
          onRetry: widget.controller.startDownload,
          onCancel: _cancel,
        );
      },
    );
  }
}
