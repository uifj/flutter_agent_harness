---
name: review
description: Three-axis review of a branch diff — Standards (this repo's rules + skills + architecture gates), Spec (vs the originating acceptance criteria), and Correctness (runtime bugs + PlanStar's threat model). Use when reviewing a branch, a PR, or work-in-progress changes before opening or merging, or "review since X". Runs the axes separately and reports them side by side; not a debugger — a known reproducing bug goes to a failing-test loop instead.
---

Review the diff between `HEAD` and a base，在三条轴上：

- **Standards** — diff 是否符合本仓已文档化的标准？
- **Spec** — 它是否忠实实现了来源的验收标准（`docs/adr` 项或 spec 阶段的 AC）？
- **Correctness** — 它真能工作、且安全吗？

三条轴**分开跑、分开报**，**永不跨轴重排**——保持分离正是全部意义（见文末「为什么分轴」）。本 harness 里可用 `Agent`（CodeReview 子代理）跑单条轴；每条轴给它 diff 命令 + commit 列表 + 它的 brief。

这是每-PR 那一遍。它**不是**调试器：一个已知且能复现的 bug 应先变成一个失败测试（见 testing 的 Test-First Loop），而不是在这里被推测。

## 1. 钉住 base

用用户指定的任何 base——commit / branch / tag / `HEAD~N`。没指定就默认与主干的 merge-base（**主干工作分支是 `develop`**，`main` 可能落后；`git rev-parse --abbrev-ref HEAD` 现场确认，别信文档里写死的分支）。捕获一次：

- `git diff <base>...HEAD`（三点，对 merge-base 比）
- `git log <base>..HEAD --oneline`

确认 ref 可解析（`git rev-parse <base>`）且 diff 非空。坏 ref 或空 diff **在这一步**就失败——不在并行子代理里面。

## 2. 识别 spec 来源

按顺序找来源的 spec：① commit 消息 / PR 里对 ADR 或 `docs/debt-register.md` 行的引用（读那个 ADR 全文，别凭编号）；② PR 描述（motivation / 做了什么）；③ 用户传的一个路径。都没有就问。确实没有 spec，则 Spec 轴跳过并报 "no spec available"。

## 3. 分别跑三条轴

**Standards 轴：**

> 读 `.agents/skills/architecture/SKILL.md`、`.agents/skills/testing/SKILL.md`、`.qoder/rules/workflow.md`（§0 不变量、§3 对应链路、§5 提交），再对照 diff 评审。
> **最高优先——分层与不变量：** 跑 `dart tool/check_architecture.dart`（应"7 recorded, 0 new"），确认 `lib/model` 不 import flutter、`lib/genkit` 不 import flutter/state、riverpod 只在装配根、`lib/ui` 不直接 `dart:io`。任何"一个数字出现在两处""一份共享物只改了一个读者"（ADR-0035 那条律）都点名。
> 然后按文件/hunk 报告 diff 违反已文档化标准之处——引用规则。**新 UI 串是否同时进了两个 ARB**（i18n）、**新令牌/形状是否带读者**、**点击件是否复用 `DswHoverTap`/shad 而非手写**、**新 ADR 是否已 ACCEPTED**。文档没覆盖处用工程判断，区分硬违反与判断题；已文档化标准覆盖判断题。跳过 `dart analyze`/`dart format`/lints 已拦的。400 字内。

**Spec 轴**（无 spec 则跳过并注明）：

> 报告：(a) spec 要了但缺失或只做了一半的需求；(b) diff 里没被要求的行为（scope creep）；(c) 看着实现了但实现错了的需求。每条引用 spec 那行。注意"明确不做"清单里的东西（企划 CALENDAR/GRAPH、24 种 embed 等）被实现出来 = scope creep。400 字内。

**Correctness 轴：**

> 找 diff 引入的 bug 与不安全代码——不是风格（那是 Standards 的）。逐文件/hunk 查：
> - **运行时 bug** — 未 await / fire-and-forget 的 future、未取消的 stream 订阅、`late` 用在前置初始化、null/空边界、被吞的错误、`close()`/`dispose()` 缺清理、竞态/TOCTOU、异步间隙后没用 `context.mounted`。
> - **PlanStar 威胁模型** — 见 [references/threat-model.md](references/threat-model.md)：工作区访问越界（security-scoped bookmark 恢复必须在任何读文件之前、`@` 引用与文件工具同一道 `Workspace` 门）、审批门禁绕过（外部/内部工具是否都过同一个 `decideGate`、免问规则的 subject 是否等于面板显示的那串）、覆盖写之前 before 镜像与冲突闸门、备份 zip-slip、PII/密钥泄漏进 checkpoint 镜像或附件或日志、genkit 0.x 投影/累加文本陷阱、序列化往返正确性。
> 每条给 `file:line`、一行严重度（critical/high/medium/low）、为什么真（没被别处处理、无覆盖测试）、一个具体修法。跳过 analyzer 或既有测试已catch的。400 字内。

## 4. 汇总

在 `## Standards`、`## Spec`、`## Correctness` 标题下呈现各报告（原文或轻清理）。**不要跨轴合并或重排发现**。每条轴末尾一行小结：该轴总发现数 + 该轴内最坏的一枚。**不要跨轴选一个赢家**——那正是分离存在去防止的重排。

## 为什么分轴

一个改动可以在一轴过、另一轴挂，合并的清单会让一轴藏住另一轴：

- 符合所有标准但实现了错的东西 → **Standards 过，Spec 挂。**
- 做了 issue 要的但破了约定 → **Spec 过，Standards 挂。**
- 干净且合 spec 但审批门禁漏了一处外部工具、或 before 镜像没存就盖写 → **Standards & Spec 过，Correctness 挂。**

分开报，任何一轴都藏不住另一轴。
