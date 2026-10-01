# 企划模式复刻实现对照表（模块 1–7）

> 功能契约来源：2026-10-01 用户简报（"以企划模式复刻 anytype-kotlin"）。
> 上游真值：`docs/anytype-feature-inventory-2026-10-01.md`（`_archive_project/anytype-kotlin` @ `7af5254` = 0.50.4）。
> 架构：**ADR-0037 不变**（2026-10-01 用户拍板）。简报的"硬约束"技术栈不引入
> （freezed / json_serializable / go_router / drift / 全量 Notifier / 新目录树），
> 等价映射：domain/models→`lib/model/plan_*`、data→`lib/state/plan_object_store.dart`（唯一副作用出口）、
> application→store/controller + `app_providers.dart` 读缝、presentation→`lib/ui/plan/**`。
> 简报判据「只复刻客户端到底答了什么」与上游事实冲突时**以上游代码为准**，偏差全部落在下表。
>
> 状态列语义：**✅ 已复刻** / **🚧 复刻(默认态)** / **⛔ 占位**（按上游自己的降级作答）/ **❌ N/A**（上游根本没有）/
> **🔁 扩展**（简报要求、超出上游移动端作答，逐条给理由）/ **🔨 Pn**（计划在第 n 阶段落，见施工表 §6）。
> 每完成一项把 🔨Pn 改成最终状态并回填代码路径；此表无空白行才算 DoD 达成。

## 0. 简报修正裁决（2026-10-01 三路深读证实）

| # | 简报说法 | 裁决 | 上游证据 |
| --- | --- | --- | --- |
| 1 | AC3-1 QUOTE 不给插入 | **更正：可插**，slash Style 段 "Highlighted" 即 QUOTE；不可插入的是 TITLE/H4/DESCRIPTION | `SlashExtensions.kt:22-33,61-72` → `EVM:7096-7103` → `MapperExtension.kt:417-438`；早批审计 ⛔ 系误记，`plan_block.dart` 已修（insertable 11 种） |
| 2 | AC3-1 "Title" 样式 | **更正：slash 的 Title 插的是 H1**；TITLE 样式仅由核心产出（DV 内嵌标题），无 UI 插入路径 | `SlashExtensions.kt:31`（Title→HEADER_ONE）、`MapperExtension.kt:419`、`Style.TITLE` 仅中间件映射+测试夹具 |
| 3 | AC3-7 表格动作 Sort/Copy | Column.Sort / Column.Copy / Row.Copy 是死代码（定义未进 UI，点击落 not implemented）；SetTableRowHeader 注入未调用 → ⛔ 不实现 | `TableCellExt.kt:413-488`、`EVM:9287-9289`、`EditorTableDelegate.kt:93` |
| 4 | AC1-5 18 条件逐一可选 | 18 是模型全集；条件选择器**按格式暴露子集**（Text 7 / Number 9 / Date 9 / Select 6 / Checkbox 3） | `Block.kt:367-371`、`Viewer.kt:214-426` |
| 5 | AC1-8 objectOrders / groupOrders 写路径 | objectOrders 写路径照做；groupOrders（列序/隐藏/着色）写回是 **🔁 扩展**（上游移动端只读，桌面端能力），理由：简报 AC1-8 明确要求且 store 已有 setGroupOrder | `ObjectSetViewModel.kt:2395-2434` vs `:1722-1733` |
| 6 | AC3-2 slash 六段 | 主菜单 **9 段**（Style/Media/Objects/Properties/Other/Actions/Alignment/Color/Background）；六内容段说法对内容段成立 | `SlashExtensions.kt:49-59` |
| 7 | AC3-16 编辑器 7 模式 | 实为 **8 模式**（+Table）；SAM 的桌面等价 = 拖拽（🔁 映射登记） | `Editor.kt:19-94` |
| 8 | AC3-20 文内搜索 5 事件 | **6 个**（Query 是第六个） | `SearchInDocEvent.kt:3-9` |
| 9 | AC3-17 动作集合 17 项 | **20 个枚举值**，面板按条件装配 | `ActionItemType.kt:4-54`、`EVM:2510-2624` |
| 10 | AC1-6 ViewEditAction 7 项 | **9 个 variant**（Dismiss/UpdateName/Layout/Relations/Filters/Sorts/More/Duplicate/Delete） | `ViewerEditWidgetUi.kt:30-40` |
| 11 | AC1-7 布局抽屉 5 组 | 非 Board 5 组；**Board 下 7 组**（+ColorColumns/GroupBy） | `ViewerLayoutWidgetUi.kt:108-121` |
| 12 | AC2-3 从类型生成 Set | 上游 UI 已铺**未接线**（仅 Preview 引用）→ 🔁 替上游补完并登记 | `ObjectsHeaderScreen.kt:101-153,207`、`UiState.kt:104-111` |
| 13 | AC6-2 模板预填横幅 | 实为模板编辑屏信息条 "You're editing a template of X"（无预填语义、无 dismiss）；另：选择器 Blank 卡被上游注释禁用（DROID-3340），null 模板语义保留在创建路径 | `fragment_editor.xml:64-104`、`EditorTemplateFragment.kt:132-159`、`TemplateSelectViewModel.kt:71-78` |
| 14 | AC6-3 Gallery 不支持告警 | 上游该告警是**死目的地**（注册无导航调用）→ 桌面版实现完整 mock 安装流（状态机 3 态 Hidden/Loading/Success） | `GalleryInstallationState.kt:8-13`、`graph.xml:306-307` |
| 15 | AC1-9 Kanban | 分组格式白名单 {STATUS,TAG,CHECKBOX}；"No value" 列仅 status/tag 合成；Date 分组列跳过；CardSize 桌面 3 档全开（移动 2 档是设备妥协） | `BoardColumnQuery.kt:18-75`、`ObjectSetViewModel.kt:4697-4712` |
| 16 | AC3-21 撤销/重做 | 上游=服务端历史（本项目无核心）→ 🔁 本地命令栈实现 | `domain/page/Undo.kt`、`Redo.kt` |
| 17 | 新建视图 = 复制；SetActive 无 RPC | Plus 新建视图底层是 DuplicateDataViewViewer；activeViewerId 是会话态不是后端态 | `ViewerDelegate.kt:78-107` |
| 18 | 对象信息关系列表 | file 段被 `if (false)` 关闭、整段"编辑模式"是注释死代码 → 不复刻这两样 | `RelationListViewModel.kt:204-208,493-507` |
| 19 | 编辑器造块的盘上表达（P8-a 裁决，2026-10-01 审计） | Markdown 词汇装不下的块（Bookmark/TOC/Embed/Link/Widget/Relation/Featured/带色段/Toggle/Callout/Title/underline mark）写 `<!-- plan:{json} -->` 信封——合法 Markdown、渲染为空、重开还原；修复"保存即消失"与 `![null]()` 垃圾行；空 checkbox 行不再被吞；slash 的 Title 经模型 `textStyleFor` 单点映射（=H1，与 4ffb414 对齐） | `plan_markdown_codec.dart`（_envelope/_markdownCarries）、`plan_block_editor.dart`（contentFor） |

