# ADR-0054: 点开一条对话，就得走进它的那个文件夹

- **状态**: ACCEPTED
- **分类**: DEF（功能缺陷）
- **优先级**: P1
- **影响维度**: 生产功能 / 认知障碍
- **日期**: 2026-10-03
- **来源**: 用户真机截图——侧栏点 `eplan-web` 分组下的会话，顶部条与输入卡下方仍写着 `flutter_tiptap_test`（批注「没有切换」）
- **修复 commit**: cefd772

## 背景（Context）

`AppScope.openSession`（修复前 `lib/state/app_scope.dart:497-504`）做了四件事：
`_conversationToken = id`、`_checkpoints.conversation = id`、`_conversation.openSession(id)`、
`_sessions.setActive(id)` + `_workbench.bindSession(id)`。**没有一件是换工作区。**

于是：转录是 `eplan-web` 里那条对话的，而 `_runtime.workspaceRoot`、`_approvals`、`_checkpoints`、
`_workbench.workspaceRoot` 全还在上一条对话的文件夹里。后果不止是"顶部条说错了"：

- `read`/`grep`/`glob`/`bash` 四个工具都过 `Workspace` 那道门（`lib/model/workspace.dart`），
  门认的是**当前**工作区——模型按屏幕上的对话说话，工具却去另一个项目里找文件；
- 审批规则按工作区分键（ADR-0012），于是"这条对话里我批过的"在点开之后不作数，
  而另一个文件夹里批过的反倒对它生效；
- 回退镜像按工作区隔离（ADR-0014），`_checkpoints.conversation = id` 却留在上一份工作区里，
  等于把一条对话的写入历史挂到了另一个项目下面。

归属信息**本来就存着**：ADR-0039 D1 把"这次跑在哪个文件夹"放进 `<support>/sessions/sessions.json`
（`SessionMeta.workspaceRoot`，`lib/model/session_meta.dart:24-33`），理由写得很清楚——genkit 拥有
session 文档，应用侧加不进字段。缺的只是**开对话时没人去读它**（`SessionRegistry.metaOf` 只有
`titleOf`/`pinnedAt`/`isDeleted` 三个读者）。

而 ADR-0053 刚把"当前是哪个文件夹"画到屏幕上，这个一直存在的分叉第一次变得可见——**先看见的是新表面，
坏的是老路径**。

## 决策（Decision）

`openSession` 在装载转录**之前**读侧车那行，并走 `adoptRecent(root)` 换文件夹：

```dart
final root = _sessionRegistry.metaOf(id).workspaceRoot;
if (root != null) await adoptRecent(root);
```

`adoptRecent` → `save(withWorkspace(path))` 是本应用**唯一**换文件夹的路（ADR-0039 已经立过这条），
所以一次调用同时带走：`_approvals.useWorkspace`、`_checkpoints.useWorkspace`、
`_workbench.workspaceRoot`，以及运行时那一侧的 live setter（工作区单独变化不重建 runtime，
`app_scope_test` 第一条守卫钉的就是它）。

两条边界写在代码里而不是留给下一个人猜：

1. **没有归属行的对话不声明任何文件夹**。ADR-0039 之前写的历史没有 sidecar 行，
   `metaOf(id).workspaceRoot == null` 就什么都不做。按猜测换目录是"走错地方"的第二种方式。
2. **先换目录、后装转录**。`save` 是唯一可能丢弃当前对话的分支（要重启 runtime 时），
   装载放在它之后不会把刚打开的对话弄丢；代价是"快照加载失败时目录已经切了"——接受，
   因为列表里的一行必然有快照，而反过来（先装载）会让这道守卫在离线测试里根本没有可跑的面。

**不做**的相邻改动：`openSession` 里给 `_conversation.openSession` 包一层 try——
genkit 的 `Snapshot session … not found` 现在会抛到点击处，那是一个独立的缺陷面（要不要在 UI 上
兜住、怎么说），按 §7 另立 ADR，不在修归属时顺手改变错误路径的形状。

## 后果（Consequences）

- **正面**: 点一行会话 = 走进它的项目：屏幕说的、工具查的、审批认的、能回退到的，四件事第一次同源；
  顶部条（ADR-0053）与输入卡下方那行不再是两个互相矛盾的标签。
- **负面/风险**: 换工作区是**有副作用的**动作（审批簿与回退历史跟着走），所以"点一行"比从前更重——
  若将来要做"只读别人的对话"，需要的是一条不切目录的查看路径，而不是把这里改回不切；
  另一条：`adoptRecent` 比的是**原始字符串**，同一目录的不同拼法（`/var` 与 `/private/var`）会被当成
  一次真实切换——这正是既有基线失败 `app_scope_test` 那一对，要收敛得先立 ADR 统一拼法。
- **中性**: 归属的读取点从 3 个变成 4 个（`titleOf`/`pinnedAt`/`isDeleted` + `workspaceRoot`），
  都在 `AppScope` 一侧，界面没有新增第二真值。

## 验证（Verification）

- `test/app_scope_test.dart` 的 `opening a conversation adopts the folder it was started in`：
  自带宿主（`sessions/sessions.json` 必须在 `AppScope` 打开注册表**之前**落盘），
  用**真实**临时目录（runtime 走 `Workspace.of` → `resolveSymbolicLinksSync`，编出来的路径开不了）；
  断言文档、live runtime（解析后的那个值）、workbench 三处同时到位，并断"没有归属行的 id 什么都不动"。
  **反向验过**：把 `_sessionRegistry.metaOf(...)` 那两行短路，当场红在
  `Expected: '/…app_scope_elsewhere…' / Actual: <null>`。
- 门禁：`dart format`（0 changed）、`dart analyze --fatal-infos lib test tool spike`（No issues found）、
  `flutter test`（**+1332 −2**，两个失败仍是既有基线）、`dart tool/check_architecture.dart`（7 recorded, 0 new）。
- 待 macOS 真机：① 在两个文件夹各有一条对话时来回点，看顶部条、输入卡下方那行、右侧文件树是否同时换；
  ② 换过去之后，上一夹批过的"总是允许"不该在这条对话里生效（ADR-0012 的按工作区分键）；
  ③ 回退 pill 只出现在本夹的写入卡片上（ADR-0014）。

## 关联（Links）

- ADR-0039（归属四件事住进 sidecar；换工作区只有 `AppScope` 一条路）、ADR-0053（让分叉可见的那块表面）、
  ADR-0012（审批规则按工作区分键）、ADR-0014（回退镜像按工作区隔离）、ADR-0002 Stage 4
  （`save` 的重建/重指向规则，`app_scope_test` 钉的就是它）
- 用户截图：`a2c03a25-…png`（批注「没有切换」）
