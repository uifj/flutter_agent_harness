# ADR-0048: 面板切换钮只有一个家，而且它在流内

- **状态**: ACCEPTED
- **分类**: DEF（布局缺陷）
- **优先级**: P2
- **影响维度**: 生产功能 / 认知障碍
- **日期**: 2026-10-03
- **来源**: 用户报告（响应式布局下"切换面板"与内容重叠）+ 附带的顶部条截图 + ZCode 参考实现
- **修复 commit**: 9be374c

## 背景（Context）

外壳把两枚面板切换钮画在**两个地方**，其中一处是浮层：

- `lib/ui/app_frame.dart`（修复前 286-298）：面板开着时 `Positioned(top: 3, right: 10, child: _ToggleCluster(...))` 钉在视口右上角。
- 同文件（修复前 190-199）：面板关着时才改画 `_CenterToggleStrip`——中列顶部一条在流内的行。

为了不让浮层盖住 tab，面板自己的 tab 条要在右端**挖洞**：`lib/ui/workbench/workbench.dart:130-138` 的 `_clusterReserve = 72.0` / `cornerClusterWidth`，经 `Workbench.reserveTrailing` → `pane.dart` → `split_view.dart` → `workbench_tab_bar.dart:133` 的 `SizedBox(width: reserveTrailing)`。`lib/main.dart:517-523` 再为 merged 抽屉单独算一次。

三条可核对的后果：

1. **洞与浮层不是一一对应**。`split_view.dart`（修复前 53/58）把同一个 `reserveTrailing` 传给**两个**子视图，而浮层只盖得住最上面那一条：一列分裂成两个 pane 时，下面那条白留 72px，上面那条则取决于 pane 高度是否恰好等于条高——重叠与否变成巧合，而不是设计。
2. **浮层落在谁头上由绘制顺序决定**，不由约束决定。`app_frame.dart` 的 `Stack` 里它在 `widget.overlay` 之后，所以它压住的是"当时恰好在右上角的任何东西"。
3. **四句 tooltip 是硬编码英文**（修复前 `app_frame.dart:570/577`），而 `lib/l10n/locales.dart:106-109` 早就有 `openWorkbenchPanel` / `collapseWorkbenchPanel` / `openBottomPanel` / `collapseBottomPanel` 四个键、中英双份——中文界面下这枚钮仍然说英文（ADR-0008 的口径）。

参考实现给的是同一条律的另一种写法：ZCode 的头部是一行 `flex ... shrink-0`（`packages/ui/src/WorkspaceHeader.tsx:140,157`），右侧动作簇是 `flex shrink-0 items-center gap-0.5`（`WorkspaceHeaderActionSection.tsx:33-39`），面板切换钮在其中（`:70-77`）；面板开着时同一枚钮出现在该面板 tab 条的尾部簇 `ml-auto flex shrink-0`（`AnimatedSidePanePanel.tsx:1044-1047`），让位的是 tab 列表本身（`min-w-0 flex-1 overflow-x-auto`，`:968-982`）。逐处 grep `absolute` + toggle：该仓库**没有**任何绝对定位的面板切换钮。

## 决策（Decision）

**一个家，在流内**：切换簇只住在中列顶部那一条 `_CenterToggleStrip`，**任何面板状态下都是这一条**；删掉视口角落的浮层与整条 `reserveTrailing` 挖洞链。

取舍说明：

- 备选是照 ZCode 更照一层——面板开着时把钮搬进该面板 tab 条的尾部。这里**不采**，因为 ZCode 的侧栏只有一条 tab 条，而本应用一列可以分裂成多个 pane：搬进去就要回答"哪一条"，那正是本 ADR 要消灭的那类巧合。中列顶部条对所有面板状态只有一个答案。
- 代价明说：顶部条常驻，面板开着时中列少 36px（放大档 64.8）。换来的是"chrome 会不会盖住内容"不再取决于绘制顺序与分裂数量。
- 顺带（同一处代码，不另开批次）：`_ToggleButton` 那枚手画圆钮换成 `DswIconButton`（ADR-0024——它是全应用最后一枚私有图标钮，`icon_button_test` 的类名正则 `_.*Icon.*Button` 恰好漏掉了 `_ToggleButton` 这个名字）；四句 tooltip 改走 `context.tr`；顶部条的座位按 ADR-0017 S3 随字号步子。

## 后果（Consequences）

- **正面**: 重叠这一类缺陷从"可能但靠洞规避"变成"结构上不可能"；净删代码（`reserveTrailing` 四处、`_clusterReserve`/`cornerClusterWidth`/`layoutIsMerged`、浮层 `Positioned`、私有圆钮一类）；中文界面下那四句话终于跟着语言走。
- **负面/风险**: 中列顶部条在面板打开时也多占一行高度；图标钮由圆形变圆角方形（与 ADR-0024 已收的 browser/git 两处同判词），**观感待 macOS 真机签收**。
- **中性**: `app_frame.dart` 不再 import `primitives/tappable.dart`；`workbench.dart` 不再依赖 `layout/columns.dart`；测试的**认法**从"角落坐标"改成"中列右边界"，断言的是列宽与钮位置的关系而不是像素常量。

## 验证（Verification）

- `test/app_frame_test.dart` 两棵新守卫：`the panel toggles have one home, and the centre pays for it`（开/关/merged 三态各测一次右边界 == 中列右边界 − 10）、`the shell top bar rides the text step`（1.8x 下钮宽 32×1.8）。
- **三条反向验过**：顶部条右内边距 10 → 60，第一棵红在 `Expected: a numeric value within <1> of <990.0> Actual: <940.0>`；钮的 `size` 去掉步子，红成 `A RenderFlex overflowed by 4.0 pixels on the right`；改回即绿。
- `grep -rn "reserveTrailing\|cornerClusterWidth" lib/` == 0。
- 门禁：`dart format` 0 changed、`dart analyze --fatal-infos lib test tool spike` 干净、`flutter test` `+1321 -2`（两条已登记失败，零新增）、`dart tool/check_architecture.dart` 7 recorded / 0 new。

## 关联（Links）

- ADR-0017 S3（座位随字号）、ADR-0024（图标按钮只有一枚原语）、ADR-0008（双语键集）、ADR-0036（换件批次族；本 ADR 的钮正是该族最后一枚手画件）
- 参考证据：`_archive_project/ZCode-main/packages/ui/src/WorkspaceHeader.tsx`、`WorkspaceHeaderActionSection.tsx`、`AnimatedSidePanePanel.tsx`
