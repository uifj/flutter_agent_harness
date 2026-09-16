# AGENTS.md — AI 代理入口文档

> 本文件是所有 AI 编码代理（Qoder / Trae / Copilot / Claude Code / Codex 等）进入本仓库的第一站。任何任务开始前：先读本文件 → 再读下方规则 → 按关键词路由加载对应 skill → 动手。

## 0. 必读配置（按优先级）

| 路径 | 作用 | 必读 |
| --- | --- | --- |
| `.qoder/rules/ponytail.md` / `.trae/rules/ponytail.md` | 底层编码哲学：懒惰阶梯（YAGNI → 复用 → stdlib → 最简）；根因修复而非打补丁 | ✅ 任务前 |
| `.qoder/rules/workflow.md` / `.trae/rules/workflow.md` | 三条硬不变量 + 关键词自动路由表 + skill 集合边界（已裁掉 7 个）+ 提交/测试/i18n/主题约定 | ✅ 任务前 |
| `.qoder/rules/build.md` / `.trae/rules/build.md` | 桌面端构建事实：版本基线、仅 macOS、entitlements/沙箱边界、签名缺口、出包清单 | 构建/排障/发布前 |
| `.qoder/skills/` / `.trae/skills/` | 25 个 skill（git-commit、flutter-*、dart-*、ponytail-*）；哪些被裁掉、为什么，见 workflow.md §2 | 按需 |
| [docs/README.md](docs/README.md) | 文档体系规范：ADR 分类 / 优先级 / 状态机 / 新增流程 | 记录问题时 |
| [docs/debt-register.md](docs/debt-register.md) | 技术债与缺陷登记表（唯一状态源）：当前 1 条已登记 ADR + 5 条待立 ADR 的观察 | 动手前 |
| [docs/migration-log.md](docs/migration-log.md) | ADR-0002/0003/0004 迁移执行台账：阶段·commit·门禁·待人签收清单 | 接手迁移时 |
| [docs/starkins-settings-migration-analysis.md](docs/starkins-settings-migration-analysis.md) | 从 starkins_app 迁移设置页的分析：逐项 可迁/改造/不迁 判定 + 不变量冲突（待拍板） | 做该迁移前 |
| [repomix.config.json](repomix.config.json) | 全仓库打包配置（产物 `repomix-output.xml` 不入库；已排除 vendored UI 库实现） | 按需 |
| `技术文档-agent_harness基于genkit-dart的可落地增强路线.md` | genkit-dart 0.16.1 逐文件审读：能借哪些能力、要绕哪些限制、该放弃哪些幻想 | 动运行时前 |
| `对标技术文章-agent_harness与dsh生态横向对比.md` | 与 dsh / better-sidebar 的十维度对比与完成度评估 | 判断"该不该做"前 |

> **路径说明**：`.qoder/` 与 `.trae/` 是同步镜像，rules 与 skills 均逐文件一致（skill 数量以 workflow.md §2 为准）。Qoder 代理优先读 `.qoder/`，Trae 代理优先读 `.trae/`。改任一份必须同时改另一份，否则两个 IDE 的行为会静默分叉。
>
> **本文件不存在的引用**：本仓库没有 `.mcp.json`（无 context7 等 MCP 服务器）、没有 `CI-CD.md`。别按"应该在那儿"去写代码或声称查过。

## 1. 仓库概览

- **是什么**：`agent_harness` —— 用 **Flutter + Google Genkit** 从零实现的 **桌面端 AI Agent 工作台**：对话流 + 工具调用投影 + 分栏 workbench（文件树 / 编辑器 / 终端 / git / diff / 浏览器 / 子 agent / side chat）。pubspec 自述："A Flutter desktop agent harness: chat UI, tool-call projection via Genkit, and a split-pane workbench."
- **不是什么**：不是移动端/网页 App（三桌面平台 `macos/`+`windows/`+`linux/`，见 ADR-0003；无 `android/`/`ios/`/`web/`）；不是 dsh 的 fork（不吸收其代码，只取其设计思想重写）；不是发布物（`version: 0.0.1`，ad-hoc 签名，见 `build.md` §4）。
- **规模**：`lib/` 95 个 Dart 文件 / ~29.5k 行，`test/` 39 个测试文件；`spike/` 2 个可执行证据脚本。
- **技术栈**：Dart SDK `^3.11.5` / Flutter 3.41.9 stable；运行时 `genkit` 0.16.1 + `genkit_openai` / `genkit_anthropic` / `genkit_google_genai` / `genkit_mcp` / `genkit_middleware`（**全是 0.x**）；状态管理 `flutter_riverpod` 3.2.1 + `riverpod_annotation` 4.0.2（ADR-0002 修订 1：注解模式，`*.g.dart` 入库）；组件库 `shadcn_ui` 0.56.3（迁移中）；宿主能力 `flutter_pty` + `xterm`（终端）、`flutter_inappwebview`（浏览器 tab）、`file_picker` + `path_provider`（工作区）、`pasteboard`（剪贴板）、`gpt_markdown` + `re_editor` + `re_highlight`（渲染与编辑）、`schemantic`（工具运行时 schema）、`flutter_lucide`（图标）。lint 只有 `flutter_lints`（`riverpod_lint` 因 SDK meta 约束暂不可装，见 ADR-0002 修订 1）。
- **刻意不存在的机制**：genkit 工具输入保持 Map、schema 运行时构造（codegen 仅限 riverpod 注解，见 ADR-0002 修订 1）；没有 `intl` / `.arb` / `flutter_localizations`（i18n 自研，见 §3）；没有路由表（单窗口，界面靠 widget 组合与 scope 拼装）。

