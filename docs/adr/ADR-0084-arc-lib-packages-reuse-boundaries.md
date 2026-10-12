# ADR-0084: lib↔packages 复用边界映射与特定包收尾路线

- **状态**: ACCEPTED
- **分类**: ARC
- **优先级**: P2
- **影响维度**: 认知障碍 / 上下文膨胀 / 幻觉源
- **日期**: 2026-10-12
- **来源**: lib↔packages 逐区域复用评估（用户请求「将 lib 的代码用 packages 的内容来实现，哪些值得迁入 / 直接使用」的深入调研；示例前提 = lib/theme 用 appunits_core 样式）
- **修复 commit**: 映射裁决（D1–D3/D5）docs-only 先行；**D4 Tier A（`app_common` 收尾）@ 本批**（未提交）

## 背景（Context）

### B0. 一句话

ADR-0083 把 `packages/` 治成可解析的三层 monorepo（`sentry → stone_core → pudding → appunits → lib`），但**只回答了「包自己能不能编译」，没回答「lib 该不该、能不能消费它们」**。本 ADR 逐区域裁决 lib↔packages 的复用边界：**对 PlanStar 当前形态，packages 里安全可复用项极少**——多数包对桌面 shadcn agent 工作台是**错形**（移动聊天套件 / 无影网络栈 / 下载式自更新 / grpc-gql-firebase），强行复用会 **regress**（keychain workaround、shadcn 主题）或**过度工程**（dio 重栈）。故裁决以「拒绝 / parked / 附加非替代」为主，并给出「只收尾特定包」的分级路线。

### B1. 依赖路线（承 ADR-0083，不可反向）

```
sentry ──▶ stone_core ──▶ pudding ──▶ appunits ──▶ lib（应用代码）
```

`lib/` 是终点：可依赖以下所有层，但没有任何包可依赖 `lib/`。因此「lib 用 packages」是**向下消费**（合法）；「lib 迁入 packages」是**下沉重构**（合法但需复用驱动）。

### B2. lib 当前消费现状（grep 实证，2026-10-12）

`grep -rn "package:(app_common|stone_core|appunits_core|pudding|board_panel|plan_editor)/" lib/` 只命中 **4 处，全在 `lib/ui/plan/`**：

- `lib/ui/plan/blocks/plan_block_view.dart:22` + `lib/ui/plan/blocks/plan_block_editor.dart:32` → `package:plan_editor/plan_editor.dart`（ADR-0044 接入）
- `lib/ui/plan/dataview/plan_calendar_viewer.dart:17` + `lib/ui/plan/dataview/plan_board_viewer.dart:11` → `package:board_panel/board_panel.dart`（ADR-0037 接入）

`app_common` / `stone_core` / `appunits_core` / `pudding` **既不在 root `pubspec.yaml` 的 path 依赖里、lib 也零 import = 四个纯岛**。要让 lib 消费任何一个，第一步都是往 root pubspec 加 path dep。

### B3. 各包来源与形态（决定「契合度」的根因）

- **`appunits/appunits_core`** = vendored 腾讯 **TUIKit `base_component`**（移动聊天 UI 套件）：自带一套 theme（`theme_state.dart` 717 行 / `color_scheme.dart` ~90 字段 / colors / font / radius / spacing）、一套 basic_controls（button 762 / alert_dialog 645 / action_sheet 442 / avatar 418 / toast 405 / bubble 252 / switch 253 / label 243 / badge 55）、一套 atomic_localizations（ar/en/ja/ko/zh，主文件 3120 行），外加移动平台能力（album_picker / image_uploader / permission / pip / device_info）。
- **`infras/stone_core`** = 无影(Wuying) 基础设施：重型 **dio 网络栈**（`http_manager.dart` 517 / `refresh_login_interceptor.dart` 409 / `multipart_uploader.dart` 526 / `offline_sync_service.dart` 292 / retry / cache / `response_envelope.dart` / `env_entity.dart`）+ **logger**（`sentry_logging` 副本）+ **storage**（`config_service_impl.dart` = SharedPreferences + FlutterSecureStorage + `getUmid`/`isStrongControl`/DM 监听器等无影概念）。
- **`pudding`** = grpc / gql(link) / firebase_remote_config 的 sentry 集成（ADR-0083 Q3 裁决保留的未来生态料）。
- **`appunits/app_common`** = `feedback/`（`feedback_form_panel.dart` 242 / `feedback_success_dialog.dart` 127 / `feedback_ui_labels.dart` 59 / `log_file_browser.dart` 53）+ `updater/`（`upgrade_version_panel.dart` 248 / `upgrade_release_images.dart` 99 / `upgrade_ui_labels.dart` 53）。**改写中**：入口 `app_common.dart`（16 行）仍是 plan_editor 副本、`export 'src/editor_mark.dart'` 等指向**不存在的 `src/`**（ADR-0083 已登记）；`updater/` 依赖 `package:upgrade`（`UpgradeController`/`UpgradeSnapshot`/`UpgradeState`）但 pubspec 未声明。**（→ 上述残壳/幽灵包缺口已由 D4 Tier A 于本批收尾：入口重写、`updater/`→`upgrade/` 内联引擎无关契约、声明 shadcn_ui/open_file、root path dep + lib 消费点；`feedback_ui_labels.dart`/`upgrade_ui_labels.dart` 两个数据类注入层已删除，feedback 与 upgrade 文案改由 `app_common` 自有 gen-l10n 束 `AppCommonLocalizations` 承载（镜像 `appunits_core` 的 `AtomicLocalizations`，见「验证」②），四门禁绿——本段保留为提案时的「before」快照，行数以删除前为准。）**

