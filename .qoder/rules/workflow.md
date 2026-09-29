# 项目工作流规则（workflow）

本项目 `agent_harness`：用 Flutter + Genkit 从零实现的**桌面端 AI Agent 工作台**（chat UI + tool-call 投影 + 分栏 workbench；macOS/Windows/Linux 三桌面目标，见 ADR-0003），设计思想分别取自 dsh（Runtime 内核）与 better-sidebar（工作台交互），不 fork 二者代码。

顶层形态是**两种工作区模式**（ADR-0007）：**企划**（当前工作区内 .md 的本地工作台 + 看板/日程/表格扩展面板）与**代理**（对话 + 工具环 + 双树工作台）。

所有编码任务遵循 `.qoder/rules/ponytail.md` 的懒惰阶梯：先问是否需要构建、是否已有现成实现，再写最少的代码。以下规则在此基础上补充本仓库的实操约定。凡是命中下方关键词，直接加载对应 skill / 工具执行，不再向用户确认。

## 0. 三条硬不变量（动手前先确认没踩）

| 不变量 | 为什么 | 验证命令（应无输出，注释文字除外） |
| --- | --- | --- |
| Genkit 只活在 `lib/genkit/` | genkit 全系是 0.x 包，破坏性变更应当只砸两个文件，而不是穿过整棵 widget 树 | `grep -rn "package:genkit" lib/ \| grep -v "^lib/genkit/"` |
| 状态模型不碰框架 | `lib/model/` 是运行时与 UI 之间的唯一词汇表 | `grep -rln "package:flutter" lib/model/` |
| 控制器不反向依赖界面 | `lib/state/` 原则上不 import `lib/ui/` | `grep -rn "\.\./ui/" lib/state/` |

第四条边界（ADR-0015，不算"硬不变量"但同样由门禁拦）：`lib/genkit/` 不 import `package:flutter*`、也不 import `lib/state/`——`grep -rn "package:flutter\|\.\./state/" lib/genkit/` 必须为空。它保证的是 `dart run spike/runtime_smoke.dart` 还能编译：那条链曾经经 `state/fs_revision.dart`（一个 `ValueNotifier`）摸到 `dart:ui`，把工具改动的验收门静默弄断了。需要跨层共享的东西若是给 runtime 用的，就放 `lib/model/` 并保持纯 Dart。

第三条的**唯一已知例外**：`lib/state/layout_controller.dart:13` import `ui/layout/columns.dart`（列宽求解要读约束表达式）。要新增例外，先按 §7 立 ADR。

第一条还有一个人工放行例外：`test/restore_projection_test.dart` 是全仓库唯一在 `lib/genkit/` 之外 import `package:genkit` 的测试文件（它要构造持久化形状）。这个例外是刻意的，别"顺手清理"掉。

这三条 grep 现在是**可执行门禁**（ADR-0011，第 6 条规则由 ADR-0015 补）：`dart tool/check_architecture.dart` 六条规则（三条不变量 + `lib/genkit/` 既不 import `package:flutter` 也不 import `lib/state/` + `lib/ui` 不直接 `dart:io` + riverpod 只在 `main.dart`/`app_providers.dart`）按**指纹 baseline + 只拦新增**运作，`tool/architecture_baseline.json` 是今日实况而非豁免清单——债务修掉了要 `--update` 把 baseline 缩小。`test/architecture_check_test.dart` 调同一段代码，所以 `flutter test`（= CI）已经在跑它，**不必往 `.github/workflows/` 里加步骤**。

## 1. 关键词自动路由（命中即用）

