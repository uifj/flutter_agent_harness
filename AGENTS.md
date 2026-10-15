# AGENTS.md — PlanStar 代理入口

> 本文件是所有 AI 编码代理（Qoder / Trae / Copilot / Claude Code / Codex 等）进入本仓库的第一站，也是 PlanStar **运行时 agent** 每次开会话都会读到的指令（ADR-0009）。任务开始前：读本文件 → 读下方规则 → 按关键词路由加载 skill → 动手。**这里放不进 prompt 的东西（密钥、内部主机名）一律不要写。**

## 0. 必读配置

| 路径 | 作用 | 何时读 |
| --- | --- | --- |
| `.qoder/rules/ponytail.md` ↔ `.trae/rules/ponytail.md` | 底层编码哲学：懒惰阶梯（YAGNI → 复用 → stdlib → 最简）；根因修复而非打补丁 | 每个任务前 |
| `.qoder/rules/workflow.md` ↔ `.trae/rules/workflow.md` | **密集操作层的唯一权威源**：三条硬不变量全表述 + 关键词自动路由表 + skill 集合边界（已裁 7 个）+ 提交/测试/i18n/主题约定 + 双树工作台与企划/代理模式的固定链路 | 动手前 |
| `.qoder/rules/build.md` ↔ `.trae/rules/build.md` | 桌面构建事实：版本基线、三桌面目标 + 两移动脚手架、CI 门禁口径、entitlements/沙箱、签名缺口、出包清单 | 构建/排障/发布前 |
| `.agents/skills/` | PlanStar 专属工作流/约束技能（spec、design-first、architecture、testing、review），带 `references/` 渐进披露，**且会被运行时 agent 注入**（见 §6 与 `.agents/README.md`） | 按流水线 |
| `.qoder/skills/` ↔ `.trae/skills/` | 25 个通用技能（git-commit、flutter-*、dart-*、ponytail-*、shadcn-ui-flutter）；哪些被裁、为什么见 workflow.md §2 | 按需 |
| `.claude/settings.json` | harness 配置：Bash/WebFetch/Skill 权限白名单 + 守护生成物的 PreToolUse 钩子 | Claude Code 类 harness |
| [docs/README.md](docs/README.md) | 文档体系规范：ADR 分类 / 优先级 / 状态机 / 新增流程 | 记录问题时 |
| [docs/debt-register.md](docs/debt-register.md) | **技术债与缺陷登记表（唯一状态源）**。逐条状态、commit、下一 ADR 编号一律以它 + `ls docs/adr/` 现场为准，**别抄任何写死的状态串** | 动手前 / 修已登记问题前 |

> 更多专题文档（企划三面、分组施工表、UI/生产化/shad 采纳、各家对比评估、真机签收单）在 `docs/` 里；它们各自管一片，动手前按 `docs/debt-register.md` 与 workflow.md §3 的链接下钻，别在本文件里维护第二份清单。

## 1. 仓库概览

- **是什么**：**企划星 / PlanStar**（pubspec 包名 `planstar`，macOS bundle id `top.planstar.desktop`，用户级指令目录 `~/.planstar`）—— 用 **Flutter + Google Genkit** 从零实现的**桌面端 AI Agent 工作台**，两种工作区模式：**企划**（当前工作区内 .md 的本地工作台，复现 Anytype 客户端的数据视图内核——一个集合 = Table/List/Gallery/Board/Calendar 对同一份记录的五种投影，外加库屏与块编辑器，ADR-0007 立模式、ADR-0037 换内核）与**代理**（对话流 + 工具调用投影 + 分栏 workbench，右栏与下栏**两棵树**）。
- **不是什么**：不是能在手机上跑的应用——真正的目标平台是三个桌面（`macos/`+`windows/`+`linux/`，ADR-0003），`android/`+`ios/` 只是品牌脚手架（启动即撞上未注册的 `window_manager`，而 `flutter build ios` 仍会绿——**别把绿构建当成能跑**）；无 `web/`；不是 dsh 的 fork（只取其设计思想重写）；不是发布物（`version: 0.1.0`，ad-hoc 签名，见 `build.md` §4）。
- **规模**：`lib/` ~165 个 Dart 文件 / ~54.6k 行（ui 最大），`test/` ~102 个 `*_test.dart`，`docs/adr/` 到 ADR-008x，入库本地包 `packages/board_panel` 另有 ~72 文件。**这些数字是快照，会腐烂**——引用前用 `find`/`wc`/`ls docs/adr` 现场重算。
- **技术栈**：Dart `^3.11.5` / Flutter 3.41.9 stable；运行时 `genkit` 0.16.1 + `genkit_openai`/`genkit_anthropic`/`genkit_google_genai`/`genkit_mcp`/`genkit_middleware`（**全是 0.x**）；`flutter_riverpod` 3.2.1（注解模式，`*.g.dart` 入库）；`shadcn_ui` 0.56.3 + 入库本地包 `board_panel`；`drift` 2.31（单库多域 `<support>/planstar.db`）；宿主能力 `flutter_pty`+`xterm`、`flutter_inappwebview`、`tray_manager`+`window_manager`+`hotkey_manager`、`pdfrx` 等。lint 只有 `flutter_lints`。
- **刻意不存在**：genkit 工具输入保持 Map、schema 运行时构造（codegen 仅限 riverpod 注解、drift 表、`flutter gen-l10n`）；i18n 走 `flutter_localizations` + ARB + `gen-l10n`（ADR-0082 flip 后从自研双字典迁来）；没有路由表（单窗口，界面靠 widget 组合与 scope 拼装）。

