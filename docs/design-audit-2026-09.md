# 设计层审计报告（2026-09-15）

> 方法论来源：Qoder `design-review` 插件 v0.1.0 的手动审查模型（design-debt-review + component-library-alignment + accessibility-review 三个场景 skill 的证据分级、严重度与发现格式）。
> 插件的自动化链路（Playwright 截图、视觉回归、Figma 比对）需要可运行的 Web 目标，本项目为 macOS-only Flutter 桌面应用且当前工作机为 Windows，**视觉保真度结论按插件规则记为 Inconclusive**；本报告全部为代码层证据（令牌名 + 文件:行号 + 确定性计算），不含任何"目测"结论。

## 结论（Verdict）

**代码层：Fail（无障碍阻断级） / 设计债与组件对齐：Pass with warnings。**

dsw 令牌体系本身纪律良好（无越界 BoxShadow、无 Tailwind 式魔数泛滥、暗色对比度几乎全过），但三个问题足以让代码层判 Fail：

1. 全应用 60 个交互元素全部基于 `GestureDetector`，`InkWell` 为 0——**键盘完全无法操作本应用**，屏幕阅读器语义覆盖约等于零。
2. 亮色主题下 6 组正文级令牌对比度低于 WCAG AA（最低 1.26:1），其中两条位于关键路径（主输入框占位符、审批条警示文案）。
3. 表单控件层完全没有 primitives 覆盖，39 处裸 Material 控件仅靠 `ColorScheme` 兜底。

第 3 条与已立项的 ADR-0002（riverpod + shadcn_ui 改造）方向一致；第 1、2 条**不被 ADR-0002 自动解决**，改造时若不同步处理会被 shadcn 组件直接继承。

## 证据范围

- 设计契约：`lib/theme/dsw_alias.dart`（头注释 §1-9 声明的硬规则：`ui/` 只准消费 alias 层，`DswStatic` 禁止，字面颜色禁止）、`dsw_typography.dart`（11 档 UI 刻度 + Markdown 刻度）、`dsw_motion.dart`、`dsw_theme.dart`（`ColorScheme`/`TextTheme`/Tooltip/Scrollbar/TextSelection 映射）。
- 实现代码：`lib/ui/` 46 文件 18k 行全量 grep 扫描 + 疑点逐处人工核读。
- 确定性计算：解析 `dsw_static.dart` + `dsw_alias.dart` 的 118 个别名令牌，按 WCAG 2.x 相对亮度公式计算 28 组"文字令牌 × 所在表面令牌"对比度（含半透明令牌的合成），亮/暗两套。
- 截图/视觉证据：无（见结论段说明）。**以下所有视觉性判断均未做，不代表通过**：字体实际渲染、间距节奏、图标对齐、明暗主题切换观感。

## 阻断级（Blocker）

### A1. 交互层不可键盘达、屏幕阅读器不可用

- 严重度：blocker
- 证据：`grep -c "GestureDetector(" lib/ui/` = **60**（56 处带 onTap）；`InkWell(` = **0**；`FocusNode|Focus(` = **4**；`Semantics(` = **3**（全应用）；`semanticsLabel` = **0**。
- 观察：`GestureDetector` 不参与焦点遍历、不生成可操作语义节点。副标题、tab 条、工具栏、文件树、审批面板的确认按钮——全部只能鼠标点。25 个 `Tooltip` 也因此只有悬停触发（无焦点态）。
- 影响：键盘用户与 VoiceOver 用户无法完成任何主流程；也堵死未来的集成测试路径（无 key 可敲）。
- 建议：这不是逐点修补能解决的——需要把 60 处 `GestureDetector` 换成可聚焦语义控件。**与 ADR-0002 合并处理成本最低**（ShadButton/ShadIconButton 等自带焦点与语义），单独做则新建 `lib/ui/primitives/` 的 focusable wrapper。
- 验证：`grep -c "GestureDetector(" lib/ui/` 趋零；macOS 上用 Full Keyboard Access 走通「发送消息 → 审批 → 打开终端」。

## Major

### A2. 亮色主题 6 组正文级对比度低于 AA

- 严重度：major（其中两条在关键路径，接近 blocker）
- 确定性计算结果（WCAG 相对亮度法，AA 正文 4.5:1 / 大字与图形 3:1）：

