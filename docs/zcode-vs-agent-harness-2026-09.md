# ZCode-main × agent_harness 全维度对比与移植评估

- **日期**: 2026-09-29（对比基线：本项目 HEAD `45dee4e`）
- **对比对象**: `_archive_project/ZCode-main`（ZCode v3.14.3，Apache-2.0，Copyright 2026 Z.AI Co., Ltd）
- **用途**: 决定把 ZCode 的哪些内容实现进 `agent_harness`。**本文只做评估，不含代码改动**；任何移植动作先按 `docs/README.md` 立 ADR 并置 ACCEPTED。
- **证据口径**: ZCode 侧行号来自本地归档；该目录**已在 `.gitignore` 里**（commit `f352938`），新 clone 没有它，行号只对持有归档的机器有效。本项目侧数字为现场命令输出。

---

## 1. 一页结论

**规模差 24.6 倍，整体对标没有意义，只有"设计移植"这条路。**

| | agent_harness | ZCode |
| --- | --- | --- |
| 源文件 | 115 个 `.dart` | 3890 个 `.ts`/`.tsx` |
| 代码行 | 35,138 行 | 861,417 行 |
| 进程模型 | 单进程 Flutter（genkit 在进程内） | Electron main + window-scoped Host + CLI 子进程（stdio）+ 可选 server/web |
| 测试 | **52 个 `*_test.dart`** | **4 个 `.test.ts`**（`node:test`），且根 `package.json` 无 `test` 脚本 |
| 决策记录 | ADR-0001…0008 + `docs/debt-register.md` + 迁移台账 | **无 docs/、无 specs/、无 ADR 目录**（AGENTS.md 要求 spec-first，产物未入库） |

两条必须先说的反直觉结论，用来防止把 ZCode 当成全面标杆：

1. **测试覆盖我们是它的 13 倍**。ZCode 的架构治理与"spec 先行"是**书面约束强于机械执行**：`architecture-policy.yaml` 里 15 个模块只有 1 个（`storage`）标了 `managed:true`，`.architecture-baseline.json` 是 `{"violations":[]}`，最大源码文件 6363/5775/5664/5477 行——那套 400 行上限实际只管住 13 个文件 / 1121 行（`packages/services/src/storage`），占 86.1 万行的 0.13%，是**给未来立规矩的脚手架，不是当下的约束**（`scripts/architecture/index.mjs:132,305-306`、`packages/ui/src/v4/ConversationRowView.tsx`）。
2. **它的深度在"分布式状态与时序"上，而我们没有那个问题**。CommandInbox / owner-lease / replayable / stale-run 防护（`apps/zcode-cli/packages/bootstrap/src/zcode-protocol-v4/command-inbox.ts:82-104`、`packages/services/src/zcode-agent/zcodeTaskServiceAdapter.ts:365-380`）之所以存在，是因为有手机远控、relay、多窗口 Host 三条链路要跨进程对账。**照抄这套=为一个不存在的故障面写防御代码**（ponytail：先问这东西要不要存在）。

**真正值得搬的，是那些"和我们同一个问题、解法更成熟"的部分**：审批规则主体与持久化、跑动中排队/转向、文件级 checkpoint 与 rewind、上下文压缩策略、AGENTS.md 指令发现、工具副作用元数据、捆绑原生搜索二进制、模型 IO 轨迹检视器。见 §7 分级路线图。

---

## 2. 定位与技术栈

| 维度 | agent_harness | ZCode |
| --- | --- | --- |
| 产品形态 | 单机桌面 harness（三桌面目标，ADR-0003），无服务端、无账号、无商店 | 桌面（Electron）+ Web + 手机远控 + CLI/TUI，四端共享同一 agent |
| UI 栈 | Flutter 3.41.9 + `shadcn_ui` 0.56.3（迁移中，ADR-0002）+ 自绘 `lib/ui/primitives` | React + Tailwind（CSS 变量令牌）+ Zustand + Lexical（composer）+ shadcn/ui（同源不同版本） |
| 状态 | riverpod 3.2.1 注解模式 + `ChangeNotifier`（`lib/state`） | Zustand store（`packages/ui/src/store`、`v4/*Store.ts`），localStorage 持久化 |
| 运行时 | **Google Genkit（Dart 0.x）**，只活在 `lib/genkit/`（不变量 1） | 自研 TS agent loop（`apps/zcode-cli`，1375 文件 / 29.4 万行）+ zod 协议 |
| 状态模型 | 手写 `toJson`/`fromJson` + `dart:convert` | zod schema + `zod-to-json-schema` 生成工具 JSON Schema |
| 平台边界 | `lib/host`（git/PTY/security-scoped bookmark/profile） | `IPlatformService`（`packages/shared/src/platform.ts`）+ DI |

**共同血统**：本项目的双树工作台/审批回路取自 better-sidebar + dsh 设计思想，ZCode 也实现了同一族形态（side pane tab 系统、工具卡、审批对话框）。所以差异不是"有没有"，而是**成熟度与约束表达**。

---

## 3. UI 布局逐区对比

