# ADR-0007: 工作区模式切换（企划/代理）+ 企划 Markdown 工作台 + 扩展面板（board_panel）

- **状态**: ACCEPTED
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 生产功能（工作区顶层形态）· 依赖面扩大（board_panel 本地包）
- **日期**: 2026-09-16
- **来源**: 用户决策（参照 starkins_app：① 顶层「企划/代理」切换；② 企划=当前工作区内 .md 文档的 Obsidian 式本地编辑；③ 扩展下拉接入看板/日程等，board_panel 已放 `packages/board_panel`）
- **修复 commit**: —（分阶段回填）
- **关联**: ADR-0002（riverpod 注解模式/shadcn_ui；board_panel 沿用同一栈）、ADR-0001（vendored 包不入库的先例——本 ADR 对 board_panel 例外，见决策 5）

## 背景（Context）

1. **starkins 机制**（调研证据，`starkins_app/lib/workspace/`）：
   - 切换器在侧栏顶部：`left_sidebar.dart:345-422` `_TaskChannelTabs` 分段控件（企划/代理）；状态是 riverpod `sidebarTabProvider`（`sidebar_tab_provider.dart:12-23`，`enum SidebarTab { plan, agent }`，**不持久化**）。
   - 切换语义（`left_sidebar.dart:336-343`）：换 tab 时若当前视图属于另一模式的扩展页则重置视图；中心区条件渲染（`center_pane.dart:34-47`：plan+选中笔记 → `PlanNoteEditor`，否则会话）。
   - 企划侧：`_PlanFileTree`（`left_sidebar.dart:472-632`，Obsidian 式 vault 树）+ `PlanNoteEditor`（`plan_note_editor.dart`，基于 **appflowy_editor** 富文本、400ms 防抖写回）。
   - 扩展：`_ExtensionGroup`（`left_sidebar.dart:260-328`，可展开导航组而非下拉）；企划扩展 = 日历日程/表格/看板（`workspace_fixtures.dart:459`）；选择经 `workspaceViewProvider` 枚举切换，中心区整块换为 `WorkspaceViewHost`（`task_workspace_page.dart:91-103`）。
2. **本项目现状**：无顶层模式概念——`main.dart` 的 `AppFrame.center` 恒为 `ConversationRoot`；侧栏（`sidebar.dart`）= 会话列表 + footer。已有可复用件：`re_editor` 编辑器（`editor_tab.dart`，含加载/保存/脏确认）、`gpt_markdown` 渲染（`assistant_markdown.dart`）、`indexWorkspace` 工作区索引（`model/workspace_index.dart`，compute 离线程）、`file_tree_tab.dart` 的树呈现。
3. **board_panel**（用户放置于 `packages/board_panel`，15.2k 行，未入库）：提供 `BoardPanel`（看板，`BoardPanelController`/`BoardPanelGroupData`/拖拽回调）、`EventController`+`MonthView/DayView/WeekView`（日历）、`ExpandableTable`（表格）；自带 `shad_theme_fallback`。**其 `shadcn_ui` 依赖是路径 `../shadcn_ui`，该目录不存在**（实际叫 `flutter-shadcn-ui`）——当前无法解析。
4. **不变量**（workflow §0 / migration-log）：`package:riverpod*` 仅 `main.dart` + `state/app_providers.dart`；`lib/model/` 纯 Dart；无路由；riverpod 注解模式。

## 决策（Decision）

### D1：顶层模式 = `WorkspaceModeController`（ChangeNotifier）+ app_providers provider，侧栏分段控件切换

- `enum WorkspaceMode { agent, plan }` + `extensionView`（none/board/calendar/table）同住一个 `lib/state/workspace_mode_controller.dart`（LayoutController 式 ChangeNotifier；riverpod 只在 `app_providers.dart` 加 `workspaceMode` per-controller provider——沿用既有边界不变量）。
- 切换语义照 starkins：换模式时若扩展视图属于另一模式则重置；**不持久化**（视图态，与会话/布局持久化无关——starkins 同样不持久化）。
- UI：侧栏 logo 行下加分段控件（企划/代理，dsw 令牌、`DswHoverTap`；rail 态两个图标按钮），i18n 双字典。

