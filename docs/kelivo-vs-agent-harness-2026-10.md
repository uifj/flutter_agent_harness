# Kelivo × PlanStar 全功能面对比与移植评估

- **日期**: 2026-10-04（对比基线：本项目 HEAD `9131d7b`，本机门禁 `flutter test` = `+1340 -2`）
- **对比对象**: `_archive_project/kelivo`（Kelivo master @ `0cfc718`，2026-04-20，pubspec `1.3.0+79`，**AGPL-3.0**，codeload tarball 下载并按 commit 内容验证过 pin——盘上代码含该提交的 `bitsdojo_window` Windows 注册）
- **用途**: 决定把 Kelivo 的哪些功能点、按钮、能力合并进本项目。**本文只做评估，不含代码改动**；任何移植动作先按 `docs/README.md` 立 ADR 并置 ACCEPTED。
- **证据口径**: Kelivo 侧行号来自本地归档（`.gitignore` 已排除 `_archive_project/`，新 clone 没有它，行号只对持有归档的机器有效）；本仓库侧数字为现场命令输出。调查方法与诚实边界见 §9。

---

## 1. 一页结论

**规模差 ~8.9 倍，产品是两个物种；它的"agent 内核"比我们浅，"客户端功能密度"比我们宽，而它恰好把 ZCode 评估里几个 B/C 组缺口在 Flutter 上做了参考实现。**

| | PlanStar（本仓库） | Kelivo |
| --- | --- | --- |
| 源文件 | `lib/` 165 个 `.dart` | **864 个** `.dart` |
| 代码行 | ~54.6k（含 l10n 1.5k） | **~487.5k**（含 l10n 72.2k；实码 ~415k） |
| 产品形态 | 桌面 agent 工作台（企划 + 代理双模式，三桌面） | 跨五端 LLM 聊天客户端（Android/iOS/macOS/Windows/Linux + HarmonyOS 独立仓） |
| 运行时 | Google Genkit（Dart 0.x），只活在 `lib/genkit/` | **自研 HTTP/SSE 栈**（dio 降级为 transport）+ 自研工具循环 |
| 状态 | riverpod 3.2.1 注解 + ChangeNotifier | `provider` 包 + ChangeNotifier 单例服务 |
| 持久化 | JSON sidecar（settings/prefs/workbench/sessions/plan_space，手写 toJson） | **drift/SQLite 单库 29 张表**（含 FTS5 虚拟表与触发器）+ hive 仅剩迁移 |
| 依赖策略 | 禁新增依赖除非 DEP ADR | vendored 5 个包（gpt_markdown/mcp_client/flutter_tts/terminal_view/tray_manager fork） |
| i18n | en/zh 双字典 + parity 守卫 | en/zh/zh-Hans/zh-Hant 4 arb，~3787 条/语言 |
| 测试 | 102 个 `*_test.dart`（~25k 行） | 有 test/ 与 integration_test/，密度不明（未逐个数） |
| 决策记录 | ADR-0001…0055 + 登记表 | AGENTS.md 有结构规范，无 ADR 体系 |

三条必须先说的反直觉结论：

1. **许可反转了 ZCode 那次的前提**。ZCode 是 Apache-2.0，当时还写了"若确实要抄代码，先立 DEP/ARC ADR 并写明归属方案"（`zcode-vs-agent-harness-2026-09.md` §8.9）；Kelivo 是 **AGPL-3.0**——复制任何一段源码都会把整个仓库拖进 AGPL 传染，而且**提示词文本、UI 文案、图标同属"作品"**。所以对 Kelivo 只存在一条路线：**设计思想移植，连"翻译式照抄文案"都不做**。这份文档里所有"采纳"判定的含义都是"按我们的架构重写"，不是"搬文件"。
2. **agent 内核我们更深**。Kelivo 的工具循环是 `while (calls.isNotEmpty)`（`lib/core/services/api/generation/tool_loop_runner.dart:95-133`）——**无最大轮数、无 token 预算、无子 agent、无 hooks**；审批是内存 Completer 表 + 一个持久化进会话 extras 的 `allowAll` 布尔（`workspace_tool_ui.dart:1109-1138`），**没有规则式 allowlist**（我们 ADR-0012 的 approvals.json 按工作区分键是它没有的）；没有 checkpoint/rewind（它的"多版本回复"是消息级不是文件级）；没有中途转向。它也没有子 agent 委托、plan 工具、todo 工具这些我们已有的东西。
3. **它是 ZCode 评估 B/C 组缺口的现成 Flutter 参考**。ask-user 工具、定时任务、多 Key 负载均衡、每供应商代理、FTS5 全局搜索、请求/上下文日志、备份恢复流水线——这些 ZCode 有而我们没有的项，Kelivo 全部在 Dart/Flutter 里实现过一遍，等于给 ZCode 路线图的对应条目补了"落进我们技术栈长什么样"的证据。见 §6 交叉对照。

---

## 2. 定位与技术栈

