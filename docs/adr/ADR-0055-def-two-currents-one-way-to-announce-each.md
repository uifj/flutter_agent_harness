# ADR-0055: 两个"当前"各自要有一种宣布方式

- **状态**: ACCEPTED
- **分类**: DEF（功能缺陷）
- **优先级**: P1
- **影响维度**: 生产功能 / 幻觉源 / 认知障碍
- **日期**: 2026-10-03
- **来源**: 用户两张截图（顶部条停在上一条对话；「复制工作区路径」粘出上一个项目的路径）+ 全仓走查 `docs/state-consistency-on-switch-2026-10-03.md`
- **修复 commit**: e679c4c

## 背景（Context）

应用只有两个"当前"：**当前文件夹**（`AppSettings.workspaceRoot`，由 `SettingsStore` 这个
`ChangeNotifier` 持有，经 `settingsDocument` provider 用 `invalidateSelf` 重发）与
**当前对话**（`SessionIndex.activeId`/`active`，`SessionIndex` 自己是 `ChangeNotifier`，
而 `sessionsProvider` 是函数式 provider，**永远给回同一个实例**，所以它不会因为值变了而重发）。

上一批给顶部条加头部时，`main.dart` 把 `ref.watch(sessionsProvider).active` 当**值**递进了
`AppFrame`。上游不重发 ⇒ 那个值再也不更新：

- 侧栏点 `eplan-web / 1`，顶部条仍写 `123`（`flutter_tiptap_test` 那条）；
- 更糟的是那枚 `⋯` 的**动作作用在错误的对话上**——`session_actions.dart` 的
  「复制工作区路径」读的是 `session.workspaceRoot`，于是粘出
  `/Users/…/pinplan/flutter_tiptap_test`（用户截图①红框）。

同一次走查（逐表面问"你读哪个当前、怎么知道它变了"）另找到三处，证据与判词全在
`docs/state-consistency-on-switch-2026-10-03.md`：

- `AppScope.save` 的工作区分支只重挂了审批簿（`_approvals.useWorkspace`）与回退镜像
  （`_checkpoints.useWorkspace`），**没动当前对话**——ADR-0054 的反方向没人管：转录留在
  旧项目里，而 `read`/`grep`/`bash` 的 `Workspace` 门已经指向新目录。
- 同一段的重启分支自己写了 `_sessions.setActive(null)` + `bindSession(null)`，
  **没重铸未保存令牌**（对比 `newSession` 的 `_conversationToken = 'unsaved-N'`），
  于是下一次持久化 `adoptConversation(旧, 新)` 会把上一条对话的镜像认领过来——
  回退卡片提议撤销别人家的写入（ADR-0014 的归属被破）。
- `composer.dart` 的 `@` 索引只在打字时取（`_onDraftChanged:380`），而那张卡跨文件夹活着：
  换目录后菜单继续排上一个项目的文件（注释还声称"菜单关掉就清"——代码里没有那一行）。

## 决策（Decision）

**律：从 ChangeNotifier 里读出来的"值"是快照；只有那个 notifier 本身是活的。**
需要跟随切换的表面，要么听 notifier（`ListenableBuilder`/`addListener`），要么每棵 build 现读。
把值当参数往下递，只有在上游会重发时才成立——`SettingsStore` 会，`SessionIndex` 的 provider 不会。

四处据此修：

1. **删掉 `AppFrame.session` 参数**，`_header` 每棵 build 现读 `sessions?.active`；
   外层 `ListenableBuilder(listenable: sessions)` 负责"变了就重建"。第二真值不是被同步，是被删除。
2. **换文件夹即结束对话**：`save()` 的工作区分支调用 `newSession()`。旧对话不丢——
   它仍在盘上、仍在侧栏自己那一组里，一点就回来。这也让"上一项目的编辑器/文件树 tab"
   自然回到正确的会话（布局按会话绑定，`bindSession` 整棵换）。
3. **重启分支改走同一个 `newSession()`**：一条"结束当前对话"的写法，两处用，
   顺带补上它漏掉的重铸令牌。
