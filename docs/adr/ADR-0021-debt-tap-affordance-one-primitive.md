# ADR-0021: 一处按钮只用一套原语，鼠标之外还得有键盘

- **状态**: ACCEPTED
- **分类**: DEBT（键盘可达性回归 + 缺结构守卫）
- **优先级**: P1（影响真实使用：键盘用户点不到这五枚控件）
- **影响维度**: 生产功能 / 安全合规（可访问性）
- **日期**: 2026-09-30
- **来源**: 「每处按钮和 ui 逻辑也要统一风格」的普查（承接 ADR-0002 的 A1 键盘可达条目）
- **修复 commit**: 501dd93（五处改造）· c70ded2（结构守卫）

## 背景（Context）

`lib/ui/primitives/tappable.dart:1-18` 的头部注释把历史写得很清楚：在 `DswHoverTap` 之前，**每一枚** hover-and-tap 控件都自己手搓同一套 `MouseRegion` + `GestureDetector` + `setState(_hovered)` 三连，而"那套三连是 mouse-only：不进 focus traversal，所以 Space/Enter 永远到不了它，VoiceOver 看到的只是一个没有 button 角色的文本节点"。2026-09 的审计把这件事记成 A1 与 A3 两条阻断项，`DswHoverTap` 用 `FocusableActionDetector` + `Semantics(button/onTap)` 一次解决，并由 `test/dsw_hover_tap_test.dart` 证明它的四性（指针／键盘／语义／右键）。

这次为了"按钮统一风格"逐原语普查 `lib/ui`，发现**同一个三连又长回来了五处**：

```
grep -rn "GestureDetector(" lib/ui（排除注释，只看带 onTap 的顶层参数）
  lib/ui/app_frame.dart:576                     外壳那组 32px 圆形面板开关（tooltip 有，键盘无）
  lib/ui/workbench/free_window_layer.dart:376    自由窗口标题条的 20px 关闭键（连名字都没有）
  lib/ui/workbench/pane.dart:359                 空 pane 的欢迎动作（图标 + 标签的描边按钮）
  lib/ui/plan/plan_workspace.dart:383            企划头部的切换工作区图标
  lib/ui/conversation/composer.dart:1866         文档 chip 上那枚移除 x
```

同一次普查的两条对照事实：`DswHoverTap` 已有 **63** 处调用，而这三连全部五处都是 `StatefulWidget` **只为存一个 `_hovered`**。也就是说它们不但少了键盘与语义，还各自多养了一份状态——删掉之后 `app_frame.dart`、`free_window_layer.dart`、`pane.dart` 那三个 State 类整个消失（净删代码）。

另外三条**看着像问题、其实不是**的观察，记下来免得下次再查一遍：`settings_quick_menu.dart:115` 是点击别处收起的 scrim（键盘出路是菜单自己的 `CallbackShortcuts` Escape，即审计 F3）；`pane.dart:127` 是"把下一次打开瞄准到这个 pane"的**区域**手势，不是控件；`workbench_tab_bar.dart:443` 的 tab 芯片**已经自带** `FocusableActionDetector` + `Semantics(selected:)`（见该文件 `:415-419` 的注释）——它要的角色是 selected 而不是 button，所以**故意不走** `DswHoverTap`。横向拖拽分栏（`app_frame.dart:404/462`、`split_view.dart:157`）没有键盘等价物，是另一件事，见"明确不做"。

## 决策（Decision）

1. **五处全部换成 `DswHoverTap`**，并遵守仓库既有的两枚约束：图标即控件必须自报姓名（`semanticLabel` + `excludeSemantics: true`，与 `details_panel.dart:228-233` 的 `Tooltip` + `DswHoverTap` 同一写法），以及"hover 亮起来"的那一档**同样给 focused**——键盘用户该拿到和鼠标用户一样的可见反馈（`tappable.dart` 的 builder 本来就把 `focused` 交出来）。三处因此从 `StatefulWidget` 降回 `StatelessWidget`。
2. **不新增逐站键盘测试**。四性由 `dsw_hover_tap_test.dart` 证明**一次**，换到该原语上的控件继承这份证明；给每枚按钮再补一条 Enter 断言是重复劳动。
3. **立一条结构守卫**：`test/tap_affordance_test.dart` 扫 `lib/ui/**.dart`，找"顶层参数里带 `onTap`/`onTapDown` 的 `GestureDetector`"，要求结果**恰好等于**一份带理由的白名单（primitive 自身 + scrim + pane 区域 + tab 芯片）。三点设计选择：按**文件**而不是行号记（行号会随着上方任何改动漂移）；计数而非只判存在（同一文件多长一枚也拦得住）；深度从 `GestureDetector(` 那一记开始数，否则 `builder: (context, …) => GestureDetector(` 会把外层的 `builder(` 多算一层——这条在本 ADR 落地时踩过，pane 那处白名单差点因此被漏掉。
4. 守卫写成 **widget 测试文件**而不是 `check_architecture` 的第 8 条规则：那个工具的判定是**单行正则**，判不出"这个 `onTap:` 属于 detector 还是属于它的孩子"。先例是 ADR-0017 的圆角守卫也放在 `theme_token_test.dart` 里做源码扫描。