| 维度 | Kelivo（证据） | 本仓库现状 | 判定 |
| --- | --- | --- | --- |
| 状态管理 | `provider` + ChangeNotifier，超大盘门面（`HomePageController` 3000 行外观 + `ChatService` 4500 行业务 + `ChatDatabaseRepository` 8231 行存储），重建靠 `context.select` 字段级订阅 | riverpod 19 provider + `lib/state` 控制器，159 处 `textScalerOf` 同级精读纪律 | 各成体系，不搬 |
| 数据库 | drift 单库 29 表 + FTS5 + 触发器 + `GenerationRunRows` 生成状态机 + `TombstoneRows` 跨设备墓碑（`lib/core/database/app_database.dart:37-725`，schemaVersion 3） | 每域一份 JSON sidecar，原子写 | sqlite 决策维持 ZCode C1 口径：除非会话搜索/量级成为实测瓶颈 |
| HTTP 层 | dio 5.9.2 包成 `http.BaseClient`（`DioHttpClient`），SOCKS5 经 `socks5_proxy` 的 `connectionFactory` + DNS 预解析缓存（`lib/core/services/network/dio_http_client.dart:92-153`），一套客户端服务聊天/OAuth/余额/模型列表四条链 | genkit 供应商栈 + `http` 升格（ADR-0045 PE） | transport 思想可参考，不搬实现 |
| 桌面/手机分叉 | 同一棵 HomePage 树 + `PlatformUtils.isDesktop` 运行时分支；桌面 = 桌面壳（nav rail + IndexedStack）嵌同一个聊天页 | 桌面-only，五区外壳 | 无需分叉层，不搬 |
| 渲染 | vendored gpt_markdown + **自研增量渲染**（`IncrementalMarkdownDocument` 按空行切块只重扫尾部 + 已完成子树复用，`lib/shared/widgets/incremental_markdown_document.dart:27-127`） | gpt_markdown（pub 直依赖）+ re_editor | 增量渲染思想值得吸收（流式长回答的重建成本），B |

---

## 3. 功能面逐区对比（核心）

> 判定三档：**采纳**（值得做进我们的架构，先立 ADR）/ **参考**（吸收思想不照形状）/ **不搬**（平台/定位/架构冲突）。括号里的 A/B/C 对应 §7 路线图分组。

### 3.1 模型与供应商

| Kelivo（证据） | 本仓库现状 | 判定 |
| --- | --- | --- |
| 16 家预置供应商 + 自定义 OpenAI 兼容 + 账号登录（ChatGPT/Codex、Grok、Kimi、Claude 真 OAuth+PKCE：loopback 回调 / device code 两式，`lib/core/models/provider_oauth.dart:3-53`、`lib/core/services/auth/oauth_callback_io.dart:14-48`） | `known_models` 目录 + `/v1/models` 拉取；形态② 自家账号体系（ADR-0045 PE/PG） | **不搬**账号登录（与形态②冲突）；OAuth loopback/refresh 的技术形状留档，将来接自建后端可用 |
| 模型能力四源合成：`ModelSpecResolver` 优先级 override > catalog > guess > vendor，**字段级溯源** `Map<ModelSpecField, SpecSource>`，memo 按 catalog 版本失效（`lib/core/services/model_spec/model_spec_resolver.dart:16,176-215`）；内置 models.dev 217 家目录快照、24h 自动刷新（`assets/model_catalog/models_dev.json`） | `known_models` 静态表（含 `modelAcceptsImages`，ADR-0010） | **参考→采纳**（B）：能力矩阵的"四源 + 溯源 + 可远程刷新"是把静态表做活的正确形状 |
| 多 Key：轮询/优先级/最少使用/随机 + 失败冷却 5 分钟 + 批量测试（`lib/core/services/api_key_manager.dart:19-100`）。**注意：`updateKeyStatus`/`recordKeyUsage` 全库无调用方——"请求失败自动标记异常 Key"是死代码**，实际标记只发生在手动批量测试 | 单 key + keychain 槽位（ADR-0045 PF savedProviders） | **采纳**（B1）：多供应商地址簿落地后自然需要；照搬必须把执行层补上或砍掉超前字段（`maxRequestsPerMinute` 也无限流实现） |
| 每供应商 HTTP/SOCKS5 代理（`resolveProxyType` 只认 http/socks5，`settings_provider.dart:6166-6174`） | 无 | **采纳**（B1，需 DEP ADR：`socks5_proxy`） |
| 流式重试律：**仅当内层流一个元素都没吐出才重试**（`yielded` 标志，`lib/core/services/api/stream/retrying_stream.dart:37-46`）+ 可重试状态码表 `{408,425,429,500,502,503,504,529}` + 中英文限流关键字 + stopKeywords（余额不足/unauthorized 不重试）（`auto_retry_options.dart:1-67`） | 无重试层 | **采纳**（A，零新依赖）："首 chunk 前才重试"是防重复输出的正确不变量 |
| 自定义请求头/体三级合并（供应商/模型/助手，值做类型推断而非模板变量，`lib/core/services/custom_request_merger.dart:6-95`） | 无 | **参考**（C）：我们工具 schema 走 schemantic，请求定制等真实需求出现再做 |
| reasoning 方言层：四 transport（chatCompletions/responses/anthropicMessages/geminiGenerateContent）各自的 thinking 参数映射 + 档位→budget 阶梯（`lib/core/services/api/reasoning/reasoning_dialects.dart:10-13`） | 无 reasoning effort 控制 | **采纳**（B4，与 ZCode B4 同项，Kelivo 给了 Dart 参考） |
| 余额查询（可配路径表达式 `a.b[0].c` 与 `X - Y`，`provider_balance_service.dart:12-17`） | 无 | **不搬**（C）：中转站特化功能 |
| Claude prompt cache 开关 + OpenAI `prompt_cache_key` | 无 | **参考**（B）：与 B8 记忆注入的"稳定注入保缓存命中"同一件事的 provider 侧 |