## 决策（Decision）

用户裁决：**战略意图 = 只收尾特定包**（不做 lib 全量迁移）、**交付物 = 先出映射 ADR/doc**（本次不动代码）。以下 D1–D5 为边界裁决，D4 为收尾路线。

### D1. lib↔packages 逐区域复用裁决表

| # | lib 区域 | packages 候选 | 裁决 | 证据锚点 |
| --- | --- | --- | --- | --- |
| 1 | `theme/`（dsw_* + shad bridge） | `appunits_core/base_component/theme` | **拒绝** | `dsw_shad_bridge.dart`(244) 把 `DswAlias` 逐字段映到 shadcn `ShadColorScheme`(12 槽)，受 `tool/contrast_check.dart` WCAG 门禁(ADR-0004) + 6 个 ADR(0002/0017/0028/0029/0036/0038) 约束；`theme_state.dart`(717)+`color_scheme.dart`(341) 是 ~90 字段**扁平聊天**调色板(`bgColorBubbleOwn`/`buttonColorHangupDefault`/`tagColorLevel1-4`)+`BaseThemeProvider extends InheritedNotifier`+SharedPreferences 持久化。替换 = 重写 lib 每处取色 + 弃 shadcn |
| 2 | `ui/primitives/feedback.dart`(43) | `app_common/feedback` | **附加非替代** | lib 是 `showFeedback()`→shad `ShadSonner` 吐司条(ADR-0020，app 唯一反馈条)；app_common 是 `FeedbackFormPanel`(242，shad-native + 宿主无关插槽 `onSubmit`/`attachmentArea`，产 `FeedbackFormData`)——**用户反馈提交表单，lib 现在没有**。但表单假设账号/企业(`companyId`/`isLogin`/`isPersonal`)，PlanStar 商用形态未定(见 production-readiness-gap) |
| 3 | `state/update_service.dart`(169)+`model/update_check.dart`(77)+`ui/primitives/update_dialog.dart`(74) | `app_common/updater` | **哲学不同** | lib = 检查 GitHub Releases latest → 弹窗 → 开浏览器手动下载(ADR-0079，`package:http`)；app_common = `package:upgrade` 的**应用内下载→解压→MD5→安装→重启**自更新 UI(`UpgradeVersionPanel`/`UpgradeVersionPanelHost`)+需一个发更新包的后端。两者不是同一层，不能直接互换 |
| 4 | `state/secret_store.dart`(83)+settings_store+prefs_store | `stone_core/storage` | **拒绝** | lib `SecureSecretStore` 带 macOS ad-hoc 签名 keychain 关键 workaround(`MacOsOptions(useDataProtectionKeyChain:false)` @ `secret_store.dart:30-32`，避开 `-34018` 启动崩，ADR-0045 PB / ADR-0049)+`InMemorySecretStore` 测试替身+`NotifyingSecretStore`；`config_service_impl.dart`(183) 用**默认** `FlutterSecureStorage`(会撞同一 `-34018`)+SharedPreferences+无影 `getUmid`/`isStrongControl`。采用会 regress keychain 修复，且持久化哲学冲突(PlanStar 用原子写 JSON + drift，非 SharedPreferences) |
| 5 | HTTP：`state/auth_session.dart:10`+`state/update_service.dart:16` | `stone_core/network` | **现在拒绝** | lib 仅 2 处简单 `package:http` GET；`stone_core/network` 是重型 dio 栈(`http_manager` 517 + `refresh_login_interceptor` 409 + retry + cache + `multipart_uploader` 526 + `offline_sync_service` 292 + `response_envelope`)，为无影后端塑形。对 PlanStar 是过度工程；**仅当 ADR-0045 形态②自建后端落地才重估** |
| 6 | （lib 无结构化日志，仅 `main.dart:122` 一处 `debugPrint`） | `stone_core/logger` | **半价值** | `stone_core/logger` 是 `sentry_logging` 副本(`logger.dart` 234 + `logging_integration.dart` 134)。但 `sentry_flutter` 未接(ADR-0083 明确另立 ADR) → 无崩溃上报的 logger 只发挥一半价值。**宜与 sentry_flutter 一起落**，不单独接 |
| 7 | `ui/primitives/*`（自绘 card/code/diff/terminal/menu/toast/reveal） | `appunits_core/base_component/basic_controls` | **拒绝** | TUIKit basic_controls 由其 `SemanticColorScheme` 主题驱动，是**平行**组件集；采用即拖入 TUIKit 主题，与 lib 全量 shadcn(ADR-0036) 冲突 |
| 8 | `host/*`（git/terminal/reveal/support_directory/project_folder_ops/profile_repository） | — | **无对应** | packages 无桌面宿主能力；`appunits_core` 的 device_info/permission/pip/album_picker/image_uploader 全是**移动**平台通道能力，桌面无用 |
| 9 | （lib 无 grpc/gql/firebase） | `pudding` | **拒绝** | root pubspec 无这三者；pudding 是 ADR-0083 Q3 裁决保留的未来生态死代码，PlanStar 当前零命中 |

