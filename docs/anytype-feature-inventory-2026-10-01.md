# Anytype 功能清单（代码实证）

> 取证对象：`anyproto/anytype-kotlin`，head **`7af5254`**（提交信息 `version 0.50.4`，2026-09-26），
> 本机只读副本在 `_archive_project/anytype-kotlin/`（gitignore 内）。
> 规模实测：3058 个 `.kt` / 532,422 行 / 36 个 Gradle 模块。
>
> **本文所有条目都带 `path:line`**，路径相对该副本根。行号只对 `7af5254` 有效；上游移动后需按 §20 重跑。
> 这是**清单不是待办**：任何"要不要做对应能力"都要按 `.qoder/rules/workflow.md` §7 先立 ADR。

## 0. 四档标记（避免把"模型里有"当成"功能有"）

| 标记 | 含义 |
| --- | --- |
| ✅ | 已实现，用户可达 |
| 🚧 | 有实现，但被实验开关 / 清单开关 / 平台条件门控 |
| ⛔ | 只存在于数据模型或 wire 协议里，Android **没有渲染路径也没有入口** |
| ❌ | 该客户端里根本没有（容易被营销文案或桌面版误当成已有） |

一条贯穿全表的判据：**wire/proto 枚举 ≠ 视图能力**。Anytype 的模型层是跨平台共用的，Android 客户端对
每一档都显式作答——要么渲染，要么画一张"not available on mobile yet"的占位（`Viewer.Unsupported`），
要么根本没有插入入口。这份清单按"客户端到底答了什么"来记。

---

## 1. 数据视图（Data View / viewers）——用户问的 kanban / table / gallery 在这里

线上模型声明 **6 种视图**：`core-models/src/main/java/com/anytypeio/anytype/core_models/Block.kt:294-301`
（`GRID` `LIST` `GALLERY` `BOARD` `CALENDAR` `GRAPH`）。客户端实际作答：

| 视图 | 档位 | 客户端类 / 证据 |
| --- | --- | --- |
| Table（`GRID`） | ✅ | `presentation/.../sets/model/Viewer.kt:32` `GridView`（`.Row` `:41`）；widget `core-ui/.../widgets/dv/` |
| List（`LIST`） | ✅ | `Viewer.kt:100` `ListView`，行分三型：`Default:110` / `Profile:118` / **`Task:126`（带 done 状态）** |
| Gallery（`GALLERY`） | ✅ | `Viewer.kt:65` `GalleryView`；卡片两型 `Item.Default:78` / `Item.Cover:86`；`largeCards:69` |
| Kanban（`BOARD`） | 🚧 | `Viewer.kt:136` `Board`（`Column:145`、`Card:157`）+ `core-ui/.../widgets/dv/board/BoardScreen.kt`。**开关**：`presentation/.../relations/ObjectSetRenderMapper.kt:145-147` 关掉时降级成 `Viewer.Unsupported(TYPE_KANBAN)`；用户可切位 `presentation/.../settings/ExperimentalFeaturesViewModel.kt:20-48`，持久键 `prefs.device.kanban_enabled`（`persistence/.../repo/DefaultUserSettingsCache.kt:1158`），**出厂默认 true**（同文件 `:61-63`） |
| Calendar（`CALENDAR`） | ⛔ | `ObjectSetRenderMapper.kt:188-190` → `Viewer.Unsupported.TYPE_CALENDAR`；文案 `localization/src/main/res/values/strings.xml:1466` |
| Graph（`GRAPH`） | ⛔ | `ObjectSetRenderMapper.kt:191-193` → `TYPE_GRAPH`；文案 `strings.xml:1467` |

`Viewer.Unsupported` 的四档常量在 `Viewer.kt:19-30`（`TYPE_KANBAN=0` `TYPE_CALENDAR=1` `TYPE_GRAPH=2`
`TYPE_UNKNOWN=-1`），四条文案都在 `strings.xml:1465-1468`，措辞统一是
"…is not available on mobile yet.\nChange view type (Settings → View) or create a new one…"。

视图的**可配项**（模型层，逐条 `Block.kt`）：

- 尺寸 `Size SMALL/MEDIUM/LARGE` `:303`；每列 `ViewerRelation`（`isVisible` / `width` / `dateFormat` /
  `timeFormat` / `includeTime`）`:306-313`；日期格式枚举 `DateFormat` `:239`、`TimeFormat H12/H24` `:247`。
- 卡片与分组：`cardSize:284`、`hideIcon:285`、`coverFit:286`、`coverRelationKey:287`、
  `groupRelationKey:290`（Kanban 分组关系）、`groupBackgroundColors:291`、
  `defaultTemplate:288` / `defaultObjectType:289`。
- 排序：模型 `Sort.Type ASC/DESC/CUSTOM` `:335-339` + 空值位置 `EmptyType NOT_SPECIFIC/START/END` `:341-345`；
  UI 只暴露 Asc/Desc 与空值上下（`presentation/.../sets/sort/ModifyViewerSortViewModel.kt:66,76,86,96`），
  **`CUSTOM` 是模型内部用**（收藏列表排序 `presentation/.../widgets/ListWidgetContainer.kt:263-264`）。
- 筛选：运算符 `AND/OR/NO` `:366`；**18 个条件** `:367-371`
  （`EQUAL, NOT_EQUAL, GREATER, LESS, GREATER_OR_EQUAL, LESS_OR_EQUAL, LIKE, NOT_LIKE, IN, NOT_IN, EMPTY,
  NOT_EMPTY, ALL_IN, NOT_ALL_IN, NONE, EXACT_IN, NOT_EXACT_IN, EXISTS`）；
  **15 个日期快捷项** `:373-377`（`EXACT_DATE, YESTERDAY, TODAY, TOMORROW, LAST_WEEK, CURRENT_WEEK, NEXT_WEEK,
  LAST_MONTH, CURRENT_MONTH, NEXT_MONTH, DAYS_AGO, DAYS_AGO/DAYS_AHEAD, LAST_YEAR, CURRENT_YEAR, NEXT_YEAR`）；
  15 条都有 UI（`core-ui/.../features/dataview/modals/FilterDateViewHolder.kt:60-62`、
  `core-ui/.../features/sets/CreateFilterAdapter.kt:187`）。
  **嵌套/高级筛选是桌面端专属**，判据就在模型里：`Block.kt:360-365 isAdvanced()`。
- 视图管理：`ViewEditAction UpdateName / Layout / Relations / Filters / Sorts / Duplicate / Delete`
  （`presentation/.../sets/ViewerEditWidgetUi.kt:30-40`）+ 页签拖拽与增删
  （`presentation/.../sets/ViewersWidgetUi.kt:30-45`：`EditMode/DoneMode/Delete/Edit/OnMove/SetActive/Plus`）。
  布局抽屉：图标开关、封面适配、卡片尺寸、封面字段选择、Kanban 分组与彩色列
  （`presentation/.../sets/ViewerLayoutWidgetUi.kt:15-80`）。
- 手工排序：`objectOrders` / `groupOrders` `Block.kt:273-274` → 写路径
  `domain/.../block/repo/BlockRepository.kt:351` → `data/.../BlockDataRepository.kt:636` →
  应用点 `presentation/.../sets/ObjectSetViewModel.kt:2425`。
- Kanban 是**每列一条订阅 + 每列分页**：`ObjectSetViewModel.kt:1056-1144`，列上有 `hasLoadedRecords`。

### 2. Set / Collection / TypeSet / All Content

- 三者状态形状**成员完全相同**，只有身份与限制不同：`presentation/.../sets/state/ObjectState.kt:17-77`。
  默认值 `VIEW_DEFAULT_OBJECT_TYPE = ot-page`、`VIEW_TYPE_UNSUPPORTED = BOARD` 在 `:88-89`。
- Set 与 Collection 创建时跳过"选模板"步骤：`presentation/.../sets/ObjectTypeExtensions.kt:107-130`。
- 从对象类型生成 Set：`feature-object-type/.../ui/UiState.kt:105-110`（`CreateSet/OpenSet/Hidden`），
  入口 `ui/objects/ObjectsHeaderScreen.kt:114,128`。