| 用户说的话（举例） | 自动动作 |
| --- | --- |
| 「基于这部分代码理解代码」「梳理整个仓库」「看下整体结构」「这句话/模块在哪个文件」 | 局部需求直接读相关文件；全仓库需求跑 `repomix` 刷新 `repomix-output.xml` 后作答。引用证据一律用「文件路径:行号」 |
| 「提交代码」「commit 一下」「提交这个改动」 | 走 `git-commit` skill：分析 diff → 定 type/scope → Conventional Commits 消息 → 逐逻辑变更提交（见 §5） |
| 「这个 API 怎么用」「genkit 新版有什么变化」「XX 包最新写法」 | 按 §6：以磁盘上 pub-cache 里的包源码为准，配合 `spike/agent_spike.dart` 的 FINDINGS 回答 |
| 「genkit 升版」「把 genkit 从 0.16.1 升到 X」 | 按 §3 第一条：先重跑 spike，核对 FINDINGS，再改 `lib/genkit/` |
| 「加一个 agent 工具」「给工具改 schema」「工具审批怎么串」「免问/总是允许怎么加」 | 按 §3「加/改一个 agent 工具」（`lib/genkit/tools.dart` → `lib/model/` → `agent_runtime.dart` → `lib/ui/tool/tool_card.dart`）；**审批判定只有一个函数**（§3「审批门禁只有一个顺序」的 `decideGate`）——新工具要过门就问它，别自己写 `shouldInterrupt` |
| 「加一种工作台 tab」「新面板怎么挂进 tab 条」 | 按 §3「加一个工作台 tab」（`BuiltinTabType` 字符串常量 → `tabs/xxx_tab.dart` → `workbench.dart` 里 `registerTab`），并确认它落在哪个面板（§3「双树工作台」） |
| 「切换企划/代理」「工作区模式」「企划笔记/看板/日程/表格」 | 按 §3「工作区模式（企划/代理）与企划扩展面板」（ADR-0007 链路：`state/workspace_mode_controller.dart` → `app_providers.dart` 的 `workspaceModeProvider` → `ui/plan/`，数据走 `plan_task_store.dart`，面板用入库本地包 `packages/board_panel`） |
| 「设置页怎么加一节」「快捷菜单」「用户 Profile」 | 全屏设置 = `ui/settings/model_settings.dart`，级联快捷菜单 = `ui/settings/widgets/settings_quick_menu.dart`（ADR-0006）；偏好字段先进 `lib/model/*_settings.dart` + `AppSettings`，再在快捷菜单与设置页两处同时接，否则两处真值分叉 |
| 「跑起来时用户又打了字」「中途转向」「排队发送」 | 按 §3「忙时输入只有一个出口」（`lib/model/queued_input.dart` → `conversation_controller` 的 FIFO 与 `_drain` → `agent_runtime` 的 `_GuideInjector` → `ui/conversation/input_queue_panel.dart`） |
| 「回退 agent 改过的文件」「这次写入能撤销吗」「rewind / checkpoint」 | 按 §3「文件写入只有一个回退闸门」（`lib/model/checkpoint.dart` 的 `CheckpointSink` → `state/checkpoint_store.dart` 实现 → `genkit/tools.dart` 两处截获 → `ui/tool/tool_card.dart` 的 pill）；**只有 `write`/`edit` 在射程内**，`bash`/MCP 的改动没有镜像 |
| 「公式/Mermaid 图渲染不出来」「回复没有层级」 | `ui/conversation/assistant_markdown.dart`（`useDollarSignsForLatex` + mermaid 围栏），回归用例在 `test/markdown_rendering_test.dart`。**层级不只是字号**：`gpt_markdown` 里块与块之间只有渲染器那一条空白行（16px 正文下量得 18.4px），标题的呼吸全靠 `HeadingStyle.padding`（现在是 24/16），守卫断言的是**差值**而不是绝对像素——想靠改 h* 字号做层级是改错了地方 |
| 「拖文件进对话」「PDF/文档抽文本」 | `ui/conversation/composer.dart` 的 `_attachImages`（选择器/粘贴/拖拽三条入口共用同一道门）+ `ui/conversation/conversation_root.dart`（`desktop_drop`）+ `state/document_extractor.dart`（`pdfrx`）。**图片按模型能力门控**（ADR-0010）：真值在 `model/known_models.dart` 的 `modelAcceptsImages`，经 `state/model_directory.dart` 的 `acceptsImages` 读；文档不走这条路（本地抽成文字），没有能力位 |
| 「全局热键」「系统托盘」 | `state/hotkey_service.dart` / `state/tray_service.dart`（都在首帧后由 `main.dart` 接线，因为要等 `window_manager` 拿到窗口句柄）。修饰键按平台取：macOS 用 `meta`、其他用 `control`；两级别混——`Cmd/Ctrl+Shift+H` 是 **system-scope**（应用后台也生效，用来切窗口显示/隐藏），`Cmd/Ctrl+N` 新会话与 `Cmd/Ctrl+,` 打开设置是 **in-app** |
| 「本地备份/恢复」 | `state/backup_service.dart`（`archive` 打 zip：settings/prefs/tasks/layouts/sessions/skills/checkpoints），入口在设置页 Backup 节 |
| 「加个文案」「这句中文怎么改」「也要英文」 | 按 §3「文案」：`lib/l10n/locales.dart` 双字典同键增改。仓库里**没有**也**不该有** `flutter-setup-localization`（见 §2） |
| 「改颜色」「间距/阴影/动效令牌」 | 按 §3「主题」：只在 `lib/theme/dsw_*` 上加令牌；改对比度相关色值后跑 `dart tool/contrast_check.dart` + `test/theme_contrast_test.dart`（ADR-0004） |
| 「RenderFlex overflowed」「布局溢出」「窗口拉小被挤爆」 | `flutter-fix-layout-issues` |
| 「支持不同窗口宽度自适应」「侧栏收起怎么算」 | `flutter-build-responsive-layout`（本仓库的约束求解在 `ui/layout/columns.dart`，先看它） |
| 「加个 widget 测试」「给这个按钮写测试」 | `flutter-add-widget-test`，遵守 §4 的仓库约定 |
| 「写单元测试」「补个单测」 | `dart-add-unit-test`；替身**手写** `test/fake_*.dart`（mockito 那套生成路径已随 `dart-generate-test-mocks` 一并移除，见 §2） |
| 「跑静态分析」「dart analyze」「修下 lint」 | `dart-run-static-analysis`（`analysis_options.yaml` 只 include `flutter_lints`，勿私自加规则集） |
| 「JSON 序列化」「写 fromJson/toJson」「存盘格式」 | `flutter-implement-json-serialization`（本仓库正是手写 `toJson`/`fromJson` + `dart:convert` 路线，见 §3 末条） |
| 「构建失败」「编译不过」「flutter build macos」「出包」 | 按 `.qoder/rules/build.md` 排查：版本基线 → 校验命令 → entitlements → 签名 → 产物 |
| 「发版」「签名」「公证/notarize」 | 按 `build.md` §5 出包清单逐项过；签名与公证的现状缺口见 `build.md` §4 |
| 「记录技术债」「登记缺陷」「新建/补充 ADR」 | 按 `docs/adr/ADR-0000-template.md` 在 `docs/adr/` 新建下一编号 ADR（文件名 `ADR-NNNN-<分类小写>-<slug>.md`），并在 `docs/debt-register.md` 追加一行；分类/优先级/状态规范见 `docs/README.md` |
| 「查看技术债」「债务清单」「已知问题」「还有什么没修」 | 读 `docs/debt-register.md` 总览，按链接下钻单个 ADR；修复已登记问题前必须先读对应 ADR 并确认状态为 ACCEPTED |

## 2. skill 集合的边界（已按本仓库裁剪）

两份镜像 `.qoder/skills/` 与 `.trae/skills/` 各 **25 个** skill，逐文件一致。曾装过 32 个，以下 **7 个因为"命中即破坏现状"已经移除**（不是禁用，是磁盘上没有了；要恢复必须先满足最后一列前提）：