## 1. 模块 1：数据视图（Data View / Viewers）

| 子功能 | 上游档位 | 状态 | 施工 | 代码路径 | 状态层 | shadcn 组件 |
| --- | --- | --- | --- | --- | --- | --- |
| 视图模型 6 档（GRID/LIST/GALLERY/BOARD/CALENDAR/GRAPH） | ✅ | ✅ 已复刻 | P1 | `lib/model/plan_dataview.dart:19-56` | — | — |
| 列配置 ViewerRelation（isVisible/width/dateFormat/timeFormat/includeTime） | ✅ | ✅ 已复刻 | P1 | `plan_dataview.dart:128-189` | — | — |
| 视图可配项全字段（cardSize/hideIcon/coverFit/coverRelationKey/groupRelationKey/groupBackgroundColors/defaultTemplate/defaultObjectType） | ✅ | ✅ 已复刻（模型） | P1 | `plan_dataview.dart:456-586` | — | — |
| Table（GRID）渲染：表头/行共用横向滚动器、单元格按格式分发 | ✅ | ✅ 已复刻 | P3 | `lib/ui/plan/dataview/plan_viewers.dart` | `planObjectStore.stageFor` | ShadCheckbox；单元格经 `plan_cell_value.dart` |
| List 三行型 Default/Profile/Task(done)（AC1-1） | ✅ | ✅ 已复刻 | P3 | `plan_viewers.dart`（PlanListViewer） | 同上 | DswHoverTap（勾选） |
| Gallery 两卡型 Default/Cover + largeCards（AC1-2） | ✅ | ✅ 已复刻 | P3 | `plan_viewers.dart`（PlanGalleryViewer，cardSize 三档） | 同上 | ShadCard 形状走 DswShape |
| Calendar 视图 | ⛔(上游) | 🔁 扩展（2026-10-01 用户拍板：旧日程面板能力迁入集合 Calendar 视图，MonthView 宿主画格，超出上游移动端"不支持"作答；Graph 仍为诚实占位） | P3+ | `plan_calendar_viewer.dart`（PlanUnsupportedViewer 只剩 graph） | stage.records 按日期键分组 | board_panel MonthView |
| 排序 UI：ASC/DESC + 空值首/尾；CUSTOM 仅内部（AC1-4） | ✅ | ✅ 已复刻 | P3 | `plan_viewer_sheets.dart` | store.`_writeViewer` | ShadSelect |
| 筛选 UI：AND/OR/NO + 按格式条件子集 + 15 日期快捷（AC1-5） | ✅ | ✅ 已复刻 | P3 | `plan_viewer_sheets.dart`；求值 `lib/model/plan_filter_engine.dart` | 同上 | ShadSelect + ShadPopover |
| 高级/嵌套筛选 | ⛔ | ⛔ 占位（模型保留形状，UI 只显示占位名） | P3 | `plan_dataview.dart:390-452` | — | — |
| 视图管理 9 动作 + 页签增删/拖拽/激活（AC1-6） | ✅ | ✅ 已复刻 | P3 | `plan_viewer_bar.dart` + sheets | store（viewer CRUD，最后一个不可删） | DswMenu（封装） |
| 布局抽屉 5+2 组（AC1-7） | ✅ | ✅ 已复刻 | P3/P4 | `plan_viewer_sheets.dart` | store.`_patchView` | ShadSwitch / ShadSelect |
| objectOrders 拖拽写回（AC1-8） | ✅ | ✅ 已复刻 | P3/P4 | viewer 拖拽回调 | store.`setManualOrder` ✅P2 | — |
| groupOrders 列序/隐藏/着色写回 | ✅(桌面) | ✅ 已复刻（🔁 扩展：上游移动端只读） | P4 | `plan_board_viewer.dart` | store.`setGroupOrder` ✅P2 | — |
| Board/Kanban：分组列=选项、跨列拖拽、每列分页（AC1-9） | 🚧 | ✅ 已复刻（默认态开放） | P4 | `plan_board_viewer.dart` 复用 `packages/board_panel`；分页窗口 = 包的 cardPageSize(50) 触底增长，store 持全量列（等价性登记） | store.stageFor 分组 | BoardPanel 自绘卡 |
| 新建视图 = 复制当前视图；activeViewerId 为会话态 | ✅ | ✅ 已复刻 | P3 | `plan_viewer_bar.dart` | store.`duplicateViewer`；activeViewerId 不落盘 | — |
| 勾选类分组读成两列（空值并入未勾选） | ✅ | ✅ 已复刻 | P4 | `plan_filter_engine.dart`（groupPlanRecordIds 归一） | — | — |
| 彩色列（groupBackgroundColors，上游 Boolean） | ✅ | ✅ 已复刻（表头带着色；整列体着色待包提供按组底色，登记） | P4 | `plan_board_viewer.dart` headerBuilder | — | — |

