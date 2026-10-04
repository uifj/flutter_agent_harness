# ADR-0069: 定时任务——分钟级调度 + 脱离会话的 detached 执行（S1）

- **状态**: ACCEPTED
- **分类**: ARC
- **优先级**: P2
- **影响维度**: 生产功能
- **日期**: 2026-10-04
- **来源**: kelivo 评估 §7 B7（kelivo 的 scheduled_tasks：hour/minute+weekdays、newChat 模式、run 记录、无人值守遇审批判 `user_interaction_required` 失败）+ ZCode 评估 B6（单进程 Timer + 持久化任务表即可）
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

"每天早上把工作区变更总结成一段话"这类循环指令现在只能靠人记得来问。kelivo 桌面侧的形状与本仓库完全同构：**应用存活期间的 Timer 轮询**（无 OS 闹钟/launch agent——它对桌面的注释原话"no OS alarms"），到点把指定提示词发给一个新会话，run 记录含预览。

## 决策（Decision）

**S1 = drift 两张表 + AppScope 每分钟 Timer + `AgentRuntime.runDetached` + 设置面列表（增/删/启停）。**

1. **调度模型**（kelivo 收窄）：`{name, prompt, hour, minute, weekdaysMask, enabled}`——weekday 位掩码（周一=1…周日=64，0 = 每天），**非完整 cron**；到点判定是纯函数（-minute 匹配 + weekday 位测试）。错过触发（应用没开着）**不补跑**——S1 的诚实边界，应用下次启动只等下一个匹配分钟。
2. **drift 表**（schemaVersion 1→2，`onUpgrade` 补建）：`scheduled_tasks`（id/name/prompt/hour/minute/weekdaysMask/enabled/lastRunAt）与 `scheduled_task_runs`（id/taskId/startedAt/ok/preview——预览截 200 字符，kelivo 同量级）。**单飞**：fire 前先写 lastRunAt，防重入。
3. **执行**：`runDetached(prompt)` 在 runtime 上新开一个**独立 chat**（不碰 `_chat`——用户正在打字的会话与定时任务互不感知），收集助手文本至 TurnFinished；途中出现 `ApprovalRequired` 或 `ask_user` 中断 → 立即 stop 并把 run 判失败（"需要用户在场"），即 ADR-0059 埋的那笔债在此闭环。
4. **调度器**：`AppScope` 持 `Timer.periodic(15s)`，钟面分钟匹配即 fire（15s 步长不会双触发——匹配按分钟相等判定，同一分钟内 fire 过就由 lastRunAt 挡住）。
5. **UI**：设置页新「定时任务」节：任务列表（名字 + 时间 + 启用开关）+ 新建（名称/提示词/时间/周几）+ 删除；run 历史不在 S1 UI（表已落，读侧 S2）。
6. **明确不做**：cron 表达式；后台唤醒/开机自启（OS 集成是另一档 ADR）；S2 的 run 历史 UI；每任务的模型覆盖。

## 后果（Consequences）

- **正面**：循环指令第一次可委托；ADR-0059 欠的"无人值守遇 ask_user 悬挂"债闭环；drift 二号表域坐实。
- **负面/风险**：应用关闭即不执行（kelivo 桌面同此边界）；detached run 与用户会话共享 runtime 的审批簿/环境变量——审批簿按工作区，环境变量全局，语义一致。
- **中性**：`drift` schemaVersion 2（迁移两行）；`locales.dart` +8 键 ×2。

## 验证（Verification）

- `test/scheduled_task_test.dart`：due 纯函数（分钟/星期/掩码边界）；store CRUD；runtime runDetached 由假 turn source 无法覆盖（真 chat 才有）——记为真链余项；迁移由 drift 的 schema 验证（v2 建表）。
- 四道门禁；真机走查新建任务到点触发。

## 关联（Links）

- 代码: `lib/model/scheduled_task.dart`、`lib/state/scheduled_task_store.dart`、`lib/state/app_database.dart`、`lib/genkit/agent_runtime.dart`、`lib/state/app_scope.dart`、`lib/ui/settings/model_settings.dart`
- 关联 ADR: ADR-0059（ask_user 的无人值守债在此闭环）、ADR-0060（drift 单库多域）、ADR-0055（换文件夹结束对话——detached run 不受影响，绑定 fire 时刻的工作区）
- 来源评估: `docs/kelivo-vs-agent-harness-2026-10.md` §7 B7