### 3.2 对话与消息

| Kelivo（证据） | 本仓库现状 | 判定 |
| --- | --- | --- |
| 多版本回复：regenerate 保留旧版本，版本组 = `groupId`+`version`（`core/models/chat_message.dart:69-74`），每会话记忆所选版本，`_BranchSelector` "1/N" 切换器（`chat_message_widget.dart:3941-4009`）；用户消息编辑也存新版本 | 无；重新生成会怎样需现场确认 | **采纳**（A4）：消费级聊天里被验证最多的功能之一 |
| fork：从任意消息分叉出新会话（`chat_service.dart:3646,3719`） | 无 | **参考**（B，与 ADR-0014 rewind 同族："这一步之前的世界还在"） |
| 临时对话：内存集合不落库、退出即弃、不参与搜索（`chat_service.dart:114-138,306`） | 无 | **采纳**（A，小件） |
| **上下文压缩** = LLM 摘要 + 建新对话，四种裁剪模式 start/recent/unlimited/keepRecent（`home_view_model.dart:1188-1340`），压缩模型回退链 | 无（只有 `read_window.dart` 的读窗口截断） | **采纳**（A2★，与 ZCode B2 同项）：长会话爆窗是硬缺口 |
| 聊天建议：流结束后 JSON 协议生成 ≤3 条（`chat_suggestion_service.dart:16-50`） | 无 | **参考**（C） |
| 按对话覆盖模型/系统提示词（override 不写穿到助手，`chat_input_section.dart:142-177`） | 新会话无 per-conversation override | **参考**（B） |
| 全局搜索：drift FTS5 虚拟表 + 触发器，**流式 checkpoint 期间延迟索引**（`is_streaming` 翻 0 才入 FTS，`chat_database_repository.dart:4099-4191`）+ Dart 侧评分 | 无 | **采纳**（B5，前置 = sqlite DEP ADR）：延迟索引这条是防流式写风暴的关键细节 |
| 消息导出：单条/批量 → Markdown/TXT/图片（RepaintBoundary 离屏切片拼接，`message_export_sheet.dart:906`） | 无 | **采纳**（A5，小件） |
| 迷你地图：按问答对排列的 popover（桌面）/带防抖搜索的 sheet（手机） | 无 | **参考**（C）：依赖虚拟滚动先行 |
| 虚拟滚动 super_sliver_list + 自定义高度估算 + `ChatAutoFollowScrollController` 布局期钉底零闪烁（`scroll_controller.dart:12-60`） | `ListView.builder`（ZCode 对比已记"长会话向上滚会被流式内容顶飞"差距） | **参考→采纳**（B，与 ZCode §3 会话时间轴同项合并评估） |
| 思考段与工具调用按发生顺序排成一条竖直时间线（`timeline_projection.dart` + `_ChainOfThoughtCard`，思考步骤带耗时、可折叠） | 工具卡单枚一卡；无时间线轴 | **参考**（B）：我们工具数 9+MCP，投影层有 TurnEvent，加一条时间线轴是投影侧改动 |
| shell 工具卡实时 tail：128KB 环形缓冲 + 50ms 节流 notify（`tool_run_registry.dart:11-126`）；长输出 offload 落盘、回给模型的 JSON 带 `output_file`（`workspace_tools_service.dart:858-883`） | bash 结果一次性返回；终端 tab 有实时流 | **参考**（B）：offload 律对 bash 长输出适用 |
| 渲染：增量 markdown（见 §2）+ Mermaid WebView 可导出 PNG + HTML 消息渲染预览 | gpt_markdown（LaTeX+Mermaid 已接） | **参考**（C）：HTML 预览是消费功能 |

### 3.3 工具与工作区

