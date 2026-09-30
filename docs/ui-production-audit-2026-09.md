# UI 生产化审计（2026-09-29）

> 本文要守住的那句话：**每一条 UI 抱怨都必须落到一个可复现的代码位置和一条可执行的验收上，否则它只是审美意见。**
>
> 触发：用户对照 ZCode（`_archive_project/ZCode-main`，Apache-2.0）提出七条（基础 UI 四条 + 响应式三条），要求"参考其按钮布局、高级感 UI 风格与响应式设计"完善本仓库，最终达到可上线的商用产品级。
> 本文是**第一步（落 docs）**。实施按 §5 的批次走，每批一个 ADR/commit 组。
>
> 判定口径：**以代码为准，不以报告为准。** 七条里有三条需要修正表述（其中一条的根因与报告说的不是一回事），另有四条报告没提但同样阻断"商用"。

## 1. 证据基线

| 项 | 值 |
| --- | --- |
| 界面证据 | 用户截图 2 张（1176×812 窗口，代理模式，工作区 `flutter_tiptap_test`，模型 `deepseek-chat`） |
| 代码基线 | `develop` @ `2146c0f`（2026-09-29） |
| 运行时 | Flutter 3.41.9 / Dart 3.11.5，macOS arm64 |
| 参照物 | ZCode-main（Electron + React + TS，`packages/ui`，设计规范在 `DESIGN.md`） |
| 复核命令 | `dart run spike/runtime_smoke.dart`（真链路）、`flutter test test/columns_test.dart test/app_frame_test.dart test/theme_token_test.dart`、`dart tool/contrast_check.dart` |

## 2. 逐条判定

图例：**成立** = 报告与代码一致；**部分成立** = 症状真、归因错；**不成立** = 代码里已有该能力。

### 一、基础 UI

| # | 报告的说法 | 代码实况（文件:行号） | 判定 | 真因与目标 |
| --- | --- | --- | --- | --- |
| 1 | 标题栏：系统按钮与标题间距过近 | **本仓库没有自绘标题栏**：`macos/` 全仓 `grep titleBarStyle\|titleVisibility\|styleMask` = 0 命中，`MainFlutterWindow.swift:4` 只用默认 `NSWindow`。截图里那行"Agent Harness"是** macOS 原生标题栏**，间距由系统决定 | **不成立（作为我们的 bug）** | 这不是"加 padding"能修的。要呼吸感只有两条路：① `titleBarStyle = .hiddenInset` + 自绘一行应用内 chrome（能放面包屑/窗口标题，代价是要自己处理拖动区与全屏行为）；② 保持原生、把标题留空（`windowManager.setTitle('')`），让那行只剩系统按钮。**决策进 ADR-0019（编号让给了先落地的 §3-B 缺陷）**，不偷偷选 ① |
| 2a | 会话列表文字截断 | `sidebar.dart:738-742` 是 `maxLines: 1 + TextOverflow.ellipsis`——**截断策略本身是对的**。真正的问题在标题内容：`agent_runtime.dart:1382-1390` 的 `_titleOf()` 取"第一条 user 消息的文本"，而 ADR-0009 的指令注入（`instructions.dart`）正是把 `<project-instructions>` 块作为**同一条消息的前置 TextPart** 发出去的（`agent_runtime.dart:961-972`）。于是每条会话标题都以 `<project-instructions> …` 开头，80 字预算被注入块吃光 | **部分成立（症状真、归因错）** | **这是 ADR-0009 引入的回归**，且是 DEF 级：用户看到的会话名是模型读的散文，不是自己说的话。修法：`_titleOf` 跳过指令块（按块的起始标记识别），或标题改由控制器在**用户原文**上生成并持久化。**这条优先于所有美化项**。**2026-09-29 已修**：`_userWords()` 单点过滤注入 part，标题与重开气泡两处同时改，姊妹缺陷（重开会话把整块指令画成用户发言）一并闭掉；`test/restore_projection_test.dart` 两例 + `spike/runtime_smoke.dart` 一条真链守卫 |
| 2b | 无活跃状态指示 | **有**，但和 hover 是同一个颜色：`sidebar.dart:729-732` `color: selected ? color.interactiveBgHover : null`，而 hover 态用的也是 `interactiveBgHover`（`:560`、`:603`、`:731`） | **部分成立** | 选中与悬停共用一个 token ⇒ 鼠标划过谁，谁就像"当前会话"。缺的不是指示器，是**第二个状态语义**。目标：**一个与 hover 不同的独立选中 token**（ZCode 用 `bg-selected` = 10% neutral-950，见 §4.2），hover 只改亮度不改身份；行首再留一个状态圆点槽位。**不加左侧强调条**——那不是 ZCode 的做法，初稿写错已在 §4.2 更正。**两半都落地 @ `d3c5473`**：token 之外，行首加了 14+6 的状态槽（与邻居图标同列，**每行都留位、只有活跃行填点**——只在选中行出现的点会把文字横向推走，那是跳动不是指示），行自己包 `Semantics(selected: …, container: true)`；2a 那句「截断策略是对的」同时补上它缺的那半：整标题挂 Tooltip。**1.8x 测不出这行的钉高**（36 恰好等于一行 14/20），钉回 36 只有再上一档红出 `44.0 vs 36.0`——所以这行的守卫跑两档而不是一档，条数以现场命令为准 |
| 2c | Logo 与按钮留白不足；底部设置按钮孤立 | 品牌行 `sidebar.dart:374-377`：`EdgeInsets.only(left: 4, top: 8, bottom: 8)`——4px 左、8px 上下，确实紧。且 `:397` 把文案**硬编码成 `'DSH'`**（截图里侧栏是 DSH，窗口标题是 Agent Harness） | **成立，且比报告说的严重** | ① 留白按 §4 的间距标度重定；② `'DSH'` 是**第三方产品名残留在我们的 UI 上**，商用不可接受，必须换成产品名并进 i18n（`locales.dart` 双键）；③ 底部三件套（头像/齿轮/侧栏开关）要成为一个视觉组，而不是三个散落图标。**① ② 2026-09-29 已修**：复现出的真因不是"上下 8px 太小"，而是**品牌行自己多加了一层 4px**——整列已经被 `Padding(horizontal: 12)` 内缩，于是 logo 是唯一不与下方列表对齐的那一行；现已并成 `DswShape.sidebarInset` 单点真值，New Session 条也去掉它自己的 2px 侧缩（它是唯一比邻居窄 4px 的控件），品牌行与模式开关的间距从 4 提到 12。`_logoRow` 里那对 `top/bottom: 8` 是**死内缩**（行高被外层 `SizedBox(height: 60)` 钉住、内容居中，对称内缩不改变任何像素），已随包装一起删。**③ 已修 @ `005b76c`，且真因不是"没成组"**：齿轮与面板开关**嵌在**个人资料行自己的 `DswHoverTap` 里——hover 齿轮会点亮整行、点中间空白会打开快捷菜单、语义树是"一个按钮里装着两个按钮"。改成同级 + 4px 间距 + 同一中心线后，个人资料的洗色在齿轮左边就结束。守卫 `sidebar_test.dart` 的 `the footer controls are neighbours, not nested targets`，**反向验过**：拿修复前的文件跑，触发区右边界量到 268 而齿轮左边界是 206。 |
| 3 | 对话区代码块与路径堆成文字墙，缺层级；段落间距模糊 | `assistant_markdown.dart` 已有 h1–h6 与 code block 的完整样式映射（`:80-86`、`:103-124`），圆角 6/12 混用（`:106`、`:115`），`fontSizeFactor: 0.875` | **部分成立** | 排版**令牌存在**，缺的是**层级差**：正文与 inline code 的视觉权重几乎相同（截图里满屏反引号包裹的 `run-raw-sql`、`create-bucket`），列表项无呼吸。目标：inline code 降饱和 + 底色、段落/列表间距走统一标度、圆角收敛到 §4 的嵌套律。**必须用截图这一屏做前后对照验收**，不许只改常量。→ 已按测量落地，见 §4.3 的 P3 段 |
| 4 | 输入框控件拥挤、对齐不精准、缺容器质感 | `composer.dart:7` 自述"控制行是 dsh 的 toolbar"，attach/mode/model/send 一行排开；`_deliverChips`（`:881-903`）在忙时**再往同一行塞两枚**（排队/转向），间距 6/8 硬编码 | **拆成三件事，两件按数字处置**（2026-09-30）。① **缺容器质感/边界不清 = 成立并已修**：卡片只有一枚静态 6% 黑边，屏幕上没有任何东西说明"键盘在谁那里"。现在按 ZCode 的三态律走：静置 `borderL2DarkmodeThin`(6%) → hover `borderL3`(12%，正好 2×) → focus-within `brandPrimary`，`DswMotion.fast` 过渡且尊重 reduced-motion；守卫 `composer_test.dart` 的 `the card shows which surface has the keyboard` 用 autofocus／`Tab` 走开／指针进出／点回字段走完全程，读的是画出来的 `border`，**反向验过**：换回一枚静置边即红。② **对齐不精准 = 不成立**：748 宽的卡（实测矩形 42..758）里，工具行首枚图标的左沿量得 **57.0**，而正文文字左沿是字段盒左沿 42 + `_draft` 的 `contentPadding.left` 16 = **58.0**（同一根轴，1px 是字形在自己按钮盒里居中的余量）；尾部那组贴边是 dsh 原注释写明的选择（`_row` 右 pad 4 而非 8），不是错位。③ **拥挤的真因是忙时那两枚投递 chip**，已由 P4 的"先丢标签与描边，最后才丢座位"一条律接住（`3199d26`）。**按数字拒绝**：卡片内部 10/12/6 的竖向节奏改成 ZCode 的 uniform 12 只换来 2px，而 ADR-0018 刚把 seat 内容与渐隐带的关系钉在这条高度上；`theme_token_test` 的 4px 律只管**档位步长**（`step % 4`），没有授权我为一处无收益的观感重算这条高度 |

