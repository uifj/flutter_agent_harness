# ADR-0085: Monorepo 门禁对齐、pub workspace、drift 单库化与 sqlite3_flutter_libs 移除

- **状态**: RESOLVED（D1–D7 七批于 2026-10-15 全部落码；余留项见「验证」段的逐条标注与评估文档 §6 的「没做的事」清单）
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 评估阻断 / 幻觉源 / 生产功能
- **日期**: 2026-10-15
- **来源**: 用户拍板（packages/ 全量保留 + sqlite3_flutter_libs 弃用改 drift）+ 2026-10-15 monorepo 架构评估
- **修复 commit**: D1 `d1044fa` · D2 `0b63d5e` · D3 `e2c7e23` + `1d34b1f` · D4 `02d39ff`（+ `98f8457` 生成物重排）· D5 `883bca8` · D6 `3217f87` · D7 `f90fbd0` + 规则落盘 `8f7a3a6`

## 背景（Context）

2026-10-12 起仓库成为 packages/ monorepo（ADR-0083/0084）。2026-10-15 架构评估（评估面落盘 `docs/monorepo-topology-review-2026-10-15.md`，八项发现）量到以下事实：

1. **门禁与代码拓扑劈叉**：`analysis_options.yaml:8` 将 `packages/**` 整体排除在 format/analyze 之外，理由注释仍写着已删除的 shadcn vendored 镜像；`.github/workflows/pr-check.yml` 同口径。一手包 `app_common`（115 文件 / 31,830 行）、`stone_core`（5,761 行）、`plan_editor`（1,245 行）因此零 lint/format/test 覆盖；`board_panel` 的排除理由另写在 ADR-0007 D5。
2. **保留令与依赖线**：用户拍板 packages/ 下所有包保留，依赖线上界为 `sentry → stone_core → pudding → appunits → lib`（ADR-0083）。实测 `appunits_core`（22,029 行）与 `pudding`（2,546 行）在解析图中零消费者——是「保留待接线」，不是删除对象。
3. **drift 双库并存**：`lib/main.dart:146` 开 `<support>/planstar.db`（注释自述 "One database connection for every domain"），`lib/state/usage_ledger.dart:82` 又开 `<support>/usage.db`；UsageRows 表在共享 schema 里却由第二个文件句柄承载，启动即打 drift double-instantiation 告警（实跑日志 `/tmp/planstar_run.log`）。
4. **`sqlite3_flutter_libs: ^0.6.0+eol`**（root `pubspec.yaml:84`）：EOL 预编译包。证据：`sqlite3-2.9.4/lib/src/ffi/load_library.dart` 的 `_defaultOpen()` 回退链——macOS `DynamicLibrary.process()` → `/usr/lib/libsqlite3.dylib`；Linux `libsqlite3.so`；Windows `sqlite3.dll` → `winsqlite3.dll`。三个桌面目标均有系统库可退；android/ios 为不可运行品牌脚手架（ADR-0057）。
5. **无 pub workspace**：7 个 pubspec 手工维护 SDK/依赖约束，无统一解析真值。
6. **CI 无 macOS 构建**：`pr-check.yml` 单 ubuntu job；`build.yml` 仅 workflow_dispatch。
7. **手写文件预算失守**：lib 5 个文件 ≥1,500 行，最大 `lib/ui/settings/model_settings.dart` 3,839 行。

## 决策（Decision）

按七批次施工（顺序与验收见评估文档 §3/§4）：

- **D1**：评估文档 + 本 ADR + 登记表落盘（docs 先行）。
- **D2**：移除 `sqlite3_flutter_libs`；drift 经 sqlite3 纯 Dart 绑定加载系统库；macOS 真机验证 DB 打开与现有 15 处 planstar.db 测试全绿即为行为证明。
- **D3**：UsageLedger 改注入共享 `AppDatabase`（main.dart 已开的 planstar.db），旧 `usage.db` 一次性导入后废弃（先例 `_importLegacyJsonl`）；双实例告警消失。
- **D4**：根 pubspec 加 `workspace:`（成员含全部 path 依赖包 + appunits_core/pudding），各包 `resolution: workspace`、SDK 对齐 `^3.11.5`；**全部包保留**，零消费者两包接入 workspace 以获得依赖审计与版本对齐（「保留 ≠ 豁免」），消费路径接线另立 ADR。
- **D5**：门禁对齐——`app_common`/`plan_editor`/`stone_core` 进 format/analyze/单测；`board_panel`（ADR-0007 D5 先例）与 `sentry`（vendored fork，ADR-0083）保持排除，排除理由逐包写进 `analysis_options.yaml` 注释与 ADR-0083 实施清单；治理标准（包内测试底线、l10n 约定、stone_core 便利静态方法改 host 注入）一并落 ADR-0083。
- **D6**：pr-check 加 `macos-latest` 构建 job（`flutter build macos --debug`，预算约 10 min）。
- **D7**：`model_settings.dart` 按节拆分为多文件 + registry，新增/改动手写文件 ≤1,000 行预算自此生效。**落地形状**（`f90fbd0`）：入口文件留 `_Section`、`SettingsPanel`、State 核心（字段/存盘/nav/`_content` 的 switch registry）与 `rebuild` 门，每一节与它的行件放进同库的 `part` 文件——选 `part` + `extension` 而不是「一节一个 widget 类 + 回调注入」，是因为前者让节体**逐字搬运**（行级 `comm` 比对：除 `setState`→`rebuild` 与脚手架外零增删），后者要重写三十八枚字段接线，把一次治理改动变成一次行为风险。预算文本进 `AGENTS.md` §5 与两份 rules 镜像（`8f7a3a6`）。