## 2. 模块 2：Set / Collection / TypeSet / All Content

| 子功能 | 上游档位 | 状态 | 施工 | 代码路径 | 状态层 | shadcn 组件 |
| --- | --- | --- | --- | --- | --- | --- |
| 三种身份同构（成员同、限制不同） | ✅ | ✅ 已复刻 | P1 | `lib/model/plan_dataview.dart:675-804` | — | — |
| 创建跳过选模板（null 模板=空白） | ✅ | ✅ 已复刻（语义） | P1/P2 | `lib/state/plan_object_store.dart` createRecord | store | — |
| 从类型生成 Set（CreateSet/OpenSet/Hidden 三态） | ✅ | ✅ 已复刻（🔁 扩展：替上游补完未接线入口） | P6 | `plan_create_collection.dart` + store.`createSetOfType` | store.`createCollection`（mint id + 推荐关系播种） | ShadDialog |
| All Content 5 tab（PAGES/LISTS/MEDIA/BOOKMARKS/FILES） | ✅ | ✅ 已复刻 | P6 | `lib/ui/plan/library/plan_all_content_screen.dart` + `lib/model/plan_all_content.dart` | store.objects 按 tab 的类型清单过滤 | DswHoverTap 签条 |
| All Content 两种菜单模式 AllContent/Unlinked + 状态恢复 | ✅ | ✅ 已复刻（状态经 onStateChanged 回流；持久化随工作区偏好 🔨） | P6 | 同上 | PlanAllContentState（RestoreAllContentState 等价） | — |
| 时间分组 Today/Yesterday/Previous7Days/14Days/Month/Year | ✅ | ✅ 已复刻（now 可注入，空桶丢弃，未来日期读作今天） | P6 | `plan_all_content.dart`（groupPlanAllContent） | 纯函数 | — |