| 已移除 | 为什么在本仓库有害 | 要用回来的前提 |
| --- | --- | --- |
| `flutter-setup-localization` | 本仓库有自研 i18n（`lib/l10n/locales.dart`）。按它引入 `flutter_localizations` + `intl` + `.arb` + 生成代码，会顶掉双字典与 `context.tr()`，并让 widget 测试失去"无 scope 即英文"的确定性 | 先立 ARC 类 ADR 论证替换自研方案 |
| `flutter-setup-declarative-routing` | 没有命名路由表，也没有页面级 `Navigator.push` / `GoRouter` / `onGenerateRoute`：单窗口桌面壳，界面由 widget 组合与 scope 拼装（见 `lib/main.dart`），全屏设置也是视图态切换而非路由（ADR-0006 明确"改为全屏视图但**仍不引入 Navigator 路由**"）。现存仅有的 `Navigator` 用法是 5 处 **pop 返回结果**：`primitives/confirm_dialog.dart:41,45` 与 `ui/plan/plan_workspace.dart`（3 处 `Navigator.of(context).pop(...)`），用途是对话框返回值，不是要"迁移"的导航层 | 出现真正的多窗口/深链需求 |
| `dart-generate-test-mocks` | mockito 的生成路线与测试替身约定冲突：本仓库替身一律手写 `test/fake_*.dart`。codegen 在本仓库仅限 riverpod 注解（ADR-0002 修订 1），mockito 不在放行范围 | 同时立 ADR 接受 mockito 测试路线 |
| `dart-use-ffigen` / `dart-setup-ffi-assets` | 无 C/C++ 资产；宿主能力（PTY、剪贴板、文件系统）全部走已装插件 | 真要接自研原生库 |
| `dart-migrate-to-checks-package` | dev 依赖只有 `flutter_test`，没有 `test`/`checks`；"迁移"等于加依赖 | 同时接受引入 `checks` |
| `flutter-add-integration-test` | 未配置 `integration_test`，也没有 golden 基线；集成测试要真机/模拟器驱动 + 稳定截图，属独立工程投入（CI 已能跑三平台构建，但仍未接这套） | 决定投入集成测试 + 立 ADR |

**组件库现状（ADR-0002 实施中）**：`shadcn_ui` 0.56.3 已是 `pubspec.yaml` 的直接依赖，`lib/main.dart` 经 `theme/dsw_shad_bridge.dart` 挂载 `ShadTheme`（colour 仍全部来自 `DswAlias`），`capsule_button` 与块原语（`primitives/tappable.dart` 的 `DswHoverTap`）已用上 shad 的按钮/焦点/语义机制。`shadcn-ui-flutter` skill 从"守卫项"转为**正当的组件参考**。不变的约束：颜色/字号只从 `lib/theme/dsw_*` 取，不要 `import 'package:shadcn_ui/...'` 去读它的调色板配色——组件用 shad、配色用 dsw。`packages/flutter-shadcn-ui/` 仍是 gitignore 的本地源码镜像（ADR-0001）。

## 3. 本仓库特有工作流（skill 覆盖不到的部分）

**genkit 升版。** 投影逻辑的依据全写在 `spike/agent_spike.dart` 头部的 FINDINGS（可执行证据）。升完依赖先 `dart run spike/agent_spike.dart` 重跑，再对照这三条：`Part` 是单一 json-backed 类型（`part is TextPart` 永不成立，要用 `PartExtension` 的 `isText`/`isToolRequest`/… 判别）；`SchemanticType.jsonSchema(...)` 不存在，运行时 schema 用 `SchemanticType.from<T>(jsonSchema: ..., parse: ...)`；`chunk.accumulatedText` 是 **turn-global**，不能当单条消息正文，要按 `chunk.raw.modelChunk.index` 分组。若升版使 FINDINGS 失效，先补 ADR 记录新事实，再改 `lib/genkit/`。

**工作区指令注入（ADR-0009）。** `lib/genkit/instructions.dart` 会在开会话或换工作区时，把用户级 `~/.agent_harness/AGENTS.md` 与**从文件系统根到工作区这条链上**的 `AGENTS.md`/`.agents/AGENTS.md` 合成一个块，作为**首条用户消息的前置 TextPart** 发给模型（不是 system prompt——agent 只定义一次、workspace 是活 setter）。三条实操后果：① 本仓库的 `AGENTS.md` 与它指向的规则**现在是模型的输入**，写它就等于写给 agent 的指令，密钥/内部主机名一律不要放进去；② 只向上找、**不向下扫子目录**，子项目的 `AGENTS.md` 要靠 `read` 工具自己取；③ 预算是单文件 8 KiB / 总 24 KiB，超限会**在块里明说截断**，所以别指望长文件后半段生效。`openSession()` 恢复的会话不会重发（历史里已有）。改这块行为的回归面：`test/instructions_test.dart`。

**加/改一个 agent 工具。** 顺序是：`lib/genkit/tools.dart`（`WorkspaceTools` 只注册一次，工具在调用时读 workspace，换文件夹不重注册）→ 需要新事件形状时在 `lib/model/turn_event.dart` / `conversation.dart` 里表达 → `lib/genkit/agent_runtime.dart` 做投影 → UI 侧 `lib/ui/tool/tool_card.dart`。会写文件/执行命令的工具要走 `lib/model/approval_mode.dart` 的审批回路（interrupt → resume），判定见下一段。工具的 description 与返回给模型的 error 文本**不进 i18n**：那是模型读的，不是 UI 文案。验收：`dart run spike/runtime_smoke.dart`（离线跑 no-key / 空 store 路径；带 `DEEPSEEK_API_KEY` 则真跑一轮流式 + 工具环 + 审批 + **覆盖写镜像断言** + 恢复；判成败别看接了管道的退出码）。这道门能不能跑取决于 `lib/genkit/` 保持无 Flutter（ADR-0015，规则 6 守着）——工具需要跨层共享的状态时，把纯 Dart 的形状放进 `lib/model/`，别去 import `lib/state/`。

**审批门禁只有一个顺序（ADR-0012）。** `lib/genkit/tools.dart` 的顶层函数 `decideGate({mode, subject, decided, modeRefusal})`：`plan` 先拒 → 命中 deny 规则带理由拒 → 命中 allow 规则静默放行 → 非 `ask` 放行 → 否则 interrupt。三个可写工具调 `WorkspaceTools.gateFor(kind, subject)`，MCP 外部工具在 `agent_runtime.dart` 的 `_ToolGate` 里调同一个函数——**不要在新工具里自己拼 `shouldInterrupt`**，否则外部/内部会出现两套免问语义。两件事必须同时记住：① 工具"是否只读"的唯一声明是 `WorkspaceTools.readOnlyToolNames`，委托目标（sub-agent）的工具集由它派生，加只读工具就把它加进这个集合，不要再在 `agent_runtime.dart` 里补一份列表；② 规则的 subject **必须与审批面板显示的那串一致**（文件用 `ws.relative(path)`、命令用原文、外部工具用 `server/tool`），由 `ApprovalRequest.ruleFor()` 从 interrupt payload 反推——"记住的东西"和"用户批准的东西"分叉就是安全漏洞。规则落在 `<support>/approvals.json`，按工作区分键；设置页 `approvals` 节可逐条移除（"只能加不能减的免问"按隐藏后门处理）。会话级作用域与 deny 规则的面板入口是**已知缺口**，理由记在 ADR-0012。回归面：`test/tool_gate_test.dart`、`approval_rule_test.dart`、`approval_rule_store_test.dart`、`approval_panel_test.dart`。

