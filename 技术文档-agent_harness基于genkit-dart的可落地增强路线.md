# agent_harness 基于 genkit-dart 的可落地增强路线

> 本文在《对标技术文章：agent_harness 与 dsh 生态横向对比》的完成度评估基础上，逐文件审读 genkit-dart 0.16.1 源码（`~/.pub-cache/hosted/pub.flutter-io.cn/genkit-0.16.1`，与 agent_harness `pubspec.lock` 解析版本一致）及 genkit_openai 0.4.1 / genkit_anthropic 0.3.1 / genkit_mcp 0.3.1 / genkit_middleware 0.6.1 四个伴生包，并核对上游 GitHub releases（截至 2026-09），回答一个问题：**在不引入任何插件系统、完全排除插件生态的前提下，agent_harness 还能借助 genkit-dart 的哪些能力、绕过哪些限制、放弃哪些幻想。**

---

## 一、现状总览

### 1.1 genkit-dart 0.16.1 能力地图（与 agent_harness 相关子集）

| 能力域 | genkit-dart 提供 | 关键源码证据 |
|---|---|---|
| Agent 循环 | `defineAgent`（prompt agent）+ `definePromptAgent`/自定义 `AgentFn`（完全控制回合循环）；`maxTurns`；多回合 `chat()` / `sendStream()` / `resumeStream(respond/restart)` | `lib/src/genkit_class.dart:372`、`lib/src/ai/agents/agent.dart` |
| 流式事件 | `AgentChunk`：`text` / `reasoning` / `accumulatedText` / `toolRequests` / `data` / `media` / `artifact` / `custom`；`AgentStreamChunk`：`modelChunk` / `customPatch` / `artifact` / `turnEnd` | `lib/src/ai/agents/agent_core.dart:363`、`lib/src/types.g.dart:5986` |
| 取消语义 | `CancellationToken`（协作式，AbortSignal 的 Dart 对应物）；`AgentTurn.abort()`；快照 `aborted` 终态 + abort-aware 写入守卫 | `lib/src/ai/agents/agent_core.dart:41-83,402-419`、`agent.dart:142-186,296-300` |
| **关键限制** | in-process transport **不把 cancel 线入 generate**："Aborting an attached in-process turn is therefore effectively persist-only… Threading cancellation through `generate` to cancel attached turns is future work." | `agent.dart:879-885`（源码注释原文） |
| 会话 | `SessionStore`（`getSnapshot`/`saveSnapshot` 两方法）+ 可选 `SnapshotChangeNotifier`；`SessionState = {sessionId, messages, custom, artifacts}`，**messages 含完整轮次（含 tool role）**；快照分支（leaf 解析、可配置拒绝分支）；`FileSessionStore`（`.pointers/` 指针目录 + 2s 轮询变更通知，`maxPersistedChainLength`） | `session.dart:85-131`、`types.g.dart:6878`、`session_io.dart` |
| 中间件 | `GenerateMiddleware` 三钩子：`generate`（整回合含工具循环）/ `model`（裸模型调用）/ `tool`（单次工具执行），外加 `tools` getter（中间件自带工具包） | `lib/src/ai/generate_middleware.dart:31-83` |
| 工具 | `ToolResult<Output>` v2：`.response(output, parts, metadata)`（**multipart，可回传图片等 Part**）或 `.interrupt(data)`；`ToolFnArgs.resumed`（interrupt 后重启的裁决载荷） | `lib/src/ai/tool.dart:56-184` |
| 指标 | `ModelResponse.usage: GenerationUsage`（inputTokens/outputTokens/totalTokens/**thoughtsTokens**）；genkit_openai 0.4.1 流式请求恒带 `stream_options.include_usage` 且已修复填充（上游 #373） | `lib/src/ai/generate_types.dart:88,99`、genkit_openai `openai_plugin.dart:305,337`、`converters.dart:290-297` |
| 子代理 | genkit_middleware 0.6.1 `agents()` 中间件：按 agentNames 自动生成 `delegate_to_<agent>` 委派工具、`maxDelegations` 防失控、会话捕获、**委派产物 artifact 合并**（`AgentDelegationArtifact`） | genkit_middleware `src/agents_middleware.dart:29-173` |
| MCP | genkit_mcp 0.3.1 双向：host 消费外部 **tools + prompts + resources**；`GenkitMcpServer` 反向暴露 | genkit_mcp `lib/genkit_mcp.dart:18-62` |
| 重试 | `RetryPlugin`：maxRetries/statuses/initialDelayMs/maxDelayMs/backoffFactor/jitter/retryModel/retryTools | `lib/src/ai/middleware/retry.dart:24-60` |
| 可观测性 | `runInNewSpan` span 追踪、`setCustomMetadataAttributes`（tool interrupt 自动落 span）、OTLP HTTP exporter、ReflectionServerV2（`listActions`/`runAction`/`runActionState` 流式通知——Dev UI 数据面） | `lib/src/o11y/instrumentation.dart`、`core/reflection/reflection_v2.dart:169-338` |
| 遥测型 UI 协议 | `genkit_a2ui`（0.16.0 新增，Agent-to-UI 流式协议） | releases 0.16.0 |

### 1.2 agent_harness 当前对 genkit API 的实际使用面

`lib/genkit/agent_runtime.dart`（967 行）已使用：`defineAgent`（maxTurns 24 / maxTurns 子代理 / maxTurns 1 侧聊三 agent）、`tools` + `toolNames` 通配（`mcp:tool/*`）、`use: [stopGate, agents(agents:[subagent], maxDelegations), skills(条件挂载)]`、`FileSessionStore(maxPersistedChainLength)`、`chat.resumeStream(restart/respond)` 审批恢复、`AgentChunk.text/.reasoning/.toolRequests` 投影、自定义 `GenerateMiddleware`（`_StopGate` 重载 `model`+`tool` 两钩子实现停止门）。

**已注册但未使用 / 完全未触达的能力**：

- `stateSchema`（typed custom state）与 `customPatch` 流式状态通道——完全未用（`Agent<dynamic>`，State 为 dynamic）；
- `Artifact` / `chunk.artifact` 通道——未用；
- `ToolResult.response(parts:)` multipart——未用（工具只回结构化 JSON）；
- `ModelResponse.usage` 采集——未做（前文报告的"拿不到 token 用量"，实为未截获而非不存在）；
- `RetryPlugin`、OTLP/telemetry、ReflectionServerV2（Dev UI）——未接入；
- 快照分支（conversation fork）、detached abort 路径、`SnapshotChangeNotifier`——未用；
- MCP prompts/resources——只用了 tools。

**这个"未用面"正是本文全部增量的来源。**

### 1.3 基线与分类口径

沿用前文的完成度基线，重映射到本文的八个维度（前文"运行时架构 30% + Agent 核心 40%"合并为维度 1 基线 35%；插件生态与交付形态两维度按要求**不在本文范围**）：

| 维度 | 基线 | 主要失分来源（前文结论） |
|---|---|---|
| 1. Agent 运行时与事件模型 | 35% | guard/compaction/计量缺失、事件族映射靠自研推断 |
| 2. 工具调用与审批链路 | 35% | 工具面窄、无 multipart、无统一工具管线 |
| 3. 会话存储与事件溯源 | 30% | 快照丢 tool turn、无事件溯源、无分支 |
| 4. 模型层指标与流式体验 | 25% | 无 usage、无 retry、TTFT 未采集 |
| 5. 子代理/委派链路 | 45% | 只读、进度黑盒、审批不穿透 |
| 6. UI 工作台交互体验 | 60% | 预览器矩阵、拖拽、侧聊持久化 |
| 7. 安全与权限控制 | 20% | 无统一工具防御层、MCP 工具绕过审批 |
| 8. 工程与质量 | 35% | 无 CI、无可观测性、文档债 |

**三类标记定义**（判定依据均为 0.16.1 源码实证，非推测）：

- **【原生】** genkit-dart 现有 API 直接支持，agent_harness 接线即可；
- **【封装】** genkit-dart 提供了必要的接缝/钩子/数据，但需要上层自研封装才能落地（含"绕过其限制"的合法路径）；
- **【硬约束】** 受 genkit-dart 底层设计或上游明确声明的边界约束，短期无法解决（附缓解策略与上游证据）。

---

## 二、分维度可落地增强清单

### 维度 1：Agent 运行时与事件模型（基线 35%）

**1.1 【原生】typed custom state：为会话引入结构化状态通道**

- **现状**：`Agent<dynamic>` 无 `stateSchema`，todo/plan 存内存、随会话丢；子任务进度靠过滤工具调用流反推。
- **方案**：`defineAgent` 传入 `stateSchema`（schemantic 类型，如 `HarnessState{todos, plan, subtasks, usage}`）；turn 内经 `SessionRunner.updateCustom` 更新；运行时对 `chunk.custom` 订阅即可获得**逐帧 JSON-Patch 应用后的最新状态**（genkit 内部完成 patch 合并与校验容错——中间帧不合规时 `chunk.custom` 为 null，终态严格校验）；`AgentOutput.state` 拿终态。
- **依赖能力**：`AgentChunk.custom` / `AgentStreamChunk.customPatch` / `SessionRunner.updateCustom`（`agent_core.dart:363-394,947-972`）。第一帧补丁为全量替换、后续为增量 patch，协议已定义好。
- **收益**：这是后续多项增强（5.2 进度回传、6.2 实时面板、4.1 usage 累计）的**地基**。单独计 +4%。

**1.2 【原生】TurnOutcome 对齐官方 `AgentFinishReason`**

- **现状**：`TurnFinished` 的 outcome 枚举是自研推断；`aborted` 与 `failed` 的区分靠 StopGate 自行标记。
- **方案**：订阅 `AgentStreamChunk.turnEnd`，直接映射 `AgentFinishReason`（`aborted`/`completed`/`failed` 等官方值）；错误路径用 `AgentOutput.error`（`AgentErrorDetails{status,message,details}`，status 为标准 gRPC 码名）。
- **依赖能力**：`turnEnd` chunk、`AgentFinishReason.aborted`（`agent.dart:415-423`、`agent_core.dart:157-162` 终态集合）。
- **收益**：+2%，同时消除一处自研语义漂移风险。

**1.3 【封装】guard 最小集：超时与工具调用频率护栏**

- **现状**：只有 `maxTurns`（主 24 / 子代理收紧）；无超时、无循环检测。dsh 的 guard（防循环/超时）整体缺失。
- **方案**：复用 `_StopGate` 的中间件骨架，在 `generate` 钩子（包裹整个回合含工具循环）外包一层 timeout race，在 `tool` 钩子内做滑动窗口频率计数；触发即等价于置位停止标志（复用现有取消通路）。genkit 不提供任何现成 guard，但三钩子接缝完整。
- **依赖能力**：`GenerateMiddleware.generate/tool` 钩子（`generate_middleware.dart:41-82`）；局限：genkit 无 guard 概念，策略全自研。
- **收益**：+3%。

**1.4 【封装】abort 状态机落地（detached 路径）**

- **现状**：停止门是自研边界取消；genkit 的 abort 体系（快照标 `aborted`、abort-aware 写入守卫、`AgentTransport.abort`）完全未用，停止后快照状态与 UI 认知不一致。
- **方案**：停止时调用官方 abort 路径持久化 `aborted` 状态；UI 的会话列表/恢复逻辑识别 `aborted` 终态，恢复时提供"从中断处继续"（0.16.1 恢复语义：仅 `completed` 快照可恢复——`agent.dart:700`——aborted 会话需重新发起）。
- **依赖能力**：`_abortSnapshotInStore`、abort-aware mutator（`agent.dart:142-186`）；**局限**：见硬约束 H1——attached turn 的 abort 是 persist-only，模型调用不会被中断。
- **收益**：+1%（状态一致性，能力面增量有限但正确性收益高）。

**维度 1 前后对比：35% → 45%（+10）**

| 项 | 类别 | 增量 |
|---|---|---|
| 1.1 typed custom state | 原生 | +4 |
| 1.2 finishReason 对齐 | 原生 | +2 |
| 1.3 guard 最小集 | 封装 | +3 |
| 1.4 abort 状态机 | 封装 | +1 |

---

### 维度 2：工具调用与审批链路（基线 35%）

**2.1 【原生】`ToolResult` v2 multipart：落地 `read_image`**

- **现状**：6 件套工具只回结构化 JSON；模型看不了图（dsh 有 `read_image`）。
- **方案**：`read_image` 工具用 `ToolResult.response(output, parts: [Part.media(...)])` 回传图片 Part；genkit 负责把它装配进 tool 响应消息。
- **依赖能力**：`ToolResult.response(parts:)`（`tool.dart:68-72,136-158`），0.16.0 的 v2 工具契约（releases #398 同期）。
- **收益**：+4%。

**2.2 【原生钩子 + 封装策略】统一工具执行管线**

- **现状**：工具各自为政；无参数校验、无审计、无统一拦截点（dsh 有 pre/execute/post 三段瀑布）。
- **方案**：新增一个 `GenerateMiddleware`，重载 `tool` 钩子作为唯一拦截点：按工具名路由策略（路径白名单校验、参数 schema 二次校验、结构化审计日志、耗时统计），`next()` 放行；`tools` getter 可顺带注入纯中间件型工具。这是 dsh 工具管线的单点近似。
- **依赖能力**：`GenerateMiddleware.tool` + `tools` getter（`generate_middleware.dart:34,72-82`）。genkit 无 pre/post 三段，但 tool 钩子是包裹式（可前置于 `next` 之前与之后执行逻辑），语义等价。
- **收益**：+3%（同时是维度 7 的 7.1 基建，不重复计分）。

**2.3 【原生注册 + 纯上层实现】`terminal_*` 工具族与 `sidebar_open`**

- **现状**：PTY 终端、文件树、浏览器都已在 UI 层存在，但模型无法触达（better-sidebar 的工具贡献完全缺失，前文标"概念对齐未落地"）。
- **方案**：`terminal_open/read/send/signal/list/close` 六件包装 `terminal_manager.dart` 的会话池；`sidebar_open` 通过 TurnEvent 流通知 UI 层打开对应 tab。注册面是 genkit `defineTool`，实现纯上层。
- **依赖能力**：无新依赖（`defineTool` 现有）；注意 terminal 工具与审批门的关系需在 2.2 管线中声明（写类操作纳入审批）。
- **收益**：+5%。

**2.4 【原生】MCP prompts / resources 消费**

- **现状**：genkit_mcp host 只用了 tools 通配；MCP 服务器的 prompts 与 resources 被丢弃。
- **方案**：host 的 prompts 映射为可执行提示（composer 斜杠命令数据源）、resources 映射为附件/上下文注入。API 已在包内（`convert_prompts.dart`、`convert_resources.dart`），接线即可。
- **依赖能力**：genkit_mcp 0.3.1 host 三资源消费（`lib/genkit_mcp.dart:18-62`）。
- **收益**：+4%（其中 UI 侧收益计入维度 6 的 6.4）。

**2.5 【封装】MCP 工具纳入审批与防御**

- **现状**：`mcp:tool/*` 通配工具绕过审批门——外部服务器工具与本地写工具安全等级不同，当前无区分。
- **方案**：在 2.2 的 tool 钩子里对 `mcp:tool/*` 前缀默认启用审批拦截（`ToolResult.interrupt`），并在系统提示中延续 dsh"外部工具失败需报告而非绕过"的语义。
- **依赖能力**：tool 钩子 + 现有审批中断通路；局限：MCP host 的工具 schema 是运行时动态的，白名单策略需按 server 维度配置。
- **收益**：+2%（安全面同时计入维度 7）。

**维度 2 前后对比：35% → 50%（+15）**

| 项 | 类别 | 增量 |
|---|---|---|
| 2.1 read_image（multipart） | 原生 | +4 |
| 2.2 统一工具管线 | 封装 | +3 |
| 2.3 terminal_* / sidebar_open | 原生注册 | +5 |
| 2.4 MCP prompts/resources | 原生 | +4 |
| 2.5 MCP 审批 | 封装 | +2（与 7 联动，此处计工具面） |

**硬约束注记**：工具级流式输出（genkit JS 的 `streamingCallback`）在 Dart 版不存在（`ToolFn` 返回 `FutureOr<ToolResult>`，无流通道）——见 H3。

---

### 维度 3：会话存储与事件溯源（基线 30%）

**3.1 【封装】修复会话恢复丢 tool turn（本清单最高优先级）**

- **现状**：从快照重建 transcript 时工具轮次丢失。genkit 侧的 `SessionState.messages`（`types.g.dart:6878`）**本身就保存完整消息历史**——`Message` 携带 role（含 tool）与 content（`ToolRequestPart`/`ToolResponsePart`），快照数据是完整的；丢失发生在 agent_harness 的重建/投影层（`conversation_controller.dart` 只投影了部分角色的消息）。
- **方案**：重建逻辑改为遍历 `snapshot.state.messages` 全量投影：tool role 消息 → `ToolCall` 节点（复用现有 sealed `ConversationNode`），model 消息中的 reasoning part → 推理链展示。数据零改造，纯上层修复。
- **依赖能力**：`SessionState.messages` 完整性（原生保证）；局限：无——这是前文报告误判为"Genkit 快照会丢"的一处澄清，实为应用层缺陷。
- **收益**：+8%。**这是向 dsh"模型可见 ⟺ 已记录"不变量收敛的第一步。**

**3.2 【封装】自定义 SessionStore：快照 + JSONL 事件日志双写**

- **现状**：`FileSessionStore` 纯快照制；无逐事件日志，无回放能力。
- **方案**：实现自定义 `SessionStore`（接口仅 `getSnapshot`/`saveSnapshot` 两方法，`session.dart:85-111`，实现成本低）：`saveSnapshot` 时把本次增量消息追加为 JSONL 事件行（`{snapshotId, parentSnapshotId, turnIndex, messages[], finishReason, ts}`），读路径保持快照。事件行即可支撑逐事件回放、审计与检索（session_search 近似）。
- **依赖能力**：`SessionStore` 接口的最小面积 + `TurnContext`（`snapshotId`/`parentSnapshotId`/`turnIndex` 在 turn 开始前预留并传入 handler，`agent.dart:59-75`——事件行天然有链路字段）。
- **收益**：+6%。

**3.3 【原生】会话分支（conversation fork）**

- **现状**：线性快照链；无法从某条消息分叉。
- **方案**：store 层已支持分支解析（"branched history resolves to the most-recently created leaf, or rejected when configured"，`session.dart:97-103`）——以历史某快照为 parent 写入新快照即产生分支；UI 提供"从此消息分叉新会话"。
- **依赖能力**：`getSnapshot` 的 leaf 解析语义 + `parentSnapshotId`（原生）；UI 部分计入维度 6。
- **收益**：+3%。

**3.4 【封装】compaction 近似：回合级历史裁剪**

- **现状**：快照链上限 200（`maxPersistedChainLength`）；无上下文压缩，长会话必然撞模型上下文墙。
- **方案**：在 `generate` 钩子内对 `envelope.request.messages` 做裁剪：保留 system + 近 N 轮 + 更早轮次的摘要（摘要用低配模型旁路生成，经 `GenerateMiddlewareContext.ai` 可发起嵌套 generate——中间件上下文明示支持 `ai.generate/embed`，`generate_middleware.dart:85-92`）。裁剪结果写入 custom state 以便 UI 展示"已压缩"。
- **依赖能力**：`generate` 钩子对 request 的改写 + 中间件内嵌套 AI 调用（原生接缝）；局限：见 H6——dsh 式 compaction/spill 分级体系无原生对应，本方案是回合级近似。
- **收益**：+4%。

**3.5 【原生】`SnapshotChangeNotifier` 多视图同步**

- **现状**：会话状态变更对 UI 是拉模式；`FileSessionStore` 内建的 2s 轮询变更通知（`session_io.dart:17` `_defaultSnapshotWatchPollInterval`）未消费。
- **方案**：注册快照变更回调，驱动会话列表脏标记与多窗口同步（自由悬浮窗场景）。
- **依赖能力**：`SnapshotChangeNotifier.onSnapshotStateChange`（`session.dart:120-131`，FileSessionStore 已实现）。
- **收益**：+2%。

**3.6 【封装】会话列表索引结构化**

- **现状**：`listSessions` 靠遍历 `.pointers/` 目录（`session_index.dart:3` 注释自认"no listing API"）。
- **方案**：随 3.2 自定义 store 顺带维护 `index.json`（sessionId → 标题/时间/消息数/摘要）。**注意**：`SessionStore` 接口无 list 方法（见 H5），list 是自己 store 实现类上的自有方法，不经过 genkit 调用面。
- **收益**：+2%。

**维度 3 前后对比：30% → 50%（+20，八维度中最大单项增益）**

| 项 | 类别 | 增量 |
|---|---|---|
| 3.1 修 tool turn 丢失 | 封装 | +8 |
| 3.2 JSONL 双写事件日志 | 封装 | +6 |
| 3.3 会话分支 | 原生 | +3 |
| 3.4 compaction 近似 | 封装 | +4 |
| 3.5 变更通知 | 原生 | +2 |
| 3.6 列表索引 | 封装 | +2（与 3.2 同工地） |

---

### 维度 4：模型层指标与流式体验（基线 25%）

**4.1 【封装】usage 采集中间件（前文"拿不到 token 用量"的正式解法）**

- **现状**：前文报告称"Genkit `AgentOutput` 不暴露 usage"。经源码核实，**数据在模型响应层是完整的**：`ModelResponse.usage: GenerationUsage`（`generate_types.dart:88,99`），genkit_openai 0.4.1 对流式请求恒带 `stream_options.include_usage`（`openai_plugin.dart:305`）并在 0.16.0 修复了流式/非流式的 usage 填充（上游 #373）；`GenerationUsage` 含 `inputTokens/outputTokens/totalTokens/thoughtsTokens`（推理 token，`converters.dart:290-297`）。缺的只是 Agent 层透出——`AgentOutput` 类型无 usage 字段（`types.g.dart:5630-5650`，字段集固定）。
- **方案**：在 `_StopGate` 同款中间件里重载 `model` 钩子，`next()` 返回的 `ModelResponse` 上截获 usage，累计进 custom state（依赖 1.1）并转发 UI（TTFT 同法：首 chunk 到达时间戳在钩子内记录）。
- **依赖能力**：`GenerateMiddleware.model` 钩子收到完整 `ModelResponse`（含 usage）——这是官方留给"模型调用观测"的正门。
- **依赖局限**：AgentOutput 层不透出属类型面硬边界（见 H2），但 middleware 截获已完全满足应用需求；chunk 级 usage 不存在（只有 per-model-call 粒度）。
- **收益**：+8%（八维度中性价比最高的单点）。

**4.2 【原生】RetryPlugin**

- **现状**：无重试；网络抖动/限流直接失败。
- **方案**：`Genkit(plugins: [..., RetryPlugin()])`，agent `use` 追加 `middlewareRef(name: 'retry', config: {maxRetries: 3, ...})`。配置项完整：statuses 白名单、指数退避、jitter、`retryModel`/`retryTools` 开关。
- **依赖能力**：`lib/src/ai/middleware/retry.dart:24-60`（原生，零自研）。
- **收益**：+4%。

**4.3 【原生 / 部分硬约束】reasoning 链路的补全**

- **现状**：`AgentChunk.reasoning` 消费已做（`agent_runtime.dart:739-740`），但仅对"插件会产出 reasoning part 的模型"有效。genkit_anthropic 0.3.1 原生支持 thinking（`ClaudeThinkingMode.adaptive/enabled`，`known_models.dart:50-67`）；**genkit_openai 0.4.1 未映射 OpenAI 兼容协议的 `reasoning_content` 字段**（全包 grep 无映射代码），DeepSeek 等经兼容端点的推理链依赖 agent_harness 的 `CustomModelDefinition` 自定义包装（现状已在用，`agent_runtime.dart:311`）。
- **方案**：为 anthropic provider 开启 thinking 配置透出；兼容端点继续走自定义 model 包装并在该处统一映射为 reasoning part。
- **依赖局限**：兼容协议映射缺失属上游 gap（H4），有 workaround。
- **收益**：+2%。

**4.4 【封装】流式体验 HUD**

- **现状**：只有 `wallMs/ttftMs` 两个自研计时。
- **方案**：基于 4.1 的数据补 tokens/s、上下文占用估计（inputTokens 累计）、TTFT 分布；流式 markdown 渲染稳定性属纯 Flutter 侧工作。
- **依赖能力**：无（消费 4.1 产物）。
- **收益**：+3%。

**维度 4 前后对比：25% → 42%（+17）**

| 项 | 类别 | 增量 |
|---|---|---|
| 4.1 usage/TTFT 采集中间件 | 封装 | +8 |
| 4.2 RetryPlugin | 原生 | +4 |
| 4.3 reasoning 补全 | 原生+H4 绕过 | +2 |
| 4.4 流式 HUD | 封装 | +3 |

---

### 维度 5：子代理/委派链路（基线 45%）

**5.1 【原生】`agents()` 中间件深化（现状已在用，用满其能力面）**

- **现状**：已接 `agents(agents:[_subagentName], maxDelegations)`（`agent_runtime.dart:417-420`），但只用了委派工具生成与上限两个参数。
- **方案**：①注册多个子代理类型（general / coder / …，官方机制是"每个 agentName 一个专属委派工具 `delegate_to_<agent>`"，`agents_middleware.dart:32-40`）；②启用 artifact 合并——子代理经 `AgentDelegationArtifact` 回传结构化产物，中间件自动把 artifact 内容并入委派结果**并合并进父会话 artifacts**（`agents_middleware.dart:63,81-101`），配合维度 6 的工件查看器形成"子代理产出 → UI 查看"闭环。
- **依赖能力**：`AgentsOptions` 全参数面（原生）。
- **收益**：+5%。

**5.2 【封装】子代理进度实时回传**

- **现状**：subagent tab 靠过滤父会话工具调用流"反推"子任务状态，无实时输出尾部。
- **方案**：委派工具执行期间把子代理 chunk 摘要写入 custom state（`subtasks[i].tail`），经 `customPatch` 逐帧推送（依赖 1.1）；UI 订阅 `chunk.custom` 渲染实时尾部。genkit 的 tool 无流式输出（H3），custom state 是官方进度通道的正解。
- **依赖能力**：customPatch 流（原生）+ tool 钩子（封装）。
- **收益**：+5%。

**5.3 【封装】审批中断穿透验证与修复**

- **现状**：子代理只读是"委派中间件无法把审批中断传回 UI"的自认限制（`agent_runtime.dart:366-375` 注释链）。
- **方案**：先 spike 实证官方 agents 中间件对子代理 `ToolResult.interrupt` 的传播行为（两种可能：中断被吞、或以 tool 结果形式回传父模型）；若被吞，参照其实现自研 delegation middleware（`agents_middleware.dart` 源码约 300 行，参考成本可控），在委派工具内把子代理的 interrupt 重新抛出为父回合 interrupt——父审批面板天然接得住（现有 `resumeStream(restart/respond)` 通路）。
- **依赖能力/局限**：genkit 未承诺委派链的 interrupt 语义（无文档、无测试背书）——此项必须 spike 先行。
- **收益**：+4%（条件性：spike 结论决定走官方还是自研）。

**5.4 【硬约束】多 agent 协作原语**

- genkit-dart 无 spawn_teammate / team_task / wait_agent 等协作原语（对比 dsh 工具目录），见 H8。不计入本轮增量。

**维度 5 前后对比：45% → 60%（+15）**

| 项 | 类别 | 增量 |
|---|---|---|
| 5.1 agents() 深化 + artifact 合并 | 原生 | +5 |
| 5.2 进度实时回传 | 封装 | +5 |
| 5.3 审批穿透（spike 条件性） | 封装 | +4 |

---

### 维度 6：UI 工作台交互体验（基线 60%）

本维度分两组：**genkit 数据通道依赖组**（新数据源解锁的 UI 能力）与**纯上层组**（与 genkit 无关，列入只为完整性，本文不展开设计）。

**6.1 【原生依赖 3.3】会话分支 UI**：消息级"从此分叉"入口 → 以该消息所在快照为 parent 开新链；配合 3.5 的变更通知刷新会话列表。+3%

**6.2 【原生依赖 1.1】todo/plan 面板实时化**：`chunk.custom` 订阅驱动 plan review 面板与 todo 列表实时刷新，替代回合计数器式刷新。+2%

**6.3 【原生依赖 2.1/5.1】工件查看器**：`chunk.artifact` 通道接收委派产物/工具图片 → 工作台开工件 tab（复用现有 image viewer/diff 基建）。Artifact 是 `{name, parts, metadata}` 结构（`types.g.dart:6410-6417`），天然带命名与多 Part。+3%

**6.4 【原生依赖 2.4】MCP prompts 斜杠命令**：composer 补全列表接入 host prompts 映射。+2%

**6.5 【封装依赖 4.1】usage/性能 HUD**：TTFT、tokens/s、上下文占用的状态栏常驻区。+2%

**6.6 【纯上层，genkit 无关】工作台打磨**：拖拽拆分/合并（split_node 纯函数已就绪）、会话级布局持久化、markdown TOC、PDF/HTML 预览、侧聊持久化与"保存为新会话"提升、侧聊继承进行中回合快照。合计 +5%（本文不展开，仅占位）。

**上游跟踪项（不计分）**：`genkit_a2ui`（0.16.0 新增的 Agent-to-UI 流式协议）与 agent_harness 自研的 TurnEvent 投影层思路同源，建议每季度评估一次成熟度；成熟后可考虑替换自研投影层的部分职责，当前不建议引入。

**维度 6 前后对比：60% → 72%（+12；其中 genkit 依赖组 +7，纯上层组 +5）**

---

### 维度 7：安全与权限控制（基线 20%）

**7.1 【封装】统一工具防御管线**（与 2.2 同一基建，此处计安全收益）：tool 钩子内强制工作区路径归一化校验（所有 fs 类工具入参不得逃逸 workspace root）、参数 schema 二次校验、结构化审计日志（对齐 better-sidebar `path-security.ts`/`trust-fence.ts` 的模块化思路）。**+4%**

**7.2 【封装】MCP 外部工具默认审批**（与 2.5 同一实现，安全面计分）：`mcp:tool/*` 默认走审批门 + 按 server 维度配置信任等级。**+3%**

**7.3 【原生依赖 1.4】中断/拒绝的状态一致性**：审批拒绝与停止都落 `aborted`/终态快照，消除"UI 认为已停、存储认为进行中"的不一致窗口。**+2%**

**7.4 【封装（非 genkit 域）】bash 沙箱与凭据**：genkit-dart **完全不含**执行沙箱概念（对比 dsh 的 sandbox 族：bwrap/Landlock/Seatbelt/Windows ACL）——这不是"genkit 限制"而是上游生态位空白（见 H7）。macOS 上用 `sandbox-exec`（Seatbelt profile）包裹 bash 子进程、apiKey 迁 Keychain，纯自研。**+3%**

**维度 7 前后对比：20% → 30%（+10）**

---

### 维度 8：工程与质量（基线 35%）

**8.1 【原生】Dev UI / ReflectionServer 接入**

- **现状**：genkit 的反射服务（`ReflectionServerV2`：`listActions`/`runAction`/`runActionState` 流式通知，`reflection_v2.dart:169-338`）未启用——所有 agent/工具/模型 action 无法可视化调试。
- **方案**：debug 构建下启动 reflection server（`lib/io.dart` 路径），浏览器打开 Dev UI 检查注册的全部 action、手动触发 generate、实时观察流式状态。对"工具 schema 是否正确暴露给模型"这类问题，调试成本从写测试降到打开网页。
- **依赖能力**：原生，零自研；局限：仅在 debug 形态开启，release 不启动。
- **收益**：+4%。

**8.2 【原生】telemetry：span 追踪 + OTLP 导出**

- **现状**：genkit 已自动为每个 action/模型调用/工具执行创建 span（tool interrupt 会自动落到 span metadata，`tool.dart:216-221`），OTLP HTTP exporter（`src/o11y/otlp_http_exporter.dart`）未接。
- **方案**：debug/诊断模式接 OTLP exporter，导出 turn→model→tool 全链路耗时瀑布；配合 4.1 的 usage 中间件把 token 数写入 span attributes。
- **依赖能力**：`runInNewSpan` + exporter 原生。
- **收益**：+3%。

**8.3 【封装】spike 契约扩展（0.15→0.16 语义复验）**

- **现状**：spike 是本仓库既有的升级前契约，但 0.15.0（Agents 大版本）→ 0.16.x 之间有多个行为敏感变更：ToolResult v2 契约（`tool.v2` 注册）、usage 填充修复（#373）、transport 接口加 context 参数（0.16.1 breaking）、abort persist-only 语义。
- **方案**：spike 增补五组探针：①`ToolResult.interrupt` 在 `agents()` 委派链内的传播（喂给 5.3）；②流式 usage 是否稳定填充；③abort 后快照终态与恢复语义；④`chunk.custom` 中间帧 null 容错行为；⑤MCP host prompts/resources 映射形状。
- **收益**：+2%。

**8.4 【封装（纯上层）】CI 与文档**：GitHub Actions（analyze + test + spike）、覆盖率门禁、README/CHANGELOG 正式化。与 genkit 无关，+5%。

**维度 8 前后对比：35% → 47%（+12；genkit 依赖组 +7，纯上层组 +5）**

---

## 三、受 genkit-dart 硬约束无法解决的问题清单

以下各项均有源码或上游 release 证据，短期无法在 agent_harness 侧彻底解决，只能缓解：

| # | 约束 | 证据 | 缓解策略 | 残余风险 |
|---|---|---|---|---|
| H1 | **attached turn 的 in-flight 模型请求无法真正中断**。in-process transport 不把 cancel 线入 generate，`AgentTurn.abort()` 仅持久化 `aborted` 状态 | `agent.dart:879-885` 注释原文："…effectively persist-only. Threading cancellation through `generate` to cancel attached turns is future work." | ①保留自研 StopGate（model/tool 边界取消）；②detached 路径 + `SnapshotChangeNotifier`：分离 worker 观察 aborted 状态自行协作取消（官方推荐路径，仅适用分离模式）；③不建议 middleware race 抛 CANCELLED（底层 HTTP 连接不保证关闭） | 已发出的模型请求照常计费与返回，UI 需按"停止后仍可能收到尾部 chunk"设计 |
| H2 | **`AgentOutput` 无 usage 字段**，chunk 级亦无 usage（仅 per-model-call 粒度） | `types.g.dart:5630-5650` 字段集固定 | 4.1 的 model 钩子截获方案可完全满足应用需求 | 无实质残余；仅"Agent 层原生透出"无解 |
| H3 | **工具无流式输出通道**（genkit JS 有 `streamingCallback`，Dart `ToolFn` 返回单个 `FutureOr<ToolResult>`） | `tool.dart:180-184` | 长任务进度走 custom state `customPatch` 通道（方案 5.2） | 工具中途产物无法以"工具流"语义呈现，需按状态帧解释 |
| H4 | **genkit_openai 未映射 OpenAI 兼容协议的 `reasoning_content`** | 全包 grep 无映射代码（0.4.1） | `CustomModelDefinition` 自定义模型包装（现状已具备） | 上游补映射前，兼容端点推理链依赖自维护包装 |
| H5 | **`SessionStore` 接口无 list 方法** | `session.dart:85-111` 接口仅两方法 | 自定义 store 实现类上自行提供 list（不经过 genkit 调用面） | 官方 store（Firestore 等）不提供，切换 store 时需自己补 |
| H6 | **无 compaction/spill 体系** | 0.16.1 源码无对应模块；上游 releases 无计划条目 | 3.4 的 generate 钩子回合级裁剪近似 | 无法做到 dsh 式分级落盘与透明恢复 |
| H7 | **沙箱能力域空白**（非"限制"，是上游不涉及） | 全包无 sandbox 概念 | macOS `sandbox-exec` 自研（7.4） | 跨平台沙箱（Landlock/bwrap）需逐平台自研 |
| H8 | **多 agent 协作原语缺失**（teams/teammates/wait） | 工具/中间件面均无对应物 | 远期完全自研编排层 | 单机多 agent 协作无上游路线图背书 |

**关于"上游是否会解除 H1"**：截至 0.16.1（2026-09-02）的 releases 与 39 个开放 PR 中均未见 cancellation threading 计划。建议把 H1 的复验纳入 8.3 的 spike 契约，每次升级重跑——一旦上游把 cancel 线入 generate，StopGate 的 model/tool 边界检查可整体退役。

---

## 四、整体预估完成度提升后总表

### 4.1 分维度前后对比

| 维度 | 基线 | 提升后 | Δ | 关键驱动 |
|---|---|---|---|---|
| 1. Agent 运行时与事件模型 | 35% | 45% | +10 | custom state 通道、finishReason 对齐、guard 最小集 |
| 2. 工具调用与审批链路 | 35% | 50% | +15 | multipart 工具、统一管线、terminal_*/sidebar_open、MCP prompts |
| 3. 会话存储与事件溯源 | 30% | 50% | **+20** | 修 tool turn 丢失、JSONL 双写、分支、compaction 近似 |
| 4. 模型层指标与流式体验 | 25% | 42% | **+17** | usage 中间件、RetryPlugin、reasoning 补全 |
| 5. 子代理/委派链路 | 45% | 60% | +15 | agents() 深化、进度回传、审批穿透（条件性） |
| 6. UI 工作台交互体验 | 60% | 72% | +12 | 分支 UI、实时面板、工件查看器、斜杠命令、纯 UI 打磨 |
| 7. 安全与权限控制 | 20% | 30% | +10 | 统一防御管线、MCP 审批、状态一致性、沙箱 |
| 8. 工程与质量 | 35% | 47% | +12 | Dev UI、OTLP、spike 复验、CI |

