# ADR-0039: 代理模式的对话历史按工作区分组

- 分类: ARC
- 优先级: P1
- 状态: ACCEPTED（2026-10-02，用户拍板范围：截图可见 + 会话右键菜单；「代码」侧指代理模式的右侧工作台）

## 背景

两条事实决定了这不是"给侧栏加个标题行"那么小。

**本仓库现状**：会话没有任何工作区归属。

- `SessionSummary` 只有三个字段：`id` / `updatedAt` / `title`（`lib/model/conversation.dart:210-218`）。
- `AgentRuntime.listSessions()` 平铺扫一个目录：`<support>/sessions/global/.pointers/*.json`，逐个 `getSnapshot` 取 `updatedAt` 与派生标题（`lib/genkit/agent_runtime.dart:1350-1372`）。
- 侧栏一条 `SliverList.builder` 平铺渲染 `_SessionRow`，座位 `DswShape.rowSession * step`（`lib/ui/sidebar/sidebar.dart:669-693`、`:607`、`:919`）。
- `TurnSource` 接口**没有** deleteSession（`lib/model/turn_source.dart:15-61`）——删除没有现成的下游。
- 但两份地基已经在了：`AppSettings.recentWorkspaces`（`lib/model/app_settings.dart:113,167`）就是一份工作区注册表，`AppScope.setWorkspace(path)`（`lib/state/app_scope.dart:405`）已经能带着审批/回退点/工作台一起换工作区。

**ZCode 侧**（`_archive_project/ZCode-main`，逐行读过的证据）：

- 归属在 task meta 上：`workspacePath`（绝对路径）、`workspaceIdentity`、`workspacePurpose: "project" | "conversation"`、`createdAt/updatedAt`（`packages/shared/src/zcode-task-types-core.ts:266-291`）。身份 key 统一为 `workspaceIdentity?.trim() || workspacePath`（`packages/services/src/paths.ts:190-192`）。
- 盘上**一个工作区一个目录**：`~/.zcode/v2/sessions/{sha256(workspaceKey) 前 12 位}/{taskId}.json`，删除是兄弟文件 `{taskId}.deleted.json` 墓碑（`packages/services/src/paths.ts:203-224`）；另有一份 sqlite 查询索引，PK `(workspace_key, task_id)`（`packages/services/src/tasksDatabase/schema-v1.ts:4-32`）。
- 视图偏好独立一档：`organizeBy: "grouped" | "project" | "chronological"`（默认 `project`）、`sortBy`（默认 `updated`），落 localStorage（`packages/ui/src/lib/sidebarTaskPreferences.ts:4-17,55-73`）。
- 组内序 = `ORDER BY updated_at DESC, created_at DESC, task_id DESC`（`packages/services/src/.../taskIndexRepo.ts:922,1717`），组间序跟着打开的项目 tab 顺序且可拖拽（`packages/ui/src/WorkspaceSidebar.tsx:711,1502-1510`）。
- 相对时间四档：`<1m` 刚刚、`<60m` `{n}分`、`<24h` `{n}小时`、else `{n}天`（`packages/ui/src/lib/taskListItemPresentation.ts:33-53`，i18n `packages/ui/src/i18n/locales/zh-CN.ts:1771-1773`）——截图里的 `59分` 与 `23天` 就是这两档。
- 项目行的动作：折叠态未读点、live workflow 计数、只读告警（`packages/ui/src/WorkspaceSidebarItem.tsx:749-784`）、`⋮` 菜单含**移除工作区**（`:903-949`）、`ListTree` = 显示文件树（`:952-968`）、`MessageCirclePlus` = 在该项目新开会话（`:1090-1110`）。**没有**项目改名、删除该项目全部会话、项目级置顶/归档/导出。
- 会话行右键：置顶、重命名、归档、标记未读、分屏打开、在访达中显示、复制工作区路径 / 任务路径 / 日志路径 / 会话 id、查看 trajectory（`packages/ui/src/TaskListItemContextMenu.tsx:8-90` → `TaskActionMenuContent.tsx:91-205`）；真删除只在归档区（`WorkspaceArchivedTasksFlatSection.tsx:141`）。
- 两条**别抄**的：侧栏那把搜索是死键（`workspaceSidebar.searchTasks*` 三个 i18n 键无消费者，`zh-CN.ts:1519-1522`），真跨项目搜索在 command center（`packages/ui/src/command-center/CommandCenterDialog.tsx:471-519`）；ZCode **没有** chat/agent/code 三态，`ZCodeTaskMode` 是审批模式（`yolo|plan|edit|auto|autoEdit|build`，`zcode-task-types-core.ts:149`），"代码"面是右侧 side pane 的文件树/Git/终端/预览。