### D2：「代理」= 现有中心区不动

`ConversationRoot` 及其全部现有功能照旧；模式切换只影响中心区渲染分支与会话列表可见性（企划态侧栏显示 .md 树——见 D3）。

### D3：「企划」= 当前工作区的 .md vault：树 + 源码编辑器 + 预览切换

- **范围收敛（与 starkins 的差异，刻意）**：starkins 用 appflowy_editor 富文本；本项目**不做富文本**，用已有的 `re_editor` 做源码编辑 + `gpt_markdown` 做预览（编辑/预览二态切换）。理由：复用现有栈、不新增 15k+ 行编辑器依赖；Obsidian 的核心体验（vault 树 + 本地 md 编辑 + 预览）由此覆盖。
- 文件树：复用 `indexWorkspace`（compute 离线程）过滤 `*.md`，按相对路径构树；仍指向**当前选中的工作区根**（用户要求）；无工作区时给引导文案。
- 选中文件 → 中心区编辑器（加载/保存复用 `editor_tab` 的模式：脏态、Ctrl+S、失焦保存、丢弃确认走 `showConfirmDialog`）。
- 文件列表/编辑器选中**不进 layout 持久化**（视图态）。

### D4：扩展面板 = 侧栏「扩展」可展开组（企划模式），中心区整块换视图；任务数据落 Application Support

- 企划模式的侧栏显示「扩展」组（看板/日程/表格——starkins 同款三项；代理模式无扩展组，本项目代理侧的"扩展"已有真实居所=设置面板的 MCP/Skills 节，不重复造）。
- 选中 → `extensionView` 置位，中心区渲染对应面板；再点收起或切模式重置。
- **数据**：三个面板共享一个 `PlanTaskStore`（`lib/state/plan_task_store.dart`，ChangeNotifier），字段覆盖看板（组/序）与日程（日期）所需：`id/title/groupIndex/dueDate?/done`。**持久化到 `<support>/plan_tasks.json`**（tmp+rename 原子写，照 `settings_store.dart` 模式；starkins 也持久化任务，且不持久化的看板没有实用价值）。看板列固定四段（待办/进行中/评审/完成）拖拽改 `groupIndex`+序；日程 `EventController` 投影 `dueDate`。MVP 不做任务编辑对话框以外的新建/编辑表单复杂化——用最小的新建/编辑行内交互（见实施）。
- **实施细化（表格）**：表格改用手写 dsw 表（列头 + 每任务一行：完成切换/标题/截止/移除），**不用 board_panel 的 `ExpandableTable`**——后者基于 ChangeNotifier 的 cell 对象与 `build(context, details)` 契约，对一个扁平任务列表是过重的机器，且手写表与全应用 dsw 词汇更一致。看板与日历仍取 board_panel（拖拽看板、月视图是依赖的价值所在）。
- 面板 widget：`lib/ui/plan/plan_workspace.dart`（树+编辑器宿主）与 `lib/ui/plan/plan_extensions_view.dart`（`PlanExtensionsView` + 内聚的 `_BoardView`/`_CalendarView`/`_TableView` + 共享 add 行/卡片），配色/字号全走 `context.dsw` + `DswType`（board_panel 内部自带 shad fallback，不强改其内部）。

### D5：board_panel 依赖接线（修断路径 + 入库）