**忙时输入只有一个出口（ADR-0013）。** 一次 run 期间用户仍然能提交，去向由 `InputDelivery` 决定：`queue` 排在本轮之后，`guide` 交进本轮。三条不可拆开的事实：① **队列归控制器**（`lib/state/conversation_controller.dart` 的 `_queue`），排空点**只有一个**——`await _consume(...)` 返回之后的那一次 `_drain()`（`send` 与 `respondToApproval` 两条路径都走到）；绝不在 `_handle(TurnFinished)` 里排空，那时旧 subscription 还没 settle，新流会丢掉通知。② **交接归运行时**：`AgentRuntime.guide()` 只在 `_turn != null || _pendingInterrupts.isNotEmpty` 时收下（审批暂停也算在跑），文本由 `_GuideInjector` 这条 `GenerateMiddleware.model` 在**下一次模型调用**写进 `ModelRequest.messages`——追加到最后一条 user/tool 消息，不新开一条（provider 一条 Message 就是一个 turn，避免相邻同角色）。③ **没读走的一定要回来**：`takeUndeliveredGuides()` 在 `_drain()` 开头整批插回队首；纯长回答不会再有模型调用，漏了这一步就是静默丢用户输入。另两条实操后果：`stop()` 只是**停车**（`_queueHeld`），用户再次 send 才放行且新消息先发；队列**刻意不持久化**（它是草稿不是历史，换会话随 `_reset()` 一起丢）。改这块的回归面：`test/input_queue_test.dart`、`test/input_queue_panel_test.dart`，以及 `spike/agent_spike.dart` 的 probe G + FINDINGS 15（genkit 升版必查：若循环不再从被改过的请求派生下一轮，`guide` 会退化成一次性耳语）。

**文件写入只有一个回退闸门（ADR-0014）。** `write`/`edit` 在**覆盖写之前**把原字节交给 `CheckpointSink`（接口在 `lib/model/checkpoint.dart`，实现在 `lib/state/checkpoint_store.dart`，`lib/genkit` 只认接口——不变量 1/2 都不破），存的是 **before 镜像**（内容寻址 blob，同一份字节只存一份）+ after 指纹，不存 patch、不做 shadow git。五条实操后果：① **只有这两处可截获**——`bash`（`shell_run.dart` 走 `Process.start`）与 MCP 工具改的文件没有镜像，报告必须明说，别把它说成"这一轮的全部变化都能退"；② 动手之前必看冲突闸门：该 path **范围内最新**条目的 `afterFingerprint` 与磁盘不符（含"agent 新建、用户又编辑过"）就**不动它**并报 `changedOutsideAgent`，镜像没存（超 2 MiB）或已被淘汰就报 `imageUnavailable`——宁可什么都不改，也不盖别人的编辑；③ 会话归属是 `AppScope` 铸造的占位令牌（`unsaved-N`），第一轮持久化拿到真 session id 时由 `adoptConversation` 就地改名，**不要在 `AgentRuntime` 里再存一份令牌**（两个必须相等的字段就是一种新的错法）；④ 范围只有 `conversation`/`workspace` 两档（`both` 与 `workspace` 同义，已砍）；⑤ 落盘在 `<support>/checkpoints/`（app 级，不往用户工作区写，理由同 ADR-0012），随 `backup_service` 的 zip 一起走。UI 入口长在改动本身旁边：`ui/tool/tool_card.dart` 的 `_QuietPill` → `previewRewind` → `primitives/confirm_dialog.dart` 二次确认（逐文件说"恢复 / 删除 / 保持不变 + 理由"）→ `rewindTo` → 用**同一个**构造函数报告结果，两者不能各说一套。服务到卡片手里走 `ui/tool/checkpoint_scope.dart`（`InheritedWidget`，沿 `DetailsSelectionScope` 先例；riverpod 不许进 widget 树），`ConversationRoot` 的那两个回调由 `main.dart` 从 `AppScope` 传入。还有一条别忘：**被批准的工具结果不在直播流里**——genkit 跑被重启的工具时不 `sendChunk`，所以 pill 读得到的那个 `checkpoint` id 是 `_drive` 在收尾处从 `_agent.getSnapshot().messages` 补投影出来的（ADR-0016）。删掉那段补投影，症状不是报错而是"回退按钮要点开重会话才出现"。改这块的回归面：`test/checkpoint_test.dart`（真实临时目录：镜像、闸门、两种范围、预算淘汰）、`test/rewind_pill_test.dart`（pill 的出现条件、确认框与报告的措辞同源、取消不动盘）。

**加一个工作台 tab。** 三步：`lib/model/sidebar_tab.dart` 的 `BuiltinTabType` 加一个字符串常量（`TabType` 是 `String` typedef，**不是封闭 enum**，registry 接受任意键，所以新增类型不必改这个文件之外的地方）→ 新建 `lib/ui/workbench/tabs/xxx_tab.dart` → 在 `lib/ui/workbench/workbench.dart` 的 `_registerBuiltinTabs()` 里 `registerTab(TabDescriptor(...))`。`tab_registry.dart` 头部写明了为什么只保留 4 个字段（源项目 `TabDescriptor` 的 `single`/`available`/`badge`/`urlTarget` 等在别处已有答案或无消费者），别回去补那十二个字段。

