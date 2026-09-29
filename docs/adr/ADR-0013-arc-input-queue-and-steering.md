# ADR-0013: 忙时输入队列与中途转向（A4）

- **状态**: IN-PROGRESS（2026-09-29：S1–S4 的代码与测试均已合入，781 例通过、相对基线零新增失败；余"带 API key 的真实链路里跑一次忙时排队 + 转向"的人工签收）
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 生产功能 / 认知障碍
- **日期**: 2026-09-29
- **修复 commit**: ff85999（模型层 + `TurnSource` 缝）· c916316（运行时注入 + spike probe G）· 850be2a（控制器队列与排空）· 480a1f6（composer 两枚投递钮 + 队列面板 + 双语键）
- **来源**: `docs/zcode-vs-agent-harness-2026-09.md` §7 A4（§9 第 2 步的第三件，也是最后一件）

## 背景（Context）

**跑起来就打不了字。** `lib/state/conversation_controller.dart:67` 的 `isInputBlocked => _isBusy || _pendingApproval != null`，`send()` 第一行就是 `if (isInputBlocked) return;`（`:190`）。UI 侧 `lib/ui/conversation/conversation_root.dart:419` 把它原样喂给 composer 的 `blocked`，composer 在 `lib/ui/conversation/composer.dart:353` 直接 `if (widget.blocked) return;`，发送按钮的 enable 条件是 `widget.busy || (!widget.blocked && hasPayload)`（`:849`）——**busy 时按钮亮着但走的是另一条路（stop）**。净效果：一个跑 20 次工具调用的 agent 回合里，用户想到的修正要么憋着，要么敲了发不出去。评估文档把"跑起来无法干预"与"每次都要点批准"并列为本项目最真实的两个痛点，后者已由 ADR-0012 收口。

**运行时没有转向的入口，但 genkit 有。** `TurnSource`（`lib/model/turn_source.dart:14-44`）只有 `send` / `respondToApproval` / `stop`；一次 run 期间没有任何地方能把新文本交给模型。并发 `chat.sendStream` 也不可行：`AgentChat` 没有互斥（`genkit-0.16.1/lib/src/ai/agents/agent_core.dart:873` 的 `sendStream` 直接建 turn），两次 send 会用同一个 `snapshotId` 各跑各的，`_applyOutput`（`:672`）互相覆盖历史。

**可 genkit 的模型中间件恰好站在正确的位置。** 证据（pub cache 源码，非记忆）：

- `GenerateMiddleware` 有 `model(ModelRequest request, ctx, next)` 钩子（`genkit-0.16.1/lib/src/ai/generate_middleware.dart:56-66`）。
- 工具循环**每次模型调用**都重新构造 `ModelRequest` 并把整条模型中间件链跑一遍（`lib/src/ai/generate.dart:273-305`：`final request = ModelRequest(...)` → `composedModel = resolvedMiddleware.reversed.fold(coreModel, (next, mw) => (r, c) => mw.model(r, c, next))`）。
- `ModelRequest.messages` 是 **可写** 的 json-backed getter/setter（`lib/src/types.g.dart:2159-2197`），`coreModel` 把中间件手上的同一个 `req` 交给 model action（`generate.dart:292-299`），所以就地改 `messages` 会真的到达 provider。
- 下一轮的消息列表取自**被改过的那个请求**：`final newMessages = List<Message>.from(currentRequest.messages) ..add(response.message!) ..add(Message(role: Role.tool, ...))`（`generate.dart:417-421`）。也就是说中途注入的文本**不只影响这一次调用，它会随循环历史一路走到本轮结束并被会话存储持久化**。

**角色相邻是这里唯一真实的坑。** 循环里工具结果是一条 `Role.tool` 消息（`generate.dart:421`）。若在它后面再追加一条独立 `Role.user` 消息，等于向 provider 发两条相邻的非 assistant 消息；Anthropic 系对此最敏感。稳妥形状是**把转向文本作为 `TextPart` 追加到最后一条 `Role.user`/`Role.tool` 消息的 content 里**（tool_result 与附加文本同处一个 user turn 是各 provider 都接受的标准形状），只有当最后一条不是这两种角色时才新开一条 user 消息。

**为什么"到下一次模型调用为止"必须能被回收。** 若 run 已经在流最终回答（不再有模型调用），交给运行时的转向就永远不会被读走——用户输入静默丢失，这是数据丢失级缺陷，不是小毛病。

## 决策（Decision）

沿用评估文档的明确瘦身：**每会话 FIFO、settle 时排空、`queue` 与 `guide` 两种投递语义，不做 epoch/CAS/LRU**（那是跨进程重连的产物，本应用单进程）。

### S1 模型层：一个值，两种去向

`lib/model/queued_input.dart`（纯 Dart，不碰 flutter/genkit）：