- All Content 屏：五个 tab `PAGES / LISTS / MEDIA / BOOKMARKS / FILES`
  （`feature-all-content/.../models/AllContentModels.kt:29-31`），两种菜单模式
  `AllContent | Unlinked`（`:33-43`），状态恢复用例 `domain/.../all_content/RestoreAllContentState.kt:9`。

---

## 3. 文档块（Block）能力

### 3.1 文本样式

`Block.Content.Text.Style` 共 14 档（`Block.kt:169-171`）：
`P, H1, H2, H3, H4, TITLE, QUOTE, CODE_SNIPPET, BULLET, NUMBERED, TOGGLE, CHECKBOX, DESCRIPTION, CALLOUT`。

- `H4` 头部注释标 deprecated（`:166-168` 附近）；
- ⛔ **`QUOTE` 不可插入**：既不在 slash 样式段，也不在样式工具栏状态里；
- `DESCRIPTION` 是系统行（`presentation/.../editor/editor/model/BlockView.kt:623`），不给用户选。

可插入集合的唯一活入口是 **slash 菜单**（`core-ui/.../features/editor/slash/SlashWidget.kt:98-109`，
条目定义 `presentation/.../editor/editor/slash/SlashItem.kt:39`，装配 `SlashExtensions.kt`）：

| 段 | 内容 | 证据 |
| --- | --- | --- |
| Style | Text / Title / Heading / Subheading / Highlighted / Callout / Checkbox / Bulleted / Numbered / Toggle | `SlashExtensions.kt:61-72` |
| Media | File / Picture / Video / Bookmark / Code | `:91-97` |
| Other | Line / Dots / TOC / **Table（`table(NxM)` 解析，行列各夹到 1–25）** | `:99-104`、`:308-325`、`domain/.../table/CreateTable.kt:33-37` |
| Objects | 该空间每一个用户对象类型 + Link To + Select Date | `:133-138` |
| Properties | 已有关系 → `RelationBlock`；`PropertyNew` **被注释掉** | `:140-144`、`SlashItem.kt:314` |
| Actions | Delete / Duplicate / Copy / Paste / Move / Move To（`CleanStyle` 被注释掉） | `:106-114` |
| 颜色 / 对齐 | 文本色与背景色两组、对齐三档 | `:146-162`、`:116-131` |

标记（`Mark.Type`，`Block.kt:148-160`）11 种：
`STRIKETHROUGH, KEYBOARD, ITALIC, BOLD, UNDERLINE, LINK, TEXT_COLOR, BACKGROUND_COLOR, MENTION, EMOJI, OBJECT`。
选区工具栏实际只暴露 8 个（`core-ui/src/main/res/layout/widget_markup_toolbar_main.xml:10,25,40,55,70,85,100,123`；
状态 `presentation/.../editor/editor/control/ControlPanelState.kt:90-117`；
描述 `presentation/.../editor/markup/MarkupStyleDescriptor.kt:3-16`）；
`EMOJI/OBJECT/MENTION` 是**渲染态**标记（`presentation/.../editor/editor/Markup.kt:32-161`）。
颜色档位 `ThemeColor` 11 档（default/grey/yellow/orange/red/pink/purple/blue/ice/teal/lime，
`core-models/.../ThemeColor.kt:10-42`）。对齐只有左中右；⛔ `JUSTIFY` 在模型里但被映射回 START，
注释写着 `// TODO support justify`（`presentation/.../mapper/MapperExtension.kt:280-286`）。

### 3.2 布局与容器

`Layout.Type = ROW, COLUMN, DIV, HEADER, TABLE_ROW, TABLE_COLUMN`（`Block.kt:175`）。
⛔ **ROW/COLUMN 在手机上不并排**：渲染器把所有布局容器展平到同一缩进层
（`presentation/.../editor/render/DefaultBlockViewRenderer.kt:660-684`），只有 TABLE_ROW/TABLE_COLUMN
有结构意义（`:2005-2030`）。
其余：Toggle `:171`；Callout 可带 emoji 或图片图标（`Block.kt:105-106`、`BlockView.kt:481`）；
嵌套层级 `DefaultBlockViewRenderer.kt:690` + `core-ui/.../features/editor/SupportNesting.kt`；
分隔线两档 `LINE / DOTS`（`Block.kt:261`）；TOC `:410`（holder `core-ui/.../holders/other/TableOfContents.kt`）；
Featured Relations `:264`；Relation 块 `:266`；⛔ **synced block / linked block 不存在**
（全仓 `grep -i synced` 只命中 `SyncStatus.kt`、`Event.kt`、`Chat.kt`）。

**表格块操作**（`presentation/.../editor/editor/table/SimpleTableWidgetItem.kt:8-46`，
CELL/ROW/COLUMN 三个 tab `BlockView.kt:1522`）：

- Cell：ClearContents / Color / Style / ResetStyle
- Column：Insert Left·Right / Move Left·Right / Duplicate / Delete / Copy / ClearContents / Sort / Color / Style / ResetStyle
- Row：Insert Above·Below / Move Up·Down / Duplicate / Delete / Copy / ClearContents / Color / Style / ResetStyle
- ⛔ **冻结表头**：`SetTableRowHeader` 被注入但没有任何调用点（唯一引用 `EditorTableDelegate.kt:93` + DI
  `app/.../di/feature/EditorDI.kt:405`）；⛔ **合并单元格**全仓 0 命中（`merge` 只指退格时的块合并
  `Orchestrator.kt:70`）。

### 3.3 媒体 / 链接 / 书签 / 嵌入 / 公式

- 文件块 `File.Type = NONE, FILE, IMAGE, VIDEO, AUDIO, PDF`（`Block.kt:232`），状态 `EMPTY/UPLOADING/DONE/ERROR`
  `:233`。图片走全屏（`Command.OpenFullScreenImage` `editor/editor/Command.kt:82`）、
  视频与音频走内置播放器（`Command.kt:42-43` + `presentation/.../media/MediaViewModel.kt:85,110`）、
  **PDF 与 FILE 没有内置预览**（`OpenFileByDefaultApp` `Command.kt:38`；全仓无 PDF 渲染依赖，
  `grep PdfView|pdfview|brotweiler|SubsamplingPdf` = 0 命中），按通用文件卡渲染
  （`DefaultBlockViewRenderer.kt:638`）。
- 选择器三枚：photo / video / file（`Command.kt:21-23`）。Unsplash **只服务封面**，不能插图
  （`Action.SetUnsplashImage` `presentation/.../common/Delegator.kt:21`、
  `domain/.../unsplash/DownloadUnsplashImage`）。
- 书签块状态 `EMPTY/FETCHING/DONE/ERROR` `:257`；URL 可编辑（`OpenBookmarkSetter` `Command.kt:27`、
  `EditorViewModel.kt:5001`；创建走 `SetupBookmark`/`CreateBookmarkBlock` `Orchestrator.kt:525-546`）；
  ⛔ 没有书签预览卡片样式选项。
- 链接块四组枚举（`Block.kt:185-196`）：`Type PAGE/DATA_VIEW/DASHBOARD/ARCHIVE`、
  `IconSize NONE/SMALL/MEDIUM`、`CardStyle TEXT/CARD/INLINE`、`Description NONE/ADDED/CONTENT`；
  外观面板有开关（`BuildConfig.ENABLE_LINK_APPERANCE_MENU = true`，`presentation/build.gradle:18`；
  面板 `BlockView.kt:274-315` + `presentation/.../objects/appearance/ObjectAppearanceSettingViewModel.kt:58-127`）。
- 提及（`@` 面板 `ControlPanelState.kt:205-223`；变体含 Date/ObjectType/Profile/Task/Deleted，
  `Markup.kt:75-160`）。⛔ 编辑器里没有"回复某对象"（`replyToMessageId` 是聊天专属，`core-models/.../chats/Chat.kt:42`）。
