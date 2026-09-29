# ADR-0016: 审批通过的工具结果从不进直播投影（rewind pill 因此不出现）

- **状态**: RESOLVED（2026-09-29 拍板并当日闭环：这是 ADR-0014 交付物的功能缺陷，不是新特性）
- **分类**: DEF
- **优先级**: P1
- **影响维度**: 生产功能（用户批准一次写入后，卡片永远转圈、回退 pill 不出现）
- **日期**: 2026-09-29
- **修复 commit**: `815814e`（`send()` 守卫）· `ebcdd45`（快照补投影）· `7712df1`（冒烟脚本改成会应答审批并断言捕获）
- **来源**: 第一次带 key 真跑 `dart run spike/runtime_smoke.dart`（ADR-0015 恢复的那道门）。它存在的意义就是证这种话：**离线全绿、`flutter test` 全绿，也看不见这条。**

## 背景（Evidence）

**现象**：带 key 的冒烟里，两个被审批的工具都在"批准"之后**没有** `ToolCallSucceeded`：

```
  tool -> bash({command: ls -la, …}) [ref=call_00_Yv731A9pg1m2W30mZhfS3758]
  APPROVAL needed: bash …
  finished: awaitingApproval
  --> approving call_00_Yv731A9pg1m2W30mZhfS3758 (bash)
  tool <- ok [ref=call_00_1E77AlHOPrQkZkWe3gXz3508] {path: hello.txt, …}   ← 这是 resume 之后**新发起**的 read
  …
  --> approving call_00_MSpUJJ6mIr0aX6TBG0cM6623 (edit)
  checkpoint r0: notes.md modified (21 bytes -> 51 bytes)                    ← 镜像截到了
  text[0] Appended to `notes.md`:                                            ← 直接跳到模型正文，edit 自己没有结果事件
```

而**同一轮从盘上恢复**时，两个 ref 都是有结果的：

```
  m3-call_00_Yv731A9…  tool bash [succeeded] {output: total 16 …}
  m11-call_00_MSpUJJ6… tool edit [succeeded] {ok: true, path: notes.md, replacements: 1, checkpoint: r0}
```

**根因在 genkit 侧，且是设计如此。** `resumeStream(restart: …)` 走 `generate.dart` 的 `coreGenerate`：被重启的工具由 `_executeTools`（`genkit-0.16.1/lib/src/ai/generate.dart:521-527`）直接执行，输出被折进 `respond`（`:546-560`）当作**下一次模型调用的输入**，全程没有 `c.sendChunk(...)`。而 `agent.dart` 只在两处发 chunk：模型自己的 chunk（`genkit-0.16.1/lib/src/ai/agents/agent.dart:1566-1570`）与中断时**重发 tool request**（`:1584-1596`）——**tool response 从来不成 chunk**。我们的投影只认 `modelChunk?.content` 里的 response（`lib/genkit/agent_runtime.dart:1209-1215`），所以拿不到它不是投影写错了，而是那条流里根本没有。

**为什么这不是"只是日志少一行"。** 两处消费都靠这个事件：
1. `ConversationController.respondToApproval` 在按钮按下时把节点置成 `ToolStatus.running`（`lib/state/conversation_controller.dart:326-332`），只有 `_settleTool`（由 `ToolCallSucceeded`/`Failed` 驱动）会把它落成终态。**批准一次写入，卡片永久转圈**，直到重开会话。
2. ADR-0014 的回退入口整个挂在这个事件上：`_ToolRowModel.checkpointId = _checkpointOf(node.output)`（`lib/ui/tool/tool_card.dart:551-552`），pill 只在 `checkpoint != null` 时出现。镜像**确实已经落盘**（上面那行 `checkpoint r0` 就是证据），但 output 进不了节点，所以**pill  live 不出现，重开会话才出现**。S3 的验收里"写完就能就地回退"这一条，在真链路上是不成立的。

**顺带第二条缺陷（同一次运行暴露）**：`AgentRuntime.send()` 只挡 `_turn != null`（`:1040`），审批暂停时 `_turn` 已清空而 `_pendingInterrupts` 非空，此时发新消息等于**在一条没有回复的 tool request 上追加历史**，provider 直接 400，被 `catch (e)` 变成一句 `Converting object to an encodable object failed: Instance of 'BadRequestException'`。app 里 `isInputBlocked = _isBusy || _pendingApproval != null`（`conversation_controller.dart:78`）与 `_drain` 的 `!isInputBlocked`（`:302`）把它挡住了，所以**只有绕过控制器的调用者会踩**——而那个调用者就是冒烟脚本本身。

## 决策（Decision）

**在运行时补上投影，不去改控制器、也不在 UI 里猜。** 具体是在 `_drive` 收尾处（`turn.response` 已 resolve、`TurnFinished` 之前），为"本轮被批准、但流里没出现结果"的那个 ref，从 `_agent.getSnapshot(snapshotId: response.snapshotId)` 的 `messages` 里把 `toolResponse` 找出来，按既有的 `_toolResult(ref, output)` 发一次事件。四条理由：

