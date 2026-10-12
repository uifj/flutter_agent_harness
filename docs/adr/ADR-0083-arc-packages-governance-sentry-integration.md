# ADR-0083: packages 三层 monorepo 治理与 sentry 集成路线

- **状态**: IN-PROGRESS
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 认知障碍 / 上下文膨胀 / 评估阻断 / 幻觉源
- **日期**: 2026-10-12
- **来源**: `packages/` 全量深入学习 + `_archive`（sentry-dart 9.30.1 完整 monorepo）逐包清点
- **修复 commit**: 待提交（治理批次 2026-10-12 已落地；见文末「治理执行结果」）

## 背景（Context）

### B0. 一句话

`packages/` 是一次**进行中的三层 monorepo 重组**：从阿里无影（Wuying）"stone" God-package、腾讯 TUIKit、sentry-dart 三处搬来物料，按 `infras / appunits / pudding` 分层落位，但**只有 `board_panel` + `plan_editor` 真正接进了主 app**（`lib/`）。`stone_core / pudding / appunits_core / app_common` 处于半接线状态，存在系统性断链，当前**均无法编译**。本 ADR 给出 `_archive` 集成路线（分级）与治理修复方案。

### B1. 用户指定的依赖路线（不可反向）

```
sentry ──▶ stone_core ──▶ pudding ──▶ appunits ──▶ lib（应用代码）
（最底层，第三方监控 SDK）        （最顶层，只被依赖，不依赖任何包）
```

- 箭头 `A ──▶ B` = **B 可以依赖 A**（A 是更底层）。
- "不可反向" = 底层不得依赖上层：`stone_core` 不得依赖 `pudding/appunits/lib`；`sentry` 不得依赖其余任何包。
- 允许**向下跨层**（如 `appunits ──▶ stone_core` 跳过 `pudding`），但每一跳都必须朝下。
- `lib/` 是终点：可依赖以下所有层，但**没有任何包可依赖 `lib/`**。

### B2. `packages/` 现状（现场 `find`/`grep`，2026-10-12）

| 包 | 来源 | lib 规模 | 声明依赖 | 可编译 | 与主 app 关系 |
| --- | --- | --- | --- | --- | --- |
| `infras/sentry` | sentry-dart core SDK 9.30.1（= `_archive/packages/dart`，`diff -rq` **0 差异**，纯 vendored 未改） | 228 文件 / 22883 行 | ffi·http·meta·stack_trace·uuid·web | ✅（上游原样） | 未被正确接线（下层用坏路径引它） |
| `infras/stone_core` | Wuying "stone" God-package 抽取（`network_core.dart` 自述"去 stone 化 Phase 2"） | 21 文件（logger 3 / network 16 / storage 2） | flutter·dio·uuid·sentry | ❌（见 B4） | 未接入；`app_common` 已声明依赖它 |
| `pudding` | sentry 官方集成脚手架（grpc/link/remote_config） | grpc 2 文件（1 空）+ link/remote_config 空 | flutter·dio·uuid·sentry·stone_core | ❌（坏路径 + 空壳） | 未接入 |
| `appunits/appunits_core` | 腾讯 TUIKit `base_component` 设计系统 + i18n + permission | 42 文件 / ~21417 行（**65% 是 i18n**） | flutter·intl·provider·cached_network_image·…·sentry | ❌（入口自引用 + 缺 `ai/`） | 未接入 |
| `appunits/app_common` | **迁移中**：入口仍是 `plan_editor` 副本，实体已换成 `updater/`(3)+`feedback/`(4) | 8 文件 | collection·flutter·stone_core | ❌（入口 export 不存在的 `src/*`） | 未接入 |
| `appunits/board_panel` | Simform `flutter_calendar_view`(MIT) + 自研看板；深度集成 shadcn_ui | 72 文件 / 15206 行 | equatable·flutter·flutter_riverpod·intl·shadcn_ui | ✅ | **已接入**（企划 Board + MonthView，ADR-0037） |
| `appunits/plan_editor` | super_editor / attributed_text(MIT) span 引擎 | 4 文件 / 434 行 | attributed_text·collection·flutter | ✅ | **已接入**（企划块编辑器，ADR-0044） |
| `_archive` | sentry-dart **完整 monorepo**（melos + warden + codecov + e2e/metrics/min_version_test + 13 集成包 + scripts） | 895 dart 文件 | — | —（归档，不参与构建） | 集成物料来源 |

