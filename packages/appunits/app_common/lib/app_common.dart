/// PlanStar 应用级通用能力（ADR-0084 D4 Tier A）：用户反馈 + 应用内升级。
///
/// 两块都是「宿主无关的纯 UI + 插槽/回调出让设备与后端能力」的形态，由 lib
/// 消费时用 PlanStar 的落地实现接线：
/// - `feedback/` —— `FeedbackFormPanel`（账号化字段 `isLogin`/`isPersonal`/
///   `companyId` 已预留，见 ADR-0084 决策①）+ `FeedbackSuccessDialog` +
///   `LogFileBrowser`。文案直接读本包 gen-l10n 的 `AppCommonLocalizations`
///   （`localizations/`，镜像 appunits_core 的 `AtomicLocalizations`），不再由
///   宿主注入——宿主须在 `MaterialApp` 注册 `AppCommonLocalizations.delegate`。
/// - `upgrade/` —— `UpgradeVersionPanel`/`Host`（自绘、shadcn 统一、三桌面一致）
///   + 引擎无关契约 `UpgradeController`/`UpgradeSnapshot`/`UpgradeState` +
///   `UpgradeReleaseImages`。文案同样读本包 gen-l10n 的 `AppCommonLocalizations`
///   （比照 feedback，含 `{version}`/`{progress}` 占位符），宿主已注册同一 delegate。
///
/// 依赖路线（ADR-0083）：`sentry → stone_core → pudding → appunits → lib`；
/// 本包在 appunits 层，只被 lib 消费、不消费 lib。
library;

export 'feedback/feedback_form_panel.dart';
export 'feedback/feedback_success_dialog.dart';
export 'feedback/log_file_browser.dart';
export 'localizations/app_common_localizations.dart';
export 'upgrade/upgrade_contract.dart';
export 'upgrade/upgrade_release_images.dart';
export 'upgrade/upgrade_version_panel.dart';
