# 从零重写一个 AI Agent Harness：自研 agent_harness 对标 DeepSeek dsh 生态的全维度技术对比

> 本文基于对三个真实仓库的源码级审读（2026-09），横向对比自研 Flutter 项目 `agent_harness` 与两大参考工程——DeepSeek 官方宿主 `deepseek-harness-master`（下称 **dsh**）与社区头部插件 `DSH-better-sidebar-main`（下称 **better-sidebar**），从运行时架构、Agent 能力、工具系统、会话模型、UI 工作台、插件生态、工程质量、安全、交付形态、短板量化十个维度逐一拆解，并给出带前提声明的完成度评估与演进路线。

---

## 摘要

`agent_harness` 是一个用 **Flutter + Google Genkit** 从零重写的 macOS 桌面端 AI Agent Harness：它不 fork 任何参考项目的代码，而是分别吸收 **dsh（Runtime Agent 内核）** 与 **better-sidebar（UI 工作台交互）** 两个项目的设计思想后重新实现。

本文的核心结论：

- **对标 dsh（runtime 内核视角）综合完成度约 33%**：agent loop、流式投影、审批中断、停止门、子代理委派这些"内核中的内核"已经立住，但 dsh 靠 227 个包堆出来的能力缝体系、事件溯源会话、63 个工具面、沙箱与自修改能力，绝大部分未落地。
- **对标 better-sidebar（UI 工作台视角）综合完成度约 41%**：8 个工作台 tab 全部是真实现（真 PTY 终端、Git、diff、内嵌浏览器、自由悬浮窗、侧聊、子代理面板），且多处代码注释明确写着"as in the source"的逐行为对齐；缺的是 Mermaid/PDF/HTML 预览、模型驱动的 `sidebar_open`、跨面板拖拽拼装这类"打磨层"。
- **最有价值的部分不是功能覆盖率，而是三件"骨架正确"的事**：`TurnSource/TurnEvent` 协议把 Genkit 隔离在两个文件里（dsh"能力缝"思想的缩小版）、spike 驱动的版本升级契约、以及一条明确的"模型可见 ⟺ 必须入会话"的近似不变量（尽管当前会话层还有已知的丢数据缺陷）。

如果你在评估"用一个非 TS 技术栈重写 agent harness 是否可行"，本文的分维度账单可以直接当 checklist 用。

---

## 一、三个项目与定位关系

工作区 `apps/deep_harness` 是一个"AI Agent Harness 研究对标工作区"，包含三个对象：