4. **`@` 索引认目录**：换 root 时清 `_fileIndex`、`_indexLoading = false`、`_indexGeneration++`
   （挡住已在飞的旧响应），菜单开着就当场重取；注释与代码重新对齐。

**附带一处判据升级**（因为它从无害变成伤人）：`adoptRecent` 与 `save` 过去比原始字符串，
macOS 上 `/var/…` 与 `/private/var/…` 会被当成两个目录——以前只是多存一次，现在会**误结束对话**。
改用 `model/session_groups.dart` 已有的 `workspaceKey`（侧栏分组用的同一个答案）。

**明确不做**（逐条有证据，见走查页 §3）：活 shell 的 cwd 不改（`terminal_manager.dart:219-220`
重挂时本就忽略 `workingDirectory`，任何终端都改不了活进程的目录）；把盘上 root 统一成解析后的拼法
（要动 settings 写侧与既有文档，另立 ADR）；用量数字的启动快照、子代理 dock 的选中丢失、
外部 `git checkout` 后分支不刷新（三条与"切换"不是同一触发条件，各记各的案）。

## 后果（Consequences）

- **正面**: 顶部条、菜单动作、工具的门、审批簿、回退归属、`@` 索引，六个表面第一次同时跟着
  两个"当前"走；ADR-0054 与它是同一条规则的两侧——**对话与文件夹互为归属**，任一方向的切换
  都带走另一个。
- **负面/风险**: 换目录现在是**有后果的动作**（会结束当前对话）。从设置页改文件夹的人会发现
  转录清空——这是刻意的，且旧对话一键可回；若将来要做"只读别的文件夹的对话而不切目录"，
  需要一条新的查看路径，而不是把这里改回去。
- **中性**: `AppFrame` 少一个参数；`save()` 少一份内联的"结束对话"写法；
  `workspaceKey` 从"只影响分组"变成"也决定会不会误结束对话"——它的正确性从此更要紧。

## 验证（Verification）

- `test/app_frame_test.dart` 的 `the header names the workspace and the conversation`：
  `index.setActive('s2')` 后**不重建宿主**，断顶部条出现 `Ship the drawer`、旧标题消失；
  点开菜单**按下**「复制工作区路径」，用 `ClipboardProbe` 断粘的是 `/work/beta`；
  另断文件夹 chip 与 Settings 两扇门按得动（`picked == 1` / `settings == 1`），
  以及 `setActive(null)` 时 `⋯` 不画。**反向验过**：读数换成 `sessions.firstOrNull`
  即红在 `Found 0 widgets with text "Ship the drawer"`。
- `test/app_scope_test.dart` 两棵新守卫：`choosing a folder ends the conversation about the old one`
  （先 `setActive` + `bindSession`，换目录后断 `activeId` 与 `workbench.sessionId` 都归零，
  runtime 仍是重指向而非重建）；`one folder spelled two ways is still one folder`
  （同一目录换拼法保存，`activeId` 必须还在）。
- `test/composer_test.dart` 的 `a folder change drops the index the old folder built`：
  两次 `pump` 换 root，断 lookup 被调第二次且菜单出现新目录的文件；
  **反向验过**：去掉清缓存即红在 `Expected: <2> Actual: <1>`。
- 门禁：`dart format`（0 changed）、`dart analyze --fatal-infos lib test tool spike`（No issues found）、
  `flutter test`（**+1335 −2**，两个失败仍是既有基线）、`dart tool/check_architecture.dart`（7 recorded, 0 new）。
- 待 macOS 真机：① 两夹各若干对话来回点，看顶部条、转录、右侧文件树、`@` 菜单四者同时换；
  ② 从设置页改文件夹后转录清空是否符合预期；③ 换目录后旧 shell 仍在原地（预期行为）不让人困惑。

## 关联（Links）

- 走查页（逐表面证据）：`docs/state-consistency-on-switch-2026-10-03.md`
- ADR-0054（点开对话 → 走进它的文件夹）、ADR-0053（顶部条与那六项动作）、ADR-0039（`workspaceKey`
  与会话归属）、ADR-0014（回退归属与 `adoptConversation`）、ADR-0012（审批按工作区分键）、
  ADR-0002 的 riverpod 读缝笔记（函数式 provider 不重发值）