## 2. 目录导航

| 路径 | 文件 | 行 | 职责 |
| --- | --- | --- | --- |
| `lib/main.dart` | 1 | ~240 | 纯装配：开 store → 恢复工作区授权 → 建 riverpod container（override stores）→ 挂树。**不做决策** |
| `lib/genkit/` | 8 | 3.1k | Genkit 唯一的家：`agent_runtime`（投影 + 系统提示 + 审批回路）、`tools`（`WorkspaceTools`）、`shell_run` / `text_edit` / `read_window` / `plan_tools` / `file_search` / `models_endpoint` |
| `lib/model/` | 18 | 3.7k | 纯 Dart 领域词汇：`conversation` / `turn_event` / `turn_source` / `approval_mode` / `sidebar_tab` / `split_node` / `workbench` / 各 settings。手写 `toJson`/`fromJson` |
| `lib/state/` | 15 | 3.1k | 控制器与持久化：`app_providers` + 生成件 `.g.dart`（riverpod 注解层：stores、read seams、9 个 per-controller provider，ADR-0002）、`app_scope`（组合根：runtime 热替换链仍在其中）、`conversation_controller`、`workbench_controller` / `split_node` 布局、`layout_controller`、`settings_store` / `prefs_store`（原子写）、`streaming_tail` |
| `lib/host/` | 3 | 0.7k | 宿主能力：`git`、`terminal_manager`、`project_folder_ops`（security-scoped bookmark） |
| `lib/ui/` | 46 | 18k | 界面：`workbench/`（16，含 `tabs/` 与 `tab_registry`）、`primitives/`（13，卡片/代码块/diff/终端等自绘件）、`conversation/`（12）、`layout/columns.dart`（约束求解）、`sidebar`、`tool/tool_card`、`settings` |
| `lib/theme/` | 5 | 0.9k | `dsw_alias`（令牌）→ `dsw_theme`（挂到 `ThemeData` + `DswShadow` elevation ramp）→ `dsw_typography` / `dsw_motion` / `dsw_static` |
| `lib/l10n/` | 1 | 0.7k | `locales.dart`：en/zh 双字典（键集当前完全对齐；条数不写死，见 debt-register 的 i18n 条）+ `AppLocaleScope` + `context.tr()`，zh 逐键回退 en |
| `spike/` | 2 | — | `agent_spike.dart`（genkit 真实形状的可执行证据，头部 FINDINGS）、`runtime_smoke.dart`（命令行驱动 runtime 的验收门） |
| `packages/flutter-shadcn-ui/` | — | — | **vendored 源码镜像，`.gitignore` 排除**（ADR-0001）。`shadcn_ui` 0.56.3 已是 pubspec 依赖（ADR-0002 实施中），但配色仍走 `dsw_*`（经 `theme/dsw_shad_bridge.dart`）。查组件 API 用入库的 `.qoder/skills/shadcn-ui-flutter/`；读实现看此目录或上游 `nank1ro/flutter-shadcn-ui` `0.56.3` |
| `docs/` | — | — | `README.md`（ADR 规范）+ `debt-register.md`（状态源）+ `adr/`（模板 + ADR-0001/0002/0003）+ `design-audit-2026-09.md` |

## 3. 架构不变量（违反即错误，命令可自证）

```
grep -rn "package:genkit" lib/ | grep -v "^lib/genkit/"   # 必须为空（注释文字除外）
grep -rln "package:flutter" lib/model/                    # 必须为空
grep -rn "\.\./ui/" lib/state/                            # 只有 layout_controller 一条已知例外
```

