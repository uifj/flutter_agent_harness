# 技术债与缺陷登记表（debt-register）

本文件是本仓库**唯一的状态源**：所有已登记问题的分类、优先级与当前状态在此总览，细节与证据在下钻的 ADR 里。修改规则、分类、状态机见 [README.md](README.md)。迁移的逐阶段执行台账（commit/门禁/待签收）见 [migration-log.md](migration-log.md)。

## 已登记

| 编号 | 标题 | 分类 | 优先级 | 状态 | 日期 | ADR |
| --- | --- | --- | --- | --- | --- | --- |
| ADR-0001 | vendored `packages/flutter-shadcn-ui` 不进版本库 | DEP | P2 | RESOLVED @ d72ff4c | 2026-09-15 | [链接](adr/ADR-0001-dep-vendored-shadcn-ui.md) |
| ADR-0002 | develop 分支改造为 riverpod + shadcn_ui | ARC | P1 | IN-PROGRESS（riverpod 读侧 Stage 1–3 完成、Stage 4 热替换链保持命令式·修订 2；shadcn Stage 4/5a–5d 已落、深层组件替换达自然边界·修订 3；余仅 macOS 真机验收） | 2026-09-15 | [链接](adr/ADR-0002-arc-riverpod-shadcn-migration.md) |
| ADR-0003 | 增加 Windows/Linux 桌面平台目标（本机可验证） | ARC | P2 | RESOLVED @ 54e75d7 | 2026-09-16 | [链接](adr/ADR-0003-arc-windows-linux-platforms.md) |
| ADR-0004 | 亮色正文对比度 AA 修正层（A 新增 AA 别名 / B 显式豁免） | CFG | P1 | ACCEPTED（决策性关闭：采纳 **B 显式豁免**，palette 不改；回归门禁 `test/theme_contrast_test.dart` 已落地防恶化。此前本行误记 PROPOSED，与 ADR 正文的 ACCEPTED(B) 矛盾，2026-09-29 拍平） | 2026-09-16 | [链接](adr/ADR-0004-cfg-light-contrast-aa.md) |
| ADR-0005 | 以 starkins 设置页为蓝本重建设置界面（重接本项目栈） | ARC | P1 | RESOLVED（S1–S5 落地，S5 真机走查通过；未接线的 previewMode/字体/皮肤见下方观察行） | 2026-09-16 | [链接](adr/ADR-0005-arc-starkins-settings-rebuild.md) |
| ADR-0006 | 设置面重构：全屏设置视图 + 底部级联快捷菜单 + 用户 Profile（预留 Supabase） | ARC | P1 | RESOLVED（S1–S5 已落 develop，S5 Windows 真机走查通过；Supabase 仅预留接缝未接） | 2026-09-16 | [链接](adr/ADR-0006-arc-settings-fullscreen-profile.md) |
| ADR-0007 | 工作区模式切换（企划/代理）+ 企划 Markdown 工作台 + 扩展面板（board_panel） | ARC | P1 | ACCEPTED（S1–S5 待实施；board_panel 入库为 ADR-0001 先例的记录在案例外） | 2026-09-16 | [链接](adr/ADR-0007-arc-workspace-modes-extensions.md) |
| ADR-0008 | i18n 双语键集对齐加机器守卫 | TST | P2 | RESOLVED @ 5c14ec8（`test/l10n_parity_test.dart`；反向验证实测过：单侧插一个键即失败并指名缺哪个） | 2026-09-29 | [链接](adr/ADR-0008-tst-i18n-key-parity.md) |
| ADR-0009 | 工作区指令注入（AGENTS.md → 上下文消息） | ARC | P1 | IN-PROGRESS @ 9019f3c（S1 已落：`lib/genkit/instructions.dart` + 11 例单测 + `send()` 排队/排空；顺带修掉 `_systemPrompt` 的 "on the user's Mac" 平台硬编码。带 key 的真实链路注入仍待确认） | 2026-09-29 | [链接](adr/ADR-0009-arc-workspace-instructions.md) |
| ADR-0010 | 图片附件按模型能力门控（含纯附件发不出、Windows 附件名两处缺陷） | DEF | P1 | IN-PROGRESS @ c34d1a7/ac18647/4496677（能力表 + composer 单门 + 两处同源缺陷已修，7 例测试绿；余 macOS 真机贴一张 deepseek 下的图走查） | 2026-09-29 | [链接](adr/ADR-0010-def-image-capability-gate.md) |
| ADR-0011 | 架构不变量做成可执行门禁（指纹 baseline + 只拦新增） | TST | P2 | RESOLVED @ f74417b（`tool/check_architecture.dart` 五条规则 + `tool/architecture_baseline.json` 7 条实况债务 + 6 例测试；反向验证实测：临时往 `lib/model/` 加一个 flutter import → 退出码 1 并指名规则。`flutter test` 已含它，CI 无需改） | 2026-09-29 | [链接](adr/ADR-0011-tst-architecture-gate.md) |
| ADR-0012 | 工具契约与审批规则（A3 只读集单点声明 + A1 免问规则按工作区落盘） | ARC | P1 | IN-PROGRESS @ b51ad6a/bca42ce/15a0ae6（只读集改为单点声明、`_subagentTools` 消失；本地与 MCP 工具共用同一判定顺序；`<support>/approvals.json` 按工作区分键 + 原子写；面板加"总是允许"、设置页加可撤销清单；38 例新测试全绿。会话级作用域与 deny 的创建入口**实施时砍掉**，理由写在 ADR 决策段。带 key 的真实链路已确认一半（2026-09-29 首跑：模型**自己选中**的 `bash ls` 与 `edit` 都走了 interrupt→resume，工具真跑、结果真回；ADR-0016 的两个 commit 顺带把审批后的结果投影修好了）。**allow/deny 规则的命中与"总是允许"的记住路径仍未在真链上验过**） | 2026-09-29 | [链接](adr/ADR-0012-arc-tool-contracts-and-approval-rules.md) |
| ADR-0013 | 忙时输入队列 + 中途转向（A4：FIFO 排队 / `guide` 经模型中间件注入本轮历史） | ARC | P1 | IN-PROGRESS @ ff85999/c916316/850be2a/480a1f6（S1–S4 已落：`queued_input.dart` + `TurnSource.guide/takeUndeliveredGuides`、`_GuideInjector` 模型钩子（spike probe G 实测 `{0:false, 1:true}`、快照含标记 1 个文件）、控制器 FIFO 单一排空点 + `stop` 停车、composer 两枚投递钮 + 可拖拽队列面板；21 例新测试，`flutter test` 得 `+781 -2`（仍是那两条既有失败）。余带 key 的真实链路走查；**已记录的偏离**：重启后那条转向不再显示为用户行，理由写在 ADR 后果段） | 2026-09-29 | [链接](adr/ADR-0013-arc-input-queue-and-steering.md) |
| ADR-0014 | 文件级 checkpoint + rewind（B1：`write`/`edit` 的 before 镜像 + 冲突闸门 + 卡片上的一枚回退 pill） | ARC | P1 | IN-PROGRESS @ 70e3206/f9782a7/2b0bc24/5988cfa/e385f58/0ec548d（S1/S2/S3 全落：`lib/model/checkpoint.dart` 值+接口、`lib/state/checkpoint_store.dart` 内容寻址镜像 + 冲突闸门 + 两种范围 + 预算淘汰、`write`/`edit` 在覆盖写之前取镜像并把 id 放进输出、`AppScope` 持令牌与 rewind 门面、`checkpoints/` 进备份清单、工具卡一枚 pill → 预览 → 二次确认 → 报告，9 个双语键；33 例新测试，`flutter test` 得 `+814 -2`（仍是那两条既有失败）。范围仍钉死在 `write`/`edit`，`bash`/MCP 的改动看不见。**九条实施偏差逐条记在 ADR 的"实施记录"段**（会话字段合一、令牌改由组合根铸造、`created` 也走指纹闸门、`RewindFile` 带理由、测试面合并、备份那行无测试等）。带 key 的真实链路首跑（2026-09-29）已验：**真模型 + 真审批之下，覆盖写之前的字节确实交给了 sink**，after 指纹与盘上一致。它同时抓出 pill 当轮不出现的缺陷（ADR-0016，已修）。该 ADR 原文"在 `dart run` 里验 rewind 被闸门挡住"这句被证伪并就地更正（`CheckpointStore` 是 ChangeNotifier，拖进 `dart:ui`），那半段由 `test/checkpoint_test.dart` 守。**余 app 内人工走查**（不重开会话，pill 当场出现）；那扇门本身曾不可运行，已由 ADR-0015 修好） | 2026-09-29 | [链接](adr/ADR-0014-arc-file-checkpoints-and-rewind.md) |
| ADR-0015 | 运行时脱离 Flutter 依赖，恢复 `dart run spike/runtime_smoke.dart` 这道验收门（并把边界做成第 6 条架构规则） | ARC | P1 | RESOLVED @ eb17573/c2b7c49/3af1317（`fs_revision` 从 `lib/state` 的 `ValueNotifier` 变成 `lib/model` 的纯 Dart 监听表，三个调用点形状不变、只换 import；`lib/genkit/tools.dart:31` 那条越层 import 随之消失）。实测证据：命令不带 key 也能编译并跑完离线路径（打印 `No API key set`）；规则 6 反向验过（临时往 genkit 加一条 flutter import → 退出码 1 并指名规则）；`flutter test` 仍 `+814 -2`，门禁输出 `architecture OK: 7 recorded, 0 new (122 files, 6 rules)`。本行闭环了下方原先那条"验收门不可运行"的观察 | 2026-09-29 | [链接](adr/ADR-0015-arc-runtime-flutter-free.md) |
| ADR-0016 | 审批通过的工具结果从不进直播投影：卡片停在 `running`，ADR-0014 的回退 pill 当轮不出现（只有重开会话后才在） | DEF | P1 | RESOLVED @ 815814e/ebcdd45/7712df1（第一次带 key 真跑 `spike/runtime_smoke.dart` 才暴露：genkit 的 `coreGenerate` 用 `_executeTools` 跑被重启的工具，把输出折进下一次模型请求，全程不 `sendChunk`；`AgentChat.messages` 又只累积模型消息，实测 `historyRefs=[]`，故取数处改成 `_agent.getSnapshot(snapshotId:).messages`——正是 `openSession` 读的同一份。修后同一条命令 `EXIT=0` 并打出 `tool <- ok … checkpoint: r0`。附带修第二条：`send()` 只挡 `_turn`，审批暂停时发新消息会在悬空 tool request 上追加历史，provider 回 400 变成一句 `Converting object to an encodable object failed: Instance of 'BadRequestException'`——app 里被 `isInputBlocked` 挡着，绕开控制器的调用者才会踩，而那个调用者就是冒烟脚本本身。冒烟脚本同时改：逐个应答审批、断言镜像与 id、失败置 `exitCode`）。修后同一条命令 `EXIT=0`，两条被批准的 ref 各自带回结果，`tool <- ok … {ok: true, path: notes.md, replacements: 1, checkpoint: r0}`；四道门禁同口径（format 0 changed / analyze `--fatal-infos` 干净 / `architecture OK: 7 recorded, 0 new` / `flutter test +814 -2` 仍是那两条既有失败）。**余在 app 里的人工走查**（不重开会话，pill 当场出现），与 ADR-0014 欠的那笔并成一次） | 2026-09-29 | [链接](adr/ADR-0016-def-approved-tool-result-never-streams.md) |
| ADR-0017 | 形状令牌契约：圆角按嵌套深度、4px 间距节奏、控件同高；选中态与 hover 必须是两个 token | ARC | P1 | IN-PROGRESS @ c2255c6（**实测 94 处 `Radius.circular(<字面量>)`、12 个不同值、`lib/theme/` 里形状令牌数为 0**。新建 `lib/theme/dsw_shape.dart`（**故意不进 `DswAlias`**：别名层每字段写两遍因为颜色随明暗变，圆角不变——塞进去就是造两个必须相等的字段，与 ADR-0014 同一条理由）。80 处原值即档位、保持不变；14 处离群值归到最近档，其中两处 `circular(1)` 是 2×2 状态点、`pill` 被 Flutter 夹到半边长后视觉完全一致。`interactiveSelected` 作为颜色令牌进别名层（light 0.10 / dark 0.12，hover 分别 0.06 / 0.08），`sidebar.dart` 选中分支换过去——**此前选中与 hover 同色，鼠标划过哪行哪行就像当前会话**。4 例新守卫：扫 `lib/ui/**` 的字面圆角必须为 0（**反向验过**：塞一个 `circular(7)` 就红）、档位递减律、4px 节奏、selected≠hover 两主题各一条。`contrast_check` 前后同为 9 对低于 4.5:1（ADR-0004 既有豁免面，无新增回归）。**余 S3 文本缩放**（单一 base scalar → TextTheme，闭环 ADR-0005 那条欠账）与逐屏取值复核） | 2026-09-30 | [链接](adr/ADR-0017-arc-shape-token-contract.md) |