### 4.2 加权综合

八维度权重（合计 100%）：运行时与事件模型 25、工具与审批 15、会话 15、指标与流式 10、子代理 10、UI 工作台 15、安全 5、工程 5。

- **基线综合：约 37%**（插件生态与交付形态两维度按本文范围排除，故与前文的 33% 口径不同）
- **提升后综合：约 51%（+14 个百分点）**

结构解读：+14pp 中的大部分（约 10pp）来自**genkit-dart 已提供而 agent_harness 未消费的原生/半原生能力**——即"接线工程"而非"造轮子工程"。三个最大的单项（会话 +20、指标 +17、子代理 +15）对应的恰是三个已经存在但未接的数据面：快照里的完整消息历史、模型响应里的 usage、委派中间件的 artifact 合并。

---

## 五、落地优先级

### P0 — 正确性与止血（决定日常可用性，建议一个迭代内完成）

| 序 | 项 | 维度 | 类别 | 理由 |
|---|---|---|---|---|
| 1 | 3.1 修 tool turn 丢失 | 3 | 封装 | 数据正确性缺陷，违反"模型可见⟺已记录"近似不变量，且修复成本最低（纯投影层） |
| 2 | 4.1 usage/TTFT 采集中间件 | 4 | 封装 | 单点性价比最高；agent 产品无 token 计量等于盲飞 |
| 3 | 2.2/7.1 统一工具防御管线 | 2/7 | 封装 | 后续所有工具增量（terminal_*、MCP）的安全前提 |
| 4 | 1.1 typed custom state | 1 | 原生 | 5.2/6.2/4.1 三项的地基，宜早不宜迟 |
| 5 | 8.3 spike 复验 0.16.x + 5.3 审批穿透探针 | 8/5 | 封装 | 委派链 interrupt 语义必须实证后再决定路线 |

