# ADR-0005: 以 starkins 设置页为蓝本重建 agent_harness 设置界面（重接本项目栈）

- **状态**: IN-PROGRESS（S1–S4 已落 develop；S5 真机走查待完成）
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 生产功能（设置面）· 认知障碍（两套设置并存风险）
- **日期**: 2026-09-16
- **来源**: 用户决策（照搬 starkins 设置页的布局/组件，融合本项目现有设置功能，用本项目 dsw 配色 + 自研 i18n，且符合现有架构；对话宽度入 `AppSettings`）
- **修复 commit**: S1 c56bb02 · S2 a59bcdc · S3 f6c074c · S4 07ead77（S5 待补）

## 背景（Context）

用户要求把 `starkins_app` 的设置页布局与组件照搬进 `agent_harness`，同时：① 用本项目 `DswAlias` 配色（不读 ShadTheme 配色）、② 自研 `context.tr` 双字典（不留硬编码中文）、③ 符合本项目单窗口/无路由/overlay 架构（不引入 `Navigator.push` 全屏路由）、④ 把本项目**现有**设置功能（模型/MCP/Skills/工作区/工作台，现居 `lib/ui/settings/model_settings.dart` ~2155 行）**融进**这一整页。分析见 [starkins-settings-migration-analysis.md](starkins-settings-migration-analysis.md)。

冲突点（故须先立本 ADR）：starkins 原页用 `ShadTheme.of().colorScheme` 取色、硬编码中文、`Navigator.push` 全屏页、`Notifier<AppPreferences>` 内存态、含本项目没有的账号/语音/意识等分区。照搬即破坏本项目三条不变量（见 AGENTS §3）。

## 决策（Decision）

**借 starkins 的"形"（分组 nav-rail + 卡片/行/下拉/开关的版式），落本项目的"实"（数据/配色/文案/持久化全走现有栈），把现有 5 节功能并入其中，而不是并存两套。**

映射规则（红线守卫，逐条可 grep 自检）：
1. 取色：starkins 的 `ShadTheme.of(context).colorScheme.X` → 一律 `context.dsw.Y`（`foreground→labelPrimary`、`mutedForeground→labelTertiary/labelCaption`、`border→borderL2`、`card→bgLayer1`、`muted→sidebarFill` 等，与 `dsw_shad_bridge` 表一致）。**不得** `import` shad 读调色板。
2. 字体/字号：starkins 的裸 `TextStyle(fontSize:..)` → 本项目 `DswType` 刻度（缺失档加进 alias 层，别散写数字）。
3. 文案：starkins 硬编码中文 → `context.tr(key)`，`en/zh` 双字典同键新增（键数不写死，见 workflow §3）。
4. 呈现面：不引入路由。starkins"全屏页"= 本项目现有 overlay `SettingsPanel` 的**放大版**（沿用 overlay/scope，不 `Navigator.push` 新页面）。starkins 的 quick-popup 与 全屏页**二选一保留 overlay 单层**（本项目已有一层）。
5. 状态/持久化：新偏好一律进 `AppSettings`（`SettingsStore` 原子落盘），read 走 `settingsDocument` provider；**不**新建 `Notifier<AppPreferences>` 内存态（与本项目持久化模型并存=第二个真值源）。
6. 分区取舍：只保留本项目**有真实数据/行为可接**的节（外观偏好、模型、MCP/Skills、工作区、工作台、快捷键占位可留空但不编账号/语音/意识等无子系统支撑的节）。starkins 的"个人资料/更新/语音/意识/安全/实验"等 **不带入**（本项目无对应能力）。

## 分阶段落地（每阶段过 analyze/format/test 再 commit）

- **S1 数据层**（✅ c56bb02）：`AppSettings` 扩 `AppFontFamily`/`AppFontSize`/`AppConversationWidth`/`AppInterfaceStyle`/`AppPreviewMode`/`bool expandToolCalls`/`bool promptSuggestions`（枚举 + toJson/fromJson/copyWith/==/hashCode），补序列化往返测试；`SettingsStore` 通用往返无需改动。
- **S2 控件层**（✅ a59bcdc）：审计后**塌缩为一个 `SettingsCard` 分组框**。本项目设置面已自带 starkins 控件的 dsw 重接版——`_SettingCellRow`（= SettingRow+SettingSelect 的下拉胶囊）、`_SwitchRow`/`_Switch`（= SettingToggle，走 `DswHoverTap` 已键盘可达）、`_heading`（= SettingsPageTitle）。重复实现即第二真值源（守卫 #6），故只补项目缺的那件：圆角描边卡片框（沿用 `_providerRowCard` 的 borderL2/radius12 描边语言，非 starkins 的填充卡）。
- **S3 版面层**（✅ f6c074c）：nav 增「外观」节（5 下拉 + 2 开关，全用既有控件），并把「常规」节的主题/语言行包进 `SettingsCard`——starkins 的卡片分组"形"落地；en/zh 双字典同键补齐；仍 overlay 单层、无路由。默认节仍为「常规」，`find.text('Follow system')` 仍 2 个（既有测试不动）。
- **S4 接线**（✅ 部分 07ead77）：`conversationWidth` + `expandToolCalls` 经新的 `AppearanceScope`（WorkbenchPrefsScope 式 InheritedWidget，避免 riverpod 渗入 UI）在 `main` 挂载并驱动 chat_view/composer/审批·计划卡同步加宽、以及 ToolCard 初次展开。**未接线（仅持久化意图，另立后续）**：`previewMode`（需"生成文件预览流"规格，且"新窗口"要多窗口支持）、正文字体族/字号、`interfaceStyle` 皮肤（需各自 DswAlias 调色板）。无 scope 时各消费方回退到旧默认（748、折叠），既有测试零扰动。
- **S5 校验**（⏳）：Windows `flutter run -d windows` 人眼走查（外观节呈现、加宽生效、卡片分组观感）+ `contrast_check` 不因新色回退。

## 后果（Consequences）

- **正面**：统一为"一页"，功能全保留且新增外观项持久化生效；不破坏三条不变量。
- **风险**：`model_settings.dart` 大改（布局 + 融入 starkins 版式），需逐节回归；字体族/字号/界面风格若要真生效触及主题系统，可能拆成后续 ADR；工作量按 S1-S5 分多轮。
- **中性**：riverpod/shad 迁移与 A1 无障碍成果不受影响；overlay→overlay，无路由。

## 验证（Verification）

- `grep -rn "ShadTheme.of" lib/ui/settings/` 空（配色走 dsw）；新分区内 `grep` 无裸中文字面量（全 `tr`）；`flutter test` 全绿（含新增序列化/provider 测试）；en/zh 键集对齐；`contrast_check` 暗色零回归。
- 每阶段 commit 前：analyze 零告警、format 自有码零 diff、test 相对基线零新增。

## 关联（Links）

- 分析：[starkins-settings-migration-analysis.md](starkins-settings-migration-analysis.md)
- 代码：`lib/ui/settings/model_settings.dart`、`lib/model/app_settings.dart`、`lib/state/settings_store.dart`、`lib/state/app_providers.dart`、`lib/theme/dsw_alias.dart`、`lib/ui/settings/widgets/`(新)
- 关联 ADR：ADR-0002（riverpod/shad 迁移，本改动复用其 read-seam 与 ShadTheme 桥）
