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
| [docs/debt-register.md](docs/debt-register.md) | 技术债与缺陷登记表（唯一状态源）：ADR-0001…0041 已登记（**ADR-0030 只在观察表里没有文件**），下一编号 **ADR-0042**；状态与 commit 以该文件和 `ls docs/adr/` 现场为准，别抄任何写死的状态串。ADR-0040 = 企划块编辑器补全（P9：toggle 折叠/序号/引用条/callout/书签 URL/table(RxC)/列菜单/内部剪贴板，@ 3000755），ADR-0041 = 代码侧够到文件（reveal/树展开/编辑器折行） | 动手前 |
| [docs/anytype-feature-inventory-2026-10-01.md](docs/anytype-feature-inventory-2026-10-01.md) | Anytype Android 客户端（`_archive_project/anytype-kotlin` @ `7af5254` = 0.50.4）的**功能清单**，每条带 `path:line`：§1 数据视图六档、§3 块与 slash 可达集、§4 二十三个内置类型 key、§5 十六种关系格式、§7 十三种组件形态与五档布局，外加 §17「看起来有其实没有」23 行（Calendar/Graph 视图、24 种 embed、LaTeX 插入、Notion 导入、used-in、goal/habit 全部为 ⛔/❌）。回答"Anytype 有没有/怎么做这个功能"先读它，别按记忆或营销文案答 |
| [docs/plan-mode-anytype-dataview-migration-2026-10-01.md](docs/plan-mode-anytype-dataview-migration-2026-10-01.md) | ADR-0037 的**施工表**：企划模式复现上述 §1–§7（现状分析 → 目标形状 → `packages/board_panel` 复用线 → 逐段映射 → 分层落位 → P0–P7 阶段提交（真机走查后又补了 P8-a 信封/P8-b 侧栏库/P8-c 工具栏三批）→ 每段守卫清单 → §8 诚实边界；§0 记 2026-10-01 功能契约并入与架构裁决）。动企划模式的数据视图/块/组件之前先读它 |
| [docs/plan-mode-parity-table-2026-10-01.md](docs/plan-mode-parity-table-2026-10-01.md) | ADR-0037 的**实现对照表**（2026-10-01 起是企划复刻的唯一进度源）：模块 1–7 逐条 AC × 上游档位 × 复刻状态 × 代码路径 × 状态层 × shadcn 组件，外加 18 条「简报 vs 上游事实」修正裁决（QUOTE 可插更正、表格死代码动作、条件按格式子集、groupOrders 扩展……）。回答"这个 AC 做了没有/为什么不做"先读它 |
| [docs/agent-history-workspace-groups-2026-10-02.md](docs/agent-history-workspace-groups-2026-10-02.md) | ADR-0039 的**施工表**：代理模式的对话历史按工作区分组（sidecar 归属与墓碑 → 分组纯函数 → 索引与偏好 → 侧栏分组 UI → 工作台两件事），S1–S5 每片带门禁与提交语；上游逐行证据在 ADR-0039 的「背景」里。动 `lib/state/session_registry.dart`、`lib/model/session_groups.dart` 或侧栏历史那一棵之前先读它 |
| [docs/migration-log.md](docs/migration-log.md) | ADR-0002/0003/0004 迁移执行台账：阶段·commit·门禁·待人签收清单 | 接手迁移时 |
| [docs/starkins-settings-migration-analysis.md](docs/starkins-settings-migration-analysis.md) | 从 starkins_app 迁移设置页的分析：逐项 可迁/改造/不迁 判定 + 不变量冲突（待拍板） | 做该迁移前 |
| [repomix.config.json](repomix.config.json) | 全仓库打包配置（`npx repomix@latest`，产物 `repomix-output.xml` 不入库）。2026-10-01 按 ADR-0037 之后的结构重写过 headerText：包内 480 文件 / ~1.22M token，排除项是 `.trae/**` 镜像、`.qoder/skills/**`、`packages/board_panel/example/**`、本地工具状态 `.zcode/**`，加上 `.gitignore` 已经排除的 `_archive_project/` 与 `packages/flutter-shadcn-ui/`。结构或规模变了要重跑并同步改这段文案 | 按需 |
| [docs/ui-consistency-audit-2026-09-30.md](docs/ui-consistency-audit-2026-09-30.md) | **第一批真机窗口截图**（四张）的逐组件走查：令牌层与原语已统一之后剩下的不一致都在内容层——七条里**四条已闭**（§U1 工具卡信封 = ADR-0031、§U2 覆盖层文案 = ADR-0032、§U5 上游路径 = ADR-0033、§U4 圆形短气泡 = ADR-0034），**§U3「对话列三条轴」复核后撤回**（是一条轴两种对齐，判词写在 ADR-0034 的"明确不做"），同批补记的 **§U8（详情栏第二套读法，§U1 的同函数回扫发现，非截图）= ADR-0035 已闭**，剩 §U6/§U7 两条等用户选方向。回答"还有哪些 UI 要调"先读它，别重新调研 |
| [docs/shad-adoption-2026-09-30.md](docs/shad-adoption-2026-09-30.md) | shad 组件采纳映射（ADR-0036 的执行表）：四张真窗截图 36 行逐件三档判定（shad 有则用 / 无则 shad 风格封装 / 保留必带理由）+ B6 菜单 13 处归零 / B7 字段·开关·按钮·徽标 / B8 封装与图标钮身体 + 桥要补的四枚主题项。回答"这个件该不该换 shad、换成哪个"先读它 |
| [docs/zcode-vs-agent-harness-2026-09.md](docs/zcode-vs-agent-harness-2026-09.md) | ZCode-main（Apache-2.0 桌面 agent 产品，86.1 万行）逐维度对比与移植评估：UI 布局 / agent 能力 / 功能面 / 工程治理，含 A/B/C 分级路线图与红线检查表 | 判断"要不要搬 ZCode 的某个能力"前 |
| `技术文档-agent_harness基于genkit-dart的可落地增强路线.md` | genkit-dart 0.16.1 逐文件审读：能借哪些能力、要绕哪些限制、该放弃哪些幻想 | 动运行时前 |
| `对标技术文章-agent_harness与dsh生态横向对比.md` | 与 dsh / better-sidebar 的十维度对比与完成度评估 | 判断"该不该做"前 |

