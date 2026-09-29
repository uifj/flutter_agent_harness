# ADR-0012: 工具契约与审批规则（A3 + A1）

- **状态**: IN-PROGRESS（2026-09-29：S1 与 S2 的代码、测试、设置页撤销入口均已合入；余"带 API key 的真实链路确认免问生效"）
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 生产功能 / 安全合规
- **日期**: 2026-09-29
- **修复 commit**: b51ad6a（规则模型）· bca42ce（门禁与存储）· 15a0ae6（面板与设置页撤销入口）
- **来源**: `docs/zcode-vs-agent-harness-2026-09.md` §7 A1 + A3（§9 第 2 步的前两件；评估文档明写"与 A1 可合并"）

## 背景（Context）

**审批是逐个工具硬编码的。** `lib/genkit/tools.dart` 里 `write`/`edit`/`bash` 三处各自写一遍门禁（`:216-227`、`:329` 附近、`:589` 附近）：

```
if (context.resumed == null) { final refusal = gateRefusal(); … if (shouldInterrupt) return ToolResult.interrupt({…}); }
```

判定只有三个输入：`ApprovalMode`（ask/plan/auto，`lib/model/approval_mode.dart:19`）、是否已 resumed、工具名。也就是说 **ask 模式下每一次写/改/shell 都要点一次"允许"**，同一轮里 `git status` 这种只读命令也要点。`docs/debt-register.md` 与评估文档 §9 第 2 步把"每次都要点批准"列为本项目最真实的痛点之一。

**"只读"这件事在本仓库有两份真值。** `lib/genkit/agent_runtime.dart:117` 硬写着 `const _subagentTools = {'read', 'glob', 'grep'}`，注释说"everything read-only"；而真正决定某工具是否只读的是它在 `tools.dart` 里有没有调 `gateRefusal()`。加一个只读工具（例如 `ls`）时，`define()` 里注册了它，但委托目标看不见它——两处列表靠人同步，正是 ADR-0011 那条"文档规则会腐烂"的同一形态。

**MCP 侧同理。** `_ToolGate.tool()`（`agent_runtime.dart:347-392`）对外部工具只看名字里有没有 `/`，ask 模式一律 interrupt，没有任何规则可记；而外部工具恰是最该按 server/tool 记住选择的一类。

**为什么不是小改。** 规则一旦能自动放行，判定就从"每调用必问"变成"命中规则不问"，这是安全语义的改变：必须回答"规则匹配什么字符串""谁写的规则算数""deny 能不能被 allow 覆盖"。ZCode 的对应设计（评估文档 §4）是规则主体分 command/url/file_path/pattern、`allowOnce/always/deny/denyAlways` 四态、会话内存与项目落盘两级，且有一条 `alwaysAsk` 不可被规则绕过。

## 决策（Decision）

分两阶段，S1 是 S2 的输入。

### S1（A3）工具契约，一处声明两处消费

在 `tools.dart` 的 `WorkspaceTools` 上，**在注册工具的那处**声明契约，不在每个 builder 里散着写：

```dart
/// 只读工具的名字：决定它要不要过审批门，也决定委托目标能不能用它。
static const readOnlyToolNames = {'read', 'glob', 'grep'};
static bool isReadOnly(String name) => readOnlyToolNames.contains(name);
```

- 消费方一：`agent_runtime` **删掉** `const _subagentTools`，委托目标的工具集改为 `WorkspaceTools.isReadOnly(tool.name)` 派生（原来两处列表靠人同步）。
- 消费方二：S2 的门禁判定。可写工具的"要不要问"不再是每个 builder 自己记着调 `gateRefusal()`，而是共用 `decideGate`。
- **没做的部分要说清**：提案里的 `gatedNames`（"全集减只读集"）在实施中被去掉——`tools.dart` 的 `define()` 已经枚举了全部工具，再造一个派生集没有消费者。`destructive` / `concurrentSafe` / `maxOutputBytes` / `timeoutMs` / `sideEffectScope` 同样**不引入**：本仓库工具串行执行、输出上限已在 `read_window.dart`/`shell_run.dart` 各自落地、副作用范围由审批表达。等出现真实消费者（并发工具执行、B1 checkpoint 的 before/after 采集）再随各自 ADR 一起加。

### S2（A1）审批规则

- **模型**（纯 Dart，`lib/model/approval_rule.dart`，手写 `toJson`/`fromJson`）：
  `ApprovalSubjectKind { command, filePath, tool }`；`ApprovalOutcome { allow, deny }`；
  `ApprovalRule { kind, value, outcome, sessionOnly }`，`matches(subject)` 支持**精确匹配**与**尾随 `*` 前缀匹配**（`git *` 允许、`* rm` 不允许——模式只能右端通配，因为左端通配等于"任何包含 rm 的命令"，那是最容易写错的一类规则）。
- **优先级：deny 恒压 allow。** 命中任一 deny 即拒，不问也不放行。这条顺序让"加一条 allow"永远不会意外撤销已有 deny。
- **一级作用域：按工作区落盘的持久规则**（`<support>/approvals.json`，键为工作区根路径）。
  提案里写的"会话内存 + 项目落盘"两级在实施时**砍掉了会话级**：面板上没有"仅本次会话免问"的按钮，而一个没有创建者的作用域就是一段永不执行的分支。会话级留到真有对应交互（例如设置页的"本会话暂停所有规则"）再随该需求引入。
  **也刻意不做 ZCode 的"写进项目文件"**：往用户工作区落一个 `approvals.json` 需要 security-scoped bookmark 之外的新写入面（`host/project_folder_ops.dart` 是 macOS 专属，非 macOS 无持久授权，见 `build.md` §2B），且克隆来的仓库可能自带一个"批准一切"的文件——那是把审批决定权交给仓库内容。
