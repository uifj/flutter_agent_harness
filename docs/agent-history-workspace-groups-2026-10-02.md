# 代理模式：按工作区分组的对话历史 — 施工表（ADR-0039）

> 上游依据：`_archive_project/ZCode-main` 的 `packages/ui/src/WorkspaceSidebar.tsx`、`WorkspaceSidebarItem.tsx`、`TaskListItemContextMenu.tsx`、`lib/taskListItemPresentation.ts`、`lib/sidebarTaskPreferences.ts`、`packages/services/src/paths.ts`。逐条 `path:line` 证据在 [ADR-0039](adr/ADR-0039-arc-workspace-grouped-history.md) 的「背景」里，本表不重复。
>
> 范围（用户 2026-10-02 拍板）：截图可见的那一套（分组、折叠、组内新建、相对时间、选中态、组菜单）+ 会话右键菜单；「代码」侧 = 代理模式的右侧工作台。跨项目搜索、归档区、未读徽标、live 计数、组序拖拽、sqlite 索引**不在本表**，理由见 ADR 的「明确不做」。

## 0. 现状与地基（读过的代码，不是记忆）

| 事实 | 位置 |
| --- | --- |
| 会话摘要没有工作区维度 | `lib/model/conversation.dart:210-218` |
| 平铺扫盘：`<support>/sessions/global/.pointers/*.json` | `lib/genkit/agent_runtime.dart:1350-1372` |
| `TurnSource` 无 deleteSession | `lib/model/turn_source.dart:15-61` |
| 侧栏一条惰性 `SliverList`，座位 `rowSession * step` | `lib/ui/sidebar/sidebar.dart:669-693`、`:607`、`:919` |
| 工作区注册表已在 | `lib/model/app_settings.dart:113,167`（`recentWorkspaces`） |
| 换工作区的唯一链路已在（带着审批/回退点/工作台/runtime 重指向） | `lib/state/app_scope.dart:405`、`:323-346` |
| 视图偏好的正确落点（不进 `requiresRuntimeRestart` 通道） | `lib/model/workbench_prefs.dart` 头部注释 |
| 菜单只认一枚原语 | `lib/ui/primitives/menu.dart`（`DswContextMenu`），ADR-0036 B6 |

## 1. 切片

| 片 | 交付物 | 落位 | 门禁 | 提交语 |
| --- | --- | --- | --- | --- |
| S1 | `SessionRegistry`（sidecar `<support>/sessions/sessions.json`：`workspaceRoot`/`pinnedAt`/`deletedAt`/`title` override，tmp+rename 原子写）+ `SessionMeta` 值类型 | `lib/state/session_registry.dart`、`lib/model/session_meta.dart` | `session_registry_test.dart`（真实临时目录：读写、缺文件、坏 JSON 退空表不崩、墓碑过滤、override 与派生标题的优先级） | `feat(state): give each session a workspace, a pin and a tombstone` |
| S2 | 分组纯函数 + 相对时间纯函数 | `lib/model/session_groups.dart`、`lib/model/relative_time.dart` | `session_groups_test.dart`（组序、组内 pinned 优先、未归属档、当前工作区第一、空注册表）、`relative_time_test.dart`（四档阈值边界 59s/60m/24h） | `feat(model): group the history by the folder it happened in` |
| S3 | 索引接上归属与墓碑：`SessionIndex` 读 registry，`SessionSummary` 带 `workspaceRoot`/`pinnedAt`；`WorkbenchPrefs` 加 `historyOrganizeBy` + `collapsedWorkspaces`；`backup_service` 清单加 `sessions.json` | `lib/state/session_index.dart`、`lib/model/conversation.dart`、`lib/model/workbench_prefs.dart`、`lib/state/backup_service.dart` | `session_index_test.dart`（墓碑不出现在列表）、`workbench_prefs_test`/`settings_test` 偏好往返、`app_providers_test`（新 provider override） | `feat(state): the session index learns which folder each one lives in` |
| S4 | 侧栏分组 UI：「工作区」节 + 组头行（chevron/Folder 图标/叶子名/`+`/`⋮`）+ 会话行右侧相对时间与置顶徽标 + `DswContextMenu` 六项 + 重命名走 `ShadDialog` | `lib/ui/sidebar/sidebar.dart`（或拆 `sidebar_history.dart`，能不拆就不拆）、`lib/l10n/locales.dart` 双键 | `sidebar_test.dart`：分组渲染与折叠、组菜单两项、右键菜单六项与 mac 专属那项的缺席、`l10n_parity_test`、`tap_affordance_test` 表、`amplified_text_probe` 两档 ×（多组/折叠/展开） | `feat(ui): the sidebar's history is grouped by workspace` |
| S5 | 「代码」侧两件事：组菜单「显示文件树」= 换工作区后在右栏开/聚焦 explorer；「移除此工作区」= 只摘 `recentWorkspaces` | `lib/state/app_scope.dart`（复用 `setWorkspace`）、`lib/ui/sidebar/sidebar.dart`、`lib/main.dart` 接线 | `app_scope_test`（移除注册表项不动会话与布局）、`workbench_ui_test`（切档后 explorer 落在右栏）、真机走查标"待 macOS 验证" | `feat(workbench): a workspace row can open its tree or step out of the list` |