- **嵌入 24 个 provider 全在模型里**（`Block.kt:383-407`）：
  `MERMAID(1), CHART(2), YOUTUBE(3), VIMEO(4), SOUNDCLOUD(5), GOOGLE_MAPS(6), MIRO(7), FIGMA(8), TWITTER(9),
  OPEN_STREET_MAP(10), REDDIT(11), FACEBOOK(12), INSTAGRAM(13), TELEGRAM(14), GITHUB_GIST(15), CODEPEN(16),
  BILIBILI(17), EXCALIDRAW(18), KROKI(19), GRAPHVIZ(20), SKETCHFAB(21), IMAGE(22), DRAWIO(23), SPOTIFY(24)`。
  ⛔ **一个都不在应用内渲染**：统一画占位卡（`core-ui/.../holders/placeholders/EmbedPlaceholder.kt:60-91`），
  点击用 `Command.Browse` 外部打开（`EditorViewModel.kt:5572-5580`）；
  15 个需要 URL（`presentation/.../editor/ext/EmbedExt.kt:47-67`），其余 9 个显示
  "This content is not available on mobile"（`strings.xml:992`）并把载荷换成标记（`EmbedExt.kt:69-77`）；
  并且 slash 菜单**没有插入嵌入的入口**。
- ⚠⚠ 更正：Mermaid 并非只靠嵌入——`Block.Content.DataView` 之外另有渲染路径？没有。**Mermaid 在本客户端
  只能经 `Processor.MERMAID` 嵌入，故仍属 ⛔**（对照我们自己用 `flutter_mermaid` 真渲染，见
  `lib/ui/conversation/assistant_markdown.dart`）。
- LaTeX ✅ **客户端渲染**（KaTeX，`core-ui/.../holders/other/Latex.kt:13,40-47`，依赖
  `libs.versions.toml:130`），但 ⛔ 无插入入口（不在 `getSlashWidgetOtherItems` 里）。

### 3.4 对象头部与交互

- 图标：emoji（数据来自 `library-emojifier/.../data/EmojiProvider.kt`，选择器
  `presentation/.../picker/ObjectIconPickerViewModel.kt:13,26`）、自定义图片
  （`Command.OpenPhotoPicker` / `OpenDocumentImagePicker`）、391 枚矢量类型图标
  `core-ui/.../widgets/objectIcon/custom_icons/`。
- 封面：`CoverType = NONE, UPLOADED_IMAGE, COLOR, GRADIENT, BUNDLED_IMAGE, UNSPLASH_IMAGE`
  （`core-models/.../CoverType.kt:7-14`）；可选 8 渐变 + 12 纯色 + 设备图 + Unsplash
  （`presentation/.../editor/cover/SelectCoverViewModel.kt:44-60`、`CoverColor.kt:6-50`、`CoverGradient.kt:14`）。
- 空间壁纸：`WallpaperResult` → `core-ui/.../widgets/SpaceBackground.kt:23`（Solid/Gradient/None）。
- 模式 7 档 `Edit, Read, Locked, Select, SAM, Search, Styling`（`presentation/.../editor/Editor.kt:25-84`）；
  锁/解锁在对象菜单（`presentation/.../objects/ObjectAction.kt:22-23`）；
  锁定或只读时图标与封面都收（`ObjectMenuOptionsProviderImpl.kt:109-110`）。
- 动作集合 `ActionItemType`（`presentation/.../editor/editor/actions/ActionItemType.kt:3-55`，
  装配 `EditorViewModel.kt:2509-2610`）：AddBelow / TurnInto(TurnIntoPage) / Delete / Duplicate / Rename /
  MoveTo / SAM / Style / Download / Replace / AddCaption / Preview / Copy / Paste /
  OpenObject / OpenLink / OpenFile。
- 拖拽排序 ✅（`app/.../ui/editor/DragAndDropDelegate.kt:46,82`，三段落点
  `core-ui/.../features/editor/DragAndDropConfig.kt:4-8`，自动滚动 `core-ui/.../features/editor/scrollandmove/`）。
- 剪贴板：内部块存储 + 系统剪贴板带 HTML，**粘贴接受外部 HTML/文本**
  （`clipboard/.../AnytypeClipboard.kt:17-41`、`data/.../clipboard/ClipboardDataStore.kt:6-27`）。
- 文内搜索 ✅（`EditorMode.Search` + `SearchInDocEvent{Query, Next, Previous, Clear, Cancel, Search}`
  `presentation/.../editor/search/SearchInDocEvent.kt:3-9`，引擎 `DocumentSearchEngine.kt`）。
- 撤销/重做 ✅ 但是**服务端历史**（`Intent.Document.Undo/Redo`，`EditorViewModel.kt:2870-2893`，
  `domain/.../page/Undo.kt` / `Redo.kt`）。
- 限制位：`ObjectRestriction` 11 档（`core-models/.../restrictions/ObjectRestriction.kt:6-40`：
  `NONE, DELETE, RELATIONS, BLOCKS, DETAILS, TYPE_CHANGE, LAYOUT_CHANGE, TEMPLATE, DUPLICATE,
  CREATE_OBJECT_OF_THIS_TYPE, PUBLISH`）；`DataViewRestriction` 3 档（`VIEWS, RELATION, CREATE_OBJECT`
  `DataViewRestrictions.kt:9-14`）。
- ⛔ **块级深链不存在**：只有滚动到位置/动作菜单（`Command.kt:33,170`），没有块锚点 URL 方案。
- ❌ **"文档设置"不存在**：没有文字边距、等宽字体、页面布局之类（全仓无 `ObjectSettings` 类型；
  "monospace" 只是 `KEYBOARD` span `Markup.kt:192`；"Set layout" 菜单项直接回
  `COMING_SOON_MSG`，`app/.../ui/editor/sheets/ObjectMenuBaseFragment.kt:193`）。

---

## 4. 对象类型清单（内置 21 个 key）

`core-models/.../ObjectTypeIds.kt:9-31`：
`ot-page`、`ot-objectType`、`ot-relation`、`ot-template`、`ot-image`、`ot-file`、`ot-video`、`ot-audio`、
`ot-set`、`ot-collection`、**`ot-task`**、`ot-date`、`ot-profile`、`ot-human`、`ot-participant`、`ot-note`、
`ot-space`、`ot-dashboard`、**`ot-bookmark`**、`ot-relationOption`、`ot-chatDerived`、`ot-chat`、`ot-project`
（默认 `ot-page`，`:33`）。市场镜像键带 `_ot` 前缀（`:55-76`），市场空间 id `_anytype_marketplace`（`:79-82`）。
分组函数：`getTypesWithoutTemplates:35`、`getFileTypes:39`、`getSystemTypes:41`、`getSetTypes:52`。

**客户端对每一类到底做了什么**（这一列才是"功能"）：

- `ot-task` ✅ 但**只作为行渲染形态**：List 视图的 `Item.Task(done)`（`Viewer.kt:126`）、
  桌面组件里按关系映射（`app/.../ui/widgets/types/DataViewWidget.kt:907`）。
  ❌ **没有 Task 专属屏**。
- `ot-bookmark` ✅ 有新建记录对话框（`ObjectSetViewModel.kt:2512,2537,2579,2662`、
  `ObjectSetCreateBookmarkRecordViewModel.kt`）、系统分享接收（`presentation/.../sharing/SharingViewModel.kt:512,1264`）、
  菜单位（`ObjectMenuOptionsProviderImpl.kt:155`）。❌ 没有独立书签库屏。
- `ot-date` ✅ 整屏：`feature-date/`（日历图标、相对日期头、字段抽屉、对象列表、同步徽标；
  `feature-date/.../viewmodel/DateModels.kt:25-45`；可用布局 `SearchParams.kt:178-196`）；
  也是**只能作为组件源的类型**（`presentation/.../widgets/WidgetConfig.kt:14,27`）；
  编辑器里可选日期创建对象（`EditorViewModel.kt:10113`）。
- `ot-chat` / `ot-chatDerived` ✅ 组件容器与搜索分桶（`CreateChatObjectViewModel.kt:59`、
  `WidgetContainerDelegate.kt:209-215`、`presentation/.../search/ObjectSearchConstants.kt:80-181`）。
