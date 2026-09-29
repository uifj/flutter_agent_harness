# ADR-0014: 文件级 checkpoint 与 rewind（B1）

- **状态**: IN-PROGRESS（2026-09-29：S1/S2/S3 的代码与测试均已合入，`flutter test` 得 `+814 -2`（仍是那两条既有失败）、format/analyze/check_architecture 全清；余"带 API key 的真实链路里跑一次 write → 用户改文件 → rewind 被闸门挡住"的人工签收。**本轮另实测**：文档规定的 `dart run spike/runtime_smoke.dart` 当时在本机编译不过（原因先于本 ADR 存在），已立并闭环 ADR-0015 修好，所以这条签收现在只差一把 key）
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 生产功能 / 安全合规（rewind 会改磁盘，误用即毁数据）
- **日期**: 2026-09-29
- **修复 commit**: 70e3206（模型层：`checkpoint.dart` 两个值 + `CheckpointSink`）· f9782a7（存储层 `checkpoint_store.dart` + 23 例文件系统测试 + 备份目录）· 2b0bc24（`write`/`edit` 的截获点与 `checkpoint` 输出）· 5988cfa（`AppScope` 接线与 rewind 门面）· e385f58（顺带修掉 ADR-0005 的 `initState` 依赖断言）· 0ec548d（卡片 pill + 确认框 + 报告 + 9 个双语键）
- **来源**: `docs/zcode-vs-agent-harness-2026-09.md` §7 B1（§9 第 3 步，唯一一项）；评估文档称"这是最能改变产品性质的一项"

## 背景（Context）

**agent 改过的文件目前无处可退。** `lib/genkit/tools.dart` 里两个工具直接落盘：`write` 在 `_guard` 内 `file.parent.createSync` + `file.writeAsStringSync(content)`（`:261-264`），`edit` 在同处 `file.writeAsStringSync(outcome.content)`（`:384`）。两处都是**覆盖写**，唯一的保护是写之前的审批门（`gateFor(ApprovalSubjectKind.filePath, ws.relative(path))`，`:241-252`、`:350-361`）。审批过了、写坏了，用户只能自己去编辑器或 git 里找——而本仓库的工作区**不保证是 git 仓库**（`lib/host/git.dart` 只是宿主能力，UI 有 git tab 不代表用户仓库能被 `checkout` 回滚，且 `GitRepo.checkout` 是用户主动操作）。

**能拦的只有这两处。** 这是本 ADR 最重要的一条事实：
- `bash` 只解析工作目录（`:599`），实际执行走 `Process.start('/bin/bash', ['-lc', …])`（`lib/genkit/shell_run.dart:84-98`）——命令里的 `rm`、`sed -i`、`> file` 全都不经过我们的文件代码，**无法在文件级截获**。
- MCP 外部工具在 `_ToolGate.tool()`（`lib/genkit/agent_runtime.dart:343-386`）只过审批门，它们若在远端写文件，本应用一概看不见。
- `plan_tools.dart` **不落盘**（`todo_write`/`plan` 只改内存字段，`:128`、`:158`）。

所以 checkpoint 是"agent 通过我们的文件工具做的改动"的快照，不是"这一轮工作区的全部变化"。这个边界必须在 UI 上说清楚，否则用户会以为 rewind 能undo `bash` 删掉的东西。

**"是否已被别人改过"必须在恢复前判得出来。** `edit` 的实现已经把这条当成正确性前提：审批暂停后会**重读**文件（`tools.dart:371-378` 的注释写明"the user may have edited the file themselves while the prompt was up, and writing the content computed before that would silently revert them"）。rewind 面对同一个风险，而且更大：它要一次改多个文件、跨越多次改动。没有冲突检测的 rewind 就是数据毁灭器。

