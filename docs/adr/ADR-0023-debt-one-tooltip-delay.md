# ADR-0023: 提示气泡的出场延迟只有一处真值

- **状态**: ACCEPTED
- **分类**: DEBT（同一枚 chrome 在应用里有三种速度）
- **优先级**: P2（不阻断使用，但"鼠标划过哪一行哪一行就弹"是能看见的不一致）
- **影响维度**: 生产观感 / 可访问性（瞬时气泡对抖动指针的用户是噪声）
- **日期**: 2026-09-30
- **来源**: 「每处按钮和 ui 逻辑也要统一风格」——ADR-0021 那轮普查里剩下的一枚 Material 原语（`Tooltip`）
- **修复 commit**: b4e4810（令牌 + 主题 + 删 19 处）· 401b017（守卫）

## 背景（Context）

`lib/ui` 里 `Tooltip(` 共 **30** 处（`grep -rn "Tooltip(" lib/ui --include='*.dart'`）。按"往后的 8 行里有没有 `waitDuration`"分开数：**19 处自己写了延迟，11 处没写**。

```
自己写的 19 处：  15 × Duration(milliseconds: 500)   4 × Duration(milliseconds: 600)
没写的 11 处：    composer.dart:1222 · details_panel.dart:228 · input_queue_panel.dart:143
                 diff_tab.dart:723,755 · editor_tab.dart:362,601,631 · file_tree_tab.dart:587
                 git_tab.dart:1107 · workbench_tab_bar.dart:706
```

"没写"不是"跟着主题走"。Flutter 的取值顺序写在 `packages/flutter/lib/src/material/tooltip.dart:542`：

```dart
hoverDelay: widget.waitDuration ?? _tooltipTheme.waitDuration ?? _defaultWaitDuration,
```

而本仓库的 `tooltipTheme`（`lib/theme/dsw_theme.dart:162`）只给了 `decoration` 与 `textStyle`，**没给 `waitDuration`**；`_defaultWaitDuration` 是 **`Duration.zero`**（同文件 `:394`）。所以那 11 处是**鼠标一碰到就弹**。

三条必须一起记住的事实：

1. **这 11 处恰好全在最容易被扫过的表面上**：tab 条（`workbench_tab_bar.dart:706`）、文件树行（`file_tree_tab.dart:587`）、git 行（`git_tab.dart:1107`）、diff 行（`diff_tab.dart:723,755`）、编辑器那三枚图标（`editor_tab.dart:362,601,631`）、队列条与详情栏。横向划过 tab 条=每过一个 tab 闪一次气泡；而下栏侧栏**同样形状的行**要等 500ms。同一类产品里两种行为，用户读到的是"应用有时很吵"。
2. **500 与 600 的差不是设计**。四个 600ms 里没有一处说明为什么它要慢 100ms；`grep -B3 "milliseconds: 600" lib/ui` 出来的只有 `workbench_tab_bar.dart:448`（tab 芯片）与 `composer.dart` 的两枚投递药丸——它们与 500ms 那批的差别不是内容差别。
3. **ZCode 的画法支持"一处真值 + 一处具名例外"**：它的 tooltip 组件默认 `delayDuration = 0`（`packages/ui/src/components/ui/tooltip.tsx:9`），而唯一刻意加了延迟的地方把那 1500ms 提成了**文件顶部的具名常量**（`SidePaneTabTitleTooltip.tsx:5` `SIDE_PANE_TAB_TOOLTIP_DELAY_MS = 1_500`），不是散在每个调用点。它没有"每个按钮自己决定"这一层。

`Tooltip` 也是 ADR-0020 之后 `lib/ui` 里**仅剩的 Material 交互原语**（census：`IconButton`/`TextButton`/`Switch`/`Checkbox`/`PopupMenuButton`/`InkWell` 等全部 0 处，`Tooltip` 30 处）。它的**配色已经**走 `DswAlias`（`tooltipBg`、`labelPrimaryForeground`、圆角 `DswShape.inner`），所以这里不是"换成 shad 组件"的问题，而是**同一枚 chrome 的时序没有真值**——与 §3 那条"两个必须相等的字段就是一种新的错法"是同一族问题，只不过这次是 30 个字段。

