# ADR-0068: 模型调用自动重试——注册 genkit 的 RetryPlugin（A8 判定修正）

- **状态**: ACCEPTED
- **分类**: ARC
- **优先级**: P2
- **影响维度**: 生产功能
- **日期**: 2026-10-04
- **来源**: kelivo 评估 §7 A8（kelivo 的"首 chunk 前才重试"律 + 状态码/关键字表）。**判定修正**：genkit 0.16.1 **自带 `RetryPlugin`**（`lib/src/ai/middleware/retry.dart`：默认 maxRetries 3、指数退避 2.0、initial 1s / max 60s、状态码表 408/429/500/502/503/504 等）——评估时误判为"无重试层"。A8 从自研降为**注册即用**。
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

429 限流、503、连接拒绝这类**流前失败**目前直接把整轮判死（`TurnFinished(failed)`），用户手动重发。kelivo 的自研重试在其自有 HTTP 栈上实现"仅当流未吐 chunk 才重试"；本仓库押注 genkit，模型缝的重试属上游。

## 决策（Decision）

**`Genkit(plugins: [..., RetryPlugin()])` + agent `use` 列表加 `middlewareRef(name: 'retry')`，上游默认值原样。**

1. **不复制 kelivo 的自研层**：状态码表、退避曲线、jitter 全在上游维护；我们零代码引入。
2. **已知边界，如实记录**：genkit 的 `_retry` 包住整个 `model()` 调用——若失败发生在**流中途**（部分 chunk 已吐），重试的第二趟会重复已吐内容。缓解因素按序：① 最常见的 429/503/拒连都发生在首 chunk 之前（正是 kelivo "yielded" 旗标瞄准的窗口，上游重试对该窗口行为正确）；② 中途失败后本轮本来就以 failed 收场，用户感知是"重发一次"，重复风险只在"中途失败且自动重试成功"的窄窗口；③ 若真机观察到达成问题，升级路径是在我们侧的 `_UsageCapture` 前挂一枚计数中间件把 retryModel 关掉——**今天不做没有读者的防御**。
3. **不做设置开关**：重试是可靠性参数不是偏好，无读者字段不建（ADR-0022）。
4. **明确不做**：关键字表（余额不足/unauthorized 不重试——上游按状态码已排除 4xx 非 429）、流式 tail 的 kelivo 式缓冲。

## 后果（Consequences）

- **正面**：瞬时限流/抖动对用户透明；零自研代码、上游升级自动改善。
- **负面/风险**：中途失败窄窗口的输出重复（记录在案，升级路径明确）；重试延迟最长 60s 内用户看到的是"还在跑"而非失败——stats 行的 wallMs 本来就在计时。
- **中性**：`agent_runtime.dart` +2 行。

## 验证（Verification）

- 结构守卫（`test/runtime_wiring_test.dart` 新节）：扫描 `agent_runtime.dart` 源码断言 RetryPlugin 注册与 use 引用在位（工具门禁同款结构测试先例）；反向验过——删 use 引用即红。
- `dart run spike/runtime_smoke.dart` 离线路径不破；带 key 真链观察 429 重试为余项。

## 关联（Links）

- 代码: `lib/genkit/agent_runtime.dart`
- 关联 ADR: ADR-0015（模型缝的中间件族）、ADR-0058（同缝上的诊断中间件——重试的每次尝试都各留一行，恰好是排查重试的证据）
- 来源评估: `docs/kelivo-vs-agent-harness-2026-10.md` §7 A8（判定修正：上游已内建）
