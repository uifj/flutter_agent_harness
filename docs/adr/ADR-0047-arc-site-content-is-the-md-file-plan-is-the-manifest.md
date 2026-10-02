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

## 追记（2026-10-02）：对照 GitHub 上的发布项目之后，三条调整

本轮实扫四个"内容在仓库里、站点从内容生成"的开源先例（MkDocs / mdBook / Docusaurus / Obsidian Publish）。**决策 1（内容 = 文件）被全部四个支持，不动**；决策 2/5 需要调整，另有一条本 ADR 原本没答的问题被它们答了。

| 项目 | 内容真值 | 清单 | **清单外的文件** | 页级元数据 |
| --- | --- | --- | --- | --- |
| **MkDocs** | `docs_dir` 里的 `.md` | `nav:` 是一枚独立清单；省略则按目录字母序自动列，index 文件领头 | **仍会渲染、仍可用 URL 直达，只是不进侧栏与上下页** | front matter（YAML 或多标记）可设 `template`/`title`；显式 `nav` 覆盖它 |
| **mdBook** | `src/*.md` | **`SUMMARY.md` 必需**——原文："Without this file, there is no book" | **不参与编译**（builder 只读清单） | 无页级配置；但**清单条目可以没有路径**（`[Draft Chapter]`） |
| **Docusaurus** | `docs/` 里的 `.md` | `sidebars.js`：autogenerated（"each folder creates a sidebar category, and each file creates a doc link"）或显式 items | — | 页级 front matter（`sidebar_position` 等）——**细节今日未核到官方页**，只从 issue 标题与 plugin 页得知键存在 |
| **Obsidian Publish** | **本地笔记**（pricing 页原文 "Publish notes to the web"） | 站点即发布结果，按站点计费 | 未核（help 页今日抓不到） | 未核 |

### 调整一（新增决策 6）：清单外的 `.md` **不进站点**——取 mdBook 式，不取 MkDocs 式

本 ADR 原文没答"工作区里有 `.md` 但没进清单"这一格。两个先例给了相反的策略，而**只有一个对我们成立**：MkDocs 的"渲染但不出现在导航"对静态文档站只是发现性损失；但我们的发布是**显式动作、站点公开且 URL 可直达**，"目录里没有但链接能打开"就是**假私密**——用户会以为那页没发出去。所以：**只有清单里的页参与发布；不在清单里的文件在站点上不存在（404）**，与 mdBook 同。这条也正好回收了"不做文件树镜像"那条否决的理由：用户随手放的临时 `.md` 不该出现在站点上，也不该因为被删而改动已发布目录。

### 调整二（决策 5 升级成两态）：清单里**允许还没有文件的页**

mdBook 的 `[Draft Chapter]`（条目无路径）是成熟用法，所以"解析不到 `sourcePath`"不该只有一种解释。改成两态：**未落地**（条目建了、文件从没写过——这是草稿，正常态）与**已失效**（文件曾经存在、现在没了——这是异常，要点名）。措辞沿用 ADR-0014 已有的那族词（`imageUnavailable` / `changedOutsideAgent`），**不造第三套说法**。

### 调整三（决策 2 的理由改写 + 一条待办）：元数据住 `plan_space.json` 是被编解码器逼的，不是偏好

本轮新查到的事实：**`plan_markdown_codec.dart` 不认 front matter**——`---` 被当成分隔线（`:238` 写、`:353` 读，`___` 同），全仓 `grep -niE frontmatter lib test` = **0**。也就是说今天把 `sidebar_position`/`title` 这类写进 `.md` 头部，块编辑器会把它读成"一条分割线 + 若干段落"，**往返就吞掉**。所以决策 2 不是"我们偏好对象库"，是"文件头这条路今天走不通"。

代价必须写清：**发布出去的站点不能直接喂给 MkDocs / Quartz / Docusaurus**——front matter 恰恰是这一族工具的共同语言，而我们的元数据在应用目录里。可移植性归零不是抽象损失：它意味着用户想换托管方式时带不走结构。

**待办（已登记进 `docs/debt-register.md` 观察表）**：若要让企划面与静态生成器互通，第一件事不是写导出器，而是**让 codec 认 front matter 并保证往返逐字节不变**，守卫形状：读入一段带 YAML 头的 `.md` → 编辑任意块 → 写回 → 断言头部字节相同。这件事做完，页级元数据才谈得上搬到文件里去；届时决策 2 要重开一次 ADR。

### 未核清单（别当已知）

Docusaurus 的页级 front matter 键集与语义、Quartz 的 `publish` 键、Obsidian Publish 的选择模型/侧栏组织/变更确认——今日均未抓到官方页，标未核。**它们只影响调整一的细节（要不要给"隐藏但可直达"留一档）与决策 2 的未来形态，不影响决策 1 与调整一的结论。**

