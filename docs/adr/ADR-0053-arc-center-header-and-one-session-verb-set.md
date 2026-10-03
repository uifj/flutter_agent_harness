# ADR-0053: 顶部条说出在哪个工作区，对话的动词只答一次

- **状态**: ACCEPTED
- **分类**: ARC（架构决策）
- **优先级**: P2
- **影响维度**: 认知障碍 / 生产功能
- **日期**: 2026-10-03
- **来源**: 用户真机截图批注「出现选中的"工作区"」+ ZCode 对话列头部那张菜单截图（14 项）
- **修复 commit**: 45fca1d

## 背景（Context）

1. **屏内没有任何地方说"现在在哪个工作区"**。中列顶上的那条 chrome 是 ADR-0048 立的
   `_CenterToggleStrip`（`lib/ui/app_frame.dart`），它的身体是
   `Align(alignment: Alignment.centerRight, child: _ToggleCluster(...))`——**左半边永远是空的**，
   只放两枚面板开关。窗口标题确实写了「会话 — 工作区」（ADR-0019 ③，`model/window_title.dart`），
   但那是系统画的那一行，最大化之后没人再看它。用户的截图正是指这一格。
2. **参考那一行还带一枚菜单**。ZCode 的对话头部是 `📁 + 会话标题 + ⋯`，菜单 14 项：
   置顶任务 / 重命名任务 / 归档任务 / 标记为未读 / 在 Finder 中打开 / 复制路径 / 复制任务路径 /
   复制日志路径 / 复制会话 ID / 前往配置 / 查看调用轨迹 / 反馈问题。
   按 ADR-0041 的判据（**搬一格之前先给它找调用点**）逐条对：本仓库**只有六项有真后端**——
   置顶（`SessionIndex.setPinned`）、重命名（`rename`）、在文件管理器中显示（`host/reveal.dart`
   经 `ui/primitives/reveal.dart`）、复制工作区路径、复制会话 ID（`SessionSummary.id`）、打开设置。
   其余四项**这里没有机制**：归档区与未读/live 计数是 ADR-0039 的「明确不做」清单里点名的；
   应用没有自有的日志文件可复制；没有调用轨迹的存储与表面。给它们做入口就是 ADR-0022
   那枚"只有写入点的开关"换了个地方长。
3. **这些动词已经答过一次了**，长在侧栏里：`sidebar.dart` 的 `_sessionMenu`（五行）、
   `_rename` + `_promptForText`（命名对话框）、`_delete`（确认框 + 墓碑）、`_warnIfNotSaved`
   （侧车写失败当场说）。顶部条要再写一遍，就是同一批动作两份实现——本仓库为这件事立过律
   （ADR-0035"被读的地方一份答案"、ADR-0041"两扇门各自腐烂"）。

## 决策（Decision）

- **先抽一处答案，再装第二扇门**。新增 `lib/ui/session_actions.dart`：`sessionMenuEntries(...)`
  给出那几行，`renameSession` / `deleteSession` / `warnIfHistoryNotSaved` 给出三个副作用与
  命名对话框。`withDelete` 与 `onOpenSettings` 是两个表面**各自多出来的那一格**：
  删除留在侧栏（从头顶的菜单里毁掉正在读的转录是一把自伤），设置只属于头部。
  侧栏的 `_sessionMenu` 改为调用它，行为与顺序一字未动。
- **顶部条的左半边**：`📁 文件夹名`（可点，交出的还是 `scope.pickFromHero` 那枚 picker）
  + 会话标题（`Flexible` + ellipsis）+ `⋯`。文件夹名用 `p.basename` 而不是
  `root.split(Platform.pathSeparator)`——`lib/ui` 直接 `dart:io` 是 `check_architecture`
  第 5 条的 baseline 项，新加一处就是新增违规。
