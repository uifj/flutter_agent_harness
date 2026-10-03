# ADR-0050: 输入框的键盘语义——IME 与忙时主按钮

- **状态**: ACCEPTED
- **分类**: DEF（功能缺陷）
- **优先级**: P1
- **影响维度**: 生产功能 / 认知障碍
- **日期**: 2026-10-03
- **来源**: 用户要求对照 `_archive_project/ZCode-main` 补齐代理模式输入框；逐行对照见 `docs/composer-parity-2026-10-03.md`
- **修复 commit**: 89b20b7

## 背景（Context）

两条缺陷，都在"敲键盘"这条路上，且都影响中文用户日常。

**一、输入法组合中的 Enter 会把半条草稿发出去。**
`lib/ui/conversation/composer.dart:357-373` 的键处理只分三件事：Escape 关菜单、Enter 提交、
Shift+Enter 交给编辑器换行。没有任何"正在组合"的判据。参考实现把这件事挡了两次：
`LexicalChatInput.tsx:548-550` 的 `if (event.isComposing) return false`，加上
`:140` 的 `shouldSubmitLexicalEnter`。在 macOS 的拼音/仓颉候选里按 Enter 是**选词**，
不是发送——我们当前会在用户选词那一刻把已经落进盒里的那半句提交给模型。
Flutter 侧的等价事实是 `TextEditingValue.composing`：组合区间非空即"正在组合"。

**二、忙时主按钮说的和盒子里的东西相反。**
`composer.dart:396-402` 的 `_onPrimary` 在 `widget.busy` 时**一律**先 `onStop`；
`:896-912` 的 `_primary` 同样只看 `busy` 就把圆钮换成方块。于是转圈期间用户打了一段字，
主钮的 tooltip 是"停止"，按下也是停止——而这段草稿本该能发（本项目 ADR-0013 的整条设计
就是"忙时输入只有一个出口"，旁边还摆着排队／转向两枚药丸）。
参考的判据是 `canStop && !hasDraftToSubmit`（`ConversationComposer.tsx:1136,2064-2077`）：
**盒里有草稿时主钮是发送，空盒才让位给停止**。这不是审美差异，是同一枚钮在两种事实里
选了错的那个：用户已经写了字，"停止"就不是他此刻的意图。

顺带第三条同类问题：参考的修饰键投递是反向的——忙时 Enter 排队、Cmd/Ctrl+Enter 立即送
（`LexicalChatInput.tsx:599-617`、`followupModeSettings.ts:18-24,63-83`），tooltip 跟着换字。
我们 Enter 固定走 `InputDelivery.queue`（`composer.dart:376`），修饰键无意义：想立刻送只能
去点旁边那枚"立即转向"，而键盘用户不会中途离开键盘。

## 决策（Decision）

1. **Enter 前先问"在组合吗"**：`_controller.value.composing` 非空即把这次 Enter 让给编辑器
   （返回 `ignored`），与 Shift+Enter 同一条出口。判据取框架事实，不取"看起来像不像中文"。
2. **主钮跟着草稿走**：`_hasPayload` 为真时它永远是发送/入队，只有空盒且 `busy` 才是停止。
   停止这件事另有两条路（Esc 与空盒主钮），不会因为写了字就消失。
3. **忙时的 Enter 排队、Cmd/Ctrl+Enter 立即转向**，tooltip 同步换字；空闲时 Enter 就是发送。
   这条把参考的反向投递照搬过来，因为它解决的正是本项目"忙时输入只有一个出口"要的那个
   用户动作——不离开键盘就能表达"排到后面"与"现在就插进去"。
4. **占位文案随状态换**：忙时不再问"随便问点什么"，而是说明"继续输入会排队"（新键进双语字典）。

不做的：不把 CUA/plan/think 那套五档工具栏折叠搬过来（我们行上只有四件，两档地板是量出来的，
见对照表 C9）；不在这一批动历史与草稿持久化（C4/C5 另片，因为要新增两处真值）。

## 后果（Consequences）

- **正面**: 中文输入法可以正常选词而不误发；忙时"写着字按主钮"从"停掉这一轮"变成"把这段发出去"，
  与 ADR-0013 的排队/转向语义对齐；不离开键盘就能选投递方式；占位文案说的是当下会发生什么。
- **负面/风险**: 忙时空盒的主钮仍是停止——用户若想中止而盒里恰好有草稿，得先清空或用 Esc；
  这是参考同一条取舍，写在这里而不是藏起来。Cmd/Ctrl+Enter 是新增的键盘面，需要真机走查一眼。
- **中性**: 键处理集中回一个函数（原本也是），三处判据（组合、修饰键、有没有草稿）都在同一处，
  下一次加快捷键时有唯一的地方要改。

## 验证（Verification）

- 守卫：`test/composer_test.dart` 新增四棵——组合中 Enter 不提交、Shift+Enter 仍换行、
  忙时有草稿时主钮是发送且空盒时是停止、忙时 Enter 排队而 Cmd+Enter 转向；
  每棵都**反向验过**（把判据种回去必须红并指名）。
- 门禁：`dart format` / `dart analyze --fatal-infos lib test tool spike` / `flutter test`
  （基线 `+1324 -2`，零新增失败）/ `dart tool/check_architecture.dart`。
- 待 macOS 真机：拼音候选下按 Enter、忙时 Cmd+Enter 两眼的实际手感。

## 关联（Links）

- ADR-0013（忙时输入只有一个出口）、ADR-0010（图片能力门）、ADR-0038（卡片两态描边）
- `docs/composer-parity-2026-10-03.md`（C1–C11 全表与批次切分）
- 参考证据：`_archive_project/ZCode-main/packages/ui/src/LexicalChatInput.tsx:140,548-550,599-617`、
  `packages/ui/src/v4/ConversationComposer.tsx:1136,2064-2077`、`packages/ui/src/v4/composer/followupModeSettings.ts:18-24,63-83`
