# ADR-0027: 样式名不许对它渲染的字号撒谎（`DswType` 的第二处真值）

- **状态**: ACCEPTED
- **分类**: DEBT
- **优先级**: P2
- **影响维度**: 认知障碍 / 幻觉源 / 生产功能
- **日期**: 2026-09-30
- **来源**: UI 生产化走查（ADR-0026 之后，同一把尺子转向字号）
- **修复 commit**: ea0c3bb（五处归位）· d7a721a（守卫）

## 背景（Context）

`DswType` 的 UI 阶梯是 Figma 导出的逐值移植（`dsw_typography.dart:80-100`：24/20/16/16/14/13/12/11，每档配 line-height 与 weight，`strong` 变体是 w500）。律与形状令牌同一条：取名字，不要取数字。

但 `lib/ui` 里存在**五处"拿一个名字、渲染另一个数"**的写法（守卫扫出，`DswType.<名>.copyWith(fontSize: N)` 且 N ≠ 该档声明的数）：

| 位置 | 名字说 | 实际渲染 | 备注 |
| --- | --- | --- | --- |
| `sidebar.dart:474` | `l20` | 18（height 24/18、w600、.04em） | 注释自己写着"dsh 唯一在令牌阶外排版的地方" |
| `tool/tool_card.dart:407` | `xs13` | 11（height 16/11） | 阶梯里就有 `xxxs11` |
| `conversation/details_panel.dart:202` | `xs13` | 12（height 18/12、w500） | 与 `xxsStrong12 = _ui(12, 18, w500)` **逐参数相同**，等于把已有的一档重新拼了一遍 |
| `conversation/approval_panel.dart:141` | `s14` | 15（height 24/15、w500） | 15 不在 UI 阶梯上 |
| `conversation/conversation_root.dart:287` | `xl24` | 26（height 32/26、w500） | 26 不在 UI 阶梯上 |

危害不是观感，是**读数**：后来的人在 `xs13` 下面看到 `fontSize: 12`，要么以为阶梯有 12 档、要么以为这行是 13px；这正是 ADR-0022 那条"一条自我辩解的注释仍是一枚假开关"的排版版本——`sidebar` 那处确实靠注释承认了自己不在阶上。

`lib/ui` 另有 4 处 `fontSize:` 数字是给 mono 面用的（`CodeEditorStyle`/`MarkdownCodeBlockTheme` 的构造参数按 double 取：`editor_tab.dart:90,442`、`plan_workspace.dart:601`、`assistant_markdown.dart:134`）。它们不属于这次的分叉：**那里没有"名字"**可撒谎，且编辑器正文与行号沟必须同高（`_gutter` 的注释说明了这点）。

## 决策（Decision）

1. 三处**改用阶梯里已有的档**，像素不变：`details_panel` → `DswType.xxsStrong12`（本来就是 12/18 w500）；`tool_card` → `DswType.xxxs11`（11 档，line-height 16/11 仍显式写出，因为它是刻意的松行）；`sidebar` 品牌字 → 新档。
2. 两处**把数收进主题层并命名**，像素不变：`DswType.brand18 = _ui(18, 24, w600)`、`panelHeadline15 = _ui(15, 24, w500)`、`heroTitle26 = _ui(26, 32, w500)`。这三档是 Figma 导出之外的，按本文件已有的先例登记（`markdownCodeBlockSmall` 就写着"Hand-added upstream (not from the Figma export)"）——数留在主题里受阶梯的律管，调用点只取名字。
3. 守卫写成**谎言检测器**（`theme_token_test.dart` 的 `a style name never lies about its size`）：从 `dsw_typography.dart` 解析 `static final <名> = _(ui|code)(<数>,` 建立档位表，再扫 `lib/ui` 里 `DswType.<名>.copyWith(` 之后六行内的 `fontSize: N`，N 不等于该档声明值就红并两数并列指名（`DswType.l20 (=20) renders 18`）。档位表解析不到 10 条以上也算失败——防正则烂掉后空守卫自证通过（同 ADR-0025）。
4. **不做**：不给 mono 面造档（它们没有可撒谎的名字，且编辑器/沟同高是另一条律）；不动 12 处 `FontWeight.wNNN` 字面量（其中多数是在已有档上补 weight，名字并未说错尺寸——属于可读性优化，不是两处真值）。

## 后果（Consequences）

- **正面**：`DswType.<名>` 现在**保证**渲染出那个名里的数；阶梯多出的三档在主题层可见、可比、受守卫管。
- **负面/风险**：**零像素变化**——五处改的都是同一数值的另一种写法（新档的 size/height/weight 与原 `copyWith` 逐参数相同），因此不需要真机走查来确认观感，只需要守卫与全量套件确认没有算错（已做：`+920 -2`，既有两条失败未变）。
- **中性**：`brand18`/`panelHeadline15`/`heroTitle26` 三枚是"手加档"，若下一批把它们换成已有档，守卫不会反对；它会反对的是再写一个 `copyWith(fontSize: …)`。

## 验证（Verification）

- 反向验：守卫先跑在未修的树上，红并逐条并列两个数——`l20 (=20) renders 18`、`xs13 (=13) renders 11`、`xs13 (=13) renders 12`、`s14 (=14) renders 15`、`xl24 (=24) renders 26`。
- 复跑普查：`grep -rn "DswType\.\w*\.copyWith($" lib/ui -A6 | grep "fontSize:"` 为空。
- 门禁四条（format / analyze `--fatal-infos` / `flutter test` / `check_architecture`）+ `theme_token_test.dart` 24 条全绿。

## 关联（Links）

- 代码: `lib/theme/dsw_typography.dart`、`lib/ui/{sidebar/sidebar,tool/tool_card,conversation/details_panel,conversation/approval_panel,conversation/conversation_root}.dart`
- 关联 ADR: ADR-0017（阶梯与令牌的律）· ADR-0022（"注释承认"不等于真值）· ADR-0026（同一批里字形尺寸的阶梯）· ADR-0025（令牌必须有读者）
