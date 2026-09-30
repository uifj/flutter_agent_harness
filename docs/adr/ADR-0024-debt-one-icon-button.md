# ADR-0024: 图标按钮只有一个原语（三处自绘的分叉收进 `primitives/`）

- **状态**: ACCEPTED
- **分类**: DEBT
- **优先级**: P2
- **影响维度**: 认知障碍 / 生产功能
- **日期**: 2026-09-30
- **来源**: UI 生产化走查（ADR-0021 统一了点击原语，没管它上面那一层）
- **修复 commit**: 596a76a（原语与三处迁移）· 350483e（守卫）

## 背景（Context）

`lib/ui` 里有 **4 枚私有图标按钮类**（`grep -rn "class _\w*Icon\w*Button" lib/ui`）：

| 文件:行 | 类 | 盒子 | 字形 | 形状/半径 | 静止→激活色阶 | 禁用的说法 |
| --- | --- | --- | --- | --- | --- | --- |
| `sidebar.dart:964` | `_IconButton` | 28（宽栏）/36（rail） | 调用点自绘 16–24 | `BoxShape.circle` | 调用点自绘，静止 `labelPrimary` | **没有禁用态** |
| `file_tree_tab.dart:572` | `_IconButton` | 20 | 13 | 方形 `DswShape.inset` | `tertiary → secondary` | 没有 |
| `browser_tab.dart:342` | `_BarIconButton` | 24 | 14 | 方形 `DswShape.inner` | `secondary → primary` | **`enabled` 字段 + 可空 `onTap` 两个真值** |
| `git_tab.dart:1088` | `_RoundIconButton` | 28 | 14 | `BoxShape.circle` | `secondary → primary` | `onTap == null` |

四枚的身体逐字相同（`Tooltip` → `DswHoverTap` → `AnimatedContainer` 悬停底色），分叉全在身体之外的五个决定上。三条最硬的证据：

1. **同一条注释指向两种控件**。`browser_tab.dart:341` 与 `git_tab.dart:1087` 都写着这是"the source's `.iconButton`"，一个画 24px 圆角方形、一个画 28px 圆形。核对参考实现：`_archive_project/ZCode-main/packages/ui/src/components/ui/button.tsx:10,33-37` 是**一个** Button 组件带尺寸变体——base `rounded-md`（6px）、`text-ui-base/relaxed`（静止比悬停暗一档）、`disabled:pointer-events-none disabled:opacity-50`，图标档位 `icon-xs 20 / icon-sm 24 / icon 28 / icon-lg 32` 各配一档字形尺寸。**那个家族里没有圆形**，圆形是把别的控件的 `rounded-full` 当成了它。
2. **`enabled` 与 `onTap` 已经各说一套**。`browser_tab.dart:236,242`：前进/后退传的是非空回调 + `enabled: _cursor > 0` / `enabled: _cursor < _history.length - 1`。"能不能点"由 `enabled` 决定，"长什么样"由另一处决定——正是 ADR-0014 那条"两个必须相等的字段就是一种新的错法"在按钮上的形态。
3. **图标按钮的名字漏进了硬编码**。`file_tree_tab.dart:448` 的 tooltip 写死 `'Refresh'`，而同批的 `browser_tab.dart:254`、`git_tab.dart:692` 都走 `context.tr('refresh')`（该键在双字典里都在：`locales.dart:44`、`:495`）。tooltip 是用户可见文案，按文案律必须进字典。

## 决策（Decision）

1. 新增 `lib/ui/primitives/icon_button.dart` 的 `DswIconButton`，把这五件事收成一处：tooltip 同时就是语义名（`semanticLabel: tooltip` + `excludeSemantics`）、底色只用 `interactiveBgHover`、时长取 `DswMotion.respecting(context, DswMotion.fast)`（ADR-0023 S2 那条律的第三枚实例）、半径由盒子尺寸按 ADR-0017 嵌套律推出、色阶静止 `labelSecondary` → 激活 `labelPrimary`、禁用 `labelCaption`。
2. **禁用只有一个表达：`onTap == null`**。删掉 `enabled` 字段；调用点用三元决定传不传回调（`onTap: _cursor > 0 ? _back : null`）。
3. **形状统一为圆角方形**，`BoxShape.circle` 从这三枚里消失；半径随尺寸：≤20 → `DswShape.inset`(4)，≤ `DswShape.controlMd`(28) → `DswShape.inner`(6)，更大 → `DswShape.control`(8)。依据是参考实现只有一个 `rounded-md` 家族，且 ADR-0017 的半径律本来就按嵌套深度取值——不需要新 tier。
4. **激活含键盘焦点**。`DswHoverTap` 把 hover 与 focus 一起交给 builder，所以 Tab 到按钮时得到与鼠标悬停同一档变亮（ADR-0002 的键盘无障碍面）。
5. **几何留在调用点**（`size`/`iconSize`）：tree 行 20、地址栏 24、git 头 28 各随所在行高，"同一行的控件等高"是按表面成立的事实。本轮只统一风格与判定，不动几何。
6. **`sidebar.dart` 的 `_IconButton` 本轮不收**，allow-list 进守卫。理由：rail 上没有文字，它的三枚图标静止就是 `labelPrimary`，收进来会让导航变暗；且折叠开关在 rail 上从 24px 品牌标记换成 18px 面板图标（`sidebar.dart:486-504`）——同时换形与换字号，为一个调用点加 `hoverIcon` + 两档字号 + 两档色，正是 ponytail 反对的"为假想需求铺抽象"。等真机走查看完再判。

## 后果（Consequences）

- **正面**：三个表面的同一个控件从此一起变脸；`enabled`/`onTap` 双真值消失；圆形/方形分叉结束；文件树的刷新按钮有了中文名。
- **负面/风险**：git 头部与暂存行的按钮由圆形变圆角方形、文件树图标静止时亮一档（`tertiary`→`secondary`）、地址栏按钮开始响应键盘焦点——都是可见变化，**待 macOS 真机走查**。
- **中性**：守卫按文件计数，`lib/ui` 任何角落再自绘一枚私有图标按钮都会直接红；`lib/ui` 里 `BoxShape.circle` 的用量减少一枚（rail 仍用）。

## 验证（Verification）

- 结构：`test/icon_button_test.dart` 扫 `lib/ui` 下 `class _…IconButton…`，断言按文件计数只剩 `{'lib/ui/sidebar/sidebar.dart': 1}`。**反向验过**：迁移前跑它，红并指名三枚 tab 里的类。
- 行为（同文件）：`onTap == null` 时点击不生效、取 `labelCaption`、且悬停也不画底色；可点时悬停得到 `interactiveBgHover` 与 `labelPrimary`。
- 门禁四条 + `dart tool/contrast_check.dart`（本次只把静止色往上提了一档，没有降低任何对比度）。

## 关联（Links）

- 代码: `lib/ui/primitives/icon_button.dart`；`lib/ui/workbench/tabs/{file_tree_tab,browser_tab,git_tab}.dart`
- 关联 ADR: ADR-0021（收的是它下面的点击原语，本条收它上面的图标按钮）· ADR-0017（半径律）· ADR-0023 S2（动效 ramp）· ADR-0014（"两个必须相等的字段"这条判例）· ADR-0008（双字典键）