### D2. 反向下沉（lib → packages）裁决

依赖路线里 lib 在顶端，**下沉只为复用或分层**。PlanStar 是单 app、无第二消费者 → **无复用驱动 → 下沉大多 YAGNI**。

反直觉点：lib 的 `secret_store.dart` 其实**优于** `stone_core/storage` 的 secure 实现（前者有 macOS keychain workaround + 测试替身 + notifying 包装，后者会撞 `-34018`）。若哪天真要统一 secure 存储，应是 **lib 的实现下沉替换 stone_core**，而非反向消费。

### D3. theme 前提专裁（回应用户的示例）

用户示例「lib/theme 用 appunits_core 样式」经证据**否决**：dsw+shadcn 与 TUIKit 是两套为不同 app 类型（桌面 agent 工作台 vs 移动聊天）塑形、互不兼容的设计系统（见 D1 行 1）。

**唯一可捞的一件**：`theme_state.dart` 里的 `ThemeColorGenerator`（~330 行纯 Dart 的 HSL 10 阶调色板生成算法，含 blue/green/red/orange 预设 + 从任意 hex 动态生成）。**仅当** PlanStar 将来要做「用户自定义强调色」（从一个 hex 生成整套 token）时才有价值；当前 dsw 是固定品牌调色板（dsh 身份），故 **YAGNI，不激活**。

### D4.「只收尾特定包」分级路线（对应用户裁决）

> 本路线的 D1–D3/D5 裁决是**记录**；分级收尾待本 ADR ACCEPTED 后另批。**Tier A（`app_common`）已于 ACCEPTED 当批执行完成**（四判据全绿，见下 ✅ 与「验证」段②）；Tier B/C/D 仍 parked / 未执行。

- **Tier A — `app_common`（PlanStar 唯一真实可消费候选）**。收尾判据（四条全绿才算 done）——**本批全绿 ✅**：
  1. **定目标角色**（用户已拍板）：
     - feedback = **去账号化**：单机形态传 `isPersonal:true`（隐藏 `companyId`/企业字段）；`onSubmit` 走**组合预填 GitHub issue 草稿 + `url_launcher` 外开浏览器**（无反馈后端，不伪造 server issueId，故不用 `FeedbackSuccessDialog`），复用 `AppMeta.issuesUrl` 与 help「报告问题」同一通道。
     - updater = **保留自绘面板 + 内联引擎无关契约**（用户裁决）：`updater/` 更名 `upgrade/`，把原属幽灵包 `package:upgrade` 的 `UpgradeController`/`UpgradeSnapshot`/`UpgradeState`（大写枚举，legacy cloudspace 逐值保真）**内联**进 `upgrade/upgrade_contract.dart`（形状由面板消费处反推，非自由设计），面板脱离幽灵包即可编译。**明确拒绝 `auto_updater`**：其为 Sparkle/WinSparkle **原生 UI**、不暴露本状态机、且**不支持 Linux**（违三桌面不变量 ADR-0003）。契约只定义状态机 + 快照值 + 编排接口，**不含**下载/解压/校验/安装实现——那是宿主「搭后端」时提供的 `UpgradeController` 具体实现。
  2. **修入口** ✅：`app_common.dart` 去掉 plan_editor 残壳（`src/editor_mark.dart` 等），改 export `feedback/` + `upgrade/` 的公开件。
  3. **声明依赖** ✅：pubspec 补 `shadcn_ui: 0.56.3`（对齐宿主 root，防 monorepo 解析漂移）+ `open_file: ^3.5.10`（LogFileBrowser 打开本地日志）；**不声明** `upgrade`（幽灵包已被内联契约取代）/ `attributed_text`（未用到）/ `auto_updater`（见判据①拒绝）。
  4. **接入验证** ✅：root `pubspec.yaml` 加 `app_common: path: packages/appunits/app_common` + lib 落**一处真实消费点**（`ui/settings/model_settings.dart` 诊断区「发送反馈」→ `showShadDialog` 承载 `FeedbackFormPanel`）+ `dart analyze` 绿（四门禁见「验证」段②）。
