# Monorepo 拓扑评估与治理施工表（2026-10-15）

> 本文是 2026-10-15 架构评估的落盘记录与施工表，配套 ADR：[ADR-0085](adr/ADR-0085-arc-monorepo-gates-workspace-sqlite3.md)。
> 触发：用户两条拍板——① **packages/ 下所有包保留**；② **`sqlite3_flutter_libs: ^0.6.0+eol` 弃用，改用 drift**——并要求「先落 docs，再推进清单，macOS 真机验证」。
> 所有数字均为 2026-10-15 HEAD 实测快照，引用前现场重算。

## 0. 度量口径

- 行数：`find <dir> -name '*.dart' -not -name '*.g.dart' | xargs wc -l`（手写口径，排除生成物）。
- 消费者/被依赖关系：`flutter pub deps`（解析图）+ 各包 pubspec 声明交叉核对。
- 测试基线：**D1 落盘时写的 `+1490 -1` 是错的**（它只算了 `app_scope_test` 那棵 flake）。同日 HEAD `5bb1469` 实测 **`+1489 -3`**：`app_scope_test` 的 `/var`↔`/private/var` flake，加上 `shad_widget_adoption_test` 的 `no hand-drawn Material field is left in lib/ui` 与 `theme_token_test` 的 `no widget picks its own radius`——后两棵都只点名 `lib/ui/auth/lib/harness/widgets.dart`（`5bb1469` 带入的 harness，与本表八项发现无关）。收口时 **`+1490 -3`**，+1 是 D3 追加的那棵 `usage_migration_quiet_test`。逐批数字见 §6。
- 门禁：`dart format --set-exit-if-changed` / `dart analyze --fatal-infos`（范围 `lib test tool spike`）/ `flutter test`。

## 1. 度量总表

| 区域 | 规模 | 在解析图里 | 被谁依赖 |
| --- | --- | --- | --- |
| `lib/` | 156 文件 / 82,030 行 | ✅ | 根包 |
| `packages/appunits/app_common` | 115 文件 / 31,830 行 | ✅ | lib（path 依赖） |
| `packages/appunits/appunits_core` | 121 文件 / 22,029 行 | ✅（path 声明） | **0**（无消费者） |
| `packages/appunits/board_panel` | 57 文件 / 23,493 行 | ✅ | lib |
| `packages/appunits/plan_editor` | 8 文件 / 1,245 行 | ✅ | lib |
| `packages/infras/sentry` | 291 文件 / 53,834 行 | ✅ | stone_core（ADR-0083 依赖线） |
| `packages/infras/stone_core` | 25 文件 / 5,761 行 | ✅ | app_common、lib |
| `packages/pudding` | 16 文件 / 2,546 行 | ✅（path 声明） | **0**（无消费者） |
| `packages/_archive` | ~94 万字节 | — | gitignored（`.gitignore:56-57`） |

解析图事实：`lib → {stone_core, app_common, plan_editor, board_panel}`；`app_common → stone_core → sentry(fork)`。用户钦定依赖线（ADR-0083）：`sentry → stone_core → pudding → appunits → lib` 为允许方向的**上界**——`pudding`/`appunits_core` 当前零消费者，属「保留待接线」，不是缺陷。

## 2. 八项发现与处置