**会话归属拿不到现成的 id。** genkit 的工具上下文只有 `context`/`toolRequest`/`resumed`（`genkit-0.16.1/lib/src/ai/tool.dart:25-43`），没有 session id；`AgentRuntime.sessionId` 要到**第一轮持久化之后**才有值（`agent_runtime.dart:900-902`，`startNewSession` 置空、`openSession` 赋值）。Zone 路线（`getCurrentSession()`）机械上可行但本仓库零处使用，且子 agent 委托时它会指向另一个会话（`agent_runtime.dart:747-765`）。已被证明可用的是 holder 模式：`ApprovalModeHolder`（`lib/model/approval_mode.dart:31-33`）、`_StopFlag`、`_GuideHolder`（ADR-0013）。

**diff 计算在本仓库不存在。** `lib/ui/primitives/diff_block.dart` 头部（`:1-10`）明说自己不做 diff——两侧全文并排画；`lib/ui/workbench/tabs/diff_tab.dart:138` 的 `parseUnifiedDiff` 只是**解析 git 输出**。评估文档说 B1 "需要 diff/patch 能力"，但按懒惰阶梯：rewind 的必要信息是"哪些文件、什么状态、会不会覆盖别人的改动"，这些**不需要 diff**；预览文本差异是可选装饰，代价是新增依赖（要走 DEP ADR）或把 git 变成 checkpoint 的运行时前提。

**持久化有既定口径。** 原子写 tmp+rename（`settings_store.dart:63-71`、`approval_rule_store.dart:126-138`）、每会话一个文件 + 防抖（`workbench_store.dart:24-31,100-114`）、按工作区分键的一份 JSON（`approval_rule_store.dart:124-135`）。support 目录由 `main.dart:58` 交出，下面已有 `sessions/`、`workbench/`、`approvals.json` 等（`app_scope.dart:43-45`）。`backup_service.dart:44,56` 的 zip 清单**必须**同时接住新目录——否则"备份后换机"会得到一个没有快照的应用。

## 决策（Decision）

存 **before 镜像**（+ 一份 after 指纹用于冲突检测），不存 shadow git，不存 patch。理由：restore 只需要 before；after 全量镜像只在"同一文件被反复改"时白占盘，而冲突检测只需要它的指纹。blob **内容寻址**（同一份字节只存一次），所以反复改同一文件的 after 字节不重复占盘。

### S1 模型层：两个纯值 + 一个接口（`lib/model/checkpoint.dart`）

```dart
enum CheckpointChange { created, modified }   // 没有 deleted：agent 没有删除工具

class FileCheckpoint {
  final String id;                 // 存储时铸造，UI 与 rewind 都认它
  final String conversation;       // 哪一次会话做的（见 S2 的会话令牌）
  final String? sessionId;         // 一旦持久化会话 id 已知就回填
  final String path;               // 工作区相对路径——与审批面板显示的那串同源（ADR-0012 的同一律）
  final CheckpointChange change;
  final bool captured;             // before 镜像是否真的落盘了（超预算则是 false）
  final String? beforeFingerprint;
  final String afterFingerprint;   // 冲突检测用
  final int beforeBytes, afterBytes;
  final DateTime at;
}

/// 变更探测器，不是安全散列：FNV-1a 64 + 长度，纯 Dart 十余行，无新依赖。
String contentFingerprint(List<int> bytes);

/// genkit 侧唯一的接触点：`lib/model` 定义接口，`lib/state` 实现它，
/// `lib/genkit/tools.dart` 只认这个接口（不变量 1/2 都不破）。
abstract interface class CheckpointSink {
  String? conversation { get; set; }
  FileCheckpoint? record({required String path, required List<int> after, List<int>? before});
}
```

### S2 存储层：`lib/state/checkpoint_store.dart`（implements CheckpointSink）

