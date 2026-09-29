# ADR-0019: 标题栏要不要从系统原生改成应用内自绘（hiddenInset）

- **状态**: ACCEPTED（选 ③）／实施 IN-PROGRESS —— 代码已落 `657fe22`，**真机签收未做**，故不得进 RESOLVED（本 ADR 自己的验证条就是这个门槛）
- **决策修正**: 前置条件 1 在写这份 ADR 时已经满足，只是不在它以为的地方（见下）
- **分类**: ARC
- **优先级**: P2
- **影响维度**: 生产功能（商用观感）/ 跨平台一致性
- **日期**: 2026-09-29
- **来源**: [UI 生产化审计 §2 条 1](../ui-production-audit-2026-09.md)（用户报告"系统按钮与标题间距过近"）
- **修复 commit**: —

## 背景（Context）

审计已判定：**这条报告不是我们的 bug**。macOS 侧证据：全仓
`grep titleBarStyle|titleVisibility|styleMask macos/` = 0 命中，
`macos/Runner/MainFlutterWindow.swift:4` 只用默认 `NSWindow`；截图里那行
"Agent Harness" 是**系统标题栏**，间距由系统决定，加 padding 修不了。

但报告背后的感受是真的，而且代码能给出真因的两条：

1. **产品名出现两次**：系统标题栏画 `Agent Harness`（来自
   `macos/Runner/Configs/AppInfo.xcconfig` 的 `PRODUCT_NAME`），侧栏品牌行
   自 `74ab800` 起也画 `context.tr('appName')` = 同一个词，两者相距约 40px。
   `lib/` 全仓 `grep setTitle` = 0 命中——我们**从没设置过窗口标题**，
   所以那行只能显示 bundle 名。
2. **窗口里已经有第二条 chrome**：工作台 tab 条本身就是顶部 chrome
   （见 workflow §3「双树工作台」，Layout audit `c53af9e`），系统标题栏在它上面，
   于是窗口顶部是两条横杠。

## 决策（Decision）

**三个候选，本 ADR 不选 ①，理由是可验证性而不是审美：**

| 方案 | 内容 | 代价 | 本会话能否验收 |
| --- | --- | --- | --- |
| ① | `titleBarStyle = .hiddenInset` + 应用内自绘一行 chrome（拖动区、全屏按钮要让位） | macOS 独有；Windows/Linux 上 GTK/Win32 不认这个样式，会出现"mac 一条杠、别的平台两条杠"的**平台分叉**（先例见 build.md §2B 的浏览器 tab 降级）；要自己处理 `DragToMoveArea` 与红绿灯的命中区 | **不能**——OS 层的东西 widget 测不到，而本机 `screencapture -x` 报 `could not create image from display`，看不见就不能签收 |
| ② | 保持原生，`windowManager.setTitle('')`，那行只剩系统按钮 | 丢掉窗口菜单/Mission Control 里的可辨识标题 | 部分能（能断言调用），但"是否更好看"仍要眼睛 |
| ③ | 保持原生，但让标题栏**说窗口的事而不是产品名**：`<会话标题> — <工作区目录>` | 会话标题目前只有运行时那一份推导（`agent_runtime.dart:1386` 的 `static String? sessionTitle(List<Message>)`，输入是 genkit 的 `Message`，且要靠 `_userWords()` 剔掉 ADR-0009 的注入块）。装配根要读它就得把"这条会话叫什么"提升成 `lib/model/` 里的真值，否则窗口标题和侧栏标签会各算一套 | 能（纯字符串函数可单测），但**前置工作是那条提升**，不是本 ADR 能顺手做的 |

**推荐 ③ 作为下一步，① 作为它之后的可选项**：③ 先把重复的产品名变成有用信息，
且不动 OS chrome；等它落地、并且能在真机上走查了，再评估 ① 值不值得吃平台分叉。

**置 PROPOSED 不动手的前置条件（缺一条都不开工）**：

