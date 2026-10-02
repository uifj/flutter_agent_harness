# ADR-0047: 站点内容是 `.md` 文件，企划是发布清单

- **状态**: PROPOSED
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 幻觉源（文档说"发布企划"，代码里企划与文件互不引用）/ 评估阻断（发布物没有定义就无法实现，也无法验证）
- **日期**: 2026-10-02
- **来源**: 锚点①定案（发布单位 = 一个企划 = 一个工作区 = 一个站点）+ 竞品实扫（Obsidian Publish）+ ADR-0046 的前置发现
- **修复 commit**: —

## 背景（Context）

**缝在哪**：企划面目前是**两套互不引用的真值并排**。

- 中列的 vault 树来自磁盘索引：`_reloadVault()` 调 `compute(indexWorkspace, root)`，筛出 `entry.relative.toLowerCase().endsWith('.md')`（`lib/ui/plan/plan_workspace.dart:132-152`），编辑器读写 `File(p.join(root, note.relative))`（`:219`/`:247`）。
- 集合/记录/类型/关系/模板/组件住在 `plan_space.json`（`lib/state/plan_object_store.dart:95-106`、`:1210-1230`）。
- **记录里没有任何指向文件的键**：`PlanRelationKeys` 的全部字面量是 `name/type/done/assignee/dueDate/status/priority/tags/url/email/phone/emoji`（`lib/model/plan_struct.dart:20-32`），mock 用的 `PlanMockKeys` 是 `status/tags/effort/dueDate/assignee/contact/doc/…`（`lib/model/plan_mock_content.dart:25-34`）；在 `plan_struct.dart`、`plan_all_content.dart`、`plan_object_store.dart` 三个文件里 grep `.md` 与 `path` **零命中**。而 `PlanObject.toJson()` 就是 `{'id': id, ...struct}`（`plan_struct.dart:193`），所以"加一条路径"目前无处可加——它得先被定义成一个 relation key。
- 类型表里**已经有** `ot-document`/`ot-page`/`ot-note`（`lib/model/plan_object_type.dart:13-26` 一族），也就是说模型早就预期"文档是一种记录"，但**没有把记录落到任何一个具体文件上**。

