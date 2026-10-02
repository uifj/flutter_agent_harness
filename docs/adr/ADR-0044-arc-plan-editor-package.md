# ADR-0044: packages/plan_editor——企划编辑器抽成独立包，编辑面升级为属性化富文本

- 分类: ARC
- 优先级: P1
- 状态: ACCEPTED（2026-10-02，用户拍板："明确需要创建 packages/plan_editor 完整实现 anytype 中的编辑器能力，从能力清单确定开始，到架构设计，再到开发实现，替换现有的企划模式下的编辑器功能"；参考 re_editor / super_editor / appflowy_editor 源码，副本已落 `_archive_project/`）

## 背景

ADR-0040（P9）落完后，企划块编辑器剩余的最大缺口是实现对照表 AC3-3 登记的那句：
**编辑面非所见即所得**——ShadInput 纯文本字段，富文本外观只存在于读视图/搜索态/Preview。
对照上游（`anytype-kotlin` @ `7af5254`）：编辑中实时渲染 11 种 mark 是 Anytype 编辑器的基本面。

2026-10-02 对三个参考项目做了逐文件深读（副本在 `_archive_project/`，行号以当日 head 为准）：

- **re-editor**（reqable，43 文件）：自绘 RenderBox + `ui.Paragraph` 直画，**IME 只见一行**
  （`_code_input.dart:472-497` 的 `_buildTextEditingValue`）、controller 持 `TextInputConnection`
  的 `DeltaTextInputClient`（`:442-453`）、结构相等 `TextSpan` 键控的 `ui.Paragraph` 缓存
  （`_code_paragraph.dart:198,250`）、快照链表 undo 带打字合并（`_code_line.dart:1997-2086`）。
  陷阱：viewId 注入 shim、裸 `ViewportOffset` 管线、无上限 undo。
- **super_editor**（superlistapp，head 068a20d）：核心资产是独立包 **`attributed_text`**
  （MIT，纯 Dart ~2.5k 行，无 Flutter 依赖）——marker-pair span bank、`add/toggle/removeAttribution`
  带自动合并与冲突覆盖、copy-based insert/remove 自动平移 span、`collapseSpans` 供渲染；
  `AttributionStyleBuilder` + `computeInlineSpan`（`infrastructure/attributed_text_styles.dart:24`）
  是引擎到 `InlineSpan` 的全部胶水。文档内核/命令管线/工具栏不应取。
- **appflowy-editor**（AppFlowy-IO 6.1.0）：Delta-in-attributes 文本、事务带预计算反转 delta、
  50ms 防抖封历史项、IME 机制（前导哨兵空格、Windows/CJK 合成期不回推
  `setEditingState`、合成期抑制快捷键）。它的 markdown 编解码**静默丢弃颜色/底色**——反面教材。

### 关键事实：flutter_markdown_plus 与 gpt_markdown 都不是编辑器

2026-10-02 另对 `flutter_markdown_plus 1.0.12`（6 文件 2808 行）与 `gpt_markdown 1.3.0`（53 文件 17k 行）
做了逐文件取证：两者都是**单向渲染器**，全包零写回路径（无 TextEditingController/EditableText/
insert/delete/undo）；`package:markdown 7.3.1` 与 plusparse 的 AST 均不携带源码偏移。
它们在 plan_editor 里的位置是**读路径与视觉参考系**，不是编辑内核。flutter_markdown_plus 无采用价值
（AST 无 offset、widget-per-block、GFM-only、全文档重解析）。

## 决策

### 1. 包的定位：属性化文本编辑内核，不是第二个文档框架

`packages/plan_editor` 只装"**正在编辑的那一块文本**"需要的东西：

| 层 | 内容 | 参考 |
| --- | --- | --- |
| `src/editor_mark.dart` | `EditorMark` = 命名属性 + 参数属性（link(url)/textColor(梯名)/backgroundColor(梯名)），与上游 11 种 mark 的可工具栏集对齐 | super_editor `NamedAttribution`/`LinkAttribution` |
| `src/plan_editor_controller.dart` | `PlanEditorController extends TextEditingController`：持 `AttributedText`；**值变更即差分平移 span**（insert 继承跨点样式、delete 收缩）；`buildTextSpan` 覆写（含 composing 下划线）；`toggleMark/queryMarks`（重叠替换语义） | `attributed_text` 引擎 + app 既有 `editText` 平移算法的语义 |
| `src/editor_spans.dart` | `AttributedText → List<InlineSpan>`，样式由调用方注入的 `EditorStyleResolver` 决定（包不认识 dsw_*） | super_editor `AttributionStyleBuilder` |
| 读面 | **不进包**——app 的 `PlanBlockView`（P9 已补全四种样式长相）继续当读面；聊天流继续用 gpt_markdown | — |

### 2. 新依赖：`attributed_text ^0.4.5`（仅作为 plan_editor 的依赖）

