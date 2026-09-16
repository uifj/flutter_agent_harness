# ADR-0006: 设置面重构——全屏设置视图 + 底部级联快捷菜单 + 用户 Profile（预留 Supabase）

- **状态**: RESOLVED（S1–S5 已落 develop；S5 Windows 真机走查通过——快捷菜单渲染 + 实时值正确、应用启动无异常，全屏设置由 settings_test 覆盖；macOS VoiceOver 待用户自测）
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 生产功能（设置面呈现）· 认知障碍（overlay↔页面两套心智）· 外部协作（Supabase，未来）
- **日期**: 2026-09-16
- **来源**: 用户决策（保留 starkins 的级联快捷菜单"不进设置页即可改偏好"；设置页参考 starkins 走全屏视图；保留左下角头像，真实 profile 后续对接 Supabase，当前用 mock 并预留接口）
- **修复 commit**: S1 76ceddd · S2 acf5991 · S3 0e0ce99 · S4 6fa85d6 · S5 真机走查通过（本 docs commit）
- **关联**: 取代 [ADR-0005](ADR-0005-arc-starkins-settings-rebuild.md) 守卫 #4 的"沿用 overlay 单层、不引入路由"呈现决定（改为全屏视图，但**仍不引入 Navigator 路由**）；复用 ADR-0005 的外观节与 `AppSettings`

## 背景（Context）

三件事，证据均为 `文件:行号`：

1. **设置呈现现状 = 遮罩浮层**。`main.dart:230-247` `_overlay(doc)` 在 `_settingsOpen` 时返回一个 `Stack`：底层 `FreeWindowLayer`，上层 `SettingsPanel`；`SettingsPanel`（`model_settings.dart:437-456`）是 `BackdropFilter` 遮罩 + 居中 800px 卡片（`width:800`、`height:constraints.maxHeight.clamp(0,800)-48`）。用户要求改为**全屏视图**。
2. **starkins 的级联快捷菜单**（`starkins_app/lib/workspace/presentation/widgets/settings_panel.dart:29-99`）：`SettingsPanelHost` 用 `OverlayEntry + LayerLink` 在触发点弹出一个级联菜单，含 语言/主题/字体/字号/对话宽度 等偏好**即时生效**（`appPreferencesProvider`），并有"设置"项 `Navigator.push(MaterialPageRoute(SettingsPage))` 打开全屏页（`settings_panel.dart:79-84`）。用户要求**保留这种"不进设置页即可改偏好"的快捷入口**。
3. **左下角头像 + 用户信息**（`starkins_app/.../left_sidebar.dart:636-712`）：`_Avatar` 是硬编码 'W' 的装饰块，name/email 是写死串（'WB02410627'/'团队版'）；项目有 `UserProfile` 模型（`domain/models/user_profile.dart:12-49`）+ `userProfileProvider`，但侧栏不读它。**agent_harness 当前无任何 user/account/auth 概念**（`grep -rniE "userprofile|account|avatar|login|auth" lib/` 仅命中 git author / HTTP auth header / StreamSubscription，均无关）。用户要求：保留头像，真实 profile 后续接 **Supabase**，当前用 **mock**，并**预留 Supabase 接口**。

不变量约束（AGENTS §3 / workflow §2）：单窗口、**无路由表、无 `Navigator.push` 页面路由**；riverpod import 仅限 `main.dart` + `state/app_providers.dart`；`lib/model/` 纯 Dart 不碰 flutter。

## 决策（Decision）

### 决策 1：设置改为「全屏视图」，但用状态切换、**不引入 Navigator 路由**

「全屏页面」≠「Navigator 路由」。用 `_settingsOpen` 状态把 `home` 的 body 从「frame」整体切换成「全屏 SettingsPage」，而不是 `Navigator.push` 一条路由。

- 呈现：去掉遮罩 + 居中 800px 卡片 + `BackdropFilter` blur，`SettingsPage` 铺满视口，沿用其既有「nav-rail + 内容」布局（ADR-0005 已把它做成卡片分组），顶部/侧栏给一个「返回应用」入口（关闭 = `_settingsOpen=false`，回到 frame）。
- **为何不走 starkins 的 `Navigator.push`**：那会引入页面路由，逆反"无路由"不变量，需另立 ADR 推翻 workflow §2 / AGENTS §3，并牵动全部 widget 测试的 `Navigator` 依赖——为一个"看起来是页面"的效果代价过大。**否决 B2（真路由）**，采 **B1（状态驱动全屏视图）**。
- 影响面：`main.dart` 挂载点（overlay→body 切换）、`SettingsPanel` 外壳（去遮罩/铺满/加返回）。`SettingsPanel` 的对外 API（settings/onSave/onClose/…）不变。

### 决策 2：新增底部「级联快捷菜单」，偏好即时生效，不进设置页

在 sidebar 底部（头像/设置按钮处）挂一个弹层（`OverlayEntry`/`CompositedTransformFollower`，与现有 overlay 机制同源，**不是路由**），提供 语言 / 主题 /（对话）字号 / 对话宽度 等**即时生效**的偏好切换，并含一个「打开设置」项切到决策 1 的全屏视图。