> **路径说明**：`.qoder/` 与 `.trae/` 是同步镜像：3 个 rules + 25 个 skills 的**内容**逐文件一致，唯一设计内差异是 `rules/workflow.md` 里对自己目录的引用（`.qoder/rules/…` ↔ `.trae/rules/…`）。Qoder 代理优先读 `.qoder/`，Trae 代理优先读 `.trae/`。改任一份必须同时改另一份，否则两个 IDE 的行为会静默分叉。
>
> **本文件不存在的引用**：本仓库没有 `.mcp.json`（无 context7 等 MCP 服务器）、没有 `CI-CD.md`。别按"应该在那儿"去写代码或声称查过。

## 1. 仓库概览

- **是什么**：`agent_harness` —— 用 **Flutter + Google Genkit** 从零实现的 **桌面端 AI Agent 工作台**：两种工作区模式（**企划**：当前工作区内 .md 的本地工作台，复现 Anytype 客户端的数据视图内核——集合 = Table/List/Gallery/Board/Calendar 同一份记录的五种投影，外加 All Content／组件条／回收站／Gallery 这几面库屏与块编辑器，ADR-0007 立模式、ADR-0037 换内核；**代理**：对话流 + 工具调用投影 + 分栏 workbench（文件树 / 编辑器 / 终端 / git / diff / 浏览器 / 子 agent / side chat），工作台有右栏与下栏**两棵树**）。pubspec 自述："A Flutter desktop agent harness: chat UI, tool-call projection via Genkit, and a split-pane workbench."
- **不是什么**：不是移动端/网页 App（三桌面平台 `macos/`+`windows/`+`linux/`，见 ADR-0003；无 `android/`/`ios/`/`web/`）；不是 dsh 的 fork（不吸收其代码，只取其设计思想重写）；不是发布物（`version: 0.0.1`，ad-hoc 签名，见 `build.md` §4）。
- **规模**（2026-10-01 现场重算，会腐烂：引用前用 `find`/`wc` 重算）：`lib/` 158 个 Dart 文件（不含 `*.g.dart`）/ ~52.1k 行 —— `ui` 76/30.1k、`model` 37/8.7k、`state` 23/5.6k、`genkit` 9/3.7k、`theme` 7/1.3k、`l10n` 1/1.4k、`host` 4/0.8k、`main.dart` 487；`test/` 95 个 `*_test.dart`（~23.6k 行，另有 3 个手写替身 + 2 个探针 `clipboard_probe.dart`·`amplified_text_probe.dart`）；`docs/` 16 篇 + `docs/adr/` 38 个文件；入库本地包 `packages/board_panel` 另有 72 个 `lib/` dart / ~15.2k 行（不受本仓库 lint/format 门禁，见 `build.md` §0）。`spike/` 2 个可执行证据脚本，`tool/` 2 个脚本（对比度校验 + 架构门禁）与它的 baseline。
- **技术栈**：Dart SDK `^3.11.5` / Flutter 3.41.9 stable；运行时 `genkit` 0.16.1 + `genkit_openai` / `genkit_anthropic` / `genkit_google_genai` / `genkit_mcp` / `genkit_middleware`（**全是 0.x**）；状态管理 `flutter_riverpod` 3.2.1 + `riverpod_annotation` 4.0.2（ADR-0002 修订 1：注解模式，`*.g.dart` 入库）；组件库 `shadcn_ui` 0.56.3（迁移中）+ 入库本地包 `board_panel`（path 依赖，ADR-0007 D5）；宿主能力 `flutter_pty` + `xterm`（终端）、`flutter_inappwebview`（浏览器 tab）、`file_picker` + `path_provider`（工作区）、`pasteboard`（剪贴板）、`tray_manager` + `window_manager` + `hotkey_manager`（托盘/窗口/全局热键）、`desktop_drop`（拖拽入 composer）、`pdfrx`（PDF 与文档抽文本）；渲染与编辑 `gpt_markdown`（含 LaTeX 与 `flutter_mermaid` 围栏图）+ `re_editor` + `re_highlight`、`archive`（本地备份 zip）、`schemantic`（工具运行时 schema）、`flutter_lucide`（图标）。lint 只有 `flutter_lints`（`riverpod_lint` 因 SDK meta 约束暂不可装，见 ADR-0002 修订 1）。
- **刻意不存在的机制**：genkit 工具输入保持 Map、schema 运行时构造（codegen 仅限 riverpod 注解，见 ADR-0002 修订 1）；没有 `intl` / `.arb` / `flutter_localizations`（i18n 自研，见 §3）；没有路由表（单窗口，界面靠 widget 组合与 scope 拼装）。