### 二、响应式

| # | 报告的说法 | 代码实况 | 判定 | 真因与目标 |
| --- | --- | --- | --- | --- |
| 5 | 缺少收起/展开的汉堡菜单及主区域返回导航 | 响应式**求解层已经存在且被测过**：`columns.dart:64-125` 有 `centerMin 640`/`sidebarMin 264`/`sidebarCollapsed 56`（rail）/`sidebarAutoCollapse 1024`/`mobileMergeViewport 768`，五步让步链（details 先缩→先关→workbench 再缩→再关），`effectiveSidebarPreference`（`:216-225`）在 <1024 自动收成 rail，`test/columns_test.dart` 守着 | **不成立（作为缺失）** | 真正缺的是**可达性与可发现性**三件事：① 收成 56px rail 后，展开入口是否还在（窄屏下没有侧栏顶部按钮可点时，用户就被关在门外）；② 没有键盘等价物（`hotkey_service.dart` 只有 3 个热键，无"展开/收起侧栏"）；③ 窄屏下主区域没有"返回会话列表"的导航。**验收必须是真把窗口拖到 900/700/520px 三档并截图**，不是加断言。**2026-09-29 三件事的处置**：① **复核实为已有**——rail 上有两枚入口（品牌位的 logo 悬停换成 panel 图标、以及会话列表位的那枚 message 图标，`sidebar.dart` 的 `_sessionList(!wide)` 分支 `onTap: widget.onToggle`），且 `DswHoverTap` 让两枚都能键盘激活（`dsw_hover_tap_test.dart` 守）；② **已补 @ `40cea0e`**：`Cmd/Ctrl+B` 注册进 `hotkey_service` 的 in-app 一档，tooltip 里把修饰键拼出来（拼法由注册它的服务给，`lib/ui` 不许自己问平台），`l10n_parity_test.dart` 一条断言钉住"两种语言都带着这个占位符"；③ **"主区域返回导航"这条撤回**：本应用没有可返回的历史——外壳是常驻三列 + tab 条（双树工作台），没有一个"上一个视图"的栈存在。ZCode 的 前进/后退 是给它的 pane 历史用的；我们要么先立"每个 pane 有浏览历史"的产品决策（新 ADR），要么那两枚按钮就是没有后座的装饰。**不做没有真值可指的界面**。②③ 之外的**指针路径**也在 2026-09-30 落成断言：`sidebar_test.dart` 的 `both forms carry a working collapse control` 两种形态各点一次，要求 tooltip 说的是当前方向（宽档 `Collapse sidebar (Cmd+B)`／轨道 `Open sidebar (Cmd+B)`），且必须打到外壳的 toggle。顺带一条测试坑：**两阶段折叠的淡入层带 `IgnorePointer`**，未 `pumpAndSettle` 就点是打在空气上——而 `find.byTooltip` 照样命中（widget 仍在树上），所以只断言「存在」会**为错误的理由通过**。**三档窗口的真机截图仍然欠着**，这条不是它的替代品 |
| 6 | 窄屏下下拉菜单压缩输入空间 | 控制行是定宽 chip 的 `Row`（`composer.dart:883`、`:930`），未见 `Flexible`/`Wrap` 用于该行的模式与模型选择器（chip 内部有 `Flexible`，`:821-823`，但那是附件 chip） | **成立（需实测确认溢出）** | 目标：窄阈值下模式/模型选择器**降级为图标 + tooltip**，或整行移到第二行（ZCode 的做法见 §4）。**RenderFlex 溢出是可测的**：给 widget 测试加一个 420px 宽 composer 的用例，断言不溢出。**2026-09-29 实测后两处更正**：① 我写"未见 Flexible"是**看漏了**——`_row` 里早就有 `LayoutBuilder` + 两个宽度闸门（mode 140 / model 220），`_ModeChip` 内部也已经有"挤不下就丢标签留图标"的一档；② 真缺陷不是"没有降级"而是**降级的方向反了**：model 在 220px 就整枚消失（此时图标位还放得下），而 blocked 态的排队/转向两枚 chip 是不肯缩的定宽件——260px 下实测 `RenderFlex overflowed by 67 pixels`。已由 `3199d26` 改成"三个件共用一条律：先丢标签与描边，最后才丢座位"，闸门收成一个数（140），5 条宽度用例钉住（320/260/420/120 + 长文件夹名）。**2026-09-30 补上"把菜单打开"的那一半**：那五条量的都是**合着的一行**，而报告 6 说的是"下拉菜单压缩输入空间"——菜单只在点开之后才存在，所以这半句从未被证明过。新增 `composer_test.dart` 的 `a menu wider than the column overlays it, never squeezes it`：260px 的列里依次打开附件菜单与模式菜单，每一把都要 ① `TextField` 的矩形与打开前逐像素相同，② 每一条 `PopupMenuItem` 完整落在视口内，③ 点 barrier 收起后树里不剩 item（没弹回来的路由会把它的 timer 留给下一个面）。数字值得记，因为它证明这条断言不是空转：**260px 的列里附件菜单第一行量得 504.0 宽、右沿被 material 收到 792.0**（视口 800）——菜单比叫它出来的那一列宽出一倍，只有"盖在卡片上"这一种画法能成立；模式菜单那 `minWidth: 260` 恰好等于整列，是同一件事的极端形式。**报告 6 到此闭合**：窄列里那一行按档位自己丢座位（`3199d26`），它叫出的菜单从不回头挤那一行（overlay route + 视口 clamp，现在有断言）。基线 `+899 -2`，两条注册失败未动 |
| 7 | 长路径与代码块在极窄屏破坏排版 | 代码块有 `borderRadius`/字号（`:103-124`）；**未见** `SingleChildScrollView` 横向滚动或 `TextScaler` 处理；`TextOverflow.ellipsis` 用在侧栏而非正文路径 | **成立** | 目标：代码块横向可滚（不折行时不撑破列）、长路径中段省略（`…tap_test/foo.dart` 式）、极窄下正文字号不塌。这条与 ADR-0005 欠的**文本缩放**（登记表已列 P2，ZCode 用单一 `--ui-font-size` 标度解决）是同一族问题，合并进 ADR-0017。**2026-09-29 实测后拆分**：① "代码块要横向滚动"这条**撤回**——`code_block.dart:106-107` 明写 body 走 `pre-wrap`（折行而不横滚，dsh 同款决策），banner 的标签是 `Expanded` + ellipsis，窄列下不会撑破；横滚只是另一种产品选择，不是缺陷。② 真溢出在别处，而且机制值得记进规则：**Row 的非 flex 子件是按"无限宽"量出来的**，所以只写 `overflow: ellipsis` 拦不住溢出——`composer.dart` 的工作区状态条被长文件夹名撑出 **487px**，`diff_tab` 的 `← 旧路径` 明明已经有 ellipsis + maxLines 仍照漏。`2b84051` 把三处共享件（每条工具卡与推理行都用的 `DisclosureRow` 头、终端提示行的 cwd、diff 文件头的旧路径）加上 flex 上界，`test/disclosure_row_test.dart` 顺手把这条机制反向验死：同样的 Text 换成非 flex 包装，180px 面板溢出 1224px 而 ellipsis 原样在场。③ 这一条里 `TextScaler` 那一格（"极窄下正文字号不塌"那一族）**已由 ADR-0017 S3 闭合并带守卫**（`3301165`/`5cbf566`/`bab3a0f`）：用户的字号档位现在**乘进**平台 scaler（`main.dart` 根 `MediaQuery`，默认档 1.0 保证零改动），接上之后在 1.8x 实测到 7 处裁字座位，律是「一行高的 chrome 把高度取自那一步」。**没闭的**：`grep -rhoE "height: (2[0-9]|[3-9][0-9]|1[0-9][0-9])," lib/ui | wc -l` 现场 **38 处**（15 个文件）写死的 ≥20px 座位——它们**不等于**会裁，2026-09-30 已逐条分过类（尺子现在挂在十七个面上：外壳／每一棵工作台 tab 正文／三棵右键菜单／设置页七个分区／企划三面板／对话流七个块／侧栏会话列表／子代理／diff／composer 卡片与它的五把下拉／git 面板的两把菜单／审批面板／忙时队列条／自由窗口／底部快捷菜单与设置页那把打开着的主题菜单）。余下的是真机「放大文本」四档人工走查，且**守卫只到 2.2**（XXL 不在证明范围内）。**普查收口（`764f890`）**：38 处按"装的是字还是图形"分完——**33 处根本不装文字**（图标命中区 24/28、条带高度、`itemExtent`；`Icon(size:)` 不随 `textScaler` 长大，`clipDefects` 在那里原理上不可能开火，钉着是正确答案），**5 处带字**（composer 的模型菜单行／动作行／模式菜单行、`plan_workspace.dart:364`、`terminal_tab.dart:386`），而它们所在的面都已在两档下、**点开之后**量过。同一批查出这把尺子的**第三种自欺画法**：宿主在 `home:` 里写一枚全新的 `MediaQueryData(disableAnimations: …)` 会连同 `textScaler` 一起换掉整个 data 对象，那条缝上的走查因此量的是 1.0 并报成通过——18 个用尺子的宿主里只有 `chat_view_test` 这样写，改成 builder 内 `MediaQuery.of(context).copyWith(…)` 之后，把 `chat_view.dart:302` 钉回 `height: 26` 立刻红出 `40.0 vs 26.0`／`48.0 vs 26.0`，与那行注释记的历史数字一致。**报告 7 可测的部分到此闭合**，剩下的仍是真机四档走查，而 2026-09-30 再次确认这台机器给不了：`screencapture -x` 报 `could not create image from display`（exit 1），与 `osascript` 的 `-1728` 是同一个缺权限的两张脸 |
## 3. 报告没提、但同样阻断"商用"的四条