- **判定顺序抽成一个纯函数** `decideGate({mode, subject, decided, modeRefusal})`（`lib/genkit/tools.dart`）：`plan` 先拒 → deny 规则带理由拒 → allow 规则放行 → 非 ask 放行 → 否则 interrupt。
  本地三个可写工具与 MCP 外部工具中间件（`agent_runtime.dart` 的 `_ToolGate`）**共用这一个顺序**，否则"外部工具"可以绕开用户以为自己全局生效的规则。策略是纯的，所以不依赖 API key 也能测（`test/tool_gate_test.dart`）。
- **规则的 subject 就是面板刚显示的那串**：`ws.relative(path)` / 命令原文 / `server/tool`，由 `ApprovalRequest.ruleFor()` 从 interrupt payload 反推（`lib/model/conversation.dart`）。用户批准什么就记住什么，不重新拼一遍。
- **UI**：审批面板 `[拒绝] [总是允许] [本次允许]`；只有 `ruleFor()` 能命名 subject 的调用才出现中间那颗按钮。`ConversationController.respondToApproval(approved, {remember})` 在 resume **之前**写入规则，因此同一轮里下一个同类调用已经免问。
- **撤销入口做进设置页**：新的 `approvals` 节列出当前文件夹的规则，每行一个"移除"，外加"移除当前文件夹的全部规则"。一颗只能往上加、不能往下减的免问按钮不是权限，是隐藏后门。**不做快捷菜单那一格**：ADR-0006 的双入口律管的是偏好开关，这里是一份可删除的清单，不是同一类控件。
- **拒绝的持久化（deny 规则）暂不在 UI 里创建**：模型与门禁都支持，面板只提供 allow。理由是"总是拒绝"同样需要一个看得见、可撤销的清单才成立，而那个清单已经在了——留一个没有入口的按钮不如留一个有文档的缺口。
- **不做 `alwaysAsk`**：本阶段没有任何工具被标记为 alwaysAsk，加了就是永不触发的分支。它真正的用武之地是"允许用户在设置里把某类调用钉成必问"，那需要同时接设置页与快捷菜单两个入口（ADR-0006 的双入口律），随那条需求一起来。

## 后果（Consequences）

- **正面**：只读工具与审批门禁的关系从两处硬编码变成一处声明；用户可以为反复出现的同一写/同一命令免掉后续提示；deny 不可被 allow 撤销；规则按工作区隔离，换个文件夹不继承上一个文件夹的批准；本地与外部工具走同一个判定顺序。
- **负面/风险**：`git *` 这类前缀规则的粒度是命令词首，不是语义（`git push --force` 会命中 `git *`）——缓解是"总是允许"只针对**当前这一次调用的确切 subject**（面板不给通配符选项，通配只能手写进文件），且设置页每行都能移除。deny 规则被门禁支持但面板暂无创建入口（见决策最后一条）。会话级作用域被砍，将来要加得先加它的交互。
- **中性**：`ApprovalMode` 的三态语义不变，规则只是 ask 模式内部的"是否还需要问"；MCP 外部工具第一次有了可记忆的批准粒度；`lib/model/` 多了一个纯 Dart 模型、`lib/state/` 多了一个 store，`_subagentTools` 这个常量消失。

## 验证（Verification）

```
flutter test test/approval_rule_test.dart   # 匹配（精确/仅右端通配）、deny 压 allow、同 subject 覆盖、序列化往返、未知 kind 抛错、ruleFor 从 payload 反推 subject
flutter test test/approval_rule_store_test.dart  # 按工作区分键、重开读回、forget/forgetWorkspace、坏文件与坏行、tmp 不残留
flutter test test/tool_gate_test.dart       # 判定顺序 5 例（含 plan 优先于 allow、deny 优先于 auto）+ 只读声明
flutter test test/approval_panel_test.dart  # 三颗按钮各自回传什么、答过一次后其余失效、无 subject 时不给"总是允许"
dart tool/check_architecture.dart           # 新文件不得引入 lib/state→lib/ui 等违规
dart analyze --fatal-infos lib test tool spike && flutter test   # 实测 +760 -2，与基线同样只有那两条既有失败
```

带 `DEEPSEEK_API_KEY` 的真实链路（同一写命令第二次不再 interrupt、设置页移除规则后又开始问）由 `spike/runtime_smoke.dart` 的审批往返段确认；**离线门禁只证判定顺序与存储，不证模型侧真的免问了**——交付说明标"待带 key 确认"。

## 关联（Links）

- 代码: `lib/genkit/tools.dart`、`lib/genkit/agent_runtime.dart`、`lib/model/approval_rule.dart`、`lib/state/approval_rule_store.dart`、`lib/state/conversation_controller.dart`、`lib/ui/conversation/approval_panel.dart`
- 测试: `test/approval_rule_test.dart`、`test/approval_rule_store_test.dart`
- 来源评估: `docs/zcode-vs-agent-harness-2026-09.md` §4 权限、§7 A1/A3、§9 第 2 步
- 关联 ADR: ADR-0009（同一 runtime 生命周期钩子：`startNewSession()` 清会话规则）、ADR-0011（新文件受架构门禁约束）、ADR-0006（撤销入口若做进设置页要双入口接线）