> 注：`packages/flutter-shadcn-ui` 已不在磁盘（ADR-0001 记录，`.gitignore` 排除）；`shadcn_ui` 0.56.3 是根 pubspec 直接依赖。

### B3. `_archive/packages/*` = sentry-dart 13 个集成包（清点）

| `_archive` 目录 | 上游包名 | lib 规模 | 依赖（上游） | 对 PlanStar 的契合度 |
| --- | --- | --- | --- | --- |
| `dart` | `sentry` | 228 / 22883 | ffi·http·meta·stack_trace·uuid·web | = `infras/sentry`（已抽出） |
| `dio` | `sentry_dio` | 11 / 818 | **dio ^5.2.0** + sentry | ★★★ stone_core 全栈用 dio ^5.4.0 |
| `logging` | `sentry_logging` | 4 / 197 | logging + sentry + meta | ★★★ **已被 stone_core/logger 逐字吸收** |
| `file` | `sentry_file` | 6 / 740 | sentry + meta（纯 dart:io） | ★★ multipart/config 的文件 I/O 面包屑 |
| `drift` | `sentry_drift` | 6 / 372 | sentry + meta + **drift ^2.24.0** | ★★ PlanStar 根用 drift ^2.31，但 DB 在 `lib/` 不在 stone_core |
| `sqflite` | `sentry_sqflite` | 9 / 1695 | sentry + sqflite | ☆ 移动端，PlanStar 用 drift |
| `hive` | `sentry_hive` | 11 / 832 | sentry + hive | ☆ PlanStar 无 hive |
| `isar` | `sentry_isar` | 6 / 902 | sentry + isar | ☆ PlanStar 无 isar |
| `grpc` | `sentry_grpc` | 4 / 312 | **grpc** + meta + sentry | ☆ → `pudding/grpc`，但 PlanStar **无 grpc** |
| `link` | `sentry_link` | 10 / 657 | **4×gql** + sentry | ☆ → `pudding/link`，但 PlanStar **无 gql** |
| `firebase_remote_config` | `sentry_firebase_remote_config` | 2 / 61 | flutter + **firebase_remote_config** + sentry | ☆ → `pudding/remote_config`，但 PlanStar **无 firebase** |
| `supabase` | `sentry_supabase` | 10 / 743 | sentry + supabase | ☆ PlanStar 无 supabase |
| `flutter` | `sentry_flutter` | 148 / 143020 | flutter + sentry + native | 应用层崩溃监控（另立 ADR，不属 stone_core/pudding） |

**映射证据**（集成风格 = infra 包**逐字吸收**上游集成源码，而非作为独立包依赖）：

- `pudding/grpc/src/internal_logger.dart` 与 `_archive/packages/grpc/lib/src/internal_logger.dart` `diff` **仅差行尾换行**；内含 `SentryInternalLogger('sentry_grpc')`。
- `stone_core/lib/logger/src/logging_integration.dart` 与 `_archive/packages/logging/lib/src/logging_integration.dart` `diff` **仅差行尾换行**；`extension.dart` 同为副本。

**PlanStar 技术栈判据**（根 `pubspec.yaml` grep `grpc|gql|firebase|dio:|sentry`）：**只命中 `drift`/`sqlite3_flutter_libs`**。即本 app 用 genkit（AI）+ drift（DB），**不用 grpc / gql / firebase / 直接 dio / 尚未初始化 sentry**。故 `pudding` 三件套对 PlanStar 是 **YAGNI**（除非本仓服务更大生态）。

### B4. 治理断链清单（逐条带证据）