| # | 发现 | 证据 | 级别 |
| --- | --- | --- | --- |
| A | **产品名在 UI 里自相矛盾**：侧栏写 `DSH`，窗口标题写 `Agent Harness`，bundle id 是 `com.stow.agentHarness` | `sidebar.dart:397`；`macos/Runner/Configs/AppInfo.xcconfig` | DEF·商用阻断。**2026-09-29 已修**：品牌行走 `context.tr('appName')`，`en`/`zh` 双键同为 `Agent Harness`（名字不译），`sidebar_test.dart` 一条用例同时断言"我们的名字在、`DSH` 不在" |
| B | **正文出现文字重叠**：截图里统计行的中文数字/量词压在 `SDK returns \`{data, error}\` structure…` 同一基线上。**已定位并修掉**：不是覆盖层缺 scrim，而是**输入区自己那条设计上就半透明的渐隐带**——`conversation_root.dart:530` 的 `_Masked` 在 seat 矩形上画 `transparent → bgBase`（`composerMaskHeight = 36`），而 seat 的第一条内容就是统计行，等于把不透明文字画在"能看穿"的区域里；截图右侧还浮着滚动到底按钮 ⇒ 列表不在底部，正文有行被滚到带子下面 | 原图（**1152×795**，本文此前记作 1176×812）裁剪放大：重叠在 y≈650–672 / x≈680–745。排除项：① 渲染器叠字——4 个 fixture 逐字符走 `getBoxesForSelection`，无任何 (行,左) 位置收到两个框；② `[3]` 角标——它是 14.2×22 的独立段落、占了横向推进，只是上浮（截图里那个"³"就是它，正常）。修法与守卫见 [ADR-0018](adr/ADR-0018-def-seat-mask-overlap.md) @ `bd38147` | DEF·**已修**（余真机看一眼 36px 空档是否显空） |
| C | **中列正文看起来未居中**：截图里正文贴右、左侧留出一条空白。**已复现，且不是缺陷**：`chat_view_test.dart` 在 1400/1152/700 三档把三块矩形量出来了——输入卡 310–1090 / 186–966 / 16–684，中心 700 / 576 / 350 = 三档视口宽度的正中；正文左沿 326 / 202 / 32 = 卡片左沿 + 16；用户气泡右沿 1074 / 950 / 668 = 卡片右沿 − 16。**那条空白是用户发言自己的**：`message_item.dart:53-60` 按 dsh 的 `max-width: min(525px, 82%)` 把气泡封顶并右对齐（`mainAxisAlignment.end`），748 列里气泡只占 525 ⇒ 左边留 223px；700 宽时列变 636，百分比接管，实测 521.5。审计初稿把这条右对齐的旁白当成了正文 | 三档实测矩形（守卫已进 `chat_view_test.dart`）+ `chat_view.dart:176-179,203-215`、`message_item.dart:47-60` | DEF·**非缺陷，撤回**；留下的是那枚守卫：`Center` 换成 `Alignment.centerLeft` 即红（实测 `Expected: <326.0> Actual: <32.0>`） |