**双树工作台（一布局，两面板）。** `SidebarState` 持有**两棵树**：`tree`（右栏）与 `bottomTree`（下栏），`lib/model/sidebar_state.dart:99-139`。三条必须记住的性质：① 两棵树共用**一个** pane id mint 计数器，所以一个 id 全局唯一地命名一个 pane——别给下栏另起计数器；② `activePane` 是**单个全局**（最后被触碰的 pane，不分树），新 tab 落它；③ 面板的开合与尺寸**只归 `LayoutController`**（`panelOpen`/`width`/`bottomOpen`/`bottomHeight`），`SidebarState` 不复制第二份真值。跨树拖拽/右键移动走 `lib/model/split_node.dart` 的 `takeTabFrom`（`:451`）与 `moveTabBetweenTrees` / `moveTabBetweenTreesToEdge`（`:486,:510`）；UI 侧用 `workbench.dart:120` 的 `enum WorkbenchPanel { right, bottom }` 指明目标面板。布局事实（Layout audit `c53af9e`）：下栏只挤压中列，tab 条本身就是顶部 chrome（带 `+` opener 菜单），面板切换按钮聚在视口右上角，条高 34px。持久化在 `state/workbench_store.dart`：每会话一个文件、写盘按会话防抖 200ms，`bottomTree` 与 `tree` 一同存。回归面：`test/sidebar_state_test.dart`、`split_node_test.dart`、`workbench_ui_test.dart`。

**工作区模式（企划/代理）与企划扩展面板（ADR-0007）。** 开关是 `lib/state/workspace_mode_controller.dart`，经 `app_providers.dart` 的 `workspaceModeProvider` 前置。两条设计约束别漏：① 模式是**视图状态，刻意不持久化**——重启回到代理模式（该决定写在 controller 头部注释里）；② 它是 `ChangeNotifier` 而不是 riverpod `Notifier`，因为 riverpod import 只允许出现在 `main.dart` + `app_providers.dart`。企划侧的 Markdown 工作台在 `lib/ui/plan/plan_workspace.dart`，扩展面板（看板/日程/表格）在 `lib/ui/plan/plan_extensions_view.dart`，用入库本地包 `packages/board_panel`（path 依赖；ADR-0007 D5 明确它是 ADR-0001"vendored 不入库"的记录在案例外，别再往 `packages/` 里塞第二个入库镜像）。任务数据走 `lib/state/plan_task_store.dart`（`planTaskStoreProvider`，`main`/测试里必须 override）+ `lib/model/plan_task.dart` 的手写序列化。回归面：`test/workspace_mode_test.dart`、`plan_workspace_test.dart`、`plan_task_store_test.dart`。

**文案。** 新增或修改 UI 字符串必须**同时**进 `lib/l10n/locales.dart` 的 `enStrings` 与 `zhStrings`，键完全一致（**不记死条数**——它随加键漂移，是典型的会腐烂的断言；对齐才是不变量，现由 `test/l10n_parity_test.dart` 断言两个方向的键集差集为空，ADR-0008）。en 是先写的源语言，zh 逐键回退到 en（`translate()`：`zhStrings[key] ?? enStrings[key] ?? key`），两边都缺则把键本身渲染出来，好让缺口可见。取值走 `context.tr(key, params)`，`{name}` 占位符插值。**守卫只管键不管值**：zh 是否真的翻译过、译得对不对，仍是人眼的事；`{name}` 占位符名两侧是否一致也没进守卫（要加就再立 TST 类 ADR）。**不挂 `AppLocaleScope` 即退化成英文**，这是 widget 测试不关心 i18n 的前提，别改这个 fallback。不做 i18n 的两类内容：持久化进 layout 的 tab 标题（数据不能随语言翻），以及单例 tab 的显示名（在渲染时由类型派生）。

**主题。** 颜色/字号/动效/阴影只从 `lib/theme/dsw_*` 取：别名令牌在 `dsw_alias.dart`，绑定与 elevation ramp 在 `dsw_theme.dart`，排版在 `dsw_typography.dart`，shad 桥在 `dsw_shad_bridge.dart`（DswAlias → ShadColorScheme，反向取 shad 配色即违规）。新增令牌加在 alias 层，让 widget 通过 `context` 拿。抄 dsh 的 CSS 阴影值必须换算——CSS blur 与 `BoxShadow.blurRadius` 不是一回事（见 `DswShadow._blur`）。**对比度是 ADR-0004 的显式豁免面**：动正文级颜色前先 `dart tool/contrast_check.dart`（确定性三求值，只依赖 dart:io/dart:math）并保证 `test/theme_contrast_test.dart` 仍绿；该 ADR 采纳的是"方案 B 显式豁免"，所以低于 AA 的令牌是**决策**而不是待修 bug，别顺手"提亮"。圆角/间距/控件尺寸是 ADR-0017 的面：只在 `lib/theme/dsw_shape.dart` 加档位，`test/theme_token_test.dart` 会扫 `lib/ui/**` 里括号后不是 `DswShape.` 的 `Radius.circular(`（**只认数字的正则拦不住 `wide ? 12 : 999`**，这条改过一回）。

**行里的自由文本必须有 flex 上界。** 侧栏行、工具卡头、状态条这类"一行装一个可变长度字符串"的地方，`Text` 要么是 `Expanded`/`Flexible` 的子件，要么就会溢出面板——**`overflow: TextOverflow.ellipsis` 单独写没有用**，因为 Row 的非 flex 子件是按无限宽量出来的，ellipsis 根本没有触发机会。已踩实过的三处：`composer.dart` 的工作区状态条（长文件夹名撑出 487px）、`diff_tab.dart` 的 `← 旧路径`（ellipsis 在场仍漏）、`primitives/disclosure_row.dart` 的标题（每条工具卡与推理行共用）。守卫是 `test/disclosure_row_test.dart`，它把机制反向验死：同样的 Text 换成非 flex 包装，180px 面板溢出 1224px。窄屏降级也有一条律：**先丢标签与描边，最后才丢座位**（一个控件消失了就不叫降级，叫缺控件）。

**成组靠同一中心线和一个间距，不靠嵌套。** 想让几个控件读成一组，就把它们做成同级、等高、相邻；**把一个控件塞进另一个控件的 `DswHoverTap`/`_Pressable` 里**不是成组，是嵌套：hover 小的会点亮整行、点空白处会触发那个"看起来不相干"的目标、语义树变成"按钮里装按钮"。侧栏底部那枚"孤立的设置按钮"真因就是这个（`005b76c`，守卫 `sidebar_test.dart` 的 `the footer controls are neighbours, not nested targets`——反向验过：旧结构量到触发区右边界 268 > 齿轮左边界 206）。