### P1 — 能力面拓宽（P0 稳定后）

| 序 | 项 | 维度 | 类别 |
|---|---|---|---|
| 6 | 4.2 RetryPlugin | 4 | 原生（半天工作量） |
| 7 | 2.1 read_image（multipart parts） | 2 | 原生 |
| 8 | 2.3 terminal_* 工具族 + sidebar_open | 2 | 原生注册 |
| 9 | 5.2 子代理进度回传 + 6.2 todo/plan 实时面板 | 5/6 | 封装（依赖 P0-4） |
| 10 | 3.2 JSONL 双写事件日志 + 3.6 列表索引 | 3 | 封装 |
| 11 | 8.1 Dev UI + 8.2 OTLP（debug 形态） | 8 | 原生 |
| 12 | 2.5/7.2 MCP 工具审批 | 2/7 | 封装 |

### P2 — 打磨与远期

| 序 | 项 | 维度 | 类别 |
|---|---|---|---|
| 13 | 3.3/6.1 会话分支 + UI | 3/6 | 原生 |
| 14 | 3.4 compaction 近似 | 3 | 封装 |
| 15 | 2.4/6.4 MCP prompts 斜杠命令 | 2/6 | 原生 |
| 16 | 6.6 工作台纯 UI 打磨（拖拽/预览器/侧聊持久化） | 6 | 封装 |
| 17 | 1.4/7.3 abort 状态机（detached 路径） | 1/7 | 封装 |
| 18 | 7.4 bash 沙箱（sandbox-exec）+ Keychain 凭据 | 7 | 封装（非 genkit 域） |
| 19 | 6.3 工件查看器（依赖 5.1 artifact 合并） | 6 | 原生依赖 |

