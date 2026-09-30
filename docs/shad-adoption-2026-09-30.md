# shad 组件采纳映射 —— 四张真窗截图（2026-09-30）

> 决策见 [ADR-0036](adr/ADR-0036-arc-shad-components-for-the-screenshot-surfaces.md)（ACCEPTED）。本表是它的执行映射。
> **范围律**：截图定**发现面**，"同族一次换完"定**范围**——菜单的皮只有一层（ADR-0028），换一半就是两层皮；与 ADR-0031"改一个共享的东西要问它所有的读者"同律。所以工作台那几把截图外的菜单也进 B6。
> **事实基线**（2026-09-30 现场核对 pub-cache `shadcn_ui-0.56.3`）：`ShadSelect.options` 是 `Iterable<Widget>`（选项行/分隔/动作行/异步行可混排，`select.dart:433`）；`ShadIconButton` 在 `icon_button.dart:20`；`ShadCard` 的 `backgroundColor/radius/border` 可逐点给也可走 `cardTheme`；`ShadSwitch` 带 `label/sublabel`；`ShadInput` 带 `decoration/prefix/style/maxLines`。**没有** ToggleGroup、ScrollArea、Skeleton、NavigationMenu、Label、HoverCard、DropdownMenu。
> **仓库现状**：Shad 用量 ShadInput×11 / ShadDialog×11 / ShadButton×11 / ShadSonner×5 / ShadToast×2 / ShadFocusable×1；桥 `theme/dsw_shad_bridge.dart` 只映射颜色 + `radius: DswShape.control` + `disabledOpacity`，**排版不映射**——字号仍由调用点用 `DswType` 显式给（ADR-0027 继续管调用点）。

## 0. 判定三档

- **shad**：改用现成组件。
- **封装**：shad 没有该件 → 按 shad 风格在 `lib/ui/primitives/` 封装，或沿用既有封装件（皮只从 `DswAlias`/`DswShape` 取，经既有主题缝说一次）。
- **保留**：shad 有组件但表达不了该面**已被守卫证过**的性质 → 写明理由；不写理由的保留视为违规。

## 1. 映射表

