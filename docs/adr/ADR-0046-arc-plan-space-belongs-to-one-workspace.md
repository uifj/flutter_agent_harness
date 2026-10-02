# ADR-0046: 企划对象库属于一个工作区（`plan_space.json` 从全局一份改成按工作区分）

- **状态**: PROPOSED（方向由锚点①定案逼出；**待批准的是实施形状**——目录来源、store 生命周期、旧全局文件的迁移去向）
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 评估阻断（发布功能无法界定边界）/ 认知障碍（换项目看到的还是那批集合）/ 幻觉源（文档写"企划 = 当前工作区"，代码里不是）
- **日期**: 2026-10-02
- **来源**: 用户研究锚点定案（`docs/user-research/outline-2026-10-02.md` §10、`docs/user-research/deep-dive-2026-10-02.md` §2/§4/§10、`docs/user-research/bench-2026-10-02.md` §7）+ 竞品实扫
- **修复 commit**: —

## 背景（Context）

**决策的前提**：2026-10-02 用户拍板发布的最小单位是**一个企划 = 一个工作区 = 一个可阅读站点**（参照 [krahets/hello-algo](https://github.com/krahets/hello-algo)：MkDocs + `docs/` + 5 语言 + 130.6k stars），**不是发布单篇 `.md`**。这条前提把下面这个现状从"可接受的观察"变成了"阻断"。

**现状（逐行核实）**：

1. 笔记正文确实共享工作区：企划中列读写的就是文件工具被约束的那个 root——`lib/ui/plan/plan_workspace.dart:11` 的头部注释原话是"`workspaceRoot` the file tools are confined to) — there is no separate vault"，读 `:219`（`File(p.join(root, note.relative))`）、写 `:247`、新建 `:519`/`:528`。工作区只有一个真值：`AppSettings.workspaceRoot`（`lib/model/app_settings.dart:162`），切换只有一条路（`lib/state/app_scope.dart:428`）。
2. **对象库不共享，而且是全局唯一一份**：`PlanObjectStore.open(support, seed: planMockSeed())`（`lib/main.dart:106`）把集合/记录/类型/关系/模板/组件存进 **Application Support** 下的 `plan_space.json`（`lib/state/plan_object_store.dart:95-106`，写盘 `:1211-1213`），启动时 `planObjectStoreProvider.overrideWithValue(planSpace)` **一次**（`lib/main.dart:124`）。切工作区时只有那棵文件树重建（`plan_workspace.dart:111`），store 不动。
3. 笔记在账本里以 **workspace-relative path** 引用（`plan_workspace.dart:82` 注释、`:140`/`:165`/`:185`）。

**三条直接后果**：

- **发布无法界定边界**：要发"这个企划"，但企划的对象集合是跨项目共享的一份，A 项目的集合与 B 项目的记录会混进同一个站点。
- **换项目，集合还是那一堆**，而且默认体带 mock 种子（`planMockSeed()`，`main.dart:106`）——用户看到的是别的项目的演示数据。
- **同名相对路径可能串键**（两个项目都有 `notes/plan.md` 时，全局账本里指向同一个相对键）。这一条**未实测**，但本 ADR 的决策顺带让它不可能发生。

**为什么不能选"个人全局库"路线**：全局库 + 企划级发布 = 每次发布都要用户手工圈"这次算哪几页"，那是把结构缺陷转嫁给用户动作；而按工作区分之后，边界由"你打开了哪个文件夹"这一件本应用已经知道的事给出。

## 决策（Decision）

**1. 对象库按工作区分，落盘位置选 Application Support 的分子目录，不写进用户仓库。**

```
<support>/workspaces/<workspaceKey>/plan_space.json
```

`workspaceKey` 复用 `lib/model/session_groups.dart` 已有的那把规范化键（它已经把 `/private/var` 与 `/var` 合成一个键，ADR-0039）。

备选与取舍：
- **① 写进工作区（`<workspace>/plan_space.json` 或 `<workspace>/.agent_harness/…`）**——好处是随项目走、天然可备份；**否决理由**：它是应用状态不是用户内容，往用户仓库里放一个非内容文件，git 面板与文件树会永远多出一条 `??`（ADR-0043 之后那棵树有"只看变更"，这条脏项会常驻），而且用户提交不提交都难看。本仓库对这件事已有明确立场：**应用状态一律落 support，不往用户工作区写**（ADR-0012 `approvals.json`、ADR-0014 `checkpoints/`、ADR-0039 `sessions/sessions.json`，其中 approvals 已经是**按工作区分键**的同一形状）。
- **② 保持全局一份，发布时手工圈页**——否决，理由见上一节。

**2. 换工作区必须重开 store。** `overrideWithValue` 的一次性接线（`main.dart:124`）改成随 `workspaceRoot` 失效重开；riverpod 读缝沿用既有律——值变更用 `ref.invalidateSelf()`，**不用** `ref.notifyListeners()`（`state/app_providers.dart` 头部与 workflow.md 的"riverpod 读缝"段）。provider 默认体继续 `throw UnimplementedError`，由 `main`/测试 override，不把兜底塞回 provider。

**3. 旧的全局单文件要迁移，而且**要问用户它属于哪个项目**。** 首次以某工作区打开时：若 `<support>/plan_space.json`（v1）存在且目标不存在，则**复制**过去并**保留原件**（读侧宽容、写侧收敛，ADR-0022 的先例）。文档带上 `schemaVersion` 戳——**复用 ADR-0045 PB 给 settings 建立的那套版本化迁移形状**（`lib/model/app_settings_migration.dart`），不另造第二套迁移机制。
迁移目标默认取"最近使用的工作区"，并在设置里可重新分配。**这是本 ADR 实施里最脏的一块**：作者本人（以及任何老用户）的全局库里已经有一堆真记录，机器上可能同时存在多个项目，程序没有资格替用户猜它属于哪一个。

**4. mock 种子只给"从未有过空间的新工作区"。** 现在 `planMockSeed()` 是每次启动的兜底；改后只在目标文件不存在且用户明确同意看示例时播种，并且**在 UI 上标成示例内容、可一键清空**。理由：形态②要给陌生人看发布出去的站点，演示数据混进真数据是最快失去信任的方式。

**明确不做**：
- 跨工作区共享对象库（"个人全局库"路线）——与锚点①正面冲突。
- 协同编辑与云端同步——用户已定不做；本 ADR 只动**本地**落盘位置与生命周期。
- 把 `plan_space.json` 放进用户仓库——见决策 1 的否决理由。

## 后果（Consequences）

- **正面**：企划的边界由"打开了哪个文件夹"给出，发布单位成立；同名相对路径不再可能串键（闭掉背景里那条未实测风险）；删项目/删号时"这个空间的数据"有了明确范围，能一次清干净；备份与导出可以按项目走。
- **负面/代价**：① 多项目用户会看到多个各自为空的企划，需要引导（决策 4 的"示例可一键清空"就是为这一格准备的）；② 迁移要问用户，多一枚一次性对话框与一处设置项；③ store 生命周期从"启动一次"变成"随工作区重开"，所有渲染 store 的面板必须**重新订阅**——这正是 ADR-0037 记过的那条教训（"渲染 store 的面板不订阅 store，就是两份真值"），改的时候要逐面核 listener。
- **中性**：`plan_object_store` 的测试宿主本来就传临时目录（`test/plan_object_store_test.dart:35` 等），改动集中在 `main.dart` 的接线与 provider 生命周期；`workspaceKey` 不新造。

## 验证（Verification）

1. **结构守卫**：`grep -n "PlanObjectStore.open" lib/main.dart` 不得再传 `support`，参数必须是当前工作区根（或由其派生的 `<support>/workspaces/<workspaceKey>`）。
2. **行为守卫（新测试，建议名 `test/plan_space_scoping_test.dart`）**：两个临时目录各开一次 store → 在 A 建集合/记录 → 切到 B 必须看不到，切回 A 必须在。**反向验过**：把目录来源退回全局一份，这条立刻红。
3. **迁移守卫**：v1 全局文件存在 + 首次以工作区打开 → 目标文件出现、**原件仍在**、`schemaVersion` 已戳上；重复打开不二次迁移。
4. **重开守卫**：换工作区后 `planObjectStoreProvider` 给的是新实例（不是旧缓存）——沿用 `test/app_providers_test.dart` 里那种"store→provider 传播"的断言形状。
5. **门禁**：`dart format --set-exit-if-changed lib test tool spike`、`dart analyze --fatal-infos lib test tool spike`、`flutter test` 相对基线零新增失败（基线以现场为准，不抄文档数字）。

## 关联（Links）

- 代码：`lib/main.dart:106`、`lib/main.dart:124`、`lib/state/plan_object_store.dart:95-106`、`:1211-1213`、`lib/ui/plan/plan_workspace.dart:11`、`:82`、`:111`、`:219`、`:247`、`lib/model/app_settings.dart:162`、`lib/state/app_scope.dart:428`、`lib/model/session_groups.dart`（`workspaceKey`）
- 关联 ADR：**ADR-0037**（对象库与"记录是 `PlanStruct` 的视图"，本 ADR 只改它的家在哪）、**ADR-0045**（形态②总纲；PB 批次的版本化迁移形状在此复用）、**ADR-0039**（`workspaceKey` 与 sidecar 按工作区分键的先例）、**ADR-0012/0014**（应用状态落 support、不写用户仓库）、**ADR-0022**（读侧宽容、写侧收敛）、**ADR-0043**（往用户仓库写非内容文件的代价会直接出现在"只看变更"里）
- 研究：`docs/user-research/outline-2026-10-02.md` §10（锚点①②③定案、④待验）、`docs/user-research/deep-dive-2026-10-02.md` §2（"共享工作区"成立与裂缝）、`docs/user-research/bench-2026-10-02.md` §7