**"未居中"这类主张只有同轴这一种证法。** 眼睛在截图上量不出一列正中没有偏：把 `ConversationRoot` 在固定视口宽度（1400/1152/700）各起一次，取**输入卡、正文左沿、用户气泡右沿**三块矩形，断言轴差而不是像素——正文左沿 = 卡左沿 + `composerCardWidthInset/2`、气泡右沿 = 卡右沿 − 同一枚 inset、卡中心 = 视口宽度的一半。审计 §3-C 的"正文中心偏右约 66px"就是这样被撤回的：中列一直与卡片同轴，左边那条空白是用户气泡按 dsh 的 `max-width: min(525px, 82%)` **自己**封顶并右对齐的结果（`ui/conversation/message_item.dart:47-60`），不是布局缺陷。**先问"这块本来该不该贴右"，再立缺陷**——旁白与正文在同一列里读起来就是两种对齐。反向验过：`Center` → `Alignment.centerLeft` 即红（`Expected: <326.0> Actual: <32.0>`）。守卫 `chat_view_test.dart` 的 `the transcript and the aside share the card's two axes`（`3990b0c`）。

**一个状态一枚 token，容器也一样。** 交互态各要一档：hover 与 selected 不许同色（ADR-0017 S2 的 `interactiveSelected`），**一张卡片也不许只有一枚静态边**——输入卡就因此被记成"边界不清"（UI 审计条 4）：屏幕上没有任何东西说明键盘在谁那里。现在按 ZCode `ChatPromptEditor.tsx:347` 的三态形状取值：静置 `borderL2DarkmodeThin`(0.06) → hover `borderL3`(0.12，正好 2×) → focus-within `brandPrimary`，`AnimatedContainer` + `DswMotion.fast`（那一档动效本来就是 hover/press 反馈）并经 `DswMotion.respecting` 尊重 reduced-motion；**焦点优先于 hover**（"正在打字"才是用户要知道的状态）。`b9684f4`，守卫 `composer_test.dart` 的 `the card shows which surface has the keyboard` 走 autofocus／`Tab` 走开／指针进出／点回字段，读的是**画出来的** `BoxDecoration.border` 而不是 widget 参数——反向验过：换回一枚静置边即红。两条实操结论：**先复用别名层已有档位，别为一种状态造一枚新令牌**；ZCode 那一步还换 `bg-input-focused`，这里按"说话的是边不是底"拒绝，免得为一个观感多出两枚随明暗变的字段。

**riverpod 读缝（bridge）。** 把 `ChangeNotifier`/store 桥成**函数式** provider 时，值变更用 `ref.invalidateSelf()`（重跑 body 取新值），**绝不用** `ref.notifyListeners()`——后者对函数式 provider 只重通知旧缓存、不重跑 body，会静默不刷新（且运行日志无异常，只有真机能发现；见 `state/app_providers.dart` 的 `settingsDocument`/`workbenchPrefs`）。该文件现有 19 个 `@Riverpod` 声明；`planTaskStore` 之类默认体直接 `throw UnimplementedError`，是**逼调用方在 `main`/测试里 override**，别把兜底塞回 provider。

**持久化。** 手写 `toJson`/`fromJson` + `dart:convert`（`lib/model/` 里那批 settings/state 模型即范例）。写盘沿用 `lib/state/settings_store.dart`、`prefs_store.dart` 的 tmp + rename 原子写；工作台布局是**每会话一个文件** + 200ms 防抖（`workbench_store.dart` 头部说明了为什么不合并成一份文档）。设置类偏好的真值入口是 `AppSettings` / model 里的 settings 类，新增字段要同时接住全屏设置页与底部快捷菜单（ADR-0006），只接一处就是分叉。工作区访问靠 security-scoped bookmark，恢复必须发生在任何读文件之前（`main()` 里的 `restoreWorkspaceAccess`）。跨机搬迁走 `state/backup_service.dart`（zip 打包 settings/prefs/tasks/layouts/sessions/skills/checkpoints）。

## 4. 测试约定

