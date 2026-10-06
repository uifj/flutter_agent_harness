# ADR-0074: 看板卡片编辑 + 企划演示种子国际化

- **状态**: ACCEPTED
- **分类**: ARC（编辑通道）+ DEF（种子 i18n）
- **优先级**: P1
- **影响维度**: 生产功能
- **日期**: 2026-10-06
- **来源**: 用户截图（Delivery board 全英文名、卡片不可编辑）+ 指令（深读 `_archive_project/anytype-kotlin`，支持看板编辑并 drift 持久化）
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

两个用户可见的问题：

1. **种子是硬编码英文**：`plan_mock_content.dart` 的 37 个 `name:` 全部英文字面量——集合名（Delivery board / Reading inbox）、视图名（Board / All tasks / Open only / Cards / Calendar / Graph / List / Table）、关系与选项名（Status / Todo / Doing / Blocked / Shipped / Tags / Urgent / Client / Internal / Effort / Due）、类型与模板名。种子在首次打开时写进 `planstar.db`，之后就是**用户数据**——但演示种子属于"产品自带 furniture"，全英文在中文界面里是宿主没换。
2. **看板卡片不可编辑**：Grid 的单元格包 `PlanCellEditor`（点值弹 picker → `amendRecord` → drift，ADR-0071 载体），**Board 的卡片渲染裸 `PlanCellValue`**——没有编辑包装。卡片点击本应打开记录检视器（inspector 的字段行就是编辑器），但该路径**从未有测试钉过**，用户实测"都不能编辑"。

**Anytype 研究**（`ObjectSetFragment.kt:404` + `ObjectSetViewModel.kt:1967`）：看板卡片**不做内联编辑**——`onCardClick → onObjectHeaderClicked → objectStore.get(id) → proceedWithNavigation`，即**打开对象编辑器**（名字是 featured relation，在那里面编辑），看板从 store 重渲染。本仓库的对应物 = 记录检视器对话框（inspector 的每个字段行就是 `PlanCellEditor`，与 Grid 共用同一编辑器，"两个表面不能回答不同"的既有律）。

## 决策（Decision）

**① 看板卡片编辑 = 修通"点卡片 → 检视器"，并把卡片上的明细单元格升级为与 Grid 同款的就地编辑器。**

- 卡片明细单元格（status 等）包 `PlanCellEditor`：点卡片上的 pill → 选项 picker → `amendRecord` → drift（ADR-0071 载体）。与 Grid 完全同款——"两个表面不能回答不同"。
- 卡片点击（标题区）→ 检视器保持 Anytype 语义；名字在检视器的 name 字段编辑（`PlanCellEditor` shortText 文本行）。**加测试钉住这条从未验证的路径**。
- 明确不做：卡片标题的内联文本编辑（Anytype 没有；检视器已覆盖）、拖拽进空列建卡（onAddToColumn 已有）。

**② 种子国际化 = 结构 furniture 进字典 + seedVersion 一次性换血。**

- 字典新增 `seed*` 键（集合 2 + 视图 7 + 关系 4 + 选项 7 + 类型/模板若干 ≈ 24 键 ×2），`locales.dart` 出 `planSeedText(AppLocaleId)` 查询函数——**lib/model 不碰字典**（纯度律），main.dart 在解析 launch locale 处构建本地化种子传入 `planMockSeed(text: …)`。
- **演示记录内容（17 条记录名）保留英文**：它们是样例内容（如同演示邮箱里的样例邮件），是 store 里可改名/可删除的用户数据，不是界面文案。这条边界写死，避免把 17 条散文塞进字典。
- **已有安装的一次性换血**：`PlanSpaceMetaRows` 加 `seedVersion` 列（schemaVersion 3→4）。open 时 `seedVersion < 2` 且空间**仍与旧英文 mock 完全一致**（双集合名 + 全部 mock 记录 id 的名字逐条比对——用户改过任何一个名字就不动）→ 用本地化种子整体替换并盖章 seedVersion=2；不一致 → 只盖章保数据。演示内容是产品自带的，换血防御的是"用户已改"的唯一可能丢数据路径。

## 后果（Consequences）

- **正面**：中文界面下企划演示全中文；看板卡片就地改状态（最常见操作免开对话框）；检视器路径有守卫。
- **负面/风险**：seedVersion 迁移多一档；`PlanCellEditor` 的 popover 在检视器对话框内的 overlay 叠放由测试验证。
- **中性**：`locales.dart` +~24 键 ×2；schema v4；`_archive_project` 的 Anytype 结论：卡片无内联编辑，对象编辑器承载。

## 验证（Verification）

- `test/plan_vault_tree_test.dart` 同族新增：种子 i18n（zh 文本出 zh 名）；换血迁移（旧英文 mock → zh 种子；用户改过的不动）。
- `test/plan_data_view_test.dart`：**卡片点击 → 检视器**（首次钉住）；卡片上 status pill 点击 → picker → store 写入（drift 行可读回）。
- 四道门禁同口径；真机走查中文界面看板。

## 关联（Links）

- 代码: `lib/ui/plan/dataview/plan_board_viewer.dart`、`plan_data_view_screen.dart`、`lib/model/plan_mock_content.dart`、`lib/state/app_database.dart`、`lib/main.dart`、`lib/l10n/locales.dart`
- 关联 ADR: ADR-0071（amendRecord 的 drift 载体）、ADR-0037（种子住在 provider 层）、ADR-0008（键集对齐守卫）
- 上游研究: `_archive_project/anytype-kotlin` `ObjectSetFragment.kt:404`、`ObjectSetViewModel.kt:1967-1977`