| 区域 | ZCode（证据） | agent_harness 现状 | 差距判定 | 移植建议 |
| --- | --- | --- | --- | --- |
| 外壳分区 | 5 区：sidebar / 顶浮 chrome / 中列会话 / 底部 terminal / 右侧 pane（`packages/ui/src/app-shell/WorkspaceShellLayout.tsx:1510-1980`） | 5 区外壳（`lib/ui/app_frame.dart:1-5`），右栏 + 下栏 | **持平** | 无需搬 |
| 分栏模型 | **二分树 pane layout**：最多 4 叶、ratio clamp 0.25–0.75、每 pane 绑定 `{workspaceScope, sessionId\|draft\|readOnly}`、单个全局 `focusedPaneId`、渲染用**绝对定位 + CSS 变量**从而改尺寸不 remount 活面板（`v4/paneLayoutTree.ts:23-102`、`v4/workbenchLayout.ts:1-10`、`V4WorkspaceChatArea.tsx:555-590`） | 两棵树（`tree`/`bottomTree`）共用 pane id 计数器、`activePane` 单个全局、尺寸真值只归 `LayoutController`（`lib/model/sidebar_state.dart:99-139`） | **形态等价，实现深度差一档**：我们是固定两栏，它是任意二分树 | 若要做"N 栏自由切分"才搬；当前两栏够用。**注意**：改尺寸不 remount（保住列表滚动/草稿/编辑器状态）这条，无论几栏都值得核对我们的实现 |
| 侧栏 tab | 19 种 tab 类型 + 可排序 + 右键 close/close-others/close-all + "tab overview" 弹出含最近关闭恢复 + browser/bash tab 隐藏时**保持挂载**（`lib/workspaceSidePane.ts:516-551`、`app-shell/SidePaneTabTrigger.tsx:41,190-194`、`SidePaneTabOverview.tsx:238`） | 8 种 `BuiltinTabType` + 右键菜单（close / close others / close all / 送到另一面板）（`lib/model/sidebar_tab.dart:29-38`、`workbench_tab_bar.dart`，commit `319633f`） | 右键菜单**已对齐**；缺 overview+最近关闭恢复、keep-alive | 低成本：keep-alive（browser/terminal tab 隐藏时不销毁）。overview 面板价值低 |
| 会话时间轴 | `useVirtualizer` + `getItemKey` + `measureElement` 实测高度 + 高度缓存 + **底部锚定** + live-tail + 独立"turn 导航轨"（`v4/ConversationTimeline.tsx:696-728,1832`、`timelineRowHeightCache.ts`、`timelineScrollAnchor.ts`、`ConversationTurnNavigator.tsx:110`） | `ListView.builder` 惰性构建（`lib/ui/conversation/chat_view.dart:200`，头部注释自述"已优于源项目"） | **有真实差距**：无高度缓存/锚定 → 长会话向上滚会被流式内容顶飞；无 turn 导航 | 值得搬，纯 UI 层：`ScrollPosition` 锚定 + 每 turn 高度缓存；turn 导航轨（右侧刻度）可作独立小 feature |
| 行模型 | 协议定义 17 种行（`shared/src/zcode-protocol-v4/rows.ts`：turnHeader/userInput/assistantText/reasoning/toolCall/artifact/subagent/hookInvocation/timelineMarker/compact\|forkNotice/modelChange/goalSet/goalVerify/retryNotice/checkpointRestored） | `TurnEvent`/`Conversation` 手写投影（`lib/model/turn_event.dart`、`conversation.dart`） | 我们缺：reasoning 独立行、artifact、hookInvocation、compact/modelChange/checkpointRestored 标记行 | 随 §4 的 compact/steering/hooks 一起补，别单独补行型（无生产者的行型就是死代码） |
| 工具卡 | 渲染器注册表：约 20 工具族 → 60+ 渲染器（`ToolCallBlocks/resolveRenderer.ts:132-168`），edit 卡内嵌 diff | `lib/ui/tool/tool_card.dart` 单卡 + diff 原语 | 结构性差距**但不必追**：我们 9 个工具，一张卡够 | 等工具数 >15 再拆注册表 |
| 审批 UI | `PermissionDialog.tsx:149-217`：allowOnce / allowAlways(带规则 scope) / deny / denyAlways，project 与 session 两级 | 审批回路（interrupt → resume）+ 三模式 composer 选择器（`lib/model/approval_mode.dart:19-28`） | 缺"**always**"这一层：我们现在每次都要点 | 高价值低成本，见 §7 A1 |
| Composer | Lexical + `@` 提及（虚拟化面板）+ slash 命令 + 附件上传队列 + 模型选择 + **思考等级循环控件** + 忙时**输入队列面板**（可删除/编辑/立即发送/拖拽重排/自动排空）（`v4/composer/*`、`LexicalChatInput.tsx`、`ConversationQueuePanel.tsx:31-87`） | mention 展开（`lib/model/mention_expansion.dart`）、拖文件入 composer（`desktop_drop`）、PDF 抽文本（`document_extractor`）、模型 chip（`8a2b8f2`）、审批模式选择 | 缺：忙时排队（我们现在多半是禁发）、思考等级选择 | 排队见 §7 A2；thinking level 依赖模型层（§7 B4） |
| 计划/Plan | **plan 是 composer 开关不是视图**；计划正文作为 `plan-detail` 侧栏 tab，按 `toolCallId` 实时渲染 markdown（`v4/composer/V4ComposerModeControls.tsx:40-209`、`app-shell/PlanDetailSidePane.tsx:42-75`） | 两种工作区模式：企划（Markdown 工作台 + 看板/日程/表格）与代理（ADR-0007）+ `plan` 工具记录 plan of record | **形态分歧，不是落后**：我们把 plan 做成了"另一个工作区"，它做成"会话内视图" | 建议**并存**：在代理模式的会话里加 plan-detail 侧栏 tab（读 `plan` 工具的最新结果）。这是 ADR-0007 的补充面，别推翻既有模式切换 |
| 设置 | 16 个导航节（general/appearance/shortcuts/model/mcp/plugin/plugin-store/skill/commands/hooks/subagents/memory/browser/automations/usage/migration），60+ 节文件（`SettingsPage.tsx:338`） | 全屏设置 + 底部级联快捷菜单（ADR-0005/0006） | 节数少，但**双入口一致性**我们有守卫（快捷菜单与设置页两处接线是规则明文） | 按 §7 引入 hooks/memory 时同步加节，两处都要接 |
| 快捷键 | 注册表 + 录制 + 冲突检测（`shared/src/shortcutCommands.ts:61-99`、`ui/src/shortcuts/bindings.ts:243-377`） | 3 个热键，硬编码在 `state/hotkey_service.dart`（macOS 用 `meta`、其他 `control`） | 缺注册表与冲突检测 | 低成本可搬"注册表"这一层（一处定义，托盘菜单/设置页/热键服务共用），冲突检测等产品需求出现再说 |
| 设计系统 | 排版**只允许** `text-ui-*` 标度，由 `--ui-font-size`（默认 14px）计算；禁 `text-base/sm/xs`；圆角=**嵌套深度**递减（xl→lg→md→sm）；~40 个语义色变量；4 主题；间距基 4px；pane 间 4px 可拖缝 + 4px 透明命中区 + 2px hover 线（`DESIGN.md`、`styles.css:58,143-151,253-606`） | `lib/theme/dsw_*` 令牌 + `DswShadow` elevation ramp（ADR-0004 的 AA 显式豁免） | 我们是**移植 dsh CSS**，它是自成一体的半径/字号律 | 值得搬两条：① 单一 `--ui-font-size` 派生全量字号（Flutter 侧 = 一个 base scalar → `TextTheme`）；② radius-by-nesting 写进 `dsw_alias` 约定。两者都能用现有 `theme_token_test.dart` 守住 |
| 文本缩放 | 有 `--ui-font-size` 用户标量 + 移动端 16px 防 iOS 缩放 | **无**（`textScaler` 全仓 0 处，已登记 P2） | 我们的已知缺口，它给了可抄的解法 | 直接对应登记表"无文本缩放适配"那条 → 见 §7 A5 |
| 无障碍 | 键盘优先（CLI AGENTS.md 明写"键盘操作优先"），虚拟化面板 + 语义 | `DswHoverTap` 提供指针/键盘/语义/右键四性（`dsw_hover_tap_test.dart`） | **持平**，且我们有测试钉住 | 无需搬 |