1. ~~"这条会话叫什么"在 `lib/model/` 有单一真值~~ —— **这条在写 ADR 时就已成立，证据在现场**：
   `lib/model/conversation.dart:215` 的 `SessionSummary.title` 就是那份真值，
   运行时在持久化时用 `sessionTitle()` 填它（`agent_runtime.dart:1369`），
   侧栏那一行读的就是它（`ui/sidebar/sidebar.dart:822`）。
   实施因此**没有新造真值**，只是把已有的两份（会话标题、工作区目录）交给窗口；
2. 本机拿到 Screen Recording 权限，或由用户本人走查——否则 ①/②/③ 的观感改动
   全部无法签收，违反 build.md §0"没在当前平台真跑过的不声称成功"；
3. 若最终选 ①：Windows/Linux 的退化写法要同时定（是保留原生标题栏，
   还是三平台都自绘），并把结论写进 build.md §2B。

## 实施（③，`657fe22`）

- 纯函数 `lib/model/window_title.dart` 的 `composeWindowTitle`：
  `"<会话> — <目录 basename>"`，只有一半就显示那一半，**两者都没有则返回 null**
  （窗口是新开的，此时 bundle 名才是诚实的那行）。会话那半在 48 字内先让位——
  标题栏自己的 ellipsis 会把**目录**挤出去，而目录是用户猜不到的那半。
- 接线 `lib/state/window_title_service.dart`：听 `SessionIndex`（它同时知道
  哪条会话是活跃的与它的标题），工作区由 `main` 在 `settingsDocumentProvider`
  变化时推进来。放在首帧之后、与 tray/hotkeys 同一道缝，因为要等窗口句柄。
- 守卫 `test/window_title_test.dart` 五条：两半都有／只有目录／只有会话／
  两者皆无＝null／长句让位后目录仍在。`flutter test` = `+897 -2`（那两条既有失败未变），
  analyze `--fatal-infos` 无告警，`check_architecture` 新增两文件后仍 0 new（126 个 lib 文件）。
- **仍未闭环的一半**：`windowManager.setTitle` 是平台通道调用，widget 测不到；
  本机无 Screen Recording 权限截不到系统标题栏。所以 ③ 的**观感**要用户在 macOS 上
  看一眼（打开任意会话，标题栏应读作"那句话 — 目录名"），①/② 维持 DEFERRED
  的理由不变（平台分叉 + 同样看不见就不能签收）。

## 后果（Consequences）

- **正面**: 报告里"拥挤"的两条真因（重名、双 chrome）被记录成可决策的事实，
  而不是留给下一次"加个 padding 试试"。
- **负面/风险**: 条 1 在实施批次表里保持未闭环，P2 chrome 批次仍欠一次真机走查。
- **中性**: 一旦选 ①，`macos/Runner/MainFlutterWindow.swift` 与
  `window_manager` 的接线会进入"改它=改产品能力边界"那一类，需要真机回归。

## 验证（Verification）

怎样算闭环（尚未开始，故本 ADR 不动代码）：

- `grep -rn "setTitle" lib/` 有命中，且标题字符串由 `lib/model/` 的一个纯函数产出，
  有单测覆盖"无会话/无工作区/两者都有"三种形状；
- 或：存在 ACCEPTED 的 ADR 明确选择 ①，并附三平台各自的表现说明；
- 二者都要配一次真机走查记录（截图或用户签收），否则状态不得进 RESOLVED。

## 关联（Links）

- 代码: `macos/Runner/MainFlutterWindow.swift#L4` · `macos/Runner/Configs/AppInfo.xcconfig` ·
  `lib/ui/sidebar/sidebar.dart`（品牌行）· `lib/genkit/agent_runtime.dart`（`_userWords`/`sessionTitle`）
- 关联 ADR: ADR-0003（增删平台目标要立 ADR 的先例）· ADR-0009（会话标题的真值来源）·
  [审计 §2 条 1 / §5 P2 行](../ui-production-audit-2026-09.md)