- 四类文件 `getFileTypes()`：不给模板（`ObjectTypeIds.kt:35`）。
- `ot-project` 🚧 **只在类型排序优先级里出现**（`presentation/.../objects/ObjectTypeSortingExtensions.kt:20,37`），
  没有任何专属行为。
- ❌ **`goal` / `habit` 不存在**：无 `ot-goal`、无 `ot-habit`（grep 0 命中）。全仓与 "goal" 相关的只有
  两句注释里的英文单词；"habit" 只出现在**新用户引导的用例标签** `"HabitTracking"`
  （`app/.../ui/onboarding/screens/signup/OnboardingUsecaseScreen.kt:51`），同批标签还有
  `Knowledge / LifePlanning / Messaging / NoteTaking / Projects / TeamWork / Other`（`:52-58`）。
  → 结论：所谓"小组件里的 goal"在这个 Android 客户端没有对应功能；task 与 bookmark 有，见上。

---

## 5. 关系（Relation）能力

- 16 种格式（`core-models/.../Relation.kt:33-49`）：
  `LONG_TEXT(0), SHORT_TEXT(1), NUMBER(2), STATUS(3), DATE(4), FILE(5), CHECKBOX(6), URL(7), EMAIL(8),
  PHONE(9), EMOJI(10), TAG(11), OBJECT(100), RELATIONS(101), MAP(102), UNDEFINED(-1)`；
  来源 `Source = DETAILS, DERIVED, ACCOUNT, LOCAL`（`:51-54`）。
- **可新建的只有 11 种**（`feature-properties/.../add/UiEditTypePropertiesState.kt:20-32`：
  LONG_TEXT, TAG, STATUS, NUMBER, DATE, FILE, OBJECT, CHECKBOX, URL, EMAIL, PHONE）——
  `SHORT_TEXT / EMOJI / MAP / RELATIONS` 不给建。
- CRUD：`CreateRelation`、`AddRelationToObject`、`DeleteRelationFromObject`、`SetRelationKey`、
  `Add/RemoveFromFeaturedRelations`、`CreateRelationOption`、`DeleteRelationOptions`、`SetRelationOptionOrder`
  （`domain/.../relations/`）。
- 对象信息里的关系列表分 Local / Hidden 两段并可编辑（`presentation/.../relations/RelationListViewModel.kt:88,300,327,354,472,493`）。
- ❌ **没有 "used in / used by" 屏**（全仓 `usedIn` 无真实实现，只有无关的同名颜色参数）。
- 值编辑器按格式分屏：tag/status、option、date、file…（`nav_relations.xml:8,13` 的 `tagStatusScreen` / `optionScreen`）。

---

## 6. 模板与 Gallery Experience

- 用例：`ApplyTemplate`（`template = null` 即空白，`domain/.../templates/ApplyTemplate.kt:26-30`）、
  `CreateTemplate`、`CreateTemplateFromObject`、`GetTemplates`、`OpenTemplate`；
  带类型与模板创建 `domain/.../page/CreateObjectByTypeAndTemplate.kt`。
- 选择器：`presentation/.../templates/TemplateSelectViewModel.kt` + `TypeTemplatesWidgetUI.kt`；
  类型内模板列表与菜单（DELETE/DUPLICATE `feature-object-type/.../ui/UiState.kt:141-143`，
  设为默认 `ui/UiEvent.kt:47`），模板屏 `ui/templates/{TemplatesScreen,TemplatesList,TemplatesModalList}.kt`；
  对象菜单里"设为模板"（`ObjectAction.kt:19` USE_AS_TEMPLATE）+ 模板预填横幅
  （`app/src/main/res/layout/fragment_editor.xml:65-96`）。
- Gallery 安装流：`gallery-experience/.../viewmodel/GalleryInstallationViewModel.kt:87,103,119,165`，
  状态 `models/GalleryInstallationState.kt:8-12`；不支持时告警屏
  `app/.../ui/alert/AlertImportExperienceUnsupported.kt`（目的地 `alertImportExperienceUnsupported`）。

---

## 7. 小组件（Widget）清单——用户问的 task / goal / bookmark 相关面在这里

### 7.1 主屏（Home）组件

形态类 `presentation/.../widgets/WidgetView.kt` 共 **13 种**（+3 种辅助）：

| 组件形态 | 行号 | 说明 |
| --- | --- | --- |
| `Tree` | `:35` | 以某对象为根的树 |
| `Link` | `:71` | 单个对象一行 |
| `SetOfObjects` | `:85` | Set/视图的对象集合 |
| `Gallery` | `:133` | 封面卡片横排 |
| `ChatList` | `:152` | 聊天列表 |
| `UnreadChatList` | `:198` | 未读聊天列表 |
| `RecentlyEdited` | `:214` | 最近编辑 |
| `ListOfObjects` | `:231` | 紧凑列表 |
| `Bin` | `:275` | 回收站 |
| `AllContent` | `:283` | 全部内容 |
| `SpaceChat` | `:289` | 空间聊天卡（带未读） |
| `ObjectTypesGroup` | `:314` | 按类型分组的类型段 |
| `Home` | `:349` | 整屏组件容器 |
| 辅助 | `EmptyState:338` / `InviteMembers:368` / `ChatCounter:377` | 空态、邀请成员卡、未读计数 |

**布局只有 5 档**（`presentation/.../widgets/WidgetTypeView.kt:12-16`：`List | CompactList | Tree | Link | View`），
对应模型码值 `Block.Content.Widget.Layout = TREE(1), LINK(0), LIST(2), COMPACT_LIST(3), VIEW(4)`
（`Block.kt:423-426`，另有 `limit` 与 `activeView` 字段 `:417-420`）。
❌ **组件没有"尺寸"概念**（只有类型不同），行数上限走关系 `widgetLimit`
（`core-models/.../Relations.kt:136`、`Widget.kt:756`，解析 `WidgetConfig.resolveListWidgetLimit` `:36`）。

模型侧 `presentation/.../widgets/Widget.kt`：`Tree:60 / Link:74 / List:87 / View:98 / AllObjects:108 /
Chat:117 / UnreadChatList:126 / PersonalFavorites:135 / Bin:144 / RecentlyEdited:157 / ObjectTypesGroup:178`；
源 `Source.Default:192` / `Source.Bundled`（`Favorites:199, Recent:204, RecentLocal:209, Bin:214,
AllObjects:219, Chat:224, PersonalFavorites:229`）/ `Other:235`；
分区 `SectionType`（`:36-42`：`PINNED, UNREAD, MY_FAVORITES, TYPES, …`）。
内置源 id 7 个（`core-models/.../widgets/Widgets.kt:4-12`）：
`favorite, recent, recentOpen, bin, allObjects, chat, personalFavorites`。

操作：`CreateWidget / DeleteWidget / UpdateWidget / ObserveWidgetSections / SetWidgetActiveView /
ReorderPersonalFavorites`（`domain/.../widgets/`），调用点 `HomeScreenViewModel.kt:1313,1350,1392,1448`，
拖拽重排 `:1836-1855`；组件下拉动作 `WidgetView.kt:408-419`
（`ChangeWidgetType, RemoveWidget, EmptyBin, ChangeHome, Favorite/Unfavorite, CreateObjectOfType`）。
两屏选择器：选源 `SelectWidgetSourceViewModel.kt:66` + 选布局 `SelectWidgetTypeViewModel.kt:57-106`
（fragment/屏在 `app/.../ui/widgets/`）。

### 7.2 Android 桌面（Glance）组件

**5 个 receiver**（`feature-os-widgets/src/main/AndroidManifest.xml:10,23,36,46,59,69,82,92,105`），
**出厂全部 `android:enabled="false"`**，理由写在 manifest 注释里：
"disabled until the feature is production-ready"（`:4-5`）→ 整组是 🚧：

| 组件 | 渲染 | 配置入口 |
| --- | --- | --- |
| spaces list | `feature-os-widgets/.../ui/OsSpacesListWidget.kt:136` | `SpaceSelectionScreen.kt` |
| create object（按类型按钮） | `ui/OsCreateObjectWidget.kt` | `app/.../ui/oswidgets/CreateObjectWidgetConfigActivity.kt:35` |
| space shortcut | 单空间方块 | `.../SpaceShortcutWidgetConfigActivity.kt:57` |
| object shortcut | 单对象方块（1×1） | `.../ObjectShortcutWidgetConfigActivity.kt:81` |
| data view | 某视图的行列表 | `ui/OsDataViewWidget.kt` + `ViewerSelectionScreen.kt` |

