# 项目工作流规则（workflow）

本项目 `agent_harness`：用 Flutter + Genkit 从零实现的 **macOS 桌面端 AI Agent 工作台**（chat UI + tool-call 投影 + 分栏 workbench），设计思想分别取自 dsh（Runtime 内核）与 better-sidebar（工作台交互），不 fork 二者代码。

所有编码任务遵循 `.trae/rules/ponytail.md` 的懒惰阶梯：先问是否需要构建、是否已有现成实现，再写最少的代码。以下规则在此基础上补充本仓库的实操约定。凡是命中下方关键词，直接加载对应 skill / 工具执行，不再向用户确认。

## 0. 三条硬不变量（动手前先确认没踩）

| 不变量 | 为什么 | 验证命令（应无输出，注释文字除外） |
| --- | --- | --- |
| Genkit 只活在 `lib/genkit/` | genkit 全系是 0.x 包，破坏性变更应当只砸两个文件，而不是穿过整棵 widget 树 | `grep -rn "package:genkit" lib/ \| grep -v "^lib/genkit/"` |
| 状态模型不碰框架 | `lib/model/` 是运行时与 UI 之间的唯一词汇表 | `grep -rln "package:flutter" lib/model/` |
| 控制器不反向依赖界面 | `lib/state/` 原则上不 import `lib/ui/` | `grep -rn "\.\./ui/" lib/state/` |

第三条的**唯一已知例外**：`lib/state/layout_controller.dart:13` import `ui/layout/columns.dart`（列宽求解要读约束表达式）。要新增例外，先按 §7 立 ADR。

第一条还有一个人工放行例外：`test/restore_projection_test.dart` 是全仓库唯一在 `lib/genkit/` 之外 import `package:genkit` 的测试文件（它要构造持久化形状）。这个例外是刻意的，别"顺手清理"掉。

## 1. 关键词自动路由（命中即用）

| 用户说的话（举例） | 自动动作 |
| --- | --- |
| 「基于这部分代码理解代码」「梳理整个仓库」「看下整体结构」「这句话/模块在哪个文件」 | 局部需求直接读相关文件；全仓库需求跑 `repomix` 刷新 `repomix-output.xml` 后作答。引用证据一律用「文件路径:行号」 |
| 「提交代码」「commit 一下」「提交这个改动」 | 走 `git-commit` skill：分析 diff → 定 type/scope → Conventional Commits 消息 → 逐逻辑变更提交（见 §5） |
| 「这个 API 怎么用」「genkit 新版有什么变化」「XX 包最新写法」 | 按 §6：以磁盘上 pub-cache 里的包源码为准，配合 `spike/agent_spike.dart` 的 FINDINGS 回答 |
| 「genkit 升版」「把 genkit 从 0.16.1 升到 X」 | 按 §3 第一条：先重跑 spike，核对 FINDINGS，再改 `lib/genkit/` |
| 「加一个 agent 工具」「给工具改 schema」「工具审批怎么串」 | 按 §3 第二条（`lib/genkit/tools.dart` → `lib/model/` → `agent_runtime.dart` → `lib/ui/tool/tool_card.dart`） |
| 「加一种工作台 tab」「新面板怎么挂进 tab 条」 | 按 §3 第三条（`TabType` → `tabs/xxx_tab.dart` → `workbench.dart` 里 `registerTab`） |
| 「加个文案」「这句中文怎么改」「也要英文」 | 按 §3 第四条：`lib/l10n/locales.dart` 双字典同键增改。仓库里**没有**也**不该有** `flutter-setup-localization`（见 §2） |
| 「改颜色」「间距/阴影/动效令牌」 | 按 §3 第五条：只在 `lib/theme/dsw_*` 上加令牌 |
| 「RenderFlex overflowed」「布局溢出」「窗口拉小被挤爆」 | `flutter-fix-layout-issues` |
| 「支持不同窗口宽度自适应」「侧栏收起怎么算」 | `flutter-build-responsive-layout`（本仓库的约束求解在 `ui/layout/columns.dart`，先看它） |
| 「加个 widget 测试」「给这个按钮写测试」 | `flutter-add-widget-test`，遵守 §4 的仓库约定 |
| 「写单元测试」「补个单测」 | `dart-add-unit-test`；替身**手写** `test/fake_*.dart`（mockito 那套生成路径已随 `dart-generate-test-mocks` 一并移除，见 §2） |
| 「跑静态分析」「dart analyze」「修下 lint」 | `dart-run-static-analysis`（`analysis_options.yaml` 只 include `flutter_lints`，勿私自加规则集） |
| 「JSON 序列化」「写 fromJson/toJson」「存盘格式」 | `flutter-implement-json-serialization`（本仓库正是手写 `toJson`/`fromJson` + `dart:convert` 路线，见 §3 末条） |
| 「构建失败」「编译不过」「flutter build macos」「出包」 | 按 `.trae/rules/build.md` 排查：版本基线 → 校验命令 → entitlements → 签名 → 产物 |
| 「发版」「签名」「公证/notarize」 | 按 `build.md` §5 出包清单逐项过；签名与公证的现状缺口见 `build.md` §4 |
| 「记录技术债」「登记缺陷」「新建/补充 ADR」 | 按 `docs/adr/ADR-0000-template.md` 在 `docs/adr/` 新建下一编号 ADR（文件名 `ADR-NNNN-<分类小写>-<slug>.md`），并在 `docs/debt-register.md` 追加一行；分类/优先级/状态规范见 `docs/README.md` |
| 「查看技术债」「债务清单」「已知问题」「还有什么没修」 | 读 `docs/debt-register.md` 总览，按链接下钻单个 ADR；修复已登记问题前必须先读对应 ADR 并确认状态为 ACCEPTED |