1. **路径依赖全部无法解析**（根 pubspec **无 `workspace:` 声明**，也无 melos）：
   - `stone_core`: `sentry: packages/infras/sentry`
   - `pudding`: `sentry: packages/infras/sentry`、`stone_core: packages/infras/stone_core`
   - `appunits_core`: `sentry: ./infras/sentry`（相对基准错，从 `appunits/appunits_core` 出发应 `../../infras/sentry`）
   - `app_common`: `stone_core: packages/infras/stone_core`
   > `packages/infras/sentry` 这种写法是 **workspace/melos 基准**（从 monorepo 根算），搬到无 workspace 根的 PlanStar 后全断。
2. **`stone_core/lib/network_core.dart` 入口 15 条 export 全错**：export `src/api_client.dart` 等，但实际文件在 `network/api_client.dart`（`find lib/network -type d` 只有 `interceptors/cache/multipart`，**无 `src/`**）。
3. **两个幽灵包**（被 import 但仓库中不存在）：
   - `package:stone_domain`（提供 `Result`/`Failure`，`api_client.dart:22` 等 3 lib + 3 test 引用）——**整包缺失**。
   - `package:logger_core`（6 个 network 文件引用）——但 stone_core 内**已有** `lib/logger/logger_core.dart`（`library logger_core;`），说明它本应是 stone_core 内部模块（相对 import），抽取时留下了 `package:` 写法。
4. **stone_core 缺失 pubspec 依赖**：代码 import `meta`/`logging`/`shared_preferences`/`flutter_secure_storage`（真 pub 包，未声明）+ 上述 2 幽灵包。声明只有 flutter/dio/uuid/sentry。
5. **`stone_core/lib/logger` 断链**：`logging_integration.dart:10` 仍 `import 'version.dart'`、`:70` 用 `packageName/sdkVersion`，但 `version.dart` **已删**、`extension.dart` 不定义它们；入口 `logger_core.dart` 只 `export 'src/logger.dart'`（新的 `StoneLogger`），把 `logging_integration.dart`/`extension.dart` **孤立**。
6. **`appunits_core/lib/appunits_core.dart` 入口坏**：`export 'package:appunits_core/appunits_core.dart'`（**自引用循环**）+ `export 'ai/ai_transcriber.dart'`（`ai/` 目录**不存在**）。
7. **`app_common/lib/app_common.dart` 入口 = plan_editor 副本**：export `src/editor_mark.dart` 等，但 `app_common/lib` **无 `src/`**；真实模块 `updater/`(3)+`feedback/`(4) 未被入口 export。（用户正在改写此包，pubspec 已挂 `stone_core`+`collection`。）
8. **`pudding` 空壳**：`grpc/src/grpc_interceptor.dart` 空、`link/`+`remote_config/` 空；依赖 2 条坏路径。

## 决策（Decision）

### D1. sentry 集成路线（分级；"合适的内容"判据 = 是否契合 PlanStar 现有技术栈）

**集成风格**：沿用既有先例——**infra 包逐字吸收上游集成源码 + 只依赖 `sentry` core**（如 `stone_core/logger` 之于 `sentry_logging`），而非把每个 `sentry_*` 作为独立 vendored 包。这样层数最低（`stone_core ──▶ sentry`），且与 B3 的映射证据一致。