格子尺寸在 `feature-os-widgets/src/main/res/xml/os_*_widget_info.xml`；数据不是现查而是
**组件读 DataStore 快照**（`persistence/.../OsWidgetsDataStore.kt:19`，由 vault 写入
`feature-vault/.../VaultViewModel.kt:502,514`），需要实时数据的组件自己拉起中间件
（`presentation/MiddlewareLauncher.kt:49`）；入口走深链 `anytype://os-widget/<widget>/<action>/<id>?token=`
（`feature-os-widgets/.../deeplink/OsWidgetDeepLinks.kt:11-59`，token 在 Activity 里回验
`MainActivity.kt:821-848`）。

---

## 8. 聊天与讨论

模型 `core-models/.../chats/Chat.kt`：`Message(:32) / State(:170) / Preview(:196)`。

- 消息内容 = `Content(text, style, marks)`（`:47`）+ `blocks: List<MessageBlock>`（`:63`），
  块变体只有 **Text / Link(`OBJECT|FILE|IMAGE|BOOKMARK`) / Embed**。
- **附件只有 3 类**：`Attachment.Type = File | Image | Link`（`:56-60`）。
- 回复是**字段不是内容变体**：`replyToMessageId: Id?`（`:42`）。
- 编辑 ✅（`Message.updated :145` + `isEdited`，`feature-chats/.../presentation/ChatView.kt:45`）；
  删除 ✅ 且带权限规则（`ChatViewModel.kt:1647`；作者本人或 Owner/Admin，`ChatView.kt:39-43`）；
  表情回应 ✅ `reactions: Map<String, List<Id>>`（`Chat.kt:41`）+ `ToggleChatMessageReaction` +
  最近使用（`ChatViewModel.kt:2730`）；提及 ✅（`ChatView.kt:86`、`onMentionClicked :2474`）；
  未读 ✅（`State.UnreadState(counter, olderOrderId)` `Chat.kt:179-193`，
  分隔线 `ChatView.kt:49`）；静音三档 `ALL|MENTIONS|DISABLE`（`core-models/.../chats/NotificationState.kt:4`）；
  搜索 `ChatMessageSearchResult` + 排序键 `ORDER_ID/SCORE/CREATED_AT/MODIFIED_AT`（`Chat.kt:8,22`）；
  同步位 `isSynced`（`:46`）。
- "置顶"语义 = **把聊天钉成主屏组件**（`ChatViewModel.kt:2110 onPinChatAsWidget`、
  `presentation/.../widgets/PinObjectAsWidgetDelegate.kt:22-26 isChatPinned`）；❌ 没有消息置顶。
- 附件展示形态（Gallery/Image/Video/Link/Bookmark，`ChatView.kt:98-186`）与输入框附件盒
  （Media/File/Existing{Image,Video,Link}/Link/Bookmark + `Idle/Preloading/Preloaded`，`:190-236`）。
- 讨论 = 对象级聊天，带回应与提及面板（`feature-discussions/.../ui/DiscussionScreen.kt:191-192`），
  宿主 `app/.../ui/discussions/DiscussionFragment.kt`，也从编辑器内嵌。

---

## 9. 空间（Space）与多人协作

- 空间状态 11 档 `SpaceStatus`（`core-models/.../restrictions/SpaceStatus.kt:3-16`）：
  `UNKNOWN, LOADING, OK, MISSING, ERROR, REMOTE_WAITING_DELETION, REMOTE_DELETED, SPACE_DELETED,
  SPACE_ACTIVE, SPACE_JOINING, SPACE_REMOVING`。
- 成员与权限：`ParticipantStatus` 6 档（`JOINING/ACTIVE/REMOVED/DECLINED/REMOVING/CANCELLED`，
  `core-models/.../multiplayer/Multiplayer.kt:30-39`）、`SpaceMemberPermissions` 5 档
  （`READER/WRITER/OWNER/NO_PERMISSIONS/ADMIN`，`:41-65`）、`SpaceAccessType :67`、
  `SpaceUxType`（含 `ONE_TO_ONE`）`:73`、`SpaceType :81`；邀请链接形状
  `https://invite.any.coop/$contentId#$fileKey`（`:13`）。
- 邀请类型 3 档 `InviteType = MEMBER / GUEST / WITHOUT_APPROVE`（`core-models/.../multiplayer/InviteType.kt:3-7`）。
- 空间 CRUD：`domain/.../spaces/CreateSpace.kt:11`、`DeleteSpace.kt:9`、命令 `core-models/.../Command.kt:504`；
  UI `presentation/.../spaces/CreateSpaceViewModel.kt:55` + `app/.../ui/spaces/{CreateSpaceFragment,
  CreateSpaceScreen, DeleteSpaceWarning}.kt`；列表动作按角色分叉
  （`presentation/.../spaces/SpaceListViewModel.kt:66-84`：owner ⇒ DeleteSpace，否则
  CancelJoinRequest / DeleteSpace / LeaveSpace）。❌ **没有空间恢复/撤销删除**。
- 共享与成员管理（`domain/.../multiplayer/`）：`MakeSpaceShareable`、`Generate/Revoke/GetSpaceInviteLink`、
  `ChangeSpaceInvitePermissions`、`Add/RemoveSpaceMembers`、`ChangeSpaceMemberPermissions`、
  `StopSharingSpace`、`Send/Approve/Decline/CancelJoinSpaceRequest`、`ApproveLeaveSpaceRequest`、
  `GenerateOneToOneChatLink`（`OneToOneLinkData` `:49`）、`SearchOneToOneChatByIdentity`。
- UI（`presentation/.../multiplayer/ShareSpaceViewModel.kt`）：链接三态
  `Init / NotGenerated / Shared`（`:1194-1198`）、访问档 Editor/Viewer/Request/Disabled（`:1220-1224`）、
  成员动作 `MAKE_ADMIN / CAN_VIEW / CAN_EDIT / REMOVE_MEMBER / VIEW_REQUEST`（`:1263-1269`）、
  每个 ParticipantStatus 的文案（`:1293,1377,1403,1423-1425`）、错误集（`:1517-1537`）。
- QR：渲染两处（`core-ui/.../features/multiplayer/ShareQrCodeScreen.kt`、
  `features/profile/ProfileQrCodeScreen.kt`）；扫码用 ML Kit（`app/.../ui/qrcode/QrScannerActivity.kt:52,188`）；
  扫码错误 4 类含 `SharedSpaceLimitReached`（`feature-vault/.../presentation/Models.kt:157-163`）。
- Vault（空间选择器）：`DataSpace / DataSpaceWithChat / OneToOneSpace`（`Models.kt:16-76`），
  命令里含 `CreateNewSpace(channelType, selectedMembers, writersLimit)`、`ScanQrCode`、
  四类深链跳转（`:88-118`）。
- 空间类型可切换 Chat ↔ Space（`feature-ui-settings/.../space/new_settings/ChannelTypeBottomSheet.kt:95-115`）。
- ❌ **没有跨空间移动对象**：`presentation/.../moving/MoveToViewModel.kt:39-176` 是"把当前对象链接到另一个对象"。

---

## 10. 版本历史 / 发布到 Web / 收藏 / 回收站 / 链接

- 版本历史：`presentation/.../history/VersionHistoryViewModel.kt`——状态 `:655`、错误三类
  （`SpaceMembers / GetVersions / NoVersions`）`:661-663`、预览 `:668-669`、
  分组 Today/Yesterday `:717-718`、命令 `:636-638`；
  用例 `DiffVersions / GetVersions / SetVersion / ShowVersion`。
  ⚠ **回滚 = `SetVersion`，协议里没有独立 restore 动作**。
