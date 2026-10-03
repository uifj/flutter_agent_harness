# ADR-0052: 一行的松弛只该有一个去处，一列的宽度只该有一个理由

- **状态**: ACCEPTED
- **分类**: DEBT（技术债）
- **优先级**: P2
- **影响维度**: 认知障碍 / 生产功能
- **日期**: 2026-10-03
- **来源**: 用户真机截图两处批注（「太宽了」「再往右边一些」）；上一批"照参考改首页"整体回退（`d9426cf`）之后，改为按截图逐条落地
- **修复 commit**: 040cc63 / 8da3701

## 背景（Context）

两处都是**同一行**上的事，而其中一处的说法早就写在了代码注释里，只是没人去量它。

1. **发送钮没有贴到卡边**。`composer.dart` 的 `_row` 注释写着 "the model chip and
   button are the trailing group and should feel anchored to the right"，右内边距也确实只给了 4px
   （`EdgeInsets.fromLTRB(8, 2, 4, 6)`）。真机上量的结果：**60.3px**。原因在子件是平铺的一排：
   `const Spacer()`（= `Expanded`，tight）与模型芯片的 `Flexible`（loose）**都是 flex 孩子**，
   RenderFlex 把剩余空间按 flex 份数分给它们，芯片拿了自己那份里需要的一点点，**剩下的那份变成 residue**，
   而 `MainAxisAlignment.start` 把 residue 放在**最后一个孩子之后**——于是发送钮右边空出来的，
   正是那枚"没把空间用完的芯片"预留下的宽度。900px 视脚下量得 60.33（守卫里就是这个数）。
2. **整列太宽**。`chatContentWidth = 748` 是从 dsh 的 `--dsh-chat-content-width` 抄来的（注释自己这么写），
   不是这里量出来的决定：16px 正文下 748px ≈ 93 个拉丁字符一行，远超眼睛能稳定回行的 60–75；
   而输入卡按 `内容宽 + 32` 走，于是在默认窗口里读起来顶到两边。**三枚测试宿主**还各自写死了
   `contentWidth: 748`（`rewind_pill_test.dart`、`tool_card_readability_test.dart`、
   `tool_payload_one_voice_test.dart`），同一个数字在产品之外还有三处真值。
3. **收窄之后，队列行自己露了顶**。把尺子（`test/amplified_text_probe.dart` 两档）在 2.2x 下重跑，
   新增两棵红：`app_frame_test` 与 `input_queue_panel_test` 都报同一行——`_QueueRow` 的两枚
   `CapsuleButton` 在 2.2x 量得 **436px（"After this turn"）+ 178px（"Remove"）**，
   于是 `Expanded` 的草稿预览被给到 **0.0px**，整行溢出 2.4px。748 那一档刚好容得下，所以这顶天花板
   一直在，只是此前没人走到它边上。

## 决策（Decision）

- **一行只留一处吸收松弛**。`_row` 收成两簇：右簇（模型芯片 + 投递药丸 + 发送）先按自己的地板排，
  左簇（附件 + 模式芯片）是唯一的 `Expanded`，因此**剩余与挤压都落在它身上**。右簇的封顶取
  "行宽 − 左簇地板"，地板是**量出来的 84px**（先按 94 写，260px 那棵当场溢出 10px，遂改 84），
  且只在 `seatsFit` 为真时施加——140px 以下右簇只剩发送钮，把它压到自己盒子的一半不是降级而是炸版。
- **列宽回到"由行长决定"**。`chatContentWidth` 748 → **672**（用户在三个候选里选的：整列一起收到 672 /
  只去掉卡片多出的 32px / 只收窄首页卡片）。仍是一枚常数：卡片、队列面板、企划待审卡、正文都跟着走，
  两条轴关系不变（`chat_view_test` 的轴守卫在 1400/1152/700 三档仍绿，它断的是轴差不是像素）。
  `chatContentWidthWide`（960，ADR-0005 的"宽"档）不动——那是用户显式偏好，不是这里的默认。