| # | 发现 | 证据 | 处置 | 批次 |
| --- | --- | --- | --- | --- |
| 1 | **门禁与代码拓扑劈叉**：`analysis_options.yaml:8` 把 `packages/**` 整体排除（理由注释已腐烂——说的是已删除的 shadcn vendored 镜像），CI 同口径；结果是 app_common/stone_core/plan_editor 三个一手包零 lint/format/test 覆盖 | 见 §1；`tool/check_architecture.dart` 只管 lib | 一手包进闸（lint+format+单测随包跑），vendored（sentry）与板件（board_panel）保持排除并逐包写清理由 | D5 |
| 2 | **appunits_core / pudding 零消费者** | `flutter pub deps` 无入边 | **保留**（用户拍板，ADR-0083 已录）；本文补「保留 ≠ 豁免」：两包接进 pub workspace 拿 SDK 对齐与依赖审计，接回消费路径另行立 ADR | D4 |
| 3 | **drift 双库并存**：`main.dart:146` 开 `<support>/planstar.db`（注释自述「One database connection for every domain」），`usage_ledger.dart:82` 又开 `<support>/usage.db`——同 schema 两个文件句柄，启动即打 drift double-instantiation 告警 | 实跑日志 `/tmp/planstar_run.log` | UsageLedger 改注入共享 `AppDatabase`，旧 `usage.db` 一次性导入（先例：`_importLegacyJsonl`） | D3 |
| 4 | **`sqlite3_flutter_libs: ^0.6.0+eol`**（root `pubspec.yaml:84`）：EOL 预编译包，三桌面目标全部用不上 | `sqlite3-2.9.4/lib/src/ffi/load_library.dart` 的 `_defaultOpen()` 回退链：macOS→`DynamicLibrary.process()`→`/usr/lib/libsqlite3.dylib`；Linux→`libsqlite3.so`；Windows→`sqlite3.dll`→`winsqlite3.dll`；Android/iOS 为不可运行脚手架（ADR-0057） | 移除依赖；drift 经 sqlite3 纯 Dart 绑定走系统库；三桌面本机验证 | D2 |
| 5 | **无 pub workspace**：7 个 pubspec 手维护，SDK/依赖版本无统一解析（drift 2.31.0 ↔ sqlite3 2.9.4 多处散落） | 各包 pubspec `environment:` 逐份核对 | 根 pubspec 加 `workspace:`，各包 `resolution: workspace`；SDK 约束对齐 `^3.11.5` | D4 |
| 6 | **CI 无 macOS 构建**：`pr-check.yml` 单 ubuntu job 只跑 format/analyze/test；`build.yml` 是 workflow_dispatch，macOS 打包从不自动验 | `.github/workflows/` | pr-check 加 `macos-latest` 构建 job（`flutter build macos --debug`，约 10 min 预算） | D6 |
| 7 | **一手包漂移出仓标**：app_common 无独立测试、自带一份 gen-l10n 管线；stone_core 暴露便利静态方法；i18n 覆盖度不一 | 各包 `test/` 现状 | 治理标准随 D5 写进 ADR-0083 实施清单（测试底线、l10n 约定、便利静态方法的 host 注入替代） | D5 |
| 8 | **手写文件预算失守**：lib 5 个文件 ≥1,500 行，最大 `model_settings.dart` 3,839 行；app_common 最大 1,395 行 | `wc -l` 实测榜 | 新增/改动文件 ≤1,000 行（含测试）；`model_settings.dart` 按节拆分为多文件 + registry | D7 |

## 3. 施工顺序

```
D1 本文 + ADR-0085 + 登记表        （docs 先行，用户要求）
D2 移除 sqlite3_flutter_libs        （最小 diff、真机可验，先行兑现「改用 drift」）
D3 drift 单库化（usage.db 并入）    （依赖 D2 后的依赖面）
D4 pub workspace                   （治理基础，先行可减少后续各包改动反复）
D5 门禁对齐（一手包进闸）           （依赖 D4 的 workspace 解析）
D6 CI macOS 构建 job               （独立，可与 D5 并行评审）
D7 model_settings.dart 拆分        （纯 lib 内部，最后做避免与 D5 交叉）
```

每批收口标准：三条门禁零新增失败（基线见 §0 更正：`+1489 -3`，收口 `+1490 -3`）+ 一个 Conventional Commit + 相关 ADR/登记表状态推进。**七批已全部收口，逐批 commit 与实测见 §6。**

## 4. 验收口径（全部完成的定义）

1. `grep -n sqlite3_flutter_libs pubspec.yaml` = 0；`flutter pub deps` 解析图中不存在该包。
2. 应用启动日志无 drift double-instantiation 告警；`<support>/planstar.db` 单文件承载全部域；旧 `usage.db` 数据经一次性导入可达。
3. 根 `flutter pub get` 一次解析全部 workspace 成员，`pubspec.lock` 单份真值。
4. `dart format --set-exit-if-changed` / `dart analyze --fatal-infos` / `flutter test` 覆盖 app_common、plan_editor、stone_core（board_panel/sentry 保持排除但理由落盘）。
5. pr-check 含 macOS 构建 job 且绿。
6. macOS 真机：`flutter run -d macos` 起应用，会话/企划/设置读写正常，日志无新增异常。

## 5. 与既有文档的关系

- 依赖线、包溯源、sentry fork 路线：**ADR-0083**（本文不重复，只扩展其「实施清单」）。
- 复用边界判定（Tier A/B/C）：**ADR-0084**。
- 本文与 ADR-0085 是同一轮治理的评估面与决策面；后续每批完成的 commit 回填 ADR-0085「修复 commit」列。

## 6. 收口表（2026-10-15，七批全部落码）

