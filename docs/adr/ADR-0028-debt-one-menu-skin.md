# ADR-0028: 菜单只有一层皮（`popupMenuTheme` 缺席，Material 自己填了一遍）

- **状态**: ACCEPTED
- **分类**: DEBT
- **优先级**: P2
- **影响维度**: 观感 / 认知障碍 / 生产功能
- **日期**: 2026-09-30
- **来源**: UI 生产化走查（用户 §二「下拉菜单」条目；ADR-0025 已指出 `DswShape.shell` 的注释把 "dropdown menu" 写成自己的表面）
- **修复 commit**: 1adc254（主题层）· f34d097（守卫）

## 背景（Context）

`lib/theme/dsw_theme.dart` 里从来没有 `popupMenuTheme` 这一项（`grep -n "popupMenuTheme\|menuBarTheme\|dialogTheme\|cardTheme" lib/theme/dsw_theme.dart` 无匹配），而 `lib/ui` 用的是 Material 的菜单：**13 个入口、7 个文件**——

| 形式 | 位置 |
| --- | --- |
| `PopupMenuButton` 7 处 | `settings/model_settings.dart:1438,2410` · `workbench/workbench_tab_bar.dart:158` · `conversation/composer.dart:1276,1379,1606` · `workbench/tabs/git_tab.dart:1036` |
| `showMenu` 6 处 | `conversation/hero_workspace_picker.dart:154` · `workbench/workbench_tab_bar.dart:482` · `workbench/free_window_layer.dart:308` · `workbench/tabs/git_tab.dart:462,525` · `workbench/tabs/file_tree_tab.dart:383` |

`popup_menu.dart:785-795` 的取值顺序是 `widget.route.color ?? popupMenuTheme.color ?? defaults.color`；调用点普查显示**没有一处**传 `color:`/`shape:`/`elevation:`（`composer.dart:1232,1758` 那两枚 `shape: BoxShape.circle` 是头像盒，不是菜单），所以 13 个入口全部落在 `_PopupMenuDefaultsM3` 上：`color => _colors.surfaceContainer`（`:1856`）、`shape => 4.0px`（`:1865`）、`elevation: 3.0`（`:1835`）、标签 `labelLarge`。

本仓库的 `ColorScheme` 只显式给了 `surface` 与 `surfaceContainerHighest`（`dsw_theme.dart:142-144`），**没给 `surfaceContainer`**——它是 Material 从中性色带算出来的，不在这 89 枚别名里。实测（改动前用一次性探针跑出后删除）：

| 主题 | 菜单实测填充 | 它等于 | 自家 popover 用的 |
| --- | --- | --- | --- |
| dark | `rgb(0.1373, 0.1373, 0.1412)` | **`bgLayer1`**（页面本身） | `bgLayer2` `rgb(0.1725, .1725, .1804)` |
| light | `rgb(1, 1, 1)` | **`bgLayer1`**（light 三层塌成白，ADR-0017 已断言 `bgLayer1 == bgLayer3`） | `bgLayer2` `rgb(0.9765, .9804, .9843)` |

也就是说菜单展开时，**它的底色和它浮在上面的那一层是同一个颜色**——只有 Material 的投影在区分两者。用户 §一 抱怨的"缺乏容器化质感、边界不清"在菜单上是最直白的一次：`settings_quick_menu.dart:141-147` 的自家浮层早就给了答案（`bgLayer2` + `DswShape.shell` 圆角 + `borderL2` 发丝边框），而同一含义的另一个表面什么都没拿到。

同一批里另外两处不一致：