- 落盘 `<support>/checkpoints/index.json`（按工作区分键的一份 JSON，沿用 `approval_rule_store.dart` 的形状）+ `<support>/checkpoints/blobs/<fp>.bin`。
- **捕获点两处，就在覆盖写之前**：`write` 取"存在则原字节、不存在则 null"；`edit` 取 `current`（`:375` 那份**重读后**的字节，不是 `:328` 的旧读）。`bumpFsRevision()` 旁边就是它的邻居。
- **上限**是简化出来的诚实代价：单文件 before 超过 2 MiB 不存镜像（条目仍记录，`captured = false`），总量超过 64 MiB 从**最旧**条目整条淘汰（连它的 blob）。淘汰只让"能退回去的范围"变小，不破坏任何正确性——rewind 遇到缺失 blob 就把那个文件报成"镜像已不可用"，绝不猜。
- **会话令牌**：`AgentRuntime` 在 `_chat` 诞生处（`_chat ??= _agent.chat()`）铸一个令牌赋给 `sink.conversation`；`TurnFinished` 带回报的 sessionId 一到，就把本次令牌下所有 `sessionId == null` 的条目回填。第一轮因此不会丢归属，也不需要 Zone 路线。
- **rewind 的语义（正确性的核心，逐条都要测）**：`rewindTo(checkpoint, scope)` 表示"把该 checkpoint **之前**的状态拿回来"。
  1. 取范围：`scope == conversation` 只算同一 `conversation` 的条目；`scope == workspace` 算该工作区全部条目。评估文档写的第三个 `both` 是 `workspace` 的超集即它本身，**不做成第三个选项**（三个里有两个同义就是把选择变成噪音）。
  2. 从新到旧筛出范围内、序号 ≥ 目标条目的条目，**按 path 取其中最旧的一条**作为目标镜像——一路倒回，不是把每条都倒一遍（那样等于退到比用户要求的更早）。
  3. **冲突闸门**：该 path **最新**那条条目的 `afterFingerprint` 必须等于当前文件的指纹；不等（或存在性不符）就跳过并报"agent 之外被改过"。这一条是 rewind 唯一的防毁数据机制，不许省。
  4. `change == created` → 删除该文件；`change == modified` → 写回 before 镜像（tmp+rename 原子写）。
  5. 返回 `RewindReport{restored, deleted, skipped[{path, reason}]}`，由 UI 原样说出来——包括最坏的一种：范围里存在 `captured == false` 的文件，明确告知"这些文件的改动无法回退"。

### S3 界面层：把入口长在改动本身旁边

- `write`/`edit` 的返回 map 多带一个 `'checkpoint': id`。这让工具卡片能精确定位条目，**避免按路径猜**（同一文件被改两次时按路径查必错）。多出的这二十来字符是给模型看的，不进 i18n（沿 workflow.md §3 的既有边界）。
- `lib/ui/tool/tool_card.dart`：`write`/`edit` 卡片在 `_body`（`:138-156`）加一枚"回到这次之前"pill（复用 `_InspectPill` 的形状），点击 → `primitives/confirm_dialog.dart` 二次确认（列出将恢复/删除的文件与所有 skip 理由）→ 调 store → 结果用 `ScaffoldMessenger` 报出。
- **评估文档原本要求的 UI（"编辑已发送消息时让用户选 preserve/rewind"）不在本 ADR 范围内**：本应用没有"编辑已发送消息"这条链路（`lib/ui/conversation/message_item.dart:38-81` 的用户气泡是 `SelectableText`，头部注释明说源项目的动作图标"this build does not have yet"）。先做消息编辑再谈它附带的 rewind 选择，是另一个功能。

### 明确不做

- **shadow git / patch 文件**：before 镜像已经能表达"退回去"，patch 只增加一种会失败的格式。
- **文本 diff 预览**：见背景段。升级路径已写在案上——`git diff --no-index` 配 `diff_tab.dart:138` 的 `parseUnifiedDiff`，但那会把 git 变成 checkpoint 的运行时前提，或引一个 diff 依赖（须另立 DEP ADR）。
- **bash / MCP 改动的回退**：做不到，UI 与报告里都明说。
- **自动回退、定时清理策略**：淘汰只有"总量超 64 MiB 从最旧整条丢"这一条规则。

## 后果（Consequences）