---

## 4. Agent 能力对比（核心）

| 能力 | ZCode（证据） | agent_harness 现状 | 判定 |
| --- | --- | --- | --- |
| 内置工具 | ~45 个：Read/Write/Edit/ReadPdf/read-image/read-video、Glob/Grep、Bash(+js/node-repl)、TaskOutput/TaskStop、WebFetch/WebSearch、Agent/Task/SendMessage/RespondToCoordinator/submit_result/escalate、TodoRead/TodoWrite、EnterPlanMode/ExitPlanMode、AskUserQuestion、Skill、ReadSessionContext、CronCreate/List/Update/Delete、OffPeak*、Workflow*(9 个)、`mcp__<server>__<tool>`（`tool/handlers/index.ts:76-137`） | 9 个：read/write/edit/glob/grep/bash + plan + todo_write + dsh（子 agent 委托）（`lib/genkit/*.dart` 的 `name:` 实测）+ MCP 工具动态接入 | 工具数是**结果不是目标**。我们缺的关键项：WebFetch/WebSearch、AskUserQuestion、read-image/pdf |
| 工具契约元数据 | 每工具声明 `readOnly/destructive/concurrentSafe/maxOutputBytes/timeoutMs/sideEffectScope/permission/resultBudget`，调度器据此分组并行（`tool/registry.ts:104-129`、`tool/scheduler.ts:65-100,185`） | 只有"哪些工具要审批"这一条硬编码事实（`approval_mode.dart` + 提示词文案） | **最划算的一项移植**：把这几个字段放进 `lib/genkit/tools.dart` 的声明，审批与并发都读它。零新依赖，落点仍不越 `lib/genkit/` 不变量 |
| 审批模式 | 5 档 `plan\|build\|edit\|yolo\|auto`（auto 明确未实现，`permission/service.ts:137`），判定顺序固定（`service.ts:100-210`），`alwaysAsk` **不可绕过**（:127） | 3 档 `ask/plan/auto`（`lib/model/approval_mode.dart:19-28`） | 我们的三档够覆盖 plan/edit/auto 语义，**缺规则体系**（下一行） |
| 审批规则 | 规则主体 `command\|url\|file_path\|path\|pattern\|patch_text`，通配→正则（`permission/rule-matching.ts`），Write 继承 Edit 规则（`service.ts:264,283-292`）；session 级授权**只在内存**，project 级落盘（`service.ts:88`、`executor/permission-rules-persistence.ts:14-23`） | 无。任何 gated 调用每次都问 | **缺口，优先级最高**（每次重复点批准是真实痛点） |
| Turn 状态机 | 10 相位 `idle→processing_input→awaiting_model_response→streaming→scheduling_tools→executing_tools→aggregating_results→awaiting_permission→completing\|error` + `pendingInputs/acceptsPendingInput`（`agent/turn-state.ts:25-58`） | 投影式（`agent_runtime.dart` 的流式 + `streaming_tail.dart`），有流式拆分性能契约（`conversation_controller_test.dart`） | 相位显式化能让我们排队/转向有落点；**别为状态机而状态机**——先做 §7 A2 的队列再补相位 |
| 忙时输入排队 | `CommandInbox`：每会话 FIFO `AsyncGateRegistry`，只在 `settle` 释放；在途/实时/固定三段事实 + 512 条 settled LRU；revision+epoch CAS（`bootstrap/src/zcode-protocol-v4/command-inbox.ts:2,30-33,82-130`） | 无队列（composer 忙时的行为需现场确认；`lib/model/workbench.dart:10-13` 明确说明为什么工作台不设队列） | **值得搬，但要瘦身**：我们单进程，只需"每会话 FIFO + 运行结束排空"，不要 LRU/CAS/epoch（那是跨进程重连产物） |
| 中途转向 steering | `steerTurn` + `delivery: "queue"\|"guide"` + `expectedTurnId` CAS + 字节上限 + 拒绝原因；子 agent 复用同一条（`runtime/methods/steering.ts:57`、`protocol/index.ts:1190`、`subagent/message-steering.ts:26-40`） | 无 | 高价值：跑偏时不打断就能纠偏。与 A2 同批做 |
| checkpoint / rewind / fork | **不是 shadow git**：每次成功文件变更写 before/after artifact + `CheckpointCreated` 事件（`runtime/methods/tools.ts:167-245`、`workspace-checkpoint-persistence.ts:26-47`）；rewind 作用域 `conversation\|workspace\|both`、策略 `active_chain\|file_only\|fork_required\|unavailable`、**compact 感知**（`contracts/src/rewind/index.ts:21-60`）；应用走三路 `applyPatch` + safe/unsafe 分级（`methods/file-rewind.ts:1-55`）；fork 克隆消息 + `forkWorkspaceAtMessage` | 无 rewind/fork/checkpoint。编辑本身有 `text_edit.dart` 精确替换 | **产品级差距**。UI 侧对应"编辑消息时选 preserve/rewind + 文件回滚对话框"（`ConversationRowView.tsx:994-1039`）。成本最高，收益也最高 |
| 上下文压缩 | 有效窗口 = contextWindow − min(maxOutput,21K)；阈值 = 窗口 − 13K buffer；provider 真实 usage 覆盖估算；**3 次失败熔断**；另有 microcompact（`core/src/compact/policy.ts:6-14,67-155`） | 只有读窗口截断与 `TurnOutcome.truncated`（`read_window.dart:43-98`、`agent_runtime.dart:1064`），**没有会话级压缩** | 长会话必然爆窗。缺口明确 |
| 项目指令发现 | 用户级 `~/.zcode/AGENTS.md` → 工作区向上搜索 `AGENTS.md`，去重合并 + 字节上限，并作为 **meta_user 消息**注入而非 system（`adapters/src/context/index.ts:24,94-126,204-241`、`context/sections/request-user-context.ts:23-26`） | 系统提示是**编译期常量** `_systemPrompt`（`agent_runtime.dart:44-75`），无 AGENTS.md 注入 | 我们仓库自己重度依赖 AGENTS.md，**产品里却不读它**——这条最讽刺，且几乎零成本 |
| 记忆文件 | 一条事实一个文件，frontmatter `name/description/type` + `[[links]]` + `MEMORY.md` 索引 + recall 引擎（`context/sections/memory.ts:25-49`、`core/src/memory/recall`） | 无 | 与上一行同批（同一注入通道） |
| 子 agent | `AgentProfile` = markdown frontmatter（tools/disallowedTools/model/permissionMode/memory scope/injectAgentsMd/background/maxTurns/mcpServers/skills），内置 general-purpose/explore，runner 2142 行，支持并行分组与后台（`subagent/profile.ts:22-40`、`runner.ts`、`contracts/src/tools/agent.ts:43-68`） | 固定一个委托目标（`dsh` 工具 + `_subagentPrompt`，`agent_runtime.dart:86,632`）+ 子 agent tab（`subagent_tab.dart`，端口自 SubagentView.tsx） | 从"1 个内置子 agent"升级到"用户可定义的 profile 目录"，成本中等，价值高 |
| Skills | SKILL.md frontmatter，scope project/user/system/admin，来源 agents\|zcode\|bundled\|plugin\|remote，**拒绝符号链接逃逸**（`contracts/src/skills/index.ts:8-57`、`adapters/src/skills/scan.ts:6-22`） | 已有：`genkit_middleware` 的 `skills()`，默认目录 `<support>/skills`，备份也打包 skills（`agent_runtime.dart:654-677`、`backup_service.dart`） | **我们已对齐**，缺多 scope 优先级与 symlink 逃逸防护 |
| Hooks | 7 事件 `SessionStart/UserPromptSubmit/PreToolUse/PermissionRequest/PostToolUse/PostToolUseFailure/Stop`，PreToolUse 可 allow/ask/deny，project hooks 需 trust 记录，transcript 以 `.jsonl` 交给 hook（`contracts/src/hooks/index.ts:7-190`、`hooks/configured-runner-input.ts:26`） | 无 | 引入即"外部代码可改变 agent 行为"= 安全面扩大，必须先 ADR（SEC） |
| MCP | stdio（含进程树包裹）+ StreamableHTTP + SSE + OAuth lease，命名 `mcp__<server>__<tool>`（`adapters/src/mcp/index.ts:132,1417-1462`、`core/src/mcp/name.ts:3-12`） | `genkit_mcp` 主机已接（`agent_runtime.dart:19,108,499,660`），命名 `<server>/<tool>`，设置模型 `lib/model/mcp_settings.dart` | 已有基础，transport 广度取决于 `genkit_mcp` 能力——**升 genkit 前先核 spike FINDINGS** |
| 模型层 | 20 个内置 provider 模板（`config/provider/zcode-builtin.json`，schemaVersion 1/revision 30）× 3 种 API 形状，BYOK 一等 + OAuth + 订阅；modelId 编码 effort（`modelId@@level`）、能力位 `supportsImage/Pdf/Video`（`contracts/src/model/media-policy.ts:40-46`）、完整 usage（cacheRead/Write/reasoning/serverToolUse）与 off-peak 白名单回退 | `known_models` 目录 + `model_directory` + `models_endpoint`（OpenAI 兼容/Anthropic 的 `/models` 拉取）+ 设置页存 key | 缺：能力位（决定能否发图片/PDF 给某模型）、usage 统计、reasoning effort |
| 搜索性能 | 捆绑 ripgrep 14.1.1 / ugrep 7.8.4 / bfs 4.1.1，**逐平台归档 + sha256 清单**，开启时把 Glob/Grep 从模型可见面撤下、改用 bash 预lude（`third-party/native-search/sources.json`、`tool/handlers/index.ts:204-210`、`core/src/embedded-search/capability.ts`） | 纯 Dart 扫描（`lib/genkit/file_search.dart` 用 `Directory.list` + `RegExp`） | 大仓 grep 是我们的性能天花板。搬"捆绑外部二进制"要权衡：体积、三平台、签名/公证（`build.md` §4 缺口）——见 §7 C4 |

