# ADR-0071: 企划对象库迁入 drift（载体更换，语义不变）

- **状态**: ACCEPTED
- **分类**: ARC（ADR-0060 的 S2 扩展）
- **优先级**: P1
- **影响维度**: 生产功能
- **日期**: 2026-10-04
- **来源**: 用户决策（"企划模式下，相关的也需要存储到 drift 中"）+ ADR-0060 的多域单库路线
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

企划模式有两类持久状态，审计（2026-10-04）确认：

1. **对象库**：`<support>/plan_space.json`（`PlanObjectStore`，1256 行）——objects/collections/types/relations/templates/widgets/bin 七个集合 + revision，**每次变更全量重写整份文档**（`_commit` → `_save`，34 个调用点），原子 tmp+rename，损坏读空、缺失播种 mock。**跨工作区共享一份**（ADR-0046 的 PROPOSED 问题原样保留，本 ADR 不改语义）。
2. **笔记正文**：工作区内的 `.md` 文件（Markdown 是唯一盘上格式，块信封 `<!-- plan:{json} -->`，ADR-0037/0047）——**不动**：那是用户文件，进库等于把用户内容扣在应用私有存储里（ADR-0046 否决项的同一条理由）。

## 决策（Decision）

**对象库迁入 drift：两张表 + 事务式提交；`_commit` 的 34 个调用点与内存模型零改动；旧 `plan_space.json` 一次性导入即删。**

1. **表**（schemaVersion 2→3，`onUpgrade` 补建）：
   - `plan_space_meta`：单行表——`id`（恒 `'space'`）、`revision`、`bin`（JSON 数组）。回收站是 id 集合，一行 JSON 足够。
   - `plan_records`：`kind`（object/collection/type/relation/template/widget）+ `id` + `payload`（JSON）复合主键——六个集合一张表，kind 分区；payload 保留各模型的手写 `toJson`，**不建列级 schema**：这些是 Anytype 语义的 Struct 视图，列化等于把 ADR-0037 的数据模型抄进 SQL DDL，两处真值。
2. **提交即事务**：`_save` 改为 `batch`——upsert 当前全部行 + 删除库中多余行 + 写 meta。内存模型与 34 个调用点不动；小数据量（mock ~百行）下事务内全量对账的成本可忽略，换来的是永不出现"半份空间"。
3. **导入**：open 时若 `plan_space.json` 存在 → 解析入库 → 删除文件（usage 台账同款一次性迁移）；损坏文件删除读种子——"损坏读空"的原语义。**种子语义不变**：库空 + 无旧文件 + 有 seed 才播种。
4. **接线**：`main.dart` 提前开**一个** `AppDatabase`（此前 AppScope 内部自开一个——两连接一文件是隐患），传给 `PlanObjectStore.open` 与 `AppScope`（新参数），`AppScope` 的 `ScheduledTaskStore` 改用传入实例。
5. **明确不做**：列级 schema（见 1）；per-workspace 拆分（ADR-0046 仍 PROPOSED，本 ADR 只换载体不改归属语义——拆分时加 `workspaceKey` 列即可）；`plan_block_document` 的内存 undo 栈落库（会话态）。

## 后果（Consequences）

- **正面**：企划数据获得 schema 版本迁移轴（为 ADR-0046 的拆分铺路）；全文档 JSON 解析从读路径消失；usage/scheduled/plan 三域同库，备份之外的第二道完整性（WAL）。
- **负面/风险**：测试宿主 34 处 `_commit` 的 FakeAsync 语义需复核（写入从文件变 SQL，通知先行的次序保留则无影响）；`plan_space.json` 的手编调试通道消失（换成 sqlite3 CLI）。
- **中性**：`AppDatabase` 提升到 main 开启；备份清单**减**一格 `plan_space.json`（数据进了 planstar.db，备份策略随之要带库——**本批把 `planstar.db` 加进备份清单**，替代旧条目）。

## 验证（Verification）

- `test/plan_object_store_test.dart` 既有断言原样通过（API 不变的证明）。
- `test/plan_space_drift_test.dart` 新增：迁移（旧文件 → 行 → 文件删除）、事务对账（删行）、种子语义、schema 2→3 升级。
- 四道门禁同口径。

## 关联（Links）

- 代码: `lib/state/app_database.dart`、`lib/state/plan_object_store.dart`、`lib/main.dart`、`lib/state/app_scope.dart`、`lib/state/backup_service.dart`
- 关联 ADR: ADR-0060（drift 路线）、ADR-0037/0046（企划数据模型与归属——语义不动）、ADR-0037/0047（.md 与信封不动）
- 来源评估: 用户指令；`docs/kelivo-vs-agent-harness-2026-10.md` §3.5 的 drift 单库参照