- **头部跟的是索引，不是 provider 重建**。`SessionIndex` 是 `ChangeNotifier`，
  `setActive` / 改名 / 置顶都在上面通知；`_CenterToggleStrip` 用 `ListenableBuilder` 直接听它
  （`sessions == null` 时不装这层）。为此给 `SessionIndex` 加了一枚 `active` getter——
  "当前是哪条会话"这个问题在侧栏、标题服务和头部三处都要问，不该各自 `firstWhere`。
- **没有会话就没有菜单**。`session == null || sessions == null` 时 `⋯` 不画：
  未保存的新会话没有 id 可置顶、可复制、可删除，一枚点开是空的菜单就是 ADR-0022 的假门。

## 后果（Consequences）

- **正面**: 屏内第一次说出"在哪个工作区、在读哪条对话"，且这行 chrome 在面板开合的每个状态下都在
  （ADR-0048 的那条"一个家"）；对话的六个动词现在只有一份实现，侧栏与头部按同一批行、走同一个
  侧车写入与失败提示。
- **负面/风险**: `AppFrame` 多了五枚可选参数——它们的存在理由是"宿主可能真的没有这些"（全新安装没有
  文件夹，未保存会话没有 id），不是给测试兜底的默认值；`_CenterToggleStrip` 从"只放开关"长成"一行
  头部"，再往里塞东西要先问它属于谁。头部与侧栏**同时**能置顶/改名，这是刻意的两扇门（同一份实现，
  不会各自腐烂），但两处入口意味着两处都要有守卫。
- **中性**: 侧栏删掉了 `_promptForText`/`_rename`/`_delete`/`_warnIfNotSaved` 四个私有成员与三枚
  因此空掉的 import；`app_frame_test` 的宿主现在跑在真侧车上（`SessionRegistry.open(temp)`），
  因为"按了置顶但没落盘"这种谎只有在真写入面前才测得出来。

## 验证（Verification）

- `test/app_frame_test.dart` 的 `the header names the workspace and the conversation`：
  断言条上出现 `alpha` 与会话标题（**限定在 `ValueKey('center-strip')` 之下**——侧栏的工作区分组
  头显示同一个文件夹名、也带同一枚 `⋯`，不限定就等于什么都没断）；点开菜单断言六行齐全且
  **没有** `Delete`；**按下去**验证两扇真门：`Pin to top` 之后 `index.sessions.single.pinnedAt`
  非空（走真侧车），`Settings` 之后宿主计数器为 1；最后一段证明"没有会话就没有 `⋯`"。
- 反向验过三处：头部整体不画 → 红在 `Found 0 widgets with text "alpha" descending from ...`；
  置顶那行短路成空动作 → 红在 `Expected: not null / Actual: <null>`；
  而**守卫第一次跑红在 `Found 0 widgets with text "Settings"`，抓到的是实现漏传
  `onOpenSettings`**——先红后绿，红在真缺陷上。
- 门禁：`dart format`（0 changed）、`dart analyze --fatal-infos lib test tool spike`（No issues found）、
  `flutter test`（见登记表回填的数）、`dart tool/check_architecture.dart`（7 recorded, 0 new——
  `p.basename` 换掉 `dart:io` 正是为了让这条不变量不新增）。
- 待 macOS 真机：① 长文件夹名 + 长会话标题在 1400/1100/700 三档下各自省略号；② 2.2x 字号下这行
  是否仍然一行装得下（守卫量过，观感未看）；③ 中文档下六行菜单的措辞。

## 关联（Links）

- ADR-0039（分组的历史：三个动作都在 `SessionIndex`，删除是墓碑）、ADR-0041（先找调用点再搬；
  两扇门各自腐烂）、ADR-0022（没有读者的开关）、ADR-0048（这条顶部条的来历与"一个家"）、
  ADR-0019 ③（窗口标题是同一份真值的另一个读者）、ADR-0035（被读的地方一份答案）
- 参考证据：`_archive_project/ZCode-main` 的对话头部行与任务菜单（截图），
  `useTaskListItemContextActions.ts:168-175`（reveal 也挂在任务行上）