| # | 面（截图证据） | 现状 | 判定 | 换成 / 理由 | 批次 |
| --- | --- | --- | --- | --- | --- |
| 1 | 企划/代理分段控件（`5dfe47f3` 侧栏） | `sidebar.dart:256` 手画 Container+Row | **保留**（试过，回退） | shad 无 ToggleGroup，所以按决策 2 抽了 `primitives/segmented.dart`（轨道 + 两枚 `ShadButton.ghost`）并把宽栏接上去：**放大文本守卫当场红**，`amplified_text_probe` 在 shad 的 decorator 造出的 render box 上撞到 `hasSize` 断言（`render_box.dart:2251`），去掉自算座位高度也一样，说明是库那层 `CustomPaint`/`MouseArea` 链与探针的走法冲突，不是座位数学。四条点击性质 `DswHoverTap` 已给足，标签让位律与两档守卫都已在 sidebar 上量过并有断言；而全应用只有这一枚分段控件——一枚没有第二个读者的原语正是 ADR-0025 拦的那种。要真做，先立 ADR 说清探针怎么穿过 shad 的 decorator | — |
| 2 | 新会话（`5dfe47f3`） | `sidebar.dart:507` `_Pressable`+Container | **保留**（判定改） | 指针／键盘／语义／焦点四条 ADR-0021 已满足（`DswHoverTap` 本就是放行的一支），换 `ShadButton` 得不到任何新性质；而它的两档形态（宽栏 hug 标签 ／ rail 36 见方）与刻意不做动画的理由（`AnimatedContainer` 在有限宽与无界宽之间无法插值，注释已写）都要往 shad 的固定座位里硬塞 | — |
| 3 | 会话行（`5dfe47f3`/`86e0bd57` 选中态） | `sidebar.dart:809` | 封装（沿用） | shad 无 list 组件；`DswHoverTap` 行，selected/hover 皮已在令牌（ADR-0017 S2） | — |
| 4 | 图标钮族：logo 折叠、页脚齿轮/详情、外壳右上两钮、详情栏关闭 | `sidebar.dart:447,624,681`；`app_frame.dart:529,536,550`；`details_panel.dart:215` | shad（经原语） | `DswIconButton` 的**身体**改 `ShadIconButton`（ADR-0036 决策 3；wrapper 仍管 tooltip=语义名、半径按盒、色阶、动效） | B8 |
| 5 | 页脚 Profile 行（`5dfe47f3`） | `sidebar.dart:624` | 保留 | 级联快捷菜单 shad 无对应（ShadMenubar 是横向常驻）；触发器是整行不是钮 | — |
| 6 | 字母头像（`5dfe47f3` 页脚） | `sidebar.dart:1008` `_UserAvatar` | 封装（沿用） | `ShadAvatar` 必需图片 `src`（`avatar.dart` 位置参数），字母+索引色表达不了 | — |
| 7 | hero 标题/副标题（`5dfe47f3`） | `conversation_root.dart:244,272` | 保留（排版层） | 非组件；`DswType` 阶梯 | — |
| 8 ✅ | hero 工作区 chip + recents 菜单（`5dfe47f3`） | `hero_workspace_picker.dart:75,154`（showMenu） | shad | `ShadSelect`：trigger=`selectedOptionBuilder` 画 chip（folder 图标+名+chevron），options 混排 recents 行与"打开…"动作行 | B6 |
| 9 | composer 卡容器（四张皆有） | `composer.dart:722` AnimatedContainer 三态边 | 保留 | 三态动画边是已证性质（ADR-0017 S2b，守卫读**画出来的** BoxDecoration）；ShadCard 装饰是静态主题项，表达不了"焦点优先于 hover"的过渡 | — |
| 10 ✅ | composer 草稿字段（四张皆有） | `composer.dart:763` Material `TextField` | shad | `ShadInput`（`decoration` 给无边框档、`style` 取 `DswType.base16`、maxLines/minLines 照旧） | B7 |
| 11 | `/` 命令与 `@` 提及补全面 | `composer.dart:634,666` 内联 DecoratedBox | 封装（沿用） | shad 无 combobox/autocomplete；内联补全不是浮层语义；行皮对齐 shad 选项行（hover/selected 令牌） | — |
| 12 | 附件菜单（`5dfe47f3` 回形针） | `composer.dart:1276` PopupMenuButton | shad | **落地改 `DswMenu`（`ShadPopover`）**：一把只有动作、没有值的菜单不该是 select——`ShadSelect` 在 value 为 null 时 assert `placeholder != null`，逼调用点伪造一个选中项 | B6 ✅ |
| 13 ✅ | 模型菜单（`bf783e32` 展开态） | `composer.dart:1379` PopupMenuButton | shad | `ShadSelect`：`ShadOption` 选项行 + `ShadSeparator` + 动作行 + 异步 Retry 行（options 是 `Iterable<Widget>`，异质行进得来） | B6 |
| 14 ✅ | 审批模式菜单（`5dfe47f3` 每次询问） | `composer.dart:1606` PopupMenuButton | shad | `ShadSelect<ApprovalMode>` | B6 |
| 15 ✅ | 发送圆钮（四张皆有） | `composer.dart:1721` DswHoverTap | shad | `ShadButton.ghost`，填充／悬停取 `buttonInfoFill`／`buttonInfoHover`，圆角由 `decoration.shape: BoxShape.circle` 在调用点说（button 几何不读 `theme.radius`，ADR-0029 边界②）；`enabled` 与 `Opacity(0.4)` 那对双真值删掉，禁用只由 `onPressed: null` 说一次，焦点环由 shad 补上（此前应用的主操作完全没有键盘指示） | B7 |
| 16 | 投递药丸（queue/guide） | `composer.dart:1769` | **保留**（判定改） | 落地前核对 `ShadBadge` 的参数：它有 `onPressed`，但**没有 `decoration`／边框入口**（`badge.dart:26-38` 只有 shape / backgroundColor / foregroundColor / padding）。这枚药丸读作「可按」靠的就是那圈描边，描边只能回调用点画，那就不是「用 shad 的件」了；且它是动作不是标签 | — |
| 17 | 用户气泡 / 助手 markdown / 统计行 / 工作区状态行（`86e0bd57`） | `message_item.dart:47`、`assistant_markdown`、`conversation_root.dart:330`、`composer.dart:963` | 保留 | 内容层，分别由 ADR-0034/0031/0018 与 §U3 撤回记录管 | — |
| 18 | 工具卡容器（`86e0bd57`） | 行 18 的前提在落地核对时不成立：`tool_card.dart` 与它用的 `disclosure_row.dart` **没有卡片容器**（`grep -n "BoxDecoration\|Border.all\|borderRadius" disclosure_row.dart` 只命中图标色两行），一条工具调用就是一行加展开的正文，无边框无填充。所以不是"换 ShadCard"而是"要不要给每次工具调用加一张带发丝的卡"——那是版式决定，与 §U6/§U7 同批等用户选方向；`ShadCard` 那层皮已由行 23 住进桥，选了加就直接复用 | — |
| 19 | 工具卡头行（chevron+名+摘要） | `disclosure_row.dart:17` | 封装（沿用） | ShadAccordion 是**组**语义，单卡折叠不匹配；行皮已在令牌 | — |
| 20 | 详情栏容器与两 blob | `details_panel.dart:31,76,99,256` | 保留 | 复制面留原文（ADR-0035）；容器自绘 | — |
| 21 | 设置左导航行（`e68d068b`） | `model_settings.dart:1813` | 封装（沿用） | 此移植版无垂直 nav（无 NavigationMenu）；左 accent 条 + selected 皮已在令牌 | — |
| 22 ✅ | 设置搜索框（`e68d068b`） | `model_settings.dart:1765` Material `TextField` | shad | `ShadInput`（prefix 放大镜） | B7 |
| 23 ✅ | 设置分区卡（`e68d068b` 的段落容器族） | `settings_card.dart:36,55` | shad | `ShadCard`，皮（`bgLayer1` + `shell` + `borderL2` + 裁剪）住在桥的 `cardTheme`；`shad_radius_test` 新增三条：桥值两档 + 「settings_card 里不得再出现 `Border.all(`」。**观感变化要人签收**：分区卡此前是**透明底 + 发丝**，现在按映射表 §3 多了一层 `bgLayer1` 底——这是表格写的目标形状，但只有真窗能判断它比原来读得好不好 | B8 |
| 24 | 设置字段（`e68d068b` 文件夹） | `model_settings.dart:1927` | 已 shad | `ShadInput` — 不动 | — |
| 25 ✅ | 设置开关行 | `model_settings.dart:2010,2059` 自画 AnimatedContainer | shad | `ShadSwitch`（label/sublabel 接既有文案键） | B7 |
| 26 ✅ | 设置选择器 pill + 菜单 | `model_settings.dart:1447,2419` PopupMenuButton | shad | `ShadSelect`（trigger=pill 现值） | B6 |
| 27 | 设置保存/关闭（`e68d068b` 顶部） | CapsuleButton / 图标钮 | 已 shad / B8 | CapsuleButton 内即 ShadButton；关闭钮随决策 3 | B7/B8 |
| 28 | 级联快捷菜单 | `settings_quick_menu.dart:41` OverlayEntry | 保留 | 级联浮层 shad 无对应；已有滚动 + 两档放大文本守卫 | — |
| 29 | 工作台 `+` opener / tab 右键（截图外同族） | `workbench_tab_bar.dart:158,482` | shad | `DswMenu`（`ShadPopover`，动作列表，trigger=图标钮）/ `DswContextMenu`（`ShadContextMenuRegion`） | B6 ✅ |
| 30 ✅ | 文件树行右键 / 自由窗口表头菜单（同族） | `file_tree_tab.dart:383`；`free_window_layer.dart:308` | shad | `ShadContextMenuRegion` | B6 |
| 31 ✅ | git 面板三把菜单（同族） | `git_tab.dart:462,525,1036` | shad | 选项类 `ShadSelect` / 行右键 `ShadContextMenuRegion` | B6 |
| 32 | tab chip 与拖拽 / pane 欢迎页 | `workbench_tab_bar.dart:272`；`pane.dart:232,331` | 保留（判定改） | chip 可拖拽重排，shad Tabs 无 reorder → 保留。**落地核对**：`_WelcomeAction`（`pane.dart:331-385`）是一枚**按钮**不是卡（inset 4 圆角 + h8v4 内边距 + 发丝 + 省略号标签），行 32 里"ShadCard"那半是映射表的口误；换 `ShadButton.outline` 那半是纯观感决定——半径 4→8、内边距 h12v8 会把三枚动作撑大，而它的 `enabled` 是从 `onTap != null` 导出的（`Semantics(enabled:)` 才是它真正在做的事，不是双真值）。所以留原样，与行 18 一并等真窗那一眼 | — |
| 33 ✅ | 静态标签 pill | `primitives/pill.dart:15` | shad | `ShadBadge` | B7 |
| 34 ✅ | 图标钮原语身体 | `primitives/icon_button.dart:26` | shad（身体） | `ShadIconButton.ghost`：焦点环／`disabledOpacity`／按压语义由库给，wrapper 继续只管 tooltip=语义名、半径按盒推、三档色阶（一条被反向验过的断言钉着：挪错一档即红）；`icon_button_test` 新增一条身体类型断言（正+反） | B8 |
| 35 | CapsuleButton wrapper | `primitives/capsule_button.dart:42` | 已 shad | 调用点迁完后删 wrapper（可选收尾，登记不强制） | — |
| 36 | 内容块 code/read/diff/search/terminal、state_dot、row_sweep | `primitives/*` | 保留 | bespoke 内容面，非组件层 | — |