| 批 | commit | 实测证据 |
| --- | --- | --- |
| D1 | `d1044fa` | 本文 + ADR-0085 + 登记表行落盘（docs 先行） |
| D2 | `0b63d5e` | `grep -n sqlite3_flutter_libs pubspec.yaml` = 0、`flutter pub deps` 无该包；macOS 真机 sqlite3 经系统库打开（§0 更正过的基线在下一行） |
| D3 | `e2c7e23` + `1d34b1f` | UsageLedger 注入共享 `AppDatabase`；旧 `<support>/usage/usage.db` 导入后删除。**真机跑才暴露的缺陷**：那枚一次性导入用第二个 `AppDatabase` 句柄读旧文件，而 drift 的双实例检查按**类**计数，所以 D3 想消掉的那条告警原封不动还在启动日志里——修复是把 drift 自己给的 `dontWarnAboutMultipleDatabases` 只在那一枚句柄周围置位、`finally` 还原（真机跑第二次的日志 `WARNING (drift)` = 0，`lsof` 只见一个 `.db` 句柄，`planstar.db` 的 `usage_rows` 有数据）。守卫 `test/usage_migration_quiet_test.dart` 单文件单 isolate：drift 计数是进程全局的，同一文件里先开先关过数据库就会**为错误的理由通过**（第一次挂在 `production_ops_test` 里就是这么假绿的） |
| D4 | `02d39ff`（+ `98f8457`） | 根 `workspace:` 收 8 个成员（含 `board_panel/example`），各包 `resolution: workspace`、SDK `^3.11.5`；一次 `flutter pub get` 解析全仓。求解链：`flutter_test` 钉 meta 1.17.0 + `riverpod_generator` 要 analyzer ^9 ⇒ `json_serializable` 封顶 `<6.13.2`；`sentry/example` 不能入成员（`lints ^2` 与 `flutter_lints 6` 的 `lints ^6` 在统一求解里撞），它的野锁文件进 `.gitignore` |
| D5 | `883bca8` | 三个一手包进 format/analyze/test（`app_common` 无 test/ 一事登记在 ADR-0083 治理标准）；stone_core 进门禁当场只暴露机械债：14 文件重排 + `dart fix` 7 处 + 一棵**过期断言**（`multipart_uploader_test` 期望 `FailureType.network`，而实现与 `api_client._handleError` 一致地给 `FailureType.timeout`——改测试那一侧，不动实现） |
| D6 | `3217f87` | pr-check 第二个 job `build-macos`（`pod install` + `flutter build macos --debug`）。本机同口径代理证据：`flutter build macos --debug` → `✓ Built …/Debug/PlanStar.app`（这条同时是 D2 的端到端证据）。**job 本身是否绿要等 push**——本批只在本地验，未推 |
| D7 | `f90fbd0` + `8f7a3a6` | `model_settings.dart` 3,839 → **751 行**，14 个同库 `part` 文件（最大 `settings_section_models.dart` 865），`_content` 的 `switch (_Section)` 仍是唯一 registry。节体逐字搬运（脚本对 HEAD 与产物做行级 `comm` 比对：除 `setState`→`rebuild` 与 part/extension 脚手架外**零增删**）；唯一必要改动是那枚 `rebuild`——extension 不是 `State` 子类，够不着 protected 的 `setState`。两棵扫源码的守卫（`settings_shad_adoption_test` 的 `_pageLines`、`settings_reach_test` 的「写入页」集合）改为顺着 `part` 声明读整棵库：**同一把尺子，不是更弱的尺子**（前者自带的 `hasLength(>500)` + 五类组件计数就是非空证）。设置页既有测试**一条断言未改**，全量 `flutter test` `+1490 -3`（与基线同三棵失败） |

还债之外**没做的事**（别把本表读成全绿交付）：

1. **Windows/Linux 未实测**——`winsqlite3.dll` 那条回退链是包源码事实，不是本机走查（`build.md` §0 的口径：没在当前平台跑过就标待验证）。
2. **CI 的 macOS job 未见绿**——它需要 push 才跑；本地代理证据只是同一条 `flutter build macos --debug` 在本机过。
3. **真机 UI 走查仍待人工**——本次能机器证的三件是：启动日志 0 告警 0 异常、单库单句柄（`lsof`）、旧 `usage.db` 被导入并删除且 `usage_rows` 有数据。「会话/企划/设置读写正常」这一格要眼睛，窗口截图不在本 harness 能力内。
4. **`app_common` 仍无 test/**、`appunits_core`/`pudding` 仍零消费者、`board_panel/example` 之外 sentry 的 example 仍是野包——都按 ADR-0083/0085 记为「保留待接线」，接线另立 ADR。
5. **存量四个 ≥1,500 行文件未拆**（`composer.dart` 2,040 / `sidebar.dart` 1,889 / `agent_runtime.dart` 1,852 / `plan_block_view.dart` 1,715）——D7 立的是「新增/改动文件 ≤1,000 行」这条律（已进 `AGENTS.md` §5 与两份 rules 镜像），不是批量重排的依据。