## 3. 模块 3：文档块（Block）

| 子功能 | 上游档位 | 状态 | 施工 | 代码路径 | 状态层 | shadcn 组件 |
| --- | --- | --- | --- | --- | --- | --- |
| 14 样式建模 / 11 可插（AC3-1，含 QUOTE 更正） | ✅ | ✅ 已复刻 | P1(更正 10-01) | `lib/model/plan_block.dart:36-52` | — | — |
| slash 菜单（AC3-2；主菜单插入集合照上游；table(NxM) 夹 1–25） | ✅ | ✅ 已复刻（P8-c）：输入过滤随打字收窄；Style/Media/Other 三段全插；**Simple table 落真表格（3×3 表头行，table(NxM) 解析模型就绪、尺寸输入待接）**；Objects/Properties 诚实空态；对齐/颜色/背景由工具栏回答；Actions 由块菜单回答 | P5/P8-c | `plan_block_editor.dart`（_SlashSheetState）+ store.`insertTable` | PlanBlockDocument | ShadDialog + ShadInput |
| 选区工具栏 8 mark（AC3-3） | ✅ | ✅ 大部分已落（P8-c）：选区工具栏 bold/italic/strike/underline/keyboard/link 六钮 + 颜色/背景改选区优先（outlined=未应用/ghost=已应用）；MENTION/EMOJI/OBJECT 仍为渲染态 mark；**编辑面非所见即所得**（ShadInput 纯文本；富文本外观仅读视图/搜索态/Preview——WYSIWYG 需富文本编辑依赖，另立 ADR） | P5/P8-c | `plan_block_editor.dart`（选区回调+mark 钮）+ `plan_block_view.dart`（选区上报） | PlanBlockDocument.applyMark | DswIconButton.outlined |
| 颜色 11 档 × 文本/背景（AC3-4） | ✅ | ✅ 已复刻（P5：工具栏两个颜色菜单，作用于聚焦块；mark 级颜色随上一行） | P5 | `plan_block_editor.dart`（_ColorSelect）+ `planLadderColor` | PlanBlockDocument | DswContextMenu |
| 对齐左中右；JUSTIFY ⛔（AC3-4） | ⛔ | ✅ 已复刻（justify.isInsertable=false；HIGHLIGHT 无中档已入模型） | P1 | `plan_block.dart`（PlanAlign/supportsCenterAlignment） | — | — |
| Toggle / Callout / 分隔线 / TOC / FeaturedRelations / Relation 块 / 嵌套（AC3-5） | ✅ | ✅ 已复刻（P5 渲染器；toggle 展开态与 callout 图标编辑 🔨） | P5 | `lib/ui/plan/blocks/plan_block_view.dart` | PlanBlockDocument | — |
| ROW/COLUMN 展平（AC3-6） | ⛔ | ✅ 已复刻 | P1/P5 | `plan_block.dart` + `plan_block_view.dart`（PlanBlockRow 递归） | — | — |
| 表格块三 tab 动作（AC3-7，死代码动作 ⛔ 不做） | ✅/⛔ | ✅ 部分已落（P5）：行级插入/移动/复制/清空/删除进块菜单；Cell 清空走 store；列级插入/删除在 store 有、UI 🔨；Sort/Copy ⛔ 照上游死代码不做 | P5 | `plan_block_actions.dart`（planTableRowActions）+ `plan_block_document.dart` 表格族 | PlanBlockDocument | DswContextMenu |
| 文件块 6 型 4 态；PDF/FILE 文件卡（AC3-8） | ✅ | ✅ 部分已落（P5）：四态渲染 + 按型分图标；图片全屏/选择器 🔨（笔记面尚无上传管线） | P5 | `plan_block_view.dart`（_FileBlock） | PlanBlockDocument | ShadCard 形状 |
| 视频/音频内嵌播放 | ✅(上游) | 🔁 偏差：本仓库无播放器依赖 → 首版按文件卡+外部打开；要内嵌须另立 ADR 加依赖 | P5 | — | — | — |
| 书签 4 态 + URL 可编辑（AC3-9） | ✅ | ✅ 部分已落（P5）：四态渲染；URL 录入对话框 🔨 | P5 | `plan_block_view.dart`（_BookmarkBlock） | PlanBlockDocument | ShadCard 形状 |
| 链接块四组枚举 + 外观面板（AC3-10） | ✅ | ✅ 部分已落（P5）：text/card 两形态按 cardStyle 渲染；外观面板 🔨 | P5 | `plan_block_view.dart`（_LinkBlock） | PlanBlockDocument | — |
| @提及面板（Date/ObjectType/Profile/Task/Deleted）（AC3-11） | ✅ | 🔨 P6（提及的目标对象随对象库到达；mention mark 渲染已落） | P6 | `lib/ui/plan/blocks/` | store 查询 | ShadPopover |
| 嵌入 24 provider 统一占位卡（AC3-12） | ⛔ | ✅ 已复刻（占位卡标注 opens-externally / not-available） | P1 模型 / P5 UI | `plan_block_view.dart`（_EmbedBlock） | — | ShadCard 形状 |
| LaTeX 渲染但无插入入口 | ✅/⛔ | ✅ 已复刻（gpt_markdown 渲染；无插入入口照上游） | P5 | `plan_block_view.dart`（_LatexBlock） | — | — |
| 对象图标（emoji/自定义图/矢量图标）（AC3-13） | ✅ | 🔨 P5/P6；🔁 规模差异：上游 391 枚矢量图标与全量 emoji.json 不整体搬运，用精选集 | P5/P6 | — | — | ShadPopover |
| 封面（8 渐变+12 纯色+设备图）（AC3-14）；Unsplash | ✅/❌ | 🔨 P6；Unsplash ❌ N/A（无网络源，登记） | P6 | — | — | ShadDialog |
| 空间壁纸 Solid/Gradient/None（AC3-15） | ✅ | 🔁 扩展：作用于企划工作台容器 | P6 | — | — | ShadSelect |
| 编辑器 8 模式 + 锁/解锁（AC3-16；SAM=拖拽映射 🔁） | ✅ | ✅ 部分已落（P5）：Edit/Read 两面 + 搜索自动转只读（与上游同一决定）；Locked/Select/Styling/Table 独立模式 🔨 | P5 | `plan_block_editor.dart`（readOnly/searching） | PlanBlockDocument | — |
| 动作集合 20 项按条件装配（AC3-17） | ✅ | ✅ 部分已落（P5）：duplicate/delete/moveRoot 按块装配；TurnInto/样式走工具栏；其余（MoveTo/Rename/Download…）随媒体与对象屏 🔨 | P5 | `plan_block_actions.dart` | PlanBlockDocument | DswContextMenu |
| 拖拽三段落点 + 自动滚动 200px/350px·60ms（AC3-18） | ✅ | 🔨（第一版为工具栏 moveRoot 上/下移；三段落点拖拽待接） | P5+ | `plan_block_document.dart`（moveRoot） | — | — |
| 剪贴板：内部块 + 系统 HTML 粘贴（AC3-19） | ✅ | 🔨 | P5+ | — | — | — |
| 文内搜索 6 事件（AC3-20） | ✅ | ✅ 已复刻（Query/Search 计数/Next/Previous/Clear/Cancel；搜索自动转只读；ensureVisible 滚动定位） | P5 | `plan_block_editor.dart`（_search* 族） | PlanBlockDocument | ShadInput |
| 撤销/重做（AC3-21） | ✅(服务端) | ✅ 已复刻（🔁 扩展：本地快照栈，深度 50，id 保持） | P5 | `plan_block_document.dart`（_undoStack/undo/redo） | PlanBlockDocument | DswIconButton |
| 限制位 ObjectRestriction 11 / DataViewRestriction 3（AC3-22） | ✅ | 模型 ✅P1；UI 按位禁用 🔨 P6（数据视图的 3 档已在 P3 落：views/relation/createObject 门 +、新建与抽屉） | P1/P3/P6 | `plan_struct.dart:60-91`、`plan_data_view_screen.dart` | — | — |

