# ADR-0061: 会话上下文压缩——摘要 + 新会话，摘要骑 ADR-0009 的注入通道

- **状态**: ACCEPTED
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 生产功能
- **日期**: 2026-10-04
- **来源**: kelivo 评估 §7 A2（kelivo `compressContext` 四模式 + 摘要模型回退链）+ ZCode 评估 B2（阈值/熔断/microcompact）。两份评估共同点名的硬缺口：长会话必然爆窗，现在只有 `read_window` 的工具读截断，会话级没有任何出路。
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

会话越跑越长，上下文只增不减：`AgentChat` 的历史无限累积，`read_window` 只截文件读，一个跑了几十步的会话最终会撞上模型的窗口上限，然后没有出路——用户只能开新会话从头再来。kelivo 的答案：`compressContext` = LLM 摘要 + 新对话（四种裁剪模式）；ZCode 的答案：阈值触发的自动 compact（真实 usage 覆盖估算 + 3 次失败熔断）。两者的共同内核是"**把对话蒸馏成一段摘要，让它成为新上下文的种子**"。

本仓库有一条现成的缝正好承载这件事：ADR-0009 的工作区指令注入。`_pendingInstructions` 在新会话/换工作区时排队、由下一次 send 拼进首条消息、被 `openSession` 清空——"上下文必须让模型知道，但不是用户说的话"正是这个通道的定义域。而且 ADR-0009 的守卫群已经处理了注入块的副作用（`_userWords()` 把注入块排除在标题与用户气泡之外）——一个新的注入块天然继承这些正确性。

## 决策（Decision）

**`/compress` 命令：摘要当前会话 → `startNewSession` → 摘要挂进新的 pending 槽，随新会话首条消息注入。手动优先，自动阈值留待 contextWindow 数据。**

1. **摘要骑 ADR-0009 的注入通道，但住独立的槽**：`_pendingSummary` 与 `_pendingInstructions` 并列。独立槽的三个生命周期点：`send()` 两者都排出（instructions 在前，摘要在其后，`@` 引用与用户的话贴在一起）；`startNewSession()` 清摘要（排队 instructions 之后）——压缩流程自己"先 startNewSession 再 set"，而用户压缩后改按 `+` 另起空白会话时，旧摘要不应跟着走；`openSession()` 清摘要——被点开的旧会话有自己的历史，吃掉一个属于续篇的摘要是第二个错误方向。ADR-0009 的 `isInjectedPart` 增加 `<conversation-summary>`，标题与用户气泡自动保持干净（既有守卫群覆盖）。
2. **摘要调用是独立的 `ai.generate`**（system 固定提示词 + `maxTurns: 1`，无工具）：它不是 agent 的一轮，不占 stop 门（用户不能中途停一次秒级的后台调用——代价明说）、不进 usage 台账、不进诊断日志（agent 中间件按 agent 的 `use` 列表挂载，直接 generate 不经过）。转录来源是控制器投影的用户+助手文本，纯函数 `compressionTranscriptOf` 组装（单条 800 / 总量 12000 字符封顶，kelivo 同量级）；工具调用不进摘要源是 S1 的边界——工具结果对"接着聊"的连续性贡献最小，却最容易把窗口撑爆。
3. **手动命令优先，自动阈值不做**：自动 compact 的阈值需要模型 contextWindow 数据（ZCode 口径：窗口 − 21K 输出 − 13K 缓冲），而本仓库的能力矩阵（ADR-0058 评估 B3）还没数据——没有真值的阈值就是猜测，与 ADR-0049 的"凭据点已经在回答"同理，宁可先给手动闸门。stats 行的 token 计数（`statsTokens`）已经回答"上下文有多满"。失败熔断（3 次）是自动化的口径，手动失败直接以 destructive 反馈条说出，不需要熔断器。
4. **UI 是 composer 的 `/compress` 命令**：与 `/new` 同一座菜单、同一套接线（命令菜单是会话级动词的既有家）；压缩期间命令不出现（`onCompress` 在 busy/compressing/空会话时传 null）。反馈走 ADR-0020 的反馈条：开始一条、终态一条（成功/失败）。
5. **明确不做**：keepRecent 克隆旧消息进新会话（依赖 fork 机制，本仓库没有）；microcompact（ZCode 的会话内裁剪，同样需要 contextWindow）；压缩结果的盘上留档（旧会话照常在侧栏，摘要本身没有二次消费场景——有读者才留档，ADR-0022 的律）。

## 后果（Consequences）

- **正面**：长会话第一次有出路；新会话的标题与首气泡不受摘要污染（ADR-0009 守卫群）；指令与摘要在同一道缝上，没有第二条注入通道需要守卫。
- **负面/风险**：
  1. 摘要调用本身有窗口上限——12000 字符的转录在 8K 窗口的模型上仍可能失败，反馈条如实说；剪得更碎是 S2 的事。
  2. 压缩到发送之间有一个"摘要只活在内存里"的窗口：用户压缩后立刻杀掉应用，摘要丢失（旧会话还在，重开重压即可）——落盘需要为没有读者的数据建文件，不做。
  3. send 的摘要拼装是本 ADR 唯一没有离线测试覆盖的缝（真 chat 才走得到），带 key 的真链走查是余项。
- **中性**：`TurnSource` +2 方法（`FakeTurnSource` 同步实现）；`locales.dart` +5 键 ×2；`instructions.dart` +1 标签常量 +1 块构建器。

## 验证（Verification）

- `test/context_compression_test.dart`：纯函数（封顶/跳过工具节点/空会话）；摘要块构建与 `isInjectedPart` 识别；控制器（守卫/成功流/失败流/isCompressing 开合；**反向验过**：短路 startNewSession 即红）；composer（/compress 出现与触发、callback 缺席时命令不存在；反向验过）。
- 四道门禁同口径；`dart run spike/runtime_smoke.dart` 离线路径不破。

## 关联（Links）

- 代码: `lib/genkit/agent_runtime.dart`（摘要调用 + 摘要槽 + send 拼装）、`lib/genkit/instructions.dart`（标签 + 块）、`lib/model/context_compression.dart`、`lib/state/conversation_controller.dart`、`lib/ui/conversation/composer.dart`、`lib/ui/conversation/conversation_root.dart`
- 关联 ADR: ADR-0009（注入通道与注入块判别）、ADR-0013（busy 期间命令不可用）、ADR-0020（反馈条）、ADR-0055（会话换届的唯一写法）
- 来源评估: `docs/kelivo-vs-agent-harness-2026-10.md` §7 A2
