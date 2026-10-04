# ADR-0064: 工作区环境变量与面向模型的输出脱敏

- **状态**: ACCEPTED
- **分类**: SEC
- **优先级**: P2
- **影响维度**: 安全合规 / 生产功能
- **日期**: 2026-10-04
- **来源**: kelivo 评估 §7 B2（kelivo：环境变量全局共享 + privacyMode 下把值从回给模型的工具文本中替换为 `[REDACTED]`，`environment_output_redactor.dart:11-76`）
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

模型 经常需要一把凭据去调 API（CI token、第三方 key），现在唯一的路是把明文写进对话或写进文件——两者都落进转录与快照。kelivo 的形状：用户维护一组键值，shell 执行时并入进程环境，模型用 `$NAME` 引用；**值不进提示词**，且 privacyMode 下把值从回给模型的工具输出里抹掉。

## 决策（Decision）

**键值对：名字持久化、值进 keychain；注入只发生在进程环境；脱敏只作用于回给模型的工具文本。**

1. **存储分层**（ADR-0045 PF 的 savedProviders 同形）：名字列表进 `<support>/environment.json`（名字不是秘密），值进经典 keychain 槽位 `environment:<name>`（`SecureSecretStore`，ADR-0049 的接缝语义原样适用）。**不进备份**——值与机器绑定，与 provider key 同口径。
2. **注入**：`shellRun` 增加可选 `extraEnvironment`，并入 `Process.start(environment:)`（`includeParentEnvironment: true` 保持——PATH 是工具链可达性的一半）。提示词只告诉模型"值已注入环境，用 `$NAME` 引用"（在 bash 工具 description 中），值永不进提示词。S1 只注入 shell；MCP stdio 的 env 并入留给 S2（我们的 MCP host 经 genkit_mcp 建，环境注入受包参数面限制）。
3. **脱敏**：纯函数 `redactToolOutput(text, secrets)`——长度 ≥5 的值（过短的值无法可靠替换，kelivo 同界）按长度降序拼字面替换，作用于 `bash` 工具结果回给模型的 `output` 字段；UI（工具卡、详情栏）读**同一份已脱敏文本**——屏幕上出现明文就等于转录里出现明文，脱敏必须发生在进投影之前。S1 范围 = bash 的 stdout/stderr；`write`/`edit` 的 diff 不脱敏（模型写的值模型本来就知道）。
4. **名字校验**：`[A-Za-z_][A-Za-z0-9_]*`——进程环境的键必须可注入；重复名更新值。
5. **接线**：`WorkspaceTools` 增可选 `environmentLoader`（`Future<Map<String,String>> Function()`，组合根闭包读 store；`DiagnosticHooks` 同款缝，运行时不碰 state）。空 map = 无环境变量，工具行为与今天逐字节相同。
6. **明确不做**：MCP stdio env（S2）、非 bash 工具的注入（无意义）、脱敏审计日志、把值同步进备份（见 1）。

## 后果（Consequences）

- **正面**：凭据第一次有"不落转录"的通道；脱敏让"命令回显变量值"不再等于"值进了快照与摘要"。
- **负面/风险**：脱敏是字面匹配——拼接构造（`echo $TOKEN | base64`）天然绕过；这是已知边界，保密级别高的值不该交给任何 agent。keychain 拒绝时 store 置 error（ADR-0049 语义），写入侧把值留在内存直到成功。
- **中性**：`WorkspaceTools`/`AgentRuntime` +1 可选钩子；settings 新节；`shellRun` +1 可选参数（默认 null，零调用点变化）。

## 验证（Verification）

- `test/environment_test.dart`：名字校验；脱敏纯函数（值替换、短值不匹配、多值降序、无值原样）；store 往返（临时 keychain 替身）；bash 注入路径由 store→hooks 的单测钉住。
- 四道门禁；真机走查：设置节增删改 + bash `echo $NAME` 屏幕上只见 `[REDACTED]`。

## 关联（Links）

- 代码: `lib/model/environment.dart`、`lib/state/environment_store.dart`、`lib/genkit/tools.dart`、`lib/genkit/shell_run.dart`、`lib/state/app_scope.dart`、`lib/ui/settings/model_settings.dart`
- 关联 ADR: ADR-0045 PB/PF（keychain 槽位形状）、ADR-0049（keychain 拒绝不杀流程）、ADR-0012（工具结果进投影的唯一通道）
- 来源评估: `docs/kelivo-vs-agent-harness-2026-10.md` §7 B2