截图（用户 2026-10-01 附）与上面一致：亮色档一节「工作区」，下挂 `hunnu_app_osos` / `flutter_agent_harness` 等文件夹，会话标题缩进其下、长标题省略号、选中那行有底色；暗色档一节「项目 ▾」带 `⋮` 与 `+`，项目行尾有图标，会话行右侧是 `59分` / `23天`。

## 决策

1. **归属不进快照，进 sidecar。** 新增 `<support>/sessions/sessions.json`：`{ "<sessionId>": { workspaceRoot?, pinnedAt?, deletedAt?, title? } }`，由 `lib/state/session_registry.dart`（`ChangeNotifier`，tmp+rename 原子写，沿用 `settings_store`/`prefs_store` 的形状）唯一持有。
   理由：genkit 的 pointer/snapshot 形状不由我们决定（不变量 1），而标题的真值已经在快照里（`sessionTitle(messages)`）——sidecar 再存一份就是 ADR-0014 点名的"两个必须相等的字段"。所以 sidecar **只存快照装不下的四件事**；其中 `title` 是用户改名的 override，没有 override 时读派生值，优先级写在字段注释里。
2. **分组是纯函数。** `lib/model/session_groups.dart`：`groupSessions(summaries, registry, knownWorkspaces, currentWorkspace, prefs)` → `List<WorkspaceGroup>`。无 IO、无副作用、可单测。规则：组内 pinned 优先、其余 `updatedAt` 降序；组间当前工作区第一、其余按组内最新会话降序；`workspaceRoot == null` 的会话进**「未归属」组**（ZCode 没有这一档，我们有既成历史会话，硬套就是丢数据——这条差异写在这里，别在实现时"顺手对齐上游"）。
3. **视图偏好进 `WorkbenchPrefs`**：`historyOrganizeBy`（`project` | `flat`，默认 `project`）与 `collapsedWorkspaces`（一组路径）。**不进 `AppSettings`**——那条通道带 `requiresRuntimeRestart`，为一个折叠状态重启 agent 是 bug 不是功能（`workbench_prefs.dart` 头部已经把这条边界写明了）。
4. **删除 = 墓碑。** `deletedAt` 写进 sidecar，列表过滤掉，盘上快照与工作台布局**不删**。与 ZCode 的 `{taskId}.deleted.json` 同构；不可逆操作要一次显式确认，而我们现在没有归档区，真删就是唯一且无回路的动作。
5. **相对时间是纯 Dart + 双字典键。** `lib/model/relative_time.dart` 的 `formatRelativeTime(at, now, tr)`，阈值照上游四档。放 model 而不是 ui：它要能被单测，且 `lib/ui` 不许直接 `dart:io`/自己造时间格式。
6. **侧栏结构**（代理档；企划档不动，那里扩展区已经是企划库）：
   - 节头本身带一把 `⋮`：视图选择（按工作区分组 / 平铺）+ 全部展开 / 全部收起。上游把后两枚画成表头图标（`WorkspaceSidebar.tsx:1072-1095`），这里收进菜单，因为 280px 一列里先让位的从来是 chrome 的座位；「收起全部」一次写入整个折叠集合，不是一组一次通知。
   - 一节标题「工作区」，其下每组：**组头行** = 折叠 chevron + `Folder`/`FolderOpen` 图标 + 叶子名（`p.basename`）+ 行尾 `DswIconButton` 两枚：`+`（在该工作区新开会话）与 `⋮`（菜单：显示文件树 / 移除此工作区）；当前工作区那组默认展开并在名旁给一枚 `stateDot` 表示"就是这里"。
   - **会话行**沿用 `rowSession * step` 座位，标题 `Expanded` + ellipsis（行里自由文本必须有 flex 上界），右侧 `formatRelativeTime`，置顶的在标题前挂一枚小图标（不是换色，见 ADR-0017 S2）。
   - 右键走 `primitives/menu.dart` 的 `DswContextMenu`（ADR-0036 B6：`lib/ui` 里 `PopupMenuButton`/`showMenu` 必须保持 0）：重命名 / 置顶或取消置顶 / 删除 / 复制会话 id / 复制工作区路径 / 在访达中显示。reveal 挂在会话行而不是只挂组头，是照上游来的（`useTaskListItemContextActions.ts:168-175` 同时给两处）：用户问的通常是「这次对话的文件去哪了」，那是会话的问题，不是文件夹表头的问题。非 mac 上该项不出现，与 `project_folder_ops` 的 `isSupported` 同一个判据。
  **（2026-10-02 更正：最后这半句不成立，从未有过 `isSupported` 门。**`lib/host/reveal.dart`** 从第一天起就是三平台各答一次**
  （`open`／`explorer`／`xdg-open`），所以这一格在 Windows 与 Linux 上同样出现，只是叫法不该是 Finder——
  那枚错名由 ADR-0041 收成中立的「在文件管理器中显示」。)**
   - 列表仍必须是惰性的（`SliverList`），折叠的组不建行。