```dart
enum InputDelivery { queue, guide }

class QueuedInput {
  final int id;              // UI 的行键与移除目标
  final String text;
  final List<AttachedImage> images;
  InputDelivery delivery;    // 排着的时候还能改主意
}
```

`TurnSource` 加两个方法（仍是纯值签名，不变量 1/2 不动）：

```dart
/// 交给正在跑的 turn：它会在下一次模型调用时读到。没有 turn 在跑则返回 false，
/// 调用方自己把它当成一个 turn 发出去。
bool guide(QueuedInput input);

/// 运行中的 turn 始终没读到的转向，最旧在前；读走即清空。
List<QueuedInput> takeUndeliveredGuides();
```

`QueuedInput` 直接进运行时签名，不再造一个同形影子类型——它的含义就是"等着进模型的一段用户输入"。

### S2 运行时：一个 holder + 一条模型中间件

`agent_runtime.dart` 里按 `_StopFlag`/`ApprovalModeHolder` 的既有惯例（先分配、再作为 plugin 携带）加 `_GuideHolder`：

- `guide(input)`：`_runOpen`（`_turn != null || _pendingInterrupts.isNotEmpty`，**审批暂停也算在跑**）时把 input 放进 holder 并返回 true，否则返回 false。
- `_GuideCapture.model(request, ctx, next)`：`takeAll()` 排空 holder，非空则按上文"追加到最后一条 user/tool 消息的 content，否则新开 user 消息"注入，然后 `next(request, ctx)`。空队列时**一个字节都不改**。
- 中间件只挂在主 `dsh` agent 的 `use` 上，**不挂**委托目标与 side chat：否则子 agent 的一次模型调用会把父会话的转向吃掉。
- 运行结束时没被读走的，由控制器在排空点取回（S3）；**换会话**（`startNewSession()`/`openSession()`）则直接清空 holder——那属于一个正在被丢弃的会话，留着会把上一个文件夹的话注入到下一个文件夹的第一次模型调用里。

### S3 控制器：FIFO 归它，排空点在 `_consume` 之后

- `send()` 不再因 blocked 而 return：**blocked 时进队列**（`queue` 语义为默认），空闲时行为与今天完全一致。
- `send(text, {images, delivery})`（不另起 `submit`：已有的 6 处调用点不必改名字，`delivery` 默认 `queue` 就是旧行为）：`guide` 且 `_runtime.guide(...)` 返回 true → 立即在 transcript 里落一条 `UserMessageNode`（用户必须看得见自己说了什么）；返回 false 则按下面的门落进队列或直接成为 turn。
- **排空点唯一**：`await _consume(...)` 返回之后调用 `_drain()`（`send` 与 `respondToApproval` 两条路径都有）。先 `takeUndeliveredGuides()` 整批插回队首并改成 `queue`，再按 FIFO 逐条发。递归由"只有 `_send` 会被循环调用、而 `_send` 不排空"挡掉，不需要额外标志位。
- **`stop()` 停车而不是放行**：按下停止的人不期望紧接着发出下一条排队消息，所以 `stop()` 置 `_queueHeld`，`_drain` 见到它就停下（队列仍在面板上可见、可改、可删）；用户**再次 send** 时清掉该标志，新消息先发、排队的跟在它后面。
- 不在 `_handle(TurnFinished)` 里排空：那时旧 subscription 还没 settle，`_consume` 会覆盖 `_subscription` 并把新流的通知权弄丢。
- `_reset()`（切会话 / `adoptRuntime` / `startNewSession`）清空队列：**队列属于这个会话**，跨会话残留会把上一文件夹的话发到下一文件夹里。队列不落盘——它是草稿，不是历史（与 ADR-0007"模式刻意不持久化"同理）。

### S4 UI：composer 的门 + 队列条

- `lib/ui/conversation/input_queue_panel.dart`：composer 上方一条紧凑列表，`ReorderableListView`（拖拽改序）+ 每行显示投递语义与可点切换（"排在后面"/"立刻转向"）+ 移除按钮。空则整条不占位。
- `composer.dart` 的发送门改一处：`_submit` 不再 `if (widget.blocked) return`，而是带 `delivery` 交给控制器——**忙时输入不是拒绝，是排队**。blocked 且草稿非空时，主圆圈左边出现两枚带边框的小钮（"排队"/"转向"），主圆圈本身照旧在 busy 时是停止键。`onSubmit` 因此多收一个 `InputDelivery`，全仓库 6 处签名一起改。
- 文案照 §3 规矩同时进 `lib/l10n/locales.dart` 双语字典（`inputQueue`/`queueInput`/`guideNow`/`deliveryQueue`/`deliveryGuide`/`dragToReorder`；移除按钮复用已有的 `removeAttachment`）。