## 2. 目录导航

| 路径 | 文件 | 行 | 职责 |
| --- | --- | --- | --- |
| `lib/main.dart` | 1 | 487 | 纯装配：开 store → 恢复工作区授权 → 建 riverpod container（override stores，含 `planObjectStore`）→ 挂树（`MaterialApp.builder` 那道缝按 `MediaQuery(字号) → ShadTheme → AppLocaleScope → ShadSonner` 的顺序包）；并接 `window_manager` / `tray_service` / `hotkey_service` / `window_title_service`。**不做业务决策** |
| `lib/genkit/` | 9 | 3.7k | Genkit 唯一的家：`agent_runtime`（投影 + 系统提示 + 审批回路 + 指令注入 + 中途转向的 `_GuideInjector` + **MCP host**（`genkit_mcp`，按 settings 里的 server 才建）+ `general-purpose` **子 agent 委托**，ADR-0012/0013）、`tools`（`WorkspaceTools`：`read`/`write`/`edit`/`glob`/`grep`/`bash` 与 `decideGate` 审批门禁，并在覆盖写之前把 before 镜像交给 `CheckpointSink`，ADR-0014）、`instructions`（工作区 `AGENTS.md` 发现与合并，ADR-0009，纯 Dart）、`shell_run` / `text_edit` / `read_window` / `plan_tools`（**agent 的 `todo_write`/`plan` 工具，与企划模式无关**）/ `file_search` / `models_endpoint` |
| `lib/model/` | 37 | 8.7k | 纯 Dart 领域词汇。**对话侧**：`conversation` / `turn_event` / `turn_source` / `approval_mode` / `approval_rule`（免问规则，ADR-0012）/ `queued_input`（忙时输入与它的两种投递，ADR-0013）/ `checkpoint`（before 镜像的值、FNV 指纹与 `CheckpointSink` 接口，ADR-0014）/ `todo_state`（`todo_write` 与 `plan` 工具维护的那份列表）/ `attached_image` / `mention_expansion` + `workspace_index`（composer 的 `@` 引用：BFS 文件索引与发送时的展开，port 自 dsh-at-file）/ `window_title`（ADR-0019 ③）· `fs_revision`（纯 Dart 的监听表，ADR-0015，`lib/model` 第一个全局可变单例）。**工作台侧**：`sidebar_tab`（+ `sidebar_state` 双树）/ `split_node` / `workbench` / `workbench_prefs` / `workspace` / `user_profile`（ADR-0006 侧栏头像与快捷菜单读的身份）/ `known_models`（含 `modelAcceptsImages`，ADR-0010）/ `mcp_settings` / 各 settings。**企划侧（ADR-0037，十个 `plan_*`）**：`plan_struct`（记录是 `Struct` 的视图，不是带字段的类）/ `plan_dataview`（视图·条件·阶段·限制）/ `plan_relation` / `plan_object_type` / `plan_template` / `plan_widget` / `plan_block` / `plan_markdown_codec`（Markdown 是唯一盘上格式，md 装不下的块走一行 `<!-- plan:{json} -->` 信封）/ `plan_filter_engine`（filter/sort/group 的唯一答案处）/ `plan_all_content` / `plan_space` + `plan_mock_content`（种子）。手写 `toJson`/`fromJson`。**分组的历史（ADR-0039）**：`session_meta`（快照装不下的那四件事）、`session_groups`（分组纯函数：组内置顶优先、当前工作区在前、「未归属」垫底，`workspaceKey` 把 `/private/var` 与 `/var` 合成一个键）、`relative_time`（四档「多久以前」，答 i18n 键加参数，因为 model 不碰字典）。**没有 `plan_task.dart`** —— 它与 `plan_task_store`、`plan_extensions_view` 一起随 ADR-0037 退役（`da7ace5`） |
| `lib/state/` | 23 | 5.6k | 控制器与持久化：`app_providers`（+ 唯一入库生成件 `app_providers.g.dart`，19 个 provider：stores、read seams、per-controller provider，ADR-0002）、`app_scope`（组合根：runtime 热替换链仍在其中，并在此打开 `approval_rule_store` 与 `checkpoint_store`）、`conversation_controller`、`side_chat_controller`、`workbench_controller` / `workbench_store`（双树持久化）/ `workbench_prefs`、`layout_controller`、`workspace_mode_controller`（企划/代理 + `PlanExtensionView`，ADR-0007/0037）、**`plan_object_store`**（记录一份 map、集合持 id、订阅按集合引用计数、每次改动抬一个 revision；ADR-0037 P2）与 **`plan_block_document`**（笔记的内存块树 + 本地 undo 栈，ADR-0037 P5）、`approval_rule_store`（`<support>/approvals.json`，按工作区分键，ADR-0012）/ `checkpoint_store`（`<support>/checkpoints/` 的镜像、冲突闸门与 rewind，ADR-0014）、`model_directory`、`session_index`（把运行时列出的会话与下面那份 sidecar 组合成屏幕上的一条列表：过滤墓碑、把标题按 `override ?? derived` 解一次、置顶/改名/删除三个动作都在它身上）、`session_registry`（`<support>/sessions/sessions.json`：工作区归属、置顶、墓碑、改名 override，同步 tmp+rename，ADR-0039）、`backup_service`、`details_selection`、`tray_service`、`hotkey_service`、`window_title_service`、`document_extractor`、`settings_store` / `prefs_store`（原子写）、`streaming_tail` |
| `lib/host/` | 5 | 0.9k | 宿主能力：`git`、`terminal_manager`、`project_folder_ops`（security-scoped bookmark）、`profile_repository`（ADR-0006 S1，用户 Profile）、`reveal`（在文件管理器中显示——`lib/ui` 不许直接 `dart:io`，所以界面经 `ui/primitives/reveal.dart` 调它；文件和目录都认，只回答命令是否启动，不回答窗口是否出现） |
| `lib/ui/` | 77 | 31.2k | 界面：`workbench/`（7 + `tabs/` 9 = 16，含 `tab_registry`、`workbench_tab_bar` 右键菜单、`free_window_layer`、`workbench_prefs_scope`，`tabs/pending_tab.dart` 是尚未落地 tab 的占位，真 tab 到达就整份删）、`primitives/`（20，卡片/代码块/diff/终端/菜单/吐司/露出等自绘件——`reveal.dart` 是"在文件管理器里露出＋失败就说"唯一的一枚函数，ADR-0041）、`conversation/`（13，含 `assistant_markdown`：LaTeX + Mermaid，`input_queue_panel`：忙时队列条，`plan_review_panel`：计划待审时接管 composer 的那张卡，`details_panel`：右栏）、`layout/columns.dart`（约束求解）、**`plan/`（19）**：`plan_workspace.dart`（中列的企划脸：vault 树 + 块编辑器）+ `blocks/`（3，块视图/编辑/动作）+ `dataview/`（7，视图条·单元格·Table·List·Gallery·Board·Calendar 与配置抽屉）+ `library/`（7，All Content·对象信息·新建集合·模板·Date·Gallery·回收站）+ `widgets/`（1，主屏组件条）、`settings/`（3：全屏设置 + `widgets/` 卡片与级联快捷菜单）、`sidebar/`（1，代理档的会话列表按工作区分组：节头 + 组头 + 嵌套行 + 组菜单 + 会话右键，ADR-0039；企划档把整块会话模块换成**扩展区**：集合列表 + 库分组，ADR-0037 P8-b）、`tool/`（2：`tool_card` 与它读的 `checkpoint_scope`，卡片上那枚回退 pill 属于 ADR-0014）、根 `app_frame.dart`（五区外壳）+ `appearance_scope.dart` |
| `lib/theme/` | 7 | 1.3k | `dsw_alias`（令牌）→ `dsw_theme`（挂到 `ThemeData` + `DswShadow` elevation ramp + `tooltipTheme`/`popupMenuTheme`/`hoverColor`）→ `dsw_typography` / `dsw_shape`（半径·图标·控件尺寸档位，ADR-0017/0026）/ `dsw_motion` / `dsw_static` / `dsw_shad_bridge`（DswAlias→ShadColorScheme + input/select/switch/card 主题项） |
| `lib/l10n/` | 1 | 1.4k | `locales.dart`：en/zh 双字典（键集对齐由 `test/l10n_parity_test.dart` 守卫，ADR-0008；条数不写死）+ `AppLocaleScope` + `context.tr()`，zh 逐键回退 en |
| `spike/` | 2 | — | `agent_spike.dart`（genkit 真实形状的可执行证据，头部 FINDINGS）、`runtime_smoke.dart`（命令行驱动 runtime 的验收门：没有 Flutter、没有 UI 也能把工具环跑起来。它能编译的前提是 ADR-0015，并由 `check_architecture` 规则 6 守着） |
| `tool/` | 2 | — | `contrast_check.dart`：对 `dsw_static` + `dsw_alias` 做 WCAG 对比度三求值（dart:io/dart:math only），`dart tool/contrast_check.dart`；`check_architecture.dart`：**七条**架构规则的指纹 baseline 门禁（ADR-0011 + 规则 6 由 ADR-0015、规则 7 由 ADR-0020 补），baseline 落 `tool/architecture_baseline.json`（2026-10-01 实况：7 条全部是 `lib/ui` 直接 `dart:io`，新 clone 后跑 `dart tool/check_architecture.dart` 应得「7 recorded, 0 new」） |
| `packages/board_panel/` | — | — | **入库的本地包**（path 依赖，ADR-0007 D5 记录为 ADR-0001"vendored 不入库"的例外）：`analysis_options.yaml` 把 `packages/**` 排除在 lint/format 之外，改它要在该包目录内单独验证。ADR-0037 之后企划只吃它的 **Board（分组列拖拽）与 `MonthView`**，而日历的日期格由宿主用 `cellBuilder` 画（`dataview/plan_calendar_viewer.dart`）；Table/List/Gallery 由宿主画。数据来自 `state/plan_object_store.dart` |
| `packages/flutter-shadcn-ui/` | — | — | **vendored 源码镜像，`.gitignore` 排除**（ADR-0001）—— **2026-10-01 本机核实：这个目录已经不在磁盘上了**（`ls packages` 只有 `board_panel`），新 clone 同样没有。`shadcn_ui` 0.56.3 是 pubspec 直接依赖（ADR-0002/0036），配色仍走 `dsw_*`（经 `theme/dsw_shad_bridge.dart`）。查组件 API 用入库 skill `.qoder/skills/shadcn-ui-flutter/`；读实现与签名以磁盘上的 `~/.pub-cache/hosted/pub.dev/shadcn_ui-0.56.3/` 为准，**不要再往 `packages/` 里补一份镜像**（要补先立 ARC 类 ADR） |
| `docs/` | — | — | `README.md`（ADR 规范）+ `debt-register.md`（状态源）+ `migration-log.md` + `adr/`（模板 + ADR-0001…0038，**没有 ADR-0030 文件**）+ 审计报告与优化方案 + 企划三面（`anytype-feature-inventory-2026-10-01.md` 功能清单 / `plan-mode-anytype-dataview-migration-2026-10-01.md` 施工表 / `plan-mode-parity-table-2026-10-01.md` 实现对照表） |
| `.github/workflows/` | 2 | — | `pr-check.yml`（push/PR 到 develop·main：format + `dart analyze --fatal-infos` + `flutter test`）、`build.yml`（`workflow_dispatch`：三桌面平台出包 + 可选 GitHub Release）。两者都钉 `FLUTTER_VERSION: '3.41.9'` |