---

## 5. 功能与平台维度

| 功能簇 | ZCode 成熟度（证据） | 我们 | 是否搬 |
| --- | --- | --- | --- |
| 会话/任务索引 | MATURE：单一 `node:sqlite` 库（tasks/task_groups/members/view_node_orders/automations/automation_runs/off_peak_tasks，8 个 migration），pinned/archived/deleted/unread/`workspace_key` 主键，多片段搜索摘要（`tasksDatabase/schema-v1.ts:3`、`taskIndexRepo.ts:1334,312-352`） | `<support>/sessions` 每会话 JSON（`app_scope.dart:42`）+ `session_index`（并发扫描**丢弃而非排队**，:39） | **有条件搬**：sqlite 要新依赖（`sqflite_common_ffi`）→ DEP+ARC ADR。先问：我们的会话量是否需要索引与全文摘要？ |
| 工作区身份 | `workspaceIdentity` 与 `workspacePath` 分离，身份 key `trim()||path` 统一用于去重/绑定/缓存/队列/持久化（AGENTS.md:66-71） | 单一 workspace path + security-scoped bookmark（macOS 专属） | 远程链路不需要它，**本地不搬** |
| 定时自动化 | MATURE：cron 5 段/本地时区、maxRunCount、独立工具进程 `BEGIN IMMEDIATE` 认领 + misfire-skip + 单飞 + 退避（`desktop/src/scheduler/index.ts:1-13`、`automationService.ts`） | 无 | 值得搬（单进程内 Timer + 持久化任务表即可），价值高 |
| 闲时任务 off-peak | PARTIAL：云端取号 + poll 晋升 + settle outbox（`offPeakTaskService.ts:1-11`） | 无 | **不搬**（依赖云端票） |
| 插件商店 | MATURE：zip 必须带 64-hex sha256、根逃逸拦截、官方 id 冒充拒绝、内置播种带 stale-aware lock、`featured` 远控（`marketplace.ts:1319-1320,1125-1129,320-356`；`official-plugin-seed-lock.ts:5-19`） | 无，且 `flutter-setup-*` 一类扩展路线被 §2 明文裁剪 | **不搬商店**（无服务端）。**搬它的"根逃逸拒绝"**到我们的 skills 扫描——这是安全红线（SEC） |
| 手机远控 | 客户端协议 MATURE（双链路语义、两层帧预算、ownerRunId 防陈旧、pending 跨重连存活：`http.ts:98-118`、`wire-codec.ts:54-75`、`zcodeTaskServiceAdapter.ts:365-380,579`），**relay/配对服务端不在仓库里**，设备列表是占位（`webAuthLocale.ts:31`） | 无 | **不搬**：没有服务端就没有这条链路 |
| 嵌入式浏览器 / browser-use | MATURE：33 文件 browserView、Playwright 定位器执行、webm 录制、Chrome cookie/localStorage 导入、**web 元素选择器注入脚本**（`desktop/src/main/browserView/`、`ui/src/lib/webElementPickerScript.ts`） | `flutter_inappwebview` 浏览器 tab（非 macOS 平台降级为占位，`build.md` §2B） | 元素选择器可搬（价值高、成本低）；cookie 导入=隐私敏感，需 SEC ADR |
| 文档预览 | MATURE：office docx/legacy doc/xlsx、pdf、pptx（`@aiden0z/pptx-renderer`）（`PreviewPane.tsx:1806`） | 仅 PDF（`pdfrx`，`document_extractor.dart`） | 按需，依赖成本高 |
| 模型 IO 轨迹检视器 | MATURE：解析 `~/.zcode/cli/{debug,rollout}` 的 JSONL，尾读 + 200 调用上限（`services/src/zcode-agent/modelTrajectory.ts`） | 无 | **高性价比**：调试 agent 行为几乎零成本（我们只要落 JSONL + 一个 tab） |
| 白名单命令分类 | 1.8 MB 生成的 CLI flag 注册表 + 只读分类器（`tool/handlers/generated/bash-command-registry.ts`） | bash 全部需审批 | **不搬**（生成物体积与我们的门禁规模不匹配），但"把 bash 只读命令自动放行"这个**产品结论**可以在 A1 的规则体系里用一张小表实现 |
| OTA 更新 / 崩溃采集 | MATURE：stable/preview 双通道 + 服务端 manifest + forceUpdateGuard；崩溃**仅本地归档**（`autoUpdater.ts:244,721-729`、`desktopCrashCapture.ts:19` 提交 URL 指向 `zcode.invalid`） | 无更新通道，签名/公证缺口未解（`build.md` §4） | **不搬**，先把签名公证立 ADR |
| 遥测 | MATURE 但厂商锁定（阿里云 ARMS RUM + 20 个采样器） | 无 | 不搬 |
| i18n | PARTIAL：恰好 en-US + zh-CN | 双字典 + **键集对齐守卫**（`test/l10n_parity_test.dart`，ADR-0008） | 我们已对齐且多一道机器守卫 |
| Computer Use | PLACEHOLDER：`packages/zcode-cua/index.js:1-8` 直接返回"本 build 不含 Computer Use" | 无 | 不搬；留意它的规则名预留方式（权限系统里保留 capability 组） |
| `formal-proof` 包 | **名不副实**：不是证明器，是 d3 trace-tree 审阅视图（`packages/formal-proof/src/main.ts:1-20`） | — | 文档引用时别被包名误导 |

