# 企划模式复现 Anytype §1–§7：设计与施工表

配套 ADR：**ADR-0037**（`docs/adr/ADR-0037-arc-plan-mode-anytype-dataviews.md`，ACCEPTED）。
功能真值清单：**`docs/anytype-feature-inventory-2026-10-01.md` §1–§7 + §17**。
上游副本：`_archive_project/anytype-kotlin`（head `7af5254` = v0.50.4，只读）。

本文是施工图：§1 现状、§2 目标形状、§3 复用线、§4 逐段映射（§1–§7 每一段要交付什么）、
§5 分层与命名落位、§6 七阶段提交计划、§7 每段的守卫与门禁、§8 诚实边界。

---

## 1. 现状（读过的代码，不是记忆）

| 事实 | 证据 |
| --- | --- |
| 记录是固定六字段 `PlanTask(id,title,groupIndex,order,done,dueDate)`，没有关系/类型/视图 | `lib/model/plan_task.dart:5-49` |
| 看板列数钉死为常量 4，列名是 i18n 文案不是数据 | `lib/state/plan_task_store.dart:18`、`lib/ui/plan/plan_extensions_view.dart:4-7` |
| 面板选择是封闭四值枚举，加一视图要改四处 | `lib/state/workspace_mode_controller.dart:33-44`、`lib/main.dart:352-365`、`lib/ui/sidebar/sidebar.dart:373-379` |
| 三块面板各画一份，没有"记录=有序 id 列表 + 按行解析内容"这层 | `lib/ui/plan/plan_extensions_view.dart:55-57` |
| store 已是生产形状：JSON + 原子 tmp/rename + corrupt 读空 + notify | `lib/state/plan_task_store.dart:139-149` |
| riverpod 注解 + codegen 可用且幂等（本机已跑通） | `dart run build_runner build` → `Built with build_runner/aot in 15s; wrote 2 outputs`，`app_providers.g.dart` 无 diff |
| 全量门禁基线 | `flutter test` = **`+963 -2`**（两条既有失败：`app_scope_test` 的 `/var`↔`/private/var`、`plan_workspace_test` 的 `find.text('notes')`） |
| 笔记是纯 Markdown 文本 + `re_editor` + `_NotePreview`（gpt_markdown 渲染） | `lib/ui/plan/plan_workspace.dart:182-231`、`:561-620`、`:826-846` |

## 2. 目标形状（Anytype 的三个核心决定，逐个换成 Dart）

1. **类型/关系/视图/模板/组件都是对象，记录是 `Struct` 的视图。**
   `PlanStruct = Map<String, Object?>`（纯 Dart，`lib/model/plan_struct.dart`），
   `PlanObject` 按读时解析关系（对应 `ObjectWrapper` over `Struct`）。
   这条决定后面所有能力：加关系不改类、视图配置是数据、手工排序是 id 列表。
2. **没有 Go 核心 ⇒ 事件流换成纯函数 reducer。**
   `PlanDataViewStage(state, event)`；保持 Anytype 两条语义：**先挂订阅再取快照**
   （`DataViewSubscriptionContainer.kt:59`）、**记录是 id 列表，内容按行取**
   （`ObjectSetDatabase.observe:24`）；StateFlow 去重那格用 Anytype 的**单调 revision 盐**
   （`DataViewSubscriptionContainer.kt:96`）。
3. **块是内存形状，Markdown 是盘上格式。** 读入解析成块、保存序列化回 `.md`，
   不新增第二种盘上格式；不可无损往返的（24 种 embed）按 Anytype 自己答案画占位。

## 3. 复用线（`packages/board_panel` 能力已实测）