- 发布到 Web：`Status = CREATED | PUBLISHED`（`core-models/.../publishing/Publishing.kt`），
  `State` 带 `showJoinSpaceButton`；UI 七态 `Init/Loading/NotPublished/Published/Publishing/FailedToPublish/
  FailedToUpdate`（`presentation/.../publishtoweb/PublishToWebViewModel.kt:304-377`，含 slug 转写 `:370`）；
  "My Sites" 屏 `MySitesViewModel.kt` + `app/.../ui/publishtoweb/`。
  ❌ **没有 `syncFrequency`**（全仓 0 命中）→ 定时再同步只在桌面端。
- 收藏：只作用于**个人空间的组件段**（`domain/.../favorites/{AddPersonalFavorite, RemovePersonalFavorite,
  ReorderPersonalFavorites, PersonalFavoritesRepository}`，接线 `HomeScreenViewModel.kt:1810-1873`，
  菜单位 `ObjectMenuOptionsProvider.kt:22 isFavorited`）。
- 回收站：`SetObjectListIsArchived`、`domain/.../bin/EmptyBin.kt:14`、属性被单独丢进回收站的规则
  （`domain/.../primitives/FieldParser.kt:361`）。❌ **没有回收站浏览屏**，只有 `WidgetView.Bin` 组件形态。
- 链接：三屏 `app/.../ui/linking/{LinkToObjectFragment, LinkToObjectOrWebPagesFragment,
  BacklinkOrAddToObjectFragment}`（后者 VM `presentation/.../linking/BackLinkOrAddToObjectViewModel.kt`），
  用例 `AddBackLinkToObject / CheckForUnlink / CreateBlockLinkWithObject`；
  全局搜索结果里显示 `links` 与 `backlinks` 计数（`app/.../ui/search/GlobalSearchScreen.kt:577`）；
  分享对象深链 `ShareDeeplinkToObject`（`presentation/.../objects/menu/ObjectMenuViewModelBase.kt`）。
  ❌ **没有桌面端那种"Objects as used"引用列表屏**。

---

## 11. 外壳与系统入口

- 导航：单 Activity + NavHost（`app/src/main/res/navigation/graph.xml`，739 行，
  **22 个 `<fragment>` + 65 个 `<dialog>`**，5 个嵌套图 `objectNavigation :9` /
  `dataViewNavigation :99` / `objectTypeNavigation :270` / `onboarding_nav :482` /
  `deletedAccountNavigation :663`，另 include 四张模态图 `:93-96`）。
  代表目的地：`splashScreen:415`、`pageScreen:12`、`objectMenuScreen:32`、`objectRelationListScreen:36`、
  `objectIconPickerScreen:40`、`objectCoverScreen:44`、`objectCoverUnsplashScreen:48`、`objectValueScreen:69`、
  `versionHistoryScreen:74`、`objectTypeFieldsScreen:82`、`publishToWebScreen:87`、`objectSetScreen:102`、
  `chatScreen:172`、`discussionScreen:191`、`selectChatReactionScreen:196`、`participantScreen:206`、
  `homeScreen:211`、`homeScreenWidgets:245`、`dateObjectScreen:260`、`selectWidgetSourceScreen:302`、
  `selectWidgetTypeScreen:314`、`vaultScreen:318`、`createSpaceScreen:332`、`spaceSettingsScreen:354`、
  `spaceListScreen:364`、`profileSettingsScreen:378`、`filesStorageScreen:383`、`spacesStorageScreen:389`、
  `aboutAppScreen:395`、`logoutWarningScreen:399`、`deleteAccountWarningScreen:403`、`paymentsScreen:407`、
  `galleryInstallationScreen:411`、`appearanceScreen:636`、`keychainDialog:467`、`mnemonicReminderDialog:477`、
  `authStartScreen:486`、`debugSettingsFragment:504`、`debugScreen:510`、`experimentalFeaturesScreen:515`、
  `globalSearchScreen:520`、`allContentScreen:525`、`typeCreationFragment:554`、`relationEditingFragment:597`、
  `fullScreenImageFragment:632`、`createObjectFragment:644`、`limitObjectTypeScreen:658`。
- 清单：4 个 Activity（`MainActivity:33`、`SettingsActivity:153`、`QrScannerActivity:159`、`MediaActivity:163`）、
  **23 条 intent-filter**、1 个 FileProvider（`:168`）、1 个 FCM Service（`:192`）；
  权限含 `NEARBY_WIFI_DEVICES(neverForLocation)`、`POST_NOTIFICATIONS`、`CAMERA`、旧式外存读写（`:5-31`）；
  **没有前台 Service**（Go 节点在进程内）。
- 深链 6 类（`app/.../other/Deeplinks.kt`）：`anytype://main :30`、
  `anytype://import?type=experience&source= :32,44`、`anytype://invite?cid=&key= :28`、
  `anytype://object?objectId=&spaceId= :31,136`、`anytype://membership?tier=&code= :33,162`、
  `anytype://hi/?id=&key=`（一对一）`:25,73`、`anytype://os-widget/…`；
  autoVerify HTTPS 域 4 个：`invite.any.coop`、`hi.any.coop`、`object.any.coop`、`download.anytype.io`
  （`AndroidManifest.xml:45-81`）。
- 系统分享接收：`SEND` / `SEND_MULTIPLE`，MIME = `text/plain`、`image/*`、`video/*`、`application/*`
  （`:117-151`）→ `MainActivity.kt:469,885` → `presentation/.../sharing/`（三条流：聊天 DM / 数据空间对象 /
  混合，`app/.../di/feature/sharing/SharingDI.kt:35-40`）。出站分享：`domain/.../device/FileSharer.kt:3`
  → `device/.../SharedFileUploader.kt:16`。
- 对象来源是一枚关系位 `ObjectOrigin`（`core-models/.../ObjectOrigin.kt:4-12`：`NONE, CLIPBOARD,
  DRAG_AND_DROP, IMPORT, WEB_CLIPPER, SHARING_EXTENSION, USE_CASE, BUILT_IN, BOOKMARK`）——九档都在模型里，
  本客户端**只有 `SHARING_EXTENSION` 真的被写入**（`SharingViewModel.kt:474,505,1257`）；
  `IMPORT` 与 `WEB_CLIPPER` 是给桌面端与中间件留的位。
- App Shortcuts：动态推送 + 换空间时清空（`app/.../app/DefaultAppActionManager.kt:57-68`、
  `MainActivity.kt:880,43`）。
- Quick Capture：全屏高 BottomSheet 里嵌**真正的编辑器 Fragment 子类**
  （`app/.../ui/quickcapture/QuickCaptureFragment.kt:43-44` + 规格 `docs/quick-capture-android-spec.md` D1）；
  草稿用例 `FetchQuickCaptureDraft / SearchQuickCaptureDrafts / MoveQuickCaptureDraft /
  DeleteQuickCaptureDraftIfEmpty`（`domain/.../quickcapture/`）。
- 通知：payload 9 种（`core-models/.../Notification.kt:28-86`）：`GalleryImport`（带 `ImportErrorCode`）、
  `RequestToJoin`、`RequestToLeave`、`ParticipantRequestApproved`、`ParticipantWithoutApprovalRequestApproved`、
  `ParticipantRemove`、`ParticipantRequestDecline`、`ParticipantPermissionsChange`、`Unsupported`、`Test`；
  应用内跳转三动作（`presentation/.../notifications/NotificationsViewModel.kt:284-300`）；
  推送签名与解密校验（`presentation/.../notifications/{CryptoService, SignatureVerificationService,
  DecryptionPushContentService}.kt`）。⚠ 文件限额提醒**不是**通知 payload，走事件拦截
  （`interceptFileLimitEvents`，`feature-ui-settings/.../fstorage/FilesStorageViewModel.kt:51,66`）。
- 同步状态 UI：`core-ui/.../syncstatus/{SpaceSyncStatusScreen.kt, StatusBadge.kt}` +
  提供者 `presentation/.../sync/SpaceSyncAndP2PStatusProvider.kt`。❌ 没有独立离线横幅，
  离线只在引导错误态出现（`OnboardingStartViewModel.ErrorState.OfflineDevice`）。