> B 与 C 都来自同一张截图。**两条现都已结**：B 是缺陷（透明渐隐带，ADR-0018 @ `bd38147`）；C 不是缺陷，右边缘那条空白属于按 `min(525px, 82%)` 封顶并右对齐的用户气泡，中列与输入卡同轴——三档视口量过，守卫已进 `chat_view_test.dart`。留此记录是为了说明本文的判定口径改过一次的经过：**能用矩形量出来的，就不要留在"看起来"这一级**。
>
> 本报告初稿曾列第三条"会话列表在真机上为空"，**已自查删除**：第一张截图是全新启动（`暂无会话` 是正确状态，那时还没有任何会话），不是缺陷。留此记录是为了说明本文的判定口径：截图里看不出来的一律不算。

## 4. ZCode 参照（实测数值，2026-09-29 逐文件核过）

栈：Electron + React 19.2.7 + TS + Tailwind v4 `@theme` + shadcn 派生原语 + Zustand + `react-resizable-panels`。**不是 Flutter**，所以搬的是数值与律，不是代码。令牌真值在它的 `DESIGN.md`（537 行）。

### 4.1 窗口 chrome（对应本文条 1）

| 事实 | 值 | 证据 |
| --- | --- | --- |
| 标题栏形态 | `titleBarStyle: "hidden"` + 红绿灯手动定位 `{x: 22, y: 23}` | `packages/desktop/src/main/desktopWindowChrome.ts:140-141`、`desktopWindowButtonPosition.ts:5` |
| 左侧避让 | **96px**（macOS），Windows 右侧 **136px**，且由原生 `onWindowControlsOverlayChanged` 实时同步而非写死 | `useAppChromeState.ts:7,155-170`、`desktopWindowButtonPosition.ts:8` |
| 顶栏高度 | `h-14`（56px）浮层，内部 macOS `h-14` / Win-Linux `h-12` | `DesktopTopOverlay.tsx:106,118-119` |
| **顶栏里没有标题** | 顶栏只放侧栏开关 / 前进后退 / 新任务 / 更新按钮；标题在**第二行** `WorkspaceHeader`（`h-12` + `border-b border-border/50` + `p-2` + `[app-region:drag]`） | `DesktopTopOverlay.tsx:152-217`、`WorkspaceHeader.tsx:140-141,157` |
| 侧栏隐藏时 | header 右让 `pl-66`(264px)/`pl-58`(232px)（macOS），其他平台 `pl-44`/`pl-38` | `WorkspaceHeader.tsx:123-133` |
| 可拖与可点 | 拖拽靠 `[app-region:drag]`，交互簇再标 `[app-region:no-drag]` | `DesktopTopOverlay.tsx:131` |
| 面板圆角随平台 | Win 5 / macOS≥26 **12** / 其他 6 / Linux 12，把手内缩 = 圆角 + 4 | `workspaceShellWindowChrome.ts:14-29` |