| 面板 | 用/不用 | 依据 |
| --- | --- | --- |
| **Board（看板）** | ✅ 用 `BoardPanel` | 列重排 `board.dart:327`、组内重排 `board.dart:599`、**跨列拖拽** `board.dart:502-507` + `board_data.dart:285-365`、拖拽自动滚动 `drag_auto_scroller.dart:44,88-141`、列宽 `board.dart:219` + `ResponsiveGroupConstraints.resolve:72-83`、响应轴 `ResponsiveBoardDirection:97-142`、分页 `cardPageSize/loadMoreTriggerOffset:155-157`（宿主现在传 `cardPageSize: 0` 关掉，`plan_extensions_view.dart:228-232`） |
| Board 的卡片/头/脚 | ✅ 用但必须自绘 | `BoardPanelGroupCard{child,decoration}` / `BoardPanelGroupHeader{height,title,onAdd,onMore}` / `…Footer`；宿主已经在这么做（`:233-243`） |
| Board 的排序/筛选 | ❌ 包里没有 | 全包无排序（只有时间序插入 `extensions.dart:171-180`），board 无筛选（筛选只在日历 `event_controller.dart:24,55`）⇒ **排序/筛选/分组在宿主 model 层做纯函数** |
| **MonthView（日历）** | ✅ 保留 | 宿主已用 `cellBuilder + width + cellAspectRatio`，包的真实签名 `typedefs.dart:9-16`、度量点 `month_view.dart:391-396`（`height = cellHeight*6`），`PageView` 分页 `:344-365`；默认 `FilledCell` 硬编码 `fontSize: 12`（`month_view_components.dart:169,210`）⇒ 字号档位必须继续走宿主 `cellBuilder` |
| DayView / WeekView / TableCalendar | ⏸ 暂不用 | 导出可用（`day_view.dart:206-246` 等），但 Anytype 的日期面对象屏只需月网格 + 字段列表；接它属于后续 |
| **Table（表格视图）** | ❌ 不用 `ExpandableTable` | 单元格是**不透明 Widget + 每 cell 一个 ChangeNotifier**（`cell.dart:21,35`、`row.dart:165`），无 id、无泛型、表头无排序/选择回调（`table.dart:134-159`）⇒ 表头菜单/排序/多选只能宿主做；宿主现有 `_TableView` 已是这条路（文件头 `:5-10` 记了理由） |
| **List / Gallery** | ❌ 包里没有 | `lib/src/widgets/` 下无 gallery 文件 ⇒ 宿主画 |
| 组件（§7） | ❌ 全新宿主代码 | 包只有 board/calendar/table |
| 配色 | ⚠ 包读 `ShadTheme`，不读 `dsw_*`，且有硬编码 slate 兜底（`constants.dart:19-24`、`calendar_style.dart:181-235`、`card.dart:11`、`day_view.dart:231`） | ⇒ 一律**由调用点把 dsw 值传进去**（`config.groupBackgroundColor`、`decoration`、`CalendarStyle`），绝不在宿主读 shad 调色板（ADR-0002 桥头约束） |
| 不可用面 | `ReorderFlex` / `CalendarPage` / `BoardPanelGroup` 等被 `show` 或未导出 | `board_panel.dart:35-40`、`reorder_flex/*` 无导出 ⇒ 别绕过 `BoardPanel` 直接用 |

## 4. 逐段映射：Anytype §1–§7 → 本仓库交付物

### §1 数据视图（viewers）