### 明确不做

- **队列持久化**：见 S3。
- **`stop` 之后再排空**：`stop()` 只 `notifyListeners()`，不打断当前 `await`；排空仍由 `_consume` 返回后那一次 `_drain()` 负责，两条路径共用一个出口。
- **给转向做单独的 token/预算统计**：`TurnUsage` 归 turn，不归队列。

## 后果（Consequences）

- **正面**: 忙时输入不再被吞；一条 agent 长回合内可以说"停，先看那个测试"；`guide` 借 genkit 的循环历史一路走到本轮结束并被持久化，模型下一轮仍记得。实测证据（`dart run spike/agent_spike.dart` probe G，2026-09-29）：`per model call, did the request carry the marker: {0: false, 1: true}`、`snapshot files containing the marker: 1`、`chat history carries the marker: false`。
- **负面/风险**: **重启后那条转向不再显示为用户行**（它持久在 `tool` 角色消息里，而 `projectMessages` 只把 `Role.user` 投影成用户节点；`lib/genkit/agent_runtime.dart:1330-1390`）。刻意不去补这条投影：一旦在 `tool` 分支里读文本，任何返回文本 content 的 MCP 工具都会被伪造出一条用户消息。模型侧不受影响——快照里有它。另一个代价是"下一次模型调用"这个时机：纯长回答里 `guide` 与 `queue` 等价。中间件写 `ModelRequest.messages` 依赖 genkit 0.x 的内部形状（`generate.dart:417` 从"被改过的请求"派生下一轮）——升版可能把它变成"每轮重建请求"，届时注入仍在但只影响一次调用。这条依据写进 `spike/agent_spike.dart` 的 FINDINGS，升版必查。转向的可见时机是"下一次模型调用"，纯长回答（无工具调用）里它会等到本轮结束才落地，此时 `guide` 与 `queue` 等价。
- **中性**: `TurnSource` 从 6 个成员长到 8 个，`FakeTurnSource` 跟着补；队列条是 composer 的第一块外部 chrome，为后续（B1 rewind 的入口）腾出位置。

## 验证（Verification）

- `dart run spike/agent_spike.dart`：新增一段用脚本化 model + 工具循环 + `model()` 中间件改 `messages` 的证据，断言第 2 次模型调用收到注入文本、第 1 次没有，且循环把注入带进最终历史。
- `flutter test test/input_queue_test.dart`（14 例，已跑通）：忙时 `send` 入队不发 turn；settle 后按 FIFO 发出；审批暂停时排空停下；`stop` 停车 / 再次 send 放行且顺序为"新的先发、排队的在后"；未读走的 guide 回到队首而非丢失；切会话清空队列；空草稿不进队；`guide` 立即落一条用户节点、无 turn 时降级为普通发送；队列行改语义会自己交接；`moveQueued` 的 off-by-one 与越界索引。
- `flutter test test/input_queue_panel_test.dart`（5 例，已跑通）：空队列不显示标题、每行一条、行可切换投递语义、行可移除、拖拽确实改序（面板不持有自己的列表，一切以控制器为准）。
- `flutter test test/composer_test.dart`：原"blocked 拒发"一条改为三条实况——圆圈在 blocked 时不发（它是停止键）、排队/转向两枚各自投递正确的语义、空闲时两枚都不出现。
- 门禁同口径：`dart format --set-exit-if-changed lib test tool spike`、`dart analyze --fatal-infos lib test tool spike`、`dart tool/check_architecture.dart`（新增文件不得引入 `lib/ui` 直接 `dart:io`）、`flutter test` 相对基线零新增失败。
- `dart run spike/runtime_smoke.dart`（带 `DEEPSEEK_API_KEY`）：真链路里跑一次"忙时排队 + 转向"，待有 key 时人工签收。

## 关联（Links）

- 代码: `lib/model/turn_source.dart:14-44`、`lib/state/conversation_controller.dart:67,186-233,282-299`、`lib/genkit/agent_runtime.dart:169-186,508-720`、`lib/ui/conversation/composer.dart:353,835-860`、`lib/ui/conversation/conversation_root.dart:411-436`
- 外部形状依据: `genkit-0.16.1/lib/src/ai/generate_middleware.dart:56-66`、`lib/src/ai/generate.dart:273-305,417-421`、`lib/src/types.g.dart:2159-2197`、`lib/src/ai/agents/agent_core.dart:873,672`
- 关联 ADR: ADR-0009（指令注入同样走"首条用户消息的前置 TextPart"，本 ADR 的注入形状与它一致）· ADR-0012（审批暂停期间 `guide` 也算在跑，恢复后下一次模型调用读走）· ADR-0002（`TurnSource` 是状态层与运行时之间的窄点，新签名不得带 Genkit 类型）