- **只有一个地方需要知道这件事**。投影是 runtime 的职责；让 controller 在 `_consume` 结束后自己补状态，等于把"genkit 不流 response"这条知识复制到第二个文件，而工具卡片、用量统计、`_settleTool` 的终态判定都得跟着改。
- **终态与 output 必须同源**。分开补（状态一处、output 一处）就是 ADR-0012 反对的那种分叉。走 `_toolResult` 意味着 `{ok: false}` 约定照旧生效。
- **快照是唯一真值，而且它已经是重开时的那一份**。`AgentChat.messages` 只有模型消息（见验证段），工具响应在 server 侧快照里；`openSession` 走的 `loadChat` 读的也是它。取这一份，等于"live 看到的"与"重开看到的"由同一次读取定义，不可能各说一套。
- **decline 路径不动**。它已经在决策时被置成 `denied`，`_settleTool` 明确保留 `denied`；补一个 `respond` 的 response 事件只会把"你拒绝了"改写成一条普通失败，是信息降级。所以补投影**只针对 approve（restart）**。

`send()` 的守卫放在 runtime：一句明确的 `An approval is still waiting for your answer.`，替掉那句 provider 的 400 乱码。控制器已经挡住了自己的路径，这条是给**所有**调用者的（冒烟脚本就是证据）。它必须放在 `send()` 而不是 `_drive()`：`respondToApproval` 先 `_pendingInterrupts.remove(ref)` 再进 `_drive`（`:1011-1012`），多个中断时逐个应答要能继续走。

## 后果（Consequences）

- **正面**：批准后卡片落到终态；ADR-0014 的 pill 在写入当轮就出现，"我先让它试、不行就退回"这条工作流第一次在真链路上成立；`send()` 的误用从"看不懂的 400"变成一句人话。
- **负面/风险**：补出来的事件是**从历史重建**的，不是实时流里的——所以它一定晚于模型对同一轮的正文输出？不会：`_drive` 在流结束后、`TurnFinished` 之前发，而卡片按 ref 定位节点，顺序只影响打印观感不影响状态。另一个诚实代价：如果同一 ref 在历史里出现两次（理论上不该发生，ref 每次调用唯一），取第一条。
- **中性**：`_drive` 多一个 `{String? resumedRef}` 参数与一个 `settled` 集合；`spike/runtime_smoke.dart` 从此**断言**这件事（`surfaced`），并且它现在会 `exitCode = 1`——注意别再用 `… | tail` 判断成败，管道会吞掉退出码。

## 验证（Verification）

- **带 key 的真链**（本 ADR 的主证据，也是它的回归门）：`DEEPSEEK_API_KEY=… dart run spike/runtime_smoke.dart`。
  - 修之前：`EXIT=1`，`!!: the tool result carried checkpoint id r0 back to the caller`，批准 bash/edit 之后两条 ref 都没有 `tool <- ok`。
  - 修之后：`EXIT=0`，同一位置变成 `ok: the tool result carried checkpoint id r0 back to the caller`，并且两条 ref 各自带回了真实结果：
    ```
    --> approving call_00_AptByeyWz1tChwqlp0a75295 (bash)
    tool <- ok [ref=call_00_AptByeyWz1tChwqlp0a75295] {output: total 16 …}
    --> approving call_00_zOJDolayWuoDx6MC3Bxk1358 (edit)
    checkpoint r0: notes.md modified (21 bytes -> 49 bytes)
    tool <- ok [ref=call_00_zOJDolayWuoDx6MC3Bxk1358] {ok: true, path: notes.md, replacements: 1, checkpoint: r0}
    ```
  - **实施过程中被证伪的第一版方案**：先按"`_chat.messages` 里有 response"写，实测 `historyRefs=[]`——`AgentChat._applyOutput`（`agent_core.dart:686-690`）只在有 client 侧 state 时整体替换，否则只 `_messages.add(raw.message)`，即**只累积模型消息**。工具响应在 server 侧快照里。所以取数处改成 `_agent.getSnapshot(snapshotId:)` → `AgentSnapshot.messages`（`agent_core.dart:494`，正是 `openSession` 的 `loadChat` 读的同一份），这也顺带保证了 live 卡片与重开后的卡片同源。
- `flutter test`：投影这段依赖真实 genkit resume，离线无法构造（`AgentChat` 由 `_agent.chat()` 现场创建，快照要真跑一轮才有），因此**没有**新增 `flutter test`；守它的就是上面那条带 key 的冒烟。这是现状的诚实记录，不要假装有一道离线门。
- 门禁同口径：format / `--fatal-infos` analyze / `check_architecture` / `flutter test` 相对基线（`+814 -2`）零新增失败。
- 人工走查（macOS debug 包已构建成功）：让 agent 改一个已存在的文件 → 批准 → **不重开会话**，卡片应显示成功且 pill 立刻出现；点 pill 应能看到预览与报告。
- 判断成败**不要**用 `dart run … | tail`：管道会把退出码换成 `tail` 的，第一次运行就是这样被误读成通过的。用 `> file 2>&1; echo EXIT=$?`。

## 关联（Links）

- 证据: `~/.pub-cache/hosted/pub.dev/genkit-0.16.1/lib/src/ai/generate.dart:521-527,546-560`、`.../agents/agent.dart:1566-1570,1584-1596`、`.../agents/agent_core.dart:631,1006-1014`
- 代码: `lib/genkit/agent_runtime.dart:1011-1029,1040-1046,1070-1157,1209-1231`、`lib/state/conversation_controller.dart:78,302,326-341`、`lib/ui/tool/tool_card.dart:159,551-552,558`、`spike/runtime_smoke.dart`
- 关联 ADR: ADR-0014（S3 的 pill 依赖本事件，"写完就地回退"此前只在重开会话后成立）· ADR-0015（正是它恢复了这道带 key 的门，本缺陷才被看见）· ADR-0012（`decideGate` 与"必须同源"的同一律：状态与 output 不能分两处补）
