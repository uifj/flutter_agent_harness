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
| 1 | 标题栏：系统按钮与标题间距过近 | **本仓库没有自绘标题栏**：`macos/` 全仓 `grep titleBarStyle\|titleVisibility\|styleMask` = 0 命中，`MainFlutterWindow.swift:4` 只用默认 `NSWindow`。截图里那行"Agent Harness"是** macOS 原生标题栏**，间距由系统决定 | **不成立（作为我们的 bug）** | 这不是"加 padding"能修的。要呼吸感只有两条路：① `titleBarStyle = .hiddenInset` + 自绘一行应用内 chrome（能放面包屑/窗口标题，代价是要自己处理拖动区与全屏行为）；② 保持原生、把标题留空（`windowManager.setTitle('')`），让那行只剩系统按钮。**决策进 ADR-0018**，不偷偷选 ① |
| 2a | 会话列表文字截断 | `sidebar.dart:738-742` 是 `maxLines: 1 + TextOverflow.ellipsis`——**截断策略本身是对的**。真正的问题在标题内容：`agent_runtime.dart:1382-1390` 的 `_titleOf()` 取"第一条 user 消息的文本"，而 ADR-0009 的指令注入（`instructions.dart`）正是把 `<project-instructions>` 块作为**同一条消息的前置 TextPart** 发出去的（`agent_runtime.dart:961-972`）。于是每条会话标题都以 `<project-instructions> …` 开头，80 字预算被注入块吃光 | **部分成立（症状真、归因错）** | **这是 ADR-0009 引入的回归**，且是 DEF 级：用户看到的会话名是模型读的散文，不是自己说的话。修法：`_titleOf` 跳过指令块（按块的起始标记识别），或标题改由控制器在**用户原文**上生成并持久化。**这条优先于所有美化项** |
| 2b | 无活跃状态指示 | **有**，但和 hover 是同一个颜色：`sidebar.dart:729-732` `color: selected ? color.interactiveBgHover : null`，而 hover 态用的也是 `interactiveBgHover`（`:560`、`:603`、`:731`） | **部分成立** | 选中与悬停共用一个 token ⇒ 鼠标划过谁，谁就像"当前会话"。缺的不是指示器，是**第二个状态语义**。目标：选中用独立 token + 左侧 2px 强调条（ZCode 的 nested-radius/强调条律见 §4），hover 只改亮度不改身份 |
| 2c | Logo 与按钮留白不足；底部设置按钮孤立 | 品牌行 `sidebar.dart:374-377`：`EdgeInsets.only(left: 4, top: 8, bottom: 8)`——4px 左、8px 上下，确实紧。且 `:397` 把文案**硬编码成 `'DSH'`**（截图里侧栏是 DSH，窗口标题是 Agent Harness） | **成立，且比报告说的严重** | ① 留白按 §4 的间距标度重定；② `'DSH'` 是**第三方产品名残留在我们的 UI 上**，商用不可接受，必须换成产品名并进 i18n（`locales.dart` 双键）；③ 底部三件套（头像/齿轮/侧栏开关）要成为一个视觉组，而不是三个散落图标 |
| 3 | 对话区代码块与路径堆成文字墙，缺层级；段落间距模糊 | `assistant_markdown.dart` 已有 h1–h6 与 code block 的完整样式映射（`:80-86`、`:103-124`），圆角 6/12 混用（`:106`、`:115`），`fontSizeFactor: 0.875` | **部分成立** | 排版**令牌存在**，缺的是**层级差**：正文与 inline code 的视觉权重几乎相同（截图里满屏反引号包裹的 `run-raw-sql`、`create-bucket`），列表项无呼吸。目标：inline code 降饱和 + 底色、段落/列表间距走统一标度、圆角收敛到 §4 的嵌套律。**必须用截图这一屏做前后对照验收**，不许只改常量 |
| 4 | 输入框控件拥挤、对齐不精准、缺容器质感 | `composer.dart:7` 自述"控制行是 dsh 的 toolbar"，attach/mode/model/send 一行排开；`_deliverChips`（`:881-903`）在忙时**再往同一行塞两枚**（排队/转向），间距 6/8 硬编码 | **成立** | 拥挤是**忙时**才出现的：两枚投递 chip 与三枚既有控件抢同一基线。目标：控制行统一高度与基线、chip 间距走标度、忙时溢出策略见 §2 条 6。**注意**：`composer_test.dart` 已有"blocked composer offers the two deliveries"用例，改布局不许把它改松 |

