# ADR-0067: 指令注入卡片——用户手造的提示词卡，随工作区走

- **状态**: ACCEPTED
- **分类**: ARC
- **优先级**: P3
- **影响维度**: 生产功能
- **日期**: 2026-10-04
- **来源**: kelivo 评估 §7 A6（kelivo 的 instruction_injection：可复用提示词卡按分组管理，发送前 join 进 system；内置"学习模式"种子）。本仓库的收窄：无助手维度，卡片**按工作区不区分**（全局一套），无分组——cap 之下的平表足够。
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

ADR-0009 的注入通道目前只有一个生产者：盘上发现的 AGENTS.md 文件。用户临时想给模型加一条行为约束（"回答都用中文先给结论""代码注释写英文"），现在只能写进 AGENTS.md（重，且是仓库内容）或每句话重打。kelivo 的卡片模型是第三条路：**一份用户手造、与应用状态平级的可复用提示词**。

## 决策（Decision）

**`<support>/instruction_cards.json` 平表（`{id, title, text}` cap 10），设置页管理节 + 头部菜单勾选启用，启用的卡片在下一轮以 `<user-cards>` 块随 ADR-0009 通道注入。**

1. **存储**：卡片全表持久化（内容不丢）；**启用集合**进 `AppSettings`（`enabledCardIds: List<String>`）——启用是偏好不是内容，跟着 settings 走才对（删除卡片时启用集合自动剔除孤儿 id）。不进备份的内容本体？进——卡片是用户内容，与 quick_phrases.json 同类，备份清单 +1 格。
2. **注入**：`AgentRuntime._queueInstructions` 组装时把启用卡片的文本 join 进块尾（卡片文本之间空行分隔），仍在 `<project-instructions>` 标签内——**不新开注入通道**，`isInjectedPart` 与全部既有守卫原样生效。运行时经构造器新可选参数 `cardsLoader`（`Future<List<String>> Function()`，`DiagnosticHooks`/`environmentLoader` 第三次同形——这条缝已经是惯例）。
3. **UI**：设置页新「指令卡」节（增删改 + 启用开关，`ShadSwitch`）；侧栏页脚头像快捷菜单**不加**（低频配置面，双入口律不适用——ADR-0058 的判据第二次引用）。每卡一个启用开关而非会话级勾选：本仓库没有会话级偏好位，加位是第二真值。
4. **cap 10**：卡片的注入预算必须有界（每卡文本 500 字符裁剪），总量 ~5KB，与 AGENTS.md 的 24KB 字节预算同量级意识（`instructions.dart` 的 per-file cap 先例）。
5. **明确不做**：分组/标签；内置"学习模式"种子（kelivo 的英文教学提示词与我们无关，种子文件是内容搬运的灰色地带）；按助手/按会话作用域；卡片内的模板变量。

## 后果（Consequences）

- **正面**：用户行为约束第一次有轻量持久通道；注入通道没有第二个真值（标签、排除规则、守卫群全部继承）。
- **负面/风险**：卡片随每轮注入重复消耗 token（每次模型调用都带）——cap 与 500 字符裁剪是有界代价；卡片与 AGENTS.md 的语义重叠由用户裁决（应用不帮选）。
- **中性**：`AppSettings` +1 字段（有读者：runtime 闭包 + 设置面板）；`locales.dart` +6 键 ×2。

## 验证（Verification）

- `test/instruction_cards_test.dart`：store 往返 + cap + 裁剪；启用集合孤儿剔除；组装纯函数（启用卡片 join、空集合不加块尾）；settings 字段往返 + 不触发重建。
- 反向验证：拆组装调用 → 组装测试红。
- 四道门禁同口径。

## 关联（Links）

- 代码: `lib/model/instruction_card.dart`、`lib/state/instruction_card_store.dart`、`lib/genkit/instructions.dart`、`lib/genkit/agent_runtime.dart`、`lib/ui/settings/model_settings.dart`、`lib/state/backup_service.dart`
- 关联 ADR: ADR-0009（通道与标签守卫）、ADR-0022（字段必须有读者——`enabledCardIds` 的读者在 runtime）、ADR-0064（loader 缝的第三次同形）
- 来源评估: `docs/kelivo-vs-agent-harness-2026-10.md` §7 A6