**计数基线**（守卫的先红数字，2026-09-30 实测）：`PopupMenuButton`/`showMenu` 标识符在 `lib/ui` 共 **13 处**（composer 3、hero 1、settings 2、tab bar 2、file_tree 1、free_window 1、git 3）；裸 `TextField(` 在 `lib/ui` 共 **5 处**。

## 2. 批次与守卫（每批先红后绿）

- **B6 菜单归一**：13 处归零。守卫 `test/shad_menu_adoption_test.dart`：① 源码计数（`PopupMenuButton`/`showMenu` 标识符在 `lib/ui` = 0，照 `tap_affordance_test` 的按文件计数先例，新增即红并指名文件）；② 真开一把 `ShadSelect` 读它渲染的皮等于桥给的档（`menu_chrome_test` 的**认法改缝、断言留**：从 Material `popupMenuTheme` 改读 ShadTheme 的 select 皮，照 ADR-0034 改 `chat_view_test` 认法的先例说明）；③ 放大文本两档（1.8x/2.2x）复量打开着的菜单。**先红**：计数守卫在当前树 = 13。
- **B7 字段/开关/按钮/徽标（已落 @ d3181fb/b44c73f + 发送钮那一次）**：裸 `TextField(` 归零（5 处全换，无登记例外）；开关行渲染 `ShadSwitch`；发送钮/新会话/药丸换 `ShadButton`/`ShadBadge`。守卫：计数 + 行为（开关可点可键盘、字段可输入、三态边守卫与设置页放大守卫仍绿）。**已落**：5 处 `TextField(` 与自画 `_Switch` 类与 `pill` 三处断言全部归零（守卫 `test/shad_widget_adoption_test.dart`，先红 5 字段 / 1 开关 / pill 一条，且带正向对照，扫不到东西不算通过）；`_Switch` 的 `onChanged` 此前从未接线（只有行在动作），现在是 `ShadSwitch` 本体。**已落**：发送圆钮（行 15，`ShadButton.ghost`，同时消掉 `enabled` + `Opacity(0.4)` 这对双真值并补上焦点环）。**判定改并写明理由**：新会话（行 2）与投递药丸（行 16）留原语——前者四条性质已在且两档形态是 bespoke，后者要的描边 `ShadBadge` 根本没有入口。这两条是落地前对着 pub-cache 参数表核出来的，不是偏好。

