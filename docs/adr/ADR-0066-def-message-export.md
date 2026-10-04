# ADR-0066: 消息导出（Markdown/纯文本/复制全文）与整段选择复制

- **状态**: ACCEPTED
- **分类**: DEF
- **优先级**: P2
- **影响维度**: 生产功能
- **日期**: 2026-10-04
- **来源**: kelivo 评估 §7 A5（kelivo 的单条/批量导出 md/txt/图片 + 选择复制）。图片导出（RepaintBoundary 拼接）不进本 ADR——渲染依赖 gpt_markdown 的分块结构，成本高于其余全部之和，单列 S2。
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

对话里产出的内容（一段可用的代码、一份总结、一条命令序列）现在只能逐条手动选中复制——`SelectableText` 的选择是逐 widget 的，跨消息选择不存在。kelivo 的答案：每条消息一个动作菜单（md/txt/图片导出 + 选择复制），外加整段多选导出。本仓库的转录是 `ListView.builder` 上的 `MessageItem`，没有消息级菜单的既有家。

## 决策（Decision）

**消息右键/长按菜单（`DswContextMenu` 包裹）+ 两个导出动作（md/txt 经 `FilePicker.saveFile`）+ 会话级「复制全部」；不做多选模式。**

1. **入口**：`MessageItem` 的用户气泡与助手正文各包一层 `DswContextMenu`（桌面右键即出，触屏长按由原语的语义层带出）——菜单条目：复制本文（`Clipboard`，`pasteboard` 已在依赖树）、导出为 Markdown（`.md`）、导出为纯文本（`.txt`）。工具卡与错误行不进菜单（工具结果已在卡片上有复制路径）。
2. **导出形状**：助手消息导出 = 原文（md）；txt = 同文去 markdown 标记不做（保留原样——转 markdown→纯文本是一个无良定义的转换，做了就撒谎）。用户气泡同构。文件名 `planstar_message_YYYYMMDD_HHMMSS.<ext>`，保存对话框与备份导出同一座 `FilePicker.saveFile`。**跨平台保真**：CRLF 不做转换（文件内容 = 转录内容）。
3. **会话级**：转录头部（stats 行旁）不做——stats 行是只读计数轴（ADR-0034 判词）；「复制全部」进 composer 命令菜单 `/copy`（命令是会话级动词的既有家，ADR-0059/0061 先例），把全部用户+助手文本按行拼接进剪贴板（`compressionTranscriptOf` 的无 cap 版本，复用其装配语义）。
4. **明确不做**：图片导出（S2）；多选批量（`ListView.builder` 惰性树上的多选状态是一次大改，需求先出现）；导出含 reasoning（思考段是模型的草稿纸，不是产出）。

## 后果（Consequences）

- **正面**：对话产出第一次有"拿走"的路径；菜单复用 `DswContextMenu` 原语（键盘/语义四性自带，ADR-0021/0028 的纪律零成本）。
- **负面/风险**：长按手势与 `SelectableText` 的选择手势可能竞争——实现时以 `DswContextMenu` 的包裹顺序验证，冲突则菜单只在右键出现（桌面优先的真实代价）。
- **中性**：`locales.dart` +6 键 ×2；`MessageItem` +2 层包裹。

## 验证（Verification）

- `test/message_export_test.dart`：右键弹菜单、条目齐全；「复制文本」进剪贴板（`ClipboardProbe`，仓库既有替身）；`/copy` 命令拼接全文；导出文件名格式纯函数。
- 反向验证：拆菜单包裹 → 右键断言红。
- 四道门禁同口径；真机走查长按与选择的竞争。

## 关联（Links）

- 代码: `lib/ui/conversation/message_item.dart`、`lib/ui/conversation/composer.dart`、`lib/model/context_compression.dart`
- 关联 ADR: ADR-0028/0036（菜单皮与原语）、ADR-0020（反馈条：导出成功/失败一句话）
- 来源评估: `docs/kelivo-vs-agent-harness-2026-10.md` §7 A5