| 级别 | 集成 | 落位 | 理由 / 前置 |
| --- | --- | --- | --- |
| **Tier 1（立即，明确契合）** | `sentry_dio` | `stone_core/lib/network/sentry/`（吸收 11 文件），在 `HttpManager` 建 Dio 后调 `.addSentry()` | 自动 HTTP 失败捕获 + 面包屑 + 分布式追踪；依赖 dio（已有）+ sentry（已有），**零新增外部依赖**。`.addSentry()` 在拦截器链 index 0 插 `FailedRequestInterceptor`、包裹 `httpClientAdapter`/`transformer`——与 stone_core 现有拦截器链兼容 |
| **Tier 2（按需，契合非急需）** | `sentry_file` | `stone_core/lib/storage/sentry/` 或 `network/sentry/` | 为 `multipart_uploader`/`config` 的文件 I/O 加面包屑；纯 dart:io，契合 infra 层 |
| **Tier 2** | `sentry_drift` | **视 DB 归属**：当前 PlanStar 的 drift DB 在 `lib/`（ADR-0060），不在 stone_core | 若将来把 DB 下沉到 stone_core/storage 才在此集成；否则集成点在 app 层，另议 |
| **已就位** | `sentry_logging` | `stone_core/lib/logger`（已吸收） | 去留见 D2-④ |
| **Tier 3（裁决 B：已忠实集成 2026-10-12）** | `sentry_grpc`·`sentry_link`·`sentry_firebase_remote_config` | `pudding/lib/{grpc,link,remote_config}` | 用户裁决**现在忠实集成**（否决 YAGNI 预留）。已从 `_archive` 逐字拷 src + 加 grpc/meta/gql×4/firebase_remote_config 依赖；对 PlanStar 现技术栈仍是死代码，但按裁决就位、`dart analyze lib` 0 issue |
| **独立决策（不属本 ADR）** | `sentry_flutter`（143020 行 + native） | `appunits`/`lib` 崩溃监控接线 | 体量与平台耦合远超 infra；接入 sentry 是产品级决定，另立 ADR |
| **不集成** | `sqflite`·`hive`·`isar`·`supabase` | — | PlanStar 无对应技术栈 |

### D2. 治理修复方案（推荐 + 备选；★ = 需用户拍板）

> **用户裁决（2026-10-12）**：①=A 相对路径 · ②=A 内联+相对 · ③=**B 现在忠实集成**（否决推荐 A 的 YAGNI 预留）· ④=**B 保留并修复**（否决推荐 A 的移除）。⑤⑥ 随 ①②④ 一并落地。逐项执行结果见文末「治理执行结果」。

**① ★ 依赖接线机制**（修断链 1）
- **(A) 相对路径**（推荐 / 最简）：`stone_core: sentry: ../sentry`；`pudding: sentry: ../infras/sentry` + `stone_core: ../infras/stone_core`；`appunits_core: sentry: ../../infras/sentry`；`app_common: stone_core: ../../infras/stone_core`。无需 workspace 机制，改动面小，立即可解析。
- (B) pub workspace：根 pubspec 加 `workspace:` 列出各包 + 各包加 `resolution: workspace`（Dart 3.11.5 支持）。正规 monorepo 方案，但要把 app 根 pubspec 变成 workspace root，且 sentry 的 example 子包需排除，改动面大。
- (C) 暂缓：只记录不接线。

**② ★ 幽灵包 `stone_domain` / `logger_core`**（修断链 3）
- **(A) 内联 + 相对**（推荐）：`Result`/`Failure` 是极小的领域原语（`api_client` 自述"returns Result instead of fpdart Either"），内联进 `stone_core/lib/network/`（或建极简 `infras/stone_domain` 只含这两个类型）；`package:logger_core/logger_core.dart` 改成相对 import 指向 stone_core 自己的 `lib/logger/logger_core.dart`。
- (B) 建两个真包：新建 `infras/stone_domain` 与 `infras/logger_core` 独立包，stone_core 依赖它们（更贴 Wuying 原架构，但多两个包 + 两条接线）。
- (C) 暂缓：不修 network（则 stone_core 仍不可编译）。

**③ ★ `pudding` 三件套**（修断链 8）
- **(A) 保留为预留脚手架**（推荐 / YAGNI）：不拉 grpc/gql/firebase；`pudding` 维持最小骨架，ADR 记"待 app 采用相应技术再集成"，`pubspec` 先去掉用不到的 `dio`/`uuid` 与坏路径。
- (B) 现在忠实集成：从 `_archive` 拷 `sentry_grpc/link/firebase` 源码 + 加对应依赖（对 PlanStar 是死代码）。
- (C) 删除空脚手架：移除 `grpc/link/remote_config` 直到真需要。

**④ ★ `stone_core/logger` 的 sentry 集成去留**（修断链 5）
- **(A) 移除 sentry 集成**（推荐，若 logger 要独立）：删 `logging_integration.dart` + `extension.dart`，`logger` = 纯 `StoneLogger`（不耦合 sentry）；sentry 的日志转发改由 Tier 1 的 `sentry_dio` / 未来 `sentry_flutter` 承担。
- (B) 保留并修复：恢复 `version.dart`（或内联 `packageName/sdkVersion` 常量）、入口 export 它、补 `meta`+`logging` 依赖，让 `package:logging` 的记录转发到 sentry。
- (C) 暂缓。

