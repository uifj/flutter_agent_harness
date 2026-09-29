# ADR-0015: 把文件系统版本号从 Flutter 里拿出来，恢复"真实链路"这道门

- **状态**: RESOLVED（2026-09-29 两段全落，`dart run spike/runtime_smoke.dart` 重新可跑，规则 6 已在门禁里；余下的只是"带 key 的真实链路"本身需要一把 key）
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 评估阻断（三份 ADR 的验收都挂在它上面）/ 生产功能
- **日期**: 2026-09-29
- **修复 commit**: eb17573（本 ADR）· c2b7c49（S1 计数器迁到 `lib/model`）· 3af1317（S2 第 6 条规则 + 测试并入无债务不变量集合）
- **来源**: ADR-0014 落地期间的实测；已作为 ARC/P1 观察行登记在 `docs/debt-register.md` 的"待立 ADR 的观察"表

## 背景（Context）

**规则里写着要跑的命令，而这条命令跑不起来。** `.qoder/rules/workflow.md` §3「加/改一个 agent 工具」把
`dart run spike/runtime_smoke.dart` 写成工具改动的验收门，`.qoder/rules/build.md` §5 出包清单第 3 条同样列它
（"真实链路冒烟：流式回答 → 工具环 → 审批往返 → 会话从盘上恢复"）。实测：

```
$ dart run spike/runtime_smoke.dart
.../flutter/lib/src/foundation/binding.dart:19:8: Error: Dart library 'dart:ui' is not available on this platform.
```

编译器给出的导入链是逐字可核的（同一命令的 `Context:` 段）：

```
runtime_smoke.dart => genkit/agent_runtime.dart => genkit/tools.dart
                   => state/fs_revision.dart => package:flutter/foundation.dart => dart:ui
```

**先于 ADR-0014 存在，不是那轮改坏的。** 在独立 worktree 检出 `7b02224`（ADR-0014 任何代码进入之前的那个
docs commit）后跑同一条命令，得到同一条 `dart:ui` 报错。

**根因是一处越层 import。** `lib/genkit/tools.dart:31` 是 `lib/genkit/` 里**唯一**一条指向 `lib/state/` 的
import（`grep -rn "import '\.\./state/" lib/genkit/` 只出这一行），它要的是 `bumpFsRevision()`；而
`lib/state/fs_revision.dart:20` 的真身是 `final fsRevision = ValueNotifier<int>(0)` —— `ValueNotifier` 来自
`package:flutter/foundation.dart`。Flutter 的 foundation 层又拉 `dart:ui`，命令行 VM 没有它，于是整个 runtime
在 `dart run` 下不可编译。`spike/agent_spike.dart`（纯 genkit，不碰工具）不受影响，所以这道门的断是最近才显形的。

**代价不止一条命令。** ADR-0012（免问规则生效）、ADR-0013（忙时排队 + 转向）、ADR-0014（checkpoint/rewind）
的交付说明都以"余带 key 的真实链路签收"结尾，而那条签收的载体就是这条命令。门不可跑，三份 ADR 就只能停在
IN-PROGRESS，出包清单第 3 条也只能空着。

**消费者的形状决定了修法有多小。** 读它的地方只有一处，用的只是 `addListener`/`removeListener`：
`lib/ui/workbench/tabs/file_tree_tab.dart:97,104`（`fsRevision.addListener(_onFsRevision)` /
`removeListener(...)`，没有把它当 `Listenable` 传给 `AnimatedBuilder`）。写它的两处是
`lib/genkit/tools.dart` 与 `lib/state/checkpoint_store.dart`，都只调顶层的 `bumpFsRevision()`。
测试侧 `test/workbench_ui_test.dart:28` 用 `resetFsRevisionForTest()`。

## 决策（Decision）

把这一个计数器移到**唯一一层"两边都能碰、且被不变量 2 强制保持无 Flutter"的地方**：`lib/model/`。

### S1 `lib/model/fs_revision.dart`（纯 Dart，十余行）

- `class FsRevision { int get value; void bump(); void addListener(void Function()); void removeListener(void Function()); }`
  + 顶层 `final fsRevision = FsRevision();`、`bumpFsRevision()`、`resetFsRevisionForTest()` —— **三个调用点的写法一字不改**，
  只换 import 路径（4 处：`genkit/tools.dart`、`state/checkpoint_store.dart`、`ui/workbench/tabs/file_tree_tab.dart`、
  `test/workbench_ui_test.dart`），并删掉 `lib/state/fs_revision.dart`。
- 为什么是 `lib/model/` 而不是别处：
  - `lib/host/` 允许 import Flutter（它包 PTY/书签等宿主能力），放进去不等于"无 Flutter"；
  - `lib/genkit/` 自己放不合适——它是被通知方之一，不是文件的属主，且 `lib/state/checkpoint_store.dart` 也要 bump 它；
  - `lib/model/` 有不变量 2 兜着（`grep -rln "package:flutter" lib/model/` 必须为空），并且这条 ADR 落地后它由
    门禁规则 6 再保一遍，所以"这里没有 Flutter"是一个**被检查的性质**而不是习惯。
- 监听者列表用 `List.of(...)` 的快照派发，允许监听回调里 `removeListener`（今天的树重列就是这种形状）。
- 不引入 `StreamController`：那会把 `StreamSubscription` 的取消责任塞进 widget，而当前消费者只有 add/remove 两行；
  也不改成"由调用侧注入回调"（`WorkspaceTools(onFilesChanged: …)`）——为一个计数器多开一条贯穿 `AgentRuntime` 工厂的缝，
  比它要防的耦合更大。