- 即时写入：偏好项走 `scope.save(settings.copyWith(...))`；这些字段（theme/locale/appearance）**不触发 runtime 重建**（`AppSettings.requiresRuntimeRestart` 不含它们），故快捷写是廉价的。
- 与设置页**共享同一 `AppSettings` 真值源**（不新建内存偏好态，延续 ADR-0005 守卫 #5）。
- 取舍：starkins 菜单里的 升级/帮助/关于/退出登录 **不带入**（本项目无账号/订阅子系统）；偏好项只做本项目**有真实字段支撑**的（theme/locale/fontSize/conversationWidth 等，见 `AppSettings`）。

### 决策 3：引入 `UserProfile` 领域模型 + `ProfileRepository` 抽象（Mock 现用，Supabase 预留）

- `lib/model/user_profile.dart`：纯 Dart 领域模型（displayName、email、avatarColorIndex/initial、subscription 等，字段对齐 starkins 但按本项目需要裁剪）。
- `lib/host/profile_repository.dart`：`abstract class ProfileRepository { Future<UserProfile?> fetchProfile(); }` + `MockProfileRepository`（返回写死的 mock，**当前使用**）。
- **Supabase 预留**：接口即接缝——后续 `SupabaseProfileRepository implements ProfileRepository`（读某 auth 用户对应的 profile 表）。本 ADR 记录预留的对接信息（表/字段、鉴权来源），但**当前不引入 `supabase_flutter` 依赖、不写连接代码**（引入该依赖时需另立 DEP ADR）。`ProfileRepository` 的实现选择点集中在 `app_providers.dart`（riverpod 边界内），一处 override 即可从 Mock 切到 Supabase。
- 侧栏头像读 `profileProvider`（在 `app_providers.dart`，注解模式），无 profile 时回退到首字母占位。

## 分阶段落地（每阶段过 analyze/format/test 再 commit）

- **S1 Profile 子系统**（✅ 76ceddd）：`model/user_profile.dart`（纯 Dart 值对象 + 派生 initial）+ `host/profile_repository.dart`（`ProfileRepository` 接口 + `MockProfileRepository`，Supabase 接缝以文档预留）+ `app_providers` 的 `profileRepository`/`userProfile`（FutureProvider，`.g.dart` 已生成）+ `user_profile_test`。
- **S2 侧栏头像**（✅ acf5991）：`main` 读 `userProfileProvider.value` 下传；`Sidebar._footer` 加 `_UserAvatar`（initial + dsw 调色板按 avatarColorIndex，无 profile 时首字母占位）+ 名字/邮箱；设置按钮保留。
- **S3 级联快捷菜单**（✅ 0e0ce99）：`ui/settings/widgets/settings_quick_menu.dart`——`OverlayEntry`+`LayerLink` 弹层（非路由），Theme/Language/Conversation width/Text size 即时写 `scope.save` + "打开设置"；`settings_quick_menu_test` 钉住实时写。
- **S4 全屏设置视图**（✅ 6fa85d6）：`main` 把 body 从 overlay Stack 换成 `_settingsOpen ? _settingsPage : AppFrame`（状态切换、无路由）；`SettingsPanel` 去 `BackdropFilter` 遮罩 + 居中 800 卡片，改 `ColoredBox`+`SafeArea` 铺满；`settings_test`/`models_endpoint_test` 无需改（不依赖遮罩）。
- **S5 真机走查**（✅）：Windows `flutter run -d windows` 启动无异常；快捷菜单渲染正确（四组偏好 + 当前值高亮 + Open settings，暗色）；头像行为菜单锚点存在；全屏设置由 `settings_test` 覆盖。

## 后果（Consequences）

- **正面**：设置体验对齐 starkins（全屏 + 快捷菜单），偏好即时可改；Profile 有清晰的数据源抽象，Supabase 对接只需换一个 `ProfileRepository` 实现，不动 UI。
- **风险/成本**：S4 改设置呈现，`settings_test` 的遮罩/`FocusScope`/Escape 相关断言要重做；快捷菜单与设置页两处编辑同一 `AppSettings`，须保证并发写不打架（都走 `scope.save`，单一真值源）。
- **中性**：不引入 Navigator 路由 → 无路由不变量保持；不引入 Supabase 依赖 → 依赖面暂不变；ADR-0005 的外观节/控件全部复用。

## 验证（Verification）

- 无新增 `Navigator.push`（`grep -rn "Navigator.push" lib/ui/` 仍为空）；riverpod import 仍限 `main.dart`+`app_providers.dart`；`lib/model/user_profile.dart` 不 import flutter。
- 快捷菜单改主题/语言 → 全局即时生效（复用 `settingsDocument` 读缝）；"打开设置" → 全屏视图铺满、无遮罩残留、可返回。
- 头像在 mock profile 下显示 mock 数据；`ProfileRepository` 换成假实现时 UI 不改。
- 每阶段 commit 前：analyze 零告警、format 自有码零 diff、test 相对基线（663 通过 / 13 既有 Windows-only 失败）零新增。

## 关联（Links）

- 代码：`lib/main.dart`、`lib/ui/settings/model_settings.dart`、`lib/ui/sidebar/sidebar.dart`、`lib/model/user_profile.dart`(新)、`lib/host/profile_repository.dart`(新)、`lib/state/app_providers.dart`
- 参考：`starkins_app/.../settings_panel.dart`、`.../left_sidebar.dart`、`.../domain/models/user_profile.dart`
- 关联 ADR：ADR-0005（外观节/`AppSettings`，本 ADR 取代其守卫 #4 的呈现选择）
