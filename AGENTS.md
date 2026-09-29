# AGENTS.md — AI 代理入口文档

> 本文件是所有 AI 编码代理（Qoder / Trae / Copilot / Claude Code / Codex 等）进入本仓库的第一站。任何任务开始前：先读本文件 → 再读下方规则 → 按关键词路由加载对应 skill → 动手。

## 0. 必读配置（按优先级）

| 路径 | 作用 | 必读 |
| --- | --- | --- |
| `.qoder/rules/ponytail.md` / `.trae/rules/ponytail.md` | 底层编码哲学：懒惰阶梯（YAGNI → 复用 → stdlib → 最简）；根因修复而非打补丁 | ✅ 任务前 |
| `.qoder/rules/workflow.md` / `.trae/rules/workflow.md` | 三条硬不变量 + 关键词自动路由表 + skill 集合边界（已裁掉 7 个）+ 提交/测试/i18n/主题约定 + 双树工作台与企划/代理模式的固定链路 | ✅ 任务前 |
| `.qoder/rules/build.md` / `.trae/rules/build.md` | 桌面端构建事实：版本基线、三桌面目标与开发机平台、CI 门禁口径、entitlements/沙箱边界、签名缺口、出包清单 | 构建/排障/发布前 |
| `.qoder/skills/` / `.trae/skills/` | 25 个 skill（git-commit、flutter-*、dart-*、ponytail-*）；哪些被裁掉、为什么，见 workflow.md §2 | 按需 |
| [docs/README.md](docs/README.md) | 文档体系规范：ADR 分类 / 优先级 / 状态机 / 新增流程 | 记录问题时 |
| [docs/debt-register.md](docs/debt-register.md) | 技术债与缺陷登记表（唯一状态源）：ADR-0001…0008 已登记 + 观察表若干待立条目（0004 的登记表/正文状态矛盾已于 2026-09-29 拍平为 ACCEPTED·方案 B） | 动手前 |
| [docs/migration-log.md](docs/migration-log.md) | ADR-0002/0003/0004 迁移执行台账：阶段·commit·门禁·待人签收清单 | 接手迁移时 |
| [docs/starkins-settings-migration-analysis.md](docs/starkins-settings-migration-analysis.md) | 从 starkins_app 迁移设置页的分析：逐项 可迁/改造/不迁 判定 + 不变量冲突（待拍板） | 做该迁移前 |
| [repomix.config.json](repomix.config.json) | 全仓库打包配置（产物 `repomix-output.xml` 不入库；已排除 vendored UI 库实现） | 按需 |
| [docs/zcode-vs-agent-harness-2026-09.md](docs/zcode-vs-agent-harness-2026-09.md) | ZCode-main（Apache-2.0 桌面 agent 产品，86.1 万行）逐维度对比与移植评估：UI 布局 / agent 能力 / 功能面 / 工程治理，含 A/B/C 分级路线图与红线检查表 | 判断"要不要搬 ZCode 的某个能力"前 |
| `技术文档-agent_harness基于genkit-dart的可落地增强路线.md` | genkit-dart 0.16.1 逐文件审读：能借哪些能力、要绕哪些限制、该放弃哪些幻想 | 动运行时前 |
| `对标技术文章-agent_harness与dsh生态横向对比.md` | 与 dsh / better-sidebar 的十维度对比与完成度评估 | 判断"该不该做"前 |

> **路径说明**：`.qoder/` 与 `.trae/` 是同步镜像：3 个 rules + 25 个 skills 的**内容**逐文件一致，唯一设计内差异是 `rules/workflow.md` 里对自己目录的引用（`.qoder/rules/…` ↔ `.trae/rules/…`）。Qoder 代理优先读 `.qoder/`，Trae 代理优先读 `.trae/`。改任一份必须同时改另一份，否则两个 IDE 的行为会静默分叉。
>
> **本文件不存在的引用**：本仓库没有 `.mcp.json`（无 context7 等 MCP 服务器）、没有 `CI-CD.md`。别按"应该在那儿"去写代码或声称查过。

## 1. 仓库概览