1. **圆角**：`dsw_shape.dart:21-22` 的注释写着 `shell 12 … workbench panel, dropdown menu, popover`——律已经写在令牌上，主题没执行，菜单渲染 4px。ADR-0025 收的是"令牌没有读者"，这条是它的镜像：**读者没拿到令牌**。
2. **字重**：M3 菜单标签走 `labelLarge`，本主题把它映射成 `DswType.sStrong14`（w500）。自家 popover 的动作行是 `DswType.s14` 常规字重（`settings_quick_menu.dart:361`）；ZCode 的下拉行是 `text-ui-base` 常规（`styles.css:58` 的 `--ui-font-size: 14px`，`dropdown-menu.tsx:82`）。菜单因此比它两侧的真行**更粗**。
3. **悬停**：`PopupMenuItem` 内部自建 `InkWell`（`popup_menu.dart:461`，调用点碰不到它的颜色），`ink_well.dart:1040` 回落到 `ThemeData.hoverColor`；实测值是黑@3.92%（light）/白@3.92%（dark），不是 ADR-0021 那把原语用的 `interactiveBgHover`（light 为 `Color.fromRGBO(38, 49, 72, 0.06)`）。ZCode 同样把菜单悬停做成调色板项（`--color-menu-hover: var(--color-neutral-100/900)`，`styles.css:246,395`）而不是一层黑纱。

## 决策（Decision）

1. **`popupMenuTheme` 落进主题层**（`dsw_theme.dart`，紧跟 `tooltipTheme`）：`color: c.bgLayer2`；`shape: RoundedRectangleBorder(borderRadius: DswShape.shell, side: BorderSide(c.borderL2))`；`labelTextStyle` 按状态给 `DswType.s14`，禁用态 `labelTertiary`。发丝边框能表达是因为 `_ShapeBorderPainter.paint`（`material.dart:973`）直接 `border.paint(...)` 且不传 `borderColor`，于是 `RoundedRectangleBorder.side` 生效——`PopupMenuThemeData` 没有 `borderSide` 字段这一说法是错的，它只是把边框让给了 shape。
2. **`labelTextStyle` 一旦设置就接管禁用态**（`popup_menu.dart:417` 的顺序里主题项在 Material 自己的 dimming 之前），所以分支必须自己写；不写就出现"灰不溜秋"变"照常黑"。守卫专门断言禁用态，就是为了让这条不可见的路径有读者。
3. **投影保持 Material 的 3.0**：`PopupMenuThemeData` 只能表达 elevation，表达不了 `DswShadow.lv3` 那种 box-shadow 列表，而**投影是改动前唯一把菜单和页面分开的东西**——在发丝边框之外再把它归零，等于把视觉分离度换了一种坏法。颜色/圆角/边框/字重这四项才是"错了"的部分。
4. **`hoverColor: c.interactiveBgHover` 放在 `ThemeData` 上**，一行。不做逐点 `InkWell(hoverColor:)`：菜单项的 InkWell 是 `PopupMenuItem` 私建的，调用点根本没有这个参数可传。
5. **守卫**：`test/menu_chrome_test.dart` 亮/暗两档各 4 条主题断言（填充、圆角+发丝、常规/禁用字样式、悬停 wash），外加 1 条真开一遍菜单的渲染断言——用 `elevation > 0` 认出那一层浮起的 `Material`（Scaffold 的是 0），再验它的 `color`/`shape`。渲染这条存在的意义是：主题项写了不等于挂上了。
6. **明确不做**（各有可能，但没有一项是"小修"）：
   - **行高 48px**：`PopupMenuItem` 的默认 `height = kMinInteractiveDimension` = 48.0（`constants.dart:27`），`PopupMenuThemeData` 没有对应的字段，`visualDensity: compact` 也进不到那个 `ConstrainedBox`。要收就得给 44 个条目各写一遍 `height:`，或者造一枚 `DswMenuItem` 原语——那是另一条律、另一个 ADR。**已按"登记不修"进观察表**（与 20px 图标命中区那条同一族：触摸尺寸与指针尺寸的冲突）。
   - **`menuPadding`**：Material M3 的 `vertical: 8`（`popup_menu.dart:1866`）与自家 popover 的 `EdgeInsets.symmetric(vertical: 8)`（`settings_quick_menu.dart:143`）已经是同一个数，主题里再钉一遍今天什么也不改（ADR-0025 的反面教训：不写没有读者/没有效果的项）。
   - **`dialogTheme`/`cardTheme`/`menuBarTheme`**：本仓库没有 Material 对话框（`primitives/confirm_dialog.dart:6-7` 说明确认框已换成 shad 壳），也没有 `MenuAnchor`/`MenuBar`。给没有表面的东西加主题项，正是 ADR-0025 拦的那类。
   - **禁止调用点覆盖的皮肤守卫**：做不到。`color:` 在菜单条目的**子树**里是正当写法（图标配色），按行扫描必然误报。改由渲染断言钉住一个真表面，其余留给走查。

