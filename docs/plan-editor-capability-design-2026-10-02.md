# plan_editor 能力清单与施工表（ADR-0044 配套）

> 决策：**ADR-0044**（`docs/adr/ADR-0044-arc-plan-editor-package.md`，ACCEPTED 2026-10-02 用户拍板）。
> 上游真值：`docs/anytype-feature-inventory-2026-10-01.md` §3（块编辑器）。
> 参考项目副本：`_archive_project/re-editor`、`_archive_project/super_editor`（head `068a20d`）、
> `_archive_project/AppFlowy-Editor`（head `01eccc6`），行号以 2026-10-02 shallow head 为准。
> 本文 = 能力清单（§1）→ 三参考研究裁决（§2）→ 架构（§3）→ 阶段计划与守卫（§4）→ 诚实边界（§5）。

## 1. 能力清单（Anytype §3 逐条 → 归属）

判据：**"正在编辑的那一块文本"归 plan_editor；块树/盘上格式/命令面归 app。**
状态列：✅ 已落 / 🔨 Pn 计划 / ⛔ 照上游答案不做 / ↔ 既有（app 已有，不动）。

| # | 能力 | 归属 | 状态 | 落点 |
| --- | --- | --- | --- | --- |
| E1 | 属性化文本模型：`text + marks[(range,name,param)]`，insert 继承跨点样式、delete 收缩、toggle 重叠替换 | 包（`attributed_text` 引擎） | P10-a ✅ | `PlanEditorController` |
| E2 | 编辑中实时渲染 8 种工具栏 mark（bold/italic/strike/underline/keyboard/link/textColor/backgroundColor） | 包（`buildTextSpan`）+ app 样式注入 | P10-a ✅ | `PlanEditorController.buildTextSpan` |
| E3 | IME composing：合成区下划线、合成期 mark 平移安全 | 包 | P10-a ✅（真机走查登记 §5） | `buildTextSpan(withComposing)` |
| E4 | 打字 ⇄ 文档双向镜像：打字时字段权威、命令时文档权威，每通道一个平移引擎 | app ↔ 包边界 | P10-a ✅ | `editTextWithMarks` + `didUpdateWidget` 推送 |
| E5 | 选区→mark 查询（工具栏 ghost/outlined 态） | ↔ 既有（文档为真值） | ↔ | `PlanBlockDocument.applyMark` + `_hasMark` |
| E6 | slash 菜单（唯一插入入口，7 段 + table(RxC)） | ↔ 既有 | ↔ | `plan_block_editor.dart` |
| E7 | undo/redo（快照栈，深度 50，id 保持） | ↔ 既有（app 文档层） | ↔ | `PlanBlockDocument._undoStack` |
| E8 | 14 样式建模 / 11 可插 / 读面渲染（P9 补全的 toggle/序号/引用条/callout） | ↔ 既有 | ↔ | `plan_block.dart` + `PlanBlockView` |
| E9 | 表格块族（行级 UI + 列级菜单） | ↔ 既有 | ↔ | `plan_block_actions.dart` |
| E10 | 文内搜索六事件 + 搜索转只读 | ↔ 既有 | ↔ | `plan_block_editor.dart` |
| E11 | 块级键盘语义：Enter 拆块、Backspace 合并、方向键跨块、焦点漫游 | app（P10-b，包提供字段级 API） | 🔨 P10-b | — |
| E12 | 编辑面链接可点 / 链接 URL 二次编辑 | app | 🔨 P10-b | — |
| E13 | 单字段整文档 surface（"IME 只见一个块"的完整版，re-editor 形态） | 包+app | 🔨 P10-c（视 P10-a/b 真机实况） | — |
| E14 | 三段落点拖拽 + 自动滚动（AC3-18 全量） | app | 🔨 P10-d | — |
| E15 | 系统剪贴板 HTML 互操作（AC3-19 余项） | app | 🔨 P10-d | — |
| E16 | @提及 / emoji / object 三种渲染态 mark 的编辑面插入 | app（等对象身份面） | 🔨 P6+ | — |
| E17 | WYSIWYG 全量（跨块选区、块内嵌套子块的样式连续性） | 包+app | 🔨 P10-c/d | — |
| E18 | 自定义 token 快捷键（Cmd+B 等） | app | 🔨 P10-b | — |