- **B8 封装与身体**：`DswIconButton` 身体 = `ShadIconButton`（`icon_button_test` 四性仍绿 + 一条断言读身体类型）；新 `segmented` 件（sidebar 两档可点/可键盘/语义 toggled）；`ShadCard` 收工具卡与设置分区卡（`cardTheme` 进桥，`shad_radius_test` 扩一条"卡片皮只在桥说一次"）。**先红**：身体类型断言与 cardTheme 断言在当前树红。

### B7 落地的三条事实（2026-09-30，字段与开关先落；代码 `d3181fb`，守卫 `b44c73f`）

① **shad 的 placeholder 画在字段之上而不是字段之内**，会换行的提示在一行高的盒子里被腰斩（实测 1.8x 下 `86.0 vs 43.0`）——律是「该让位的是提示，不是用户要打的字」，收成一枚 `dswInputHint`；② **字段必须装进行自己声明的座位**，`ShadInput` 的 BoxyColumn 会直接喊 `overflowed by 8.0`，而 Material 的 collapsed decorator 是默默裁掉的——也就是说这条以前一直在错，只是没人报；③ `ShadBadge` 的宽度要跟标签走（`Align(widthFactor: 1)`），否则在无界行里按 99861px 撑爆终端 banner。

### B6 落地的四条事实（2026-09-30，13 处归零后补记；代码 `d2401a2`，守卫 `5ee3bd4`）