- **是什么**：`agent_harness` —— 用 **Flutter + Google Genkit** 从零实现的 **桌面端 AI Agent 工作台**：两种工作区模式（**企划**：工作区内 .md 的本地 Markdown 工作台 + 看板/日程/表格扩展面板，ADR-0007；**代理**：对话流 + 工具调用投影 + 分栏 workbench（文件树 / 编辑器 / 终端 / git / diff / 浏览器 / 子 agent / side chat），工作台有右栏与下栏**两棵树**）。pubspec 自述："A Flutter desktop agent harness: chat UI, tool-call projection via Genkit, and a split-pane workbench."
- **不是什么**：不是移动端/网页 App（三桌面平台 `macos/`+`windows/`+`linux/`，见 ADR-0003；无 `android/`/`ios/`/`web/`）；不是 dsh 的 fork（不吸收其代码，只取其设计思想重写）；不是发布物（`version: 0.0.1`，ad-hoc 签名，见 `build.md` §4）。
- **规模**：`lib/` 115 个 Dart 文件 / ~35.1k 行，`test/` 52 个 `*_test.dart`（另有 3 个手写替身 + 1 个探针）；`spike/` 2 个可执行证据脚本，`tool/` 1 个对比度校验脚本。
- **技术栈**：Dart SDK `^3.11.5` / Flutter 3.41.9 stable；运行时 `genkit` 0.16.1 + `genkit_openai` / `genkit_anthropic` / `genkit_google_genai` / `genkit_mcp` / `genkit_middleware`（**全是 0.x**）；状态管理 `flutter_riverpod` 3.2.1 + `riverpod_annotation` 4.0.2（ADR-0002 修订 1：注解模式，`*.g.dart` 入库）；组件库 `shadcn_ui` 0.56.3（迁移中）+ 入库本地包 `board_panel`（path 依赖，ADR-0007 D5）；宿主能力 `flutter_pty` + `xterm`（终端）、`flutter_inappwebview`（浏览器 tab）、`file_picker` + `path_provider`（工作区）、`pasteboard`（剪贴板）、`tray_manager` + `window_manager` + `hotkey_manager`（托盘/窗口/全局热键）、`desktop_drop`（拖拽入 composer）、`pdfrx`（PDF 与文档抽文本）；渲染与编辑 `gpt_markdown`（含 LaTeX 与 `flutter_mermaid` 围栏图）+ `re_editor` + `re_highlight`、`archive`（本地备份 zip）、`schemantic`（工具运行时 schema）、`flutter_lucide`（图标）。lint 只有 `flutter_lints`（`riverpod_lint` 因 SDK meta 约束暂不可装，见 ADR-0002 修订 1）。
- **刻意不存在的机制**：genkit 工具输入保持 Map、schema 运行时构造（codegen 仅限 riverpod 注解，见 ADR-0002 修订 1）；没有 `intl` / `.arb` / `flutter_localizations`（i18n 自研，见 §3）；没有路由表（单窗口，界面靠 widget 组合与 scope 拼装）。

## 2. 目录导航