```
┌─────────────────────────────────────────────────────────────┐
│                     apps/deep_harness                        │
│                                                             │
│  ┌───────────────────────┐    ┌──────────────────────────┐  │
│  │  deepseek-harness-    │    │  DSH-better-sidebar-     │  │
│  │  master (dsh)         │◄───┤  main (better-sidebar)   │  │
│  │                       │    │                          │  │
│  │  Runtime Agent 内核   │    │  UI 工作台插件           │  │
│  │  TypeScript + Cordis  │    │  寄生于 dsh runtime      │  │
│  │  227 个 workspace 包  │    │  127 个 TS/TSX 源文件    │  │
│  └───────────┬───────────┘    └────────────┬─────────────┘  │
│              │  设计思想                    │ 设计思想       │
│              ▼                             ▼                │
│  ┌─────────────────────────────────────────────────────────┐│
│  │                agent_harness（自研）                     ││
│  │    Flutter + Genkit · macOS 桌面端 · 独立 git 仓库       ││
│  │    lib/ 95 个 Dart 文件 · 29,143 行 · 317 个测试         ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

**1. deepseek-harness-master（对标基准 ①：运行时层）**
DeepSeek 官方开源的 agent harness，基于 Cordis 插件容器，核心理念是"一切皆插件"。pnpm monorepo、约 **227 个 workspace 包**、TypeScript 6 strict 全 ESM。产品形态覆盖 CLI / Web GUI / headless / ACP 自动化服务器 / JSON-RPC SDK（TS + Python 双份）。它定义了这轮对标里"runtime 该长什么样"。

**2. DSH-better-sidebar-main（对标基准 ②：UI 工作台层）**
dsh 的社区头部插件（npm `dsh-better-sidebar` v0.16.1，MIT），给 dsh Web UI 加一个 VSCode 风格的"右侧栏 + 底部面板"双工作台。它自己**没有 runtime**——寄生于 dsh，但把"工作台产品该有哪些交互"这个问题回答得非常完整：7 个内置 tab、6 种文件预览器、自由悬浮窗、跨面板拖拽、28+ 生态插件通过它的 `ctx.betterSidebar` 服务接入。

**3. agent_harness（自研实现）**
Flutter 桌面应用（`pubspec.yaml` 自述："A Flutter desktop agent harness: chat UI, tool-call projection via Genkit, and a split-pane workbench"），仅 macOS 平台，独立 git 仓库，不依赖父 monorepo 的任何包。runtime 依赖 Genkit 0.16.x 全家桶（genkit / genkit_openai / genkit_anthropic / genkit_google_genai / genkit_mcp / genkit_middleware）。

**三者关系一句话**：dsh 负责"Agent 内核该怎么抽象"，better-sidebar 负责"工作台该怎么交互"，agent_harness 是把两者装进一个 Flutter 进程的**重新实现（clean-room reimplementation）**，不是移植——参考项目的代码一行没抄，但大量行为语义（工具返回格式、shell 解析链、diff 分组、审批流）是逐条对齐的。

---

## 二、评估方法与口径声明

本文所有百分比都是**工程功能完成度的主观评估**，评估前提必须先说清楚：

1. **不是代码行数对比**。29,143 行 Dart 对 227 个包没有可比性；百分比衡量的是"该维度上，基准项目所代表的能力面，自研项目覆盖了多少"。
2. **基于静态源码审读**，未做长周期运行对比；性能、稳定性不进入评分。
3. **双基准线不对称**：runtime 类维度（架构/Agent/工具/会话/安全/交付）以 **dsh** 为主基准，better-sidebar 为辅——它自身没有 runtime；UI 类维度（工作台/生态接入）以 **better-sidebar** 为主基准，dsh web 为辅。每个维度都会同时给出对两个参考对象的对照结论。
4. **四档状态标记**，贯穿全文：

| 标记 | 含义 |
|---|---|
| ✅ 已实现 | 功能存在且可用，语义与基准对齐 |
| 🟡 部分实现 | 主干在，边界/细节/配套缺 |
| 🟠 概念对齐未落地 | 设计思想吸收了，功能形态没做 |
| ❌ 完全缺失 | 基准有，自研没有对应物 |

5. 完成度百分比的"分母"是该维度下主基准的能力面清单，由本文审读归纳，不是官方清单。

---

## 三、十维对标总表

| # | 维度 | vs dsh | vs better-sidebar | 状态速览 |
|---|---|---|---|---|
| 1 | 运行时架构 | **30%** | 形态反超（见正文） | ✅分层投影 🟠能力缝 ❌插件容器 |
| 2 | Agent 核心能力 | **40%** | —（寄生于 dsh） | ✅审批/停止门/子代理 ❌compaction/hooks/自修改 |
| 3 | 工具系统 | **35%** | 10% | ✅6 件套语义对齐 ❌web/lsp/terminal_* |
| 4 | 会话存储与事件模型 | **30%** | 形态差异 | ✅TurnEvent 事件族 🟡快照丢 tool turn ❌事件溯源 |
| 5 | UI 工作台能力 | 55%（vs dsh web） | **60%** | ✅8 tab 全真 🟡预览器 ❌mermaid/PDF |
| 6 | 插件/扩展生态 | **15%** | 10% | ✅MCP+Skills ❌对外插件 API |
| 7 | 工程质量 & 测试体系 | **35%** | 55% | ✅317 测试+spike 契约 ❌CI/覆盖率门禁 |
| 8 | 安全机制 | **20%** | 25% | ✅审批门/URL 守卫 ❌OS 沙箱/凭据库 |
| 9 | 产品交付形态 | **15%** | 20% | ✅本地可跑 ❌安装包/文档站/SDK |
| 10 | 短板与差距量化 | 见第十三节 | — | 分析型维度 |

加权综合：**vs dsh ≈ 33%，vs better-sidebar ≈ 41%，整体愿景（桌面一体化 harness）≈ 40%**。计算过程见第十四节。

---

## 四、维度一：运行时架构

### 基准做了什么（dsh）

dsh 的 runtime 是一套**可组合的插件容器操作系统**：

- **Cordis 插件容器**（vendored fork，18 项本地修改清单化管理）：服务注册、瀑布式事件、HMR 热更新、配置重载全部内建。
- **能力缝（capability seam）三角色**：Service Definition（接口）/ Service Provider（实现）/ Consumer（model-facing 工具）。换一个 provider——比如把 fs+subprocess 指向远程沙箱——Bash/PTY/LSP 整条产品行为跟着迁移，上层零改动。
- **profile/bundle 组装**：启动时按"bundle 补丁层 → profile 的 cordis.patch.yml → home 级 → 命令行 --patch"逐层 patch 配置，`dsh --dump-config` 可透视；`dsh plugin add` 一条命令改写 bundle 栈。
- **Typert**：从源码类型生成运行时 Schema 工件，支撑 Host/Client 之间类型安全的 RPC。
- 规模：227 个包、50 个分组，core / llm / 沙箱 / 数据面 / 远程 API / Web GUI / 组装层各司其职。

### agent_harness 做到了什么

- ✅ **一条架构铁律撑起"缩小版能力缝"**：`package:genkit` 只允许出现在 `lib/genkit/`（8 个文件、2,773 行），上层只讲 `lib/model/` 的自有语言。`TurnSource`（agent 接口：send / respondToApproval / stop / 会话管理）+ sealed `TurnEvent` 事件族是这条缝的接口面。Genkit 0.x 升级的破坏面被压缩到 `agent_runtime.dart` + `tools.dart` 两个文件——这正是 dsh"换 provider 不动上层"思想在单文件量级的复刻。
- ✅ **事件投影架构**：`AgentRuntime`（`lib/genkit/agent_runtime.dart`，967 行）把 Genkit `AgentChunk` 流投影成 TurnEvent，`ConversationController`（ChangeNotifier）再把 TurnEvent 投影成会话状态。runtime 与 UI 之间没有直接耦合。
- ✅ **provider 可配置**：openai / anthropic / google 三分支装配（genkit_openai / genkit_anthropic / genkit_google_genai），模型目录经 `models_endpoint.dart` HTTP 拉取。
- 🟡 **启动装配**：`main()` → `AppScope`（runtime + 九个控制器）→ `AppFrame` 五区布局，装配路径清晰；但切换 provider 需要整体重建 runtime（`requiresRestart` 全字段触发），做不到 dsh 的运行时热替换。

### 缺什么

- ❌ **插件容器**：无服务注册表、无瀑布事件总线、无运行时加载外部代码（Flutter AOT 的先天约束，但也意味着 dsh"一切皆插件"的灵活性整体缺席）。
- ❌ **profile/bundle 组装层**：没有配置补丁栈、没有 `--dump-config`、没有插件式挂载。
- ❌ **能力缝的"运行时可换 provider"**：缝在编译期（目录隔离），不在运行期。
- ❌ **Typert 式类型反射 RPC**：单进程应用暂无此需求，也未预埋。
- ❌ **配置 HMR / config-reload**：dsh 有专门的 config-reload 测试，agent_harness 的设置变更走重启重建。

### 完成度评估：**vs dsh 30%**

已实现的"分层 + 协议隔离 + 多 provider"是 dsh runtime 思想中最可移植的 30%；插件容器、seam 运行时替换、组装层是另外 70%，其中相当一部分（插件容器、HMR）在 Flutter AOT 语境下要么做不成、要么要换形态（如 isolate 级插件、编译期注册）。

**vs better-sidebar 的特别说明**：这一格是**形态反超**而非完成度——better-sidebar 自己没有 runtime（100% 寄生于 dsh），而 agent_harness 拥有完整自有 runtime。它是"把 dsh + better-sidebar 两个进程的协作，收进一个进程"的产物。

---

## 五、维度二：Agent 核心能力

### 基准做了什么（dsh）

- **agent-loop 包**：`turn/start → agent/pre-step → step/start → agent/request → llm/stream → tool/call → tools/execute → step/end → turn/end` 的完整事件流，`agent/*`、`tools/*` 是活扩展点。
- **多 LLM provider**（llm-deepseek、llm-pi-ai）、**llm-retry**、**token-meter** 计量。
- **compaction / context**：长会话压缩与上下文管理。
- **guard**：防循环、超时等资源护栏。
- **subagent / workflow / jobs / goal / schedule**：委派、编排、后台任务、目标与定时。
- **hooks**：Claude Code / Codex hook 桥接；**extensions**：agent 自我修改——工具目录里的 `cordis_define / cordis_inspect_self / cordis_run / cordis_stop / cordis_undefine` 五件套，agent 可以检查并挂载/卸载自身插件。

### agent_harness 做到了什么

- ✅ **主 agent + 三个预设角色**：主 agent `dsh`（全工具，maxTurns 24）、只读子代理 `general-purpose`（仅 read/glob/grep，进程内委派，maxDelegations 4）、侧聊 `dsh-side`（无工具无存储）。
- ✅ **流式双通道**：`TextDelta` + `ReasoningDelta`——推理链独立事件，对齐 dsh 的 DeepSeek reasoning 通道语义。
- ✅ **审批中断（human-in-the-loop）**：write / edit / bash 走 Genkit `context.interrupt` → `ApprovalRequired` 事件 → UI 审批面板 → `resumeStream(restart/respond)` 恢复。这条链路与 dsh 的审批语义对齐，是自研项目里完成度最高的一条。
- ✅ **自研停止门（StopGate）**：spike 实测发现 Genkit 的 `CancellationToken` 不能中断任何东西（`spike/agent_spike.dart`，10 条 findings 之一），于是自实现 `_StopGate` GenerateMiddleware（经 plugin 注册）+ cancel token + 停止消费流三管齐下。
- ✅ **plan / todo**：`todo_write`、`plan` 工具 + `plan_review_panel` UI。
- 🟡 **资源护栏**：只有 maxTurns 上限，没有 dsh guard 的超时/循环检测全家桶。
- 🟡 **子代理**：委派链路真实可用，但只读——因为委派中间件无法把审批中断传回 UI（代码注释自认的已知限制）。

### 缺什么

- ❌ **compaction / context 管理**：长会话只能靠快照链（上限 200），没有自动压缩。
- ❌ **hooks 桥**、❌ **extensions 自我修改**、❌ **goal / schedule / jobs**、❌ **workflow 编排**、❌ **多 agent 协作**（dsh 的 `spawn_teammate` / `team_task_*` / `wait_agent` 一族）。
- ❌ **token-meter**：Genkit `AgentOutput` 不暴露 usage，自研侧连计量数据都拿不到（已知的比缺功能更底层的缺口）。
- ❌ **stop 语义的完整性**：停止门只能卡在下一个 model/tool 边界，in-flight 请求取消不了。

### 完成度评估：**vs dsh 40%**

agent loop、流式、审批、停止门、单层子代理委派——"跑通一个回合"所需的内核全部在位且语义对齐；缺的是"规模化运行"所需的 compaction、护栏、计量、编排与协作。dsh 在这一维度的能力面里，前者约占四成。

**vs better-sidebar**：不适用（其 Agent 能力完全来自宿主 dsh）。

---

## 六、维度三：工具系统

### 基准做了什么

**dsh**：`ctx.tools` 注册表 + 执行管线（`tools/pre-execute → tools/execute → tools/post-execute` 瀑布），工具目录文档（`docs/tool-catalog.md`）机器生成收录 **63 个工具条目**（含平台变体），族谱包括：文件族（read / write / edit / str_replace_editor / read_image / glob / grep）、执行族（bash / pwsh / run_code）、终端族（terminal_open / read / send / signal / list / close 六件）、cordis 自修改族（5 件）、会话内省族（session_search / trace / event_*）、子代理与协作族（subagent / spawn_teammate / team_task_* / job_*）、goal 族（3 件）、schedule 族（3 件）、lsp / skill / todo_write / exit_plan_mode / ask_user_question 等。

**better-sidebar** 的工具贡献：可选注入 `terminal_*` 六件（把侧边栏终端暴露给模型）与 `sidebar_open`（模型主动在侧边栏打开文件/文件夹/网页）。

### agent_harness 做到了什么

- ✅ **6 件套语义深对齐**：`WorkspaceTools`（read / write / edit / glob / grep / bash）的工具约定直接对标 dsh——行号格式、offset/limit、replace_all、bash 返回 `[exit code: N]`、工具报错返回 `{ok: false, error}` 而非抛异常。
- ✅ **todo_write / plan**（`plan_tools.dart`）。
- ✅ **task 委派工具**（对标 dsh subagent capability）+ **use_skill**（genkit_middleware Skills，`<support>/skills` 目录 + SKILL.md 注入）。
- ✅ **MCP 通配接入**：genkit_mcp host，工具名 `<server>/<tool>`，agent 侧 `mcp:tool/*` 通配、懒连接。
- 模型可见工具面合计约 **10~12 个工具族**。

### 缺什么

- ❌ **web 搜索/抓取**、❌ **lsp**、❌ **run_code 代码运行时**、❌ **read_image**、❌ **ask_user_question**、❌ **session 内省族**、❌ **goal/schedule/job 族**、❌ **协作族**。
- 🟠 **terminal_*（对 better-sidebar）**：终端能力本身存在（真 PTY），但没有做成模型可调用的工具——"概念对齐未落地"的典型。
- 🟠 **sidebar_open（对 better-sidebar）**：模型驱动 UI 的入口完全未做。
- 🟡 **执行管线的扩展点**：dsh 的 pre/post-execute 瀑布，在 Genkit 语境下只对应到 middleware（skills 等），没有等价的工具级拦截管线。

### 完成度评估：**vs dsh 35%**

数量上约为 dsh 工具面的 1/5，但核心 6 件套的对齐深度很高（返回格式、错误约定都一致），MCP 又补上了一条"外部工具无限扩展"的通道——综合评 35%。

**vs better-sidebar 10%**：其工具贡献（terminal_* + sidebar_open）自研一件都没暴露给模型。

---

## 七、维度四：会话存储与事件模型

### 基准做了什么（dsh）

- **事件溯源（event sourcing）**：JSONL/SQLite 会话日志是唯一真相源，`deriveMessages()` 从日志投影模型历史。
- **运行时不变量："凡模型可见必已入日志"（Model-visible ⟺ logged）**——由运行时断言强制。
- **session-query / 投影 / 标题生成**、**compaction / spill**、持久化目录文档（`persistence-catalog.md`）机器生成并 CI 校验新鲜度。

### agent_harness 做到了什么

- ✅ **封闭事件族设计**：sealed `TurnEvent`（TextDelta / ReasoningDelta / ToolCallRequested / ToolCallSucceeded / ToolCallFailed / ApprovalRequired / TurnFinished），`TurnFinished` 必达并携带 `TurnOutcome`（completed / awaitingApproval / cancelled / truncated / failed）+ `usage{wallMs, ttftMs}` 计时指标。事件分类学上与 dsh 的 turn/step 事件族是同构的。
- ✅ **快照持久化**：Genkit `FileSessionStore`（`<root>/global/<snapshotId>.json` + `.pointers/`），`SessionIndex` 扫指针目录列出会话（Genkit 无 list API，自研 workaround），快照链上限 200。
- 🟡 **投影层**：`ConversationController` 把事件流投影成会话树（sealed `ConversationNode`：User / Assistant / ToolCall / Error）+ `streaming_tail` 流式尾缓冲。

### 缺什么

- ❌ **事件溯源**：快照制 ≠ 日志制——没有逐事件回放、没有增量查询。
- 🟡 **已知的正确性缺陷**：从快照重建 transcript 时，`chat.messages` 会**丢失 tool turn**——这与 dsh 的"模型可见 ⟺ 已记录"不变量直接冲突，是自研项目当前最刺眼的一处偏差。
- ❌ **session-query / 搜索 / trace**、❌ **compaction / spill**、❌ **标题自动生成**、❌ **SQLite 级查询能力**。

### 完成度评估：**vs dsh 30%**

事件族的"形"对齐了，持久化的"神"（事件溯源 + 不变量）没到。30% 里最大的失分项就是 tool turn 丢失——这是 dsh 用整条数据面 guarding 的东西。

**vs better-sidebar 的特别说明**：better-sidebar 自身无会话存储（peer 依赖 `dsh-session` 读写宿主），此格同样是形态差异；但它的"布局/Tab 按会话隔离持久化"（见维度五）是 agent_harness 也没有的。

---

## 八、维度五：UI 工作台能力（主基准：better-sidebar）

### 基准做了什么（better-sidebar）

7 个内置 tab（文件树懒加载目录树 + 软链接感知 / CodeMirror 编辑器 / xterm.js + node-pty 真终端带断线重连回放 / Git 面板带子仓库发现与 linked worktree / 沙箱 iframe 内嵌浏览器带协议分流 / 后台任务页 / Codex 风格侧边对话）+ 6 种文件预览器（图片 / Markdown 含 Mermaid 安全渲染与浮动目录 / HTML / PDF…）+ 双工作台（右栏 + 底部，拖 Tab 跨面板拆分合并）+ 自由悬浮窗（390×780，可拖回停靠，随会话持久化）+ 布局按会话隔离持久化 + 声明式设置卡片 + ~325KB 核心懒加载 + 10+ 语言。

### agent_harness 做到了什么

五区布局（`AppFrame`：sidebar / center / details / workbench / bottom）+ **8 个全部真实现的工作台 tab**（`lib/ui/workbench/tabs/`）：

| Tab | 状态 | 对齐细节 |
|---|---|---|
| file_tree | ✅ | 目录树 |
| editor | 🟡 | re_editor + re_highlight 代码高亮；markdown 预览开关（gpt_markdown，与聊天区共用 `AssistantMarkdown` 渲染器——"一个 markdown 观感"）；图片查看器；二进制 unsupported |
| terminal | ✅ | flutter_pty 真 PTY + xterm；shell 解析链 `$SHELL → /bin/zsh → /bin/bash` + POSIX `-l` 登录参数，注释明写对齐 better-sidebar 的降级链；IndexedStack 保活，切 tab 不断 shell |
| git | ✅ | status 三分组（untracked 归入 unstaged 的口径都对齐）、分页历史（LOG_BATCH=20）、分支切换、提交框、行右键菜单、破坏性操作确认弹窗、行点击开 diff tab |
| diff | ✅ | unified diff 解析 → hunk 行模型 → VSCode 式红删绿增 |
| browser | ✅ | flutter_inappwebview 内嵌；地址栏带**URL 守卫**：scheme 白名单 http/https、bare host 提升 https、拒绝 loopback |
| sidechat | 🟡 | 对话区旁的轻量侧聊（dsh-side agent），**有意做成一次性内存态**（代码注释："deliberately one-shot"）——对比 better-sidebar 的侧聊：继承主会话完整上下文、可持久追问、可"保存为新会话"提升为顶层会话 |
| subagent | ✅ | 从工具调用流过滤 `task` 调用渲染子任务面板 |

加上 **自由悬浮窗**（`free_window_layer.dart`，对标 better-sidebar `FreeWindow.tsx`）、split_view 分栏、窄视口全宽抽屉与宽度偏好持久化（`layout_controller.dart`）、审批面板 / plan review 面板 / 流式尾视图的对话区。

### 缺什么

- ❌ **Mermaid 图表**（计划书明确"Flutter 无成熟本地方案，不做"，README 级别的已知差距）、❌ **PDF / HTML 预览器**、🟡 markdown 预览无浮动目录 / 无内嵌 HTML 消毒渲染。
- 🟠 **跨面板拖拽拆分/合并**：split_tree 纯函数模型完整（`split_node.dart` 可 JSON 往返），但 better-sidebar 那套"拖 Tab 跨面板"的交互未实现。
- ❌ **模型驱动的 `sidebar_open`**（与维度三同源）。
- 🟡 **布局的会话级隔离**：宽度偏好是全局持久化，better-sidebar 是"布局/Tab/面板按会话隔离持久化 + 陈旧状态自动净化"。
- ➖ **懒加载分块**：better-sidebar 的 ~325KB 核心 + 按需 chunk，在 Flutter AOT 语境下形态不同（单二进制），标注为不适用而非缺失。

### 完成度评估：**vs better-sidebar 60%**

8 个 tab 全部越过"占位"抵达"真实现"，终端/Git/diff 的行为语义对齐到了代码注释级别的逐条复刻；失分集中在预览器矩阵（mermaid/PDF/HTML 全缺）、拖拽拼装、会话级布局隔离。

**vs dsh web 55%**：dsh web 是对话优先的 GUI（slots/renderer/commands 插件位 + 40+ ui-* 包）；自研的对话区（流式尾、审批面板、plan review、图片输入 composer）覆盖了它的主干交互，但 slot 化的可扩展性不在一个量级。

---

## 九、维度六：插件/扩展生态

### 基准做了什么

**dsh**："一切皆插件"——功能包即插件、npm 分发、`dsh plugin add` 一条命令装进 bundle 栈、patch 层合并、跨插件服务暴露（`ctx.betterSidebar` 就是插件暴露服务给其他插件的样本）、28+ 生态插件市场（dshfind.com）、agent 自我修改。

**better-sidebar**：生态的"服务优先"样板——内置 7 tab + 6 viewer 与第三方插件走同一个 `ctx.betterSidebar` API（`registerTab` / `registerFileViewer`），能力完全对等，官方主动把可生态化的功能让给生态。

### agent_harness 做到了什么

- ✅ **MCP**：标准的工具生态协议，外部 server 的工具经 `mcp:tool/*` 通配进入模型工具面。
- ✅ **Skills**：`<support>/skills` 目录的 SKILL.md 注入 + `use_skill` 工具——提示词生态的入口。
- 🟠 **进程内 tab 注册表**：`tab_registry.dart` 的 `registerTab(TabDescriptor)` 是 better-sidebar `registerTab` 的进程内版——签名思想同源，但只在编译期内对自家代码开放。

### 缺什么

- ❌ 对外插件 API（第三方无法给 agent_harness 注册 tab / viewer / 工具）。
- ❌ 运行时代码加载（Flutter AOT 约束，动态化需要 isolate + 解释器或编译期注解生成的方案）。
- ❌ 插件分发渠道 / 清单市场 / 版本协商（better-sidebar 连"双挂载守卫"都用 `!!js` 表达式做了，这一整套装配治理没有对应物）。
- ❌ 跨插件服务暴露协议。

### 完成度评估：**vs dsh 15%**，**vs better-sidebar 10%**

MCP + Skills 是仅有的两条真实外部扩展通道（都是业界标准协议，选型正确）；UI/服务级生态则完全未启动。

---

## 十、维度七：工程质量与测试体系

### 基准做了什么

**dsh**（业界罕见的重装阵）：六条 vitest 测试车道——单元（**per-file 100% 覆盖率门禁**，未达标打精确到 path:line:col，带理由的平台豁免清单）、真实 API e2e（无 key 自跳过）、**keyless 快照回放**（录一次模型响应，永久 diff 回放，产品可见变更必须在同 PR 加快照）、Playwright web、perf、stress；18 个 GitHub workflow + GitLab Python 发布流水线；knip / oxlint / jscpd / lefthook / publint 门禁；文档机器生成 + CI 校验新鲜度；双语翻译配对校验。

**better-sidebar**：104 个测试文件（vitest + jsdom 单元 + Playwright e2e mount），且有一类很特别的测试——**对"打包物本身"的契约测试**（plugin-shape / market-manifest / produced-files / consumer-types），保证发布产物的形状不破。

### agent_harness 做到了什么

- ✅ **42 个测试文件 / 317 个测试全绿**（Flutter 3.41.9），`flutter analyze` 零问题。
- ✅ **fake 体系**：fake_terminal_process / fake_git / fake_turn_source——与 dsh"偏爱真实现而非 mock"哲学同源，用进程外边界的 fake 换取 UI/状态层的真实测试。
- ✅ **spike 契约（自研特色，值得单独表扬）**：`spike/agent_spike.dart` 是对 Genkit 运行时行为的可执行探针（10 条 findings，例如"CancellationToken 不中断任何东西"），注释约定**版本升级前必须重跑 spike**——这是 Genkit 0.x 生态尚不稳定背景下非常正确的工程对策。
- 🟡 测试覆盖了状态层/模型层/布局求解（纯函数）等主干，但无覆盖率门禁、无 e2e 车道、无快照车道。

### 缺什么

- ❌ **CI**：无 `.github` 目录，零流水线——317 个绿测试完全依赖本地自觉。
- ❌ 覆盖率门禁、❌ 快照回放（对 LLM 应用尤其值钱——dsh 的 keyless replay 让回归测试不花钱）、❌ 性能/压力车道、❌ 消费者类型契约。
- 🟡 **文档债**：README / CHANGELOG 仍是 Flutter 模板 TODO；与 dsh/better-sidebar 的双语完整文档体系相比是裸奔状态。

### 完成度评估：**vs dsh 35%**，**vs better-sidebar 55%**

测试文化本身是健康的（数量、fake 策略、spike 契约都在水准之上），缺的是"门禁自动化"这一整层——而那恰恰是 dsh 之所以敢用 227 个包互相踩的底气。

---

## 十一、维度八：安全机制

### 基准做了什么

**dsh**：OS 级沙箱族（bwrap / Landlock / Seatbelt / Windows ACL + `native/landlock-run` 原生 launcher + E2B 远程沙箱 POC）、credentials / identity 包、guard 资源护栏、dsh-invariants 不变量库。

**better-sidebar**：`path-security.ts` / `trust-fence.ts` 专职路径逃逸与信任边界、DOMPurify 消毒的内嵌 HTML 渲染、Mermaid strict 安全渲染、沙箱 iframe、`open-external` 协议分流（HTTP 内嵌 / HTTPS 系统浏览器）、openpath 拦截。

### agent_harness 做到了什么

- ✅ **审批门**：write / edit / bash 全部走 `ApprovalRequired` 中断，人审放行——语义安全的"最后防线"是完整的。
- ✅ **工作区访问边界**：macOS 安全作用域书签（`project_folder_ops.dart`）管理工作区访问，应用级文件访问有边界感。
- ✅ **参数注入防御**：git 封装全部走参数数组（`Process.run('git', [...])`），不走 shell 字符串拼接。
- ✅ **浏览器 URL 守卫**：scheme 白名单（仅 http/https）、拒绝 loopback 地址、bare host 归一化——浏览器 tab 自带一层 SSRF/协议面收敛。
- 🟡 **终端 shell 解析**：固定降级链而非任意命令拼接。

### 缺什么

- ❌ **模型 bash 的 OS 沙箱**：bash 工具裸跑在用户权限下——dsh 有四种平台沙箱 + 远程沙箱可选，自研完全没有。这是与 dsh 差距最大、也最该优先补的一格。
- ❌ **凭据管理**：apiKey 明文存设置存储，无 credentials/identity 概念。
- ❌ **路径安全专职模块**：未见 better-sidebar 式的 path-security / trust-fence 独立防御层。
- ❌ **guard 资源护栏**（超时 / 循环检测，与维度二同源）。

### 完成度评估：**vs dsh 20%**，**vs better-sidebar 25%**

审批门是"对的最后防线"，但 dsh/better-sidebar 的安全是纵深防御（沙箱 + 路径安全 + 渲染消毒 + 凭据隔离多层叠加），自研目前只有一道门和几个局部守卫。

---

## 十二、维度九：产品交付形态

### 基准做了什么

**dsh**：npm 一键 `npx @deepseek-ai/dsh web`；CLI / Web / headless / ACP 四种形态；TS + Python 双 SDK（Python 侧把 Node 单 exe 打进平台 wheel，manylinux / glibc / macOS deployment target 全校验，GitLab PyPI 发布流水线）；VitePress 文档站；品牌规范与 benchmark 文档。

**better-sidebar**：npm 发布、`dsh plugin add` 一条命令安装（含 pnpm 构建脚本放行的完整故障指引）、双语文档 + 演示视频、插件市场收录。

### agent_harness 做到了什么

- ✅ **本地源码可运行**：`flutter run` 即起，端到端真实可用（聊天 → 审批 → 工具 → 工作台）。
- ✅ 独立 git 仓库，5 个 commit，提交信息纪律良好（"C4: tab strip 右键菜单"、"Layout audit"）。
- ❌ 无安装包（dmg/pkg）、无分发渠道、❌ 无 CLI/headless 形态、❌ 无 SDK、❌ 文档站/README 完整版（模板 TODO）、❌ 无版本发布流程。

### 完成度评估：**vs dsh 15%**，**vs better-sidebar 20%**

一个"能跑的好应用"与一个"可交付的产品"之间，隔着的全是工程外包装。

---

## 十三、维度十：现存短板与差距量化（分析型维度）

把散落在各维度的已知问题集中成一张账单，便于追踪：

### 13.1 硬数字对比

| 指标 | agent_harness | dsh | better-sidebar |
|---|---|---|---|
| 代码规模 | 95 文件 / 29,143 行 Dart | ~227 包（TS） | 127 文件 / 33,801 行 TS+TSX |
| 模型可见工具面 | ~10–12 族 | 63 条目 | +terminal_×6、sidebar_open |
| 测试 | 42 文件 / 317 tests | per-file 100% 门禁 × 6 车道 | 104 测试文件 |
| CI 流水线 | **0** | 18+ workflows + GitLab | 1（+本地钩子） |
| 界面语言 | 2（zh/en） | 双语文档体系 | 10+ 语言 |
| 文件预览器 | 文本 / 图片 + md 预览 | —（宿主职责） | 6 种（含 mermaid/PDF/HTML） |
| 会话模型 | 快照（链≤200） | 事件溯源（JSONL/SQLite） | 复用宿主 |

### 13.2 已知技术债与功能缺陷清单（按严重度排序）

1. **会话恢复丢 tool turn**（数据正确性）：快照重建 transcript 时 `chat.messages` 缺工具轮次，直接违反 dsh 的"模型可见 ⟺ 已记录"不变量。
2. **模型 bash 无沙箱**（安全）：裸跑用户权限。
3. **无 token 用量**：Genkit `AgentOutput` 不暴露 usage，计量链路从数据源就断了。
4. **in-flight 请求无法取消**：停止门只能卡在下一个 model/tool 边界（Genkit 0.x 平台限制，spike 已实证）。
5. **子代理只读**：审批中断无法穿透委派中间件传回 UI。
6. **README / CHANGELOG 模板债**：对外第一印象与实际成熟度严重不符。
7. **`pending_tab.dart` 占位机制残留**：注册表里仍保留占位路径。
8. **无 CI**：所有质量门禁靠本地自觉。
9. **`dart_sources.md` 重建来源**：项目本身是从一份 0.7MB 源码合订 md 重建的（导入路径曾从 `package:app/` 改写为 `package:agent_harness/`）——历史包袱已消化，但这份 md 与代码的漂移需要决断（归档或删除）。
10. **侧聊不可持久化/不可提升**：与 better-sidebar 侧聊的能力差距（有意取舍，但差距客观存在）。

---

## 十四、综合完成度总结

### 14.1 加权计算（权重反映"该维度对 harness 产品成败的重要性"）

**基准线 A：对标 dsh（runtime 内核视角）**

| 维度 | 权重 | 得分 | 加权 |
|---|---|---|---|
| 运行时架构 | 20% | 30 | 6.00 |
| Agent 核心能力 | 16% | 40 | 6.40 |
| 工具系统 | 12% | 35 | 4.20 |
| 会话存储与事件模型 | 12% | 30 | 3.60 |
| UI 工作台（vs dsh web） | 10% | 55 | 5.50 |
| 插件/扩展生态 | 10% | 15 | 1.50 |
| 工程质量 & 测试 | 10% | 35 | 3.50 |
| 安全机制 | 5% | 20 | 1.00 |
| 产品交付形态 | 5% | 15 | 0.75 |
| **合计** | 100% | — | **≈ 33%** |

**基准线 B：对标 better-sidebar（UI 工作台视角）**

| 维度 | 权重 | 得分 | 加权 |
|---|---|---|---|
| UI 工作台 | 45% | 60 | 27.00 |
| 模型侧工作台工具 | 8% | 10 | 0.80 |
| 会话隔离与布局持久化 | 12% | 35 | 4.20 |
| 插件生态服务 | 15% | 10 | 1.50 |
| 工程质量 & 测试 | 10% | 55 | 5.50 |
| 安全机制 | 5% | 25 | 1.25 |
| 产品交付形态 | 5% | 20 | 1.00 |
| **合计** | 100% | — | **≈ 41%** |

### 14.2 结论解读

- **33% / 41% 这两个数字要读出它的形状**：完成度的分布极不均匀——"内核主干 + 工作台主干"是 60 分水平，"规模化能力（compaction/护栏/计量）+ 生态 + 交付 + 纵深安全"接近 0 分。这不是匀速落后的曲线，而是"先立骨架、后长肌肉"策略的自然结果。
- **若把"端到端真实跑通一个 agent 工作流"作为门槛性加分**（聊天 → 流式 → 审批 → 工具 → 会话恢复 → 工作台全链路可用），总体愿景完成度可给到 **约 40%**——多数未完成项是"广度"而非"通路"。
- **重写策略本身的得失**：Genkit 换来了审批中断、会话存储、多 provider 的"开箱即得"（这三样自己写至少再花数周），代价是平台黑盒（取消不了 in-flight、拿不到 usage、快照丢 tool turn）——每一项平台短板都精确地变成了上表里的技术债。这个交换在原型期是划算的，进入打磨期后需要开始"绕开 Genkit"的局部自研（停止门就是第一个先例）。

---

## 十五、后续演进路线

结合差距量化，建议按"先堵正确性/安全性漏洞，再铺广度，最后做生态"排序：

**P0 — 正确性与安全止血（对标 dsh 不可妥协项）**
1. 修复会话恢复丢 tool turn（向"模型可见 ⟺ 已记录"不变量收敛，可考虑在 TurnEvent 落地时同步追加本地 JSONL 日志，把快照制升级为"快照 + 日志"双写）。
2. bash 工具沙箱化：macOS 上可用 `sandbox-exec`（Seatbelt profile）起步，对齐 dsh 沙箱族的最低配。
3. apiKey 迁入 macOS Keychain；guard 最小集（超时 + 工具调用频率上限）。
4. 建 CI（GitHub Actions：analyze + test + spike 重跑），把 317 个绿测试变成门禁而非纪念品。

**P1 — 把已有能力暴露给模型（低成本高收益）**
5. `terminal_*` 工具注入（PTY 已在，只差工具面）；`sidebar_open`（模型驱动 UI，对齐 better-sidebar）。
6. web fetch/search 工具（补上 agent 上网能力）。
7. token usage：绕开 `AgentOutput`，从 llm 流事件侧自行计量。

**P2 — 打磨层（对齐 better-sidebar 的"质感"）**
8. Mermaid 选型（flutter 社区方案 or 内嵌 WebView 渲染 mermaid.js）、PDF 预览、markdown 预览补 TOC。
9. 跨面板拖拽拆分/合并（split_node 纯函数已就绪，补交互层）。
10. 布局按会话隔离持久化；侧聊持久化与"保存为新会话"提升。

**P3 — 生态与交付（远期）**
11. 编译期生成的对外扩展点（`registerTab`/`registerFileViewer` 开放到 isolate 插件或注解驱动注册）。
12. dmg 打包 + 发布渠道；README/CHANGELOG 正式化；考虑 ACP/headless 形态。

每一步演进前重跑 `spike/agent_spike.dart`——这是这个仓库最值钱的自我约束，别丢。

---

## 十六、结语

这轮对标最有趣的结论不是"自研完成了 40%"，而是三个项目共同验证了一件事：**agent harness 的难点从来不是"把 agent 跑起来"（Genkit/LangChain 们已经把这部分商品化了），而是跑起来之后的一切——事件溯源的会话真相源、纵深防御的沙箱、可以承载生态的插件缝、以及敢对 63 个工具面做 per-file 100% 覆盖率门禁的工程纪律。**

agent_harness 用两个文件大小的"能力缝"证明了 dsh 的核心抽象可以跨技术栈存活，用逐行对齐的注释证明了 better-sidebar 的交互语义可以被忠实复刻；它欠下的债也非常典型——全是"跑通之后的一切"。这张账单本身，就是这次重写最有价值的产出。

---

*附注：本文所有百分比均为基于源码审读的工程功能完成度主观评估，评估口径见第二节；三个项目的代码以 2026-09-06 工作区快照为准。*
