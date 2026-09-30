# ADR-0036 · 截图里的件换 shad，shad 没有的按 shad 风格封装

- **状态**：IN-PROGRESS（**B6 / B7 / B8 三批代码与守卫已全部落地**，剩下的是四件事：macOS 真机走查那一眼（新字段皮、发送钮焦点环、分区卡的 `bgLayer1` 底、右键菜单两棵）、两处映射表判定按落地核对改回"保留"并写明理由（行 1 分段控件、行 2 新会话、行 16 投递药丸、行 18 工具卡容器、行 32 欢迎页动作），以及一条已登记的观察——屏幕上两套 Lucide 字体。原始指令：2026-09-30 用户指令：四张真窗截图中的相关组件采用 shadcn_ui 现有组件，没有的按 shadcn_ui 风格自行封装。ACCEPTED 同日；**B6 菜单归一已落 @ d2401a2/5ee3bd4；B7 的字段/开关/徽标已落 @ d3181fb/b44c73f**，B7 按钮与字段 / B8 封装件与身体待做）
- **分类**：ARC（ADR-0002 shadcn 迁移的继续，把迁移面从"主题桥 + 按钮"扩到截图内全部件）
- **优先级**：P2
- **日期**：2026-09-30

## 背景

四张真窗截图（2026-09-30，`5dfe47f3` 空态 / `e68d068b` 设置·扩展 / `86e0bd57` 对话流 / `bf783e32` 模型菜单展开）逐件看过去，仍非 shad 的表面有：侧栏的**企划/代理分段控件**、`新会话` 按钮、会话行、页脚字母头像与两枚图标钮；外壳右上两枚面板切换钮；hero 的**工作区 chip**（folder 图标 + chevron）；composer 卡与它的**五把下拉**（Material `PopupMenuButton`，皮住在 `popupMenuTheme`，ADR-0028）、发送圆钮；工具卡的容器与 IN/OUT 两 pane；设置页的**垂直导航行**、搜索框、字段、`添加服务器`/`保存`/关闭钮；以及展开的模型菜单本身（灰底、勾选项、分隔线、带 Retry 的异步行——Material popup 的形状）。

对照 shadcn_ui **0.56.3** 的组件索引（入库 skill `.qoder/skills/shadcn-ui-flutter/` 的组件表，与 pubspec 钉的版本同源）：

- **有**：Button、IconButton、Input、Textarea、Switch、Checkbox、RadioGroup、Select、Context Menu、Menubar、Popover、Tooltip、Card、Badge、Separator、Tabs、Accordion、Dialog、Sheet、Sonner/Toast、Avatar、Table、Resizable、Progress、Alert、Form、Calendar、Slider、Breadcrumb、InputOTP、Time/Date Picker。
- **没有**：分段控件（Segmented / ToggleGroup）、垂直导航列表、ScrollArea、Skeleton、DropdownMenu（React 版有；此移植版用 Select / Context Menu / Menubar / Popover 表达同一族交互）。

现状基线：ADR-0002 的 shad 迁移只落了 Stage 4 主题桥（`theme/dsw_shad_bridge.dart`，DswAlias→ShadColorScheme）与 Stage 5 的 CapsuleButton→ShadButton；对话框一路已收进 `ShadDialog`（`1e417e6`）；反馈条已收进 `ShadSonner`（ADR-0020）。其余截图内的件仍是自绘或 Material。

## 决策

