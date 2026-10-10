# ADR-0073: 笔记目录树迁入侧栏——企划模式下的常驻 Obsidian 形

- **状态**: ACCEPTED
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 生产功能 / 认知障碍
- **日期**: 2026-10-04
- **来源**: 用户截图与决策：企划模式下切到集合/库屏后笔记目录树消失（机制：树住 `PlanWorkspace` 内部，center 的 switch 在 `extensionView != none` 时整列换掉——树必然消失）。参考 Obsidian（explorer 常驻侧栏）与 Anytype（侧栏对象树），用户提议"侧边加一个按钮，点击出现当前工作区笔记"。
- **修复 commit**: 本批（见登记表行回填）

## 决策（Decision）

**树从 `PlanWorkspace` 抽取为独立 `PlanVaultTree`，住进侧栏扩展区顶部的可折叠「笔记」节（默认展开，点头折叠——用户要的那枚按钮）；编辑器全宽；跨视图持久。**

1. **`PlanVaultTree`**（`lib/ui/plan/plan_vault_tree.dart`）：拥有树的全部状态（md 索引、树构建、展开集、新建文件/文件夹、名称对话框、workspace 页脚），参数 `workspaceRoot / onPickWorkspace / selectedPath / onOpenNote(FileEntry) / width`。树头部的集合九宫格菜单**删去**——侧栏扩展区本就列出全部集合，第二入口是假门律的反面（同一扇门两把钥匙）。
2. **`WorkspaceModeController` 三行**：`openNotePath` + `openNote(relative)`（`extensionView = none` + 存路径 + notify）+ `consumeOpenNote()`（静默清空，防重入环）。这是侧栏树与编辑器的唯一会合点：任何 center 状态下点侧栏树里的笔记 → 回到文档视图并打开。
3. **`PlanWorkspace` 变纯编辑器**：删树状态与 `_treePane`，编辑器全宽；新参数 `initialNote / onNoteConsumed`——initState/didUpdateWidget 消费控制器路径（含已挂载时换笔记的分支），打开后即消费。
4. **侧栏**：`_libraryBody` 顶部加折叠节——头行（chevron + 笔记 + 计数），展开时宿主 `PlanVaultTree`；宽档限定（rail/窄档跳过，树需要宽度）。折叠状态是会话态（State 字段），默认展开——Obsidian 的 explorer 也是默认可见。
5. **明确不做**：树双驻（center + sidebar 两份展开集/选中态是两处真值）；树在窄档/ rail 的图标形态；树的拖拽排序（Anytype 亦无）。

## 后果（Consequences）

- **正面**：树跨全部企划屏常驻（bug 的成因被拆除而非修补）；编辑器全宽（正文多 232px）；"从目录树选择一个 Markdown 文件"的空态不再挡在集合视图前。
- **负面/风险**：`plan_workspace_test` 的树断言整体迁往新宿主（含登记表里那两条既有失败之一的宿主——断言按新宿主重写，失败是否消失看实测）；侧栏变宽的内容密度变化待真机观感。
- **中性**：`sidebar.dart` 参数 +2；控制器 +3 成员。

## 验证（Verification）

- `test/plan_vault_tree_test.dart`（新）：树渲染/展开/打开回调/新建；`plan_workspace_test` 改为编辑器宿主（initialNote 打开、保存往返）；`sidebar_test` 加折叠节。
- 四道门禁同口径；真机走查：企划模式切集合/库后侧栏树仍在、点笔记回文档视图。

## 后续修正（Follow-up，2026-10-10）

宽档展开态最初用 `SliverFillRemaining(hasScrollBody: false)` 让笔记树填满剩余视口；一次修复（回落固定高度地板）只处理了「上方内容高出视口」这一半，另一半——**高窗口里 `SliverFillRemaining` 从 `SliverLayoutBuilder` 返回时，会留下一个在台上却 `renderObject` 为 null 的子元素**（`ViewportElement.debugVisitOnstageChildren` 空断言即崩，设备上表现为「点笔记→整节消失」）——一直是坏的，且现有 `sidebar_test` 只钉了矮窗口地板分支（绿），从未覆盖高窗口（坏）。

根因修复：删掉 `SliverFillRemaining` 这条坏分支，展开态两半合并为已被证明安全的 `SliverToBoxAdapter + SizedBox`，高度取 `max(remaining, 地板)`——`remaining ≥ 地板` 时正好填满视口，`< 地板` 时保持地板高度让外层滚动可达。`test/sidebar_test.dart` 补一条高窗口回归（`expanding 笔记 in a tall window keeps the tree`），与矮窗口那条一起守住两半。

## 关联（Links）

- 代码: `lib/ui/plan/plan_vault_tree.dart`、`lib/ui/plan/plan_workspace.dart`、`lib/ui/sidebar/sidebar.dart`、`lib/state/workspace_mode_controller.dart`、`lib/main.dart`
- 关联 ADR: ADR-0037（企划模式与 P8-b 扩展区）、ADR-0039（侧栏双档结构）
- 参照: Anytype 侧栏对象树；Obsidian explorer