---

## 6. 工程治理维度

| 实践 | ZCode 实现 | 我们的现状 | 建议 |
| --- | --- | --- | --- |
| 架构规则即代码 | 自研 `scripts/architecture/*.mjs`：模块 `requires`/`publicEntrypoints`/层序、`maxFileLines 400`、`maxContractLines 300`、`maxPublicMethods 12`、环依赖与深导入禁令、`oxlint-disable` 计数即违规、**指纹 baseline + 只拦新增违规**、`--changed` 反向依赖闭包、`architecture:context <module>` 输出阅读包（`index.mjs:36-301`、`policy.mjs:31-74`） | 三条 grep 不变量写在规则里，**靠人跑**（`AGENTS.md` §3） | **搬"检查器 + 指纹 baseline + 只拦新增"这一条**：`tool/check_architecture.dart`（~150 行，零新依赖）把三条 grep 变成可执行门禁，并顺手加 400 行告警。这是本次评估里性价比最高的工程项 |
| 快/慢两级门禁 | `verify:pre-push = lint + architecture:check --changed`（`package.json:33`）、CLI 子包 pre-commit 跑 lint+test | 无本地 git hook，pr-check 在 CI（`build.md` §4B） | 加 pre-commit=format+analyze、pre-push=架构检查 |
| spec/ADR 先行 | 文字要求强，**产物未入库**（无 docs/specs/ADR 目录） | ADR-0001…0008 + 唯一状态源登记表 + 迁移台账 | **我们更好**。保持"先 ACCEPTED 再动手" |
| 契约与运行时校验 | zod 全覆盖（协议 3720 行、968 处 `z.`），握手用 `z.literal` 钉版本，兼容=**只加 optional 字段、永不改名**，每版本黄金测试（`protocol/index.ts:73-74,1020`、`rows.ts:14-16`、`core.ts:7`） | 手写 `toJson`/`fromJson`，无 schema 版本字面量 | 搬"只加 optional、不改名"的兼容律 + 一个协议版本常量，不搬 zod |
| 结构化错误 | `CoreErrorType` 常量表 + `{type,code,cause,context,recoverable,retryable}` + `isCoreError`（`contracts/src/errors/index.ts:7-98`），"错误是一等设计对象"、默认向上冒泡 | 各 store/controller 自定错误形态 | 值得轻改：一个 `sealed class AppFailure`（约 2 小时） |
| 日志分层 + traceId | `createServiceLogger(scope)` **强制 traceId 为首参**，4 档语义写死在 AGENTS.md；`traceId` 在 `sessionId` 之上，AsyncLocalStorage 传播 | 无统一 logger 层，`dart:developer` 散用 | 搬"4 档语义定义 + 一次运行一个关联 id"，不搬 ALS/OTLP |
| 外部 I/O 收口 | CLI AGENTS.md 明文：业务模块不得直接 `fs/child_process/fetch/process.env`，全部经 adapter；工具声明副作用范围 | `lib/host/` 就是宿主收口，但 UI 层偶有直接 `dart:io` | 加进架构检查器的一条规则即可（`dart:io` 只允许 `lib/host/`、`lib/state/`…） |
| 跨平台纪律 | CLI AGENTS.md 一整节（路径用标准库、spawn 用参数数组、Windows `.cmd`/空格/转义、大小写敏感、符号链接、能力检测而非假设、无法验证就写剩余风险） | `build.md` §0/§2B 有平台事实，但**没有这节操作守则** | **直接搬进 `.qoder/rules/build.md`**（文档改动，零成本，且和 ADR-0003 一致） |
| 提交粒度 | 每个功能级变更一个 commit、不混无关改动（CLI AGENTS.md 提交规范） | 与 `workflow.md` §5 一致 | 已对齐 |
| 代码规模治理 | 400 行上限，但 15 个模块里 14 个未纳入 managed、baseline 空、最大源码文件 6363 行 | 无上限 | 只作**告警/ratchet**，不作阻断（它的数字就是前车之鉴） |
| knip/oxfmt/patchedDeps/30 个 `.port.ts` | 有 | 无 | 115 文件规模**不需要**，别搬 |

