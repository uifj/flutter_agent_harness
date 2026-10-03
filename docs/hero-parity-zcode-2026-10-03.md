# 首页（hero）与 ZCode 的逐件对照与施工表（2026-10-03）

> 目标面：代理模式的空态首页 + 输入卡（`lib/ui/conversation/conversation_root.dart` 的 `_hero`/`_headline`，`lib/ui/conversation/composer.dart`）。
> 参考：第二张截图（ZCode 深色首页），代码真身在
> `_archive_project/ZCode-main/packages/ui/src/v4/ConversationDraftEmptyState.tsx`（唯一消费者 `SessionPane.tsx:4789`，只在 `isDraft` 时出现）
> 与 `ConversationComposer.tsx` / `ChatPromptEditor.tsx`。
> 判据沿用 ADR-0041：**先给功能找调用点**；截图上有、代码里没有的东西（"150% 配额"那枚 chip）不搬。

## 1. 逐件对照

| # | 参考（file:line） | 我们现状 | 判定 |
| --- | --- | --- | --- |
| H1 | 问候语按时段六档：`ConversationDraftEmptyState.tsx:29-35`，边界小时 `[5,9,12,14,18,23]`（`:14`），并 `setTimeout` 到下一个边界自己重绘（`:38-52,91-99`）；字号**不是固定值**——用隐藏 span 量 `text-3xl` 再夹到 20–30px（`:15-16,54-78`），`font-medium`、行高 1.2、`text-foreground` | 静态标题 `askAnything`（"随便问点什么"）+ 一行副标题（`conversation_root.dart:272-298`） | **采纳**：`lib/model/greeting.dart` 纯函数（时段→键、下一边界），hero 用它；副标题照参考去掉（参考的 header 块里只有 logo 与问候语） |
| H2 | 工作区 chip 在**卡内**、文本框之上：作为 `contextHeader` 传进 composer（`WorkspaceShellLayout.tsx:1168-1187` → `SessionPane.tsx:4382` → `ConversationComposer.tsx:2235-2238`，槽 `p-1.5 flex min-w-0 flex-wrap gap-0`），组件 `ChatEmptyWorkspacePreviewMenu`（`ChatEmptyState.tsx:169`，容器 `rounded-full hover:bg-surface-hover`、尾随 `ChevronDownIcon size-3.5`、悬停才现的 detach X），与 `GitBranchSwitcher` 并排 | 工作区状态条在卡**下方**（`composer.dart:699-703,1054-1121`），hero 另有一枚居中 picker（`HeroWorkspacePicker`） | **采纳**：把状态条搬进卡内第一行（两态都在），hero 只在**还没选过文件夹**时保留那枚 picker——参考的 chip 需要一个名字才成立 |
| H3 | 占位文案教 `@` 与 `/`：`chat.placeholder.newTask`（zh `zh-CN.ts:4264`、en `en-US.ts:4560`），纯字符串（`chatPlaceholder.ts:19` 选键，`@`/`/` 另有独立按钮 `:2270-2273`） | `askAnythingHint`＝"输入问题，或描述一个任务" | **采纳**：换文案（应用名用我们自己的），双语同键 |
| H4 | 发送钮：`size="icon-md" rounded-lg bg-brand hover:bg-brand/80` + `ArrowUpIcon size-4`，pending 换 `Spinner`，停止换 `SquareIcon fill-current` + secondary 皮（`ConversationComposer.tsx:2064-2097`） | 圆形（`BoxShape.circle`）蓝底白箭头，停止换方块 | **采纳形状**：圆角方（`DswShape.control`），与 ADR-0024"那个家族里没有圆形"同判词 |
| H5 | 工具栏左簇第一件是 `+`（`PlusIcon size-4`，`ChatPromptActionMenu.tsx:252-259`，标题"添加上下文"），其后才是 mode 芯片（`ChatPromptEditor.tsx:392,406-411`；顺序由 `:406` 的注释钉住） | 一枚回形针（paperclip）开附件菜单 | **采纳**：字形换 `+`、标题照参考叫"添加上下文"；菜单内容仍是我们真有的那几项（参考列的 `/goal`、插件组我们没有，不虚构） |
| H6 | 容器节奏：`max-w-2xl` + `gap-6` + `mb-10 sm:mb-8`（`:170-176`），卡本身复用同一个 `ConversationComposer`（`centered` → `max-w-2xl`，`:2205`），**不另画一张卡** | hero 是 `Center` + 自算宽 + 8px 间距（`conversation_root.dart:244-265`） | **采纳**：间距按参考（问候→卡 24px），卡仍是同一个组件 |
| H7 | 额度横幅：`ConversationQuotaBanner.tsx`，状态来自 `useV4SessionQuotaBanner` + `sessionQuotaBannerState.ts:29-52`（`visible/kind/modelName/remainingPercent/dismissible/blocksSubmit/priority`），消息表 `:11-35`，升级药丸 `CodingPlanEntryButton` + `RocketIcon`，只在 `dismissible` 时给 X | `lib/model/zcode_compat/zcode_account.dart` 已有 `UsageQuotaSnapshot` 形状，**零读者** | **本批不做（待数据）**：横幅要的是读者，不是形状——`ZcodeUsageQuotaSnapshot`（`lib/model/zcode_compat/zcode_account.dart:77`）在生产代码里**零读者**（`grep -rn "ZcodeUsageQuotaSnapshot" lib test` 只命中该文件与 `test/zcode_compat_test.dart:155` 的往返），`state/auth_session.dart` 也不返回它。在没有快照的面上画一枚永远隐藏的横幅，正是 ADR-0041 判过的"声明了但没有消费者"。截图里那枚"150% 配额" chip 在参考代码里**找不到**（`150%`、`配额`、`multiplier|bonusPercent|quotaPercent|ratioLabel` 全仓 grep 无命中）→ 不搬 |
| H8 | 模型右侧两枚：`ChatContextUsage` 环形用量表（`V4ComposerToolbar.tsx:1013-1022`，实现 `contextUsage.tsx:235`）与 `ThoughtLevelCycleControl`（"最高"，`ThoughtLevelCycleControl.tsx:31,199-231,305-308`，写 `reasoningLevel`，级别表 `:1002-1006`） | 只有模型芯片 | **待数据**：本轮 token 数**已经有了**——`turn_event.dart:127-160` 的 `TurnUsage.inputTokens`（运行时 `agent_runtime.dart:243-246` 从 provider 的 usage 块累加，`conversation_controller.dart:184-185` 汇总）。缺的是**分母**：`model/known_models.dart` 没有"模型上下文窗口"这一档，环形表算不出百分比；而 `reasoningLevel` 也没有进请求的通路。先接就是假开关（ADR-0022 那条律），等 ADR-0045 的后端契约回这两项再接 |