- 一律 `flutter test`。dev 依赖只有 `flutter_test`，`dart test` 跑不起来（`test/` 下**每一个** `*_test.dart` 都 import `package:flutter_test`，包括纯逻辑的 `test/file_search_test.dart`；条数以 `ls test/*_test.dart | wc -l` 现场为准，别抄文档。另有 3 个手写替身 + 1 个探针，它们不是测试）。
- **CI 已经在跑这套门禁**（`.github/workflows/pr-check.yml`，push/PR 到 `develop`·`main`）：`dart format --set-exit-if-changed lib test tool spike` + `dart analyze --fatal-infos lib test tool spike` + `flutter test`。本地三条命令与它同口径，`--fatal-infos` 意味着 info 级提示也会拦下你。
- **当前基线不是绝对全绿**：2026-09-29 在 macOS 开发机跑到 `+834 -2`（ADR-0009/0010/0011/0012/0013/0014 六批新测试之后又加了 P1 形状令牌、P4 窄列、P3 标题节奏、ADR-0018·侧栏底部、§3-C 同轴、输入卡三态六批 UI 守卫；首跑时是 `+699 -2`），那 2 个失败始终是同样两条（`app_scope_test` 的 `/var`↔`/private/var` 路径规范化、`plan_workspace_test` 的 `find.text('notes')` 命中两个 widget），都已登记在债务表，都与代理配置改动无关。交付前跑一次记下失败集，只对"零新增失败"负责，别把它们说成自己改坏的，也别顺手改测试断言。**通过条数会随加测试漂移，验收口径始终是那两个失败没变多**。
- 替身手写，命名 `test/fake_*.dart`（现成三个：`fake_turn_source.dart`、`fake_git.dart`、`fake_terminal_process.dart`；`clipboard_probe.dart` 是探针不是测试）。文件系统类测试走真实临时目录，因为要验的是 mtime 排序、跳过 VCS 元数据、二进制早退这类**文件系统事实**，fake 证不出来。
- 每个测试文件头部用注释写清"本文件要守住的那句话"以及它存在的理由（参考 `test/conversation_controller_test.dart`、`test/file_search_test.dart`）。
- widget 测试不挂 `AppLocaleScope`，直接断言英文文案。
- 流式拆分是本项目唯一的性能契约：token delta 只能通知 tail 的 notifier，不得通知 conversation controller（由 `flutter test test/conversation_controller_test.dart` 守着）。
- 已有**专门守卫**的不变量，改相关面时必跑：双树/布局 `sidebar_state_test.dart`·`split_node_test.dart`·`workbench_ui_test.dart`·`app_frame_test.dart`；工作区模式与企划 `workspace_mode_test.dart`·`plan_workspace_test.dart`·`plan_task_store_test.dart`；主题令牌与对比度 `theme_token_test.dart`·`theme_contrast_test.dart`，容器交互态 `composer_test.dart` 的 `the card shows which surface has the keyboard`（改任何容器的描边或底色档位都要跑——状态要能分辨，也能测出来）；markdown 渲染与标题块间距（LaTeX/Mermaid + 那条"标题必须比段落更空"的差值断言）`markdown_rendering_test.dart`；`DswHoverTap` 的指针/键盘/语义/右键四性 `dsw_hover_tap_test.dart`；i18n 双语键集 `l10n_parity_test.dart`（ADR-0008——它只拦键，不拦译 quality）；附件能力门 `composer_test.dart` 的 `the attach gate` + `model_directory_test.dart` 的 `image capability`（ADR-0010）；架构门禁 `architecture_check_test.dart`（ADR-0011 的三条不变量 + ADR-0015 的"运行时不碰 Flutter/state"，等价于 `dart tool/check_architecture.dart` 的六条规则）；审批门禁与免问规则 `tool_gate_test.dart`·`approval_rule_test.dart`·`approval_rule_store_test.dart`·`approval_panel_test.dart`（ADR-0012——四者分别守判定顺序、匹配语义、按工作区落盘、面板三按钮）；忙时输入 `input_queue_test.dart`·`input_queue_panel_test.dart`（ADR-0013——前者守队列与交接，后者守面板只渲染控制器）；文件回退 `checkpoint_test.dart`·`rewind_pill_test.dart`（ADR-0014——前者守镜像/闸门/范围/淘汰，后者守 pill 只在 `write`/`edit` 且挂了服务时出现、确认框与报告用同一套措辞）；窄列下的行上界与降级 `composer_test.dart` 的 `the row in a narrow column` + `disclosure_row_test.dart`（改任何"一行装可变文本"的界面都要跑，溢出是能断言的，不是要靠眼睛）；**会话列几何** `chat_view_test.dart` 的最后两条（透明渐隐带下的统计行 = ADR-0018，中列与输入卡同轴 = 审计 §3-C；改 `ChatView`、seat 或 `MessageItem` 的对齐都要跑——重叠与偏移都是**轴差**断言，截图不是证据）。

## 5. Git 提交（强制）

- 新建 commit 一律用 `git-commit` skill 生成 Conventional Commits 消息：`<type>[scope]: <description>`。
- type 取：feat / fix / refactor / perf / test / docs / build / chore / revert。
- scope 用本仓库的顶层归属名：`genkit`、`model`、`state`、`ui`、`theme`、`l10n`、`host`、`workbench`、`plan`、`macos`、`deps`；`packages/board_panel` 内的改动用 `board_panel`；仓库级配置（`.qoder/`、`.trae/`、`AGENTS.md`、`.gitignore`、`repomix.config.json`、`tool/`）用 `config`；CI 工作流用 `ci`；ADR 与登记表用 `adr` 或 `docs`。
- description 用**英文**现在时祈使句，≤72 字符（与既有历史一致：`C4: the tab strip's right-click menu`）。里程碑式改动可保留早期那种阶段编号前缀，但仍要带 type。
- 破坏性变更用 `feat!:` 或 `BREAKING CHANGE:` footer。
- **主干工作分支是 `develop`**（ADR-0002 的改造面），`main` 可能落后于它；动手前 `git rev-parse --abbrev-ref HEAD` 现场确认，别信任何文档里写死的分支。
- 安全红线（skill 内已申明，此处重申）：永不改 git config、永不 force push / hard reset、永不用 `--no-verify`；钩子失败后修复并**新建** commit，绝不 amend 已存在的提交；一次提交只含一个逻辑变更，按文件/模式分组 add。
- 不提交：`repomix-output.*`、`dart_sources.md`、`.workbuddy/`、`pubspec.lock`（库型包约定，已在 `.gitignore`）、`_archive_project/`（本地归档的第三方参考源码，约 88 MB，2026-09-29 起进 `.gitignore`）、以及任何 API key。`.gitignore` 仍**没有** `*.p12`/`*.cer`/`*.mobileprovision`——引入证书之前先补这几条（`build.md` §4）。

## 6. 文档 / API 时效性

