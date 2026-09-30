# ADR-0031: 工具卡给人读内容，不读信封

- **状态**: ACCEPTED
- **分类**: DEF
- **优先级**: P1
- **影响维度**: 生产功能 / 认知障碍 / 观感
- **日期**: 2026-09-30
- **来源**: [ui-consistency-audit-2026-09-30.md](../ui-consistency-audit-2026-09-30.md) §U1（四张真机窗口截图走查，本仓库第一次拿到真窗像素）
- **修复 commit**: 9fc0420（显示侧渲染器）· 5402104（守卫）

## 背景（Context）

真窗截图 `86e0bd57…png`（1076×829，`sips` 裁切 2× 复核）里，一条 `Bash · Show workspace root and contents` 的 `OUT` 段整段是：

```
{"output": "/Users/uifj/…/flutter_tiptap_test\n.total 88\ndrwxr-xr-x@ 25 uifj staff 800 May 26 22:35 .\ndrwxr-xr-x@ 15 uifj staff 48…
```

一次 `ls -la` 的三十行目录，在屏幕上变成**一段无法扫读的文字墙**——真实换行以字面 `\n` 出现。而**同一张卡**的 `IN` 段是多行缩进的漂亮 JSON：一张卡用两种嗓音说话。

代码链条（都取到过）：

1. 工具返回的是 Map，例如 `lib/genkit/tools.dart:672` 把 shell 结果放进 `output` 键；`read` 返回 `{path, startLine, endLine, totalLines, content, footer}`（`:198-204`）。
2. `lib/ui/tool/tool_card.dart:600-603` 的 `_format()`：`String` 原样返回，其余交给 `_pretty` = `JsonEncoder.withIndent('  ')`。
3. **`JsonEncoder` 会把字符串值里的换行转义成 `\n`** —— 于是任何"带多行文本字段"的工具结果（bash 的 `output`、read 的 `content`、grep 的 `matches`）在卡上都塌成一行。第 2 步的 `String` 分支同样漏：模型侧拿到的就是 JSON 文本，若投影某条路径把那段文本原样带过来，屏幕上也还是信封。

用户最初的抱怨"代码块与路径堆砌成文字墙"在工具卡上以最直白的方式复现了；而这不是观感偏好：**这个产品的核心输出就是工具结果**，读不了就等于功能不可用。

## 决策（Decision）

1. **渲染层负责给人读，线格式不动。** 模型继续收 JSON（它要的是结构），只有 `_format` 改成一个小的**人类渲染器** `_render`：Map 逐键一行（`path: lib/main.dart`、`totalLines: 42`），**值里含换行就把该值原样缩进成块**挂在键下面，嵌套 Map/List 递归，非 JSON 的纯字符串一字不动。约 30 行，无新依赖、无新抽象层。
2. **`IN` 与 `OUT` 走同一个函数**（`tool_card.dart:546,588` 两处调用点由 `_pretty` 换成 `_render`），"一张卡两种嗓音"就此结束；摘要行（`_firstLine(_render(args))`）也跟着同调。
3. **只在看着像 JSON 时才试解码**（`_tryDecode` 先判首字符是 `{`/`[`）：一个工具用 `{` 开头的散文回答，就按散文显示，不去动它。
4. **明确不做**：
   - **不改工具返回形状**（不为了 UI 少给模型一个键，也不把 `output` 拆成纯文本发给模型——模型侧的结构是 ADR-0012 工具契约的一部分）。
   - **不给 `OUT` 段加新的展开控件**：段落已有 `maxHeight: 150` + 各自滚动（`:295-306` 的注释写明了理由：长输入不许埋掉短输出），而整张卡本来就能通过头部的 chevron 展开。这次要修的是"读不懂"，不是"放不下"。
   - **不做语法高亮/行号**：`read` 的行号本来就在 `content` 里（`numberedLines`），bash 输出加行号反而是噪声。

## 后果（Consequences）

- **正面**：所有工具卡的多行结果第一次按行可读；`IN`/`OUT` 同一套呈现；`read`/`grep`/`write` 的卡片顺带受益（它们的 `content`/`matches` 同样是多行字段）。
- **负面/风险**：**可见改动，且面很宽**——每一张工具卡的两个段落都换了排布（JSON 花括号与引号消失，改成 `key: value` 加缩进块）。需要真机走查确认没有哪一类工具结果被这个形状弄得更难读；守卫只覆盖了 bash/read/纯字符串三种形状。
- **中性**：`_pretty` 被删除，`JsonEncoder` 不再出现在渲染路径上；如果将来需要"给人看的 JSON"（例如 MCP 原始报文调试），那是另一个表面，不该借这张卡。

## 验证（Verification）

- **先红**：`test/tool_card_readability_test.dart` 跑在未改的树上 → `+1 -3`（三条真缺陷各自红，第四条"纯字符串不动"本来就绿，证明它不是空守卫）。
- **后绿**：4/4；`flutter test` `+932 → +936 -2`（净增 4 条即本文件），两条既有失败（`app_scope_test` 的 `/var`↔`/private/var`、`plan_workspace_test` 的 `find.text('notes')`）未触碰——**没有任何一条既有断言依赖旧的 JSON 引号形状**。
- `dart format --set-exit-if-changed lib test tool spike` 无 diff；`dart analyze --fatal-infos lib test tool spike` → `No issues found!`。
- 复跑口径：`grep -n "_pretty" lib/ui/tool/tool_card.dart` 为空。
- macOS debug 已重建并重启（PID 63300）；**肉眼那一眼留给用户**：本机无 Screen Recording 权限截不到应用窗口，而这条改的正是可读性本身。

## 关联（Links）

- 代码: `lib/ui/tool/tool_card.dart`（`_format` / `_tryDecode` / `_render` / `_block` / `_scalar`）
- 守卫: `test/tool_card_readability_test.dart`
- 审计: [ui-consistency-audit-2026-09-30.md](../ui-consistency-audit-2026-09-30.md) §U1；同批还有 §U2（覆盖层文案，ADR-0032）、§U5（设置页路径泄漏，ADR-0033）、§U3/§U4（对话列轴与气泡，ADR-0034）
- 关联 ADR: ADR-0012（工具契约的形状不因 UI 而变）· ADR-0014（同一张卡上的回退 pill 读的是 `output` 里的 `checkpoint` 键——解码只发生在显示侧，`_checkpointOf` 仍看原始 Map）· ADR-0008（文案两侧同键）
