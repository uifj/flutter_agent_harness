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
| S4 | 已落 | `851f782` + `5357075` | `test/workspace_history_test.dart` 十二条，守画出来的那一棵：一组一头、当前档在前、折叠不建行、点表头回报被折的 key、空文件夹仍成组、相对时间、置顶压过更新的、删除只留墓碑（`source.sessions` 仍在）、组菜单与右键菜单、平铺档一头不画、未归属垫底。其中七条在修好"索引把来源报的 workspaceRoot 覆盖成 null"之前是红的 |
| S5 | 已接线，守待在真机 | `851f782` | 组菜单两项在 `main.dart` 落到 `scope.adoptRecent` + `scope.workbench.openFolder`，与"只从 `recentWorkspaces` 摘掉"的 `doc.copyWith`；widget 层已由 S4 的菜单两条守住回调契约，剩下的换档观感与 `在访达中显示` 属 macOS 走查 |

**门禁现状（要说清）**：S1–S4 落完时全量 `flutter test` = `+1180 -3`，比基线 `+1158 -2` 多 22 条通过。那 3 条里只有 `app_scope_test`（`/var`↔`/private/var`）是既有失败；另外两条是 `plan_workspace_test` 与 `plan_blocks_test` **加载失败**，原因是同一时间另一批在做的 ADR-0040（企划块词表）在 `lib/ui/plan/blocks/plan_block_editor.dart` 里改了 `_LinkInput` 的参数而调用点未同步——不属于本切片，本切片一行未碰。等那批活落地后这两条会回到它们自己的位置（`plan_workspace_test` 原本那条 `find.text('notes')` 失败也被这次加载失败盖住了）。


- 三条门禁命令的输出；`flutter test` 的通过数与失败集（对比基线）。
- `dart tool/check_architecture.dart` 仍是「7 recorded, 0 new」。
- 分组逻辑的单测覆盖：未归属档、当前工作区第一、pinned 优先、墓碑过滤、四档时间边界。
- 侧栏守卫在**多组 + 折叠 + 1.8x/2.2x** 下都量过（被约束裁掉的文字不抛异常，只能量出来）。
- 真机走查清单（待 macOS）：亮/暗两档看分组、组菜单两项、右键六项、`在访达中显示`、切工作区后右侧工作台跟着换、备份 zip 里出现 `sessions.json`。