> **对本仓库的含义**：报告条 1 的"呼吸感"在它那里不是调 padding，而是**放弃原生标题栏、自绘两行 chrome**。这是一次窗口形态决策（红绿灯定位、拖动区、全屏行为都要自己负责），因此单独立 **ADR-0018**，不在美化批里顺手做。

### 4.2 侧栏（对应条 2）

| 事实 | 值 | 证据 |
| --- | --- | --- |
| 宽度 | 默认 **264px** = 下限，上限 50%，键盘步长 16px，持久化；并镜像进 CSS 变量让浮层跟着变 | `WorkspaceShellLayout.tsx:99-107` |
| 折叠入口 | `PanelLeftClose/Open` 图标 + **`CmdOrCtrl+B`** | `DesktopTopOverlay.tsx:78,159`、`packages/shared/src/shortcutCommands.ts:70` |
| 折叠态 | 空 rail：`border-r bg-background-alt` + `h-9` 拖拽条 + **一枚 `size-7` ghost 按钮，logo 交叉淡入成"展开"图标** | `WorkspaceSidebarCollapsedRail.tsx:17-44` |
| Logo 与按钮之间 | 先一段裸 `h-12` 拖拽占位，再 `flex-col gap-1 px-2 py-3`（Win `py-2`） | `WorkspaceSidebar.tsx:1257,1266` |
| 行 | `rounded-lg pl-2.5 pr-1 py-1`，`gap-2` | `TaskListItem.tsx:544` |
| **选中态** | **只有背景染色** `bg-selected`（= 10% neutral-950），**没有左侧强调条** | `TaskListItem.tsx:550`、`styles.css:330-341` |
| 状态指示 | 行首 4×4 槽位放 `h-1.5 w-1.5 rounded-full` 圆点（运行/等待等） | `TaskListItem.tsx:556-584` |
| 标题截断 | **mask 渐隐，不是省略号**；标题行 `h-6 text-ui-base`，元信息行 `h-6 text-foreground-subtle`（左标签 truncate、右时间与 `·`） | `TaskListItem.tsx:642-681,716-718`、`components/TaskTitleOverflowText.tsx` |
| 底部簇 | `gap-2.5 px-4 pt-2 pb-4`；账号胶囊用**非对称圆角** `rounded-tl-2xl rounded-bl-2xl border-0 pl-0` 与相邻件焊成一组 | `WorkspaceSidebarFooter.tsx:218-228` |

> **更正本文 2b 的原目标**：我初稿写"选中加左侧 2px 强调条（ZCode 的强调条律）"——**ZCode 没有强调条**，它靠的是**一个与 hover 不同的独立 token**（`bg-selected` = 10% neutral-950）加**行首状态圆点槽**。照它做就够了；强调条是我自己加的，不许挂在 ZCode 名下。

### 4.3 会话区层级（对应条 3）

| 事实 | 值 | 证据 |
| --- | --- | --- |
| 列宽用**容器查询**，量的是面板不是窗口 | `@min-[864px]/conversation: w-[calc(100%-6rem)] max-w-4xl`；`@min-[1280px]/conversation: w-[calc(100%-24rem)] max-w-6xl`；容器声明 `@container/conversation` | `v4/conversationLayout.ts:5`、`v4/SessionPane.tsx:4624` |
| 反"文字墙"那一行 | `leading-[1.75] tracking-wide` + 首子元素 `mt-0`、末子元素 `mb-0` | `components/ai-elements/message.tsx:1368` |
| 标题节奏 | h1–h6 一律 `mt-6 mb-4`；**只有 h1/h2 改字号，h3–h6 改字重** | `message.tsx:441-446` |
| inline code | `rounded-md bg-markdown-inline-code/50 mx-0.5 px-1.5 py-0.5 font-mono text-ui-sm`（**底色 + 缩小 + 等宽**，不靠加粗） | `message.tsx:1548` |
| 代码块 | `rounded-xl bg-background`（**靠反色，不加边框**）+ 头部 `px-3 py-2 text-muted-foreground` | `code-block.tsx:155,190` |
| 工具输出降权 | `text-ui-xs text-foreground-subtlest` 的 chip：`rounded border bg-background-alt px-1.5 py-0.5 leading-none`；路径 `font-mono tabular-nums`；正文块 `max-h-60 rounded-xl border bg-muted/15 p-3` | `ToolSummaryRow.tsx:93`、`renderers.tsx:32`、`ToolCallBody.tsx:109` |