明确不做：① **不给分栏拖拽加键盘缩放**（要新立产品决策：方向键改哪一栏、步长多少、与焦点栏如何配合；且这类"键盘等价物"是新增交互面，不是把已有控件接回原语）；② **不把 tab 芯片改写进 `DswHoverTap`**（角色不同，见上）；③ 不引入 `shadcn_ui` 的 `ShadIconButton` 去替换这三枚圆形图标钮——它们是嵌在自绘 chrome 里的**裸 affordance**，`tappable.dart:16-18` 已写明"decorated button 会挪动像素"这条判别的先例（`CapsuleButton` 那种真装饰钮才走 shad）。

## 后果（Consequences）

- **正面**：键盘用户现在能打开/收起侧栏与工作台、能关自由窗口、能选空 pane 的动作、能切企划工作区、能摘掉一个文档附件；这五枚控件在 VoiceOver 里第一次有 button 角色和名字（其中自由窗口的关闭键此前**任何**辅助技术都读不到）；三处状态类整删，`lib/ui` 里手搓三连的控件从 5 降到 0；白名单把"为什么这三处可以留着"写在了代码旁边，下次不必重新判断。
- **负面/风险**：焦点顺序会变——新加进 traversal 的五枚控件占据 Tab 位，用户可能感到"Tab 变长了"；`focused` 与 `hovered` 同档亮色，意味着键盘用户看到的高亮和鼠标用户一样，不做额外焦点环（`DswHoverTap` 依赖 `FocusableActionDetector` 的 `focusNode`，视觉表达就是这档亮色，不是描边环）；**结构守卫是源码扫描，不是渲染证明**——它能拦住"又写了一枚 mouse-only 的钮"，拦不住"用 `DswHoverTap` 但把 `onTap` 传了 null"这类语义误用（那属于 `unlabelledIconControls` 与人工评审的活）。
- **中性**：改造后 `grep -rn "GestureDetector(" lib/ui` 剩 **8** 处（普查时是 13），其中 **4** 处带 tap 且都在白名单里（原语自身、快捷菜单 scrim、pane 区域、tab 芯片），另 **4** 处是纯拖拽把手（`app_frame.dart:405/463` 两条分栏、`split_view.dart:157`、`free_window_layer.dart:262` 窗口移动）——**守卫必须判"带不带 tap"，而不是"有没有 GestureDetector"**，否则这四处合法用法要么被误拦，要么逼着人往白名单里塞四行无关的理由。`DswHoverTap` 的调用从 63 涨到 **68**（正好 +5），`MouseRegion` 的条目数没当作事实引用：原语自己内部也用 `MouseRegion`，那个数不说明任何事。

## 验证（Verification）

- `flutter test test/tap_affordance_test.dart` 绿；**反向验过**：往 `lib/ui/workbench/` 放一枚新的 `GestureDetector(onTap: …)` 立刻红并指名 `'lib/ui/workbench/_scratch_probe.dart': 1`，删掉恢复。
- `flutter test test/dsw_hover_tap_test.dart` 仍绿（四性的那份证明没被动）。
- 改造前后**行为不变**：`flutter test` 由 `+908 -2` 到 `+909 -2`（净增就是这条守卫），那 2 个失败仍是 `app_scope_test` 的 `/var`↔`/private/var` 与 `plan_workspace_test` 的 `find.text('notes')`，未被触碰。`app_frame_test`／`workbench_ui_test`／`free_window_layer_test`／`plan_workspace_test`／`composer_test` 全绿，说明五枚控件的点击、右键、拖拽、悬停路径都在原断言下保持不变。
- 门禁同口径：`dart format --set-exit-if-changed lib test tool spike`（0 changed）、`dart analyze --fatal-infos lib test tool spike`（No issues found!）、`dart tool/check_architecture.dart`（7 recorded, 0 new, 7 rules）。
- **待 macOS 真机走查**：`Tab` 走完外壳与工作台时的实际焦点顺序、以及"聚焦即亮"在真实光标下够不够显眼。键盘可达这件事在 widget 测试里是结构证明，手感仍要人确认。

## 关联（Links）

- 依据: ADR-0002 的 A1 键盘可达 / A3 语义（`docs/debt-register.md` "A1 键盘可达——已闭环"一节）· `docs/ui-production-audit-2026-09.md` §4（ZCode 按钮布局与"组件用 shad、配色用 dsw"的分工）
- 关联 ADR: ADR-0017（同族的"守卫扫源码"先例；以及"一个状态一枚 token"——focused 与 hovered 同档）· ADR-0018（外壳 chrome）· ADR-0020（同一批普查里另一条"只用一套原语"：反馈条）
- 代码: `lib/ui/primitives/tappable.dart`（唯一原语，63 处调用）· 五处改造点 `lib/ui/app_frame.dart`、`lib/ui/workbench/free_window_layer.dart`、`lib/ui/workbench/pane.dart`、`lib/ui/plan/plan_workspace.dart`、`lib/ui/conversation/composer.dart` · 守卫 `test/tap_affordance_test.dart` · 命名检查 `test/amplified_text_probe.dart` 的 `unlabelledIconControls`