**为什么现在必须答**：锚点①把发布单位定成"一个企划 = 一个站点"（参照 [krahets/hello-algo](https://github.com/krahets/hello-algo)：MkDocs + `docs/` + 5 语言 + 130.6k stars）。这句话在没有映射的情况下有三种互斥读法：站点内容 = 记录、= 文件、= 两者的某种拼接。不选一个，发布功能无法实现，也无法验证。

**竞品事实（Obsidian Publish，2026-10-02 实测可核到的部分）**：官方 pricing 页原文是 **"Publish notes to the web"**、**"No technical knowledge required"**、**"Customizable theme"**、**"Graph and full text search"**，计费是 **"$8 USD" 年付 / "$10 USD" 月付，"Per site, per month"**，无免费试用（仅 7 天退款）。**内容是你本地的笔记，站点是发布出来的结果**——这是它全部设计的前提（Obsidian 本身就是本地 `.md`）。
未核到的部分（今天 `help.obsidian.md` 与 `obsidian.md/publish` 两次抓取失败）：选择模型（哪些笔记进站点）、侧栏是手工分组还是按目录、变更是否以待发布列表显式确认。**本 ADR 的决策不依赖这三条**，但实施前值得复核——已在 §验证 里列为一条。

## 决策（Decision）

**内容 = 文件；企划 = 清单。正文永远只有一份，在工作区里。**

1. **站点页面 = 工作区里的一个 `.md` 文件**，不是记录里的副本。理由：ADR-0037 已钉"Markdown 是唯一盘上格式，没有第二份文档库"，而 agent 与企划编辑器读写的就是这批文件（ADR-0046 背景第 1 条）。**把正文复制进记录 = 当场造出两份必须相等的真值**，这是本仓库反复付学费的那一类（ADR-0014/0022/0035 同族）。
2. **企划（= 站点）是对象库里的一条集合，它的成员记录是"页面条目"**：每条记录通过一条新的 relation `sourcePath`（format = text，值 = 工作区相对路径）指向一个 `.md` 文件。记录负责**元数据**（标题、封面、摘要、是否收录、导航顺序、分组），文件负责**正文**。
3. **站点导航用清单自己的 `navOrder`，不复用视图排序。** `PlanDataView.objectOrders` 是**每个 viewer 一份**的排序（`lib/model/plan_dataview.dart` 的 `PlanDataView`），切视图就变；把它当站点目录会让"你换到 Board 视图，读者的目录就重排"这种荒谬发生。目录顺序属于发布配置，不属于某个视图。
4. **发布是显式动作，带三态差异**：新增 / 变更 / 删除。发布前对每个 `sourcePath` 做一次**冲突检查**（本地文件在标记之后又变过就报出来），这与 ADR-0014 的冲突闸门是同一判据：**宁可什么都不改，也不盖掉别人的编辑**。快照一旦发出就是冻结的（对面 `workspace-shares.route.ts:50-130` 的快照替代实时树已经是这个语义），所以**不做协同编辑不需要任何新机制**。
5. **`sourcePath` 解析不到文件时，页面标"文件缺失"并保留条目**，不静默丢页。静默丢页会让用户以为"发布没生效"，而真相是"你删了那个文件"——这条与 ADR-0043 的判词同源：**静默失效的功能比报错危险**。

**明确不做**：
- 把正文写进 `plan_space.json`（第二份真值，见决策 1）。
- 把清单写进用户仓库（ADR-0046 决策 1 已否决，理由不变：它是应用状态）。
- 站点即文件树的镜像（那样集合/视图/模板全不参与，企划面在发布这条路上就白留了；而且用户删一个临时 `.md` 会意外改掉已发布的站点目录）。
- 实时自动同步发布（决策 4 的显式三态优先；自动同步会把"我本地随手改的东西"推到公开页面上）。

## 后果（Consequences）

- **正面**：发布物有了明确定义（一组 `.md` + 一份清单），可验证；记录与文件之间那条缝用**一个 relation key** 接上，不动内容模型；agent 写 `.md` → 企划组织 → 发布成站点这条闭环第一次真的成立（这是 `bench` §6 说的唯一无人具备的组合）；`sourcePath` 同时是"删项目/删号时清哪些数据"的答案。
- **负面/代价**：① 多一个 relation key，`plan_filter_engine` 与单元格渲染要认它（或把它标成隐藏 relation，不参与筛选）；② 文件被移动/重命名会让条目失效——需要一次"重新定位"动作，或按 ADR-0041 的 `reveal` 那样给用户一个能看见的出路；③ 发布前的冲突检查要求记录"发布时该文件的指纹"，本仓库已有现成形状（`lib/model/checkpoint.dart` 的 FNV 指纹），但那是新增字段；④ 清单与真实文件集不可能永远一致，必须有"缺失"这一态（决策 5）。
- **中性**：`PlanObjectTypeIds.document/page/note` 那几枚早就存在的类型第一次有了实际用法；`PlanCollection.kind` 需要能表达"这是一个可发布的企划"，但**不新增枚举也能做**（用一条 relation 标记即可，避免又造一份封闭枚举——ADR-0037 换内核的理由）。

## 验证（Verification）

1. **模型守卫**：新建一条记录 + 写一个 `notes/a.md` → `plan_space.json` 里该记录含 `sourcePath: "notes/a.md"`，而**文件内容不出现在 JSON 里**（断言 JSON 文本不含正文片段）。反向验过：把正文塞进记录，这条立刻红。
2. **导航不跟视图走**：同一集合切到另一个 viewer（不同 `objectOrders`）后重新生成站点清单，**目录顺序不变**（这条守的是决策 3）。
3. **缺失不静默**：删掉 `notes/a.md` 后生成站点，该页以"文件缺失"出现，条目不消失。
4. **发布三态**：新建/修改/删除各一次，发布前的差异列表点名对应文件；文件在标记后又变过时报 `changedOutsideAgent` 同族的说法（复用 ADR-0014 的判据词，别造第二套措辞）。
5. **复核竞品**：`help.obsidian.md` 的 Publish 三格（选择模型 / 侧栏组织 / 变更确认）今天没抓到，实施前复核一次；若 Publish 实际是"按目录镜像 + 自动同步"，本 ADR 的决策 3/4 要重新对照——**但决策 1（内容 = 文件）不受影响**。
6. 门禁：`dart format`/`dart analyze --fatal-infos`（范围 `lib test tool spike`）+ `flutter test` 相对基线零新增失败。

## 关联（Links）

- 代码：`lib/ui/plan/plan_workspace.dart:132-152`、`:219`、`:247`；`lib/model/plan_struct.dart:20-32`、`:193`；`lib/model/plan_object_type.dart:13-26`；`lib/model/plan_mock_content.dart:25-34`；`lib/state/plan_object_store.dart:95-106`、`:1210-1230`；`lib/model/plan_dataview.dart`（`PlanDataView`/`objectOrders`）；`lib/model/checkpoint.dart`（指纹形状，决策 4 复用）
- 关联 ADR：**ADR-0037**（Markdown 是唯一盘上格式——本 ADR 是它在发布面上的推论）、**ADR-0046**（对象库归属；本 ADR 回答它留下的"边界包含哪几页"）、**ADR-0045**（形态②总纲；发布是外循环的入口）、**ADR-0014**（冲突闸门与指纹）、**ADR-0043**（静默失效比报错危险）、**ADR-0041**（`reveal`：给"够不到那个文件"一个可见出路）
- 研究：`docs/user-research/bench-2026-10-02.md` §2（Obsidian Publish 的已核事实与未核清单）、§6（发布不是收费支点）、`docs/user-research/deep-dive-2026-10-02.md` §4、`docs/user-research/outline-2026-10-02.md` §10