### 二、响应式

| # | 报告的说法 | 代码实况 | 判定 | 真因与目标 |
| --- | --- | --- | --- | --- |
| 5 | 缺少收起/展开的汉堡菜单及主区域返回导航 | 响应式**求解层已经存在且被测过**：`columns.dart:64-125` 有 `centerMin 640`/`sidebarMin 264`/`sidebarCollapsed 56`（rail）/`sidebarAutoCollapse 1024`/`mobileMergeViewport 768`，五步让步链（details 先缩→先关→workbench 再缩→再关），`effectiveSidebarPreference`（`:216-225`）在 <1024 自动收成 rail，`test/columns_test.dart` 守着 | **不成立（作为缺失）** | 真正缺的是**可达性与可发现性**三件事：① 收成 56px rail 后，展开入口是否还在（窄屏下没有侧栏顶部按钮可点时，用户就被关在门外）；② 没有键盘等价物（`hotkey_service.dart` 只有 3 个热键，无"展开/收起侧栏"）；③ 窄屏下主区域没有"返回会话列表"的导航。**验收必须是真把窗口拖到 900/700/520px 三档并截图**，不是加断言 |
| 6 | 窄屏下下拉菜单压缩输入空间 | 控制行是定宽 chip 的 `Row`（`composer.dart:883`、`:930`），未见 `Flexible`/`Wrap` 用于该行的模式与模型选择器（chip 内部有 `Flexible`，`:821-823`，但那是附件 chip） | **成立（需实测确认溢出）** | 目标：窄阈值下模式/模型选择器**降级为图标 + tooltip**，或整行移到第二行（ZCode 的做法见 §4）。**RenderFlex 溢出是可测的**：给 widget 测试加一个 420px 宽 composer 的用例，断言不溢出 |
| 7 | 长路径与代码块在极窄屏破坏排版 | 代码块有 `borderRadius`/字号（`:103-124`）；**未见** `SingleChildScrollView` 横向滚动或 `TextScaler` 处理；`TextOverflow.ellipsis` 用在侧栏而非正文路径 | **成立** | 目标：代码块横向可滚（不折行时不撑破列）、长路径中段省略（`…tap_test/foo.dart` 式）、极窄下正文字号不塌。这条与 ADR-0005 欠的**文本缩放**（登记表已列 P2，ZCode 用单一 `--ui-font-size` 标度解决）是同一族问题，合并进 ADR-0017 |

## 3. 报告没提、但同样阻断"商用"的四条

| # | 发现 | 证据 | 级别 |
| --- | --- | --- | --- |
| A | **产品名在 UI 里自相矛盾**：侧栏写 `DSH`，窗口标题写 `Agent Harness`，bundle id 是 `com.stow.agentHarness` | `sidebar.dart:397`；`macos/Runner/Configs/AppInfo.xcconfig` | DEF·商用阻断 |
| B | **正文出现文字重叠**：截图里"和 4 次"压在 `SDK returns {ok, error}` 之上（两个 widget 画在同一区域）。候选因：turn 统计行 / 滚动到底按钮所在的 `Stack` 覆盖层没有底色遮挡（scrim），末条消息滚到底时会与它叠画 | 用户截图 1176×812，滚动到底按钮附近 | DEF·**待复现**（先定位是哪个覆盖层，再谈修） |
| C | **中列正文看起来未居中**：截图里正文贴右、左侧留出一条空白。**但居中逻辑是存在的**：`chat_view.dart:176-178` 取 `available = maxWidth - 2*side` 与 `contentWidth` 的较小者，`:210` 用 `Center` 包；对照同一张截图，composer（320–1100）确实居中，正文块（520–1050）中心偏右约 66px | 截图 + `chat_view.dart:176-178,210` | DEF·**待复现**，两个候选因：① `side` 只在一侧生效；② 消息块自带左缩进而 `Center` 按外层算。**不要在复现前写成结论** |

> B 与 C 都来自同一张截图，都能用"固定窗口宽度 + 打印 constraints/offset + 截图"复现。**它们比美化项更该先修**——一条重叠的正文不是"高级感"问题，是坏掉的渲染。
>
> 本报告初稿曾列第三条"会话列表在真机上为空"，**已自查删除**：第一张截图是全新启动（`暂无会话` 是正确状态，那时还没有任何会话），不是缺陷。留此记录是为了说明本文的判定口径：截图里看不出来的一律不算。