| 配对 | 亮色 | 暗色 | 真实消费点（已核实非误配） |
| --- | --- | --- | --- |
| `labelDimmed`/bgBase | **1.26** ✗ | **1.90** ✗ | `sidechat_tab.dart:319`、`subagent_tab.dart:798`（时间戳正文，xxxs11）；`model_settings.dart:1567`（输入 hint）、`:2043`（禁用态，豁免） |
| `labelCaption`/bgBase | **2.13** ✗ | 4.92 ✓ | `composer.dart:581`（**主输入框占位符**）、`reasoning_row.dart:77`、`chat_view.dart:315` 等 7 处文字 |
| `labelTertiary`/bgBase | **3.71** ✗ | 8.54 ✓ | **97 处**消费，全 UI 三级文字 |
| `stateWarnLabel`/bgBase | **2.79** ✗ | 6.53 ✓ | `model_settings.dart:546,1332`（警示正文） |
| `stateWarnPrimary`/`stateWarnTertiary`（审批条） | **1.99** ✗ | — | `approval_panel.dart:104-118`：**「等待审批」警示文字与 8px 圆点直接坐在琥珀底上**（审批是写文件/执行命令的把关路径） |
| `stateSuccessPrimary`/bgBase | **2.28** ✗ | 6.12 ✓ | `diff_block.dart:246`（diff 新增行文字）、`state_dot.dart:44`、`model_settings.dart:536,1853` |

- 观察：这是 dsh 原版调色板的忠实移植——即上游本身在亮色下就不达 AA。**改令牌值会背离"1:1 端口"的既定事实**（`dsw_alias.dart:3-5`），属于设计决策而非机械修复。
- 建议：在 ADR-0002 的主题改造中一并决策：保持 dsh 视觉身份则接受豁免记录（内部开发工具、非面向公众），或为亮色主题引入"AA 修正版"别名层。**不要**在各消费点就地调色（那会制造 97 处漂移）。
- 验证：`dart tool/contrast_check.dart`（本审计固化的检查工具，随主题改造重跑）；修订后亮色全部 ≥4.5（或书面豁免）。

### C1. 表单控件层零 primitive 覆盖

- 严重度：major
- 证据：`IconButton(` ×17、`TextField(` ×6（含 `composer.dart` 主输入）、`TextButton` ×5、`PopupMenuButton` ×7、`showDialog`/`AlertDialog` ×4，合计 39 处，分布于 9 个文件（git_tab 最多）。`lib/ui/primitives/` 13 个自绘件全部是**内容块**（code/diff/read/search/terminal block、disclosure_row、pill、state_dot…），唯一按钮是 `capsule_button`（primary/outline/ghost × md/sm）。Material 控件仅靠 `dsw_theme.dart:138` 的 `ColorScheme` 兜底，无 per-widget 主题。
- 观察：方法论判级为"缺失组件变体"而非"绕过"——不存在可绕的 primitive。但后果相同：同一意图的控件在不同 tab 里长出不同的边框/圆角/涟漪。
- 建议：ADR-0002 的核心受益点，ShadButton/ShadIconButton/ShadInput/ShadSelect/ShadDialog/ShadPopover 直接补齐这一层。
- 验证：改造后 `grep -rn "TextField(\|PopupMenuButton\|showDialog" lib/ui/`（排除 primitives/adapter 层）趋零。

### A3. 自绘原语无语义包装

- 严重度：major
- 证据：`Semantics(` 仅 3 处对应 60 个交互元素 + 全部自绘 primitives（state_dot、pill、diff_block 的行内操作等）。`gpt_markdown`/`xterm` 画布内容对辅助技术不可见。
- 影响：与 A1 同根，VoiceOver 用户得到的界面近乎空白。
- 建议：primitives 层每个对外控件补 `Semantics` 标注（与 ADR-0002 的组件替换合并做）。

### A4. 无文本缩放适配

- 严重度：major
- 证据：`textScaler|textScaleFactor` 全仓库 **0** 处；`disclosure_row` 等自绘件有固定高度（24px header）。
- 影响：macOS 辅助功能放大文本时，固定高度行内文字会裁切/溢出。
- 建议：改用 `min-height` 思路（容器高度随文字行高）或显式 `textScaler` 上限策略；至少在 ADR-0002 重写控件时不再引入新的固定高度文字容器。

## Design Debt（债级）

### D1. 排版漂移：4 处 off-scale 覆盖 + 1 处冗余覆盖

- 严重度：debt（扩散风险中等——AI 代理爱抄 `copyWith(fontSize:)` 模式）
- 证据：
  - `conversation_root.dart:176`：`DswType.xl24.copyWith(fontSize: 26, height: 32/26)`——26 不在刻度，无注释说明，直接用 xl24 即可；
  - `approval_panel.dart:138`：`s14.copyWith(fontSize: 15, …)`——15 仅存在于 Markdown 刻度（markdownTable），UI 刻度无此档；
  - `tool_card.dart:288`：`xs13.copyWith(fontSize: 11, height: 16/11)`——11 在刻度（xxxs11）但行高 16/11 ≠ 刻度的 14/11；
  - `sidebar.dart:182`：18px——**带注释的刻意例外**（dsh 源头即如此），保留；
  - `details_panel.dart:197`：12/18/w500 恰好等于刻度里的 `xxxsStrong12`——冗余覆盖，应直接引用令牌。