## 2. skill 集合的边界（已按本仓库裁剪）

两份镜像 `.qoder/skills/` 与 `.trae/skills/` 各 **25 个** skill，逐文件一致。曾装过 32 个，以下 **7 个因为"命中即破坏现状"已经移除**（不是禁用，是磁盘上没有了；要恢复必须先满足最后一列前提）：

| 已移除 | 为什么在本仓库有害 | 要用回来的前提 |
| --- | --- | --- |
| `flutter-setup-localization` | 本仓库有自研 i18n（`lib/l10n/locales.dart`）。按它引入 `flutter_localizations` + `intl` + `.arb` + 生成代码，会顶掉双字典与 `context.tr()`，并让 widget 测试失去"无 scope 即英文"的确定性 | 先立 ARC 类 ADR 论证替换自研方案 |
| `flutter-setup-declarative-routing` | 没有命名路由表，也没有页面级 `Navigator.push` / `GoRouter` / `onGenerateRoute`：单窗口桌面壳，界面由 widget 组合与 scope 拼装（见 `lib/main.dart`）。现存仅有的 `Navigator` 用法是 4 处 `Navigator.pop(context, bool)`（`tabs/editor_tab.dart:274,278`、`tabs/git_tab.dart:410,414`），用途是对话框返回结果，不是要"迁移"的导航层 | 出现真正的多窗口/深链需求 |
| `dart-generate-test-mocks` | mockito 的生成路线与测试替身约定冲突：本仓库替身一律手写 `test/fake_*.dart`。codegen 在本仓库仅限 riverpod 注解（ADR-0002 修订 1），mockito 不在放行范围 | 同时立 ADR 接受 mockito 测试路线 |
| `dart-use-ffigen` / `dart-setup-ffi-assets` | 无 C/C++ 资产；宿主能力（PTY、剪贴板、文件系统）全部走已装插件 | 真要接自研原生库 |
| `dart-migrate-to-checks-package` | dev 依赖只有 `flutter_test`，没有 `test`/`checks`；"迁移"等于加依赖 | 同时接受引入 `checks` |
| `flutter-add-integration-test` | 未配置 `integration_test`，也没有 golden 基线；集成测试要真机/模拟器驱动 + 稳定截图，属独立工程投入（本机已能跑 Windows 桌面，但仍未接这套） | 决定投入集成测试 + 立 ADR |

**组件库现状（ADR-0002 实施中）**：`shadcn_ui` 0.56.3 已是 `pubspec.yaml` 的直接依赖，`lib/main.dart` 经 `theme/dsw_shad_bridge.dart` 挂载 `ShadTheme`（colour 仍全部来自 `DswAlias`），`capsule_button` 与块原语（`primitives/tappable.dart` 的 `DswHoverTap`）已用上 shad 的按钮/焦点/语义机制。`shadcn-ui-flutter` skill 从"守卫项"转为**正当的组件参考**。不变的约束：颜色/字号只从 `lib/theme/dsw_*` 取，不要 `import 'package:shadcn_ui/...'` 去读它的调色板配色——组件用 shad、配色用 dsw。`packages/flutter-shadcn-ui/` 仍是 gitignore 的本地源码镜像（ADR-0001）。

## 3. 本仓库特有工作流（skill 覆盖不到的部分）

