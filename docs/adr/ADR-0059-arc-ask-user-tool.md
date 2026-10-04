# ADR-0059: ask_user 工具——模型停下来向用户提问，答案作为工具结果回去

- **状态**: ACCEPTED
- **分类**: ARC（工具契约 + 交互面）
- **优先级**: P1
- **影响维度**: 生产功能
- **日期**: 2026-10-04
- **来源**: `docs/kelivo-vs-agent-harness-2026-10.md` §7 A1（kelivo `ask_user_input_v0`，`_archive_project/kelivo` `local_tools_service.dart:19,723-765`、`ask_user_interaction_service.dart:129-268`）与 ZCode 评估 §4（AskUserQuestion 缺口）——两份评估共同点名的缺口
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

模型在跑一件需要用户决定的事时，现在的唯一手段是**把问题写成正文然后停下**：用户下一句话作为新输入进来，模型凭记忆把那句话当成答案——没有结构、没有"这轮在等谁"的任何表达（观察表"会话行右槽"那行记过同一缺口），更没有"答案是这次工具调用的结果"这回事。kelivo 证明了这在 Flutter 侧可以做得很薄：工具调用即挂起，UI 渲染选择题，回答以 `ask_user_answer` 回填继续。

本仓库的中断脊线已经齐备且被真链验证过（ADR-0012，`spike/runtime_smoke.dart` 实测 interrupt→resume）：工具 `ToolResult.interrupt(payload)` → 运行时 `_pendingInterrupts[ref]` + `ApprovalRequired(details)` 事件 → 面板占住 composer 座位 → `respondToApproval` 走 `chat.resumeStream`。ask_user 的每一块都已有先例，缺的只是把它们接成一个新语义。

## 决策（Decision）

**新增主 agent 工具 `ask_user`：无条件 interrupt，回答经 respond 路径作为工具结果回填。**

1. **它不走 `decideGate`，而且这是对"审批判定只有一个函数"律的边界说明而非违反**：门禁回答的是"这个副作用可不可以发生"——mode 与免问规则**可以替用户回答**；ask_user 问的是"只有用户知道的信息"，任何 mode（含 `auto`）都无权替答。所以它不经过门，工具自身无条件 `ToolResult.interrupt`。律没有被绕过——它根本不适用于这类工具；这条边界写在这里，下一个想"给 ask_user 也加免问规则"的人先读到。
2. **恢复走 `respond` 不走 `restart`**：答案本身就是这次调用的结果（`{'ok': true, 'answers': [...]}`），genkit 把它折进下一请求；工具不重跑——重跑无事可做，interrupt 就是它的全部行为。运行时新增 `respondToAskUser({ref, answers})` 与 `respondToApproval` 平行；被应答的卡片结果由运行时直接 yield `_toolResult(ref, answers)`（respond 路径没有 restart 输出可从快照恢复，ADR-0016 的恢复机制不适用）。
3. **形状**（kelivo 的收窄版）：输入 `questions: 1–4` 条，每条 `{question: string, options: string[0–4], multi: bool}`——`options` 空 = 开放题；`multi` = 多选。答案 `{'ok': true, 'answers': [{question, values[], custom?, skipped}]}`。Other 恒可用（自定义文本），Skip 按条。kelivo 的 UI 自动附加 Other/Skip，我们同形。
4. **UI**：新 `AskUserPanel`，与 `ApprovalPanel` 共享 composer 座位——`conversation_root.dart` 已按 `pendingApproval` 切换面板占位，加一个 `details['kind'] == 'ask_user'` 分支。不进 `tool_card`：卡片是结果投影，问题卡是交互面（审批面板先例同）。提交前每题必须"有值或已跳过"。
5. **作用域 = 主 agent only**：side agent 无工具表、子 agent 委托只带 `readOnlyToolNames` 白名单（`isReadOnly` 不含它），两个从动面天然够不着——悬空中断（从动面 yield `ApprovalRequired` 而其控制器无人应答）不会发生。
6. **明确不做**：问题超时/倒计时（kelivo 有 snooze，我们的会话没有时钟语义）；跨会话缓存的"问过的问题"；把答案落盘为免问规则（答案是一次性的，规则是持久判断——两者不是一件事）；`phone_control` 类设备问询（kelivo 移动特有）。

## 后果（Consequences）

- **正面**：模型第一次有了结构化问询通道——选择题替模型猜，替用户省一句自由文本；"这轮在等用户"第一次有了机器可读的表达（`ApprovalRequired` + kind），会话行"在等你"徽标（观察表那行）从此有了数据源。
- **负面/风险**：
  1. 模型可能滥用提问把决定推给用户——靠工具 description 约束（"只在真的需要用户决定/只有用户知道时使用"），不加硬限制。
  2. 无人值守场景（将来定时任务）遇 ask_user 会悬挂——kelivo 的答案是显式判 `user_interaction_required` 失败；我们尚无无人值守执行者，此项留给 B7（定时任务）落地时处理。
- **中性**：`TurnSource` 接口 +1 方法（`FakeTurnSource` 同步实现）；`locales.dart` +5 键 ×2。

## 验证（Verification）

- `test/ask_user_test.dart`：输入校验纯函数（条数/选项数/必填边界）；`AskUserQuestion` 从 interrupt details 解析（畸形 details 不抛）；答案 payload 往返。
- 控制器测试（`FakeTurnSource`）：`ApprovalRequired(kind: ask_user)` → 面板提交 → `respondToAskUser` 清 pending、替身收到答案、卡片经 `_toolResult` 翻成 succeeded；反向验过：把清 pending 短路即红。
- Widget 测试：单选/多选/Other/Skip 四种作答路径 + 未答完提交被禁用；反向验过。
- 四道门禁同口径。

## 关联（Links）

- 代码: `lib/genkit/tools.dart`（`_askUser` + 校验）、`lib/genkit/agent_runtime.dart`（`respondToAskUser`）、`lib/model/ask_user.dart`、`lib/state/conversation_controller.dart`、`lib/ui/conversation/ask_user_panel.dart`
- 关联 ADR: ADR-0012（中断脊线与审批面板先例）、ADR-0013（忙时输入与 `isInputBlocked` 的关系——问题待答期间 `send` 照旧被挡）、ADR-0016（restart 输出恢复；本 ADR 走 respond 故不适用）
- 来源评估: `docs/kelivo-vs-agent-harness-2026-10.md` §7 A1