## 4. ZCode 参照（数值待回填）

ZCode 侧的实测数值（标题栏预留、侧栏宽度与折叠控件、composer 窄屏降级策略、断点常量、`DESIGN.md` 的间距/圆角/字号标律）由并行调研产出，回填本节后进入 ADR-0017/0018。**在拿到数值前不写"照 ZCode 的 X px"这类句子**——那是会腐烂的假事实。

已确认可搬的两条律（来自本仓库既有的 `docs/zcode-vs-agent-harness-2026-09.md` §3 设计系统行）：
- **radius = 嵌套深度递减**（外层大、内层小）。我们现在 6/8/12 混用且无律（`assistant_markdown.dart:106,115`、`sidebar.dart:727,732`）。
- **单一 base 字号标度派生全量**（ZCode 的 `--ui-font-size`，默认 14px）。Flutter 侧等价物 = 一个 base scalar → `TextTheme`，顺带补上 ADR-0005 欠的文本缩放。

## 5. 实施批次（每批都要过门禁 + 给截图证据）

| 批 | 内容 | 归属 | 验收 |
| --- | --- | --- | --- |
| **P0 先修坏掉的东西** | §3-B 文字重叠、§3-C 中列疑似未居中（先复现）、2a 会话标题被指令块污染、§3-A 产品名统一 | DEF（各立 ADR 或并入登记表） | 复现→最小化→修→截图前后对照 |
| **P1 令牌与身份** | ADR-0017（radius 律 + base 字号标度 + 选中/hover 分离）、3A 产品名统一并进 i18n | ARC/UI | `theme_token_test.dart` 新守卫 + `l10n_parity_test.dart` + `contrast_check` |
| **P2 chrome** | ADR-0018（标题栏决策）、侧栏品牌行留白与底部簇成组、2b 选中态 | ARC/UI | `app_frame_test.dart`、`sidebar_state_test.dart` + 真机截图 |
| **P3 会话区层级** | 条 3（inline code/列表/段落节奏） | UI | `markdown_rendering_test.dart` 扩展 + 截图对照 |
| **P4 响应式可达性** | 条 5/6/7：rail 展开可达、键盘等价、composer 窄屏降级、代码块横滚 | UI | 900/700/520px 三档截图 + 420px composer 不溢出的 widget 测试 |

**批次纪律**：每批结束跑 `dart format --set-exit-if-changed lib test tool spike` → `dart analyze --fatal-infos lib test tool spike` → `dart tool/check_architecture.dart` → `flutter test`（基线 `+814 -2`，只许那两条失败），并按 `git-commit` skill 分逻辑提交。UI 改动**没有截图就不算验收**——本会话里终端无 Screen Recording 权限，需要用户在系统设置里放行，或由用户本人走查。

## 6. 明确不做

- **不搬 ZCode 的二分树 pane layout**（评估文档 §3 已判"当前两栏够用"）。
- **不引入新依赖**做滚动/虚拟列表/字体缩放——`flutter test` 与 `pubspec` 现状能覆盖的就用现状。
- **不做 Web/移动断点体系**：三桌面目标（ADR-0003），响应式的边界是"窗口能拖到多窄还不坏"，不是手机适配。
- **不为"高级感"动 ADR-0004 的对比度豁免面之外的正文配色**——那要另立 ADR 并跑 `contrast_check`。
- **不复制 ZCode 的代码**（Apache-2.0 允许借鉴设计，但本仓库规则是不 fork 其代码）；搬的是数值与律。

## 7. 关联

- 既有评估：`docs/zcode-vs-agent-harness-2026-09.md` §3（UI 逐区对比）、§7 A5（文本缩放）、§7 A7
- ADR：ADR-0004（对比度豁免）· ADR-0005（设置页/偏好，欠文本缩放）· ADR-0007（双模式外壳）· ADR-0009（指令注入，**本文 2a 的回归来源**）· ADR-0011/0015（架构门禁）· 待立 **ADR-0017**（设计令牌契约）、**ADR-0018**（窗口 chrome）
- 代码：`lib/ui/app_frame.dart` · `lib/ui/layout/columns.dart` · `lib/ui/sidebar/sidebar.dart` · `lib/ui/conversation/{composer,assistant_markdown,chat_view}.dart` · `lib/theme/dsw_*` · `lib/genkit/agent_runtime.dart:1382-1390`