1. **截图内凡 shad 有现成组件的件，界面一律改用该组件**：Button / IconButton / Input / Switch / Checkbox / Select / ContextMenu / Popover / Card / Separator / Badge / Tabs（语义合时）。Select 表达不了异质行（模型菜单的"选项 + 动作 + 异步状态行"）时，用 `ShadPopover` 自排列表——仍是 shad 组件，不退回 Material。
2. **shad 没有的件按 shad 风格封装**，落在 `lib/ui/primitives/`：分段控件、垂直导航行、会话行、hero 空态、以及 Card 表达不了的容器。封装件的**皮**（填充/圆角/发丝/字重）只从 `DswAlias` 与 `DswShape` 取、经既有主题缝说一次；**身体**优先用 shad 原语拼（分段控件 = 轨道容器 + 两枚 `ShadButton`），拼不出才自绘。
3. **既有原语律不破，但原语的身体改委托 shad**：点击机制仍只认 `DswHoverTap` / `ShadButton`（ADR-0021），图标钮仍只认 `DswIconButton`（ADR-0024）——`DswIconButton` 的身体改为 `ShadIconButton`，wrapper 继续负责 tooltip=语义名、半径按盒子尺寸推、色阶与动效（ADR-0023/0024 的四性不变）。这是"封装件身体用 shad"的第一枚实例：单点原语的数量不增加，变的是它站在谁的肩膀上。
4. **菜单换 shad 后，ADR-0028 的"皮只在 `popupMenuTheme` 说一次"部分被取代**：皮改住在 ShadTheme 的对应主题项（select / context-menu），由 `dsw_shad_bridge.dart` 从 `DswAlias` 映射。"一层皮、只在主题说一次"这条律不变，换的是缝。Material 的 `popupMenuTheme` 保留到最后一把 Material 菜单换完才删；`tooltipTheme`（ADR-0023）不动——Tooltip 不在截图内。
5. **配色仍只从 dsw 取**（workflow §2 老律）：shad 组件一律经桥拿色，任何调用点不得读 shad 调色板。
6. **明确不做**：
   - 不给 composer 卡换 `ShadCard`——它的三态描边是 `AnimatedContainer` + `BoxDecoration` 的动画（ADR-0017 S2b，守卫读的是**画出来的** border），ShadCard 的装饰是静态主题项，表达不了"焦点优先于 hover"的过渡；
   - 不动工具卡 IN/OUT 的读法（ADR-0031/0035）与用户气泡形状（ADR-0034）——它们是内容层，不是组件层；
   - 不换 Tooltip（ADR-0023 已闭，且不在截图内）；
   - 不引入 shad 的 `ShadApp` 替换 `MaterialApp`——装配根与 overlay 缝（ADR-0020/0032 的 `MaterialApp.builder` 顺序）是已证的事实，换根等于重开那两条律。

## 后果

- ADR-0002 的迁移面扩大；本 ADR 是它的执行批次族（B6 菜单 / B7 按钮与字段 / B8 封装件），每批一条先红后绿的守卫，映射表见 `docs/shad-adoption-2026-09-30.md`。
- `test/menu_chrome_test.dart` 读皮的缝要随菜单批改（从 Material `popupMenuTheme` 改读桥给 shad 的档）——**改的是认法不是断言**，照 ADR-0034 改 `chat_view_test` 的先例在批次里说明。
- 放大文本那把尺子（ADR-0017 S3）对换进来的 shad 件同样成立：shad 组件的固定高度座位要过两档（1.8x / 2.2x）探针，`ShadButton.height` 既是 min 又是 max 的天花板照旧登记。
- 风险：shad 组件自带排版（textTheme），与 `DswType` 阶梯可能分叉——桥只映射颜色与半径时，字号仍由调用点用 `DswType` 显式给（ADR-0027 的"样式名不许撒谎"继续管调用点）。

## 实施

**B6 菜单归一（已落 @ d2401a2 代码 / 5ee3bd4 守卫）**：`lib/ui/primitives/menu.dart` 一枚文件收全部三种形状（`DswMenu` = `ShadPopover` 动作菜单、`DswContextMenu` = `ShadContextMenuRegion`、`DswSelect` = `ShadSelect` 值选择器），行与分隔线只有一份（`DswMenuRow` / `DswMenuDivider`），13 处 Material 菜单归零。皮从 `dsw_theme.dart` 的 `popupMenuTheme` 搬进 `dsw_shad_bridge.dart`（`popoverTheme` + `optionTheme` + `contextMenuTheme`），`popupMenuTheme` 与零读取的 `DswAlias.menu` 一并删除；守卫 `test/shad_menu_adoption_test.dart`（源码计数）与 `test/menu_chrome_test.dart`（读皮，认法改缝、断言留）各先红后绿。四条实现期量到的事实记在映射表 `docs/shad-adoption-2026-09-30.md` §2 的「B6 落地的四条事实」，其中**屏幕上现在有两套 Lucide 字体**一条已另登观察表。

**B7 字段与开关（部分落 @ d3181fb 代码 / b44c73f 守卫）**：五处 `TextField` 换 `ShadInput`（桥补 `inputTheme`，字段皮从此只在桥说一次；框内字段传 `dswBareInput`），设置开关换 `ShadSwitch`（其 `onChanged` 此前根本没接线——只有行在动作），`Pill` 换 `ShadBadge`。守卫 `test/shad_widget_adoption_test.dart` 三条零容忍计数 + 一条正向对照，先红于 5 字段 / 1 自画开关 / pill。发送圆钮（行 15）随后换 `ShadButton.ghost`，并消掉它自带的 `enabled` + `Opacity(0.4)` 双真值（ADR-0024 只允许 `onPressed: null` 一种说法），焦点环由库补上。映射表另两行按落地核对改回"保留"并写明理由：行 16 的投递药丸要的描边 `ShadBadge` 没有入口，行 2 的新会话四条性质已在、两档形态是 bespoke。