**不在清单上（⛔ 照上游）**：synced/linked block、冻结表头、合并单元格、JUSTIFY、
`flutter_markdown_plus`/`gpt_markdown` 作为编辑内核（两者都是单向渲染器，2026-10-02 全文取证零写回路径）。

## 2. 三参考研究裁决（2026-10-02 逐文件）

### re-editor（取 4 件，弃 highlight/折叠/滚动管线）

- **取①"IME 只见一个块"**：`_code_input.dart:472-497` 平台通道只喂当前块文本、delta 映射回块坐标
  ——P10-c 单字段整文档的地基。
- **取② controller 持 `TextInputConnection`** 的 `DeltaTextInputClient` 架构（`_code_input.dart:442-453`，
  镜像 `_remoteEditingValue`、回推 `setEditingState/setComposingRect/setCaretRect`）——P10-c 取。
- **取③结构相等 `TextSpan` 键控的 `ui.Paragraph` 缓存**（`_code_paragraph.dart:198,250`，
  Flutter `TextSpan==` 是结构比较）——性能层的正确答案，P10-c 取。
- **取④快照链表 undo + 打字合并 + 命令新记录**（`_code_line.dart:1997-2086`）——语义参照，
  但 app 已有快照栈，只对齐"合并规则"。
- **弃**：highlight 引擎与 isolate、括号自动闭合、折叠树、行号、find、`\u200b` 前缀 hack
  （块级编辑通常不需要，真机验证后再说）、viewId shim、裸 `ViewportOffset` 管线（有
  `_kMaxLayoutCycles` 冻结前科）、无上限 undo。

### super_editor（取 1 包 + 1 函数，弃框架）

- **取①`attributed_text` 包本体**（MIT，纯 Dart，无 Flutter 依赖）：marker-pair span bank、
  `addAttribution(autoMerge, overwriteConflictingSpans)`、`toggleAttribution`、copy-based
  `insert/removeRegion`（跨点 span 自动平移收缩）、`collapseSpans`。这就是 E1 的全部。
- **取②`AttributionStyleBuilder` + `computeInlineSpan` 模式**（`infrastructure/attributed_text_styles.dart:24`，
  ~80 行胶水）：`Set<Attribution> → TextStyle` 由调用方注入，包对配色无知（ADR-0002 桥头约束）。
- **取概念**：`ComposerPreferences`（折叠选区的"下一段输入携带样式"）登记为 P10-b 候选；
  node-copy 即变更信号的思路不需要（app 文档已有 revision/notify）。
- **弃**：Document/Editor/命令管线（93k 行框架）、`SuperTextField`（拖 follow_the_leader/overlord/
  super_text_layout 全家）、document_ime 的整文档序列化（那是多节点模型才需要的）。

### appflowy-editor（取 IME 防御清单与反面教材）

- **取 IME 防御四条**：合成期不回推 `setEditingState`（Windows/CJK，`non_delta_input_service.dart:75-87`）、
  合成期抑制硬件键快捷键（`keyboard_service_widget.dart:174-179`）、autoformat 仅在
  `composing.isCollapsed` 时触发（`delta_input_on_insert_impl.dart:24-37`）、前导哨兵空格
  （`delta_input_service.dart:194-207`，P10-c 备用）。
- **取反向裁决**：它的 markdown 编解码**静默丢 font_color/bg_color**（`delta_markdown_encoder.dart`）
  ——我们绝不允许：`<!-- plan:{json} -->` 信封已经保证颜色往返（ADR-0037 P8-a）。
- **弃**：Delta-in-attributes 模型（与 PlanMark/信封双轨冲突）、Path 寻址、协作变换、插件生态。

## 3. 架构

