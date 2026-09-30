# ADR-0035: 一次工具结果只有一个读法（详情栏不再是第二套格式化）

- **状态**: ACCEPTED
- **分类**: DEBT
- **优先级**: P2
- **影响维度**: 观感 / 认知障碍
- **日期**: 2026-09-30
- **来源**: ADR-0031（§U1 工具卡）落地后的**同函数普查**——不是第四张截图暴露的，是"改一个共享的东西要看它所有的读者"那条律的反面：改了卡的读法，没问还有谁在读
- **修复 commit**: `d50764c`（`formatToolOutput` 提成库级函数，详情栏改读它）· `c186649`（守卫 `test/tool_payload_one_voice_test.dart`，两条，先红 `+0 -2`）

## 背景（Context）

ADR-0031 把对话流里的工具卡从 `JsonEncoder` 换成人读的按行渲染（`lib/ui/tool/tool_card.dart` 的 `_format` / `_render`），证据是真窗截图里 30 行 `ls -la` 变成一整段带字面 `\n` 的文字墙。当时**没有问**：同一个 `ToolCallNode` 还有别的表面在渲染吗？

有，而且用户**同时看得见**：右侧详情栏 `lib/ui/conversation/details_panel.dart` 自带两枚顶层函数：

```
:292  String? _format(Object? output) {
:294    if (output is String) return output;   // 原样返回：信封连转义一起上屏
:295    return _pretty(output);
```

`_pretty` 是 `JsonEncoder.withIndent('  ')`。于是同一条 `bash` 调用：中列卡片刻出 `output:` 缩进块，右栏 `_Pre` 刻出 `{"output":"total 88\ndrwx…","exitCode":0}` ——**字面 `\n` 原样回到屏幕上**，ADR-0031 修掉的症状在那个表面一直留着。

守卫实测（改之前）：

```
Expected: 'output:\n  total 88\ndrwxr-xr-x  2 u  wheel  64 Sep  1 10:00 docs\n'
  Actual: '{"output":"total 88\\ndrwxr-xr-x  2 u  wheel  64 Sep  1 10:00 docs\\n","exitCode":0}'
```

还有一条让它长期存活的原因：`_pretty` 头上那段 `///` 注释（原 `:280-283`）自称"dsh 在这里重新打印 `argsRaw`，并另存一份 `rawResultText`；两者留在此地是为了不与行内私有格式化耦合"。这句话在 ADR-0031 之前是真的（那时卡片的"私有格式化"就是 `jsonEncode`），之后就变成**一段为已消失的前提辩护的注释**——与 ADR-0022 那条"一条自我辩解的注释仍是一枚假开关"同族。

## 决策（Decision）

1. **读法只有一个函数**：`tool_card.dart` 的 `_format` 提成库级 `formatToolOutput(Object?)`（连同它私有依赖 `_tryDecode`/`_render`/`_block`/`_scalar` 一起搬到文件顶层），详情栏的 `_format` 删掉，`_Pre` 改读它。**不新增文件、不新增抽象**（ponytail 第 2 阶：实现在旁边，搬出来即可）。
2. **边界说清楚，别顺手统一第二处**：详情栏的 **Input 仍是 `CodeBlock(_pretty(arguments))`**。那一块是**复制面**——用户点 Copy 拿走的必须是模型形状的 JSON，换成人类读法就复制不出可用参数。所以本 ADR 的判据不是"两处必须一模一样"，而是：**被读的地方一份答案，被抄的地方留原文**。这条判别式写在 `_pretty` 的新注释里，挡下下一个"顺手统一"。
3. **明确不做**：`subagent_tab.dart` 的 `taskPreviewOf` / `delegationResponseOf` 不算第二套读法——它们回答的是"这次委托的任务是什么"（取具名字段、折行、截断），不是"任意工具结果怎么读"。普查过，不动。
4. **明确不做**：`subagent_tab.dart:50-53` 的 `failureLineOf` 与卡片的 `_firstLine` 是同一条"取首行"规则的两份实现。它是三行、语义一致、无渲染分叉；本批不合并（合并就是把一处真值拆成一次跨文件重构）。

## 后果（Consequences）

- **正面**：打开详情栏不再把 ADR-0031 的缺陷重新请回来；卡的 `IN`/`OUT` 与栏的 Output 同源，一次改动两处生效；那段过期注释换成一条**带判别式的**边界说明。
- **负面/风险**：`details_panel.dart` 现在 import `tool/tool_card.dart`，两个表面从"各自独立"变成"共用一个读者"。这是刻意的耦合（同一问题的答案必须相同），但它确实让 `tool_card.dart` 成了一个被跨目录引用的 UI 模块——将来若详情栏要独立演进，得先回答"要不要把这个函数搬去 `lib/ui/primitives/`"。
- **中性**：可见改动只在"工具结果是一个 JSON 字符串"的那批调用（`bash`、`read`、`write`、`edit` 的 OUT）。纯文本结果两处本来就一致。

## 验证（Verification）

- **先红**：`test/tool_payload_one_voice_test.dart` 两条在未修树上 `+0 -2`，失败信息就是上面那对 Expected/Actual（守卫比的是**两块表面各自画出来的字符串**，不是钉死某个期望值——所以它不会因为改渲染措辞而假红，也不会因为两处各自改了同一个错而假绿）。
- **后绿**：2/2；全量套件 `+944 → +946 -2`，两条既有失败（`app_scope_test` 的 `/var`↔`/private/var`、`plan_workspace_test` 的 `find.text('notes')`）未变多。
- 门禁同口径复核：format `214 files`、analyze `No issues found!`、`check_architecture` `7 recorded, 0 new (127 files, 7 rules)`。macOS debug 重建并重启（69068 → **71818**）；**待真机看**：选中一条 `bash` 调用，中列卡片与右栏 Output 是否同一句话，以及 Input 那块复制按钮仍给出可粘贴的 JSON。
- 两条测试坑记在这里，因为它们是这条守卫能成立的前提：① `SelectableText` **不作为 `Text` 出现在树里**，只扫 `RichText` 会看见卡片的 OUT 而看不见详情栏的 `_Pre`——守卫因此同时收 `RichText` 与各 `EditableText` 的 `controller.text`；② `ToolCallSucceeded` 之后详情栏读的是**替换后的节点**，先取的 `ToolCallNode` 仍停在 `running`，选择必须在结果落地之后再取 id。

## 关联（Links）

- 代码: `lib/ui/tool/tool_card.dart`（`formatToolOutput`）· `lib/ui/conversation/details_panel.dart`（`_Pre`、`_pretty`）
- 守卫: `test/tool_payload_one_voice_test.dart`
- 关联 ADR: ADR-0031（本批修的是它没扫到的读者）· ADR-0022（自我辩解的注释）· ADR-0014/0025/0034（"两处必须相等的字段就是一种新的错法"这一族）