每片都要过同一组三门禁（与 pr-check 同口径）：`dart format --set-exit-if-changed lib test tool spike` → `dart analyze --fatal-infos lib test tool spike` → `flutter test`（基线 `+1158 -2`，口径**零新增失败**；那两条既有失败不许动）。

## 2. 三条会咬人的实现约束

1. **sidecar 不许存第二份标题真值。** 快照里 `sessionTitle(messages)` 才是标题；`SessionMeta.title` 只在用户改名时写，读取顺序 `override ?? derived` 要写在字段注释里，`session_registry_test` 钉住这条优先级。
2. **删除是墓碑，不是 rm。** 只有 `deletedAt` 被写；盘上快照与 `WorkbenchStore` 的每会话布局都不动。确认框走 `primitives/confirm_dialog.dart`，`destructive` 反馈走 `showFeedback(..., destructive: true)`（ADR-0020）。
3. **换工作区只有 `AppScope.setWorkspace` 一条路。** 组头的 `+` 与「显示文件树」都调它；不许在 UI 里直接 `settingsDocument.workspaceRoot = ...`，那会留下审批规则、回退点与 runtime 三处指向旧目录。

## 3. 验收（每条要给证据）
## 4. 落地进度（2026-10-02）

| 片 | 状态 | commit | 证据 |
| --- | --- | --- | --- |
| S1 | 已落 | `bab31f1` | `test/session_registry_test.dart` 八条（真实临时目录：往返、首写为准、墓碑、取消置顶后整行收干净、空改名不覆盖派生标题、坏 JSON 退空表、坏行只丢一行、写失败要说出来） |
| S2 | 已落 | `c85ff70` | `test/session_groups_test.dart` 六条 + `test/relative_time_test.dart` 四条（四档边界 59s/60m/24h；`/private/var` 与 `/var` 合成一档那条是分组键的守） |
| S3 | 已落 | `5648041`（偏好）+ `bab31f1`（索引组合） | `workbench_prefs_test.dart` 新增两条：偏好往返 + **开关 tab 不许把折叠的文件夹弹开**（`withTabEnabled` 原先手搓构造函数，加字段就会被无关写入冲掉） |
| S4 | 已落 | `851f782` + `5357075` + `5886a00` + `65e7d0f` | `test/workspace_history_test.dart` 十二条，守画出来的那一棵：一组一头、当前档在前、折叠不建行、点表头回报被折的 key、空文件夹仍成组、相对时间、置顶压过更新的、删除只留墓碑（`source.sessions` 仍在）、组菜单与右键菜单、平铺档一头不画、未归属垫底。其中七条在修好"索引把来源报的 workspaceRoot 覆盖成 null"之前是红的；`65e7d0f` 补的两条守的是**生产真正走的那条路**（归属与改名都只能来自 sidecar，因为 genkit 的快照答不出文件夹）——原先那批分组用例是从 summary 字段喂进去的，那条路线上永不发生；两条都做了反向验证（把 `_decorateOne` 里的注册表读取拆掉，恰好 `+17 -1` 只红那一条，还原即绿）；`5886a00` 是推演"这台机器从没跑过应用，第一眼就是空态"抓到的回归：分组分支吃掉了「暂无会话」 |
| S5 | 已接线，守待在真机 | `851f782` | 组菜单两项在 `main.dart` 落到 `scope.adoptRecent` + `scope.workbench.openFolder`，与"只从 `recentWorkspaces` 摘掉"的 `doc.copyWith`；widget 层已由 S4 的菜单两条守住回调契约，剩下的换档观感与 `在访达中显示` 属 macOS 走查 |