Genkit 变更只应砸 `lib/genkit/` 两个文件，而不是穿过 widget 树；`lib/model/` 是运行时与 UI 之间的唯一词汇表。唯一被放行的例外是 `test/restore_projection_test.dart`（它要构造持久化形状），别顺手清掉。完整表述与例外登记见 `.qoder/rules/workflow.md` §0。

## 4. 环境与命令

```
flutter pub get            # 每台新机器第一步（本机当前连 pub cache 都没有）
flutter analyze            # 无告警才算干净
dart format --set-exit-if-changed .
flutter test               # 只有 flutter test；dev 依赖没有 package:test，dart test 跑不起来
flutter test test/conversation_controller_test.dart     # 守住流式拆分这条性能契约
dart run spike/agent_spike.dart          # genkit 升版后必跑，核对头部 FINDINGS
dart run spike/runtime_smoke.dart        # 离线冒烟；带 DEEPSEEK_API_KEY 真跑工具环与审批
flutter build macos --release            # 需 macOS + Xcode + CocoaPods
flutter run -d windows                         # Windows/Linux 桌面目标本机可跑（ADR-0003）
```

本机是 Windows：`flutter build windows` / `flutter run -d windows` 可本机验证（浏览器 tab 除外，见 ADR-0003）；`flutter build macos` 与 `pod install` 仍需在 macOS 真机验证，未跑过一律标"待 macOS 验证"。详见 `.qoder/rules/build.md`。

## 5. 工作流速查

| 场景 | 动作 |
| --- | --- |
| 「理解代码 / 梳理仓库」 | 局部直接读文件；全仓库跑 `repomix` 后基于产物回答；证据用「文件:行号」 |
| 「提交代码」 | `git-commit` skill → Conventional Commits，scope 用 `genkit`/`model`/`state`/`ui`/`theme`/`l10n`/`host`/`workbench`/`macos`/`docs`/`deps`，描述英文祈使句 ≤72 字符 |
| 「genkit 升版 / 这个 API 怎么写」 | 先 `dart run spike/agent_spike.dart`，`flutter pub deps` 核对版本，再读 pub cache 里的包源码 |
| 「加工具 / 改审批 / 加 tab / 改文案 / 改主题令牌」 | 走 `.qoder/rules/workflow.md` §3 的五条固定链路（工具、tab、文案、主题、持久化） |
| 「布局溢出 / 响应式」 | `flutter-fix-layout-issues` / `flutter-build-responsive-layout`（先看 `ui/layout/columns.dart`） |
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
- **已移除 7 个**（与自研 i18n / 无路由表 / 不用代码生成器 / 仅 macOS 目标直接冲突）：`flutter-setup-localization`、`flutter-setup-declarative-routing`、`dart-generate-test-mocks`、`dart-use-ffigen`、`dart-setup-ffi-assets`、`dart-migrate-to-checks-package`、`flutter-add-integration-test`。逐条理由与"要用回来必须先满足的前提"在 workflow.md §2；不要偷偷重装。

## 7. 硬性红线

- 永不修改 git config（`--no-verify` 同理）；永不 `force push` / `hard reset`；钩子失败后新建 commit，绝不 amend 已存在的提交。
- 永不提交密钥：API key、证书、描述文件、`.env`。当前 `.gitignore` 里**没有** `*.p12` / `*.cer` / `*.mobileprovision`，要引入证书前先补忽略规则（`build.md` §4）。
- 不新增依赖、不加抽象、不引入代码生成器（`build_runner` 等），除非任务明确要求且已立 ADR。
- 动 `macos/Runner/Release.entitlements` / `DebugProfile.entitlements`（尤其那个"故意没开的 App Sandbox"）= 动产品能力边界，先有 ACCEPTED 的 ADR。
- 未在 macOS 上真跑过，不得声称 macOS 构建/出包成功。
- 加载 skill ≠ 停止思考：skill 给规范步骤，仍按任务范围最小实现（ponytail）。

## 8. 现状缺口（以登记表为准）

已知缺口的分类、优先级、状态一律看 [docs/debt-register.md](docs/debt-register.md)：`README.md` 仍是包模板、i18n 双语对齐无测试守卫、macOS 签名/公证缺口与 `.gitignore` 缺证书规则、无 CI 且版本仍 `0.0.1`。**修任何一个之前先按 `docs/README.md` 立 ADR 并置 ACCEPTED。**

两条不算债务、但容易被误当成"应该在那儿"的事实：

1. 没有 `.mcp.json` —— 本仓库不配任何 MCP 服务器。
2. `.qoder/` 与 `.trae/` 里的规则与 skill 集合是 2026-09-15 才按本仓库事实重建的（此前内容整份属于另一个项目）。今后再发现规则与代码不符，先改规则、再改代码，别将错就错。