## 4. 模块 4：对象类型（23 key）

| 子功能 | 上游档位 | 状态 | 施工 | 代码路径 | 状态层 | shadcn 组件 |
| --- | --- | --- | --- | --- | --- | --- |
| 23 内置 key（24 常量去重）+ 市场前缀（AC4-1） | ✅ | ✅ 已复刻 | P1（勘误 e6384aa） | `lib/model/plan_object_type.dart:12-133` | — | — |
| 分组函数 getTypesWithoutTemplates/getFileTypes/getSystemTypes/getSetTypes | ✅ | ✅ 已复刻 | P1 | 同上 | — | — |
| ot-task 仅 List 行形态，无专属屏 | ✅/❌ | ✅ 已复刻（行形态 🔨P3 UI） | P1/P3 | `plan_object_type.dart` + viewers | — | — |
| ot-bookmark 新建记录对话框；无书签库屏 | ✅/❌ | 🔨 P6 | P6 | library | store.createRecord | ShadDialog |
| ot-date 整屏（相对日期头/字段条/对象列表）+ 仅 Link 组件 | ✅ | ✅ 已复刻（相对日期头 + 按日串扫描的对象列表，锚记录排除自身；日历弹层 🔨） | P6 | `plan_date_screen.dart` | store.objects 扫描 | — |
| ot-chat/chatDerived 组件源 = 本 app 会话（ADR-0037 已决） | ✅ | 🔨 P7 | P7 | `lib/ui/plan/widgets/` | 会话读缝 | — |
| ot-project 仅类型排序优先级 | 🚧 | ✅ 已复刻 | P1 | `plan_object_type.dart` sortPriority | — | — |
| 四类文件不给模板 | ✅ | ✅ 已复刻 | P1 | typesWithoutTemplates | — | — |
| 无 goal / habit（AC4-3） | ❌ | ❌ N/A 已登记 | — | — | — | — |