| 路径 | 文件 | 行 | 职责 |
| --- | --- | --- | --- |
| `lib/main.dart` | 1 | ~240 | 纯装配：开 store → 恢复工作区授权 → 建 riverpod container（override stores）→ 挂树；并接 `window_manager` / `tray_service` / `hotkey_service`。**不做业务决策** |
| `lib/genkit/` | 9 | 3.4k | Genkit 唯一的家：`agent_runtime`（投影 + 系统提示 + 审批回路 + 指令注入）、`tools`（`WorkspaceTools`）、`instructions`（工作区 `AGENTS.md` 发现与合并，ADR-0009，纯 Dart）、`shell_run` / `text_edit` / `read_window` / `plan_tools` / `file_search` / `models_endpoint` |
| `lib/model/` | 21 | 4.1k | 纯 Dart 领域词汇：`conversation` / `turn_event` / `turn_source` / `approval_mode` / `sidebar_tab`（+ `sidebar_state` 双树）/ `split_node` / `workbench` / `workspace` / `plan_task` / `user_profile` / `known_models` / `mcp_settings` / 各 settings。手写 `toJson`/`fromJson` |
| `lib/state/` | 21 | 4.0k | 控制器与持久化：`app_providers`（+ 唯一入库生成件 `app_providers.g.dart`，19 个 provider：stores、read seams、per-controller provider，ADR-0002）、`app_scope`（组合根：runtime 热替换链仍在其中）、`conversation_controller`、`workbench_controller` / `workbench_store`（双树持久化）、`layout_controller`、`workspace_mode_controller`（企划/代理，ADR-0007）、`plan_task_store`、`model_directory`、`session_index`、`backup_service`、`tray_service`、`hotkey_service`、`document_extractor`、`settings_store` / `prefs_store`（原子写）、`streaming_tail` |
| `lib/host/` | 4 | 0.8k | 宿主能力：`git`、`terminal_manager`、`project_folder_ops`（security-scoped bookmark）、`profile_repository`（ADR-0006 S1，用户 Profile） |
| `lib/ui/` | 53 | ~22k | 界面：`workbench/`（16，含 `tabs/` 9、`tab_registry`、`workbench_tab_bar` 右键菜单）、`primitives/`（15，卡片/代码块/diff/终端等自绘件）、`conversation/`（12，含 `assistant_markdown`：LaTeX + Mermaid）、`layout/columns.dart`（约束求解）、`plan/`（2，企划工作台 + 扩展面板）、`settings/`（3：全屏设置 + `widgets/` 卡片与级联快捷菜单）、`sidebar`、`tool/tool_card`、根 `app_frame.dart`（五区外壳）+ `appearance_scope.dart` |
| `lib/theme/` | 6 | 1.0k | `dsw_alias`（令牌）→ `dsw_theme`（挂到 `ThemeData` + `DswShadow` elevation ramp）→ `dsw_typography` / `dsw_motion` / `dsw_static` / `dsw_shad_bridge`（DswAlias→ShadColorScheme） |
| `lib/l10n/` | 1 | 0.9k | `locales.dart`：en/zh 双字典（键集对齐由 `test/l10n_parity_test.dart` 守卫，ADR-0008；条数不写死）+ `AppLocaleScope` + `context.tr()`，zh 逐键回退 en |
| `spike/` | 2 | — | `agent_spike.dart`（genkit 真实形状的可执行证据，头部 FINDINGS）、`runtime_smoke.dart`（命令行驱动 runtime 的验收门） |
| `tool/` | 2 | — | `contrast_check.dart`：对 `dsw_static` + `dsw_alias` 做 WCAG 对比度三求值（dart:io/dart:math only），`dart tool/contrast_check.dart`；`check_architecture.dart`：五条架构规则的指纹 baseline 门禁（ADR-0011），baseline 落 `tool/architecture_baseline.json` |
| `packages/board_panel/` | — | — | **入库的本地包**（path 依赖，ADR-0007 D5 记录为 ADR-0001"vendored 不入库"的例外）：看板/日程/表格扩展面板，由 `ui/plan/plan_extensions_view.dart` 消费，数据来自 `state/plan_task_store.dart` |
| `packages/flutter-shadcn-ui/` | — | — | **vendored 源码镜像，`.gitignore` 排除**（ADR-0001）。`shadcn_ui` 0.56.3 已是 pubspec 依赖（ADR-0002 实施中），但配色仍走 `dsw_*`（经 `theme/dsw_shad_bridge.dart`）。查组件 API 用入库的 `.qoder/skills/shadcn-ui-flutter/`；读实现看此目录或上游 `nank1ro/flutter-shadcn-ui` `0.56.3` |
| `docs/` | — | — | `README.md`（ADR 规范）+ `debt-register.md`（状态源）+ `migration-log.md` + `adr/`（模板 + ADR-0001…0008）+ 审计报告与优化方案 |
| `.github/workflows/` | 2 | — | `pr-check.yml`（push/PR 到 develop·main：format + `dart analyze --fatal-infos` + `flutter test`）、`build.yml`（`workflow_dispatch`：三桌面平台出包 + 可选 GitHub Release）。两者都钉 `FLUTTER_VERSION: '3.41.9'` |

## 3. 架构不变量（违反即错误，命令可自证）

```
grep -rn "package:genkit" lib/ | grep -v "^lib/genkit/"   # 必须为空（注释文字除外）
grep -rln "package:flutter" lib/model/                    # 必须为空
grep -rn "\.\./ui/" lib/state/                            # 只有 layout_controller 一条已知例外
```

Genkit 变更只应砸 `lib/genkit/` 两个文件，而不是穿过 widget 树；`lib/model/` 是运行时与 UI 之间的唯一词汇表。唯一被放行的例外是 `test/restore_projection_test.dart`（它要构造持久化形状），别顺手清掉。完整表述与例外登记见 `.qoder/rules/workflow.md` §0。

这三行 grep 现在有一条命令代替：**`dart tool/check_architecture.dart`**（ADR-0011）。它按五条规则（三条不变量 + `lib/ui` 不直接 `dart:io` + riverpod 只在装配根）用**指纹 baseline + 只拦新增**运作，并由 `test/architecture_check_test.dart` 跟着 `flutter test` 一起在 CI 上跑。`tool/architecture_baseline.json` 是今日实况，不是豁免清单。