| Anytype 作答 | 本项目交付 |
| --- | --- |
| 模型 6 档 `GRID/LIST/GALLERY/BOARD/CALENDAR/GRAPH` | `PlanViewerKind` 六值，**一一对应**（`lib/model/plan_dataview.dart`） |
| 渲染 4 档 | Table（`_DvTableView`，dsw 手画表头 + 列宽 + 分组行）、List（三行型：Default / Profile / **Task(done)**）、Gallery（`Item.Default` + `Item.Cover` + `cardSize` 大卡）、Board（`BoardPanel` 复用） |
| Calendar / Graph = `Viewer.Unsupported` + "not available on mobile yet" 文案 | **照做**：`PlanViewerUnsupported(kind)` 占位卡 + 双语 i18n 文案（`planViewCalendarUnsupported` / `planViewGraphUnsupported`），措辞对齐"改视图类型或新建一个" |
| `Size SMALL/MEDIUM/LARGE`、列 `isVisible/width/dateFormat/timeFormat/includeTime`、`cardSize/hideIcon/coverFit/coverRelationKey/groupRelationKey/groupBackgroundColors/defaultTemplate/defaultObjectType` | `PlanViewerRelation` + `PlanViewerLayout` 全字段（纯 Dart + toJson/fromJson），设置抽屉 `PlanViewerLayoutSheet` 逐个可改 |
| 排序 ASC/DESC/CUSTOM + `EmptyType NOT_SPECIFIC/START/END`（UI 只给前两种 + 空值上下，CUSTOM 内部用） | `PlanSort(type, relationKey, emptyPlacement)`；抽屉只出 2×2；**CUSTOM 留给手工排序路径**（收藏/自定义序） |
| 筛选 18 条件 + AND/OR/NO + 15 个日期快捷；嵌套/高级=桌面专属（判据 `isAdvanced()`） | `PlanFilterCondition` 18 值、`PlanFilterOperator` 3 值、`PlanFilterQuickDate` 15 值全枚举；求值函数 `evaluatePlanFilter(...)`；`isAdvanced` 同源判据（宿主不做嵌套，占位说明） |
| 视图管理：`UpdateName/Layout/Relations/Filters/Sorts/Duplicate/Delete` + 页签拖拽 + Plus | `PlanViewSetController` 七动作 + 页签条 `PlanViewerTabBar`（拖拽改序、激活、右键菜单） |
| 手工排序 `objectOrders/groupOrders` | `PlanObject.orders`（按视图 id 分键的 id 列表）+ 拖拽写回 |
| Kanban 每列独立订阅 + 分页 | `groupOrders` 按列分键 + Board 的 `onLoadMore/hasMore`（把现在关掉的 `cardPageSize` 打开成可配） |

### §2 Set / Collection / TypeSet / All Content

- `PlanCollectionKind { set, collection, typeSet }`，**成员同构**（Anytype 就是形状相同、身份与限制不同），
  差异只在：Set 有 `sourceType` 且记录按筛选实时求值；Collection 持显式成员列表；
  TypeSet = Set 的一种身份（从类型生成）。
- 默认值对齐：`defaultObjectType = ot-page`、`unsupportedFallback = BOARD`。
- Set/Collection 创建时**跳过选模板**（Anytype 的 `ObjectTypeExtensions.kt:107-130` 语义）。
- All Content：五 tab `PAGES / LISTS / MEDIA / BOOKMARKS / FILES` + 两种菜单模式
  `AllContent | Unlinked`，且状态可恢复（`RestoreAllContentState` 的等价：纯函数 + 单测）。

### §3 文档块（block）

- `PlanBlock`  sealed 树：`Text(14 档 style + 11 种 mark + 对齐 + 前景/背景色)`、
  `Layout(row/column/div/header/tableRow/tableColumn)`、`Link(target,type,iconSize,cardStyle,description)`、
  `File(kind: none/file/image/video/audio/pdf, state)`、`Bookmark(state)`、`Icon`、`Divider(line/dots)`、
  `FeaturedRelations`、`RelationBlock(key)`、`DataView(...)`、`Latex`、`Embed(processor 24 档)`、
  `TableOfContents`、`Table/TableRow(isHeader)/TableColumn`、`Widget(layout 5 档, limit, activeView)`、`Unsupported`。
- **入口按 Anytype 的真实答案**：slash 菜单是唯一插入入口，分段照抄
  Style(10) / Media(5) / Other(4，含 `table(NxM)`，行列各夹 1–25) / Objects(每个类型 + Link To + Select Date) /
  Properties(仅已存在关系) / Actions(6) / 颜色(11 档 × 两组) / 对齐(左中右)。
  ⛔ 不实现"看起来有其实没有"的那些：QUOTE、JUSTIFY、LaTeX 插入、embed 插入、synced block、
  冻结表头、合并单元格、ROW/COLUMN 并排——但**档位仍在枚举里**，渲染按 Anytype 的降级作答。