- 建议：前三处对齐刻度或补注释说明理由；`details_panel` 机械替换。刻度本身足够用（11 档 UI + 9 档 Markdown），不需要加档。

### D2. `DswStatic` 越界引用（违反 dsw_alias.dart:7-9 声明的契约）

- 严重度：debt
- 证据：`chat_view.dart:332-336`（shimmer 渐变用 `DswStatic.deepseek500/200` 直引 5 次）；`state_dot.dart:41`（primitive 层直引 `deepseek450`）。
- 观察：根因是 alias 层没有"品牌渐变对"令牌——shimmer 需要的 500/200 组合无现成别名，属**契约缺口**而非单纯违纪。
- 建议：在 `DswAlias` 增加 `brandGradientShimmer` 之类的成对令牌，消费点改引别名；`state_dot` 的 `deepseek450` 换 `brandPrimaryNewColor`（dark 下即同值）。

### D3. hover 态模式 15+ 处复制粘贴

- 严重度：debt
- 证据：`_hovered ? color.interactiveBgHover : Colors.transparent` 模式在 12 个文件重复 15+ 次（app_frame:592、composer:822、hero_workspace_picker:109、model_settings:1371、sidebar、free_window_layer:381、pane:367、browser_tab:369、diff_tab:745,1006、git_tab:915,1011、subagent_tab:406,947 …）。
- 建议：一个 `DswHoverSurface`/装饰器扩展即可收敛；ADR-0002 若引入 shadcn 的状态样式则自然消解。

### D4. 死令牌 12 个

- 严重度：info
- 证据：`markdownPlaceholder`、`stateSuccessSecondary`、`stateErrorSecondary`、`markdownCodeSegmentUnselected`、`borderInverted`、`bgMultiSelect`、`bgMaskPhoto`、`loginInput`、`markdownCitation`、`markdownTag`、`scrollbarBgL2`、`scrollbarHoverL2`——全 lib 零消费。
- 观察：alias 层是对 dsh `design-platform.css:156-338` 的 1:1 移植，死令牌是移植保真度的副产品，**不建议清理**（清理后与上游 diff 能力受损）。记录在案即可。

### D5. 终端调色板 46 个字面色

- 严重度：info（可接受例外，但有归位改进）
- 证据：`terminal_tab.dart:318-362`：One Dark + Atom One Light 两套 16 色 + 搜索高亮 2 色，全部字面 `Color(0x…)`。
- 观察：xterm 主题是外部标准命名色，不适用 dsw 令牌。但它们住在 feature 代码（tabs/）里，宜移入 `lib/theme/` 作为命名终端主题常量。`terminal_tab.dart:298` 的 `Colors.white.withValues(alpha: 0.22)` 同属终端主题范畴。

## 通过项（如实记录，防"全盘皆差"误读）

- **无一处** `BoxShadow` 越界（全部在 `dsw_theme.dart` 的 `DswShadow` ramp 内，且做了 CSS→Flutter 换算）。
- **无一处** 特性代码裸 `TextStyle(` 构造（唯一一处是 editor_tab 的 `_gutter`，代码编辑器几何，属例外）；字号全部经 `DswType` 刻度（除上列 5 处）。
- 暗色主题 28 组对比度仅 `labelDimmed` 一项失败；主/信息按钮、气泡、tooltip、代码块的亮暗两套全部 AA+。
- 减速动效有系统性方案：`DswMotion.respecting()`（dsw_motion.dart:28）对应 `prefers-reduced-motion`。
- 内容块 primitives（code/diff/read/search/terminal block）无克隆、无绕过，纪律良好。
- 动效时长漂移仅 4 处且均为循环周期（shimmer 1800ms、sweep 2600ms）或微交互 linger，非过渡时长，不构成令牌侵蚀。

## 迁移影响映射（ADR-0002 的输入）

### state 层（lib/state/ 13 文件 2,194 行）→ riverpod

