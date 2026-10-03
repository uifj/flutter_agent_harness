# ADR-0052: 首页读法对齐参考——问候语、卡内的工作区 chip、方角发送钮

- **状态**: ACCEPTED
- **分类**: DEBT（技术债）
- **优先级**: P2
- **影响维度**: 认知障碍 / 生产功能
- **日期**: 2026-10-03
- **来源**: 第二张真窗截图（ZCode 深色首页）与本项目首页逐件对照，对照表 `docs/hero-parity-zcode-2026-10-03.md`
- **修复 commit**: 9af8d7c

## 背景（Context）

两张截图的差别不在配色（ADR-0024…0029 已把令牌与原语收口），而在**首页那几格各自答的是什么问题**：

1. 标题。我们是一句固定的 `askAnything`（"随便问点什么"）下面再挂一行副标题 `heroSubtitle`；
   参考的空态头（`ConversationDraftEmptyState.tsx:29-35`，边界小时 `[5,9,12,14,18,23]` 见 `:14`）
   是**按时段挑一句问候**，共六档，并且自己 `setTimeout` 到下一个边界重绘（`:38-52,91-99`）；
   它的 header 块里**没有第二行**，字号是被隐藏 span 量出来后夹到 20–30px（`:15-16,54-78`）。
2. 工作区。我们的状态条长在卡**下方**（改动前 `composer.dart:699-703`），hero 另有一枚居中 picker；
   参考把它作为 `contextHeader` 传进 composer（`WorkspaceShellLayout.tsx:1168-1187` →
   `SessionPane.tsx:4382` → `ConversationComposer.tsx:2235-2238`），组件是
   `ChatEmptyWorkspacePreviewMenu`（`ChatEmptyState.tsx:169`：`rounded-full` + 尾随 `ChevronDownIcon size-3.5`），
   与文本框**同在一张卡里、位于其上**。"这次任务在哪个文件夹里跑"是问题的一部分，不是窗口的状态说明。
3. 占位文案。参考教用户两条语法（`chat.placeholder.newTask`，zh `zh-CN.ts:4264` / en `en-US.ts:4560`），
   我们那句只说"输入问题，或描述一个任务"。
4. 发送钮形状。我们是 `BoxShape.circle`；参考是 `size="icon-md" rounded-lg bg-brand`
   （`ConversationComposer.tsx:2079-2097`）。ADR-0034 已经立过"一枚 `pill` 不许长在会缩水的盒子上"，
   34px 方盒上的 pill 夹到一半就是圆盘——截图上它读起来像头像，不像"把话发出去"。
5. 工具栏左簇第一件。参考是 `+`（`PlusIcon size-4`，`ChatPromptActionMenu.tsx:252-259`，标题"添加上下文"），
   我们是一枚回形针开附件菜单。

另两格**不在本次范围**，理由是可跑的取证而不是审美：

- 额度横幅（`ConversationQuotaBanner.tsx` + `sessionQuotaBannerState.ts:29-52`）：本仓库有形状没有数据——
  `lib/model/zcode_compat/zcode_account.dart:77` 的 `ZcodeUsageQuotaSnapshot` 在生产代码里**零读者**
  （`grep -rn "ZcodeUsageQuotaSnapshot" lib test` 只命中该文件自身与 `test/zcode_compat_test.dart:155` 的往返），
  `state/auth_session.dart` 也不返回它。在没有快照的面上画一枚永远隐藏的横幅，正是 ADR-0041 判过的
  "声明了但没有消费者"。截图里那枚"150% 配额" chip 在参考代码里 grep 不到（`150%`、`配额`、
  `multiplier|bonusPercent|quotaPercent|ratioLabel` 全仓无命中），因此**不搬**。
- 模型右侧两枚（`ChatContextUsage` 环形用量、`ThoughtLevelCycleControl`）：本轮数已经有了
  （`turn_event.dart:127-160` 的 `TurnUsage.inputTokens`，运行时在 `agent_runtime.dart:243-246` 从 provider
  usage 块累加，`conversation_controller.dart:184-185` 再汇总），**缺的是分母**——`model/known_models.dart`
  没有模型上下文窗口这一档，环形表没有可算的百分比；而 `reasoningLevel` 也没有进请求的通路。
  按 ADR-0022"一条偏好必须有人读回"，这两枚等 ADR-0045 的后端契约真的回这两个字段再接。

## 决策（Decision）

H1–H6 采纳，全部落在两个文件里，不新增依赖、不新增抽象：

- **H1 问候语**：新增 `lib/model/greeting.dart`——`Greeting` 六档 + `Greetings.of(DateTime)`（边界表
  照参考的 `[5,9,12,14,18,23]`）+ `key()`（映射到 i18n 键）+ `nextBoundary()`（下一次换句的小时）。
  纯 Dart 所以可单测；文案六句逐字取自参考的 `zh-CN.ts:4221-4226` / `en-US.ts:4513-4518`。
  `ConversationRoot` 用 `Timer` 到点 `setState`（`dispose` 取消），参考同一段 (`:38-52`)。
  **不搬**参考的"量隐藏 span 再夹 20–30px"：`DswType.heroTitle26` 本来就落在那条带里，
  而自算字号会绕开 ADR-0027"样式名不许对字号撒谎"。副标题连它的两枚键一起删。