- 交互：块动作集（AddBelow/TurnInto/Delete/Duplicate/Rename/MoveTo/Style/Copy/Paste/Open…）、
  拖拽改序（复用现有 `reorder` 语义）、文内搜索（Next/Previous/Clear）、选区 markup 工具栏 8 枚。
- 限制位：`PlanObjectRestriction` 11 档 + `PlanDataViewRestriction` 3 档，UI 按位禁用。

### §4 对象类型（23 个不同 key，24 个常量）

- `PlanObjectTypeIds` 23 个 key 常量 + `all` 列表 + 四组分组函数，与 `ObjectTypeIds.kt:8-31` 逐一对齐
  （上游 `WORKSPACE` 与 `SPACE` 都等于 `"ot-space"`，故 24 个常量对应 23 个不同 key；本项目只留一个名字）；
  `_ot` 市场前缀那组镜像在 `PlanMarketplaceIds`。
- 客户端特判也照做：**Task 没有专属屏，只是 List 行形态**；Bookmark 有"新建书签记录"对话框 +
  分享接收路径；Date 有整屏（`ot-date`）；Chat/ChatDerived 有组件源；四类文件不给模板；
  Project 只出现在类型排序优先级里。
- ❌ **不发明 `goal`/`habit`**（清单 §4 已证该客户端没有），只在引导用例标签位置保留等价文案位。
- 类型管理：创建/编辑/图标/描述/推荐字段/默认模板/布局 7 档/置顶/移入回收站；
  不做 "recommended views"（Anytype 没有）。

### §5 关系（16 格式）

- `PlanRelationFormat` 16 值 + `PlanRelationSource` 4 值；**可新建只有 11 种**（照 Anytype 的门）。
- CRUD 八件套（创建/加到对象/从对象删/设 key/featured 加减/建选项/删选项/选项排序）。
- 对象信息面板分 Local / Hidden 两段 + 可编辑态；值编辑器按格式分屏（文本/数字/状态/标签/日期/文件/对象/勾选/URL/邮箱/电话）。
- ❌ 不做 "used in"（Anytype 没有）。

### §6 模板与 Gallery

- 模板用例五件（apply / create / createFromObject / get / open），`template = null` ⇒ 空白；
  类型内模板列表 + DELETE/DUPLICATE/设为默认；不给模板的类型按 §4 那组判定。
- Gallery experience：安装流的状态机（选空间 → 安装 → 完成/失败）+ "不支持"告警态；
  本项目以 mock 目录（内置 2–3 个"模板包"）驱动，不联网。

### §7 小组件（widget）

- 形态 13 种 + 辅助 3 种（`Tree/Link/SetOfObjects/Gallery/ChatList/UnreadChatList/RecentlyEdited/
  ListOfObjects/Bin/AllContent/SpaceChat/ObjectTypesGroup/Home` + `EmptyState/InviteMembers/Counter`）。
- 布局**只有 5 档** `List | CompactList | Tree | Link | View`（`Block.Content.Widget.Layout` 码值一致），
  ❌ 没有"尺寸"概念；行数上限走关系 `widgetLimit`。
- 内置源 7 个 id 全对齐：`favorite / recent / recentOpen / bin / allObjects / chat / personalFavorites`；
  源分 `Default`（具体对象/集合）与 `Bundled`（上面七个）。
- 分区 `PINNED / UNREAD / MY_FAVORITES / TYPES / RECENTLY`；动作 `ChangeWidgetType / RemoveWidget /
  EmptyBin / ChangeHome / Favorite / Unfavorite / CreateObjectOfType`；CRUD + 拖拽重排。
- 聊天类三个形态（`ChatList / UnreadChatList / SpaceChat`）的数据源 = **本 app 的会话**
  （`SessionSummary` + 未读位），不是新造一套聊天对象——映射关系写进 ADR，避免被当成"我发明了 Anytype 的聊天"。
