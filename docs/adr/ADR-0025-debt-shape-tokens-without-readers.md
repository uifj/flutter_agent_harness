# ADR-0025: 形状令牌不许只有定义没有读者（`DswShape` 的 ADR-0022）

- **状态**: ACCEPTED
- **分类**: DEBT
- **优先级**: P2
- **影响维度**: 认知障碍 / 生产功能
- **日期**: 2026-09-30
- **来源**: UI 生产化走查（ADR-0024 之后把同一把尺子转向主题层）
- **修复 commit**: 6ec20df（删六枚 + 接回会话行）· 18662f1（守卫）

## 背景（Context）

ADR-0022 的判据是"除定义与设置页外必须有读取点"，本次把它对准 `lib/theme/dsw_shape.dart`。普查（可复跑）：对每个 `static const` 名字在 `lib/ test/ tool/ spike/ packages/` 里搜 `DswShape.<名字>`，排除定义文件本身——

| 令牌 | 读取点 | 处置 |
| --- | --- | --- |
| `gapXs` / `gapSm` / `gapMd` / `gapLg` | 0 | 删 |
| `rowInset` | 0 | 删 |
| `dot`（6.0，"A dot that marks state"） | 0 | 删 |
| `hitSlop`（4.0，"Extra transparent hit area around a small control"） | 0 | 删 |
| `rowSession`（36.0，"A session row in the sidebar"） | 0，**而 `sidebar.dart:536/845` 两行自己写着 `height: 36 * step`** | 接上 |

`dot` 与 `rowSession` 说明"零读取"有两种病，得分别治：

- `dot`：状态点的几何**只有一个家**——`ui/primitives/state_dot.dart:19` 的 `size = 10`，核心半径取 `size * 0.6`（`:65`，注释自己写着"a 6px core on the 10px dot"）。`DswShape.dot = 6.0` 是**同一件事的第二种拼法**（一个是盒子、一个是核心，单位还不一样），留着只会被下一个人当成"点应该是 6px"去改。删。
- `rowSession`：令牌说的是对的数，**读它的那两处偏偏没读**——侧栏会话行与新会话条都用字面 `36` 乘字号步长。这不是"多余令牌"而是"令牌被绕过"，正是 ADR-0017 立形状令牌要防的那件事。接上。

另：`controlMd`（28）与 `iconSm`（14）在 ADR-0024 之前分别只有 1 个和 0 个读取点，`DswIconButton` 用它们当默认盒子与默认字形后各自有了读者——那两枚**不需要**动，本轮只登记为"已被 ADR-0024 救活"。

## 决策（Decision）

1. 删除 6 枚从未被读过的复合/说明性常量（四个 `gap*`、`rowInset`、`dot`、`hitSlop`）。基础步长 `xs/sm/md/lg/xl` 保留（各自仍有 2–5 个读取点）。
2. `sidebar.dart` 两行 `36 * step` 改读 `DswShape.rowSession * step`，把"会话行多高"收回一处。
3. 守卫写在 `test/theme_token_test.dart` 新加的 `every shape token has a reader` 一节：解析 `dsw_shape.dart` 的 `static const` 名字，逐个要求在 `lib/` 其余文件里出现 `DswShape.<名字>`；解析不到任何令牌也算失败（防止正则烂掉后空守卫自证通过）。

## 后果（Consequences）

- **正面**：`DswShape` 里每一条声明现在都能指出读它的界面；会话行高度改一处即全侧栏生效。
- **负面/风险**：`hitSlop` 被删掉了"小控件命中区太小"这个**未解问题**的记号——20px 的文件树图标按钮命中确实偏小。本轮按 ADR-0022 的先例处理：先删空话，问题作为待立条目留在登记表观察表里，真要修就为它立 ADR（它会动行高，属几何）。
- **中性**：`dot`/`rowSession` 一删一接，说明"零读取"必须先读代码再决定，不能一律当垃圾删。

## 验证（Verification）

- 反向验：加守卫时树上仍有 7 枚零读取令牌，它当场整份点名 `Actual: ['gapXs', 'gapSm', 'gapMd', 'gapLg', 'rowInset', 'dot', 'hitSlop']`；删/接完转绿。
- `dart analyze --fatal-infos lib test tool spike` 0 条；`dart format --set-exit-if-changed` 无 diff；`flutter test` 全量；`dart tool/contrast_check.dart`（本轮未动颜色）。
- 复跑普查：`grep -rn "DswShape\.<名字>" lib \| grep -v "^lib/theme/dsw_shape.dart"` 对每个声明的名字都非空。

## 关联（Links）

- 代码: `lib/theme/dsw_shape.dart`、`lib/ui/sidebar/sidebar.dart:536,845`、`test/theme_token_test.dart`
- 关联 ADR: ADR-0022（同一判据，那边是设置字段，这边是主题常量）· ADR-0017（形状令牌的由来与半径律）· ADR-0024（把 `controlMd`/`iconSm` 救活的那一批）