**genkit 升版。** 投影逻辑的依据全写在 `spike/agent_spike.dart` 头部的 FINDINGS（可执行证据）。升完依赖先 `dart run spike/agent_spike.dart` 重跑，再对照这三条：`Part` 是单一 json-backed 类型（`part is TextPart` 永不成立，要用 `PartExtension` 的 `isText`/`isToolRequest`/… 判别）；`SchemanticType.jsonSchema(...)` 不存在，运行时 schema 用 `SchemanticType.from<T>(jsonSchema: ..., parse: ...)`；`chunk.accumulatedText` 是 **turn-global**，不能当单条消息正文，要按 `chunk.raw.modelChunk.index` 分组。若升版使 FINDINGS 失效，先补 ADR 记录新事实，再改 `lib/genkit/`。

**加/改一个 agent 工具。** 顺序是：`lib/genkit/tools.dart`（`WorkspaceTools` 只注册一次，工具在调用时读 workspace，换文件夹不重注册）→ 需要新事件形状时在 `lib/model/turn_event.dart` / `conversation.dart` 里表达 → `lib/genkit/agent_runtime.dart` 做投影 → UI 侧 `lib/ui/tool/tool_card.dart`。会写文件/执行命令的工具要走 `lib/model/approval_mode.dart` 的审批回路（interrupt → resume）。工具的 description 与返回给模型的 error 文本**不进 i18n**：那是模型读的，不是 UI 文案。验收：`dart run spike/runtime_smoke.dart`（离线跑 no-key / 空 store 路径；带 `DEEPSEEK_API_KEY` 则真跑一轮流式 + 工具环 + 审批 + 恢复）。

**加一个工作台 tab。** 三步：`lib/model/sidebar_tab.dart` 的 `TabType` → 新建 `lib/ui/workbench/tabs/xxx_tab.dart` → 在 `lib/ui/workbench/workbench.dart` 里 `registerTab(TabDescriptor(...))`。registry 按 `TabType` 字符串为键；`tab_registry.dart` 头部写明了为什么只保留 4 个字段（源项目 `TabDescriptor` 的 `single`/`available`/`badge`/`urlTarget` 等在别处已有答案或无消费者），别回去补那十二个字段。

**文案。** 新增或修改 UI 字符串必须**同时**进 `lib/l10n/locales.dart` 的 `enStrings` 与 `zhStrings`，键完全一致（**不记死条数**——它随加键漂移，是典型的会腐烂的断言；对齐才是不变量）。en 是先写的源语言，zh 逐键回退到 en（`translate()`：`zhStrings[key] ?? enStrings[key] ?? key`），两边都缺则把键本身渲染出来，好让缺口可见。取值走 `context.tr(key, params)`，`{name}` 占位符插值。**注意**：`locales.dart` 头部注释声称"en 在测试期对照校验"，但仓库里目前**没有任何测试引用这两个字典**——双语对齐只能靠手动核对，这是已存在的缺口，别假设它会被 `flutter test` 拦下（要补就按 §7 立 TST 类 ADR）。**不挂 `AppLocaleScope` 即退化成英文**，这是 widget 测试不关心 i18n 的前提，别改这个 fallback。不做 i18n 的两类内容：持久化进 layout 的 tab 标题（数据不能随语言翻），以及单例 tab 的显示名（在渲染时由类型派生）。

**主题。** 颜色/字号/动效/阴影只从 `lib/theme/dsw_*` 取：别名令牌在 `dsw_alias.dart`，绑定与 elevation ramp 在 `dsw_theme.dart`，排版在 `dsw_typography.dart`。新增令牌加在 alias 层，让 widget 通过 `context` 拿。抄 dsh 的 CSS 阴影值必须换算——CSS blur 与 `BoxShadow.blurRadius` 不是一回事（见 `DswShadow._blur`）。

**持久化。** 手写 `toJson`/`fromJson` + `dart:convert`（`lib/model/` 里那批 settings/state 模型即范例）。写盘沿用 `lib/state/settings_store.dart`、`prefs_store.dart` 的 tmp + rename 原子写。工作区访问靠 security-scoped bookmark，恢复必须发生在任何读文件之前（`main()` 里的 `restoreWorkspaceAccess`）。

## 4. 测试约定

- 一律 `flutter test`。dev 依赖只有 `flutter_test`，`dart test` 跑不起来（39 个 `*_test.dart` 全部 import `package:flutter_test`，包括纯逻辑的 `test/file_search_test.dart`；`test/` 下另外 4 个文件是辅助替身/探针，不是测试）。
- 替身手写，命名 `test/fake_*.dart`（现成三个：`fake_turn_source.dart`、`fake_git.dart`、`fake_terminal_process.dart`；`clipboard_probe.dart` 是探针不是测试）。文件系统类测试走真实临时目录，因为要验的是 mtime 排序、跳过 VCS 元数据、二进制早退这类**文件系统事实**，fake 证不出来。
- 每个测试文件头部用注释写清"本文件要守住的那句话"以及它存在的理由（参考 `test/conversation_controller_test.dart`、`test/file_search_test.dart`）。
- widget 测试不挂 `AppLocaleScope`，直接断言英文文案。
- 流式拆分是本项目唯一的性能契约：token delta 只能通知 tail 的 notifier，不得通知 conversation controller（由 `flutter test test/conversation_controller_test.dart` 守着）。