## 4. 环境与命令

```
flutter pub get            # 每台新机器第一步（本机当前连 .dart_tool/pub cache 都没有）
dart format --set-exit-if-changed lib test tool spike    # 与 CI 同一口径（不是 `.`）
dart analyze --fatal-infos lib test tool spike           # 与 CI 同一口径；`flutter analyze` 可作本地快查
flutter test               # 只有 flutter test；dev 依赖没有 package:test，dart test 跑不起来
flutter test test/conversation_controller_test.dart     # 守住流式拆分这条性能契约
dart tool/contrast_check.dart            # 主题令牌 WCAG 对比度三求值（ADR-0004 的门禁）
dart tool/check_architecture.dart        # 架构门禁（ADR-0011）；--update 只在债务减少时跑
dart run spike/agent_spike.dart          # genkit 升版后必跑，核对头部 FINDINGS
dart run spike/runtime_smoke.dart        # 离线冒烟；带 DEEPSEEK_API_KEY 真跑工具环与审批
flutter build macos --release            # 需 macOS + Xcode + CocoaPods
flutter build windows --release          # 需 VS C++ 桌面负载 + CMake（+ nuget，见 build.md §2B）
flutter build linux --release            # 需 GTK 工具链
```

**开发机平台会变**：本仓库文档在 Windows 开发机上写过 ADR-0003/0005/0006 的真机走查，当前这台是 **macOS (Darwin arm64)、Flutter 3.41.9 / Dart 3.11.5、无 fvm**。规则只认一条不变量：**没在当前这个平台真跑过的构建/走查，交付说明一律标"待 <平台> 验证"**（详见 `.qoder/rules/build.md` §0）。三条门禁命令在两个平台都要绿。

## 5. 工作流速查

| 场景 | 动作 |
| --- | --- |
| 「理解代码 / 梳理仓库」 | 局部直接读文件；全仓库跑 `repomix` 后基于产物回答；证据用「文件:行号」 |
| 「提交代码」 | `git-commit` skill → Conventional Commits，scope 用 `genkit`/`model`/`state`/`ui`/`theme`/`l10n`/`host`/`workbench`/`plan`/`macos`/`docs`/`deps`/`ci`/`config`，描述英文祈使句 ≤72 字符 |
| 「genkit 升版 / 这个 API 怎么写」 | 先 `dart run spike/agent_spike.dart`，`flutter pub deps` 核对版本，再读 pub cache 里的包源码 |
| 「加工具 / 改审批 / 加 tab / 改文案 / 改主题令牌」 | 走 `.qoder/rules/workflow.md` §3 的固定链路（工具、tab、双树面板、工作区模式、文案、主题、持久化） |
| 「布局溢出 / 响应式」 | `flutter-fix-layout-issues` / `flutter-build-responsive-layout`（先看 `ui/layout/columns.dart` 与 `ui/app_frame.dart` 的五区外壳） |
| 「写测试」 | `dart-add-unit-test` / `flutter-add-widget-test`；替身**手写** `test/fake_*.dart`，不要 mockito + build_runner |
| 「构建失败 / 出包 / 签名」 | 按 `.qoder/rules/build.md`：版本基线 → 校验命令 → entitlements → 签名 → 产物清单 |
| 「记录技术债 / 登记缺陷」 | 新建编号 ADR + 在 `docs/debt-register.md` 追加一行；规范见 `docs/README.md` |
| 「查看已知问题」 | 读 `docs/debt-register.md`，下钻 ADR；修复前置 ACCEPTED |

## 6. skill 索引（两份镜像各 25 个，逐文件一致）