> 2026-09-15 设计层审计（方法：design-review 插件手动审查模型）产出了完整证据链，见 [design-audit-2026-09.md](design-audit-2026-09.md)。阻断级/ majors 的处置归属：键盘无障碍（A1/A3）与表单控件缺口（C1）并入 ADR-0002 实施；A2（对比度）与文本缩放留下方观察表。

## ADR-0002 迁移进度（截至 2026-09-15）

- **riverpod**：Stage 1-3 完成——boot stores 经 `ProviderContainer` override（38a9949）、`AppScope` keepAlive provider（5d5aa75）、9 个 per-controller provider + read seams、`main.dart` 转纯 Consumer 树（178f941）。riverpod import 仅限 `main.dart` + `state/app_providers.dart`。
- **shadcn_ui**：Stage 4 主题桥 `theme/dsw_shad_bridge.dart`（DswAlias→ShadColorScheme，2511804）；Stage 5 CapsuleButton→ShadButton（45ddfb8）。
- **A1 键盘可达**：新增 `primitives/tappable.dart` 的 `DswHoverTap`（`FocusableActionDetector` + `MouseRegion` + `Semantics(button,onTap)`，零绘制），已收编块原语 4 + 私有图标按钮组 4 + tab strip 关闭/分屏 + settings 控件 7 + git/sidechat/diff/editor 叶按钮 + subagent 根卡。**`lib/ui` `GestureDetector` 60 → 35**；转换项均 Tab 可聚焦 / Enter·Space 激活 / VoiceOver 读 button·toggled。