| Kelivo（证据） | 本仓库现状 | 判定 |
| --- | --- | --- |
| 7+1 工具（shell/read_file/**view_image**/write_file/edit_file/list_dir/glob/grep；view_image 仅在模型支持图像输入时注入，`tool_handler_service.dart:323-337`）；edit_file 三级容错匹配 exact→line_trimmed→block_anchor（`edit_matchers.dart:3-9`）；shell 无轮数护栏、`sh -lc` 一次一跳 | 9 工具（read/write/edit/glob/grep/bash + plan + todo_write + 子 agent 委托） | **持平偏好**：我们多子 agent/plan；view_image 的"能力门控注入"与 ADR-0010 同律；容错匹配可对照我们的 `text_edit` |
| 审批：内存 Completer 按 `(conversationId, toolCallId)` 键控；"本次会话全部允许" = `allowAll` 布尔持久化进**会话 extras**（`workspace_binding.dart:5,37`）；**无规则式 allowlist** | ADR-0012：规则式 approvals.json 按工作区落盘 + 免问规则 | **我们更深**；可反向吸收一格：会话级临时放行挂会话而非全局 |
| 环境变量：全局共享 + 注入 shell/MCP stdio + **输出脱敏**——privacyMode 下把 ≥5 字符的值按长度降序拼正则，仅对回给模型的工具文本替换 `[REDACTED]`（JSON 先解码再匹配防转义，`environment_output_redactor.dart:11-76`） | 无 | **采纳**（B2）：脱敏律是安全件，形状可直接重写 |
| 技能：SKILL.md 目录 + **渐进披露**——prompt 只注入 `<available_skills>` 名录（cap 20、描述截 200 字符、按使用次数排序），模型需自行 `read_file /skills/<id>/SKILL.md`，读到自动计数（`skills_prompt.dart:4-43`、`workspace_tools_service.dart:1609-1631`）；导入支持粘贴/md/zip（带 zip-slip 防护 `:491-497`）/GitHub 链接；内置 skill-creator 元技能（教模型用 write_file 造新技能） | genkit_middleware `skills()` 全量注入 `<skills>` 段（`agent_runtime.dart:81-82,639-643,786`） | **判定修正（2026-10-04 现场复核）**：genkit_middleware 0.6.1 的 `skills()` **本来就是渐进披露形状**——prompt 只注入 `<skills>` 名录（`skills_middleware.dart:195-203`），内容由 `use_skill` 工具按需读（`:100-124`）。评估时的"全量注入"是误读；本项无需实施，名额录/按需读的现状即目标形状 |
| MCP：Streamable HTTP/SSE/STDIO 三 transport + 完整 OAuth（发现/DCR/PKCE/刷新/403 scope 步进）+ Claude 式 JSON 导入 + 按工具审批 + 内置 fetch 进程内服务器（`mcp_provider.dart:1416-1533`、`kelivo_fetch_server.dart`） | genkit_mcp host（按 settings 建，`mcp/<name>:tool/<tool>` 命名） | **参考**：transport/OAuth 广度受 genkit_mcp 包能力约束（ZCode 对比已记"升 genkit 前先核 spike FINDINGS"）；内置 fetch 的 in-memory 传输思路可留档 |
| **ask_user 工具**：`ask_user_input_v0`，questions 1–4 条、single/multi 选择题 ≤4 选项、UI 自动附加 Other/Skip，调用即挂起（Completer），回答以 `ask_user_answer` 回填继续（`local_tools_service.dart:19,723-765`、`ask_user_interaction_service.dart:129-268`） | 无；有 plan_review_panel（计划待审接管 composer）与审批中断两块同族先例 | **采纳**（A1★，与 ZCode 的 AskUserQuestion 判定互相印证）：我们已有 interrupt→resume 协议，复用同一通道 |
| 设备工具（日历/定位/健康/屏显时间/无障碍 phone_control）、PRoot/iSH 手机沙盒、外部文件夹挂载 | 无，桌面-only | **不搬**（平台定位排除） |
| 定时任务：hour/minute+weekdays（非完整 cron）、三模式 newChat/followUp/regenerate、run 记录含 200 字预览、无人值守遇审批/待答直接 `user_interaction_required` 失败、桌面 = `Timer.periodic` 轮询仅应用存活时（`scheduled_task.dart:9-226`、`desktop_scheduled_tasks.dart:13,99`、`scheduled_task_runner.dart:21-183`） | 无 | **采纳**（B7，与 ZCode B6 同项）：桌面侧形状与我们一致（单进程 Timer + 持久化任务表即可） |

### 3.4 记忆与上下文工程