**⑤ 入口文件修复**（修断链 2/6/7；机械、无争议）
- `network_core.dart`：15 条 `export 'src/*'` → `export 'network/*'`（文件实在 `network/`）。
- `appunits_core.dart`：删自引用行 + 删 `ai/ai_transcriber.dart` export（`ai/` 不存在）。
- `app_common.dart`：**用户正在改写此包**，本 ADR 只登记不擅动；建议入口改为 export `updater/`+`feedback/` 的公开件，并清除 plan_editor 残留（需用户确认其公开 API）。

**⑥ 补齐 stone_core pubspec 依赖**（修断链 4；随 ②④ 定案）：按最终保留的源码补 `meta`/`logging`/`shared_preferences`/`flutter_secure_storage`（真实 pub 包）。

### D3. 分层守卫（防反向依赖回潮）

在 `tool/check_architecture.dart`（ADR-0011）增一条规则，或新增 `packages` 专用守卫：**扫描各包 `import 'package:X/'`，断言依赖只朝下**（`sentry` 不引任何本仓包；`stone_core` 只可引 `sentry`；`pudding` 只可引 `stone_core`/`sentry`；`appunits` 只可引 `pudding`/`stone_core`/`sentry`）。违反即红。

## 治理执行结果（2026-10-12 批次）

按用户裁决（D2 ①=A / ②=A / ③=B / ④=B）执行。**四包接线断链已清零**；两个 vendored 包各余一处**非机械**缺口，登记不擅动。

| 包 | 本次执行 | `dart analyze` |
| --- | --- | --- |
| `infras/stone_core` | 内联 `network/result.dart`（Result/Failure/FailureType，替幽灵包 `stone_domain`）+ 恢复 `logger/src/version.dart`；9 处 lib 幽灵包 import（`stone_domain`/`logger_core`）改相对；`network_core.dart` 15 条 `export 'src/*'`→`'network/*'`；`logger_core.dart` 补 `export logging_integration.dart`（④=B）；6 个 test import 改相对；pubspec 去 workspace + `sentry: path:../sentry` + 补 `meta/logging/shared_preferences/flutter_secure_storage`；顺带修 3 处 `DioExceptionType.transformTimeout` 非穷尽 switch（dio 升版既有遗留，非本次引入） | **lib+test：No issues found!** |
| `pudding` | 建 `lib/{grpc,link,remote_config}/` + `lib/pudding.dart` 桶；从 `_archive` **逐字拷** sentry_grpc(3)+sentry_link(9)+sentry_firebase_remote_config(1) 的 `src/`；link 内 7 处 `package:sentry_link/src/*` 自引用改相对；删包根空壳 `grpc/`（旧 `grpc_interceptor.dart` 为空）；pubspec 去 workspace + `sentry: path:../infras/sentry` + 加 `grpc/meta/gql×4/firebase_remote_config` + 去未用的 `dio/uuid/stone_core`；`analysis_options` 将三棵 vendored `src/` 排除出一方 lint（同 `stone_core/logger`、根 `packages/**` 先例） | **lib：No issues found!**（拷入前 35 条全 info、0 error ⇒ vendored 代码类型无误） |
| `appunits/appunits_core` | 入口删自引用 `export 'package:appunits_core/appunits_core.dart'` + 删 `ai/ai_transcriber.dart`（`ai/` 不存在）；**新建 `lib/atomicx.dart` 兼容桶**（`export 'appunits_core.dart'`）——上游 TUIKit 内部 `import 'package:appunits_core/atomicx.dart'` 指的入口名，补上后 **21 error→1**；pubspec `sentry: ./infras/sentry`→`path: ../../infras/sentry` | 1 error + 3 warning + 50 info（皆 vendored TUIKit 既有） |
| `appunits/app_common` | **仅**修 pubspec `stone_core: packages/infras/stone_core`→`path: ../../infras/stone_core`（①=A 机械接线）；**入口与 lib/ 代码未动**——用户正在改写此包（D2-⑤「只登记不擅动」） | 57 error + 8 info（用户改写中） |

