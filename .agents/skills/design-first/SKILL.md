---
name: design-first
description: Shape non-trivial work before writing it — decide the layer, the module, and the seam up front. Use when starting a feature, adding an agent tool or workbench tab, crossing a layer boundary (genkit/model/state/ui/theme/host/l10n), touching a shared reader, or deciding where a seam belongs. Produces a design sketch to approve before implementation, then hands to architecture + testing.
---

先设计形状，再写代码。这一遍的产物是一份**设计草图**，用户批准之前不动手写实现。目标是把**深模块**放在干净的**接缝**上——让调用方获得杠杆、维护者获得 locality、测试获得一个可推压的面。

这是设计遍，不是逐行实现计划。定*代码取什么形状、为什么*；行级规则交给 **architecture**，测试结构交给 **testing**。

## 何时跑

为形状是真决策的工作跑：

- 一个新特性、一个新的 agent 工具（`lib/genkit/tools.dart` 的 `WorkspaceTools`）、或一个新的工作台 tab（`BuiltinTabType` → `tabs/xxx_tab.dart` → `registerTab`）
- 跨层落位：东西该进 `model`（纯 Dart 词汇）还是 `state`（控制器/store）还是 `ui`（界面）——分层是本仓库的第一约束
- 一个改动有**多个读者**（如 `git status` 一份读数喂 git 面板与文件树；`formatToolOutput` 一张卡与右栏共用）——先定"一处答案、多处读者"
- 任何你在选接缝该放哪、或模块该怎么塑形才测试得到的时刻

**跳过并明说跳过**——一行修、放置显而易见的局部 bug 修、不改任何接口的重构。

## 词汇（草图与讨论里精确使用）

- **Module** — 任何有接口与实现的东西：函数、类、库目录。
- **Interface** — 调用方为正确使用它必须知道的一切：签名，加上不变量、顺序、错误模式、必需配置。
- **Deep module** — 小接口后面藏大量行为。这是目标。**Shallow** 模块接口几乎和实现一样复杂——避免。
- **Seam** — 你能不就地编辑就换掉行为的地方；模块接口所在，也是测试替身穿过之处。
- **Adapter** — 在某接缝满足某接口的一个具体东西。

两个检查能定下大多数设计问题：

- **删除测试。** 假想删掉这个模块。复杂度消失 → 它是个 pass-through，别建。复杂度在 N 个调用方重新浮现 → 它值它的存在。
- **接口就是测试面。** 调用方和测试跨同一个接缝。若你需要测到接口*背后*，模块形状就错了——而 per testing，穿过干净接口的测试能在重构后存活。

## 设计遍

### 1. 框定改动

用领域自己的话说这次改动引入的行为。点名它落进哪个层/目录。读相关规则：`.qoder/rules/workflow.md` §0 不变量、§3 对应链路（工具/tab/审批/回退/企划/双树/git status）。

**找最近的良好先例并对齐它。** 代码库几乎肯定已经解决过相邻的东西；定位它*最好*的当前例子并匹配——或有意改进它、说明为什么。仓库自己组织最好的案例比任何规则都强（例：新的 per-conversation store 照着 `state/plan_object_store.dart` 的"一份 map + 订阅引用计数 + 单调 revision"来，别另起一套）。

### 2. 塑形模块

定模块与接缝落点。偏好少而深，而非多而浅。对每个模块点名它的接口——不只是签名，还有调用方必须知道的不变量与错误模式。对任何你怀疑是 pass-through 的东西跑删除测试。

把"代码住哪"作为塑形的一部分来定——一个 **locality** 判断：一起变的东西放一起，让一次改动保持在目录局部。判别式是 **shared vs owned**：

- 一个内聚子系统把它的模型、生命周期、pipeline 作为**一个概念**拥有——放一起，尺寸随变化定（大子系统挣得自己的目录；小补充沿用周边约定）。
- 只有当一块东西**既有自己的生命周期、又有多于一个消费者**时，才把它剥进 **shared** 模块——删除测试定它。
- **如果你说不出某块东西服务哪个关注点，那是个 smell**——它在做两件事，或属于你还没命名的一个概念。

分层事实（哪些是层、哪些是概念、`lib/genkit` 无 Flutter/state、riverpod 只在装配根）见 **architecture** 的 File Organization 一节。**先查有没有现成接缝可复用**——本仓已知的接缝表与"一处答案多处读者"清单见 [references/seams.md](references/seams.md)。

### 3. 为可测试性设计

接缝存在是为了测试能跨它。对每个模块点名它的测试将跨哪个接缝、什么 fake 注入那里（testing 用 `test/fake_*.dart` 手写这些）。三条规则让它可能：

- **接受依赖，别自己造。** 自己构造 transport/client 的模块 fake 不了；收到的能。
- **返回结果，别埋副作用。** 返回值的函数可测；只改共享状态的不可。
- **保持面小。** 更少方法与参数意味着更少测试 setup。

宿主/原生边界特殊：`lib/host/`（git、terminal、reveal、bookmark）背后是真进程/真平台。把接缝放在 Dart 边界*之上*，让逻辑可单测，并为原生路径本身规划一个真跑的证据（`test/git_status_real_test.dart` 是全仓唯一真 spawn `git` 的那棵——普通 `test()` 故不进 FakeAsync）。

### 4. 核对仓库约束

草图之前先解决这些，各有 canon 处，去查别猜：

- **公开面 / provider。** 新东西要走 riverpod 就在 `state/app_providers.dart` 声明并 override 默认体；`lib/genkit/` 不许 import Flutter 或 `lib/state/`（ADR-0015）。
- **工具契约。** 新 agent 工具只在 `tools.dart` 注册一次；是否只读的唯一声明是 `readOnlyToolNames`；审批判定只问 `decideGate`（见 architecture）。
- **多读者。** 改一个共享的东西要问它*所有*的读者（ADR-0035 那条律）——`formatToolOutput`、`git status` 读数、主题令牌都栽过只改一处。
- **依赖/生成器。** 不新增依赖、不加 codegen、不往 `packages/` 塞第二个入库包、不动 entitlements——除非已立 ACCEPTED 的 ADR。

### 5. 写草图并求批准

写一份短草图——散文或要点，不是代码——呈现出来。**用户批准前不要开始实现。**

草图完整当它说清，对这次改动：

- [ ] 每个模块、它的接口、是新建还是修改
- [ ] 每个模块的测试跨哪个接缝、什么 fake 注入那里（原生路径处写"integration/真跑"）
- [ ] 分层落位（进 model / state / ui / genkit / host 哪一层，为什么）
- [ ] 是否触碰 shared 面及其所有读者
- [ ] 你考虑过的一个替代形状及为何拒绝

若解空间宽、最佳接口不显然，动笔前把设计做两遍。

### 6. 交接

批准后，在 **architecture** 约束下实现，在 **testing** 下于本草图点名的接缝写测试。