取舍说明：D2 先于 D3（依赖面收窄后再动 ledger）；D4 先于 D5（workspace 解析是一次 `flutter pub get` 覆盖全仓的前提）；D7 最后（纯 lib 内部，避免与 D5 门禁交叉评审）。vendored sentry 不进 lint/format 的理由与 ADR-0083 一致：第三方 fork 的代码风格不应由本仓门禁负责，但其「能否编译」由 workspace 解析与 CI 构建天然覆盖。

## 后果（Consequences）

- **正面**: 门禁与拓扑重合（一手包不再裸奔）；依赖图单份真值；drift 告警消失、备份/迁移只对一个 db 文件；EOL 依赖移除后三桌面均走系统 sqlite3（macOS 随系统更新得安全补丁）；CI 自动守 macOS 可构建。
- **负面/风险**: `winsqlite3.dll` 路径未在本机实测（Windows 目标标「待 Windows 验证」）；workspace 化后各包 `pubspec.lock` 消失，回滚某包依赖需走 git 历史；D7 拆分是纯搬运，期间设置页 diff 噪声大，需一次集中评审。
- **中性**: `_archive` 维持 gitignored 不动物理目录（ADR-0083 已定）；`packages/` 下一个包接回消费（pudding/appunits_core）须另立 ADR，本 ADR 不赋予其消费者。

## 验证（Verification）

逐条实测结果（2026-10-15，macOS 开发机；`+1490 -3` 里那三棵失败均为既有、与本 ADR 无关，见评估文档 §0 更正）：

1. ✅ `grep -n sqlite3_flutter_libs pubspec.yaml` = 0；`flutter pub deps` 无该包。
2. ⚠️ **这条最初没通过，而且是真机跑出来的**：D3 的一次性导入用第二个 `AppDatabase` 句柄读旧 `usage.db`，drift 的双实例检查按**类**计数，于是它想消掉的那条告警仍在启动日志里。修复 `1d34b1f`：`dontWarnAboutMultipleDatabases` 只在那枚句柄周围置位、`finally` 还原（drift 自己给的正当出口，不是全局消音——别处真出现两个活连接照样告警）。修后同一条真机路径 `WARNING (drift)` = 0，`lsof` 只见一个 `.db` 句柄，`planstar.db` 的 `usage_rows` 有数据。守卫 `test/usage_migration_quiet_test.dart` **单文件单 isolate**：drift 的计数是进程全局的，混在 `production_ops_test` 里它会**为错误的理由假绿**（第一版就是这么过的）。
3. ✅ `<support>/usage/usage.db` 被导入并删除，`<support>/` 顶层不再出现第二个 db 文件；用量数据在共享库里可读。
4. ✅ 根一次 `flutter pub get` 解析全部成员（含 `board_panel/example`；`sentry/example` 不能入成员，其野锁文件进 `.gitignore`）；format/analyze `--fatal-infos` 覆盖 `lib test tool spike packages/appunits/app_common packages/appunits/plan_editor packages/infras/stone_core` 零告警；`flutter test` 零新增失败。
5. ⏸ pr-check 的 `build-macos` job 已落码（`3217f87`），**本地同口径代理证据** = `flutter build macos --debug` → `✓ Built …/Debug/PlanStar.app`；job 自身见绿要等 push（本 ADR 不代跑、也不声称已绿）。
6. ✅ D7 后 `wc -l lib/ui/settings/model_settings.dart` = **751**（<1,000），14 个同库 `part` 文件、最大 865；设置页既有测试**一条断言未改**全绿。实操后果两条，改这块前先读：① 节体是 `extension _XxxSections on _SettingsPanelState`，而 **extension 不是 `State` 子类、够不着 protected 的 `setState`**，所以页面自己供一枚 `rebuild(VoidCallback)` 门给各节用（新节要走同一枚门，别在调用点手搓 ignore）；② 两棵扫源码的守卫（`settings_shad_adoption_test` 的 `_pageLines`、`settings_reach_test` 的「写入页」集合）必须顺着 `part` 声明读整棵库，只读入口文件会把设置页的写入点当成外部读取点，ADR-0022 那条律就空了。
7. ⏸ **仍待**：Windows 的 `winsqlite3.dll` 回退链未实测（标「待 Windows 验证」）；真机 UI 走查（会话/企划/设置那一眼）不在本 harness 能力内；`app_common` 无 test/ 与两个零消费者包接线，各按 ADR-0083 追。

## 关联（Links）

- 代码: `pubspec.yaml:84`、`lib/main.dart:146`、`lib/state/usage_ledger.dart:82`、`analysis_options.yaml:8`、`.github/workflows/pr-check.yml`
- 评估面: `docs/monorepo-topology-review-2026-10-15.md`
- 关联 ADR: ADR-0083（包治理与依赖线，本 ADR 扩展其实施清单）、ADR-0084（复用边界）、ADR-0060/0071（单连接多域的原始决策）、ADR-0007 D5（board_panel 入库先例）、ADR-0057（android/ios 为脚手架）、ADR-0001（vendored 不入库原则）