- **Tier B — `stone_core`**：**parked**。白纸黑字标注「暂不接 lib」；`network` 待 ADR-0045 形态②自建后端激活，`logger` 待 `sentry_flutter`（另立 ADR）激活。不强行接。
- **Tier C — `pudding`**：**parked** 生态死代码（ADR-0083 Q3），不动。
- **Tier D — `appunits_core`**：解 `GroupMember` 缺口（ADR-0083 已登记，`base_component/utils/chat_utils.dart:8`；`base_component.dart` 又 export 了 `chat_utils.dart`）使其 `dart analyze` 绿——**但明确标注 lib 不消费**（移动 / TUIKit 主题错形）。消解方式二选一：vendor TUIKit chat 模型，或从 `base_component.dart` 移除 `chat_utils` 的 export（不臆造 chat 模型）。

### D5. 备选方案与取舍

- **备选①「激进复用」**（把 lib 尽量换成 packages 内容）：**否决**。D1 证据显示会 regress（行 4 keychain）/ 冲突（行 1、7 shadcn↔TUIKit）/ 过度工程（行 5 dio 栈）。违背 repo 的 ponytail/YAGNI 律。
- **备选②「多 app 生态基座」**（把 lib 验证过的实现下沉、重塑 packages 为可复用基座、PlanStar 转消费方）：**用户未选**。记为「出现第二个 app（复用驱动）时再启」；届时 D2 的下沉才有意义。
- **备选③「维持现状不动」**：**部分采纳**——board_panel/plan_editor 已接，其余 parked；但**需本 ADR 记录边界**，否则未来 agent 会反复误判「packages 都该被 lib 复用」（这正是本 ADR 的「幻觉源」影响维度）。

## 后果（Consequences）

- **正面**：lib↔packages 边界白纸黑字，每条裁决带文件:行号 / grep 证据可复核；未来 agent 不会再误以为「packages 都该被复用」（减幻觉源）；`app_common` 收尾有了四条可执行判据；避免了激进复用导致的 keychain/shadcn regress 与 dio 过度工程。
- **负面 / 风险**：`app_common` 收尾仍需用户先定目标角色（feedback 账号假设、updater 的 `package:upgrade`+后端前提未解，非机械可决）；`stone_core`/`pudding`/`appunits_core` 将继续作为「半接线岛」存在（认知负担 / 上下文膨胀），直到未来激活或移除。
- **中性**：确立「lib 是 packages 的消费者，但只消费契合项；契合度由包的来源形态决定」这一原则，与 ADR-0083 的分层守卫（D3）互补。

## 验证（Verification）

**分两批**：① 映射裁决（D1–D3/D5）= docs-only 先行；② **D4 Tier A（`app_common` 收尾）= 本批落码**。

**① 映射（docs-only）验证**：

- `docs/adr/ADR-0084-arc-lib-packages-reuse-boundaries.md` 存在且六段齐全（背景 / 决策 / 后果 / 验证 / 关联）。
- `docs/debt-register.md` 有 ADR-0084 行（ARC / P2 / 2026-10-12 / 链接）。
- D1 表每行裁决可复核（附文件:行号或 grep 断言）。

**② Tier A 落码验证**（四判据全绿，见 D4；数字为 2026-10-12 本机现场重跑）：