7. **「代码」侧补两件**（右侧工作台，用户确认的口径）：
   - 组菜单「显示文件树」= `setWorkspace(path)` 后在右栏开/聚焦 `explorer` tab；不可达路径先反馈再要 picker（macOS 的 security-scoped 授权不能凭空恢复）。
   - 组菜单「移除此工作区」**只**从 `recentWorkspaces` 摘掉，不碰任何会话与布局；该工作区的会话在下次有会话写入前仍按路径成组可见。语义写在调用点注释里，免得下一个人以为它删了历史。

## 后果

- 会话历史第一次有了"属于哪个文件夹"这一维，`<support>/sessions/` 的目录形状**不变**（仍是 genkit 的 `global/.pointers`）——我们不在快照目录里再造一层分区，那是第二份组织真值；分组只存在于读取侧。
- 换工作区的能力从 hero picker 一处入口变成侧栏常驻入口，`AppScope.setWorkspace` 的既有链路（审批、回退点、工作台、runtime 重指向）成为唯一路径；**不允许**在侧栏里另起一条"只改 settings 不换 runtime"的捷径。
- 新增一份盘上文档（`sessions.json`）要进 `backup_service` 的清单，否则换机就丢了归属、置顶与墓碑。
  **已核（2026-10-02）**：写侧 `backup_service.dart:56` 把 `sessions` 整棵目录递归进 zip，读侧逐个条目写回同一个相对路径，
  所以侧车跟着备份往返不需要改动；核这条时发现的不是备份漏了什么，而是**读侧对条目名什么都不信**——
  那一半单独成了 ADR-0042（zip-slip）。
- **与截图的一处有意分歧**：参考实现把组行的动作藏在悬停之后（截图 A 静置时只有文件夹字形与名字，
  截图 B 悬停才出 `⋯`／`≡`／`⊕` 三枚）。这里**一直画着**，理由是 §3 那条已经成立过一次的律——
  "一个控件消失了就不叫降级，叫缺控件"——以及 hover 之后才出现的动作对键盘是第二道门（ADR-0021 收的就是这类）。
  代价写清楚：260px 的 rail 上，组行的名字少约 48px。截图里其余每一维都已复现：节头（`工作区`/`项目`）、
  文件夹字形随折叠换 open/closed、会话行缩进、行右端的相对时间（`59分`/`23天` 与 `formatRelativeTime` 四档逐字对得上）、
  选中行整条圆角高亮、文件夹名 ellipsis 截断。**上游那枚 `⠿` 排序把手属于已明确不做的"组序拖拽"**。
- 侧栏的放大文本与窄列守卫要重挂：组头是一枚新座位，`grep -rln amplified_text_probe.dart test` 里 `sidebar_test` 那棵必须覆盖"多组 + 折叠 + 展开"三态。
- 明确不做（另立，不要顺手加）：跨项目搜索（上游侧栏那把是死键，真身在 command center，我们要做就得先立自己的搜索面）、归档区与"标记未读"、live workflow 计数徽标（我们没有 per-workspace 活动流，画出来就是假徽标）、组序拖拽（上游靠项目 tab 顺序，我们没有多工作区 tab，硬造一份顺序就是新真值）、sqlite 会话索引（当前量级用不上，ponytail）。
- 待 macOS 真机走查：分组在亮/暗两档的观感、`在文件管理器中显示`（这格旧名 `在访达中显示`，2026-10-02 由 ADR-0041 改中立）、切工作区后工作台是否跟着换对、以及"未归属"这一档的文案是否读得通。