## 5. Git 提交（强制）

- 新建 commit 一律用 `git-commit` skill 生成 Conventional Commits 消息：`<type>[scope]: <description>`。
- type 取：feat / fix / refactor / perf / test / docs / build / chore / revert。
- scope 用本仓库的顶层归属名：`genkit`、`model`、`state`、`ui`、`theme`、`l10n`、`host`、`workbench`、`macos`、`deps`；仓库级配置（`.qoder/`、`.trae/`、`AGENTS.md`、`.gitignore`、`repomix.config.json`）用 `config`；ADR 与登记表用 `adr` 或 `docs`。
- description 用**英文**现在时祈使句，≤72 字符（与既有历史一致：`C4: the tab strip's right-click menu`）。里程碑式改动可保留早期那种阶段编号前缀，但仍要带 type。
- 破坏性变更用 `feat!:` 或 `BREAKING CHANGE:` footer。
- 安全红线（skill 内已申明，此处重申）：永不改 git config、永不 force push / hard reset、永不用 `--no-verify`；钩子失败后修复并**新建** commit，绝不 amend 已存在的提交；一次提交只含一个逻辑变更，按文件/模式分组 add。
- 不提交：`repomix-output.*`、`dart_sources.md`、`.workbuddy/`、`pubspec.lock`（库型包约定，已在 `.gitignore`）、以及任何 API key。

## 6. 文档 / API 时效性

- genkit-dart 及伴生包是 0.x，**以包源码为准**，不要信记忆里的写法。实际解析版本用 `flutter pub deps` 现场核对；要读实现就去 pub cache 下的对应目录（默认 `~/.pub-cache/hosted/<mirror>/<pkg>-<version>/`，`PUB_CACHE` 环境变量可覆盖）。两篇技术文档记录的审读基线是 genkit 0.16.1 + `genkit_openai` 0.4.1 / `genkit_anthropic` 0.3.1 / `genkit_mcp` 0.3.1 / `genkit_middleware` 0.6.1。注意 `pubspec.lock` 不入库，锁文件里的版本对别人不是事实，命令输出才是。
- 根目录两篇长文是现成的评估证据，回答"还能借哪些能力 / 该放弃哪些幻想"前先查它们：`技术文档-agent_harness基于genkit-dart的可落地增强路线.md`、`对标技术文章-agent_harness与dsh生态横向对比.md`。
- context7 之类的文档 MCP 可作辅助，但本仓库**尚未**配置 `.mcp.json`；没有它就不要声称查过最新文档。
- 需要把整仓库交给 AI 理解时跑 `repomix`（配置 `repomix.config.json`，产物 `repomix-output.xml` 不入库）。它已经把 `packages/flutter-shadcn-ui` 的实现源码排除了；而按 ADR-0001，该目录本身也被 `.gitignore` 排除，**新 clone 不会有它**——要读该库实现，先从上游 `nank1ro/flutter-shadcn-ui` 取 `0.56.3`，否则只读入库的 `.qoder/skills/shadcn-ui-flutter/` 组件文档。

## 7. 技术债与缺陷记录（ADR）

- 审计发现的缺陷、技术债、架构决策一律落盘 `docs/adr/ADR-NNNN-<分类小写>-<slug>.md`（模板 `docs/adr/ADR-0000-template.md`），并在 `docs/debt-register.md` 追加一行；规范见 `docs/README.md`。登记表是唯一状态源：新增观察写进它的"待立 ADR"表，闭环后回填状态与 commit hash，不要另开一份清单。
- 分类：SEC 安全 / CFG 配置漂移 / DEF 缺陷 / ARC 架构 / DEP 依赖 / DEBT 技术债 / TST 测试。优先级 P0（安全红线或评估阻断）> P1（影响真实使用）> P2（债务与优化）。
- 状态机：`PROPOSED → ACCEPTED → IN-PROGRESS → RESOLVED`（分支 DEFERRED / SUPERSEDED 须注明原因）。
- 纪律：动手修复已登记问题前，对应 ADR 必须先置 ACCEPTED；修复合入后置 RESOLVED 并回填 commit hash；新审计发现先补 ADR 再改代码；「背景」必须带证据（`文件:行号`、grep/构建/测试输出），禁止无证据登记。
- 本项目特别需要立 ADR 的三类动作：踩 §0 不变量的、动 `macos/Runner/Release.entitlements` 的、引入新依赖或代码生成器的。