---

## 7. 移植路线图（按"收益/成本/风险"排序）

> 每条都要先立 ADR（下一编号 **ADR-0009**）再动手。标 ★ 的我建议优先做。

### A 组：零新依赖、不踩三条不变量、当场可验收（估 1–2 天）

- **A1 ★ 审批规则体系**：规则主体 `command/url/file_path/pattern` + `allowOnce/always/deny(denyAlways)` + session 内存 / project 落盘两级 + `alwaysAsk` 不可绕过。落点：`lib/model/approval_mode.dart` 加 `ApprovalRule` 模型（纯 Dart）→ `lib/genkit/tools.dart`/`agent_runtime.dart` 判定 → `lib/ui/tool/tool_card.dart` 加"总是允许"入口。验收：`spike/runtime_smoke.dart` 带审批往返。ADR：ARC。
- **A2 ★ AGENTS.md / 项目指令注入 + 记忆文件**：向上搜索 + 用户级优先 + 去重合并 + 字节上限，作为 **meta_user** 消息（不是 system）。落点：`lib/genkit/agent_runtime.dart` 的 prompt 组装。顺带修一处真实缺陷：现系统提示硬写 "running on the user's Mac"（`agent_runtime.dart:45`），与三桌面目标（ADR-0003）矛盾。ADR：ARC。
- **A3 ★ 工具副作用元数据**：`readOnly/destructive/concurrentSafe/maxOutputBytes/timeoutMs/sideEffectScope`，审批与并发都读它。落点：`lib/genkit/tools.dart` 的声明结构 + `agent_runtime.dart` 调度。ADR：ARC（与 A1 可合并）。
- **A4 忙时输入队列 + 中途转向**：每会话 FIFO、运行 settle 时排空、`queue` vs `guide` 两种投递语义；UI 侧一个可拖拽队列面板。**明确瘦身**：不做 epoch/CAS/LRU（跨进程重连产物）。落点：`lib/state/conversation_controller.dart` + `lib/model/turn_event.dart`。ADR：ARC。
- **A5 文本缩放标度**：一个 base scalar 派生 `TextTheme` 全量（对应 `--ui-font-size`），同时闭环登记表里"无文本缩放适配"。落点：`lib/theme/dsw_typography.dart`。验收：`theme_token_test.dart`。ADR：CFG（动 ADR-0004 豁免面之外的正文级呈现，需确认）。
- **A6 架构检查器 + 指纹 baseline**：`tool/check_architecture.dart` 把 AGENTS.md §3 的三条 grep + "外部 I/O 只在 lib/host" + 400 行告警做成一条命令，baseline 只拦新增。接入 pre-push。ADR：TST/CFG。
- **A7 skills 扫描的符号链接逃逸拒绝 + 多 scope 优先级**（安全收口）。ADR：SEC。
- **A8 模型能力位 `supportsImage/Pdf/Video`**：决定附件能否发出，缺口会造成静默丢件。落点：`lib/model/known_models.dart`。ADR：DEF。

### B 组：中等成本，需要新模块（估 3–6 天/项）

- **B1 ★ 文件级 checkpoint + rewind**：每次文件变更写 before/after artifact（不是 shadow git），rewind 作用域 `conversation|workspace|both`，UI 在"编辑已发送消息"时让用户选 preserve/rewind。需要 diff/patch 能力——若引 `diff_match_patch`/`vector_math` 之类要走 DEP ADR（我们已有 `re_highlight`，diff 已有自绘）。ADR：ARC + 可能 DEP。**这是最能改变产品性质的一项。**
- **B2 会话自动压缩**：有效窗口/缓冲/真实 usage 覆盖估算/3 次失败熔断 + microcompact。依赖模型 contextWindow 数据（与 A8 同批）。ADR：ARC。
- **B3 子 agent profile 目录**：markdown frontmatter 定义（tools/model/permissionMode/background/maxTurns/skills），把现在写死的 `dsh` 委托目标变成可枚举。ADR：ARC。
- **B4 reasoning effort + usage 统计**：`modelId@@level` 编码方式与 usage 记账（cacheRead/reasoning 等），设置页与快捷菜单两处都要接（ADR-0006 的双入口律）。ADR：ARC。
- **B5 hooks 引擎（7 事件 + PreToolUse 可否决 + trust 记录）**：等于允许用户代码改变 agent 行为，**安全面明显扩大**，必须先 SEC ADR，建议排在 A7/A1 之后。
- **B6 定时自动化**：单进程内 Timer + 持久化任务表 + 单飞/misfire 策略。ADR：ARC。
- **B7 模型 IO 轨迹检视器**：落 JSONL + 新工作台 tab（走 `workflow.md` §3 的 tab 三步链路）。ADR：DEBT/TST（调试面）。

### C 组：需要新依赖 / 新平台能力 / 与现有 ADR 冲突，暂缓