- 根 `pubspec.yaml` 加 `board_panel: {path: packages/board_panel}`。
- **修 board_panel 的 `shadcn_ui` 依赖为 hosted `^0.56.3`**（与主应用同一实例）：其原路径 `../shadcn_ui` 不存在；若改指 `../flutter-shadcn-ui`（vendored 副本）会与主应用的 hosted shadcn_ui 形成**两个包实例**、两套 ShadTheme 类型。hosted 同版本 = 唯一实例，board_panel 的 `shad_theme_fallback` 与主应用主题自然互通。
- `intl` 仅作为 board_panel 的传递依赖（同 shadcn_ui 的 intl 约定：**禁止直接 import**）。
- **board_panel 入库**（对 ADR-0001 先例的例外）：它无上游可再拉取（无 homepage/publish_to none 的私有包），不入库即丢失；`.dart_tool/` 已被全局 gitignore 覆盖，example 保留（面板 API 的活样例）。`analysis_options.yaml` 既有 `packages/**` 排除继续生效（vendored 代码不进 analyze/format 门禁）。

### D6：不引入的东西（守卫）

- 不引入 appflowy_editor / 路由 / wiki-link 双链 / 全文搜索（Obsidian 的深水区，后续按需另立 ADR）。
- 不做移动端/多 vault；vault 恒等于当前工作区根。

## 分阶段落地（每阶段过 analyze/format/test 再 commit）

- **S1 依赖接线**：board_panel shadcn_ui 修为 hosted ^0.56.3、根 pubspec 加 path 依赖、`flutter pub get` + 首页 import 冒烟；`.gitignore` 核对；入库。
- **S2 模式骨架**：`WorkspaceModeController` + provider + 侧栏分段控件（企划/代理）+ 中心区分支（plan 先占位）；i18n；controller 单测。
- **S3 企划工作台**：.md 树（indexWorkspace 过滤）+ re_editor 源码编辑 + gpt_markdown 预览切换 + 保存链路；widget 测试。
- **S4 扩展面板**：PlanTaskStore（持久化）+ 侧栏扩展组 + 看板/日程/表格三视图接 board_panel；store 单测 + 面板冒烟测试。
- **S5 真机走查**：Windows `flutter run -d windows` 走 企划树/编辑/保存、看板拖拽、日程、切回代理；门禁全绿。

## 后果（Consequences）

- **正面**：工作区获得顶层形态（agent harness 不再是唯一形态）；企划侧复用现有编辑器/渲染栈，零新增重依赖；board_panel 三面板即插即用；任务数据持久化使其真实可用。
- **负面/风险**：`packages/board_panel` 15.2k 行 vendored 代码入库（无上游、必须保真，未来升级靠手工 diff）；board_panel 内部样式走其 shad fallback，观感与 dsw 有细微差（中心区大面板可接受，逐面微调后续做）；企划编辑器与 `editor_tab` 存在少量模式重复（刻意：不抽公共层，等第二个真实用例再收敛）。
- **中性**：模式/扩展视图态不持久化；代理模式 UI 零改动。

## 验证（Verification）

- `grep -rn "package:riverpod" lib/` 仍仅 `main.dart`+`app_providers.dart`；`grep -rn "package:intl" lib/` 为空；无 `Navigator.push`。
- 企划：树只列当前工作区 `*.md`；编辑后保存落盘（重启可见）；切代理再切回，编辑内容不丢（controller 存活）。
- 看板拖拽改组落盘；日程按 dueDate 显示；表格投影一致。
- 每阶段：analyze 零告警、format 零 diff、test 相对基线（669 通过 / 13 既有 Windows-only 失败）零新增。

## 关联（Links）

- 代码：`lib/state/workspace_mode_controller.dart`(新)、`lib/state/plan_task_store.dart`(新)、`lib/ui/plan/*`(新)、`lib/ui/sidebar/sidebar.dart`、`lib/main.dart`、`packages/board_panel`
- 参考：`starkins_app/.../left_sidebar.dart`、`workspace_view_provider.dart`、`center_pane.dart`、`plan_note_editor.dart`
- 关联 ADR：ADR-0002（同一 riverpod/shad 栈）、ADR-0001（vendored 不入库先例——board_panel 为记录在案的例外）