- genkit-dart 及伴生包是 0.x，**以包源码为准**，不要信记忆里的写法。实际解析版本用 `flutter pub deps` 现场核对；要读实现就去 pub cache 下的对应目录（默认 `~/.pub-cache/hosted/<mirror>/<pkg>-<version>/`，`PUB_CACHE` 环境变量可覆盖）。两篇技术文档记录的审读基线是 genkit 0.16.1 + `genkit_openai` 0.4.1 / `genkit_anthropic` 0.3.1 / `genkit_mcp` 0.3.1 / `genkit_middleware` 0.6.1。注意 `pubspec.lock` 不入库，锁文件里的版本对别人不是事实，命令输出才是。
- 根目录两篇长文是现成的评估证据，回答"还能借哪些能力 / 该放弃哪些幻想"前先查它们：`技术文档-agent_harness基于genkit-dart的可落地增强路线.md`、`对标技术文章-agent_harness与dsh生态横向对比.md`。
- 第三份现成评估证据：`docs/zcode-vs-agent-harness-2026-09.md`——对 ZCode-main（本地归档 `_archive_project/ZCode-main`，**已在 `.gitignore` 里，新 clone 没有它**）的 UI/agent/功能/治理逐维度对比与 A/B/C 移植分级。回答"ZCode 有没有这个能力、该不该搬"先查它，别重新调研整个归档。
- context7 之类的文档 MCP 可作辅助，但本仓库**尚未**配置 `.mcp.json`；没有它就不要声称查过最新文档。
- **版本基线现在有两处真值**：`pubspec.yaml` 的 `environment.sdk` 与 `.github/workflows/{pr-check,build}.yml` 的 `FLUTTER_VERSION: '3.41.9'`。换 SDK/Flutter 必须同时改并让 pr-check 绿，否则本地与 CI 各跑一个版本（CFG 类漂移，按 §7 立 ADR）。
- 本仓库文档里的**文件数/行数/测试数/键数都是快照**（校准于 2026-09-29，HEAD `45dee4e`）。它们会腐烂：引用前用 `find`/`wc`/`grep -c` 现场重算，发现对不上先改文档再动手，别把过期数字当事实。
- 需要把整仓库交给 AI 理解时跑 `repomix`（配置 `repomix.config.json`，产物 `repomix-output.xml` 不入库）。它已经把 `packages/flutter-shadcn-ui` 的实现源码排除了；而按 ADR-0001，该目录本身也被 `.gitignore` 排除，**新 clone 不会有它**——要读该库实现，先从上游 `nank1ro/flutter-shadcn-ui` 取 `0.56.3`，否则只读入库的 `.qoder/skills/shadcn-ui-flutter/` 组件文档。

## 7. 技术债与缺陷记录（ADR）

- 审计发现的缺陷、技术债、架构决策一律落盘 `docs/adr/ADR-NNNN-<分类小写>-<slug>.md`（模板 `docs/adr/ADR-0000-template.md`），并在 `docs/debt-register.md` 追加一行；规范见 `docs/README.md`。登记表是唯一状态源：新增观察写进它的"待立 ADR"表，闭环后回填状态与 commit hash，不要另开一份清单。
- 分类：SEC 安全 / CFG 配置漂移 / DEF 缺陷 / ARC 架构 / DEP 依赖 / DEBT 技术债 / TST 测试。优先级 P0（安全红线或评估阻断）> P1（影响真实使用）> P2（债务与优化）。
- 状态机：`PROPOSED → ACCEPTED → IN-PROGRESS → RESOLVED`（分支 DEFERRED / SUPERSEDED 须注明原因）。
- 纪律：动手修复已登记问题前，对应 ADR 必须先置 ACCEPTED；修复合入后置 RESOLVED 并回填 commit hash；新审计发现先补 ADR 再改代码；「背景」必须带证据（`文件:行号`、grep/构建/测试输出），禁止无证据登记。
- 本项目特别需要立 ADR 的动作：踩 §0 不变量的、动 `macos/Runner/Release.entitlements` 的、引入新依赖或代码生成器的、**再往 `packages/` 塞一个入库本地包的**（`board_panel` 是 ADR-0001 的个案例外，不是新惯例）、**增删桌面平台目标的**（ADR-0003 的先例）、**动 ADR-0004 对比度豁免面之外的正文级配色**的。
- 现存台账（截至 2026-09-29）：ADR-0001 vendored shadcn 不入库（RESOLVED）· ADR-0002 riverpod + shadcn 迁移（IN-PROGRESS，仅余 macOS 真机验收）· ADR-0003 Windows/Linux 目标（RESOLVED）· ADR-0004 亮色对比度 AA 显式豁免（ACCEPTED，方案 B 决策性关闭；登记表此前误记 PROPOSED，已拍平）· ADR-0005 starkins 设置页重建（RESOLVED）· ADR-0006 全屏设置 + 级联快捷菜单 + Profile（RESOLVED，Supabase 仅留接缝）· ADR-0007 工作区模式 + 企划 Markdown + 扩展面板（ACCEPTED，分阶段实施中）· ADR-0008 i18n 双语键集守卫（RESOLVED）· ADR-0009 工作区指令注入（IN-PROGRESS @ 9019f3c）· ADR-0010 图片附件能力门控（IN-PROGRESS，余真机走查）· ADR-0011 架构门禁（`tool/check_architecture.dart`，RESOLVED）· ADR-0012 工具契约单点声明 + 按工作区的免问审批规则（IN-PROGRESS，余带 key 真实链路确认）· ADR-0013 忙时输入队列 + 中途转向（IN-PROGRESS，余带 key 真实链路走查）· ADR-0014 文件级 checkpoint + rewind（IN-PROGRESS @ 70e3206/f9782a7/2b0bc24/5988cfa/e385f58/0ec548d，S1–S3 已落，余带 key 真实链路签收）。ADR-0015 运行时脱离 Flutter 依赖、恢复真实链路冒烟门（RESOLVED @ eb17573/c2b7c49/3af1317，第 6 条架构规则随之进门禁）· ADR-0016 审批通过的工具结果从不进直播投影，卡片停在 `running` 且回退 pill 当轮不出现（RESOLVED @ 815814e/ebcdd45/7712df1；**第一次带 key 真跑 `spike/runtime_smoke.dart` 才暴露**，当时离线四道门全绿）· ADR-0017 形状令牌契约（IN-PROGRESS @ c2255c6/74ab800/88b9f54，余 S3 文本缩放）· ADR-0018 输入区那条**设计上半透明**的渐隐带把统计行与正文叠画（DEF P1，RESOLVED @ bd38147——seat 内容从此从带子下面开始）· ADR-0019 标题栏要不要改成自绘 chrome（ARC P2，**PROPOSED 不动手**：三个候选全是观感改动，而本机 `screencapture` 无 Screen Recording 权限；开工前置条件写在 ADR）。UI 生产化批次（`docs/ui-production-audit-2026-09.md` §5）：P1/P3/P4 已落，P0 已全闭（§3-C 复现后**撤回**：中列与输入卡同轴，左边的空白是用户气泡自己的 min(525px,82%) 封顶，守卫见 3990b0c），P2 余 ADR-0019（侧栏底部成组已落 @ 005b76c）。**下一编号 ADR-0020**。**行号/编号/状态都以 `docs/debt-register.md` 与 `ls docs/adr/` 现场为准**，别抄这一行。