- **测试不许再抄一遍宽度**。三枚宿主（`rewind_pill_test.dart`、`tool_card_readability_test.dart`、
  `tool_payload_one_voice_test.dart`）改读 `chatContentWidth`；`appearance_scope_test.dart` 里那个 748
  **不改**——它是喂给宽度缩放函数的任意输入，不是对产品真值的复制。两处把 748 当事实写进注释的地方
  （`chat_view.dart` 头部、`appearance_scope.dart` 的 fallback 说明、`chat_view_test` 的那串数）
  重测后改写，不是顺手替换字符串。
- **队列行的"Remove"降级成一枚 ×**。按既有律"先丢标签与描边，最后才丢座位"：删除动作在附件 chip 上
  早就是 `LucideIcons.x` + `removeAttachment` 这个键（`composer.dart:1923`），队列行现在用同一说法，
  名字留在 tooltip 与语义里（ADR-0024 的 `DswIconButton`，`onTap` 非空即按钮）。
  **不采用**"按行宽动态丢标签"的那条更复杂的路：那要给一行加一把随字号算的阈值，而 × 在两档下都不占地方。

## 后果（Consequences）

- **正面**: 发送钮真的贴到卡边（注释与屏幕第一次一致）；正文行长回到 60–75 字符区间；
  队列行在最大字号下不再吃掉草稿本身；宽度真值只剩一处，测试跟着它走。
- **负面/风险**: 672 是**这一屏**的判断，不是从参考抄的数——若日后要改，改一处常数即可，但三枚宿主与
  两条注释会同时说话，别只改常数；队列行的删除动作由"词"变成"×"，观感要真机签收（与 ADR-0024
  那批"由圆变方"同一趟）。
- **中性**: `input_queue_panel_test` 的删除那棵现在按图标（`find.byIcon(LucideIcons.x).first`），
  它验的还是那扇门通不通；`_QueueRow` 少了一枚 `CapsuleButton`，投递那一枚仍是带字的药丸
  （它说的是"什么时候落地"，不是可有可无的修饰）。

## 验证（Verification）

- `test/composer_test.dart` 的 `the row in a narrow column the trailing group is anchored to the card's right edge`：
  900px 下读**画出来的**卡矩形与发送图标矩形，断 `card.right - send.right < 24`（4px 行内边距 + 9px
  字形到盒子边）。**先红后绿**：改布局之前它红在 `Actual: <60.33333333333337>`。
  同文件其余 53 棵（含 260/320/420 三档降级与两档放大文本）全绿——降级序列没变，只是按钮回到了它被承诺的位置。
- 字号两档那两棵新红已**修好而非改断言**：`flutter test test/input_queue_panel_test.dart test/app_frame_test.dart` → `+22 All tests passed!`。
- 门禁：`dart format`（0 changed）、`dart analyze --fatal-infos lib test tool spike`（No issues found）、
  `flutter test`（**+1330 −2**，两个失败仍是既有基线 `app_scope_test` 的 `/var`↔`/private/var` 与
  `plan_workspace_test` 的重名 `find.text('notes')`）、`dart tool/check_architecture.dart`（7 recorded, 0 new）。
- 待 macOS 真机：① 672 这一档在四档系统字号下的观感；② 队列行在最大字号下 × 与投递药丸是否还读得懂；
  ③ 发送钮贴边后与卡片圆角的关系（4px 内边距在 16px 角上是否显得太挤）。

## 关联（Links）

- ADR-0017 S3（一行高的座位，高度取自字号）、ADR-0024（图标即控件必须自报姓名）、
  ADR-0005（"宽"档偏好与此默认的关系）、ADR-0034（一枚 `pill` 不许长在会缩水的盒子上——同一条"预留了却不用"的病）
- 守卫：`test/composer_test.dart`、`test/input_queue_panel_test.dart`、`test/app_frame_test.dart`、
  `test/amplified_text_probe.dart`
- 布局事实来源：`lib/ui/conversation/conversation_root.dart`（`chatContentWidth` /
  `composerCardWidthInset` / `composerSideClearance`）
