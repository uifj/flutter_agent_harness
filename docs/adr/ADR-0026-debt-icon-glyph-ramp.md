# ADR-0026: 图标字形只走一把尺寸阶梯（ADR-0024 的下半身）

- **状态**: ACCEPTED
- **分类**: DEBT
- **优先级**: P2
- **影响维度**: 认知障碍 / 生产功能
- **日期**: 2026-09-30
- **来源**: UI 生产化走查（ADR-0024 把"几何留在调用点"留下的一半）
- **修复 commit**: 76f5a58（阶梯与 23 个文件）· 1a4911b（守卫）

## 背景（Context）

ADR-0024 统一了图标**按钮**的原语，但明确把 `size`/`iconSize` 留在调用点——"同一行的控件等高"是按表面成立的事实。剩下的问题是这些数字本身：按 `(^\|[^A-Za-z])size: N,` 扫 `lib/ui`，字形尺寸有 **8 档**：

| 值 | 处数 | 值 | 处数 |
| --- | --- | --- | --- |
| 10 | 1 | 13 | **21** |
| 11 | **7** | 14 | 33 |
| 12 | 16 | 15 | **1** |
| — | — | 16 | 8 |
| — | — | 18 | 4 |

其中 **11/13/15 共 29 处不是决定**：它们是"旁边文字是 12/14px，于是有人随手敲了一个中间值"。参考实现只有四档，且每档与盒子配对——`ZCode-main/packages/ui/src/components/ui/button.tsx:33-37`：`icon-xs` 20px 盒/10px 字形、`icon-sm` 24/12、`icon` 与 `icon-md` 28/14–16、`icon-lg` 32/16。本仓库的 `DswShape` 早就写了 `iconSm = 14.0`（"A small glyph inside a chip or status row"），但只有 1 个读者，其余七档全是自由数字。

这与 ADR-0017 立形状令牌时说的是同一句话：**不在阶梯上的值，会被读成一个它自己并没有表达的决定**。

## 决策（Decision）

1. `DswShape` 命名五档字形：`iconCaption = 10`（贴着 `xxxs` 文字的那一档）、`iconTiny = 12`（密行：树行、芯片、tab 条）、`iconSm = 14`（标准控件字形，`DswIconButton` 的默认值）、`iconMd = 16`（与标签同权重：设置行前导图标、菜单勾选）、`iconLg = 18`（收起后的 rail——旁边没有文字）。
2. 迁移：**11→12（7 处）、13→14（19 处）、15→16（1 处）**；文件树那两枚 `iconSize: 13`（装在 20px 盒子里）**降到 12** 而不是升到 14，因为 14 在 20px 盒里会把控件填满、失去呼吸；本来就是 10/12/14/16/18 的 62 处**像素不变**，只是把数字换成名字。
3. ≥20 的数字（20/24/28 是 `DswIconButton` 的盒子，32/34/40 是空状态与头像的装饰图形）**不是字形档位**，留在守卫的允许表里；盒子尺寸的律是"同一行等高"（ADR-0024），不是这把阶梯。
4. 守卫加在 `test/theme_token_test.dart` 的 `glyphs sit on the icon ramp` 一节：扫 `lib/ui` 里所有 `size:`/`iconSize:` 数字字面量，落在允许表外（11/13/15/17/19…）即红并整行指名。

## 后果（Consequences）

- **正面**：一个 glyph 的大小现在是五个可解释的名字之一，而不是一串 1px 差别的私人偏好；同一行里"这个图标比那个小一圈"不再可能悄悄发生。
- **负面/风险**：29 处变化 1px（27 处变大、2 处变小）。放大文本的十七个面（`amplified_text_probe` 的两档尺子）**全绿**，说明没有任何固定座位被这 1px 顶穿；但 1px 的观感（尤其 composer 里 13→14 的那 10 处）**待 macOS 真机走查**。
- **中性**：`iconCaption` 目前只有 1 个读者（subagent 的那枚 10px 点），它存在的理由是与参考实现的 10px 档对齐；若下一批发现没人再需要它，按 ADR-0025 的律删掉即可。

## 验证（Verification）

- 反向验：守卫先跑在未迁移的树上，红并按文件行号列出 11/13/15 的 29 处；迁移后绿。
- 迁移当场 `every shape token has a reader` 也红了，点名刚加 yet 没人读的 `iconCaption/iconTiny/iconMd/iconLg`——律咬到了作者本人，读者的补齐后绿。
- 门禁四条：format 无 diff、`dart analyze --fatal-infos` 0 条、`flutter test` `+919 -2`（仍只有那两条既有失败）、`dart tool/check_architecture.dart` 无新增。本轮不动颜色，`contrast_check` 不要求。

## 关联（Links）

- 代码: `lib/theme/dsw_shape.dart`（五档字形）、`test/theme_token_test.dart` 的 `glyphs sit on the icon ramp`
- 关联 ADR: ADR-0024（同一枚按钮的上半身）· ADR-0017（形状令牌与"不在节奏上的值就是意外"）· ADR-0025（令牌必须有人读）