| 现状 | 行数 | riverpod 对应 | 迁移风险 |
| --- | --- | --- | --- |
| `app_scope.dart`（组合根，手工 DI，运行时热替换） | 355 | `ProviderScope` + providers；热替换 = provider 刷新/override | 中：355 行装配逻辑要逐项拆 provider，最容易在此丢"settings 保存 → runtime 重建 → side chat 重新 adopt"链 |
| `conversation_controller` + `streaming_tail` | 466+57 | Notifier + 独立 tail provider | **高**：token delta 只通知 tail 是唯一性能契约（test/conversation_controller_test.dart 守着）；riverpod 的 autoDispose/family 重建语义可能静默破坏它 |
| `workbench_controller` + `workbench_store` | 371+123 | Notifier + 持久化 side-effect | 中：tmp+rename 原子写要在 Notifier 的构建/更新钩子里保住 |
| `layout_controller` | 173 | provider | 低；但它是 §0 不变量"state 不 import ui"的唯一例外（import columns.dart），riverpod 不改变该 import |
| `settings_store`/`prefs_store` | 72+61 | provider + 监听 | 低 |
| 其余 5 个小控制器（74-200 行） | 494 | 各自 provider | 低 |
| 39 个测试的手工 fake 注入 | — | `ProviderScope(overrides:)` | 收益：fake 注入从构造函数参数换成 override，更标准 |

### primitives（13 个）→ shadcn_ui 0.56.3

| 现状 | shadcn 对应 | 处置 |
| --- | --- | --- |
| `capsule_button`（primary/outline/ghost × md/sm） | `ShadButton`（variant 恰好同名） | 替换 |
| `pill.dart` | `ShadBadge` | 替换 |
| 4 处 `showDialog`/`AlertDialog` | `ShadDialog` | 替换 |
| 7 处 `PopupMenuButton` | `ShadSelect`/`ShadMenu`/`ShadPopover` | 替换 |
| 6 处 `TextField`（含主输入） | `ShadInput` | 替换 |
| 17 处 `IconButton` | `ShadIconButton` | 替换 |
| 25 处 `Tooltip`（已手工主题化） | `ShadTooltip` | 替换后删除 dsw_theme 手工块 |
| `code_block`/`diff_block`/`read_block`/`search_block`/`terminal_block`/`disclosure_row`/`state_dot`/`row_sweep`/`head_tail_cap`/`block_chrome`/`copy_button` | **无对应物** | **保留自绘**，仅重刷表面令牌——这些是本应用的领域表面，不是通用控件 |

### 主题碰撞（ADR-0002 必须点名的设计决策）

`ShadThemeData` 自带一套 tailwind 风格调色板，与 `DswAlias` 的 dsh 身份正面相撞。两条路线：
- **A（建议）**：`ShadThemeData.custom` 包裹现有 `DswAlias`，dsh 视觉身份不变，shadcn 只出组件不出颜色；
- B：整体采纳 shadcn 调色板，dsw_* 降级为兼容层直至移除——工作量大一档，且 118 个语义别名（97 处 labelTertiary 等消费）要全部重映射。

### 版本硬约束（已核实 pub.dev，2026-09-15）

- `flutter_riverpod` 最新稳定 **3.4.3 要求 Dart ≥3.12**；本仓库钉在 **Dart 3.11.5**（pubspec `^3.11.5` + Flutter 3.41.9）。→ 要么用 **3.3.2**（最后一个 Dart ≥3.7 的稳定线，当前基线直接可用），要么先升 SDK（按 build.md §0 需另行决策）。
- `shadcn_ui` 最新 **0.56.3**（2026-09-03 发布）即 vendored 那份；约束 Dart ≥3.11 / Flutter ≥3.41，与当前基线**兼容**。其 0.56.0 为 slang 4.18 相关破坏性变更，slang 只是传递依赖，不受影响。
- shadcn_ui 传递依赖 `lucide_icons_flutter`，与现有直接依赖 `flutter_lucide` 是**两套 lucide 图标包**——迁移时二选一，避免双图标库并存。
- riverpod 的惯用路径含 codegen（riverpod_generator + build_runner），与本仓库"不引入代码生成器"红线冲突 → 必须走**手写 provider** 路线（riverpod 3.x 完整支持无 codegen 用法）。

## 验证清单（改造落地时逐项过）

- [ ] `grep -c "GestureDetector(" lib/ui/` 趋零（A1）
- [ ] 对比度脚本重跑，亮色达标或书面豁免（A2）
- [ ] `flutter test test/conversation_controller_test.dart` 全绿（流式契约在 riverpod 化后仍成立）
- [ ] `grep -rn "package:genkit" lib/ | grep -v "^lib/genkit/"` 仍为空（不变量不因迁移松动）
- [ ] macOS 真机：Full Keyboard Access 走通发送 → 审批 → 终端；VoiceOver 朗读主流程控件
- [ ] 无 `build_runner`/`.g.dart` 进入提交