- 🚧 Android Glance 桌面组件那一档**不复现**（Anytype 自己 manifest 全 `enabled="false"`），
  但"组件读快照而不是现查"这条设计**保留**（组件区渲染 store 的内存快照）。

## 5. 分层与命名落位（不许踩四条不变量）

```
lib/model/plan_struct.dart          # PlanStruct / PlanObject / 关系解析 / 限制位
lib/model/plan_relation.dart        # 16 格式 + 选项 + CRUD 参数
lib/model/plan_object_type.dart     # 23 内置 key + 类型对象 + 七档布局
lib/model/plan_block.dart           # 块 sealed 树 + 14 样式 + 11 标记 + 24 embed 档
lib/model/plan_dataview.dart        # 视图 6 档 / 排序 / 18 条件 / 15 快捷 / 视图配置
lib/model/plan_markdown_codec.dart  # Markdown ⇄ 块（纯 Dart，可单测）
lib/model/plan_filter_engine.dart   # 筛选/排序/分组求值纯函数
lib/model/plan_widget.dart          # 组件形态 + 5 布局 + 7 内置源 + 分区
lib/model/plan_template.dart        # 模板对象 + 应用语义
lib/model/plan_mock_content.dart    # mock 种子（纯数据，无 flutter import）

lib/state/plan_object_store.dart    # 对象/记录内存 + 可选落盘（原子 tmp+rename）
lib/state/plan_space_store.dart     # 类型/关系/模板/组件/视图配置
lib/state/plan_dataview_controller.dart  # stage + reduce + 订阅（先挂后取 + revision 盐）
lib/state/plan_block_document.dart  # 块文档 store（现有 markdown 笔记的接管者）

lib/ui/plan/dataview/…              # 视图条 / 四视图 / 抽屉 / 单元格编辑
lib/ui/plan/blocks/…                # 块渲染器 / slash / markup 工具栏 / 块动作
lib/ui/plan/library/…               # 类型屏 / 关系屏 / 模板 / Gallery / All Content / Date 屏
lib/ui/plan/widgets/…               # 主屏组件区（13 形态）
```

约束复核：`lib/model/**` 不 import `package:flutter`（门禁第 2 条）；`lib/state/**` 不 import `../ui/`
（第 3 条）；riverpod 只出现在 `app_providers.dart` + `main.dart`（第 6 条）；
`lib/ui/**` 不直接 `dart:io`（第 5 条）——落盘一律在 `lib/state`。
UI 只用 `shadcn_ui` 组件（ShadInput/ShadSelect/ShadSwitch/ShadPopover/ShadDialog/ShadButton/
ShadDatePicker/ShadChip…）+ `dsw_*` 配色 + `DswShape` 半径阶 + `primitives/tappable.dart`/
`icon_button.dart`/`menu.dart`；新令牌必须带读者（ADR-0025）；图标尺寸上 ADR-0026 那把阶梯。

## 6. 七阶段提交计划（每段：实现 → 三门禁 → 一次提交）

| 阶段 | 交付 | 提交信息（Conventional Commits） |
| --- | --- | --- |
| P0 | 本文 + ADR-0037 + 登记表行 + AGENTS.md 索引 | `docs(adr): land ADR-0037, anytype dataviews in plan mode` |
| P1 | `lib/model/plan_*` 十个纯 Dart 文件 + 单测（filter/sort/group/struct/markdown codec） | `feat(model): give the plan workspace an anytype-shaped object core` |
| P2 | `lib/state/plan_*` 四件 + `app_providers.dart` 新 `@Riverpod` + codegen + `main.dart` override + mock 种子 | `feat(state): store and riverpod seams for the plan object core` |
| P3 | 数据视图 UI：视图条 + Table/List/Gallery + 不支持占位 + 视图管理/排序/筛选/布局抽屉 | `feat(ui): table, list and gallery viewers in the plan workspace` |
| P4 | Board 视图接回 `BoardPanel`（分组列 = 状态关系选项，跨列拖拽、分页、列宽）+ 手工排序 | `feat(ui): kanban viewer over board_panel with grouped state options` |
| P5 | 块文档：渲染器 + slash + markup 工具栏 + 块动作 + 表格块 + Markdown 编解码接管现有笔记 | `feat(ui): block document with slash insertion in plan notes` |
| P6 | 类型 / 关系 / 模板 / Gallery / All Content / Date 屏 | `feat(ui): object types, relations, templates and all-content screens` |
| P7 | 主屏组件区（13 形态 + 5 布局 + CRUD + 重排）+ 侧栏入口从三行改成集合列表 + 守卫补齐 | `feat(ui): home widget strip for the plan workspace` |