### S2 `tool/check_architecture.dart` 增第 6 条规则

`runtime-does-not-reach-flutter-or-state`：扫 `lib/genkit/`，命中 `^import 'package:flutter`、
`^import 'package:agent_harness/state/`、`^import '../state/` 即为违规。理由：这条链是**静默**断掉的
（编译期才暴露，而编译期只有跑 `dart run` 的人才会碰到），所以必须机器守住；ADR-0011 的分层棘轮正好现成。
实施后违规为 0，`tool/architecture_baseline.json` 的 7 条既有债务不变（只在债务减少时才 `--update`）。

### 明确不做

- **不给 `FsRevision` 实现 `Listenable`**：`Listenable` 是 Flutter 类型，实现了就把 `dart:ui` 又请回来了。
- **不动 `spike/runtime_smoke.dart` 的调用方式**（不改成 `flutter test` 驱动）：它的价值正是"没有 Flutter、没有 UI 也能
  把 runtime 跑起来"，那同时也是这条 ADR 要守的边界。
- **不顺手清理 `lib/state/` 里其他 Flutter 依赖**：store 继承 `ChangeNotifier` 是本仓库的既有形状，与本条无关。

## 后果（Consequences）

- **正面**: 出包清单第 3 条与 workflow.md §3 的命令重新可跑；ADR-0012/0013/0014 的"真实链路"签收有了载体
  （仍需 `DEEPSEEK_API_KEY`，但离线 no-key / 空 store 路径当场可验）；`lib/genkit/` 与 `lib/state/` 之间唯一的
  一条越层 import 消失，并由门禁 6 保持消失。
- **负面/风险**: `fsRevision` 不再是 `ValueListenable`，将来谁想要 `AnimatedBuilder(listenable: …)` 就得自己
  `addListener` + `setState`（今天已经是这个形状）；计数器从 Flutter 的 `ValueNotifier` 变成手写派发，少了一个
  框架保证（`hasListeners`、自动 dispose 检查），换来的是命令行可编译。
- **中性**: `lib/model/` 第一次出现"全局可变单例"（此前的 24 个文件全是值与接口）——它的正当性写在文件头注释里：
  一个工作区文件系统只有一个版本真值，而写它与读它两侧没有共同的持有者。规则 6 是 `check_architecture` 的第一条
  "禁止 import 某个自家目录"的规则，形状与既有 5 条一致。

## 验证（Verification）

- `dart run spike/runtime_smoke.dart`（不带 key）：**必须编译通过并跑完离线路径**——这是本 ADR 的唯一硬指标。
- `dart tool/check_architecture.dart` 报 6 条规则、0 新违规；反向验一次：往 `lib/genkit/tools.dart` 临时加
  `import 'package:flutter/foundation.dart';` → 退出码 1 并指名规则 6，然后撤销。
- `grep -rn "import '\.\./state/" lib/genkit/` 为空；`grep -rln "package:flutter" lib/model/` 为空。
- `flutter test test/workbench_ui_test.dart`（唯一的 `fsRevision` 监听者面）与全量 `flutter test`：相对基线
  （`+814 -2`）零新增失败。
- 门禁同口径：`dart format --set-exit-if-changed lib test tool spike`、`dart analyze --fatal-infos lib test tool spike`。
- 规则与登记：workflow.md §3 与 build.md §5 第 3 条那句"当前在本机编译不过"的警告随本 ADR 闭环改写；
  登记表观察行移入 RESOLVED 并回填 commit。

## 实施记录（实测证据）

- 迁移前：`dart run spike/runtime_smoke.dart` → `Error: Dart library 'dart:ui' is not available on this platform`。
- 迁移后同一条命令（不带 key）跑完离线路径并打印：`sessions in an empty store: 0` / `finished: failed session=null snapshot=null error=No API key set. Open settings and paste the provider API key.`——门恢复了，剩下的只等一把 key。
- 规则 6 的反向验证实测：往 `lib/genkit/read_window.dart` 临时加一行 `import 'package:flutter/foundation.dart';` →
  `NEW VIOLATION runtime-reaches-neither-flutter-nor-state`、退出码 1；撤销后 `architecture OK: 7 recorded, 0 new (122 files, 6 rules)`。
- `grep -rn "import '..\/state/" lib/genkit/` 为空；`grep -rln "package:flutter" lib/model/` 为空；baseline 仍是 7 条既有债务（本 ADR 没有新增豁免，也没消掉旧债务，故未 `--update`）。
- 全量 `flutter test`：`+814 -2`，与 ADR-0014 落地后的基线一致（那两条既有失败未变）。
- 与决策段一致，无偏差：三个调用点（`bumpFsRevision` / `fsRevision.addListener` / `resetFsRevisionForTest`）形状未变，只换 import 路径。

## 关联（Links）

- 代码: `lib/state/fs_revision.dart:1-27`（被移动的文件）、`lib/genkit/tools.dart:31`（那条越层 import）、
  `lib/ui/workbench/tabs/file_tree_tab.dart:97,104`（唯一的监听者）、`spike/runtime_smoke.dart:1-19`（门的用法）、
  `tool/check_architecture.dart:82-126`（规则表）
- 证据: `docs/debt-register.md` 的 ARC/P1 观察行（含 worktree `7b02224` 复跑结论）、
  `docs/zcode-vs-agent-harness-2026-09.md` §9 执行进度表的 B1 行
- 关联 ADR: ADR-0011（棘轮门禁，本 ADR 往上加一条规则）· ADR-0002（`lib/model` 作为运行时与 UI 之间唯一词汇表）·
  ADR-0012/0013/0014（三者都把这扇门当作收尾验收）