- **C1 sqlite 任务索引**（替代 per-session JSON）：新依赖 `sqflite_common_ffi`，且要与"手写 toJson/fromJson"路线（`flutter-implement-json-serialization`）正面协商 → DEP + ARC ADR。**除非会话数/搜索成为实测瓶颈，否则不做。**
- **C2 relay / 手机远控**：需要服务端与配对基建，本项目定位明文排除（AGENTS.md §1"单机桌面"）。**不做。**
- **C3 插件商店 / 内置播种 / featured 远控**：同上，无分发服务端。**只搬"zip 根逃逸 + 官方 id 冒充拒绝"这两条安全思想到 skills 加载（A7）。**
- **C4 捆绑 ripgrep/ugrep/bfs**：解决大仓 grep 性能，代价是三平台二进制 + 体积 + **签名/公证缺口未解**（`build.md` §4：CI 无任何 codesign/notarytool 步骤）。折中方案：允许用户指向系统 `rg`（探测 PATH，存在则优先），零体积零签名问题。ADR：DEP。
- **C5 Office 文档预览（docx/xlsx/pptx）**：`@aiden0z/pptx-renderer` 在 Dart 生态无对等物，成本高。
- **C6 OTA 双通道更新 + forceUpdateGuard**：前置是签名/公证 ADR（`build.md` §4）。顺序不能反。
- **C7 崩溃/遥测上报**：与"仓库不配 secrets、无服务端"的现状冲突；ZCode 自己也是本地归档而已。
- **C8 Computer Use**：上游就是占位实现。

### 明确不搬的治理项（在 115 文件规模上是负担）

15 模块 `requires` 图与 `publicEntrypoints` 深导入禁令（一个包 + 三条不变量已覆盖）；30 个 `.port.ts` + `contract.example.ts`/`CONTRACT.md` 仪式；`maxPublicMethods:12`；knip/oxfmt/turbo/`patchedDependencies`；三层帧字节预算（只在有 relay 重编码时才有意义）；90 条 React 规则文件。以及——**把模块治理当阻断器**：ZCode 自己的数字（只有 1 个 managed 模块、baseline 为空、最大源码文件 6363 行）说明这类规则只有在持续迁移时才诚实。

---

## 8. 移植时的红线检查表

动手前逐条过（任一命中就要先立 ADR，不能"顺手"）：

1. **genkit 只活在 `lib/genkit/`**：ZCode 的行模型/协议类型若引入，必须落 `lib/model/`（纯 Dart），不能让 `package:genkit` 出现在别处。
2. **`lib/model/` 不碰框架**：checkpoint/规则/profile 模型都写成纯 Dart + 手写 `toJson`/`fromJson`。
3. **`lib/state/` 不 import `lib/ui/`**：队列/转向/rewind 的状态在 state，UI 只读（唯一已知例外是 `layout_controller.dart:13`）。
4. **不新增依赖**：A 组全部零依赖；C 组每一条都要 DEP ADR。
5. **不动 entitlements**：`macos/Runner/Release.entitlements` 那个"故意没开的 App Sandbox"是能力边界；hooks（B5）与子进程相关能力可能触碰它 → 先 SEC/ARC ADR。
6. **三平台 + 当前机器**：涉及 PTY/文件/子进程/路径的功能（A1/A2/B1/C4）必须按 ZCode 那节跨平台守则设计（参数数组、标准库路径、能力检测），并在交付说明里对未验证平台标"待 <平台> 验证"。
7. **i18n**：任何新 UI 字符串同批进 en/zh 双字典——现在有 `l10n_parity_test.dart` 会拦。工具 description 与返回给模型的 error 文本**不进 i18n**。
8. **主题**：字号/颜色只从 `lib/theme/dsw_*` 加令牌；动对比度豁免面之外的正文级配色要立 ADR，并跑 `dart tool/contrast_check.dart`。
9. **许可与归属（重要）**：本项目立场是**不 fork ZCode 代码，只取设计思想**（与对 dsh/better-sidebar 的立场一致，AGENTS.md §1）。ZCode 是 Apache-2.0：一旦复制任何源码/提示词/素材，就必须保留 `LICENSE`、按 §4(d) 随分发保留 `NOTICE.md` 内容、按 §4(b) 声明修改，并保留其 `THIRD-PARTY-NOTICES.md` 中相关条目的归属（含 ripgrep MIT/Unlicense、zstd BSD-3、gcc-runtime GPL-3.0 + GPL Runtime Library Exception 3.1）。若确实要抄代码，先立 DEP/ARC ADR 并写明归属方案。
10. **门禁口径**：交付前跑 `flutter pub get` → `dart format --set-exit-if-changed lib test tool spike` → `dart analyze --fatal-infos lib test tool spike` → `flutter test`；当前基线是 **+699 -2（两个既有失败）**，验收口径是"零新增失败"（见 `docs/debt-register.md`）。

---

## 9. 建议的执行顺序（如果只做三件事）

1. **A2 项目指令注入 + A8 能力位 + A6 架构检查器**（1 天内，风险最低，直接改变 agent 在本仓库里的行为质量；顺带修掉"running on the user's Mac"这句与 ADR-0003 矛盾的提示词）。
2. **A1 审批规则 + A3 工具元数据 + A4 队列/转向**（2–3 天，把"每次都要点批准""跑起来无法干预"这两个最真实的痛点消掉）。
3. **B1 checkpoint/rewind**（一周量级，做完产品性质就变了：会话可编辑、可回滚、可分叉）。

C 组全部挂到对应前置 ADR 之后，不在本轮。

### 执行进度（2026-09-29，develop）

