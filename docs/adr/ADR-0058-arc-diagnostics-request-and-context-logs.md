# ADR-0058: 诊断日志——每次模型调用的请求记录与上下文快照

- **状态**: ACCEPTED
- **分类**: ARC（可观测子系统）
- **优先级**: P2
- **影响维度**: 生产功能 / 评估阻断
- **日期**: 2026-10-04
- **来源**: `docs/kelivo-vs-agent-harness-2026-10.md` A3（kelivo 的诊断三件套：请求日志 JSONL + 上下文日志 + 存储明细，`_archive_project/kelivo` `lib/core/services/network/request_logger.dart:9`、`lib/core/services/logging/context_logger.dart:11`）+ ZCode 评估 B7（模型 IO 轨迹检视器）。S3（存储明细）不在本 ADR 范围。
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

agent 的行为出了问题（答非所问、工具没被选中、上下文里出现了不该有的东西、一轮跑得异常慢），现在没有任何落盘证据可看：

- 每次模型调用只有 `TurnUsage` 聚合进 usage 台账（`lib/state/usage_ledger.dart`，ADR-0045 PC），粒度是**每轮的 token 总和**，没有耗时、没有错误信息、没有"这一轮发了几次模型调用"。
- **发给模型的实际内容无处可查**。系统提示、工作区 AGENTS.md 注入（ADR-0009）、`@` 引用展开、工具定义、审批元数据全在运行时组装（`lib/genkit/agent_runtime.dart`），组装结果只活在当次请求里。
- 调试只能靠 `spike/runtime_smoke.dart` 带 key 真跑——它是离线验收门不是现场取证工具。

kelivo 的对照实现（评估文档 A3）：
- 请求日志：按天 JSONL，记录 method/URL/头/体/耗时，base64 大负载替换为占位符，单行 1MB 上限。
- 上下文日志：默认**关**，开启后记录实际发给模型的完整消息列表 + 每条 token 估计。

本仓库的对应缝已经存在且被验证过：`_UsageCapture` 中间件（`lib/genkit/agent_runtime.dart:268-287`）在模型缝上能看到每次调用的 `ModelRequest` 与 `ModelResponse`（含 usage）——上下文快照与请求记录可以在同一道缝上拿全，不必新开通道。

## 决策（Decision）

**在同一道模型缝上挂第二枚中间件，产出两份 JSONL；两份都走 usage 台账的同一套持久化口径；开关是活读取，不触发运行时重建。**

1. **两份日志，两个文件族**：`<support>/diagnostics/requests-YYYYMM.jsonl` 与 `<support>/diagnostics/contexts-YYYYMM.jsonl`。
   - **请求日志（S1，默认开）**：每次**模型调用**一行——时间戳、模型、耗时 ms、成败、错误摘要（截 300 字符）、provider 报告的 token 三元组（未报告则缺省）。粒度是模型调用不是回合：一轮带工具循环会有多行，这正是排查"这轮为什么慢"需要的。
   - **上下文快照（S2，默认关）**：每次模型调用的 `request.messages` 逐条序列化——role + 逐 part：text 全文、reasoning 的 data、工具请求/响应的 name 与 JSON（各截 4KB）、media 只记类型并把 `data:` URL 整体省略为占位符。默认关的理由与 kelivo 一致：体积由用户选择，不替用户决定。
   - **elision 律**：媒体字节永不落盘（附件可能含用户隐私，上下文日志的读者是用户自己，但日志文件会被备份打包面考虑——见风险 2）。