> **P3 落地（`a13308c`）——量出来的现状、做的一件事、按数字拒绝的四件事。**
>
> 用 widget 测试量的"before"（`AssistantMarkdown` 在 520px 列里渲染 `A 段 / ## 标题 / B 段 / C 段`，四块都是单行，逐块取 `RenderParagraph` 的全局矩形）：**块与块之间只有一种距离，18.4px**——正文行 28、标题行 32，而标题上下的空档与"两段之间"完全相等。层级缺失不是因为字号（h1–h6 的 ramp 早就在 `dsw_typography.dart:106-113`），是因为**运行时从没拿到过块间距**：`HeadingStyle.padding` 从未设置，标题与段落共用渲染器那条空白行（`gpt_markdown-1.2.1/lib/markdown_component.dart:397-415` 的 `NewLines`，`height: 1.15 × 字号`）。
>
> 做的**只有这一件**：`heading: HeadingStyle(padding: EdgeInsets.only(top: DswShape.xl, bottom: DswShape.lg))`，即 ZCode 的 `mt-6 mb-4`（本次逐字复验 `message.tsx:442-449`）。Flutter 不折叠 margin，所以 24/16 是**加在**那条空白行之上而非替换它，实测 42.4 / 34.4 对 18.4。守卫 `markdown_rendering_test.dart` 断言的是**差值**（标题前的空档 − 段落空档 == `xl`），不是绝对像素，因此渲染器改空白行高度不会假红；反向验过：删掉那三行，断言以 `Expected: 24.0 / Actual: 0` 失败。
>
> 按数字拒绝的四件事：
> 1. **`tracking-wide` 不加**——ZCode 的 0.025em 是配 14px 正文的（`styles.css:58,145`：`--ui-font-size: 14px`、`--text-ui-base: var(--ui-font-size)`），我们正文 16px，同一 em 值在更大字面上视觉加倍；而 `DswType` 整张表是从 Figma 的 `--dsw-font-*` 逐条搬的（`dsw_typography.dart:1-16`），加字距属于改令牌表而不是改节奏。
> 2. **inline code 不再降饱和**——ZCode 的值是 `bg-markdown-inline-code/50 mx-0.5 px-1.5 py-0.5 font-mono text-ui-sm`；换算 12/14 = 0.857，我们是 `fontSizeFactor: 0.875`（`assistant_markdown.dart:99-109`），等宽/缩小/有底/无边框四条全在。截图那堵"反引号墙"是**内容**（agent 把标识符都包了 code）而不是样式缺权重；要动只能动 `markdownInlineCode` 那个不透明色标（`neutralBluish100`/`850`），那是 ADR-0004 的地盘，不搭这趟车。
> 3. **h3–h6「只改字重」不照搬**——ZCode 整个标题阶只比正文大 4px（h1 18 / h2 16 / h3–h6 全 14，权重 600/600/600/600/500/400），我们是 24/22/20/16/16/16。把 h3 拍平到 16 会砍掉代理回复里最常用的那一级；把 h5/h6 降到 500/400 要在 Figma 导出的 ramp 上凭空造 dsh 没有的两档（现况"h5/h6 共用 base-strong"正是上游 CSS 的写法）。**留下的真实缺陷**：h5/h6 与 h4 同权重=假层级，只在 `#####`/`######` 出现时可见——交给 ADR-0017 S3（base 字号标度）一并判，不在这里造令牌。
> 4. **首子元素 `mt-0` 做不到**——`HeadingStyle.padding` 是**每文档一个值**，抹掉首个标题的 24 会连带抹掉后面每一个的 24。代价：文档以标题开场时，气泡顶部多 24px 空气。记为已知偏离，不做需要布局回读或构建顺序耦合的花活。

### 4.4 Composer（对应条 4、6）

| 事实 | 值 | 证据 |
| --- | --- | --- |
| 容器 | `flex-col gap-3 rounded-2xl border border-input-border bg-input p-3`，`hover:` 换边色、`focus-within:` 再换 | `prompt-editor/ChatPromptEditor.tsx:347-348`。三档边的**实测值**：静置 `--color-border` = neutral-950 **10%**、hover **20%**、focus-within 换色——`--color-input-border-focused` 在两套彩色主题里 = `--color-brand`（sky-400 / sky-500），在两套黑白主题里退成 `--color-border-hover`（`:497-499,642-644`）——`styles.css:161,176-177,196-198,314,344-346,467,479-480`。即 **hover 是静置的两倍不透明度，focus 换色相而不是加粗** |
| 本仓的对应实现 | 静置 `borderL2DarkmodeThin`（黑 **6%**）→ hover `borderL3`（**12%**，正好 2×）→ focus-within `brandPrimary`（亮色 rgb 15,17,21）——同一条律，档位按 dsh 自己的标度取。**卡片底色不变**：ZCode 还换 `bg-input-focused`，但那需要一枚新底色令牌 × 两个主题，而让它说话的是边不是底 | `composer.dart` 的 `_card`；守卫 `composer_test.dart` 的 `the card shows which surface has the keyboard`（autofocus／`Tab` 走开／指针进出／点回字段，四段都读的是画出来的 `BoxDecoration.border`，反向验过：把三态换回一枚静置边即红） |
| 工具条基线 | `flex items-end gap-3`——**以底边对齐**，不是居中 | `:388` |
| 左右簇 | 左：附件/`+` → 模式/审批；右：`ml-auto gap-1.5` 取消(`size-8`) → 模型 → 思考 → 发送(`size-7 rounded-lg bg-brand`) | `:389-403,413-447` |
| **窄屏策略** | **实测降级为图标，不换行**：`useComposerToolbarFit.ts` 按 0–3 档依次丢标签 → 丢 provider 前缀 → 丢思考图标 → 模型触发器收成 `size-7 p-0 gap-0`；用离屏 `cloneNode` 探针 + `ResizeObserver` 量，兜底 gap 12px | `useComposerToolbarFit.ts:4-45,55-66,84-93`、`V4ComposerToolbar.tsx:1065,1068` |

### 4.5 断点（对应条 5、7）

最小窗口 **480×640**（`desktopWindowSize.ts:6-7`），内容 `min-w-[320px]`（`WorkspaceShellLayout.tsx:1640`）。自动收起：会话列 <**360px** 收侧栏、侧 pane <**480px**，300ms 空闲判定、仅窗口尺寸变化触发（`:108,117,118,460-500`）。容器阈值：会话 480/624/864/1280、composer 480/640、workspace-header 420/560、share 480/640、artifacts 380（`WorkspaceHeaderSections.tsx:471`、`styles.css:88`）。**只有 markdown 表格用窗口宽度**（`markdown-table.tsx:146,150`）。

### 4.6 可搬的"高级感"清单（零新依赖）

4px 基 + 4/8/12/16/20-24 节奏（`DESIGN.md:265-273`）· radius-by-nesting `xl→lg→md→sm` 及控件对照表（`:285-334`）· 单一 `--ui-font-size: 14px` 驱动 ±4/2/0/-1/-2/-4 标度，**绝不动 root font-size**（`styles.css:58,143-151`、`DESIGN.md:212`）· 边框/hover/选中一律 `color-mix(in oklab, neutral-950 N%)`（`styles.css:330-341`）· **先对比度后阴影**的分层（`:463-476`）· 时长 150（颜色/宽度）/200（位移）/300（padding）· 4px 透明把手 + 2px 显形线（`WorkspaceShellLayout.tsx:1627-1630`）· `tabular-nums` 与 `text-wrap: pretty`（`styles.css:70`）。