- 媒体屏：图片翻页 / 视频 / 音频 / 下载 / 删除 / 恢复（`presentation/.../media/MediaViewModel.kt:41,85,110,137,158,178`）。

---

## 12. 设置与偏好（用户可见的每一行）

- 账户屏 9 行（`feature-ui-settings/.../account/ProfileScreen.kt`）：外观 `:141`、通知 `:151`、
  登录密钥（助记词）`:163`、会员 `:174`（受 `showMembership` 门控）、空间 `:191`、本地存储 `:202`、
  My Sites `:212`、关于 `:230`、调试 `:241`、实验特性 `:252`、退出登录 `:298`。
- 外观屏 **只有主题三档** `Light / Night / System`（`AppearanceViewModel.kt:56-66` +
  `ThemeApplicator.kt:16-18`）。❌ **没有字号设置**（对照：我们 harness 有三档字号合成，ADR-0017 S3）。
- 文件存储屏：设备占用 `:116`、卸载文件 `:148`、离线下载限额 `:156`、"使用蜂窝网络" `:267`、
  危险区（删号）`:174-187`。限额 6 档 `FileDownloadLimit = OFF, MB_20, MB_100, MB_250, GB_1, UNLIMITED`
  （`core-models/.../FileDownloadLimit.kt:11-16`，默认 OFF `:41`）。
- 空间存储屏：远端用量 + 图例 Active/Free/Other（`space/SpaceStorageScreen.kt:68`）；
  已卸载文件管理 `app/.../ui/settings/RemoteFilesManageFragment.kt`。
- 空间设置 13 行（`space/new_settings/NewSettings.kt`）：默认类型 `UiSpaceSettingsItem.DefaultObjectType` `:321`、
  空间主页 `SpaceHome` `:334`、
  删除 `:347`、离开 `:357`、成员 `:367`、邀请 `:386`、对象类型 `:392`、字段 `:404`、远端存储 `:416`、
  回收站 `:426`、空间信息 `:445`、壁纸 `:457`、通知 `:484`、改空间类型 `:498`。
- 关于屏：What's new / 社区 / 帮助 / 联系 / 条款 / 隐私（`about/AboutAppScreen.kt:63-86`）+
  技术信息块 7 字段（version / buildNumber / libraryVersion / accountId / deviceId / analyticsId /
  ethereumKey，`:90`）。
- 调试屏：导出工作目录、读取所有聊天、Goroutines dump、Stat、Space Summary、导出日志、
  启动时/立即 profiler（60s）与结果分享（`app/.../ui/settings/DebugScreen.kt:73-170`、
  `DebugViewModel.kt:270`）；另有独立 `SettingsActivity` 承载**网络模式下拉 + 配置文件选择器**
  （`ui/settings/system/PreferenceFragment.kt:96-104`）。
- 用户可切的实验位 4 个（`ExperimentalFeaturesScreen.kt:66-94`）：紧凑 vault、**kanban**、quick capture、
  quick capture AI；默认值 `compact=true / kanban=true / quickCapture=true / quickCaptureAi=false`
  （`persistence/.../DefaultUserSettingsCache.kt:58-70`，注释明确 quick capture 已"Default ON"）。
- 编译期 flag：`USE_NEW_WINDOW_INSET_API`、`USE_EDGE_TO_EDGE`、`SHOW_CHATS`、`ENABLE_STRICT_MODE`
  （`app/build.gradle:84-95`）+ `local.properties` 五个中间件日志开关（`:89-94`）。

---

## 13. 账户 / 设备 / 网络 / 密钥

- 引导：新建 vault 或"我已有密钥"（`app/.../ui/onboarding/screens/OnboardingAuthScreen.kt:154,164`）；
  用例选择屏 8 项（`screens/signup/OnboardingUsecaseScreen.kt:51-58`）；类型选择、
  助记词展示、"什么是恢复短语"、设定资料名、邮箱；登录侧有恢复短语登录、网络设置、
  "进入虚空"屏（`OnboardingRecoveryPhraseLoginScreen` / `OnboardingNetworkSetupScreen` /
  `OnboardingEnteringVoidScreen`）。
- 密钥屏态 `Displayed / Blurred`（`presentation/.../keychain/KeychainViewState.kt:4-5`）+
  提醒对话框（`app/.../ui/dashboard/MnemonicReminderDialog.kt`、`DashboardMnemonicReminderDialog.kt`）。
- 退出 / 删号有两个独立确认目的地（`logoutWarningScreen`、`deleteAccountWarningScreen`）+
  `DeletedAccountFragment`。❌ **没有多账号切换 UI**（单活动账号）。
- 网络模式 `DEFAULT / LOCAL / CUSTOM`（`core-models/.../NetworkMode.kt:4`）+
  `NetworkModeConfig(userFilePath, storedFilePath, useReserveMultiplexLib)` `:11`（含 staging 节点常量 `:15`）。
- 设备侧：FCM token 落地（`app/.../device/AnytypePushService.kt:20` →
  `device/.../DeviceTokenStoringServiceImpl.kt`）、应用状态、网络类型、日期与本地化提供者、
  下载器（`device/` 共 928 行主源码，是 `domain/device/` 端口的 Android 实现）。

---

## 14. 会员与额度门控

- 档位 id 8 个（`core-models/.../membership/MembershipConstants.kt:5-12`）：
  `NONE 0`、`OLD_EXPLORER 1`、`NEW_EXPLORER 20`、`STARTER 21`、`PIONEER 22`、`BUILDER 4`、`CO_CREATOR 5`、
  `ANY_TEAM 7`（+自定义 1000，`presentation/.../membership/MembershipViewModel.kt:653`）；
  带横幅的档 `[0,1,21,22]`（`:18`）；名字最短 7 字符（`:23`）。
- 枚举：`Status` 4 档、`PaymentMethod` 5 档（`NONE / STRIPE / CRYPTO / INAPP_APPLE / INAPP_GOOGLE`）、
  `PeriodType`、`NameServiceNameType.ANY_NAME`、`EmailVerificationStatus`、
  `UpgradeReason = NumberOfReaders | NumberOfEditors | NumberOfSharedSpaces | StorageSpace`
  （`MembershipModels.kt:18-86`）。
- 屏：主会员页 + 档位列表 + 权益卡 + 激活码入口（`payments/screens/MembershipScreen.kt:69,216,237,276`）、
  `TierScreen`、`TierPreviewView`、`AnyNameView`、`EnterEmailView`、`EnterCodeScreen`、`ActivateCodeScreen`、
  `WelcomeScreen`、`ConditionInfoView`。
- Play Billing 只有 `payments/.../playbilling/BillingClientLifecycle.kt` 一处：
  `setupSubIds:72`、`querySubscriptionProductDetails:162`、`querySubscriptionPurchases:266`、
  `onPurchasesUpdated:294`、`launchBillingFlow:390`，状态 `Loading/Error/Connected/NotAvailable :410`。
- 门控点：存储（`SpacesStorageViewModel.kt:296` 按 activeTier）、共享（`ShareSpaceViewModel.kt:206-245`、
  `SpaceJoinRequestViewModel.kt:116`）、下载限额、视图与编辑限制。

---

## 15. AI 能力（只有一处）

✅ 唯一功能 = **设备端类型建议**：`core-ai/.../core_ai/MlKitTypeSuggestionEngine.kt:27`（Gemini Nano），
接线 `EditorViewModel.kt:390`（`isAvailable :8406`、`prewarm :8410`、`suggest :8435`、
`suggestedTypeId :8465`、`pinSuggestedType :8605`），接口在 `domain/ai`，DI 在
`app/.../di/main/AiModule.kt:24`，规格 `docs/quick-capture-android-spec.md` §9；
受实验位 `quick_capture_ai` 控制且**默认关**。
❌ 没有对话式 AI、没有摘要/改写、没有服务端模型调用（全仓唯一的 AI 面就是上面那一个）。

---

## 16. 埋点分组（等价于一张功能地图）