MIT、纯 Dart、无 Flutter 依赖、~2.5k 行——它就是 super_editor 自用的 span bank，正是
"(range, name, param)" 的成熟答案。自写一份平移/合并/冲突覆盖引擎是重复造已验证的轮子。
app 本身**不**直接依赖它（只经 plan_editor 间接引入）。appflowy 式 Delta 模型**不取**
（与 `PlanMark` 词表和 `<!-- plan:{json} -->` 信封双轨冲突）。

### 3. 真值通道：打字时字段权威，命令时文档权威

- **打字通道**：字段 controller 是权威——`AttributedText` 在值变更时自平移；`onChanged` 时 app
  把 `controller.attributedText` **整体镜像**进 `PlanBlockDocument.editTextWithMarks`
  （新文档方法：整块替换 text+marks，不做第二次平移计算）。
- **命令通道**（工具栏/undo/slash）：文档是权威——`applyMark`/`editText` 照旧，重建后
  `didUpdateWidget` 把文档 marks **整体推送**进 controller（marks-only 推送不触碰
  `TextEditingValue`，光标不动）。
  这样"两份必须相等的平移计算"不再存在：每条通道只有一个平移引擎。
- 平移算法唯一化后，app 侧 `editText` 的范围算术保留给表格单元格等无 mark 路径。

### 4. 替换范围（P10-a）

`_BlockTextField`（`plan_block_view.dart`）的字段从裸 `TextEditingController` 换成
`PlanEditorController`，ShadInput 外壳不动（`buildTextSpan` 沿
`ShadInput → TextField → EditableText → controller.buildTextSpan` 这条 SDK 缝生效，
SDK `editable_text.dart:5956`）。表格单元格 `_CellField` 保持裸 controller（无 mark）。
编辑中从此可见粗体/斜体/删除线/下划线/键盘码/链接/文本色/背景色。

### 5. 阶段计划（施工表 `docs/plan-editor-capability-design-2026-10-02.md`）

- **P10-a（本批）**：包骨架 + mark 模型 + controller + spans 胶水 + 包内测试；
  app 替换 `_BlockTextField`；`editTextWithMarks`；双向镜像守卫。
- **P10-b**：块级键盘语义（Enter 拆块 / Backspace 合并 / 方向键跨块）、编辑面链接可点、
  焦点与选区跨块行为。
- **P10-c**：单字段整文档（re-editor 式自绘 surface，"IME 只见一个块"的完整版），
  视 P10-a/b 的 IME 实况决定是否需要。
- **P10-d**：三段落点拖拽 + 自动滚动（AC3-18 全量）、系统剪贴板 HTML 互操作（AC3-19 余项）。

### 6. 明确不做

- 不引入 super_editor / appflowy_editor / flutter_quill 任何框架本体（依赖重量与文档模型冲突）。
- 不搬 re-editor 的 viewId shim、裸 ViewportOffset 管线、无上限 undo；不学 appflowy 丢颜色的编解码。
- 不 fork gpt_markdown 补 offset（WidgetSpan 进不了 `EditableText` 的光标世界，fork 无解）。
- `attributed_text` 的 `test` 传递依赖随包自带，不进 app 的 direct 依赖。

## 后果

- 企划编辑面从"纯文本 + 读面富文本"变为**编辑中即富文本**；AC3-3 的 WYSIWYG 行落为"已落（P10-a，
  8 种工具栏 mark）"。MENTION/EMOJI/OBJECT 渲染态 mark 的编辑面插入仍待 P6 对象身份面。
- 新增本地包沿 `board_panel` 先例：不受根仓 lint/format 门禁（根 `analysis_options.yaml` 已排除
  `packages/**`），包内自带 `analysis_options.yaml` 与测试，交付以包内 `dart analyze`/`flutter test`
  为门禁；根仓三门禁照跑不受影响。
- 跨包映射（`PlanMark ↔ EditorMark`）住在 app 侧（`plan_block_view.dart`），包保持对 dsw_*/PlanMark 无知。
- 风险登记：IME composing 与 mark 平移的交互（三个参考项目各自的防御手段已抄进 ADR 决策；
  Windows/CJK 合成期行为需真机走查）；`attributed_text` 升级漂移由包内测试钉住。
- 真机走查项：中文输入法组合期打字、双主题下的 composing 下划线与 mark 色阶、放大文本两档。

## 证据

- `_archive_project/re-editor`（head 当日 shallow）、`_archive_project/super_editor`（068a20d）、
  `_archive_project/AppFlowy-Editor`（01eccc6）三份逐文件研究记录见施工表 §2。
- SDK 缝：`editable_text.dart:5956`（`widget.controller.buildTextSpan`）。
- 两 markdown 包的零写回取证：见 ADR-0044 背景段（全文 grep 结论，行号在研究记录）。