## 5. 模块 5：关系（Relation）

| 子功能 | 上游档位 | 状态 | 施工 | 代码路径 | 状态层 | shadcn 组件 |
| --- | --- | --- | --- | --- | --- | --- |
| 16 格式建模 / 11 可新建（AC5-1） | ✅ | ✅ 已复刻 | P1 | `lib/model/plan_relation.dart:37-49` | — | — |
| normalizeValue 按格式归一 | ✅ | ✅ 已复刻 | P1 | `plan_relation.dart:113-249` | — | — |
| CRUD 八件套（AC5-2） | ✅ | ✅ 已复刻（store 全量：创建/加对象/移除/featured/hidden/选项增删序；UI 面板行菜单 + 添加关系菜单） | P2/P6 | `plan_object_store.dart` + `plan_object_info_screen.dart` | store | DswContextMenu |
| 对象信息 Local/Hidden 两段（AC5-3；file 段与编辑模式 ⛔ 照上游死代码不复刻） | ✅ | ✅ 已复刻（featured/local/hidden 三段 + featured/hidden 开关写回 + 移除走确认框） | P6 | `plan_object_info_screen.dart` | store.`setRelationFeatured/Hidden` | DswContextMenu |
| 值编辑器按格式分屏（AC5-4） | ✅ | ✅ 已复刻（与数据视图共用 PlanCellEditor——两表面一个读法；标签/状态选项选择器、复选行内翻转、文本输入） | P6 | `plan_viewer_sheets.dart`（PlanCellEditor） | store.`amendRecord` | ShadInput |
| 无 used-in/used-by 屏（AC5-4） | ❌ | ❌ N/A 已登记 | — | — | — | — |

## 6. 模块 6：模板与 Gallery Experience