## 后果（Consequences）

- **正面**：13 个入口与自家 popover 共用一层皮；菜单在**两个主题里都第一次**有了与页面不同的底色（此前实测与 `bgLayer1` 逐通道相同）；圆角回到令牌写的 12；标签字重与它两侧的真行一致；悬停 wash 与 ADR-0021 的原语同源。
- **负面/风险**：这是**可见改动**——真机走查必做（亮/暗各开一次 tab 条 `+` 菜单、文件树右键、git 菜单、composer 模型/审批菜单、hero 工作区选择器）。亮色下菜单从纯白变成 `#F9FAFC` 而它旁边的 `bgLayer1` 仍是白，分离是新增的；暗色从 `#232324` 抬到 `#2C2C2E`。文字对 `bgLayer2` 的对比就是 popover 已经在用的那一对，`dart tool/contrast_check.dart` 复跑无新增（仍是 9 对低于 4.5，全在 light 的已知豁免面内，dark 无回归）。
- **中性**：`hoverColor` 是全局项，任何未显式给色的 Material `InkWell` 都会取到令牌；本应用里这类表面基本就是菜单行。架构门禁不变（`check_architecture` 7 recorded, 0 new）。

## 验证（Verification）

- **先红**：守卫跑在未改的树上 → `+0 -9`。失败输出把两处实测错值并列出来：渲染那条 `Expected: Color<(1.0, 0.1725, 0.1725, 0.1804)> Actual: Color<(1.0, 0.1373, 0.1373, 0.1412)>`（`bgLayer2` vs 实测的 `bgLayer1`），悬停那条 `Expected: (0.06, 0.149, 0.1922, 0.2824) Actual: (0.0392, 0, 0, 0)`（`interactiveBgHover` vs Material 的黑纱）。
- **后绿**：`test/menu_chrome_test.dart` 9/9；套件 `+920 → +929 -2`，净增 9 条正是这个文件，既有两条失败（`app_scope_test` 的 `/var`↔`/private/var`、`plan_workspace_test` 的 `find.text('notes')`）未触碰。
- `dart format --set-exit-if-changed lib test tool spike` 无 diff；`dart analyze --fatal-infos lib test tool spike` → `No issues found!`；`dart tool/check_architecture.dart` → 7 recorded, 0 new；`dart tool/contrast_check.dart` 同上无新增。
- macOS debug 重建并重启，肉眼确认（本 ADR 合入时回填 PID 与结论）。

## 关联（Links）

- 代码: `lib/theme/dsw_theme.dart`（`popupMenuTheme` + `hoverColor`）· `lib/ui/settings/widgets/settings_quick_menu.dart:141-147`（第二意见）· 13 个入口见上表
- 守卫: `test/menu_chrome_test.dart`
- 关联 ADR: ADR-0025（令牌必须有读者——本条是读者没拿到令牌）· ADR-0021（悬停 wash 只有一枚令牌）· ADR-0017（形状阶梯与 light 三层塌陷）· ADR-0004（对比度豁免面）· ADR-0024/0027（同一族"一处概念只有一处真值"）