2. **词汇在 `lib/model`，存储在 `lib/state`，中间件在 `lib/genkit`**：`ModelCallRecord`/`ContextSnapshotRecord`/`DiagnosticHooks` 是纯 Dart（手写 toJson/fromJson，`TurnUsage` 先例）；`DiagnosticLogStore` 是追加 + 30 天修剪 + 撕裂行容忍（`UsageLedger.prune` 同一套口径，逐月文件、cutoff 丢弃、空文件删除）；中间件经 `AgentRuntime` 工厂的新可选参数 `diagnostics` 注入，回调签名与 `CheckpointSink`/`onTurnUsage` 同族——运行时不碰 `lib/state`（不变量 3/6）。
3. **开关是活读取**：`DiagnosticHooks` 持 `bool Function()`，组合根闭包读 `SettingsStore.value`。**不加进 `requiresRuntimeRestart`**——日志开关不是模型/MCP/skills 那类烤进 agent 的东西，为一个开关重建运行时（丢掉打开的对话）是把用户赶出应用。
4. **快照组装是公开纯函数**：`contextSnapshotOf(ModelRequest, String model)` 提在 `lib/genkit/agent_runtime.dart` 顶层（ADR-0009 为 `sessionTitle` 做过的同一件事）——genkit 消息形状（part 分派、截断、elision）是本 ADR 唯一有逻辑的地方，测试直接喂 `ModelRequest`，不造假模型。
5. **设置面一个节，双入口律不适用**：诊断开关只住设置页新增的「诊断」节（两枚 `_SwitchRow` + 一枚"在文件管理器中显示"）。ADR-0006 的快捷菜单双入口律管的是"高频偏好"（字号/主题/语言），诊断是低频排查面，进快捷菜单是给它不值得的曝光。
6. **明确不做**：S3 存储明细（另立）；应用内日志查看器 tab（走 tab 链路的成本，先用 reveal 打开文件夹，JSONL 本身可读）；请求日志记 HTTP 层 URL/头（我们经 genkit provider 插件，URL 不是我们的词汇，模型调用才是）；工具调用审计环落盘（`ToolAuditRecord` 目前是内存环，另案）。

## 后果（Consequences）

- **正面**：排查 agent 行为第一次有落盘证据；"上下文里到底有什么"从猜测变成打开文件就能看；两份日志与 usage 台账、崩溃归档组成完整的本地可观测面（ADR-0045 的"崩溃留痕、usage 台账"两格之外的第三格）。
- **负面/风险**：
  1. **上下文快照含对话内容**，落盘明文。缓解：默认关 + 30 天修剪 + 备份 zip 的清单不含 `diagnostics/`（需核实 `backup_service` 的打包根——usage/ 也不在清单里，同口径即零新增面）。**实施时核实这一格**。
  2. 每调用一次文件 append，长会话 + 工具循环会增加写次数。请求日志行 ~200B，量级与 usage 台账相同；快照默认关。
  3. `ModelRequest.messages` 的 part 分派覆盖六种 part 类型，genkit 升版加新 part 时未知类型落 `other` 分支（只记 kind），不抛错。
- **中性**：`AppSettings` +2 字段（`settings_reach_test` 的读者面 = AppScope 闭包 + 设置面板两处）；`locales.dart` +8 键。

## 验证（Verification）

- `test/diagnostic_log_store_test.dart`：追加 → 读回行数与内容；30 天修剪（注入时钟）；撕裂行容忍；两文件族互不串。
- `test/diagnostics_capture_test.dart`：`contextSnapshotOf` 喂 text/tool-request/tool-response/media/reasoning 五种 part——断言文本全文、工具 payload 截 4KB、media elide 为占位符；反向验过：截断常量放大后 media elision 断言变红即守卫咬合。
- `flutter test` 相对基线零新增失败；format/analyze/architecture 三门禁同口径。

## 关联（Links）

- 代码: `lib/genkit/agent_runtime.dart`（`_DiagnosticCapture` + `contextSnapshotOf`）、`lib/model/diagnostic_record.dart`、`lib/state/diagnostic_log_store.dart`、`lib/state/app_scope.dart`、`lib/ui/settings/model_settings.dart`
- 关联 ADR: ADR-0045（usage 台账与崩溃归档的持久化口径）、ADR-0015（运行时不碰 Flutter/state 的缝）、ADR-0022（设置字段必须有读者）、ADR-0033（hint 是事实——描述里写"30 天"就要真 30 天）
- 来源评估: `docs/kelivo-vs-agent-harness-2026-10.md` §7 A3