**明确不抄**：它 `styles.css:120-124` 有 `*:focus,*:focus-visible{outline:none!important;box-shadow:none!important}`，与它自己 `DESIGN.md:504` 矛盾、且会杀掉键盘焦点。本仓库的 `DswHoverTap` 四性测试（指针/键盘/语义/右键）是更强的既有约束，**不许为了"像 ZCode"退化它**。

### 4.7 许可与归属（搬之前必读）

ZCode 是 Apache-2.0，但它的 `NOTICE.md:70` §4 明写：**Apache-2.0 不覆盖第三方代码、原生二进制、字体、图标与 web 资源**。具体到本项目会碰到的：
- `packages/ui/src/components/ui` 与 `styles.css` 是 **MIT shadcn**；`components/ai-elements` 源自 **Vercel ai-elements**（`third-party/copied-components.json`）。我们本来就已直接依赖 `shadcn_ui` 0.56.3，所以**不引入新许可面**——只借数值。
- **不可搬**：`ZCode` 名称、`public/logo/icons/*`、`packages/ui/src/assets/provider-icons/*`（`model-provider-logo-sources.json` 记录它们是 openrouter 等官方品牌文件原样拷贝）、通知音 mp3、channel/cli/plugin 图标。
- **可搬**：数值、令牌公式、radius/间距律、容器查询阈值、以及"实测降级"这个算法思路。
- `third-party/embedded-components.json` 里 Skia/expat/freetype 标着 `reviewRequired` 未解——**不要碰那三个的产物**。

## 5. 实施批次（每批都要过门禁 + 给截图证据）

| 批 | 内容 | 归属 | 验收 |
| --- | --- | --- | --- |
| **P0 先修坏掉的东西** | §3-B 文字重叠、§3-C 中列疑似未居中（先复现）、2a 会话标题被指令块污染、§3-A 产品名统一 | DEF（各立 ADR 或并入登记表） | 复现→最小化→修→截图前后对照。**已闭 4/4**：2a（`_userWords` 单点过滤）、§3-A（`appName` 双键 + 品牌行）、**§3-B @ `bd38147`（ADR-0018：真因是输入区那条设计上半透明的渐隐带，统计行被画在它里面；守卫量"统计行顶 − scrim 顶 ≥ 带高"，删 Padding 即红）**、**§3-C @ 本轮（复现完成：不是缺陷——中列与输入卡同轴，左边的空白是用户气泡自己的 `min(525px, 82%)` 封顶；1400/1152/700 三档实测矩形已写成 `chat_view_test.dart` 的同轴守卫，`Center`→`Alignment.centerLeft` 即红）** |
| **P1 令牌与身份** | ADR-0017（radius 律 + base 字号标度 + 选中/hover 分离）、3A 产品名统一并进 i18n | ARC/UI | `theme_token_test.dart` 新守卫 + `l10n_parity_test.dart` + `contrast_check`。**部分完成 @ `c2255c6`**：radius 律与 4px 节奏已落地（94 处转换、4 例守卫反向验过）、选中/hover 已分离（`interactiveSelected`，light 0.10 / dark 0.12）。本批（`74ab800` + `88b9f54`）补上：3A 产品名（`appName` 双键 + 品牌行取之）与 2c 的品牌行内缩已闭，`sidebarInset` 成为侧栏唯一的水平基准线；radius 守卫**换掉了只认数字的写法**——`c2255c6` 那句"清零"当时并不成立，`BorderRadius.circular(wide ? 12 : 999)` 这种三元字面量从 `circular\([0-9]` 的眼皮底下过了 **4 处**（侧栏 New Session 两条、`capsule_button` 两条 `14/18`）。现在要求括号后的第一个非空 token 必须是 `DswShape.`，4 处全部收回；`capsule` 的 14/18 本就是它自己高度的一半，写成 `DswShape.pill` 是**同像素**的替换。**S3 base 字号标度已落 @ `3301165`→`db18457`**：`AppFontSize.scale` 乘进平台 scaler，两档双向守卫挂在**十五个面**（上述六面 + 三棵右键菜单 + 子代理 + diff + composer 卡片与它的五把下拉 + git 面板的两把菜单 + 审批面板 + 忙时队列条 + 自由窗口），实测随步子长高的落点现场 46 处（`grep -rn textScalerOf lib | wc -l`）（`grep -rn textScalerOf lib | wc -l`，含 `itemExtent` 与固定列宽），并第一次为扩展面板与块原语建立测试（顺带修掉表格不订阅 store、pill 被上下裁、终端 chip 顶爆 banner 三处真缺陷）。月网格那格也没留着：`MonthView` 的 `cellBuilder`/`width` 是包自己的入参，日期格改由宿主画（`21dc359`，日程面板因此第一次能勾选完成），过程中量出包的第二条默认缺陷——它按**窗口宽**算网格，800x600 里带日期的任务条落在 `Offset(742.9, 605.6)`，在树里、在屏外。余真机四档走查待人工（见 ADR-0017 S3 的「没闭的口」）。**输入卡的三态边 @ 本批**：静置 6% → hover 12% → focus-within `brandPrimary`，与 S2 那条"选中与 hover 是两个 token"同源——一个状态一枚token，不靠加粗不靠阴影（详见 §4.4 与 §2 条 4） |
| **P2 chrome** | ADR-0019（标题栏决策）、侧栏品牌行留白与底部簇成组、2b 选中态 | ARC/UI | `app_frame_test.dart`、`sidebar_state_test.dart` + 真机截图。**现状**：2b 已闭（`interactiveSelected`，ADR-0017 S2）、品牌行留白已闭（`sidebarInset` 单点，`74ab800`）；**底部三件套已成组 @ `005b76c`**（真因是嵌套点击目标，不是间距；见 §2 条 2c ③）；**ADR-0019 置 PROPOSED 不动手**——它的三个候选全是观感改动，而本机 `screencapture -x` 报 `could not create image from display`，看不见就不能签收；开工前置条件（会话标题进 `lib/model`、拿到走查）写在 ADR 里 |
| **P3 会话区层级** | 条 3（inline code/列表/段落节奏） | UI | **已修 @ `a13308c`**：唯一真实的缺陷是标题**块间距**——量过，渲染器里所有块间距都是同一条 18.4px 空白行，所以 `## 标题` 与"两段之间"等距。已按 ZCode `mt-6 mb-4` 补成 24/16（实测 42.4 / 34.4 对 18.4），守卫用**差值**断言并反向验过。inline code 降饱和、`tracking-wide`、h3–h6 只改字重、首子元素 `mt-0` 四件按数字拒绝，理由在 §4.3 的 P3 段。**余**：截图对照仍缺（无 Screen Recording 权限） |
| **P4 响应式可达性** | 条 5/6/7：rail 展开可达、键盘等价、composer 窄屏降级、代码块横滚 | UI | 900/700/520px 三档截图 + 420px composer 不溢出的 widget 测试。**部分完成 @ `3199d26`/`2b84051`**：窄屏降级改成"先丢标签、最后才丢座位"的一条律并收了口（两个闸门→一个 140），共享行（`DisclosureRow`／终端 cwd／diff 旧路径）补上 flex 上界；"代码块横滚"按证据撤回（body 是 `pre-wrap` 的设计决策，见 §2 条 7）。**余**：900/700/520 三档真机截图。**条 5 已处置**：`Cmd/Ctrl+B` 注册进 in-app 一档并把修饰键写进 tooltip（`40cea0e`），rail 的展开入口复核实为两枚且都能键盘激活，"主区域返回导航"按证据撤回（没有可返回的历史，见 §2 条 5） |