## 决策（Decision）

1. **延迟进主题，调用点全部删掉**。`lib/theme/dsw_motion.dart` 加一枚 `DswMotion.tooltipDelay = Duration(milliseconds: 500)`（取现存量最大的一档，也是 `app_frame`/侧栏/设置页已经在用的值），`lib/theme/dsw_theme.dart` 的 `TooltipThemeData` 里 `waitDuration: DswMotion.tooltipDelay`；19 处 `waitDuration:` 从调用点删除（ponytail 第 6 级：这件事一行就能说完，就不该说 19 行）。
2. **不做 reduced-motion 归零**。`DswMotion.respecting(...)` 是给**动画**用的；提示延迟不是动画，把指针"穿过"变成"立即弹"正是投诉源。这枚常量因此**故意不进** `respecting()`，理由写在它自己的注释里——否则下一个人会"顺手统一"。
3. **例外必须具名**。以后真有某处要更慢（比如 ZCode 那 1500ms 的 tab 标题），做法是在**那个文件顶部提成常量并写明为什么**，而不是就地写一个魔数；守卫允许这种"文件里先声明常量再传"的写法吗——不允许，见第 4 条。当前没有任何一处需要例外，所以守卫写成绝对的一条：**`lib/ui` 里不出现 `waitDuration`**。将来真需要，就再立 ADR 放宽，别提前留口子（这是 ADR-0021 那张白名单的反面教材：**先按零例外写，例外要挣**。）
4. **守卫**：`test/tooltip_timing_test.dart` 三条结构断言。① `lib/ui/**` 任何文件里出现 `waitDuration` 即红（延迟只允许住在 `lib/theme/`）。② 两档亮度下 `dswThemeData(b).tooltipTheme.waitDuration` 必须**等于那枚令牌**（不是字面量、也没丢）。③ `DswMotion.tooltipDelay > Duration.zero`——没有第三条，前两条会在有人"统一成 0"之后一起绿，而 0 正是投诉本身。**原计划的第四条"悬停后量气泡出现时刻"被实测证伪并撤掉**：widget 测试里的合成指针不启动 `Tooltip` 的 hover 计时器，那条断言永远不会红（逐步计数写在"验证"段）。这是本仓库"新面必须反向验一遍"律第一次抓到一个我自己写的假行为测试——它写在守卫的头部注释里，免得下一个人补回来。

明确不做：① 不动 `showDuration`/`exitDuration`（没有任何调用点覆盖它们，也没有可观察的不一致，加进主题就是给没人用的旋钮镀金）；② 不把 30 处 `Tooltip` 换成 `ShadTooltip`（配色/圆角/字色已由 `tooltipTheme` 走 `DswAlias`，换组件只会重写一遍已经对的东西；ADR-0002 的"组件用 shad、配色用 dsw"针对的是**装饰钮与输入件**，提示气泡在 Material 侧没有越界）；③ 不动 `padding`/`offset`（本机无法截图，看不见就不能签收，见 ADR-0019 那条平台不变量）。

## 后果（Consequences）

- **正面**：划过 tab 条、文件树、git/diff 行不再逐行闪气泡，与侧栏/设置页同一条 500ms；一个数字在 tree 里只出现一次；19 处调用点变短，`lib/ui` 少 19 行。
- **负面/风险**：那四处原本 600ms 的气泡快了 100ms（无人能察觉，但若有人真觉得某个 600ms 是刻意的，他得重新论证并具名，而不是回滚整条律）；瞬时弹出改成 500ms 后，**靠"悬停即出现"写的 widget 测试**要多 pump 一跳才会看见气泡——本次实测 `flutter test` 没有新增失败（各面测试原本就用 `pumpAndSettle` 或显式 `pump(duration)`）。
- **中性**：守卫拦得住源码里的 `waitDuration:`，拦不住有人给 `TooltipThemeData` 再塞第二个延迟值——那条由 `theme_token_test.dart` 的"令牌只在 dsw_* 上"覆盖面兜住，不是这层的活。