## 3. 架构不变量（违反即错误，命令可自证）

```
grep -rn "package:genkit" lib/ | grep -v "^lib/genkit/"   # 必须为空（注释文字除外）
grep -rln "package:flutter" lib/model/                    # 必须为空
grep -rn "\.\./ui/" lib/state/                            # 只有 layout_controller 一条已知例外
grep -rn "package:flutter\|\.\./state/" lib/genkit/       # 必须为空：运行时不许碰 Flutter，也不许伸进 lib/state（ADR-0015）
```

Genkit 变更只应砸 `lib/genkit/` 两个文件，而不是穿过 widget 树；`lib/model/` 是运行时与 UI 之间的唯一词汇表。唯一被放行的例外是 `test/restore_projection_test.dart`（它要构造持久化形状），别顺手清掉。完整表述与例外登记见 `.qoder/rules/workflow.md` §0。

这四行 grep 现在有一条命令代替：**`dart tool/check_architecture.dart`**（ADR-0011，规则 6 由 ADR-0015 补、规则 7 由 ADR-0020 补）。它按七条规则（三条不变量 + 运行时不碰 Flutter/state + `lib/ui` 不直接 `dart:io` + riverpod 只在装配根 + 反馈条只有一个入口）用**指纹 baseline + 只拦新增**运作，并由 `test/architecture_check_test.dart` 跟着 `flutter test` 一起在 CI 上跑。`tool/architecture_baseline.json` 是今日实况，不是豁免清单。