- **H2 工作区 chip 进卡**：`_workspaceStatusBar` → `_workspaceChip`，作为 `_card` 那棵 `Column` 的第一行
  （`rounded-full` + 尾随 `chevron_down`，与参考同形）；hero 的居中 picker **只在还没选过文件夹时**保留——
  chip 需要一个名字才成立，而全新安装没有名字可显示。
- **H3 占位**：`askWithContextHint`（`@` 加上下文、`/` 选命令），忙时仍换 `queueDraftHint`（ADR-0050）；
  被顶掉的 `askAnythingHint` 一并删除。
- **H4 发送钮方角**：`ShadButton.ghost` 的 `decoration.border` 写 `DswShape.control`(8px)，
  `focusedBorder`/`secondaryBorder` 关到 `ShadBorder.none`（ADR-0038 那条"聚焦不再换边"）；
  半径在调用点说，是因为 shad 只有一枚旋钮且它答的是控件档（ADR-0029）。
- **H5 `+` 与"添加上下文"**：字形 `paperclip` → `plus`，标签 `attach` → `addContext`（旧键删除）；
  菜单内容仍是我们真有的那几项——参考列的 `/goal`、插件组本仓库没有，不虚构。
- **H6 节奏**：hero 用参考的 24px 间距（`gap-6`），卡仍是同一个 `Composer`，不另画一张。

## 后果（Consequences）

- **正面**: 首页与参考读法一致（问候一句、卡内说清哪个文件夹、方角发送）；四枚键（`askAnything`/
  `heroSubtitle`/`askAnythingHint`/`attach`）随改动一起消失，字典不留对已删界面说话的字。
- **负面/风险**: 问候语读的是墙上时钟，widget 测试里 `pump(duration)` 不推进它——换句那条 `Timer` 的
  **观感只能真机走查**（与 ADR-0023 那条"合成指针量不出 hover 时序"同族）；`Greetings.nextBoundary`
  只保证" ahead 且换档"，跨午夜的档位由 `DateTime(day+1)` 的自然进位兜住，已由单测点名。
- **中性**: `Composer` 的卡片树多了一层（chip 成第一行），`chat_view_test` 的轴守卫与放大文本那两档
  都重跑过；hero 两态（选过/没选过文件夹）由 `HeroWorkspacePicker` 那格分派，没有新增第三态。

## 验证（Verification）

- `test/greeting_test.dart` 四棵：24 小时逐小时落且只落一档；六档答六个不同键；`nextBoundary` 恒在未来、
  恒换档、至多 6 小时；12:00→14:00、23:30→次日 05:00（挡住自我重燃的计时器）。
- `test/chat_view_test.dart` 的 `the hero headline says the hour, and only that`：渲染出的标题必须等于
  `enStrings[Greetings.key(Greetings.of(now))]`，且两枚退役旧文案不在树上。**反向验过**：把 `_headline()`
  的取值换回写死的 `'Ask anything'`，当场红在
  `Found 0 widgets with text "Good afternoon! Leave the rest to me."`。
- `test/composer_test.dart` 的 `the card holds its chip and its send` 两棵（真临时目录 + `runAsync`，
  因为 chip 会问 git 要分支）：chip 的字母与字形矩形都被卡的矩形包住、且都在 `EditableText` 之上；
  发送钮**画出来**的 `BoxDecoration.borderRadius` 必须含 `DswShape.control`。**反向验过**：把 chip 挪回
  卡外、半径改回 `DswShape.pill`，两棵各红一处（`Expected: true Actual: <false>` /
  `Actual: [BorderRadius.circular(999.0)]`），恢复后绿。
- 门禁：`dart format --set-exit-if-changed lib test tool spike`（0 changed）、
  `dart analyze --fatal-infos lib test tool spike`（No issues found）、`flutter test`（见登记表回填的数）、
  `dart tool/check_architecture.dart`（七条，只拦新增）。`test/l10n_parity_test.dart` 在删键后仍绿。
- 待 macOS 真机：① 首页问候语在六个时段的实际句子与到点换句；② 卡内 chip 在长文件夹名与长分支名下的
  省略号；③ 方角发送钮在亮/暗两档的观感（ADR-0024 那批"由圆变方"的一处）。

## 关联（Links）

- `docs/hero-parity-zcode-2026-10-03.md`（逐件对照与 file:line 证据；H7/H8 的挂起理由在那里）
- ADR-0034（一枚 `pill` 不许长在会缩水的盒子上）、ADR-0029（shad 只有一枚半径旋钮）、
  ADR-0038（聚焦不再换边）、ADR-0027（样式名不许对字号撒谎）、ADR-0022（一条偏好必须有人读回）、
  ADR-0041（搬一格之前先给它找调用点）、ADR-0050/0051（同一片输入卡的键盘与草稿归属）、
  ADR-0045（额度与账户形状的来源）
- 参考证据：`_archive_project/ZCode-main/packages/ui/src/v4/ConversationDraftEmptyState.tsx`、
  `ConversationComposer.tsx`、`ChatEmptyState.tsx`、`ChatPromptActionMenu.tsx`、`WorkspaceShellLayout.tsx`
