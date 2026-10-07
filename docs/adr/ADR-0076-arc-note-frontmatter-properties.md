# ADR-0076: md 笔记的文档属性（frontmatter）

- **状态**: PROPOSED
- **分类**: ARC
- **优先级**: P2
- **影响维度**: 生产功能
- **日期**: 2026-10-07
- **来源**: 用户产品目标（"md 文档具备文档属性"，对标截图中的 Obsidian「笔记属性」面板：章号/标题/卷/状态/字数目标/视点等键值对）+ 本机 Obsidian vault 实测 + appflowy-editor 调研
- **修复 commit**: —

## 背景（Context）

- **对标事实**：Obsidian 的文档属性 = 文件头部一段 **YAML frontmatter**（`---` 围栏）。本机 vault 实测（`SairMarkDown工具和笔记/00-uifjTemplater/沉浸式阅读笔记模板.md`）：`title/author/category/source/date/status/tags`（tags 为列表）；属性面板是 frontmatter 的结构化视图，`+ 添加笔记属性` 即加一个键。
- **上游事实**：appflowy-editor 的 md 编解码**不支持 frontmatter**（`lib/src/plugins/markdown/` 全目录 grep `frontmatter|yaml` 零结果；`document_markdown.dart:12-55` 的解析器清单里没有对应 parser）——照抄它的 md 通道解决不了这条。
- **本仓事实**：Markdown 是唯一盘上格式（workflow §3），`lib/model/plan_markdown_codec.dart` 负责 md ↔ 块树往返，装不进 md 的块走一行 `<!-- plan:{json} -->` 信封（`0fd88c4`）。块树当前没有"文档级属性"这个概念——属性是块，不是键值对。企划侧另有关系系统（`model/plan_relation.dart` + 数据视图），集合记录的"字段"住在那里。
- **语义待拍板的分叉**：笔记属性与集合关系是两套东西（Obsidian 的 properties 与 Dataview 数据库也是两套，但 Anytype 把两者合成一套 relation）。截图里的"字数目标/状态"既可以只是笔记头部的自由键值对，也可以是对接集合视图的结构化字段。

## 决策（Decision）

**方向（待 ACCEPTED 后细化施工）**：

- **底盘选 YAML frontmatter（选项 A）**：`plan_markdown_codec` 在解码时把文件头部的 `---` 围栏段解析为文档属性表，编码时原样写回头部；块编辑器顶部加"属性"区（键值行 + 添加行，对标截图形态），编辑的仍是盘上那一段 YAML。理由：与 Obsidian 生态互操作（用户的既有笔记直接可读），与信封机制正交（frontmatter 管"文档属性"，信封管"md 装不下的块"），且不发明新盘上格式——编解码不许为"看起来能表达"发明假 md 形状（workflow §3 ③ 的既有律）。
- **备选 B（属性即关系）不选为主案**：把 frontmatter 键映射进 `plan_relation` 体系能让属性直接进数据视图，但会把"自由笔记的头部元数据"强绑到集合模型——用户改一个键要过 store 校验，且 Obsidian 兼容性受损（未声明的键、列表值、任意类型）。可作为后续增强：**声明过的键**（如 `status`）可选关联到某集合的关系，属叠加层。
- **备选 C（只读展示）不选**：截图诉求含编辑（`+ 添加笔记属性`），只读是假门。
- 实施时必须回答的子题（留给施工表）：YAML 的解析器选择（不新增依赖的前提下手写受限子集 vs 立 DEP 类 ADR 引 `yaml` 包——引包须先立 ADR）；`tags` 这类列表值的编辑形态；属性与全文检索/字数统计的接法；信封与 frontmatter 同时存在时的编解码顺序。

## 后果（Consequences）

- **正面（若实施）**：对标目标 8；Obsidian 用户的存量笔记属性可直接读；为"属性→集合关系"的后续叠加留了底盘。
- **负面/风险**：codec 往返多一段要保真的结构（键序、引号风格——YAML 重排会脏 diff）；`yaml` 包引入与否是一个 DEP 决策；frontmatter 段与 agent 写文件（同一批 md）的冲突面与 ADR-0075 ④ 的门交互。
- **中性**：`plan_markdown_codec_test` / `plan_codec_envelope_test` 各加一族。

## 验证（Verification）

实施后：codec 往返断言（frontmatter 段逐字节保真，包括用户手写的引号风格）；块编辑器属性区增删改键 → 盘上 YAML 同步；Obsidian 产出的真实笔记（含中文键、列表值）可开可存。四道门禁同口径。

## 关联（Links）

- 代码: `lib/model/plan_markdown_codec.dart`（信封先例）、`lib/ui/plan/blocks/plan_block_editor.dart`（属性区挂点）
- 关联 ADR: ADR-0037（块编辑器与 md 内核）、ADR-0075（自动保存——属性编辑同样走脏+防抖链，不另做保存机制）
- 研究: `_archive/appflowy-editor/lib/src/plugins/markdown/document_markdown.dart:12-55`（无 frontmatter 的实证）、本机 `.obsidian` 模板实测