| Kelivo（证据） | 本仓库现状 | 判定 |
| --- | --- | --- |
| **长期记忆四段流水线**：Gatekeeper（小模型判值得记吗）→ Extract（四类：identity/workflow/voice/instruction，只从用户话里提取）→ Smart Add（分词检索 top5 候选 + LLM 判 NEW/MERGE/CONFLICT/SKIP）→ Profile Distiller（身份记忆蒸馏成 7 字段结构化画像）（`lib/core/services/memory/` 13 个文件）；水位线 `lastMemoryExtractedOrder` + 失败 ≥3 次熔断 + 单并发队列 + **MemoryTraceRecorder 全程埋点可逐步查看** | 无 | **参考→采纳**（B8，大件）：两种记忆形态要先拍板——ZCode 是"一事实一文件"的文件型，Kelivo 是"对话结束后台整理"的提取型；提取型更贴合我们的会话形态。**最值得抄的工程点**：注入以快照冻结进用户消息 + sha256 门控变更 + superseded 前缀发出前剥离而不回写（`memory_block_builder.dart:114-118`、`message_builder_service.dart:1720-1734`），每一步都为 provider prompt cache 让路。边界：检索纯词面（无 embedding），中文召回受分词质量限制 |
| 世界书：关键词/正则触发 + scanDepth + sticky/cooldown/delay 计时态 + 5 种注入位置 + atDepth（`world_book.dart:60-95`、`world_book_activation.dart:12-94`） | 无 | **不搬**（C）：SillyTavern roleplay 语义与 agent harness 定位不符；计时激活态用会话 extras 存、历史重写自动失效的机制留档 |
| 指令注入：可复用提示词卡片按分组管理，发送前 join 进 system；内置"学习模式"种子（`instruction_injection_store.dart:70`） | workspace AGENTS.md 注入（ADR-0009，纯 Dart） | **采纳**（A6，小件）：同一注入通道上多一种"用户手造卡"，与 ADR-0009 合并设计 |
| 快捷短语：全局/按助手两套，插入光标处不直接发送（`home_page_controller.dart:2491-2515`） | 无 | **采纳**（A7，小件） |
| 正则替换三目标 persist/visual/send（`assistant_regex.dart:7-58`） | 无 | **不搬**（C）：roleplay 向 |
| 预设消息：新会话按序写成真实历史消息 | 无 | **不搬**（C） |
| 内置工具描述可改：`ToolSchemaOverrides` 只认内置白名单、支持参数级描述路径、MCP 明确排除（`tool_schema_overrides.dart:32-104`） | 无 | **参考**（B 小）：与 ADR-0045 快捷键注册表同族"一处定义多处读" |
| 上下文 token 分桶归因：每段注入打 `ContextSegmentTags`（system/injections/history/memory/worldBook/skills/workspace/search/mcpTools，`context_assembly.dart:139-162`） | usage 台账只记 token 总量（ADR-0045 PC） | **参考→采纳**（B 小）：台账的自然延伸，压缩（A2）也靠它定阈值 |

### 3.5 数据与备份

| Kelivo（证据） | 本仓库现状 | 判定 |
| --- | --- | --- |
| 备份三通道：WebDAV（手写 PROPFIND/MKCOL/流式 PUT + 取消删半截文件）、S3（**自研 SigV4** 兼容 R2）、本地 zip（自研流式 writer 防 OOM）（`data_sync.dart:438,1490,3558`、`s3_client.dart:14`） | 本地 zip（archive 包）+ zip-slip 防护（ADR-0042） | **采纳**（B9，需 DEP/SEC 评估）：形态②有自家后端后 WebDAV/S3 是"不带后端的用户"的兜底 |
| 恢复语义：overwrite = 清单校验→staging→**把当前活库打成 previous bundle**→原子 cutover→失败自动回滚→receipt→冷启动收尾（`restore_cutover_executor.dart:51`）；merge = 设置合并/聊天 SQL 合并/文件 additive 三分 | `restoreBackup` 先遍历验名再写（ADR-0042） | **参考**：cutover 前先留可回滚副本这一思想，可直接抄进现有 restore（"恢复前先备份"） |
| 自动本地快照：启动 8s/resume 3s 评估、库大小自适应频率（≥1GB 每 7 天 / ≥200MB 每 3 天 / 否则每天）、GFS-lite 槽位（最近 3 + 上周 1 + 上月 1）、库+wal 指纹未变跳过、生成中跳过（`local_snapshot_scheduler.dart:17-28`、`local_snapshot_retention.dart:38-48`） | 无 | **采纳**（B9 后半）：把"不会把用户数据备份没了"当设计目标 |
| 诊断三件套：请求日志 JSONL（base64 elide、单行 1MB 上限）+ **上下文日志（实际发给模型的完整 prompt 快照 + token 估计）** + 存储分类明细可清（`request_logger.dart:9`、`context_logger.dart:11`、`storage_usage_service.dart:110`） | usage 台账 + crash 归档（ADR-0045 PC） | **采纳**（A3★）：agent 调试刚需，与台账同族，纯本地零风险 |
| 统计：热力图 364 天 + 按 provider 分桶趋势 + 模型/助手/话题三组排行 + 按定价表估算成本 | usage 台账 + 设置面板 | **参考**（B）：UI 面排在台账之后 |
| 导入 Cherry Studio/Chatbox（62KB/47KB importer） | 无 | **不搬**（C） |

### 3.6 桌面壳

