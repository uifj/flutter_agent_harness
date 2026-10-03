# 输入框（composer）与 ZCode 的功能对照与施工表（2026-10-03）

> 目标面：代理模式的用户输入卡（`lib/ui/conversation/composer.dart`，1811 行）。
> 参考实现：`_archive_project/ZCode-main`，composer 的真身**不在** `components/ui/chat-prompt-editor/`，
> 而在 `packages/ui/src/prompt-editor/ChatPromptEditor.tsx`（外壳）+ `packages/ui/src/LexicalChatInput.tsx`
> （编辑器引擎）+ `packages/ui/src/v4/ConversationComposer.tsx`（接线）+ `packages/ui/src/v4/composer/*`（39 个文件）。
> 判据沿用 ADR-0041：**先给功能找调用点，再谈要不要搬**；"词条在、动作没人调"不算功能。

## 0. 一句话结论

卡的**外观、附件、`@` 引用、`/` 命令、投递药丸、模型/模式两枚 chip、窄屏两档让位**我们都已有；
缺的是**键盘语义**——中文输入法的 Enter、忙时主按钮与草稿互相矛盾、Enter 的修饰键反向投递、
以及**历史与草稿的持久化**。所以这一批不是"再画一遍卡"，是把敲键盘这条路对齐。

## 1. 对照表（证据两边都给 `path:line`）

| # | ZCode 的行为 | 我们的现状 | 判定 / 批次 |
| --- | --- | --- | --- |
| C1 | Enter 提交前**两次**挡 IME：`event.isComposing → return false`（`LexicalChatInput.tsx:548-550`）与 `shouldSubmitLexicalEnter`（`:140`） | `_onKeyEvent` 只分 Enter / Shift+Enter（`composer.dart:357-373`），**没有任何 composing 判据** | **缺陷 P1**，本批 C1。Flutter 侧的等价事实是 `TextEditingValue.composing` 非空＝正在组合 |
| C2 | 主按钮：`canStop && !hasDraftToSubmit` 才是 Stop（`ConversationComposer.tsx:1136,2064-2077`）；有草稿时它仍是发送 | `widget.busy` 一律把圆钮变成方块，且 `_onPrimary` 忙时先 `onStop`（`:396-402,896-912`）——**忙时打了字，主钮说的是"停止"**，入队只能去点旁边两枚药丸 | 本批 C2：钮跟着"有没有草稿"走，Stop 只在空盒时出现 |
| C3 | 占位文案随状态换：newTask / followUpAsk / **followUpQueue**（"继续输入可排队"，`chatPlaceholder.ts:18-22`，接线 `ConversationComposer.tsx:1600-1606`） | 静态 `askAnythingHint`（`:784`） | 本批 C3（新键进双语字典） |
| C4 | ↑/↓ 调历史：最近 30 条、按工作区存、只从空盒或浏览态进入、连续重复不入列（`promptHistory.ts:1-28`、`promptHistoryStorage.ts:8,22-24`、`LexicalChatInput.tsx:1073-1077`） | 完全没有 | 本批 C4：`model/prompt_history.dart`（纯逻辑）+ `state/prompt_history_store.dart`（tmp+rename，按工作区分键） |
| C5 | 草稿按会话持久化，含 mention 的 editorState；**附件刻意不存**（`composerDraftStore.ts:1-11,37-38,61-64`） | 切会话即丢（存在 State 里） | 下一批（C5）：文本草稿按会话存，附件照 ZCode 的判词不存 |
| C6 | Cmd/Ctrl+Enter 是**反向投递**：忙时 Enter 排队、修饰键立即送（`LexicalChatInput.tsx:599-617`、`followupModeSettings.ts:18-24,63-83`），tooltip 跟着换字 | 修饰键无意义，忙时 Enter 固定 `queue`（`:376`） | 本批 C6（与 C1 同一处键处理） |
| C7 | 粘贴 ≥ 15366 字符自动转成文本附件，并挡掉编辑器自身粘贴（`chatAttachments.ts:36,127`、`useComposerAttachments.ts:737-782`） | 长文本直接灌进盒里，卡靠 `composerTextMaxHeight` 滚动 | 下一批（C7） |
| C8 | 附件上限 **8** 枚 + 去重 toast（`chatAttachments.ts:35`、`useComposerAttachments.ts:621`）；chip 带上传进度环与失败重试（`ConversationComposer.tsx:1842-1936`） | 无上限；文档 chip 有抽取 spinner、无重试；remove 常驻 | 部分采纳（下一批）：上限 + 失败重试。**进度环记"不适用"**——我们走 `localPath` 零拷贝，没有上传这件事 |
| C9 | 工具栏五档自动折叠 CUA→mode→plan→think→model（`useComposerToolbarFit.ts:27-44`） | 两档地板：`seatsFit 140` / `actionsFit 360`（`:843-849`，红过 67px 之后量的） | **保留**：我们行上只有四件控件，五档是为它六件工具栏设的；地板数由内容决定，不由参考决定 |
| C10 | 上下文/令牌用量表，含分项条与缓存命中率（`contextUsage.tsx:921-982`、`ChatContextUsage`） | 无 | 独立批次：它依赖 ADR-0045 的 `UsageLedger` 接线，不并进键盘这一批 |
| C11 | 语音输入、prompt 增强按钮、字符计数器、卡片超长态 | 无 | **不采**，且**参考自己就没有**：`chat.promptEnhance.*`（`en-US.ts:4629-4639`）零调用点；voice/dictation 在字典里根本没有键；无计数器、卡上无 over-length 态（错误是卡上方另起的块，`ConversationComposer.tsx:2216-2228`）。按 ADR-0041：declared-no-consumer 不是功能 |

## 2. 本批（C1+C2+C3+C6，键盘与投递的一致性）与下一批（C4+C5+C7+C8）

本批改动全在 `composer.dart` 的键处理与两处状态显示，加一条守卫；
C4 另起一片（model 纯函数 + state 落盘 + 接线），因为它要新增两处真值，混进键盘这批会让提交说不清自己做了什么。

**每片都要反向验过**（把缺陷种回去，看守卫是否当场点名）——这条是本仓库对守卫的最低要求，见 `AGENTS.md` §0 与 workflow.md §4。

## 3. 门禁口径

`flutter pub get` → `dart format --set-exit-if-changed lib test tool spike` →
`dart analyze --fatal-infos lib test tool spike` → `flutter test`（基线 `+1324 -2`，
两条已登记失败为 `app_scope_test` 与 `plan_workspace_test`）→ `dart tool/check_architecture.dart`。
新增文案必须 `enStrings` / `zhStrings` 同键（ADR-0008，守卫 `l18n_parity_test.dart`）。