**排布逻辑**：P0 全部是"数据正确性与度量"——它们不增加任何用户可见功能，但决定了后面每一项功能是否建立在可信的数据面上；P1 是纯增量（多为原生接线）；P2 的分支/compaction/沙箱依赖前两级打好的状态与管线地基。

---

## 六、附：上游动态跟踪建议

| 事件 | 时间 | 对 agent_harness 的影响 |
|---|---|---|
| 0.15.0 | 2026-07-17 | Agents 大版本：durable sessions、interrupts、sub-agent delegation、remoteAgent——agent_harness 当前 agent 栈的地基 |
| 0.16.0 | 2026-09-02 | ToolResult v2 multipart（→2.1）；OpenAI usage 填充修复 #373（→4.1 前提）；`genkit_a2ui` 新增（→跟踪项）；typed model catalogs |
| 0.16.1 | 2026-09-02 | transport 接口加 context 参数（breaking）——升级时注意自定义 transport（若有）签名 |
| 未来 | — | **关注 cancellation threading into generate**（H1 解除信号）；**关注 AgentOutput 透出 usage**（H2 解除信号）；**关注 store list API**（H5 解除信号） |

三条升级纪律：①每次 genkit 升级前重跑 spike（8.3 的探针集）；②`package:genkit` 引用继续锁死在 `lib/genkit/` 目录（架构铁律使升级破坏面恒定为两个文件）；③H1/H2/H5 三个硬约束在每次升级后复验，解除即触发相应自研组件的退役。

---

*本文百分比均为基于源码审读的工程功能完成度主观评估；genkit-dart 行为结论以 0.16.1 源码（pub.flutter-io.cn 缓存，sha256 与 pubspec.lock 一致）及 GitHub releases（截至 2026-09-06）为据。文中标注"spike 验证"的项（5.3、8.3）在实证前不应视为确定结论。*