**登记不擅动的两处非机械缺口**：

1. `appunits_core/lib/base_component/utils/chat_utils.dart:8` 引用 `GroupMember`——腾讯 TUIKit **chat** 模块的模型，未随 `base_component`(atomicx) 一起 vendored，而 `base_component.dart` 又 export 了 `chat_utils.dart`。**不臆造**该 chat 模型（恐与将来真 chat 模块冲突）；待 chat 模块 vendored 或移除 `chat_utils` 后消解。
2. `app_common` 整包处于用户改写中（plan_editor 副本入口 + updater/feedback 半成品）：缺 `UpgradeController/UpgradeState/UpgradeSnapshot/UpgradeUiLabels` 等类型、未声明 `shadcn_ui/open_file/upgrade/attributed_text` 依赖。**不代写**用户尚未落地的 API。

**本批未做（后续 / 另立）**：D1-Tier1 `sentry_dio`→`stone_core/network/sentry/`（待本 ADR ACCEPTED 后实施）；D1-Tier2 `sentry_file`/`sentry_drift`；D3 分层守卫挂 `tool/check_architecture.dart`；`sentry_flutter` 崩溃监控（另立 ADR）。

## 后果（Consequences）

- **正面**：`stone_core`（Tier 1 后）可编译并给出生产级 HTTP 错误捕获/面包屑；断链清零；分层由守卫固化；`_archive` 的集成物料有了明确、分级的归宿，不再"整包搬来却不知放哪"。
- **负面 / 风险**：吸收 `sentry_dio` 源码 = 承担与上游 9.30.1 的漂移（升级 sentry 时需回扫）；相对路径方案（D2-①A）在未来包增多时不如 workspace 优雅。
- **中性**：`pudding` 若选预留脚手架，则短期是空层；`sentry_flutter` 与 `stone_domain` 归属可能各自催生后续 ADR。

## 验证（Verification）

**治理批次 2026-10-12 实测**：

- ✅ `packages/infras/stone_core`：`flutter pub get`（Changed 76 deps）+ `dart analyze lib test` → **No issues found!**
- ✅ `packages/pudding`：`flutter pub get`（Changed 54 deps，含 grpc 5.1.0 / gql 1.0.1 / firebase_remote_config / sentry path）+ `dart analyze lib` → **No issues found!**
- ✅ `grep -rn "package:stone_domain\|package:logger_core" packages/{infras,pudding,appunits}`（排除 `_archive`）→ **空**（D2-②A）
- ✅ `grep -n "export 'src/" packages/infras/stone_core/lib/network_core.dart` → **空**（D2-⑤）
- ⚠️ `appunits_core`：余 **1 error**（`GroupMember` 未 vendored，已登记）+ 3 warning + 50 info（vendored TUIKit 既有风格）。
- ⚠️ `app_common`：用户改写中，余 57 error（缺类型 + 未声明依赖），仅修 pubspec 路径。二者均未接入 `lib/`，不阻断主 app。
- ⏳ `dart tool/check_architecture.dart` 分层规则（D3）：本批**未做**（后续）。

## 关联（Links）

- 代码: `packages/infras/stone_core/lib/network_core.dart`、`packages/infras/stone_core/lib/logger/logger_core.dart`、`packages/pudding/pubspec.yaml`、`packages/appunits/app_common/lib/app_common.dart`
- 物料: `packages/_archive/packages/{dio,logging,file,drift,grpc,link,firebase_remote_config}`
- 关联 ADR: ADR-0001（vendored 不入库先例，`sentry`/`board_panel` 是其记录在案的例外）、ADR-0011（架构门禁 `check_architecture`，D3 挂此）、ADR-0037（board_panel 接入）、ADR-0044（plan_editor 接入）、ADR-0045（生产化总纲，sentry 崩溃监控归此脉络）、ADR-0060（drift 单库，D1 sentry_drift 归属判据）
