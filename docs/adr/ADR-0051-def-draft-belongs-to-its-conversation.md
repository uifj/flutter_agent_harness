# ADR-0051: 草稿属于它被敲进去的那场对话

- **状态**: ACCEPTED
- **分类**: DEF（功能缺陷）
- **优先级**: P1
- **影响维度**: 生产功能 / 认知障碍
- **日期**: 2026-10-03
- **来源**: 对照 ZCode composer 的补齐批次（`docs/composer-parity-2026-10-03.md` 行 C5）
- **修复 commit**: f249944

## 背景（Context）

输入卡**跨会话活着**：`ConversationController` 是复用的（`openSession` / `startNewSession` 只是
`_reset()` 内部状态），`ConversationRoot` 里的 `Composer(key: _composerKey)` 用的是稳定的
GlobalKey，所以换会话时那张卡不会被重建。于是：

- 在 A 里打了半句、贴了两张图，点侧栏切到 B —— 那半句和那两张图**跟着到了 B**，在 B 里按发送就进了 B 的转录。
- 反过来，从 B 切回 A，A 原本没写完的草稿**没了**（被 B 的内容覆盖）。

参考实现把这件事当成一等状态：草稿按会话作用域存（`composerDraftStore.ts:1-11,37-38,61-64`），
连 mention chip 一起存，而**附件刻意不存**。本仓库的队列语义早已承认"草稿是有主人的"——
`ADR-0013` 写明排队输入"换会话随 `_reset()` 一起丢"——只有输入框本身没跟上这条。

## 决策（Decision）

`Composer` 新增一个 `draftScope`（宿主传 `conversation.sessionId`，未落盘的新会话为 null），
换 scope 时**交换而不是合并**：把当前文本与附件按旧 scope 存下，再把新 scope 存的那份装回来；
菜单的"这次 token 已被 Esc 关掉"也随草稿一起重置（那是那条草稿的事）。

存在哪：**State 里的一张内存 map**，不做落盘。理由写在这里而不是留给下一个人猜——草稿要活过一次重启，
就需要一个 store、一个备份 zip 里的位置（ADR-0045 的 `backup_service` 清单要跟着改）、以及一条
"我刚才正在打字"给不出的持久化理由；而跨会话不串味这件事，内存 map 已经完整解决。
参考刻意不存附件这一条我们照做（scope 里的附件只在本次运行内跟着走）。

## 后果（Consequences）

- **正面**: 换会话不再把半条消息和它的图片送进别人的转录；切回来草稿还在；`hero` 与停靠两态共用一个 GlobalKey，State 随元素重挂而非重建，所以两态之间也不丢。
- **负面/风险**: 退出应用仍会丢草稿（有意的边界，见上）；`sessionId` 在首次持久化后才出现，所以"新会话发出第一条"之后 scope 从 `__new__` 变成真 id——那一刻盒子里刚好被 `_submit` 清空，不会把 A 的草稿挂到 B 的 id 上。若将来首条发送前就换会话，需要把 `__new__` 那份跟着 id 迁移。
- **中性**: `Composer` 的 widget 面多了一个必填语义（宿主不传就是"永远同一作用域"），`conversation_root.dart` 是唯一传它的地方。

## 验证（Verification）

- `test/composer_test.dart` 的 `a draft belongs to the conversation it was typed in`：A 打草稿 → 切 B 必须空 → 切回 A 必须还是那句。**反向验过**：把交换短路（`if (true) return;`），当场红在 `Expected: empty / Actual: 'for A'`。
- 门禁：`dart format` / `dart analyze --fatal-infos lib test tool spike` / `flutter test`（基线 `+1328 -2`）/ `dart tool/check_architecture.dart`。
- 待 macOS 真机：两条会话之间来回切，看草稿与图片是否各回各家。

## 关联（Links）

- ADR-0013（忙时输入只有一个出口——"换会话一起丢"那条判词的出处）、ADR-0050（同一片键盘面）
- `docs/composer-parity-2026-10-03.md`（C4/C7/C8 仍是下一批）
- 参考证据：`_archive_project/ZCode-main/packages/ui/src/v4/composer/composerDraftStore.ts:1-11,37-38,61-64`