`analytics/.../base/EventsDictionary.kt` 539 行、344 个 `const val`，按注释分组（行号）：
Auth `:9`、Dashboard `:17`、Settings `:21`、Screen show `:44`、Object `:61`、Blocks `:90`、Relations `:106`、
Sets `:116`、Block Actions `:134`、Toolbars `:141`、Library `:148`、Widgets `:155`、Templates `:169`、
Onboarding `:178`、Primitives `:186`、Vault `:194`、About-app `:199`、Sharing extension `:209`、
Sharing spaces `:216,238`、Version history `:245`、All content `:250`、Date object `:259`、ObjectType `:267`、
Deep links `:277`、Network mode `:315`、Gallery experience `:319`、Membership `:327,332`、
Chats `:337-408`；内嵌枚举 `Routes :443`、`Type :475`、`BlockAction :490`、`View :507`、
`EventsPropertiesKey :513`。载荷无类型：`Props(map: Map<String?, Any?>)`（`analytics/.../props/Props.kt:3`）。

---

## 17. "看起来有、其实没有"总表（对齐功能时先看这张）

| 能力 | 结论 | 证据 |
| --- | --- | --- |
| Calendar / Graph 视图 | ⛔ 只有不支持占位 | `ObjectSetRenderMapper.kt:188-193`、`strings.xml:1466-1467` |
| Kanban 视图 | 🚧 已实现，实验位默认开、可关 | `ObjectSetRenderMapper.kt:145-147`、`DefaultUserSettingsCache.kt:61-63` |
| 24 个嵌入 provider | ⛔ 全部不内嵌渲染，且无插入入口 | `EmbedPlaceholder.kt:60-91`、`EmbedExt.kt:47-77` |
| LaTeX | ✅ 能渲染 / ⛔ 不能插入 | `holders/other/Latex.kt:40-47` vs `SlashExtensions.kt:99-104` |
| `QUOTE` 样式 | ⛔ 模型有、不可达 | `Block.kt:169` vs slash/control panel |
| `JUSTIFY` 对齐 | ⛔ 映射回 START + TODO | `MapperExtension.kt:280-286` |
| ROW/COLUMN 并排版面 | ⛔ 渲染时展平 | `DefaultBlockViewRenderer.kt:660-684` |
| 表格冻结表头 / 合并单元格 | ⛔ 用例注入未调用 / 完全不存在 | `EditorTableDelegate.kt:93`、grep `merge` |
| synced / linked block | ⛔ 不存在 | 全仓 `grep -i synced` |
| PDF 内置预览 | ⛔ 外部 app 打开 | `Command.kt:38`；PDF 渲染依赖 grep = 0 |
| Notion / 第三方导入 | ❌ 无 UI；只有中间件错误码被压成 UNKNOWN | `ToCoreModelMappers.kt:1000-1002` |
| Objects as used / used-in 列表 | ❌ 只有"添加反向链接"写路径与搜索里的计数 | `ui/linking/BacklinkOrAddToObjectFragment.kt:37`、`GlobalSearchScreen.kt:577` |
| 块级深链 | ⛔ 只能滚到位置 | `Command.kt:33,170` |
| 组件尺寸（size） | ❌ 只有 5 种布局 | `WidgetTypeView.kt:12-16` |
| 消息置顶 | ❌ "置顶"=钉成主屏组件 | `ChatViewModel.kt:2110` |
| 空间恢复 / 跨空间移动 | ❌ | `SpaceListViewModel.kt:66-84`、`MoveToViewModel.kt:39-176` |
| 发布定时同步 `syncFrequency` | ❌ | 全仓 grep = 0 |
| 多账号切换 | ❌ | `OnboardingStartViewModel.kt:39`（单 configStorage） |
| 字号设置 | ❌ | `AppearanceScreen.kt:78`（只有主题） |
| 文档设置（边距 / 等宽 / 版式） | ❌ 菜单直接 COMING SOON | `ObjectMenuBaseFragment.kt:193` |
| Goal / Habit 对象类型 | ❌ 无 `ot-goal`/`ot-habit`；只有引导里的 `"HabitTracking"` 标签 | `OnboardingUsecaseScreen.kt:51` |
| Android 桌面 Glance 组件 | 🚧 代码完整但 manifest 全 `enabled="false"` | `feature-os-widgets/src/main/AndroidManifest.xml:4-5,10-105` |
| 旧式 `AddBlock` "+" 菜单 | ⛔ 死代码（无调用点） | `editor/picker/AddBlockView.kt:42-92` |

---

## 18. 与本仓库（`flutter_agent_harness`）的对照

只是坐标，**不构成待办**；要做任何一项先按 `workflow.md` §7 立 ADR。

| Anytype 的这块 | 我们现在的对应物 | 差距形状 |
| --- | --- | --- |
| 6 种数据视图（4 渲染 / 2 占位） | `packages/board_panel` 的看板 / 日程 / 表格三面（ADR-0007） | 我们有 Calendar 而没有 Gallery；Anytype 反过来 |
| 视图不支持时的显式占位文案 | 我们的降级只有 `browserUnsupported` 一格（`build.md` §2B） | "模型有 ≠ 表面有"的**声明方式**值得对齐 |
| 块编辑器的乐观更新 + 丢弃回执 | 我们是工具环 + 流式尾，无块编辑 | 结构不同，别硬套 |
| 服务端历史 = undo/redo | 我们的 checkpoint / rewind（ADR-0014） | 我们存 before 镜像，他们让核心回放；两条路都能闭环 |
| `ObjectRestriction` 11 档集中声明 | 我们的 `decideGate` 单函数 + `readOnlyToolNames` | 同一族"能力位集中一处"的律 |
| 组件 5 种布局 + `widgetLimit` 关系 | 我们的 tab registry（4 字段）+ 双树工作台 | 他们用关系承载限额，我们用布局控制器 |
| 埋点分组 = 功能地图 | 我们没有埋点，有 ADR + debt-register | 我们的登记表承担同一职能 |
| 字号无设置 | 我们有三档字号合成 + 十七面两档守卫 | **他们有 1.0 硬编码 chrome 的坑，我们已闭** |
| 架构无机器门禁（lint 关成 no-op） | `tool/check_architecture.dart` 七条 + baseline | 我们的强项，继续 |

---

## 19. 这份清单的取证口径

- 体量与模块图来自 `find`/`wc` 现场重算（非文档抄写）：见 §开头。
- 我**亲自复核**的枚举：`Block.kt` 全部档位（Text.Style / Mark.Type / Layout.Type / File.Type /
  Viewer.Type / Sort / Filter / Embed.Processor / Widget.Layout）、`ObjectTypeIds.kt`、`Relation.Format`、
  `WidgetView` 子类、`Viewer.Unsupported` 四常量与四条文案、kanban 开关与默认值、
  `FileDownloadLimit`、`ObjectOrigin`、会员档位、`persistence` 只有一个 @Entity、
  lint.gradle、事件总线（`EventHandler.kt`）与 ack-as-payload。
- 其余带行号条目来自对同一 commit 的逐层读取，未逐条复按；引用到决策文档前请现场 `grep` 复核。
- **所有否定结论（❌/⛔）都以"全仓 grep 为 0 命中"或"指到具体降级代码"为证**，不是推测。

## 20. 更新方式（副本会腐烂）

```bash
cd _archive_project/anytype-kotlin        # head 应为 7af5254（0.50.4）
git log -1 --format='%h %ad %s'
wc -l core-models/src/main/java/com/anytypeio/anytype/core_models/Block.kt   # 枚举起点会移动
# 视图档位
sed -n '294,301p' core-models/src/main/java/com/anytypeio/anytype/core_models/Block.kt
grep -n "TYPE_KANBAN\|TYPE_CALENDAR\|TYPE_GRAPH" presentation/src/main/java/com/anytypeio/anytype/presentation/sets/model/Viewer.kt
grep -n "not available on mobile" localization/src/main/res/values/strings.xml
# 对象类型与内置组件源
cat core-models/src/main/java/com/anytypeio/anytype/core_models/ObjectTypeIds.kt
cat core-models/src/main/java/com/anytypeio/anytype/core_models/widgets/Widgets.kt
```

上游若改了档位，先改本文再动任何对照结论；行号失效时用 `grep -n` 重定位而不是猜。
