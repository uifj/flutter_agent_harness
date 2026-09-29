# ADR-0009: 工作区指令注入（AGENTS.md → 上下文消息）

- **状态**: IN-PROGRESS（2026-09-29 由 ACCEPTED 推进：注入实现已合入 develop，见下方修复 commit；余「带 key 的真实链路确认」）
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 认知障碍 / 上下文膨胀 / 生产功能
- **日期**: 2026-09-29
- **修复 commit**: 9019f3c（注入实现与单测）
- **来源**: `docs/zcode-vs-agent-harness-2026-09.md` §7 A2（移植路线图第一步，标 ★）

## 背景（Context）

harness 交给模型的系统提示只有一个编译期常量：

- `lib/genkit/agent_runtime.dart:45` 的 `_systemPrompt` 在 `AgentRuntime.create()` 里一次性写进 `ai.defineAgent(system: …)`（同文件 `:~1150`）。
- 该常量原本还硬写着 `running on the user's Mac`，与本仓库三个桌面目标（ADR-0003；`macos/`+`windows/`+`linux/` 目录俱在）直接矛盾——在 Windows/Linux 上跑时，模型被告知自己在 macOS 上。

结果是：**工作区自己的 `AGENTS.md` 从未到达模型**。本仓库为 AI 代理写了 `AGENTS.md` + `.qoder/rules/*`（约 400 行约定），但我们自己的 agent 在同一个工作区里问不到任何一条。用户只能把它们复制粘贴进输入框。

约束（决定了不能"简单地把文件拼进 system"）：

1. `AgentRuntime` 定义 agent 一次（`_agent` 是 final 字段），换工作区走的是 setter：`workspaceRoot` → `_tools.workspace = Workspace.of(path)`（`agent_runtime.dart:732`），运行时对象不重建。系统提示因此是"每个 runtime 一份"，不是"每个工作区一份"。
2. 第一条不变量要求 genkit 只活在 `lib/genkit/`（`workflow.md` §0），发现/合并逻辑必须是纯 Dart 才能用真实临时目录做单测。
3. 会话可持久化与恢复（`FileSessionStore`），恢复的会话历史里已经带着当初注入的那条消息——重复注入等于同一份工作区约定在上下文里出现两次。

ZCode 侧对应的做法（`docs/zcode-vs-agent-harness-2026-09.md` §4）是把指令作为 **meta_user 上下文消息**注入，而不是改写 system。本 ADR 采纳同一形态。

## 决策（Decision）

新增 `lib/genkit/instructions.dart`（纯 Dart，无 `package:genkit` import，与 `read_window.dart`/`file_search.dart` 同一安排），在 `AgentRuntime` 里以"排队—排空"的方式注入：

- **发现规则**：用户级 `<home>/.agent_harness/AGENTS.md` 在最前；随后从文件系统根向下走到工作区，每级认 `AGENTS.md` 与 `.agents/AGENTS.md` ——离工作区最近的一份最后被读到。向上搜索、不向下搜索：嵌套目录里子项目的 `AGENTS.md` 是模型该用 `read` 工具去找的东西，不该被抬进每次请求。
- **去重**：路径 canonicalize 后入集合，工作区恰好包含用户级文件时只读一次。
- **符号链接逃逸拒绝**：工作区*内部*的指令文件若 resolve 到工作区之外则跳过（clone 来的仓库里埋一个软链，不能把无关文件送进模型上下文）；工作区*祖先*目录的文件是用户自己放的，按原位读取。
- **字节预算**：单文件 8 KiB、总计 24 KiB，在码点边界截断，并在块内明说"已截断"——不让静默丢内容冒充完整规则。
- **注入形态**：`send()` 把块作为第一个 `TextPart` 挂在用户消息前（与已有的 `@path` 引用、图片附件同一条消息），**不进系统提示**；纯文本发送仍走 `chat.sendStream(text:)` 快路径。
- **时机**：`workspaceRoot` setter 与 `startNewSession()` 重新排队；`openSession()` 清空（恢复的历史里已有）；`send()` 取走并置空，因此一份工作区约定只发一次。
- 顺带把 `_systemPrompt` 的 "on the user's Mac" 改为 "on the user's desktop"。

候选方案与取舍：
- *把指令拼进 `system`*：需要每个工作区重建 agent（`_agent` 是 final，重建会丢 `_chat` 与会话指针），且恢复会话时系统提示已变，历史与新提示不一致。否决。
- *只用 `homeRoot`/`workspaceRoot` 两处、不做向上链*：省掉规则，但 monorepo 与"项目上一级放共享约定"两种常见布局直接失效。否决。
- *向上搜索并一律接受 symlink*：安全面变大。折中为"内部拒绝、祖先放行"。

## 后果（Consequences）

- **正面**：工作区约定第一次成为 agent 的真实输入；换文件夹自动换约定；`AGENTS.md` 过长不再能吃掉上下文窗口；系统提示的平台谎言消失。
- **负面/风险**：每条会话首消息变长（上限 24 KiB 文本）；模型可能把注入块当"用户说的话"复述出来（块首已写明这是文件内容与优先级规则）；向上搜索会读到工作区之外的父目录文件——这是有意行为，与 Claude Code / ZCode 一致，但用户若不希望如此，把无关 `AGENTS.md` 移出父目录即可。
- **中性**：注入逻辑落在 `lib/genkit/`，符合第一条不变量；`instructions.dart` 不 import genkit，故单测可脱离运行时跑。记忆文件（读写 `<home>/.agent_harness/memory/`）**不在本 ADR 范围**，留作后续。

## 验证（Verification）

```
flutter test test/instructions_test.dart        # 11 例：优先级/向上链/嵌套不注入/去重/逃逸拒绝/软链目录可读/码点截断/总预算截断链/无 home/渲染块
dart analyze --fatal-infos lib test tool spike  # 0 issue
dart format --set-exit-if-changed lib test tool spike
flutter test                                    # 相对基线零新增失败
```

注入这条边（`send()` 取走队列、恢复会话不重复注入）由代码路径 + `spike/runtime_smoke.dart` 的真实链路（带 `DEEPSEEK_API_KEY`：首消息 → 会话落盘 → 恢复）确认；**离线门禁只证发现逻辑，不证模型实际收到该块**。

## 关联（Links）

- 代码: `lib/genkit/instructions.dart`（新增）、`lib/genkit/agent_runtime.dart#L34,L45,L730-L751,L798-L822,L1106-L1124`
- 测试: `test/instructions_test.dart`
- 来源评估: `docs/zcode-vs-agent-harness-2026-09.md` §4 运行时上下文、§7 A2、§9 第一步
- 关联 ADR: ADR-0003（三桌面目标——本次修掉与之矛盾的平台硬编码）