## 4. 环境与命令

```
flutter pub get            # 每台新机器第一步（`.dart_tool/`、`pubspec.lock`、macOS ephemeral 都不入库，clone 里没有它们）
dart format --set-exit-if-changed lib test tool spike    # 与 CI 同一口径（不是 `.`）
dart analyze --fatal-infos lib test tool spike           # 与 CI 同一口径；`flutter analyze` 可作本地快查
flutter test               # 只有 flutter test；dev 依赖没有 package:test，dart test 跑不起来
flutter test test/conversation_controller_test.dart     # 守住流式拆分这条性能契约
dart tool/contrast_check.dart            # 主题令牌 WCAG 对比度三求值（ADR-0004 的门禁）
dart tool/check_architecture.dart        # 架构门禁（ADR-0011）；--update 只在债务减少时跑
dart run spike/agent_spike.dart          # genkit 升版后必跑，核对头部 FINDINGS
dart run spike/runtime_smoke.dart        # 离线冒烟（无 key 走 no-key 路径）；带 DEEPSEEK_API_KEY 真跑工具环与审批
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
| 「加工具 / 改审批 / 排队与转向 / 回退一次写入 / 加 tab / 改文案 / 改主题令牌」 | 走 `.qoder/rules/workflow.md` §3 的固定链路（工具、审批门禁只有一个顺序、忙时输入只有一个出口、文件写入只有一个回退闸门、tab、双树面板、工作区模式、文案、主题、持久化） |
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
- **正当组件库**（ADR-0002 实施中）：`shadcn-ui-flutter` 是已引入的 `shadcn_ui` 0.56.3 的组件参考；配色仍走 `lib/theme/dsw_*`（见 `theme/dsw_shad_bridge.dart`），不要读 shad 的调色板来配色。新交互控件优先用 shad 组件或 `primitives/tappable.dart` 的 `DswHoverTap`（都自带键盘/语义），不要再手写 `MouseRegion + GestureDetector`——最后 5 枚纯鼠标件已在 ADR-0021 里收回，`test/tap_affordance_test.dart` 按文件计数拦新写的。同一枚 chrome 的**时序**也只有一个真值：提示气泡的出场延迟住在 `DswMotion.tooltipDelay`、经 `tooltipTheme` 生效，`lib/ui` 里出现 `waitDuration` 即红（ADR-0023，守卫 `test/tooltip_timing_test.dart`）。
- **已移除 7 个**（与自研 i18n / 无路由表 / 不用代码生成器 / 三桌面目标不含移动·web 直接冲突）：`flutter-setup-localization`、`flutter-setup-declarative-routing`、`dart-generate-test-mocks`、`dart-use-ffigen`、`dart-setup-ffi-assets`、`dart-migrate-to-checks-package`、`flutter-add-integration-test`。逐条理由与"要用回来必须先满足的前提"在 workflow.md §2；不要偷偷重装。

## 7. 硬性红线

- 永不修改 git config（`--no-verify` 同理）；永不 `force push` / `hard reset`；钩子失败后新建 commit，绝不 amend 已存在的提交。
- 永不提交密钥：API key、证书、描述文件、`.env`。当前 `.gitignore` 里**没有** `*.p12` / `*.cer` / `*.mobileprovision`，要引入证书前先补忽略规则（`build.md` §4）。
- 不新增依赖、不加抽象、不引入代码生成器（`build_runner` 等），除非任务明确要求且已立 ADR。
- 动 `macos/Runner/Release.entitlements` / `DebugProfile.entitlements`（尤其那个"故意没开的 App Sandbox"）= 动产品能力边界，先有 ACCEPTED 的 ADR。
- 未在某个桌面平台真机跑过，不得声称该平台构建/出包/走查成功（交付说明标"待 <平台> 验证"）。
- 加载 skill ≠ 停止思考：skill 给规范步骤，仍按任务范围最小实现（ponytail）。

## 8. 现状缺口（以登记表为准）

已知缺口的分类、优先级、状态一律看 [docs/debt-register.md](docs/debt-register.md)：`README.md` 与 `CHANGELOG.md` 仍是包模板、macOS 签名/公证缺口与 `.gitignore` 缺证书规则、版本仍 `0.0.1`。（`spike/runtime_smoke.dart` 那道"真实链路"门曾不可运行，已由 ADR-0015 修好并加进门禁；ADR-0012/0013/0014 的收尾现在只等一把 API key。）（i18n 双语对齐的守卫缺口已由 ADR-0008 闭环。）ADR-0005 遗留的那几项"仅持久化未接线"的偏好**不再是缺口而是已处置**：普查发现四条设置行没有任何读取点（`previewMode`/正文字体族/界面皮肤/提示建议），已由 ADR-0022 连行带字段撤下，并立 `test/settings_reach_test.dart` 拦第五枚——要接回任何一条请先按 §7 立 ADR。**修任何一个之前先按 `docs/README.md` 立 ADR 并置 ACCEPTED。**

**测试基线（本机 macOS，2026-10-02 现场跑）不是绝对全绿**：`flutter test` 得 **`+1218 -2`**（跑法排除 `test/probe_*_test.dart` 那几棵未入库的一次性探针——它们各自 10 分钟超时，会把数字变成 `-5`），两个既有失败是 `test/app_scope_test.dart` 的 `a workspace-only save re-points the live runtime, no rebuild`（macOS temp 路径 `/var`↔`/private/var` 规范化）与 `test/plan_workspace_test.dart` 的 `lists only the markdown files, folder as the second line`（`find.text('notes')` 命中两处），都已登记在债务表的待立 ADR 观察里。验收口径因此是**相对基线零新增失败**，不是"全绿"；通过条数会随加测试漂移（2026-09-30 是 `+946 -2`），别把它当常数，也不要为了让套件变绿去改那两条断言。

**CI 已经有了**（`.github/workflows/`，commit `d09b92d`）：`pr-check.yml` 在 push/PR 到 `develop`·`main` 上跑 format + `dart analyze --fatal-infos` + `flutter test`；`build.yml` 是 `workflow_dispatch` 手动三平台出包并可选发 GitHub Release。**但它只保证门禁命令，不等于签名/公证已过**——CI 产物依旧 ad-hoc，见 `build.md` §4/§5。

三条容易被误当成"应该在那儿"或"还不存在"的事实：

1. 没有 `.mcp.json` —— **仓库**自己不配任何 MCP 服务器。这与应用有没有 MCP 能力是两件事：用户在设置页配的 server 走 `model/mcp_settings.dart`（随 `AppSettings` 落应用支持目录），由 `genkit/agent_runtime.dart` 建 `genkit_mcp` host，工具名形如 `mcp/<name>:tool/<tool>`。别把这两件事混为一谈，也别在仓库根造一个 `.mcp.json` 来"接上"。
2. 主干工作分支是 `develop`（ADR-0002 的改造面），`main` 可能落后；动手前 `git rev-parse --abbrev-ref HEAD` 现场确认，别信任何文档里写死的分支。
3. 根目录 `_archive_project/`（约 88 MB 的第三方参考源码归档）**已在 `.gitignore` 里**（2026-09-29 补），新 clone 不会有它，也别想办法把它加回来。

`.qoder/` 与 `.trae/` 里的规则与 skill 集合是 2026-09-15 才按本仓库事实重建的（此前内容整份属于另一个项目），2026-09-29 按 ADR-0004…0007、CI、双树工作台与新宿主能力做过一轮校准，2026-10-01 又按 ADR-0036…0038（shad 采纳、企划的 Anytype 数据视图内核、聚焦不改变描边）与本文件的 §2 数字做过一轮。今后再发现规则与代码不符，先改规则、再改代码，别将错就错。