| 项 | 落点 | ADR | commit | 状态 |
| --- | --- | --- | --- | --- |
| A2 指令注入 | `lib/genkit/instructions.dart` + `agent_runtime` 排队/排空 | ADR-0009 | 9019f3c | 已合入；带 key 的真实链路（模型确实收到该块）待确认 |
| A8 能力位 | `model/known_models.dart` + `state/model_directory.dart` + composer 单门 | ADR-0010 | c34d1a7 · ac18647 · 4496677 | 已合入；**只做了 `supportsImage`**——PDF 本地抽文字、视频无通道，给没有消费者的能力位是凭空加抽象。顺带修掉两处同源缺陷（纯附件发不出、Windows 附件名） |
| A6 架构检查器 | `tool/check_architecture.dart` + `tool/architecture_baseline.json` | ADR-0011 | f74417b | 已合入；5 条规则、7 条 baseline 债务、只拦新增。**没改 `.github/workflows/`**：`test/architecture_check_test.dart` 让 pr-check 的 `flutter test` 顺带跑它，加 CI 步骤就是第二份真值 |
| A3 只读集单点声明 / A1 免问审批规则 | `model/approval_rule.dart` + `genkit/tools.dart` 的 `decideGate` + `state/approval_rule_store.dart` + 面板"总是允许" + 设置页 `approvals` 节 | ADR-0012 | b51ad6a · bca42ce · 15a0ae6 | 已合入；本地可写工具与 MCP 外部工具共用同一判定顺序（plan 拒 → deny → allow → 非 ask 放行 → interrupt），`readOnlyToolNames` 成为只读的唯一声明，`_subagentTools` 消失。**与评估文档不同的两处瘦身**：① 落盘只做 app 级 `<support>/approvals.json`（按工作区分键），没有写进工作区；② ZCode 的会话级规则与 deny 的面板创建入口都没做——前者没有消费者，后者面板上没有"永久拒绝"这个动词。余带 key 的真实链路确认免问生效 |
| A4 队列 + 中途转向 | `model/queued_input.dart` + `genkit/agent_runtime.dart` 的 `_GuideInjector` + `state/conversation_controller.dart` + `ui/conversation/input_queue_panel.dart` | ADR-0013 | ff85999 · c916316 · 850be2a · 480a1f6 | 已合入；FIFO、settle 排空、`queue`/`guide` 两种语义都做了，**没做** epoch/CAS/LRU（照原瘦身）。与评估文档的两处不同：① 落点没有 `turn_event.dart`——队列不需要新事件形状，控制器自己落用户节点即可；② `guide` 不是"另开一条消息"，而是把文本追加进最后一条 user/tool 消息，让 provider 只看到一个 turn（spike probe G 实测：标记进了持久化快照，模型下一轮仍读得到；代价是重启后那条转向不再显示为用户行）。第 2 步到此收口 |
| B1 checkpoint/rewind | `model/checkpoint.dart`（值 + `CheckpointSink`）+ `state/checkpoint_store.dart` + `genkit/tools.dart` 两处截获 + `ui/tool/tool_card.dart` 的 pill 与确认框 | ADR-0014 | 70e3206 · f9782a7 · 2b0bc24 · 5988cfa · e385f58 · 0ec548d | 已合入；**存 before 镜像（内容寻址 blob）而不是 shadow git / patch**，after 只留指纹用于冲突闸门——文件不再是 agent 上次写下的样子就不动它，理由随报告一起说。范围与评估文档不同：只有 `write`/`edit` 可截获，`bash` 与 MCP 的改动看不见，所以 rewind 是"退回落盘过的写"，不是"退到这一轮的全部变化"。**没做**评估文档设想的"编辑已发消息时选 preserve/rewind"（本应用没有编辑已发消息这条链路）。作用域两档 `conversation`/`workspace`，`both` 作为同义词砍掉。第 3 步到此收口，余带 key 的真实链路签收——而 `dart run spike/runtime_smoke.dart` 本机已跑不起来（`tools.dart:31 → state/fs_revision.dart → flutter/foundation`，早于本项存在，已登记）|

移植时踩到的两条与文档判断不同的事实：

1. **能力位不该一次做三个**（A8）。本仓库的附件只有一条 media 通道，`supportsPdf`/`supportsVideo` 今天没有消费者；照搬字段表就是死代码。
2. **"规则即命令"最大的收益不是那三行 grep**（A6），而是把两条"文档里说过、从没查过"的约定（`lib/ui` 不直接 `dart:io`、riverpod 只在装配根）纳进来——前者当场量出 7 处真实违规，后者证明今天是干净的。

---

## 10. 证据索引（复核用）

- ZCode UI：`packages/ui/src/app-shell/WorkspaceShellLayout.tsx:1510-1980`、`v4/paneLayoutTree.ts:23-102`、`v4/ConversationTimeline.tsx:696-728`、`v4/ConversationQueuePanel.tsx:31-87`、`ToolCallBlocks/resolveRenderer.ts:132-168`、`app-shell/PlanDetailSidePane.tsx:42-75`、`components/PermissionDialog.tsx:149-217`、`lib/workspaceSidePane.ts:516-551`、`DESIGN.md`、`styles.css:58,143-151`
- ZCode 运行时：`apps/zcode-cli/packages/core/src/tool/{registry.ts:104-129,handlers/index.ts:76-137,scheduler.ts:65-100}`、`permission/service.ts:88-292`、`permission/broker.ts:34-118`、`agent/turn-state.ts:25-58`、`agent/compact/policy.ts:67-155`、`context/builder.ts:80-130`、`runtime/methods/{steering.ts:57,tools.ts:167-245,file-rewind.ts}`、`subagent/profile.ts:22-40`、`contracts/src/{rewind/index.ts:21-60,skills/index.ts:8-57,hooks/index.ts:7-190,tools/agent.ts:43-68,errors/index.ts:7-98}`、`bootstrap/.../command-inbox.ts:82-130`、`adapters/src/{context/index.ts:94-241,skills/scan.ts:6-22,mcp/index.ts:132,1417-1462,plugins/marketplace.ts:1319,320-356}`
- ZCode 平台/治理：`architecture-policy.yaml:1-67`、`scripts/architecture/{index.mjs:36-301,policy.mjs:31-74}`、`.architecture-baseline.json`、`package.json:33`、`packages/server/src/http.ts:98-118`、`packages/services/src/session/tasksDatabase/schema-v1.ts`、`packages/desktop/src/scheduler/index.ts:1-13`、`third-party/native-search/sources.json`、`apps/zcode-cli/AGENTS.md`（跨平台/副作用/traceId 守则）、`LICENSE`/`NOTICE.md:49,70`
- 本项目：`lib/ui/app_frame.dart:1-5`、`lib/ui/conversation/chat_view.dart:200`、`lib/model/{sidebar_state.dart:99-139,approval_mode.dart:19-28,turn_event.dart}`、`lib/genkit/{agent_runtime.dart:44-75,632-677,tools.dart,read_window.dart:43-98}`、`lib/state/{app_scope.dart:42-52,session_index.dart:39,conversation_controller.dart}`、`test/l10n_parity_test.dart`（ADR-0008）、`docs/debt-register.md`、`.qoder/rules/{workflow.md,build.md}`