| 补 | 已落 | `8906fff` | 上游清单里另外两件**有依据**的：会话行的「在访达中显示」（reveal 在上游同时挂在任务行，`useTaskListItemContextActions.ts:168-175`）与节头菜单的「全部展开 / 全部收起」（一次写入整个折叠集合）。顺带修掉一处自造的门控错误：节头那把 `⋮` 原先只在"能改视图"时才画，只接折叠动作时整把菜单根本不存在——这条是新增的守卫 `collapse all folds every group` 先红出来的 |

**门禁现状（要说清）**：本切片全部落完后全量 `flutter test` = **`+1204 -7`**（基线 `+1158 -2`，净 +46 通过）。那 7 条里属于本仓库文档基线的是两条既有的（`app_scope_test` 的 `/var`↔`/private/var`、`plan_workspace_test` 的 `find.text('notes')`）；另外 **5 条全在 `plan_blocks_test`**（read face / bookmark URL / header cells / block menu / new faces seats），来自同一时间另一批在做的 **ADR-0040（企划块词表）**——那批改的是 `lib/ui/plan/blocks/` 与 `plan_block_document.dart`，本切片一行未碰、也未替它们改断言。我自己的三棵在同一批里全绿：`workspace_history_test` 18、`sidebar_test` 12、`app_frame_test` 13（含"图标即控件必须自报姓名"与 1.8x/2.2x 两档），`check_architecture` = 「7 recorded, 0 new（163 文件）」，`dart format` 与 `dart analyze --fatal-infos` 对本切片范围零告警。剩下的仍是 macOS 真机走查那一眼。


- 三条门禁命令的输出；`flutter test` 的通过数与失败集（对比基线）。
- `dart tool/check_architecture.dart` 仍是「7 recorded, 0 new」。
- 分组逻辑的单测覆盖：未归属档、当前工作区第一、pinned 优先、墓碑过滤、四档时间边界。
- 侧栏守卫在**多组 + 折叠 + 1.8x/2.2x** 下都量过（被约束裁掉的文字不抛异常，只能量出来）。
- **2026-10-02 收口时补的三件**：① 全量套件重跑 = **`+1222 -2`**（排除两棵未入库的 10 分钟超时探针后；-2 仍是那两条既有失败，
  上面那个 `+1204 -7` 是"隔着探针与同期 ADR-0040 半成品"看到的同一个状态）；② `flutter build macos --release` 在本机通过，
  产物 `build/macos/Build/Products/Release/Agent Harness.app`（94.7MB）——**这只证明编译与打包，不证明走查**，签名仍是 ad-hoc；
  ③ 两张参考截图按维度逐条复核过（放大 3x 读）：节头、文件夹字形随折叠换 open/closed、会话行缩进、行右端相对时间
  （`59分`/`23天` 与 `formatRelativeTime` 四档逐字对得上）、选中行整条圆角高亮、名字 ellipsis ——**全部已复现**；
  唯一分歧是上游把组行动作藏在悬停后，这里故意常显，理由与代价写在 ADR-0039 的「后果」里。
- 真机走查清单（待 macOS）：亮/暗两档看分组、组菜单两项、右键六项、`在文件管理器中显示`（这一格旧名 `在访达中显示`，ADR-0041 因 Windows/Linux 上不该承诺 Finder 而改成中立说法）、切工作区后右侧工作台跟着换、备份 zip 里出现 `sessions.json`。
