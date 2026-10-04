# ADR-0063: 快捷短语——输入卡上的一把常用话术

- **状态**: ACCEPTED
- **分类**: DEF
- **优先级**: P2
- **影响维度**: 生产功能
- **日期**: 2026-10-04
- **来源**: kelivo 评估 §7 A7（kelivo `quick_phrase`：输入栏一键插入、全局与按助手两套、管理页）。本仓库没有助手维度——**只有全局一套**，这是收窄不是缺失（ADR-0045 的模型座是单座的）。
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

重复输入的常用话术（一句测试指令、一段固定的开场、一条常用的代码评审要求）每次都要重打或从别处粘贴。kelivo 的答案：短语库 + 输入栏一键插入光标处。本仓库的 composer 已有直接操纵 `TextEditingController.value` 的先例（`_insertMention`，光标定位是解过的问题）。

## 决策（Decision）

**全局短语库：composer 左簇一枚图标钮开锚定菜单，点选插入光标处；管理面在设置页新增「快捷短语」节。**

1. **存储**：`<support>/quick_phrases.json`，`QuickPhrase {id, title, text}` 列表 + 同步 tmp+rename（`SessionRegistry` 形状）；损坏按空库处理。没有助手维度——本仓库没有助手，加了就是没有读者的字段（ADR-0022 的律）。
2. **插入在光标处、不直接发送**（kelivo 同律）：短语是草稿的材料，不是草稿本身；插入后焦点回输入框。
3. **UI 座位与重量的代价**：左簇加一枚 `DswIconButton`（`text_cursor_input`），左簇最紧地板按 ADR-0052 的量法**重新量**（84px → 新值），`composer_test` 里钉死的实测数字跟着新值走——这是"设计变了就重量"的既有流程，不是改断言凑绿。
4. **管理面**：设置页新节，列表 + 新建/编辑（标题 + 正文两字段）+ 删除；短语是用户内容不是偏好，但它的消费面只有输入卡，设置页是它唯一的家（快捷菜单双入口律管的是高频偏好，短语不在其列）。
5. **明确不做**：按助手/按会话的短语集（没有助手）；占位符变量（`{{x}}` 一类——kelivo 的 assistant 提示词有模板变量，短语的消费者是草稿不是提示词，等真实需求）；导入导出（备份 zip 的 `quick_phrases.json` 一格随清单走即可——**加入备份清单**，它和 sessions.json 同类：跟着人走的内容）。

## 后果（Consequences）

- **正面**：重复话术一键到位；短语与 `/` 命令语义不混（命令动词 vs 插入材料）。
- **负面/风险**：左簇地板变大让 260px 档的降级序列提前触发——由实测守卫钉住；菜单条目随短语数增长无上限（cap 20 条 + 新建按钮禁用，kelivo 的 available_skills 同款 cap）。
- **中性**：`locales.dart` +6 键 ×2；备份清单 +1 格。

## 验证（Verification）

- `test/quick_phrase_test.dart`：store 往返 + 损坏容忍 + cap；composer 插入（光标在中间时插在光标处、插入后焦点回框）；settings 节增删改。
- composer_test 既有实测数字按新地板重测更新（红→量→改，过程记录在本行）。
- 四道门禁同口径。

## 关联（Links）

- 代码: `lib/model/quick_phrase.dart`、`lib/state/quick_phrase_store.dart`、`lib/ui/conversation/composer.dart`、`lib/ui/settings/model_settings.dart`、`lib/state/backup_service.dart`
- 关联 ADR: ADR-0052（composer 行的实测地板——本 ADR 重测）、ADR-0024（图标钮原语）、ADR-0028/0036（菜单皮与原语）
- 来源评估: `docs/kelivo-vs-agent-harness-2026-10.md` §7 A7