## A1 键盘可达——已闭环（2026-09-16）

`lib/ui` 手写 `MouseRegion+GestureDetector` 交互件 **60 → 11**。**所有** 手写动作按钮/行现均 Tab 可聚焦、Enter·Space 激活、读屏可读（button/toggled/selected 语义）：capsule、4 块原语、4 私有图标按钮组、tab strip 关闭/分屏/`_TabChip`(附加式 FocusableActionDetector+tab 语义)、settings 全控件、git 文件/历史/提交按钮、diff 折叠+文件头、sidechat/chat/hero/file-tree/inspect/close、composer mention/command/image-chip/remove/send/retry、subagent 根卡/子卡/kill/关闭。共享件 `primitives/tappable.dart` 的 `DswHoverTap` 是唯一入口，`dsw_hover_tap_test.dart` 钉住指针/键盘/语义/右键四性。

**剩余 11 处全部合法、非动作件**：`app_frame`3 + `pane`2 + `free_window`2 + `split_view`1 = 分隔条拖拽/面板改尺寸/自由窗移动（本就不是可聚焦按钮）；`model_settings`1 = 设置遮罩点空白处关闭（Escape 已绑 `FocusScope` 提供键盘路径，全屏遮罩不该占 tab 停靠）；`tappable`1 = `DswHoverTap` 自身内部；`workbench_tab_bar`1 = `_TabChip` 的拖拽/右键菜单内部 `GestureDetector`（键盘激活已由其外层 `FocusableActionDetector` 提供）。