每阶段结束跑：`flutter pub get` → `dart format --set-exit-if-changed lib test tool spike` →
`dart analyze --fatal-infos lib test tool spike` → `flutter test`（口径：**零新增失败**，基线 `+963 -2`）。
主题相关改动另跑 `dart tool/contrast_check.dart`。

## 7. 每段守卫（新增测试，不写"看起来像验证"的空测试）

- **P1**：`test/plan_struct_test.dart`（关系读时解析 / amend-unset 差异）、
  `test/plan_filter_engine_test.dart`（18 条件逐个 + 3 运算符 + null 值语义 + 15 日期快捷边界）、
  `test/plan_dataview_test.dart`（排序含 CUSTOM、分组、限制位）、
  `test/plan_markdown_codec_test.dart`（往返幂等：`md → blocks → md` 字节稳定；不可表达块降级为占位）。
- **P2**：`test/plan_object_store_test.dart`（真实临时目录：原子写、corrupt 读空、订阅计数、
  先挂订阅再取快照不漏事件）、`test/plan_providers_test.dart`（store 保存 → provider 读者刷新，
  即 `invalidateSelf` 那条坑的守卫，沿 `test/app_providers_test.dart` 先例）。
- **P3–P7**：每个面一棵 widget 测试（`plan_dataview_*_test.dart` / `plan_blocks_test.dart` /
  `plan_library_test.dart` / `plan_widgets_test.dart`），且**每个新面挂进 `test/amplified_text_probe.dart`
  的两档尺子**（1.8x 与 2.2x，挂到 `MaterialApp.builder` 那道缝，不是 `home:`）；
  视图不支持占位要断言"画的是那句话"；跨列拖拽要在**竞技场 settle 之后再越过 slop**（那条测试坑在
  `workflow.md` 里已记）；抽屉里的行必须是 `Expanded`（行里自由文本要有 flex 上界）。
- 全局：`l10n_parity_test`（新键双语同键）、`theme_token_test`（半径在阶 + 令牌有读者 + 样式名不说谎）、
  `tap_affordance_test`（不新增手写 `GestureDetector`）、`icon_button_test`（不造私有图标按钮）、
  `architecture_check_test`（七条规则）、`menu_chrome_test`（浮层的皮只在主题里说一次）。

## 8. 诚实边界（写下来，避免日后被当成"已实现"）

1. **mock 不等于真源**：类型/关系/视图的持久化形状已按生产写，但数据来自
   `plan_mock_content`；接真源（盘上对象文件或中间件）要另立 ADR。
2. **多人协作不复现**：Anytype 的邀请/成员/权限/QI 一对一都建立在空间协议上，
   本项目没有对应核心；清单 §9 那部分不在本 ADR 范围。
3. **Calendar / Graph 视图刻意不支持**，与 Anytype Android 一致；日历能力放在 Date 对象屏（§4），
   那里才是 Anytype 真正画日历的地方。
4. **Android Glance 桌面组件不复现**（上游自己都 `enabled="false"`）。
5. **24 种 embed 与 LaTeX 的"能渲染不能插入"**：本项目同样只渲染能无损往返的那几档，
   embed 一律占位；这是"完全一致"的一部分，不是缺口。
6. **观感仍需真机走查**：门禁证明形状，不证明像素。交付说明按 `build.md` §0 标"待 macOS 验证"。
