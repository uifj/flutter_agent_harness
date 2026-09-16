# ADR-0004: 亮色主题正文对比度 AA 修正层（提案）

- **状态**: ACCEPTED（采纳方案 B：显式豁免）
- **分类**: CFG
- **优先级**: P1
- **影响维度**: 生产功能（低视力可读性）· 认知障碍（与上游 diff 性）
- **日期**: 2026-09-16
- **来源**: 2026-09 设计层审计 A2（`docs/design-audit-2026-09.md`）
- **修复 commit**: —（方案 B 为决策性关闭，无代码改动；回归门禁 `test/theme_contrast_test.dart` 已落地）

## 背景（Context）

亮色主题下六组正文级令牌对比度低于 WCAG AA 4.5:1（确定性计算，见审计 A2 与 `test/theme_contrast_test.dart`，均已核实为真实消费点）：

| 令牌对 | 现值 | 主要用途 |
| --- | --- | --- |
| `labelDimmed`/`bgBase` | **1.26** | `sidechat_tab:319`、`subagent_tab:798` 时间戳；`model_settings` 禁用/ hint |
| `labelCaption`/`bgBase` | **2.13** | `composer.dart` 主输入占位符等 7 处 |
| `stateSuccessPrimary`/`bgBase` | **2.28** | `diff_block.dart:246` 新增行文字 |
| `stateWarnLabel`/`bgBase` | **2.79** | `model_settings:546,1332` 警示正文 |
| `stateWarnPrimary`/`stateWarnTertiary` | **1.99** | `approval_panel.dart:104-118` **审批条**警示文字+圆点 |
| `labelTertiary`/`bgBase` | **3.71** | 全 UI **97 处**三级文字 |

根因：dsh 原版 `design-platform.css` 的亮色板本身不达标；本项目是 1:1 忠实移植（`dsw_alias.dart:3-5` 把"可与上游 diff"当资产）。**改值即偏离上游**。暗色主题基本达标（仅 `labelDimmed` 1.90 也偏低）。

## 决策（Decision）——二选一，待产品/设计签收

**不盲改调色板**；本 ADR 列两条路线，请求签收其一：

- **方案 A（建议，最小侵入）：只新增语义别名做"AA 修正层"，不动既有 1:1 别名。** 新增 `labelBodyAA`、`stateWarnInk`、`labelTertiaryAA` 等，把六组低值消费点改指新别名；原 dsh 别名保留（其它处与上游 diff 不受影响）。示例目标值（在亮底上 ≥4.5）：
  - 正文类：`labelTertiary` 3.71→用 `neutralBluish700`（即 labelSecondary，5.80）做 AA 档；
  - 警示文字：`stateWarnLabel`/审批条文字改用 `stateWarnPrimary` 的更深一档或 `neutralBluish` 叠加，达 ≥4.5；
  - `labelCaption` 占位符：升到 `neutralBluish700` 级别（占位符仍弱于正文但可辨）。
  - `labelDimmed` 语义为"禁用/hint"，可保留但把**时间戳**这类信息性文字从 `labelDimmed` 改到 `labelCaption`/`labelTertiary`（信息不该用禁用色）。
- **方案 B（显式豁免）**：认定为内部开发工具、非面向公众，接受亮色不达 AA 并**书面豁免**，`theme_contrast_test.dart` 的 allowlist 即豁免清单的机器化。此时不改任何令牌。

无论 A/B：`test/theme_contrast_test.dart` 已作为**回归门禁**先落地（非豁免的新跌破 AA 一律 fail），保证最坏不再恶化。若走 A，实施时逐条从 allowlist 删除对应项——第二个测试会强制你删（它检测"仍在 allowlist 但其实已达 AA"）。

### 决策落点（2026-09-16）：采纳 B（显式豁免）

选 B 不选 A 的实证理由：A 要把 `labelTertiary`(3.71)、`labelCaption`(2.13)、`labelDimmed`(1.26) 全部提到 ≥4.5，在现有 `neutralBluish*` 档位上意味着三者都落到 `neutralBluish700`（=5.80，即 `labelSecondary` 现值）——**亮色三级文字层次会被抹平成同一灰**，且要达 AA 还得比 secondary 更深，进一步压缩层次。这是否需要，取决于产品对"亮色低视力可读"与"dsh 视觉层次"的取舍，需设计肉眼权衡。

据此按 **B 关闭本 ADR**：认定为内部开发工具，接受亮色六项低于 AA 并**书面豁免**——豁免的机器化表达就是 `theme_contrast_test.dart` 的 `_allowlistedDebt`（配第二测试防其腐化）。palette 不改、dsh 1:1 可 diff 性保住。若日后设计愿意接受变暗的层次，可另开 ADR 走 A（新增 `*AA` 别名或调整档位），届时逐条移出 allowlist 即可。本 ADR 状态置 ACCEPTED(B)，不再挂起。

## 后果（Consequences）

- **正面**: A 让低视力键盘用户能读全 UI（含审批把关路径）且不动上游可 diff 性；B 把豁免讲清楚、零风险。
- **负面/风险**: A 引入并行别名有认知成本（"该用 labelTertiary 还是 labelTertiaryAA"）；需一次全量视觉回归（现在可在 Windows 本机跑）。
- **中性**: 不改 genkit/model/state 任何不变量；纯 theme + 少量消费点。

## 验证（Verification）

- `dart tool/contrast_check.dart` 与 `flutter test test/theme_contrast_test.dart`：走 A 则亮色六项达标并从 allowlist 移除；走 B 则 allowlist 不变、本 ADR 状态转 RESOLVED(DEFERRED 豁免)。
- 本机 Windows `flutter run -d windows`，在亮色下肉眼看审批条、diff 新增行、composer 占位符可读性。

## 关联（Links）

- 证据: `docs/design-audit-2026-09.md` A2；`test/theme_contrast_test.dart`
- 代码: `lib/theme/dsw_alias.dart`（light 块）、`lib/ui/conversation/approval_panel.dart:104-118`
- 关联 ADR: ADR-0002（同属 develop 改造线）