```
packages/plan_editor/            # 不受根仓门禁（根 analysis_options 排除 packages/**），包内自带门禁
  lib/plan_editor.dart           # 导出 EditorMark / PlanEditorController / EditorStyleResolver
  lib/src/editor_mark.dart       # 命名属性（bold italic underline strikethrough keyboard）
                                 # + 参数属性 LinkMark(url) / TextColorMark(梯名) / BackgroundColorMark(梯名)
  lib/src/plan_editor_controller.dart
      extends TextEditingController
      · AttributedText _attributed          # E1 引擎（attributed_text 包）
      · set value(): 差分（最长公共前后缀）→ removeRegion+insert → span 自动平移
      · buildTextSpan(): collapseSpans → resolver(Set<Attribution>) → TextSpan（composing 下划线自画）
      · toggleMark(attribution, range?)     # 重叠替换语义（同 attributed_text）
      · hasMark(attribution, range) / attributedText getter
      · pushAttributedText(at): marks-only 推送不触碰 TextEditingValue（光标不动）
  lib/src/editor_spans.dart      # AttributedText → InlineSpan 列表（E2 胶水）

app 侧（lib/ui/plan/blocks/plan_block_view.dart）
  _BlockTextField: TextEditingController → PlanEditorController
      · initState / didUpdateWidget：PlanText → EditorMark 映射（PlanMarkType.name ↔ 属性 id）
      · onChanged：document.editTextWithMarks(id, controller.text, 映射回的 PlanMark 列表)
  _CellField（表格单元格）：保持裸 controller（无 mark）

lib/state/plan_block_document.dart
  editTextWithMarks(id, text, marks)   # 整块替换 text+marks（不做第二次平移），走 _mutate（可撤销）
```

**真值通道律**（ADR-0044 决策 3）：打字 → 字段权威（包内唯一平移引擎），命令 → 文档权威；
两个方向都是**整体镜像**，不存在"两份平移计算必须相等"。

## 4. 阶段计划与守卫

| 阶段 | 交付 | 门禁 | 提交语 |
| --- | --- | --- | --- |
| P10-a | 本表 + ADR-0044 + 包（E1/E2/E3）+ app 替换（E4） | 包内 `dart analyze`/`flutter test`；根仓 format/analyze/test 三门禁（零新增失败） | `docs(adr): land ADR-0044, the plan editor package` → `feat(plan): the plan editor package owns the styled edit field` |
| P10-b | E11/E12/E18（键盘语义 + 焦点漫游 + 快捷键） | 包内 + 根仓三门禁 + 放大两档 | `feat(plan): blocks answer Enter, Backspace and arrows` |
| P10-c | E13（单字段整文档，re-editor 机制①②③） | 同上 + IME 真机走查（中/英、Windows CJK） | `feat(plan): one field for the whole document` |
| P10-d | E14/E15（拖拽三段落点 + 系统剪贴板） | 同上 | `feat(plan): three-zone drag and the system clipboard` |

**守卫清单**：

- 包内（`packages/plan_editor/test/`）：平移正确性（中插/尾插/删除跨越/全删/组合期）、
  toggle 重叠替换（同型覆盖、异色覆盖）、insert 继承跨点样式、`buildTextSpan` 按跑分段调用 resolver、
  composing 下划线、marks-only 推送不动光标。
- 根仓（`test/plan_blocks_test.dart`）：编辑面选区应用 bold 后 `EditableText` 的 controller
  `buildTextSpan` 里读得到 w600 跑（编辑中富文本的第一条渲染守卫）；既有"marks survive save"与
  两档放大尺子照跑；`editTextWithMarks` 走 `_mutate`（undo 兼容）。
- 结构：包不 import dsw_*/PlanMark/shadcn（对宿主无知）；根仓 `check_architecture` 照跑
  （packages/** 本就在规则扫描之外）。

## 5. 诚实边界

1. **P10-a 的编辑面富文本只覆盖 8 种工具栏 mark**；mention/emoji/object 三种渲染态 mark 仍只在读面
   （等 P6 对象身份面）。斜体等在编辑面渲染为样式，不渲染 markdown 源符号——这是所见即所得的定义。
2. **composing 期行为要真机说了算**：中文输入法的组合段在 macOS/Windows 上的分词与 mark 平移交互、
   双主题 composing 下划线观感，真机走查后才算闭环（三个参考项目都在这里防御，我们也一样）。
3. **包依赖 `attributed_text ^0.4.5`**（pub.dev 版本；上游 head 里 `test` 在 dependencies 的 wart
   以 pub 实际解析为准）。升级漂移由包内测试钉住。
4. **P10-c 是条件项**：若 P10-a/b 的块级字段在真机上 IME/性能无恙，单字段整文档可以不立项——
   它是为"跨块选区样式连续性 + 拖拽三段落点"服务的，按需启动。
5. 交付说明按 `build.md` §0 标"待 macOS 验证"；Windows/Linux 的 IME 行为不在本机证明范围。