- **正面**: agent 的覆盖写第一次有了 undo；"我先让它试，不行就退回我原来的文件"成为可用工作流；冲突闸门 + `path` 与审批面板同源（ADR-0012 的"记住的东西必须与看到的东西一致"）让 rewind 不会静默盖掉用户自己的编辑。
- **负面/风险**: 覆盖面只有 `write`/`edit`，`bash`/MCP 的改动不在其中——用户若误以为能全退，损失比不退更大，所以报告与确认框必须显式说；before 镜像是明文落在 Application Support（与工作区文件同级敏感度，`build.md` §4 已认定该目录可存应用状态），备份 zip 里也会带上；淘汰规则使可退范围随时间收缩。
- **中性**: `WorkspaceTools` 多一个可选协作者（`CheckpointSink?`），与 `rules`（ADR-0012）同形；`lib/model/` 第一次出现"被 genkit 侧实现的接口"，这是不变量 1 的正当用法（接口在 model，实现在 genkit，消费在 state）；`backup_service.dart` 的清单要同时加目录，否则跨机搬迁少一份真值。

## 验证（Verification）

- `flutter test test/checkpoint_test.dart`（S1/S2）：指纹稳定与不同；`contentFingerprint` 对空/二进制一致；`created` 条目 rewind 删文件、`modified` 条目写回原字节；多条同 path 只回最旧那条的镜像且以最新条目做冲突闸门；当前文件被"别人"改过 → skip 并给出理由；超 2 MiB → `captured == false` 且 rewind 报告它；总量淘汰只丢最旧；`conversation` 与 `workspace` 两种范围的边界；sessionId 回填。
- `flutter test test/checkpoint_store_test.dart`：index.json 原子写与重开、按工作区分键、blob 复用（同一字节只存一份）、`backup_service` 的清单含 `checkpoints/`。
- 真实临时目录（而非替身）跑文件系统事实：mtime 之外的存在性/字节级断言，遵 workflow.md §4 的既有约定。
- `write`/`edit` 的工具级测试带出 `checkpoint` 字段；`tool_card` 的 pill 与确认框走 widget 测试（不挂 `AppLocaleScope`，断言英文）。
- 门禁同口径：`dart format --set-exit-if-changed lib test tool spike`、`dart analyze --fatal-infos lib test tool spike`、`dart tool/check_architecture.dart`（新文件不得引入 `lib/ui` 直接 `dart:io`、`lib/model` 不得碰 flutter）、`flutter test` 相对基线（`+781 -2`）零新增失败。
- 带 key 的真实链路：`dart run spike/runtime_smoke.dart` 里跑一次 write → 用户改文件 → 审批 → rewind 被冲突闸门挡住的顺序，待有 key 时人工签收。（该命令本身的可运行性由 ADR-0015 恢复；离线路径已实测跑通。）

## 实施记录（与决策段的偏差）

落地时偏离了上面几处写法，逐条记在这儿，以免下一个读者拿决策段当现状：