- **消费现状变更**：root `pubspec.yaml` 的 path 依赖新增 `app_common`（原只有 `board_panel` + `plan_editor`）；`grep -rn "package:app_common/" lib/` 命中 `ui/settings/model_settings.dart`（原「四个纯岛」的 `app_common` 已被 lib 向下消费）。`stone_core`/`appunits_core`/`pudding` 仍为零 import 纯岛（Tier B/C/D parked）。
- **四门禁**（与 CI 同口径）：`dart format --set-exit-if-changed lib test tool spike` **0 changed** · `dart analyze --fatal-infos lib test tool spike` **0 issue** · `dart tool/check_architecture.dart` **8 recorded, 0 new** · `flutter test` **+1490 通过 / −1 失败**——唯一败 = `test/app_scope_test.dart:60` 既有 macOS `/var`↔`/private/var` 符号链接 flake（ADR-0082 已白纸黑字登记，零 `app_common`/i18n 引用，CI Linux 为绿），非本批引入。
- **`app_common` 包内**：`flutter pub get` + `dart analyze`（包目录内）均 **No issues found**（`packages/**` 不受 root format/lint 门禁，故在包内单独验）。
- **i18n（本批改由 `app_common` 自有 gen-l10n 束承载，镜像 `appunits_core` 的 `AtomicLocalizations`）**：feedback + upgrade 的全部面板文案落在 `packages/appunits/app_common/lib/l10n/app_common_{en,zh}.arb`（feedback 22 键 + upgrade 14 键 = 36；upgrade 的 `{version}`/`{progress}` 走 ARB `placeholders` 元数据 → gen-l10n 生成占位符方法），包内 `flutter gen-l10n` 生成 `AppCommonLocalizations`（`lib/localizations/`，`untranslated.json` 空），面板/弹窗**直接读 `AppCommonLocalizations.of(context)`**——原 `FeedbackUiLabels`/`UpgradeUiLabels` 数据类注入层已删除。死键一并裁掉：feedback `attachmentLabel`/`attachmentHint`（附件让给宿主 `attachmentArea` 插槽、无人渲染）、upgrade `imagesEmptyText`（面板从不引用）。**lib 只保留真正在 lib 渲染的 4 键**（`settingsFeedback`/`settingsFeedbackDesc`/`settingsFeedbackOpen` 设置行 + `feedbackIssueOpened` 提交后吐司）于 `app_en.arb`/`app_zh.arb`，走 ADR-0082 的 ARB→`gen-l10n`→`gen_tr_key` 流程（Tier A 首批曾把 13 个 feedback 表单键放进 lib ARB，本批迁回 `app_common`、lib ARB 相应删除并重生成），`l10n_parity_test` 绿。`lib/main.dart` 的 `MaterialApp.localizationsDelegates` 现以 const spread 同挂 `AppLocalizations.localizationsDelegates` + `AppCommonLocalizations.delegate`（缺后者则面板 `.of(context)` 抛），`i18n_overlay_test` 断言相应更新。

## 关联（Links）

- 代码: `lib/theme/dsw_shad_bridge.dart`、`lib/state/secret_store.dart#L30-L32`、`lib/state/update_service.dart`、`lib/ui/primitives/feedback.dart`、`lib/ui/settings/model_settings.dart`（Tier A feedback 消费点）、`packages/appunits/app_common/lib/{app_common.dart,feedback/feedback_form_panel.dart,upgrade/upgrade_contract.dart,upgrade/upgrade_version_panel.dart}`、`packages/infras/stone_core/lib/storage/config_service_impl.dart`、`packages/appunits/appunits_core/lib/base_component/theme/theme_state.dart`
- 关联 ADR: **ADR-0083**（packages 治理与 sentry 集成路线——本 ADR 是其「lib 消费侧」续篇）、ADR-0044 / ADR-0037（plan_editor / board_panel 已消费先例）、ADR-0079（lib 侧升级脑 = GitHub Releases 检查）、ADR-0045（生产化总纲：stone_core 未来激活归属 + secret_store PB）、ADR-0049（keychain 拒答不能杀启动 = secret_store workaround 出处）、ADR-0036（shadcn 采纳 = theme 拒绝 TUIKit 的依据）、ADR-0020（app 唯一反馈吐司条）、ADR-0003（三桌面不变量 = `auto_updater` 不支持 Linux 的拒绝依据）、ADR-0082（i18n gen-l10n / ARB 唯一源 = lib 侧 4 键落地流程；`app_common` 自有 gen-l10n 束 `AppCommonLocalizations` 另镜像 `appunits_core`，见「验证」② + `app_scope_test` 既有 flake 登记处）、ADR-0001（vendored 入库例外）