| Kelivo（证据） | 本仓库现状 | 判定 |
| --- | --- | --- |
| 窗口：尺寸位置恢复防抖落盘；**macOS 完全交原生 NSWindow autosave**（Dart 侧不 setPosition，`desktop_window_controller.dart:76-84`）；Windows DPI 感知 + 显示枚举防越界；min 960×640 | window_manager 已接；恢复策略未成文 | **参考**（A 小）：macOS autosave 这条判断直接可用（与我们 ADR-0019 的"别和系统 chrome 打架"同律）；**最小窗口尺寸**顺带回应登记表窄窗观察项 |
| 托盘：菜单仅显示/退出、左键唤起右键菜单、**关闭即最小化到托盘**（`setPreventClose`）、退出前 flush 写队列 2s 超时（`desktop_tray_controller.dart:58-60,134-167`） | tray_service 已有（本批重命名中） | **参考**：preventClose + 退出 flush 两个细节可对照 |
| 快捷键：7 动作注册表持久化 + 系统级"显示/隐藏应用"（`HotKeyScope.system`，`hotkey_provider.dart:215`）+ HotkeyEventBus→ChatActionBus 三级解耦 | hotkey_service 3 热键 + ADR-0045 PC 注册表已落（录制 UI 待） | **持平**：解耦形状可对照；系统级显隐热键补进注册表 |
| 多栏：64px nav rail + IndexedStack 四页**常驻不销毁**（切页不断流，`desktop_home_page.dart:225-245`） | 五区外壳 + workbench 双树 | **参考**：流式中切页不断流对"托盘隐藏时继续跑"（ADR-0045 PH 注意力唤起）是同一命题 |
| 右键菜单 anchored + 边界翻转 + 记住最后坐标；毛玻璃 popover（BackdropFilter） | `DswHoverTap` 右键四性 + popup menu 主题（ADR-0028） | 已有等价，不搬（毛玻璃与 dsw 令牌体系冲突） |
| 主题：Material 3 + Android 动态取色 + JSON 自定义主题 + 气泡毛玻璃/壁纸/渐变 + Google Fonts 下载 | dsw 令牌 + shad 采纳（ADR-0036） | **不搬**：方向性冲突（我们有一套自持的令牌/对比度门禁体系） |
| i18n 4 语言 ~3787 条/语言 | en/zh 双字典 + parity 守卫 | 持平；zh-Hant 可作远期选项 |

---

## 4. 与 ZCode 评估的交叉对照

Kelivo 对 `docs/zcode-vs-agent-harness-2026-09.md` 路线图的影响——**B/C 组里 6 个"没有 Flutter 参考"的条目现在有了**：

| ZCode 路线图项 | ZCode 时的判定 | Kelivo 给出的 Flutter 参考 | 修订后的结论 |
| --- | --- | --- | --- |
| AskUserQuestion（§4 内置工具缺项） | 缺口 | `ask_user_input_v0` 全套（挂起/答题卡/回填/取消/定时任务遇待答判失败） | A1★ 证据齐了，可行性和交互形状都有先例 |
| B2 上下文压缩 | 缺口 | `compressContext` 四模式 + 模型回退链 | 可行性确认；熔断口径用 ZCode 的，裁剪模式用 Kelivo 的 |
| B4 reasoning effort + usage | 缺口 | reasoning 四方言 + budget 阶梯 + usage 三分桶 | Dart 实现直接可读 |
| B6 定时自动化 | "值得搬（单进程 Timer 即可）" | scheduled_tasks 全套含 run 记录与无人值守失败语义 | 形状确认：我们不需要原生闹钟那半 |
| B7 模型 IO 轨迹检视器 | "落 JSONL + 一个 tab" | 请求日志 + 上下文日志 + 三 Tab 查看器 | 更轻的形状：不用解析第三方格式，自己落自己读 |
| C1 sqlite 任务索引 | "除非实测瓶颈" | FTS5 全局搜索 + 触发器 + 流式延迟索引 | 价值场景被证明（会话全文搜索），但仍按 DEP ADR 走 |
| B1 checkpoint/rewind | "产品级差距" | **Kelivo 没有**（多版本回复是消息级，不碰文件系统） | 我们仍领先；"消息多版本"（A4）是消息级同族，可先做 |
| A1 审批规则 | "缺口，优先级最高" | Kelivo 也只有会话级 allowAll 布尔，无规则式 | ADR-0012 已落地，判定维持 |
| A2 队列/转向 | — | Kelivo 有排队 banner（`_QueuedInputBanner`）无转向 | ADR-0013 已落地，判定维持 |
| 记忆（§4 记忆文件） | 文件型（一事实一文件） | 提取型四段流水线 | **新决策点**：两种形态取其一（或并存），见 B8 |

---

## 5. 反向清单：它没有而我们有/它有而我们已对齐的

防止"参考项目什么都好"的错觉：

- **Kelivo 没有**：子 agent 委托、plan/todo 工具、文件级 checkpoint/rewind、审批规则式 allowlist、中途转向、工作区 AGENTS.md 指令发现（它有 workspace prompt 块但不读 AGENTS.md 文件）、架构门禁、ADR 体系、企业化生产链（keychain/quarantine/崩溃归档——它 API key 明文存 SQLite）。
- **已对齐**：MCP host、skills 目录、托盘/热键/窗口管理、i18n 守卫、zip-slip 防护（我们 ADR-0042 比它早且形状一致）、diff 投影、审批回路、忙时队列。

