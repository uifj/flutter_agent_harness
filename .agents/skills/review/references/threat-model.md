# PlanStar 威胁模型（review 的 Correctness 轴专用）

这是一个**能读用户工作区、能写文件、能跑 shell、能连 MCP 外部工具、能把内容发给远端模型**的桌面 agent。Correctness 轴除通用运行时 bug 外，专门查下面这些面。每条都对应一处已有机关，diff 若绕过它或改坏它就是发现。

## 1. 工作区访问边界（security-scoped bookmark）

- 工作区访问靠 **security-scoped bookmark**，恢复必须发生在任何读文件之前（`main()` 里的 `restoreWorkspaceAccess`，`host/project_folder_ops.dart`）。diff 若在恢复前就读了文件 = 发现。
- **`@` 引用与文件工具必须过同一道 `Workspace` 门**（ADR-0015/mention）：每个 `@path` 发送时经 `model/mention_expansion.dart` 由 `AgentRuntime.send` 调用，走与 `read`/`write` 工具相同的那道门。新增任何"读工作区外文件"的路径 = critical。
- 软链越权：符号链接能把"根内"的路径指到根外（`/var` ↔ `/private/var` 这类）。任何路径拼接要验重锚后的根，别把 git/引擎报的解析路径当成用户选中的拼法直接拼（ADR-0043 那条）。

## 2. 审批门禁（decideGate 是唯一的顺序）

- 判定只问 `genkit/tools.dart` 的顶层 `decideGate`（plan 先拒 → deny 规则带理由拒 → allow 规则静默放行 → 非 `ask` 放行 → 否则 interrupt）。**内部可写工具经 `gateFor`、MCP 外部工具经 `agent_runtime.dart` 的 `_ToolGate`，都调同一个函数**——新工具自己拼 `shouldInterrupt` = 内外出现两套免问语义 = high。
- **免问规则的 subject 必须与审批面板显示的那串一致**（文件 `ws.relative(path)`、命令原文、外部工具 `server/tool`，由 `ApprovalRequest.ruleFor()` 从 interrupt payload 反推）。"记住的东西"和"用户批准的东西"分叉就是安全漏洞。规则落 `<support>/approvals.json` 按工作区分键；设置页可逐条移除——只能加不能减的免问按隐藏后门处理。
- 工具"是否只读"的唯一声明是 `WorkspaceTools.readOnlyToolNames`；子 agent（委托）的工具集由它派生。加只读工具漏进这个集合，或另在 `agent_runtime.dart` 补一份列表 = 发现。

## 3. 文件写入的回退闸门（checkpoint）

- `write`/`edit` **在覆盖写之前**把 before 镜像交给 `CheckpointSink`（`model/checkpoint.dart` 接口、`state/checkpoint_store.dart` 实现）。diff 若在镜像之前就盖写 = high。
- **冲突闸门**：该 path 范围内最新条目的 `afterFingerprint` 与磁盘不符（含"agent 新建、用户又编辑过"）就**不动它**并报 `changedOutsideAgent`；镜像没存（超 2 MiB）或已淘汰报 `imageUnavailable`——宁可什么都不改，也不盖别人的编辑。
- **`bash`/MCP 改的文件没有镜像**（`shell_run.dart` 走 `Process.start`）。报告若把"这一轮的全部变化"说成都能退 = 谎言（critical 级别的诚实性问题）。

## 4. 密钥与 PII

- **永不把密钥写进代码/提交/文档**。当前生产化缺口之一（`docs/production-readiness-gap-2026-10-02.md`、ADR-0045）是 API key 曾明文——动设置/密钥路径的 diff 要盯：key 该走 keychain，不该进 `<support>/*.json` 明文、不该进日志、不该进 `AGENTS.md`/skill（它们经 ADR-0009 是模型输入）。
- **PII / 敏感数据别泄进发给模型的载荷**：附件（图片按 `modelAcceptsImages` 能力门控）、文档抽文本、checkpoint before 镜像、诊断日志——diff 若把这些不经 `sendDefaultPii` 类闸门就外发 = 发现。
- `.gitignore` 里**没有** `*.p12`/`*.cer`/`*.mobileprovision`——引入证书之前先补忽略规则（`build.md` §4）。

## 5. 备份 / zip（SEC P1，ADR-0042）

- `restoreBackup` 对 zip 每个条目名先经 `resolveBackupEntry` 纯函数验证（zip-slip / 目录穿越），**一枚越界的名字就让整次恢复不发生**——半恢复既看不见也退不回。新增任何"按 zip 条目名直接 `p.join(support, name)` 就写"的路径 = critical。

## 6. genkit 0.x 的投影陷阱（会静默错，不报错）

升版或改投影时核对 `spike/agent_spike.dart` 头部 FINDINGS：

- `Part` 是单一 json-backed 类型——`part is TextPart` 永不成立，用 `PartExtension` 的 `isText`/`isToolRequest`/… 判别。
- `SchemanticType.jsonSchema(...)` 不存在——运行时 schema 用 `SchemanticType.from<T>(jsonSchema:, parse:)`。
- `chunk.accumulatedText` 是 **turn-global**，不能当单条消息正文，要按 `chunk.raw.modelMessage.index`/分组。
- **被批准的工具结果不在直播流里**——genkit 重启被 interrupt 的工具时不 `sendChunk`，rewind pill 读的 checkpoint id 靠 `_drive` 收尾从快照补投影（ADR-0016）。删掉那段补投影，症状不是报错而是"回退按钮要点开重会话才出现"（静默失效）。
- **中途转向（guide）**：`takeUndeliveredGuides()` 必须在 `_drain()` 开头整批插回队首——纯长回答不会再有模型调用，漏了这步就是静默丢用户输入（ADR-0013）。

## 7. 序列化 / 状态一致性

- `toJson`/`fromJson` 往返正确性、null 处理（手写序列化，无 codegen 兜底）——尤其会话 sidecar（`sessions.json`）、`WorkbenchPrefs`、`AppSettings`（读侧宽容、写侧收敛）。
- **一份真值不许有两处**：`git status` 一份读数两个读者（ADR-0043）；窗口标题只由 `composeWindowTitle` 产出（ADR-0019 ③）；换工作区只有 `AppScope.setWorkspace` 一条路（ADR-0039）。diff 若造第二处会不相等的真值 = 发现。
- **渲染 store 的面板必须 listen**——不订阅 store 就是两份真值（企划那条，`plan_data_view_screen.dart` 头部注释 + `plan_data_view_test.dart` 守）。