## 2. 批次与落地状态

- **第一批 H1–H6（本次，已落）**：首页的读法与卡的骨架。表里"我们现状"那一列写的是**改动前**的
  `file:line`，留作证据用，不要当成现在的地图。
  改动落 `lib/model/greeting.dart`（新增）、`conversation_root.dart`（headline + 换句 Timer）、
  `composer.dart`（chip 进卡、占位文案、发送钮半径、`+` 与"添加上下文"）、`locales.dart`
  （六句问候 + 两枚新键进来，`askAnything`/`heroSubtitle`/`askAnythingHint`/`attach` 四枚键没人读了，
  连值一起删）。
  守卫七棵，逐棵反向验过：`test/greeting_test.dart`（四棵纯函数）、
  `test/chat_view_test.dart` 的 `the hero headline says the hour, and only that`
  （把取值换回写死的 `'Ask anything'` 即红）、`test/composer_test.dart` 的
  `the card holds its chip and its send` 两棵（chip 挪回卡外、半径改回 `DswShape.pill` 各红一处）。
  门禁：format 0 changed / analyze `No issues found` / `flutter test` `+1336 -2`（那两个失败仍是
  `app_scope_test` 与 `plan_workspace_test` 的既有基线）/ `check_architecture` `7 recorded, 0 new`。
  决策与后果记在 **ADR-0052**。