## 验证（Verification）

三条守卫**各自反向验过**（`flutter test test/tooltip_timing_test.dart` 三次红、每次指对地方）：

- 主题那半：删掉 `waitDuration: DswMotion.tooltipDelay` → `Expected: Duration:<0:00:00.500000>  Actual: <null>`。
- 令牌那半：把 `DswMotion.tooltipDelay` 改成 `Duration.zero`（前两格仍然全绿，正是这条存在的理由）→ `Expected: a value greater than Duration:<0:00:00.000000>  Actual: Duration:<0:00:00.000000>`。
- 源码那半：`lib/ui` 里出现一枚 `waitDuration:` → `Actual: ['lib/ui/app_frame.dart:566']`（这一格是撞出来的：清理反向试验时用了一次 `git checkout` 把本文件自己的未提交删除也退了回去，守卫当场把那一行指了出来——反向验证与一次真实教训同一条证据）。

**原计划的"悬停量气泡"那一半被证伪并撤掉**（这是本次唯一一次"测试看起来是行为验证、其实是空的"）：把主题值删掉、让 Material 退回 `Duration.zero` 之后，那一半**仍然全绿**。逐步计数（同一枚 `Tooltip`，`find.text(message).evaluate().length`）：`after startGesture: 0` → `after 1 frame: 0` → `after 400ms: 0` → `after settle: 1`。也就是说 widget 测试里的合成指针**不会启动 `Tooltip` 的 hover 计时器**，"400ms 时还不该出现"这条断言永远为真。行为那半于是写成上面三条结构断言 + SDK 取值顺序的引用（`tooltip.dart:542`/`:394`），观感仍归真机走查。这件事写进守卫文件头部，避免下一个人再补一条假行为测试。

- `flutter test` 全套 `+910 → +913 -2`（净增就是那三条），那 2 个失败仍是 `app_scope_test` 的 `/var`↔`/private/var` 与 `plan_workspace_test` 的 `find.text('notes')`。**没有一条既有测试因为延迟改变而需要改断言**——19 处里 15 处本来就是 500ms（同值），4 处从 600ms 变 500ms，11 处从 0 变 500ms，而既有测试要么用 `pumpAndSettle`，要么本来就不依赖气泡出现。
- 门禁同口径：`dart format --set-exit-if-changed lib test tool spike`（206 files, 0 changed）、`dart analyze --fatal-infos lib test tool spike`（No issues found!）、`dart tool/check_architecture.dart`（`architecture OK: 7 recorded, 0 new (126 files, 7 rules)`）。
- `lib/ui` 的净变化：**11 个文件 −19 行，0 行新增**（`git diff --stat`），主题侧 +1 令牌 +1 赋值。
- **待 macOS 真机走查**：横向划过 tab 条与文件树时气泡不再逐行闪（这一眼与 ADR-0019/0020/0021/0022 那几处并成一次走查）。

## 关联（Links）

- 依据: `packages/flutter/lib/src/material/tooltip.dart:394,542`（默认值与取值顺序）· `_archive_project/ZCode-main/packages/ui/src/components/ui/tooltip.tsx:9` 与 `app-shell/SidePaneTabTitleTooltip.tsx:5`（一处默认 + 一处具名例外）
- 关联 ADR: ADR-0020（`lib/ui` 里 Material 交互原语的清零，`Tooltip` 是最后一枚且配色已合规）· ADR-0021（同一轮普查；那条允许挣来的例外白名单，这条先按零例外写）· ADR-0004（动效/颜色令牌的归属层）
- 代码: `lib/theme/dsw_motion.dart`（`tooltipDelay`）· `lib/theme/dsw_theme.dart:162`（`TooltipThemeData`）· 19 处调用点 · 守卫 `test/tooltip_timing_test.dart`