---

## 6. 移植路线图（按"收益/成本/风险"排序）

> 每条都要先立 ADR（下一编号以 `ls docs/adr/` 现场为准，当前 **ADR-0056**）再动手。标 ★ 的建议优先。

> **执行进度（2026-10-04）**：A3 已落（ADR-0058：请求日志 + 上下文快照两份 JSONL，S3 存储明细未做）；**A1 ask_user 已落**（ADR-0059：`ask_user` 工具 + `AskUserPanel` 占 composer 座位，答案经 respond 路径作为工具结果回去）。**drift 已引入**（ADR-0060：单库多域 `<support>/planstar.db`，S1 = usage 台账迁库 + 旧 JSONL 一次性导入；架构门禁第 8 条钉住 drift 只住 lib/state）——对应本评估 §3.5 的数据层判定与 ZCode C1 的前置。并发会话同日落了 ADR-0056（PlanStar 身份）与 ADR-0057（Android/iOS 品牌脚手架——与本评估"C1 手机面全部不搬"的判据不冲突：ADR-0057 明文"只带品牌、不保证运行"）。**A2 会话压缩已落**（ADR-0061：`/compress` = 摘要 + 新会话，摘要骑 ADR-0009 注入通道的独立槽；自动阈值等 contextWindow 数据，见评估 B3）。下一项：B 组（多 Key+代理 / skills 渐进披露 / 定时任务）与 S3 存储明细。

### A 组：零新依赖、不踩不变量、当场可验收

- **A1 ★ ask_user 工具**：选择题/开放问题挂起-应答，复用 ADR-0012/0013 的 interrupt→resume 通道与 `plan_review_panel` 卡片先例。落点：`lib/genkit/tools.dart` + `lib/ui/conversation/`。注意：定时任务/无人值守场景遇待答要像 Kelivo 一样显式失败而非挂死。ADR：ARC。
- **A2 ★ 会话级上下文压缩**：阈值（真实 usage 覆盖估算）+ LLM 摘要 + 新对话；裁剪模式取 Kelivo 四档、失败熔断取 ZCode 口径（3 次）。依赖模型 contextWindow 数据。ADR：ARC。
- **A3 ★ 诊断日志三件套**：请求 JSONL（base64 elide）+ 上下文快照（完整 prompt + 分段 token 估计）+ 存储明细；与 ADR-0045 PC 的 usage 台账同族，设置页与快捷菜单双入口。ADR：ARC/DEF。
- **A4 消息多版本回复 + 编辑存新版本**：`TurnEvent`/`Conversation` 模型加版本组；与 B1 rewind 的边界要在 ADR 里写清（消息级 vs 文件级）。ADR：ARC。
- **A5 消息导出（md/txt/图片）+ 选择复制**。ADR：DEF。
- **A6 指令注入卡片**：复用 ADR-0009 注入通道，加用户手造卡与内置种子。ADR：ARC。
- **A7 快捷短语**。ADR：DEF。
- **A8 流式重试**："首 chunk 前才重试"律 + 状态码/关键字表。落点在供应商调用层。ADR：DEF。
- **A9 窗口恢复对齐**：macOS 交原生 autosave、设最小窗口尺寸（顺带回应登记表"窄窗 430px"观察项的产品前提）。ADR：DEF。

### B 组：中等成本，需新模块或新依赖（3–6 天/项）

- **B1 ★ 多 Key 管理 + 负载均衡 + 每供应商代理**：前置 ADR-0045 PF 的 savedProviders 铺开；**必须补执行层**（Kelivo 的自动熔断是死代码，别照抄半成品）；`socks5_proxy` 要 DEP ADR。ADR：ARC+DEP。
- **B2 环境变量注入 + 输出脱敏**：脱敏正则只作用于回给模型的文本。ADR：SEC。
- **B3 模型能力矩阵 ModelSpec 化**：四源合成 + 字段级溯源 + models.dev 目录快照，替代静态 `known_models`。ADR：ARC。
- **B4 reasoning effort**：方言层映射（与 ZCode B4 同项）。ADR：ARC。
- **B5 全局会话搜索（FTS5）+ 迷你地图**：前置 C1 sqlite 决策；流式期间延迟索引。ADR：ARC+DEP。
- **B6 ★ skills 渐进披露**：`<available_skills>` 名录 + 模型自取 SKILL.md + 使用计数，替换全量注入；skill-creator 元技能可选。ADR：ARC。
- **B7 定时任务**：桌面 Timer + 持久化规则表 + run 记录 + 无人值守失败语义。ADR：ARC。
- **B8 长期记忆**：大件，先拍板形态（提取型 vs ZCode 文件型 vs 暂不做）；若做，快照冻结注入 + sha256 门控是必抄项。ADR：ARC（背景需引用 user-research 编号或明写无一手证据）。
- **B9 备份升级**：恢复前自动留可回滚副本（cutover 思想）→ 本地快照 GFS-lite → WebDAV/S3 通道（SEC+DEP）。
- **B10 时间线投影 + 工具卡流式 tail + 长输出 offload**：投影层改动。
- **B11 增量 markdown 渲染**：只重扫尾部块。
- **B12 上下文分桶归因**：ContextSegmentTags 进 usage 台账。