> A1 视为达成。仍建议 macOS（及现在可跑的 Windows）上人工走一遍 Full Keyboard Access + VoiceOver 复核观感，尤其 tab 重排与右键菜单未回归。

## 待立 ADR 的观察

以下是已经确认存在、但尚未走完"提案 → 批准"流程的问题。**修任何一个之前先补 ADR 并置 ACCEPTED**（纪律见 [README.md](README.md)）。

| 现象 | 证据 | 建议分类 | 建议优先级 |
| --- | --- | --- | --- |
| 测试套件不可在 Windows 移植（13/657 失败） | 2026-09-15 首次在本机跑全套：`shell_run_test` 8 个（写死 `/bin/bash`）、`editor_tab_test` 1 个（temp 目录删除遇 Windows 文件锁 errno 32）、`git_tab_test` 2 个与 `workbench_ui_test` 2 个（tab id / 断言用 POSIX 路径分隔符拼接 `support.path`）。全部先于 riverpod 迁移存在；其中 git_tab/workbench 4 个此前被 `trash_2` 编译错误掩盖（该错已修）。本机门禁为"相对基线零新增失败"。（2026-09-29 注：本行自 2026-09-16 起未在本机复跑；"macOS 全绿"也不再成立，见下一行。） | TST | P1 |
| macOS 开发机上 2 个既有失败（+699 -2） | 2026-09-29 在当前 macOS(Darwin arm64) 开发机首跑 `flutter test`：① `test/app_scope_test.dart:52` 期望 `support.path` 为 `/var/folders/...`，实得 `/private/var/folders/...`——macOS 的 `systemTemp` 软链接在真实路径解析后被规范化，断言比的是字符串而非规范化后的路径；② `test/plan_workspace_test.dart:100` `find.text('notes')` 命中 2 个（目录行本身 + 笔记行的"folder 作第二行"标签，`plan_workspace.dart:698-720`），断言 `findsOneWidget` 因此过不了。**两条都与本轮配置改动无关**（`git diff --stat -- test lib` 为空），且均为 HEAD `8a2b8f2` 上即可复现的既有状态；此前 Windows 行记的 13 个失败与本机器这 2 个是两套平台各自的表现 | TST | P1 |
| 无文本缩放适配 | `textScaler|textScaleFactor` 全仓库 0 处；disclosure_row 等自绘件固定高度（24px header），macOS 辅助功能放大文本时裁切 | DEF | P2 |
| `README.md` 仍是 Flutter 包模板 | `README.md` 与 `CHANGELOG.md` 通篇 `TODO:`（模板注释未清），无一句项目说明；新人和代理拿它当入口会拿到零信息。代理入口是 `AGENTS.md`，但根 README 是 pub/git 默认展示面 | DEBT | P2 |
| macOS 分发缺口 | `CODE_SIGN_IDENTITY = "-"`、无 `DEVELOPMENT_TEAM`、未配 hardened runtime / `notarytool` 公证 → 产物只能本机运行；且 `.gitignore` 缺 `*.p12`/`*.cer`/`*.mobileprovision`，一旦有人放证书就会入库 | CFG | P1（若要对外发布） |
| 版本仍 0.0.1，且 CI 不覆盖签名公证 | `pubspec.yaml` 仍 `version: 0.0.1`（`CHANGELOG.md` 也只有一句 TODO）。CI **已存在**（`d09b92d`）：`pr-check.yml` 跑 format + `dart analyze --fatal-infos` + `flutter test`，`build.yml` 是 `workflow_dispatch` 三平台出包、可选发 GitHub Release（dmg/zip/tar）。但两个工作流都不含 `codesign` / `notarytool` / secrets，所以 Release 产物依旧 ad-hoc——"CI 绿"与"可对外分发"是两件事。另注意版本基线现有两处真值（`pubspec.yaml` 与两个 yml 的 `FLUTTER_VERSION`） | CFG | P2 |
| workbench store 防抖测试负载下 flaky | `test/workbench_controller_test.dart` 的 "store collapses a burst into the last value" 在 `flutter test` 全套并发下偶发失败（2026-09-16 遇到一次，单跑 3/3 通过、重跑全套即消失）。debounce/计时对调度敏感，非确定性 | TST | P2 |
| ADR-0005 S4 未接线的偏好（仅持久化意图） | `AppSettings` 已存 `previewMode`/`fontFamily`/`fontSize`/`interfaceStyle`，外观节也能改并落盘，但渲染端忽略：`conversationWidth`+`expandToolCalls` 已经 `ui/appearance_scope.dart` 生效，其余三项未接。`previewMode` 需先定"生成文件预览流"规格且"新窗口"要多窗口；正文字体族/字号需真正作用于 conversation 排版；`interfaceStyle` 的 glass/classic/parchment 各需自己的 DswAlias 调色板（见 `app_settings.dart` 内注释） | DEBT | P2 |

