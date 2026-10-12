---
name: spec
description: Produce a verified spec — problem, desired outcome, acceptance criteria — before designing or coding. Use when given a docs/debt-register.md or ADR item, starting from a fuzzy in-conversation ask, or asked to "该做什么 / 定范围 / 我要建什么 / scope this" — whenever the *what* isn't yet pinned down. Grill the ambiguities, check the premise against the code, sign off on the bar, then hand to design-first.
---

在建任何东西之前，先定下**做什么**与**为什么**——带可验证验收标准。这是流水线的前端：**spec**（what）→ **design-first**（how）→ **architecture** + **testing**（build）→ **review**（对着这份 spec 验收）。

为一个已登记的债务项或一个模糊诉求跑它。**跳过并明说跳过**——当诉求已经是一条精确、可验证的指令时。

## 1. 建立来源

从它所在的地方拿到原始意图：

- **来自登记表 / ADR**（`docs/debt-register.md` 的一行、或 `docs/adr/ADR-NNNN-*.md`）——读全文，别凭编号或记忆：登记表是**唯一状态源**，逐条状态/commit/行号以它和 `ls docs/adr/` 现场为准。修复一条**已登记**问题前，对应 ADR 必须先置 **ACCEPTED**（workflow §7 的纪律）。
- **来自对话里的想法**——从用户说的话出发（用他们的词）。如果可能已有对应 ADR，问一句链接或编号；否则照走——这份 spec 本身就是真值源。

两种情况你现在握着的都是原始意图——通常含糊。下面几步把它磨利。

## 2. 重建真实意图

原始诉求往往只点名症状；真实需要在底下。用领域自己的话说清：这次要解决的问题、为谁解决、"done" 长什么样。把**报告的症状**与**底下的需要**分开——它们常常不是同一个修法。

## 3. 拿代码核对前提

诉求——尤其来自 ADR/issue 的——可能过期、片面、或干脆是错的。动手前先查：

- 描述的行为真的存在 / 能复现吗？是 bug 就找到代码路径；非平凡的话现在就搭复现环（见 **review** 的 Correctness 轴，或直接进最小复现）。
- 是不是已经实现了一部分，或被后来的改动变得无关？（本仓库文档里的文件数/行数/键数/ADR 编号都是**快照**，会腐烂——引用前用 `find`/`wc`/`grep -c`/`ls docs/adr` 现场重算。）
- 代码库是否 contradict 了 issue 的假设？

把任何矛盾在继续之前摊给用户看——建在错误前提上的 spec 会浪费整条流水线。

## 4. 拷问空白

无情地盘问直到意图无歧义。**一次一个问题**，等回答再问下一个——批量问会把人绕晕。每个问题都带上你的**推荐答案**。能靠读代码回答的问题就去读代码，别问。逼出范围、边界情况、in-vs-out 的那条线。

## 5. 写下 spec 并签收

在对话里产出：

- **Problem** — 哪里坏了或缺了什么，为什么重要。
- **Outcome** — 期望的终态，用领域的话。
- **Acceptance criteria** — 可验证、可观察的条件（例："agent 写完文件后，文件树与 git 面板两棵同时变"；"一次 `git status` 只有一个持有者"）。这就是 **review** 的 Spec 轴将来核对的那道杠。
- **Non-goals** — 明确不做什么（企划模式里 CALENDAR/GRAPH 视图与 24 种 embed 按上游答案是"不支持占位"，不是待修 bug——别把它们写进 outcome）。
- **Open questions** — 仍未解决的。

用户**签收验收标准**才算完成——对"满足它们就等于做完"的明确同意。不是"看着挺合理"，是对那道杠的同意。

## 6. 交接

*what* 已定。这份 spec 在出包时变成 PR 描述里的 problem / outcome / acceptance；**review** 的 Spec 轴对着它验收。交给 **design-first** 去塑形 *how*。