**批次纪律**：每批结束跑 `dart format --set-exit-if-changed lib test tool spike` → `dart analyze --fatal-infos lib test tool spike` → `dart tool/check_architecture.dart` → `flutter test`（2026-09-29 P1+P4 两批与 `Cmd/Ctrl+B` 之后是 `+829 -2`，P3 之后 `+830 -2`，ADR-0018 与侧栏底部成组之后 `+832 -2`，§3-C 同轴守卫之后 `+833 -2`，输入卡三态之后 `+834 -2`，文本缩放接线 + 一行高座位 + 1.8x 双向守卫之后 `+836 -2`，工作台五棵 tab 正文的座位与守卫之后 `+837 -2`，设置页七个分区 + 企划工作台两阶段的座位与守卫之后 `+839 -2`，企划扩展面板的首批守卫（并修掉表格不订阅 store）之后 `+847 -2`，对话流七个块的首批测量（pill 随步子、chip 不再顶爆 banner）之后 `+854 -2`，日程月网格改由宿主画（1.8x 不裁 + 点任务条走通 store，另删一条同名重复 case）之后 `+855 -2`，会话行的状态槽／tooltip／两档座位守卫之后 **`+858 -2`**，两棵右键菜单之后 `+871 -2`，composer 那棵之后 `+873 -2`，git 那棵之后 `+875 -2`，审批面板／队列条／自由窗口三棵之后 `+881 -2`，快捷菜单与设置页那把打开的菜单之后 `+883 -2`，侧栏接上数据并把宽档整列改成一个滚动视图之后 `+885 -2`，overlay 接线改正（菜单／面板／拖拽芯片第一次真被放大）并修掉它抓出的三处之后 **`+887 -2`**），只许 `app_scope_test` 的 `/var`↔`/private/var` 与 `plan_workspace_test` 的 `find.text('notes')` 那两条失败），并按 `git-commit` skill 分逻辑提交。UI 改动**没有截图就不算验收**——本会话里终端无 Screen Recording 权限（`screencapture -x` 直接报 `could not create image from display`），需要用户在系统设置里放行，或由用户本人走查；**能用 widget 测试量出来的布局事实已改为以测试为证**（窄列 320/260/420/120 与 180px 面板的溢出断言，见 `composer_test.dart`、`disclosure_row_test.dart`）。

## 6. 明确不做

- **不搬 ZCode 的二分树 pane layout**（评估文档 §3 已判"当前两栏够用"）。
- **不引入新依赖**做滚动/虚拟列表/字体缩放——`flutter test` 与 `pubspec` 现状能覆盖的就用现状。
- **不做 Web/移动断点体系**：三桌面目标（ADR-0003），响应式的边界是"窗口能拖到多窄还不坏"，不是手机适配。
- **不为"高级感"动 ADR-0004 的对比度豁免面之外的正文配色**——那要另立 ADR 并跑 `contrast_check`。
- **不复制 ZCode 的代码**（本仓库规则是不 fork 其代码）；搬的是数值与律。
- **不碰 ZCode 的品牌与素材**：`ZCode` 名称、`public/logo/icons/*`、`provider-icons/*`（官方品牌文件原样拷贝）、通知音、以及 `reviewRequired` 未解的 Skia/expat/freetype 产物——它的 `NOTICE.md:70` §4 明写 Apache-2.0 不覆盖这些。

## 7. 关联

- 既有评估：`docs/zcode-vs-agent-harness-2026-09.md` §3（UI 逐区对比）、§7 A5（文本缩放）、§7 A7
- ADR：ADR-0004（对比度豁免）· ADR-0005（设置页/偏好；欠的文本缩放已由 ADR-0017 S3 接上）· ADR-0007（双模式外壳）· ADR-0009（指令注入，**本文 2a 的回归来源**）· ADR-0011/0015（架构门禁）· **ADR-0017**（设计令牌契约，IN-PROGRESS；S1/S2/S2b/S3 已落，S3 文本缩放带 1.8x 双向守卫 @ `3301165`/`5cbf566`/`bab3a0f`，余非 AppFrame 树的紧座位与真机四档走查）· **ADR-0018**（本文 §3-B 的叠字，RESOLVED @ `bd38147`）· **ADR-0019**（窗口 chrome，PROPOSED：三候选表 + 开工前置条件，编号原属它、因 §3-B 先落地而后移）
- 代码：`lib/ui/app_frame.dart` · `lib/ui/layout/columns.dart` · `lib/ui/sidebar/sidebar.dart` · `lib/ui/conversation/{composer,assistant_markdown,chat_view}.dart` · `lib/theme/dsw_*` · `lib/genkit/agent_runtime.dart:1382-1390`