## 已闭环

| 编号 | 标题 | 分类 | 闭环方式 | 日期 |
| --- | --- | --- | --- | --- |
| — | AI 代理配置（`.qoder`/`.trae`/`AGENTS.md`）内容全属另一项目 | CFG | 按本仓库事实重写三份规则与入口文档，并裁掉 7 个与现状冲突的 skill | 2026-09-15 |
| — | 设置页切主题/中英文失效、首页选文件夹后状态不更新 | DEF | riverpod read-seam 误用 `ref.notifyListeners()`：函数式 provider 下它只重通知**旧缓存值**、不重跑 body，故 store 保存传不到读者。改 `ref.invalidateSelf()`（重跑 body 返回新值）。`state/app_providers.dart`。新增 `test/app_providers_test.dart` 用真 store 断言 store→provider 传播（正是能抓住此 bug 的守卫——旧的 widget 测试直接构造 controller、且没有 store→provider 传播断言，故漏网）。本机 `flutter run -d windows` 复验中 | 2026-09-16 |
| — | ADR-0006 落地后追加审计 7 项发现（F1 快捷菜单键盘不可达 / F2 OverlayEntry 无属主泄漏 / F3 无 Escape / F4 触发器语义标签错 / F5 收起栏菜单不可达 / F6 全屏设置内容左贴 / F7 回调内 ref 惯例） | DEF·A11Y | 同批修复：菜单芯片/行全部 `DswHoverTap` 化（键盘激活 + `Semantics(button,toggled)` + hover 洗色）、菜单打开即 `requestFocus`（锚点节点）+ Escape 绑定关闭、entry 归 sidebar State 持有（dispose/打开设置前移除）、新 i18n 键 `quickPreferences`、rail 头像同触发器、设置内容列 `Center` 化、`ref.read` 惯例。测试 +2（键盘激活 / Escape）。逐项证据与修复对照见 [audit-adr-0006-followup.md](audit-adr-0006-followup.md) | 2026-09-16 |
| — | ADR-0009 的指令注入把会话标题与重开后的用户气泡都变成了模型读的散文（每条会话都叫 `<project-instructions> …`） | DEF | `Message.text` 会**拼上所有 text part**，而注入块与 `@` 引用就是同一条 user 消息里的独立 part。新增 `_userWords()` 只取用户自己的话，`sessionTitle()`（原 `_titleOf`，为可测改成公开静态，沿 `projectMessages` 的先例）与 `projectMessages` 的 user 分支**同时**改过去——只修标题会留下重开会话时把整块指令画成用户发言的姊妹缺陷。两个标记提为常量（`instructionsOpenTag`、`workspaceReferenceTag`）并由 `isInjectedPart()` 单点判定。2 例新测试（含**反向验证**：把修复改回去会红），`spike/runtime_smoke.dart` 多一条真链守卫（临时工作区里放一个 AGENTS.md，断言没有会话被注入块命名） | 2026-09-29 |
| — | ADR-0005 S4 的 `expandToolCalls` 在 `initState` 里读 `AppearanceScope`，只要真把 scope 挂到工具卡上就触发 Flutter 断言 | DEF | `dependOnInheritedWidgetOfExactType` 在 State 锁定期内建立继承依赖是断言级错误，而 `_ToolCardState.initState` 正是这么写的——app 里每张工具卡都在 `AppearanceScope` 之下。改到 `didChangeDependencies` 并加"一次挂载只读一次"的守卫（后来的偏好变化不去动读者已经展开/折叠过的卡片）。由 ADR-0014 S3 的 `test/rewind_pill_test.dart` 首次暴露：它是第一个把工具卡渲染在 `AppearanceScope` 之下的测试，此前的测试都不挂那层。commit `e385f58` | 2026-09-29 |

> riverpod 坑（记入 memory/规则）：把 `ChangeNotifier`/`Listenable` 桥成**函数式 provider** 时，值同步用 `ref.invalidateSelf()`，**不是** `ref.notifyListeners()`（后者不重跑函数式 body）。`main.dart` 迁纯 Consumer 树时删掉的 `ListenableBuilder(settings/prefs)` 靠这两个 read-seam 顶替，一旦用错 API 就静默失效、且不进运行日志（非异常），只能真机点出来。

> 这几行都不占 ADR 编号：均为一次性纠正或在途 bug 修复，无遗留状态。若日后再现同类代理配置漂移或迁移回归，按 README 流程立 ADR。
