# ADR-0018: 输入区上方的透明渐隐带把统计行和正文叠成了一行

- **状态**: RESOLVED
- **分类**: DEF
- **优先级**: P1
- **影响维度**: 生产功能 / 认知障碍
- **日期**: 2026-09-29
- **来源**: [UI 生产化审计 §3 B](../ui-production-audit-2026-09.md)（用户截图 1152×795）
- **修复 commit**: `bd38147`

## 背景（Context）

用户截图里末条回复的一行同时画着两套文字：拉丁文的
`SDK returns \`{data, error}\` structure for all operations` 与统计行的中文数字/量词
（`和 4 次` 一类），两者**在同一基线上重叠**，谁都不能读。

裁剪放大后的证据（原图坐标）：重叠发生在 y≈650–672、x≈680–745，正好落在
composer 卡片上沿之上的那条带子里；同一张截图右侧还浮着"滚动到底"按钮，
说明列表**不在底部**，即正文确实有行被滚到了输入区下方。

代码给出的机制（修复前）：

- `lib/ui/conversation/conversation_root.dart:530` 的 `_Masked` 用
  `_MaskPainter`（`:544-556`）在**输入区（seat）自己的矩形**上画一层
  `transparent → bgBase` 的渐变，`composerMaskHeight = 36`（`:90`）；
  意图是"回复滑到输入区下面时先溶掉，而不是被硬切"。
- 但 seat 的内容是 `Column[_statsLine(), InputQueuePanel, card]`
  （`_stack()`，`:462-478`），**统计行就是第一条**，也就是被画在那条
  36px **半透明**带的正中间。
- 于是：带子里同时有 ① 透过半透明画上去的正文行 与 ② 不透明的统计行文字。
  这不是渲染器叠字（已排除，见"验证"），是**一处内容被放在了设计上可见的区域里**。

## 决策（Decision）

**把这条带子同时定义为 seat 的内容内缩**：`_Masked` 在 `CustomPaint` 之内、
内容之外加 `Padding(top: composerMaskHeight)`。溶失效果保留在原处（渐变仍覆盖
整个 seat 矩形），只是**内容从渐变结束的地方开始**。

三条取舍：

1. **不给统计行加不透明底**（选项 B）：那会在溶失带里挖一块实心矩形，视觉上
   比现在更脏，而且只修好这一行，`InputQueuePanel` 仍会踩进带子。
2. **不缩短带子**（选项 C，例如 36→12）：带子高度是"回复溶掉需要多少行程"，
   与内容位置无关；把它改小等于把溶失改硬。
3. **不再复制一个高度真值**：seat 高度本来就由 `_Measured`（`:321`）量出来喂给
   `ChatView.bottomInset`（`:306`），多出来的 36px 自动进滚动预留，
   不需要第二处数字跟着改。

## 后果（Consequences）

- **正面**: 文字叠字消失；统计行与正文之间获得一条真实的呼吸带（审计条 4
  "控件拥挤"同向受益）。
- **负面/风险**: seat 变高 36px，小窗口下正文可视高度相应减少 36px；
  这 36px 是**看得见的**改动，需要一次真机走查确认不显空。
- **中性**: `composerMaskHeight` 从"一个渐变参数"升级为"输入区的内容基线"，
  注释已写清；今后任何新内容进 seat 都自动落在不透明区。

## 验证（Verification）

- 守卫：`test/chat_view_test.dart` 的 `the seat caption stays below the see-through band`
  ——量统计行顶与 scrim 自身矩形的顶，要求差值 ≥ `composerMaskHeight`。
  先用 `getSize(band).height < 600` 钉住量的是 seat 而不是 `Material` 的那层 CustomPaint。
- **反向验证过**：把那段 `Padding` 删掉，断言以 `Actual: <0.0>` 失败。
- 排除项（本次实测，别再回到这些假设）：
  - 渲染器叠字不存在——临时探针在 4 个 fixture（引用角标 / 中英混排 + inline code /
    纯英文 / 纯中文）下逐字符走 `RenderParagraph.getBoxesForSelection`，
    **没有任何一个 (行, 左边界) 位置收到两个框**。
  - `[3]` 角标不是元凶：它自己是一个 14.2×22 的独立段落，**占了横向推进**，
    只是设计上上浮（截图里那个"³"就是它，属正常渲染）。
- 门禁：`dart format` / `dart analyze --fatal-infos` 零输出，
  `flutter test` = `+831 -2`（两条既有失败不变）。
- **仍欠**：真机走查一眼——36px 的空档在真实回复里是否显空（本机无 Screen
  Recording 权限，截图不可得）。

## 关联（Links）

- 代码: `lib/ui/conversation/conversation_root.dart#L88-L96`、`#L526-L556`
- 关联 ADR: ADR-0014（统计行与回退 pill 同属一轮回话的收尾信息）·
  [审计 §3 B / 条 4](../ui-production-audit-2026-09.md)