- **强制**：`git-commit`。
- **Flutter**（7）：`flutter-apply-architecture-best-practices`、`flutter-build-responsive-layout`、`flutter-fix-layout-issues`、`flutter-add-widget-test`、`flutter-add-widget-preview`、`flutter-implement-json-serialization`、`flutter-use-http-package`。
- **Dart**（10）：`dart-add-unit-test`、`dart-run-static-analysis`、`dart-collect-coverage`、`dart-resolve-package-conflicts`、`dart-fix-runtime-errors`、`dart-write-documentation`、`dart-use-pattern-matching`、`dart-use-primary-constructors`、`dart-build-cli-app`、`dart-use-doc-examples`。
- **ponytail 系列**（6）：`ponytail`、`ponytail-review`、`ponytail-audit`、`ponytail-debt`、`ponytail-gain`、`ponytail-help`。
- **正当组件库**（ADR-0002 实施中）：`shadcn-ui-flutter` 是已引入的 `shadcn_ui` 0.56.3 的组件参考；配色仍走 `lib/theme/dsw_*`（见 `theme/dsw_shad_bridge.dart`），不要读 shad 的调色板来配色。新交互控件优先用 shad 组件或 `primitives/tappable.dart` 的 `DswHoverTap`（都自带键盘/语义），不要再手写 `MouseRegion + GestureDetector`。
- **已移除 7 个**（与自研 i18n / 无路由表 / 不用代码生成器 / 三桌面目标不含移动·web 直接冲突）：`flutter-setup-localization`、`flutter-setup-declarative-routing`、`dart-generate-test-mocks`、`dart-use-ffigen`、`dart-setup-ffi-assets`、`dart-migrate-to-checks-package`、`flutter-add-integration-test`。逐条理由与"要用回来必须先满足的前提"在 workflow.md §2；不要偷偷重装。

## 7. 硬性红线

- 永不修改 git config（`--no-verify` 同理）；永不 `force push` / `hard reset`；钩子失败后新建 commit，绝不 amend 已存在的提交。
- 永不提交密钥：API key、证书、描述文件、`.env`。当前 `.gitignore` 里**没有** `*.p12` / `*.cer` / `*.mobileprovision`，要引入证书前先补忽略规则（`build.md` §4）。
- 不新增依赖、不加抽象、不引入代码生成器（`build_runner` 等），除非任务明确要求且已立 ADR。
- 动 `macos/Runner/Release.entitlements` / `DebugProfile.entitlements`（尤其那个"故意没开的 App Sandbox"）= 动产品能力边界，先有 ACCEPTED 的 ADR。
- 未在某个桌面平台真机跑过，不得声称该平台构建/出包/走查成功（交付说明标"待 <平台> 验证"）。
- 加载 skill ≠ 停止思考：skill 给规范步骤，仍按任务范围最小实现（ponytail）。

## 8. 现状缺口（以登记表为准）

已知缺口的分类、优先级、状态一律看 [docs/debt-register.md](docs/debt-register.md)：`README.md` 与 `CHANGELOG.md` 仍是包模板、macOS 签名/公证缺口与 `.gitignore` 缺证书规则、版本仍 `0.0.1`、无文本缩放适配、ADR-0005 那三项"仅持久化未接线"的偏好。（i18n 双语对齐的守卫缺口已由 ADR-0008 闭环。）**修任何一个之前先按 `docs/README.md` 立 ADR 并置 ACCEPTED。**

**测试基线（本机 macOS，2026-09-29 首跑）不是绝对全绿**：`flutter test` 得 `+699 -2`，两个既有失败（macOS temp 路径 `/var`↔`/private/var` 规范化、企划树 `find.text('notes')` 命中两处）已登记在债务表的待立 ADR 观察里。验收口径因此是**相对基线零新增失败**，不是"全绿"；不要为了让套件变绿去改那两条断言。

**CI 已经有了**（`.github/workflows/`，commit `d09b92d`）：`pr-check.yml` 在 push/PR 到 `develop`·`main` 上跑 format + `dart analyze --fatal-infos` + `flutter test`；`build.yml` 是 `workflow_dispatch` 手动三平台出包并可选发 GitHub Release。**但它只保证门禁命令，不等于签名/公证已过**——CI 产物依旧 ad-hoc，见 `build.md` §4/§5。

三条容易被误当成"应该在那儿"或"还不存在"的事实：

1. 没有 `.mcp.json` —— 本仓库不配任何 MCP 服务器。
2. 主干工作分支是 `develop`（ADR-0002 的改造面），`main` 可能落后；动手前 `git rev-parse --abbrev-ref HEAD` 现场确认，别信任何文档里写死的分支。
3. 根目录 `_archive_project/`（约 88 MB 的第三方参考源码归档）**已在 `.gitignore` 里**（2026-09-29 补），新 clone 不会有它，也别想办法把它加回来。

`.qoder/` 与 `.trae/` 里的规则与 skill 集合是 2026-09-15 才按本仓库事实重建的（此前内容整份属于另一个项目），并在 2026-09-29 按 ADR-0004…0007、CI、双树工作台与新宿主能力做过一轮校准。今后再发现规则与代码不符，先改规则、再改代码，别将错就错。