1. **`FileCheckpoint` 只有一个 `conversation` 字段，没有 `sessionId`。** 决策段的草图里两者并存。两个必须相等的字段比一个字段多一种错法，所以 `conversation` 做成可变的，由 `adoptConversation(fromToken, sessionId)` 就地改名。
2. **会话令牌由 `AppScope` 铸造，不由 `AgentRuntime`。** 决策段写的是"运行时在 `_chat` 诞生处赋 `sink.conversation`"。实际三个变更点（`newSession` / `openSession` / `onSessionPersisted`）本来就在组合根，运行时再持一份就是第二处真值；`AgentRuntime` 只在工厂里把 sink 交给 `WorkspaceTools`，自己连字段都不留（`check_architecture` 之外也应遵守：能不留就不留）。占位令牌形如 `unsaved-N`，`N` 是本次运行内的会话序号，避免两个新会话共享一份撤销历史。
3. **冲突闸门对 `created` 条目也按 after 指纹比对。** 决策段只说了"不等就跳过"。实施中先写成"`created` 一律放行去删"，随即用测试否掉：用户编辑过的新建文件被删掉同样是毁数据。于是"文件不存在"视为一致（没什么可盖），"存在但内容不符"视为不一致（不删）。
4. **已经不在的新建文件既不报删除也不报 skip。** `RewindReport` 里它不出现——"删除了一个本来就不存在的文件"是一句用户不能相信的报告。
5. **`RewindFile` 携带 `blockedBy`（理由）而不是 `blocked`（布尔）。** 确认框要按文件说"为什么不动它"，只带布尔就得再回 store 查一次，等于两处真值。
6. **第二次点同一枚 pill 会得到"没有可以撤销的内容"**：撤销成功后索引条目仍在，而磁盘内容已不再等于该范围最新条目的 after 指纹，闸门据此挡下。这是设计边界（本特性是 undo，不是时间机器），不是待修 bug。
7. **测试面合并**：`test/checkpoint_store_test.dart` 没有单开，重开/分键/淘汰等并入 `test/checkpoint_test.dart`（23 例，真实临时目录）。工具输出里的 `checkpoint` 字段由 `test/rewind_pill_test.dart`（10 例）从卡片一侧断言，没有 genkit 层的直接调用测试——`WorkspaceTools` 的 `fn` 需要 genkit 的 `ToolCallContext`，为它造替身比它证明的东西贵。
8. **`backup_service.dart` 的清单加 `checkpoints/` 目录，但那一行没有测试**（该文件本来无测试面）。跨机搬迁是否真带上镜像，仍待人工签收。
9. **投递机制新增一个文件** `lib/ui/tool/checkpoint_scope.dart`：`CheckpointScope`（`InheritedWidget`，沿 `DetailsSelectionScope` 先例，riverpod 不许进 widget 树），`ConversationRoot` 多两个可选回调，由 `main.dart` 从 `AppScope` 传入。pill 复用 `_InspectPill` 的形状——实施时把它变成带 `label`/`icon` 参数的 `_QuietPill`，而不是复制一遍这个 widget。

## 关联（Links）

- 代码（实施后）: `lib/model/checkpoint.dart`（`FileCheckpoint` / `contentFingerprint` / `CheckpointSink`）· `lib/state/checkpoint_store.dart`（`record`/`previewRewind`/`rewindTo`/`_targets`/`adoptConversation`）· `lib/genkit/tools.dart:276,405`（两处截获点）· `lib/genkit/agent_runtime.dart:650,739`（sink 只转发给工具）· `lib/state/app_scope.dart:48-55,114-151,322,340,422,431`（开启、令牌、rewind 门面、备份）· `lib/ui/tool/checkpoint_scope.dart` · `lib/ui/tool/tool_card.dart`（`_QuietPill` 与 `_rewind`）· `lib/ui/conversation/conversation_root.dart`（两个回调 + 挂 scope）· `lib/main.dart`（从 scope 传入）
- 代码（决策时的依据）: `lib/genkit/tools.dart:236-274,315-394,599`、`lib/genkit/shell_run.dart:84-98`、`lib/genkit/agent_runtime.dart:343-386,900-902,1246,1262`、`lib/model/workspace.dart:44-115`、`lib/state/approval_rule_store.dart:124-138`、`lib/state/workbench_store.dart:24-31,100-114`、`lib/ui/tool/tool_card.dart:138-156`、`lib/ui/primitives/diff_block.dart:1-10`、`lib/state/backup_service.dart:44,56`
- 关联 ADR: ADR-0012（subject 同源律与 holder 注入形状；`decideGate` 仍是唯一门禁，checkpoint 不参与放行判定）· ADR-0013（`_GuideHolder`/`_StopFlag` 的"先分配再作 plugin 携带"惯例，本 ADR 的会话令牌沿用其精神）· ADR-0009（`AGENTS.md` 注入证明 model→genkit→state 的接口分层可以穿过）· ADR-0002（riverpod import 仍只允许出现在 `main.dart` + `app_providers.dart`）