守卫 `test/shad_menu_adoption_test.dart` 从 13 归零（`lib/ui` 里 `PopupMenuButton`/`PopupMenuItem`/`showMenu` 三个标识符 = 0），
`test/menu_chrome_test.dart` 按"认法改缝、断言留"重接：读的是桥的 `popoverTheme` + `optionTheme` + `contextMenuTheme`，不再读 Material 的 `popupMenuTheme`。
随最后一把 Material 菜单退场，`dsw_theme.dart` 的 `popupMenuTheme` 与 `DswAlias.menu`（零读取，ADR-0025）**一并删除**。

1. **`ShadSelect` 的 `minWidth` 是 trigger 与浮层共用的一枚数**（`select.dart` 的 `effectiveConstraints` 同时进两个 `ConstrainedBox`）。
   所以 `DswSelect` 给 trigger 传 `minWidth: 0`，另开 `popupMinWidth`，把它做成**每行的地板**（`ConstrainedBox(minWidth:)` 与浮层的 `IntrinsicWidth` 合成），
   而不是把 chip 撑宽。
2. **动作行混排进 options 时必须自己会关**：只有 `ShadOption` 在选中时收起浮层，所以 `DswSelect.options` 拿到 `close`
   （模型菜单的"模型管理"、hero 的"打开…"都是这种自由行）。
3. **`ShadSelect` 的 trigger 没有 hover 档**（`ShadDecoration` 表达不了 hover），且 `select.dart` 里没有 `Semantics`。
   于是 `DswSelect` 自己喂 `hovered`（ADR-0017 S2 那条"可点的行要回答指针"）、自己包 `Tooltip` + `Semantics(button:)`。
   顺带把 `interactiveBgHover` 这层 wash 给了五枚此前没有的 chip。
4. **shad 自带第二套 Lucide 字体**（`lucide_icons_flutter` 3.1.20，经 `shadcn_ui` re-export），码位与 app 用的 `flutter_lucide` 1.48.0 不同名同形不同号。
   实测：断言选项行的勾选要用 `shad.LucideIcons.check`，用 app 那把常量匹配不到任何像素。**这是 B8 之前要知道的一件事**：屏幕上现在有两套图标字体在画图标。

另外两条是被守卫逼出来的测试事实，写下来免得下次再查：
放大档位下浮层的行会**盖住叫它出来的那一行**，所以"点角落空白处收起菜单"这个惯用法在 2.2x 会点在菜单自己身上——测试改用 `Escape`（`ShadPopover` 的 `CallbackShortcuts` 真接了它，实测三种手势：远点 tap ✅ / Escape ✅ / 点回宿主行 ✗）；
一把菜单量一次就要一棵新树， chained 的两把菜单测的是"两把叠在一起"。

## 3. 桥要补的主题项（一层皮只说一次）

`inputTheme`（发丝边 + 焦点边，与 composer 三态同族：静置 `borderL2` → 焦点 `brandPrimary`）、`selectTheme` 与 popover/context 的皮（`bgLayer2` + `shell` + `borderL2` + `s14` 常规/禁用两分支——ADR-0028 那层皮**搬家**不是新增）、`switchTheme`、`cardTheme`（`bgLayer1` + `shell` + `borderL2`）。`popupMenuTheme` 在 B6 归零后删；`tooltipTheme` 不动（Tooltip 不在截图内，ADR-0023 已闭）。

## 4. 明确不做

见各行"保留"。另：不换 `ShadApp` 根（ADR-0036 决策 6④，overlay 缝是已证事实）；不动工具卡读法（ADR-0031/0035）与气泡（ADR-0034）；不给 bespoke 内容块套 ShadCard；不给 composer 卡套 ShadCard（#9 的理由）。
