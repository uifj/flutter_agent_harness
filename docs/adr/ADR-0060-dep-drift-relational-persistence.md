# ADR-0060: 引入 drift 作为关系型持久化引擎（S1：usage 台账迁库）

- **状态**: ACCEPTED
- **分类**: DEP（新依赖）+ ARC
- **优先级**: P2
- **影响维度**: 生产功能
- **日期**: 2026-10-04
- **来源**: 用户决策（"参考 kelivo，在当前项目中也使用 drift 进行持久化存储"）+ `docs/kelivo-vs-agent-harness-2026-10.md` B5/B9 + ZCode 评估 C1（sqlite 任务索引，"除非会话搜索成为实测瓶颈"的前置决策）
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

本仓库的持久化至今是每域一份 JSON/JSONL：settings/prefs/sessions/plan_space（手写 toJson 的文档）、usage 台账与诊断日志（逐月 JSONL）、checkpoints（内容寻址文件）。JSON 文档对小状态是对的；但**关系型查询**（按天/按模型聚合、按窗口删除、按列索引）在 Dart 折叠里越写越重——usage 台账的 `entries()` 全量读文件再逐行折叠，聚合逻辑长在消费侧。两份评估都把 sqlite 列为 C1/B5 的前置决策，本 ADR 即那份决策。

依赖与约束事实：
- `drift` 是 Flutter 生态的 sqlite 引擎（kelivo 用 drift + sqlite3 单库 29 表；pub.dev 同步维护）。版本解算器把 drift 钉在 `>=2.30.0 <2.35.0`（`riverpod_generator 4.x` 的 `sqlite3 ^2` / `source_gen` 区间约束），与 kelivo 的 `^2.34.0` 同域。
- **drift 的表定义需要 `drift_dev` + `build_runner` 代码生成**——这触碰两条既有红线："不引入代码生成器（build_runner 等）除非任务明确要求且已立 ADR"（AGENTS.md §7，本次任务明确要求）与 ADR-0002 修订 1 的"codegen 仅限 riverpod 注解"（本 ADR 把第二台生成器立在此处）。生成物 `*.g.dart` 入库，先例是 `app_providers.g.dart`。
- 原生库：`sqlite3_flutter_libs` 供三桌面运行时；`flutter test` 在 macOS 宿主走系统 `libsqlite3.dylib`，Linux CI 宿主需要 `libsqlite3`（GitHub ubuntu runner 预装）——这是已知 CI 风险，若红则给 pr-check 加 apt 步骤。

## 决策（Decision）

**drift 单库多域**（kelivo 的形状）：`<support>/planstar.db`，一个 `AppDatabase`、按域一张表、schemaVersion 递进迁移。**S1 只迁 usage 台账**；其余域逐个评估后入表，不一次性搬。

1. **S1 为什么是 usage 台账**：写路径本就异步（`onTurnUsage` fire-and-forget）；聚合（per-model/per-day/错误率）正是 SQL 的本行，kelivo/ZCode 的统计面都走 DB 聚合；保留策略从"重写整文件"变成一条 `DELETE WHERE timestamp < ?`；JSONL 时代的测试语义可以逐条移植。**反面教材同样写明**：`sessions.json` 不迁——它的同步 tmp+rename 是 ADR-0039 的刻意设计（异步写会把 widget 测试拖回 FakeAsync 陷阱）；诊断日志不迁——追加式流就是 JSONL 的本职，上个月才落地，今天翻掉是 churn；settings/prefs 不迁——小文档 + 版本化迁移表已经是正确形状；plan_space 等ADR-0046（它可能本来就该按工作区分库）。
2. **表**：`UsageRows(id PK, timestamp, model, inputTokens, outputTokens, reasoningTokens, error)`，timestamp 建索引（窗口删除与范围读都走它）。`UsageEntry`/`UsageSummary`/`summarize` 纯 Dart 词汇不动，消费方零改动；`UsageLedger` 的公开 API（`record`/`prune`/`entries`/`cache`）签名不动，实现换成 DB。
3. **一次性导入**：open 后检测旧 `usage-*.jsonl`，逐文件导入即删。崩溃在导入与删除之间会重复计数少数行——30 天窗口的统计值，有界伤害，值得为"不丢旧数据"付。
4. **后续候选（各自再评估，不在本 ADR 承诺）**：S2 诊断日志入表（若要做请求/上下文的 SQL 检视）、S3 会话标题 FTS、S4 plan_space（挂 ADR-0046）。
5. **明确不做**：为 drift 改造任何同步 API；引入 sqflite（drift 原生覆盖）；共享连接跨 isolate。

## 后果（Consequences）

- **正面**：聚合与修剪下推到 SQL；查询能力（索引/范围/GROUP BY）第一次可用；为 S2–S4 立了唯一的库与迁移轴。
- **负面/风险**：`build_runner` 入场（生成物入库、依赖树 +7 包）；CI Linux 宿主的 libsqlite3 风险；drift 2.34 的上界被 riverpod_generator 钉住（升 drift 要连着升 riverpod 生成器一起解算）。
- **中性**：usage 台账的月度文件语义消失（导入即终结）；`flutter pub get` 后改表需手动 `dart run build_runner build --delete-conflicting-outputs` 并提交生成物——写进本 ADR 的验证节与 workflow 提示。

## 验证（Verification）

- `flutter test test/production_ops_test.dart`：原有四棵语义移植（读回/修剪/torn 行容忍/summarize 纯折叠），新增导入一棵（旧 JSONL → 行 → 文件删除）。
- 生成物存在且入库：`lib/state/app_database.g.dart`。
- 四道门禁同口径；`grep -rn "package:drift" lib/ | grep -v lib/state` 必须为空（drift 与 riverpod 同层，只许住在装配层）。

## 关联（Links）

- 代码: `lib/state/app_database.dart`、`lib/state/usage_ledger.dart`
- 关联 ADR: ADR-0045 PC（usage 台账的持久化口径——本 ADR 是它的载体升级）、ADR-0039（sessions.json 的同步契约——明确不迁的理由）、ADR-0002 修订 1（codegen 边界——本 ADR 扩出一格）
- 来源评估: `docs/kelivo-vs-agent-harness-2026-10.md` §3.5/§7；`docs/zcode-vs-agent-harness-2026-09.md` C1