| 子功能 | 上游档位 | 状态 | 施工 | 代码路径 | 状态层 | shadcn 组件 |
| --- | --- | --- | --- | --- | --- | --- |
| 五用例（Apply null=空白 / Create / CreateFromObject / Get / Open）（AC6-1） | ✅ | 模型 ✅P1 + store ✅P2；UI 🔨 P6 | P6 | `lib/model/plan_template.dart` + store | store | — |
| 类型内模板列表 + 菜单（SetAsDefault/Edit/Duplicate/Delete）（AC6-2） | ✅ | ✅ 已复刻（设默认写类型指针+isDefault 位；复制带 (1)；删除走确认框；allowsTemplates 之外的类型如实说明） | P6 | `plan_templates_screen.dart` + store.`duplicateTemplate` | store | DswContextMenu |
| 对象菜单"设为模板" + 模板编辑信息条（AC6-2，裁决 #13） | ✅ | ✅ 已复刻（store.`createTemplateFromObject`；信息条=模板屏标题"Templates · {type}"） | P6 | `plan_object_store.dart` | store | — |
| Gallery 安装流 mock 状态机（idle/Loading/Success）（AC6-3） | ✅ | ✅ 已复刻（2 个内置包；安装=按 manifest 类型建 Set + 首条记录；"不支持"按桌面端实现完整流，裁决 #14） | P6 | `plan_gallery_screen.dart` + `planGalleryPackages` | mock 种子 | — |

## 7. 模块 7：小组件（Widget）

| 子功能 | 上游档位 | 状态 | 施工 | 代码路径 | 状态层 | shadcn 组件 |
| --- | --- | --- | --- | --- | --- | --- |
| 13 形态 + 3 辅助（AC7-1；聊天三形态数据源=本 app 会话） | ✅ | ✅ 已复刻（strip 渲染 5 布局全档 + 分区；聊天三形态按 ADR-0037 映射会话读缝，Glance ❌ N/A） | P1/P7 | `plan_widget.dart` + `lib/ui/plan/widgets/plan_widgets_screen.dart` | store.`widgets` | ShadCard 形状 |
| 5 布局（码值 TREE1/LINK0/LIST2/COMPACT_LIST3/VIEW4）+ limit 走 widgetLimit/块 limit；无尺寸概念（AC7-2） | ✅/❌ | 模型 ✅P1；UI 🔨 P7 | P7 | `plan_widget.dart:13-159` | store | — |
| 内置源 7 id + Source.Default/Bundled/Other + 分区 5 段（AC7-3） | ✅ | ✅ 已复刻（模型） | P1 | `plan_widget.dart` | — | — |
| 操作 CRUD + 下拉动作（applies 门）（AC7-4） | ✅ | ✅ 已复刻（applies 门：仅 Bin 给 Empty Bin；remove/changeLayout/favorite 写回 store；换布局循环五档 = 第二屏选择器等价） | P1/P7 | `plan_widgets_screen.dart` | store.`removeWidget/changeWidgetLayout` | DswContextMenu |
| 两屏选择器：源三段 → 布局按源 1–4 项（AC7-5） | ✅ | 🔨（桌面增量：换布局循环 + 新建走 createCollection；完整两屏 🔨） | P7+ | — | store | ShadDialog |
| Android Glance 桌面组件（AC7-6） | 🚧 | ❌ N/A（上游 manifest 全 disabled）；"组件读快照"设计保留 = store 内存快照 | — | — | store | — |
| 侧栏集合列表 + 库区导航（P8-b） | ✅ | ✅ 已复刻（2026-10-01 二次拍板：企划侧栏 = 集合组（带 + 新建集合对话框）+ 库组（All Content / 主屏组件 / 回收站 / Gallery），对话模块（新会话+会话列表）仅在代理模式；PlanExtensionView 扩为六值；行菜单接对象信息屏、集合菜单接模板屏、回收站展开屏修活 Restore） | P8-b | `sidebar.dart`（_libraryBody）+ `plan_bin_screen.dart` + `plan_data_view_screen.dart`（_openObjectInfo/_openTemplates） | store.collections/binRecords | DswContextMenu |

## 8. 守卫与门禁映射（每阶段）

- 三门禁：`dart format --set-exit-if-changed lib test tool spike` → `dart analyze --fatal-infos lib test tool spike` → `flutter test`（零新增失败，基线两条既有失败不变）。
- 结构守卫：`l10n_parity` / `theme_token` / `tap_affordance` / `icon_button` / `menu_chrome` / `shad_radius` / `architecture_check`。
- 每个新 UI 面挂 `test/amplified_text_probe.dart` 两档（1.8x/2.2x，`MaterialApp.builder` 缝）。
- 主题相关改动跑 `dart tool/contrast_check.dart`。