- **第二批 H7（本批不做，待读者）**：额度横幅的形状齐、数据源缺。接法只有一条——ADR-0045 的后端契约真的
  往 `AuthSession` 回一份 `ZcodeUsageQuotaSnapshot`，然后照参考的状态机（`sessionQuotaBannerState.ts:29-52`）
  做 `visible/kind/blocksSubmit/dismissible`。没有快照就整面不画，不画一枚永远隐藏的横幅。
- **H8 挂起（待分母）**：`TurnUsage.inputTokens` 已是真值，缺模型上下文窗口与 `reasoningLevel` 通路；
  先立 ADR 再接芯片。
- **待 macOS 真机走查**：六档问候语的实际句子与到点换句、卡内 chip 在长名下的省略号、方角发送钮两档明暗观感。
  换句那条 `Timer` 在 widget 测试里量不到（`pump(duration)` 不推进墙上时钟，与 ADR-0023 那条同族），
  所以它只有真机这一道门。


## 3. 复核补记（落地之后第二次逐像素看图）

改完之后把参考那张截图裁成两条放大重看，两处新东西，各自有了断：

- **草稿区外面那圈发丝边**（chip 之下、占位文字与工具栏所在的那个圆角盒）。参考的卡是
  `chat-composer-input-surface w-full` + `rounded-2xl bg-surface shadow-xl/5`
  （`ConversationComposer.tsx:2230-2233`，`rounded-2xl` = 我们的 `float` 档，已一致）；
  但那枚 `chat-composer-input-surface` **在整个归档里只出现这一次**——
  `grep -rln "chat-composer-input-surface" .` 只命中 `ConversationComposer.tsx`，
  `grep -rn "input-surface" --include=*.css .` 零命中。也就是说这圈边由一份我们手上没有的样式表画的，
  它的形状/色档无从取证。按 ADR-0041（"上游有"既不是"上游能用"也不是"我们缺"）**不搬**；
  而且本仓库对"键盘在谁那里"只有一枚答案——卡的那道边（ADR-0038 明确把聚焦态的第三色收回来了），
  再套一圈就是同一句话答两遍。要搬的前提是拿到真值（那圈边的 radius 与色档），不是照截图猜一个。
- **发送钮空草稿时是灰的**。这一条查下来**不是差异**：参考也从不为禁用换填充
  （`ConversationComposer.tsx:2086-2093` 只有 `bg-brand` + `disabled={!canSend}`），
  灰是共享 Button 的禁用样式在起作用。我们的同一格由 shad 的 `ShadDisabled` 读主题 `disabledOpacity`
  （40%）表达，机制同类。留在这里是为了让下一个人不必再为它开一次对照。
- **问候语背后那枚大字标**（读代码才找到的那一格：`ConversationDraftEmptyState.tsx:178-187` 把它绝对居中在
  header 之后，`w-[min(72vw,25rem)]`、`aspect-[5/4]`、`text-foreground-subtlest`，亮色档再叠
  `opacity-70` 与一条到 70% 高度就透明的纵向遮罩）。**不搬，因为可搬的部分不是截图上那件东西**：
  亮色档是**它们字母形的线框**（`:216-236` 内联 `<svg>`，一条 `Z` 的路径描 `currentColor`），
  暗色档是**另一份自带渐变与模糊的资源**（`:237-244` 的 `<img src={darkEmptyStateLogoUrl}>`，注释自己写着
  "深色资源包含专用渐变与模糊效果，不能通过 currentColor 复刻"；那份资源在归档里，
  `packages/ui/src/assets/Z.svg`，由 `:8` 引入）。**两档都是它们的字母形**，所以不搬的理由不是拿不到，
  而是**那是另一个产品的商标**：把它铺在我们的首页当水印，是身份与许可的决定，不是移植（最近的先例是
  ADR-0001 对 vendored 资源的那条判词）。要这层氛围，形状得是我们自己的标识——那时它落在这个位置上
  （`_headline` 之后、Stack 的底层、`aria-hidden` + 不吃指针 + 一条纵向渐隐遮罩）。
  判词与 ADR-0041 同一条：**先确认搬过来的是那个东西，再确认搬得起。**