## 2. 目录导航

| 路径 | 职责 |
| --- | --- |
| `lib/main.dart` | 纯装配：开 store → 恢复工作区授权 → 建 riverpod container（override stores）→ 挂树（`MaterialApp` 自带 `localizationsDelegates`/`supportedLocales`/`locale`，builder 那道缝按 `MediaQuery(字号) → ShadTheme → ShadSonner` 包）→ 接 `window_manager`/`tray`/`hotkey`/`window_title`。**不做业务决策** |
| `lib/genkit/` | **Genkit 唯一的家**：`agent_runtime`（投影 + 系统提示 + 审批回路 + 指令注入 + `_GuideInjector` + MCP host + 子 agent 委托）、`tools`（`WorkspaceTools`：read/write/edit/glob/grep/bash + `decideGate`）、`instructions`（工作区 `AGENTS.md` 发现与合并，ADR-0009）、`shell_run`/`text_edit`/`read_window`/`plan_tools`（agent 的 `todo_write`/`plan` 工具，**与企划模式无关**）/`file_search`/`models_endpoint` |
| `lib/model/` | **纯 Dart 领域词汇**，运行时与 UI 之间的唯一词汇表。对话侧（`conversation`/`turn_event`/`approval_rule`/`queued_input`/`checkpoint` 的 `CheckpointSink` 接口/`mention_expansion`+`workspace_index`/`fs_revision`）；工作台侧（`sidebar_state` 双树/`split_node`/`workbench`/`known_models`）；企划侧（十个 `plan_*`：`plan_struct` 记录是视图、`plan_filter_engine` 筛选排序分组唯一答案处、`plan_markdown_codec` Markdown 是唯一盘上格式）；分组历史（`session_meta`/`session_groups`/`relative_time`）。手写 `toJson`/`fromJson` |
| `lib/state/` | 控制器与持久化：`app_providers`（+ 唯一入库生成件，全部 provider）/`app_scope`（组合根）/`conversation_controller`/`workbench_*`（双树持久化）/`layout_controller`/**`git_status_store`**（全仓唯一跑 `git status` 的地方，ADR-0043）/`workspace_mode_controller`（企划/代理）/`plan_object_store`/`plan_block_document`/`approval_rule_store`/`checkpoint_store`/`session_index`/`session_registry`/`backup_service`/`settings_store`·`prefs_store`（原子写） |
| `lib/host/` | 宿主能力：`git`/`terminal_manager`/`support_directory`/`project_folder_ops`（security-scoped bookmark）/`profile_repository`/`reveal`（`lib/ui` 不许直接 `dart:io`，界面经 `ui/primitives/reveal.dart` 调它） |
| `lib/ui/` | 界面：`workbench/`(+`tabs/`)/`primitives/`（自绘件：`tappable.dart` 的 `DswHoverTap`、`icon_button.dart`、`menu.dart`、`feedback.dart`、`reveal.dart`）/`conversation/`/`layout/columns.dart`/**`plan/`**（`dataview/` 五投影 + `library/` 库屏 + `blocks/` + `widgets/`）/`settings/`/`sidebar/`/`tool/`（`tool_card` + `checkpoint_scope`）/根 `app_frame.dart` |
| `lib/theme/` | `dsw_alias`（令牌）→ `dsw_theme` → `dsw_typography`/`dsw_shape`（半径·图标·控件尺寸档位）/`dsw_motion`/`dsw_static`/`dsw_shad_bridge`（DswAlias→ShadColorScheme）。**颜色/字号/动效/阴影/圆角只从这里取** |
| `lib/l10n/` | ARB + `flutter gen-l10n`（ADR-0082）：`app_en.arb`（模板/源）+ `app_zh.arb` 是唯一盘上源，生成物 `app_localizations*.dart` + `untranslated.json` 入库；`tr_key.dart` 是动态键桥；`hardcoded_copy_test.dart` 零容忍硬编码中文 |
| `spike/` | `agent_spike.dart`（genkit 真实形状的可执行证据，头部 FINDINGS）、`runtime_smoke.dart`（命令行驱动 runtime 的验收门，靠 ADR-0015 才能编译） |
| `tool/` | `contrast_check.dart`（WCAG 对比度三求值）、`check_architecture.dart`（七条架构规则门禁）+ baseline |
| `packages/board_panel/` | **入库的本地包**（path 依赖，ADR-0001"vendored 不入库"的个案例外）：企划只吃它的 Board（分组列拖拽）与 `MonthView`，Table/List/Gallery 宿主画。`analysis_options.yaml` 把 `packages/**` 排除在 lint/format 之外，改它要在该包内单独验证 |
| `android/` + `ios/` | ADR-0057 加入的**品牌脚手架，应用在其中不可运行**：只承载各平台图标与启动图 |
| `docs/` · `.github/workflows/` | ADR 规范 + 登记表 + 专题文档 / `pr-check.yml`（format + analyze + test）+ `build.yml`（手动三桌面出包），都钉 `FLUTTER_VERSION: '3.41.9'` |

## 3. 架构不变量（违反即错误，命令可自证）

```
grep -rn "package:genkit" lib/ | grep -v "^lib/genkit/"   # 必须为空（注释文字除外）
grep -rln "package:flutter" lib/model/                    # 必须为空
grep -rn "\.\./ui/" lib/state/                            # 只有 layout_controller 一条已知例外
grep -rn "package:flutter\|\.\./state/" lib/genkit/       # 必须为空：运行时不许碰 Flutter，也不许伸进 lib/state（ADR-0015）
```

Genkit 变更只应砸 `lib/genkit/` 两个文件，而不是穿过 widget 树；`lib/model/` 是运行时与 UI 之间的唯一词汇表。唯一被放行的例外是 `test/restore_projection_test.dart`（它要构造持久化形状），别顺手清掉。完整表述与例外登记见 `.qoder/rules/workflow.md` §0，也在 `.agents/skills/architecture/references/invariants.md`。

这四行 grep 现在有一条命令代替：**`dart tool/check_architecture.dart`**（ADR-0011，规则 6 由 ADR-0015 补、规则 7 由 ADR-0020 补）。它按七条规则（三条不变量 + 运行时不碰 Flutter/state + `lib/ui` 不直接 `dart:io` + riverpod 只在装配根 + 反馈条只有一个入口）用**指纹 baseline + 只拦新增**运作，并由 `test/architecture_check_test.dart` 跟着 `flutter test`（= CI）一起跑。`tool/architecture_baseline.json` 是今日实况，不是豁免清单——债务修掉了要 `--update` 缩小它。

## 4. 环境与常用命令

```bash
flutter pub get                                # 每台新机器第一步（.dart_tool/、pubspec.lock、macOS ephemeral 都不入库）
dart run build_runner build --force-jit        # 改了 drift 表后跑（aot 在 drift_dev 2.31 上失败，用 jit）
dart format --set-exit-if-changed lib test tool spike packages/appunits/app_common packages/appunits/plan_editor packages/infras/stone_core   # 与 CI 同口径（不是 `.`；ADR-0085 D5 三个一手包进闸）
dart analyze --fatal-infos lib test tool spike packages/appunits/app_common packages/appunits/plan_editor packages/infras/stone_core          # 与 CI 同口径；flutter analyze 可作本地快查
flutter test                                    # 只有 flutter test；dev 依赖没有 package:test，dart test 跑不起来
flutter test packages/appunits/plan_editor packages/infras/stone_core   # 一手包的单测（app_common 暂无 test/，见 ADR-0083 治理标准）
dart tool/contrast_check.dart                   # 主题令牌 WCAG 对比度三求值（ADR-0004）
dart tool/check_architecture.dart               # 架构门禁（ADR-0011）；--update 只在债务减少时跑
dart run spike/agent_spike.dart                 # genkit 升版后必跑，核对头部 FINDINGS
dart run spike/runtime_smoke.dart               # 离线冒烟（无 key）；带 DEEPSEEK_API_KEY 真跑工具环与审批
npx repomix@latest                              # 全仓库打包给 AI（产物 repomix-output.xml 不入库）
```

- **版本基线有两处真值**：`pubspec.yaml` 的 `environment.sdk` 与 `.github/workflows/{pr-check,build}.yml` 的 `FLUTTER_VERSION: '3.41.9'`——换 SDK/Flutter 必须同时改并让 pr-check 绿。
- **开发机平台会变**：当前这台是 **macOS (Darwin arm64)、Flutter 3.41.9 / Dart 3.11.5、无 fvm**。不变律只有一条：**没在当前平台真跑过的构建/走查，交付说明一律标"待 <平台> 验证"**（详见 `build.md` §0）。
- **API/文档时效**：genkit 全系 0.x，**以 pub-cache 里的包源码为准**（`flutter pub deps` 现场核对，`pubspec.lock` 不入库故对别人不是事实），别信记忆或营销文案。

## 5. 约定

- **先问要不要构建**（ponytail），再按懒惰阶梯；skill 给规范步骤，仍按任务范围最小实现。
- **Test-first**：先写会失败的测试，再实现；修 bug 先用一个复现它的失败测试钉住（见 testing skill）。
- **未经明确要求，永不 commit / push**（提交永远走 `git-commit` skill，见 §8）。
- **动 `docs/debt-register.md` 已登记的问题前，对应 ADR 必须先 ACCEPTED**；新审计发现先补 ADR 再改代码。
- **文案**：新/改 UI 字符串同时进 `lib/l10n/app_en.arb` + `app_zh.arb`，跑 `flutter gen-l10n` 把生成物一并提交（ADR-0082）；工具 description/error 文本不进 i18n。
- **主题**：颜色/字号/动效/阴影/圆角只从 `lib/theme/dsw_*` 取；**组件用 shad、配色用 dsw**，别读 shad 调色板配色；新令牌必须带读者一起提交。
- **手写文件 ≤1,000 行（含测试）**（ADR-0085 D7）：新增或改动的手写 Dart 文件超过 1,000 行就先拆再改。先例是设置页：`lib/ui/settings/model_settings.dart` 只剩入口 + `_content` 的 switch registry，每一节在自己的 `settings_section_*.dart`（同库 `part`）里——存量 ≥1,500 行的四个文件只在被改动时受这条约束。
- **企划/代理两模式**与工作台链路的固定形状、关键词→动作的完整路由，见 `.qoder/rules/workflow.md` §1/§3——本文件不再重复。

## 6. Skills 流水线（`.agents/skills/`）

这些形成一条工作流管道——每个都由模型按需调用（命中触发语就够着它）并交给下一个：

```
spec → design-first → architecture + testing → review
```

- **spec** — 把 `docs/debt-register.md`/ADR 项或模糊诉求转成带验收标准的规格（*做什么*），拿代码核对前提后签收，交 design-first。
- **design-first** — 动手前定层/模块/接缝/公开面（*怎么塑形*），产出一份需批准的设计草图。
- **architecture** — 实现/重构/评审的分层与代码约束集（不变量、工具契约、Dart/Flutter 风格、i18n/主题/持久化）。
- **testing** — 本仓测试约定：`flutter test`、手写 fake、不变量→守卫对照、反向验证文化、已知基线两失败。
- **review** — 对分支 diff 的三轴评审（Standards + Spec + Correctness），分开报、不跨轴重排。

**注入契约**：`.agents/skills/*/SKILL.md` 会被 PlanStar 运行时 agent 通过 `lib/genkit/instructions.dart` 发现成 `<workspace-skills>` 清单（ADR-0081），因此 **frontmatter 的 `description:` 必须是单行**（YAML 折叠块 `>-` 会被截成字面量、描述丢失）。细节与三树关系见 [.agents/README.md](.agents/README.md)。

**与 plan mode 并用**：plan mode 强制只读 + 批准闸门，这些 skill 供内容——用 `spec`（what）与 `design-first`（how）塑形，它们的验收标准 + 设计草图*就是*那份计划，批准后再在 `architecture`/`testing` 约束下实现。

## 7. 上下文加载（三棵目录）

- **`.qoder/` ↔ `.trae/` 是同步镜像**：3 条 rules + 25 个 skills 内容逐文件一致，唯一设计内差异是各自 `workflow.md` 里对自己目录的引用（`.qoder/rules/…` ↔ `.trae/rules/…`）。Qoder 代理优先读 `.qoder/`，Trae 优先 `.trae/`。**改任一份必须同时改另一份**，否则两个 IDE 静默分叉。
- **`.agents/skills/` 是第三棵树**：PlanStar 专属工作流/约束技能，与上面两棵分工——它编码代理按需加载、**且**被运行时 agent 注入。深层事实（接缝表、守卫对照、威胁模型、不变量全文、Dart/Flutter 风格）都下沉到它的 `references/`，本文件与 workflow.md 只留指针。
- **密集操作层的权威源是 `.qoder/rules/workflow.md`**，专题证据在 `docs/`，逐条状态在 `docs/debt-register.md`。发现规则与代码不符，**先改规则、再改代码**，别将错就错。

## 8. 提交与 PR

- **Conventional Commits**：`<type>[scope]: <description>`，新建 commit 一律走 `git-commit` skill。type 取 feat/fix/refactor/perf/test/docs/build/chore/revert。
- **scope 用本仓顶层归属名**：`genkit`、`model`、`state`、`ui`、`theme`、`l10n`、`host`、`workbench`、`plan`、`macos`、`deps`；`packages/board_panel` 内改动用 `board_panel`；仓库级配置（`.qoder/`、`.trae/`、`.agents/`、`.claude/`、`AGENTS.md`、`.gitignore`、`repomix.config.json`、`tool/`）用 `config`；CI 用 `ci`；ADR 与登记表用 `adr` 或 `docs`。
- **description 用英文现在时祈使句 ≤72 字符**；破坏性变更用 `feat!:` 或 `BREAKING CHANGE:` footer；AI 生成 commit 带 `Co-Authored-By` footer；文件重命名一律 `git mv`。
- **主干工作分支是 `develop`**（ADR-0002 改造面），`main` 可能落后；动手前 `git rev-parse --abbrev-ref HEAD` 现场确认，别信文档写死的分支。
- **安全红线**：永不改 git config、永不 force push/hard reset、永不用 `--no-verify`；钩子失败后修复并**新建** commit，绝不 amend 已存在的提交；一次提交只含一个逻辑变更。
- **不提交**：`repomix-output.*`、`.workbuddy/`、`pubspec.lock`（库型包，已 gitignore）、`_archive_project/`·`_archive_docs/`（本地归档第三方参考，gitignore）、以及任何 API key/证书/描述文件（`.gitignore` 尚无 `*.p12`/`*.cer`/`*.mobileprovision`，引入证书前先补）。

## 9. 维护代理文档

撞到"某条指令本可避免"的墙、文档里的命令/路径写错、或约定已变时，**提议**更新对应文件，不要静默编辑：

- `AGENTS.md` — 环境、命令、目录结构、约定、skills 流水线
- `.qoder/rules/workflow.md` ↔ `.trae/rules/workflow.md` — 关键词路由、不变量全表述、本仓特有链路（改一份必须改另一份）
- `.agents/skills/*/SKILL.md` 与其 `references/` — 工作流与约束技能
- `.claude/settings.json` — 权限白名单与守护钩子

**不要**加任务级一次性补丁、代码里能直接发现的东西、或 linter 已能拦的重复。

## 诚实声明（容易被误当成"应该在那儿"或"还不存在"的事实）

1. **没有 `.mcp.json`** —— 仓库自己不配任何 MCP 服务器。这与应用有没有 MCP 能力是两件事：用户在设置页配的 server 走 `model/mcp_settings.dart`，由 `genkit/agent_runtime.dart` 建 `genkit_mcp` host，工具名形如 `mcp/<name>:tool/<tool>`。别混为一谈，也别在仓库根造一个 `.mcp.json` 来"接上"。
2. **没有 `CI-CD.md`** —— CI 事实看 `.github/workflows/` 与 `build.md`。
3. **`_archive_project/` 与 `_archive_docs/` 已在 `.gitignore`**（约 88 MB 第三方参考与归档文档），新 clone 没有它们，也别想办法加回来。
4. 本文件里的**文件数/行数/测试数/键数/ADR 编号都是快照**，会腐烂——引用前现场重算（`find`/`wc`/`grep -c`/`ls docs/adr`），发现对不上先改文档再动手。