### C 组：不搬（附理由）

- **C1 手机面全部**：PRoot/iSH 沙盒、设备工具、后台生成/Live Activity、扫码、外部分享接入——平台定位排除。
- **C2 账号登录 OAuth（第三方订阅账号）**：与形态②自建后端冲突；用量快照 UI 形状可在额度快照 UI（ADR-0045 余项）里参考。
- **C3 世界书 / 正则替换 / 预设消息 / 聊天气泡毛玻璃与壁纸 / 动态取色 / Google Fonts 下载**：roleplay 或消费向外观，与 dsw 令牌体系、ADR-0017/0036 的设计纪律冲突。
- **C4 自研 HTTP/SSE 栈**：我们押注 genkit，绕过它等于推翻 ADR-0002 运行时选型；transport 抽象思想除外。
- **C5 Cherry Studio/Chatbox 导入、余额查询、HTML 消息渲染、翻译独立页、TTS/ASR/图像生成**：消费特化，按需求再说（TTS/ASR 若做，Kelivo 的三实现分层——系统/本地 sherpa/云——是现成分层）。
- **C6 任何形式的代码/文案/提示词搬运**：AGPL-3.0（见 §8 红线 1）。

---

## 7. 如果只做三件事

1. **A3 诊断日志三件套**——agent 产品的调试刚需，纯本地、零新依赖、与已落的 usage 台账同族；做完 ADR-0045 的"可观测"短板就齐了。
2. **A1 ask_user 工具**——让"审批中断"从"能不能做"升级为"要不要这样做"，交互模型我们两块先例齐备；这是 Kelivo 与 ZCode 两份评估唯一共同点名的缺口。
3. **A2 会话压缩**——两份评估都点名的硬缺口；长会话爆窗是 agent 产品的第一天花板。

---

## 8. 移植红线检查表（Kelivo 特有部分）

通用不变量（genkit 只在 `lib/genkit/`、`lib/model/` 纯 Dart、不新增依赖除非 DEP ADR、i18n 双字典、主题只走 `dsw_*`、每项先 ADR、门禁口径 = 相对 `+1340 -2` 基线零新增失败）见 `zcode-vs-agent-harness-2026-09.md` §8 与本仓库 AGENTS.md，以下只列 Kelivo 特有：

1. **AGPL-3.0**：不复制任何源码、提示词原文、图标、README 文案。**提示词与 UI 文案必须按我们的 i18n 双字典重写**，"翻译式照抄"也不行——这是与 ZCode（Apache-2.0）评估最大的红线差异。
2. **半成品不照抄**：Kelivo 有两处"数据模型超前于执行层"的死代码（多 Key 自动熔断无调用方、`macos_window_position.dart` 无消费者）；引用它的机制设计时先核执行层是否真的存在。
3. **平台过滤**：它 40% 的功能面（沙盒/设备工具/后台/扫码）在桌面-only 定位下直接不读。
4. **vendored 依赖不效仿**：它 fork 了 5 个包；我们 vendored 只有 `board_panel` 一个入库先例（ADR-0007 D5），新增 fork 要 DEP+ARC。
5. **它的安全边界比我们松**：API key 明文入库、OAuth 凭据原样进分享二维码、桌面工作区无沙箱靠审批兜底。参考它的功能时，落点必须过我们已有的 SEC 判据（keychain/ADR-0042/ADR-0049）。

---

## 9. 方法与诚实边界

- **方法**：kelivo 归档克隆至 `_archive_project/kelivo`（master @ `0cfc718`，codeload tarball，按提交内容验证 pin）；5 个并行只读探索代理按功能面清点（对话消息 / 供应商模型 / 工具工作区 / 记忆上下文 / 数据备份与桌面壳），每个结论带 `path:line`；本文作者对关键主张做了二次抽查（工具名清单 `workspace_tools_service.dart:57-66`、`ask_user_input_v0` `local_tools_service.dart:19`、29 张 drift 表、四个巨型文件行数 4064/7251/8231/6673、memory 目录 13 文件、AGPL LICENSE 头、`app_en.arb` 5623 行——全部吻合）。
- **两处死代码判断**（多 Key 自动熔断、macos_window_position 无消费者）来自探索代理的 grep 全库结论，未逐条人工复核间接调用路径；动手前若引用这两条，先重跑一次 grep。
- **本仓库侧现状**以 2026-10-04 现场核实为准（skills 全量注入 `agent_runtime.dart:81-82`、genkit_mcp、usage 台账在、无压缩、备份仅本地 zip、无 ask-user）。
- 本文档**只评估，不含代码改动**；`_archive_project/kelivo` 已被 `.gitignore` 排除，不会进入版本库。
