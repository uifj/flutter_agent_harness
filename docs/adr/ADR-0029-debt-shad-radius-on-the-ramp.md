# ADR-0029: 半径阶梯对 shad 的表面也成立（一枚旋钮 vs 六档）

- **状态**: ACCEPTED（**部分取代** ADR-0002 在 `dsw_shad_bridge.dart` 头部写下的"No radius/geometry"那条故意省略）
- **分类**: DEBT
- **优先级**: P2
- **影响维度**: 观感 / 认知障碍
- **日期**: 2026-09-30
- **来源**: ADR-0028 收尾时顺着同一把尺子量到 shad 侧（登记表观察行）
- **修复 commit**: b8a045b（桥的一枚旋钮 + 两处对话框自报档位）· da35fe8（守卫）

## 背景（Context）

`DswShape` 的头部把档位与职责写死了（`dsw_shape.dart:17-27`）：

```
float     16  a surface that sits above the page rather than inside it:
              the composer card, a dialog, a full-screen settings card.
              ZCode's own composer is `rounded-2xl` = 16px …
shell     12  … dropdown menu, popover
control    8  anything you click: button, field, session row, chip
inner      6  decoration inside a control: row highlight, small badge
```

`float` 已有 6 个读者（`model_settings.dart:1468,2303`、`plan_review_panel.dart:90`、`composer.dart:739`、`input_queue_panel.dart:65`、`approval_panel.dart:86`）——**但本仓库真正的对话框一个都不是 16**：对话框由 shad 画，而 `lib/ui/primitives/confirm_dialog.dart` 里 `DswShape`/`borderRadius` 出现 **0** 次。

`grep -rln "theme.radius" <shadcn_ui-0.56.3>/lib/src/components/` 显示读这枚旋钮的是 dialog / input / card / toast / select / tabs / alert / slider / calendar / time_picker / input_otp / menubar 十二个组件；它的默认值在包源码里钉死：

```dart
// shadcn_ui-0.56.3/lib/src/theme/data.dart:113-114
final effectiveRadius = radius ?? const BorderRadius.all(Radius.circular(6));
```

而 `ShadDialog` 的取值顺序是 `radius ?? effectiveDialogTheme.radius ?? theme.radius`（`dialog.dart:601`）。桥（`dsw_shad_bridge.dart`）当初**故意**不给 `radius`，并把这条写进文件头：

> `* No radius/geometry. The ported shapes … shad's default (6) is left alone so a new component gets the library's own standard instead of a guessed port.`

那条省略写于 shad 表面还没铺开的时期。普查现状（`grep -rn "ShadInput(\|ShadButton\.\|ShadDialog" lib`）：**2 枚 `ShadDialog`**（`confirm_dialog.dart:36` 被 4 个调用点共用、`plan_workspace.dart:514` 的命名框）、**5 处 `ShadInput`**（`model_settings.dart:1969`、`plan_extensions_view.dart:107,119`、`plan_workspace.dart:533`、`git_tab.dart:749`）、以及 `primitives/feedback.dart` 的 Sonner 吐司。于是同一个概念有两处真值：**阶梯说对话框 16，屏幕上 6**；字段阶梯说 `control 8`，屏幕 6。而 6 在阶梯里的职责是"**控件内部的装饰**"（row highlight、小徽标），不是任何表面。

参考实现的数也站在阶梯这边：ZCode 的确认框是 `rounded-2xl` = 16（`packages/ui/src/components/ui/alert-dialog.tsx:48`，同一条还带 `ring-border` + `shadow-2xl`）。

## 决策（Decision）

1. **桥给控制档**：`ShadThemeData(radius: BorderRadius.circular(DswShape.control))`。shad 只有**一枚**旋钮，它只能答一档，就答本仓库 shad 表面里占多数的那一档——字段（5 处）、吐司、以及对话框里那张卡。
2. **不是那个档的表面自己说出来**：两枚 `ShadDialog` 各传 `radius: BorderRadius.circular(DswShape.float)`，注释指回 `dsw_shape.dart:17` 与 ZCode 的 `rounded-2xl`。**不新增第七档**——阶梯头部明写"加一档要改 ADR-0017"，而 16 已经在那儿。
3. **守卫** `test/shad_radius_test.dart` 三条：① 两档亮度下 `dswShadTheme(b).radius == BorderRadius.circular(DswShape.control)`（"6 不是这套设计系统里的任何数"写进 reason）；② **扫 `lib/` 里每一处 `ShadDialog` 构造**，语句内没有 `radius:` 就红并列文件行号——这是"表面自己说出来"这条律唯一的执法方式；③ 真开一次 `showConfirmDialog`，读出 `ShadDialog` 的 `radius` 必须是 `float`，因为 ① 与 ② 都只证明值传到了 widget，没证明它渲染出来。
4. **明确不做**：
   - **不动 `ShadButton` 的角**。`button.dart` 里根本没有 `theme.radius`（它的几何来自 `button.dart:970` 的 `ShadDecoration`），所以旋钮管不到它；要管就得逐点传 `decoration:`，那是另一件事，且 ADR-0024 已经处理过图标按钮的几何。守卫因此**不**声称按钮已上阶。
   - **不把 6 从系统里抹掉**：`inner 6` 的职责（控件内部装饰）照旧，只是它不再替表面说话。
   - **不做 `ShadInput` 的逐点半径**：它读的就是那枚旋钮，桥改完即已上阶，再加调用点参数就是制造第二处真值。

## 后果（Consequences）

- **正面**：对话框 6→16、字段与吐司 6→8，都与 `DswShape` 的文档一致；"对话框是 float 档"从注释变成可执行的事实；下一枚新对话框忘记表态会被守卫拦住。
- **负面/风险**：**可见改动**——两枚对话框与五处输入框、吐司的圆角都变了，真机走查必做（本机无 Screen Recording 权限，截不到应用窗口，这一眼留在登记表"余"里）。桥是**唯一**构造 `ShadThemeData` 的地方（文件头已申明），所以影响面可枚举；对比度不受影响（没有色值改动，`contrast_check` 不需要跑）。
- **中性**：这条**取代**了 ADR-0002 的一条故意省略。省略的理由（"别让新组件拿到一个猜来的数"）并没有被推翻——现在桥给的数是**阶梯里的**，不是猜的；被推翻的只是"把默认值留着"这个选择。`dsw_shad_bridge.dart` 头部已就地改写，不留过期说明。

## 验证（Verification）

- **先红**：守卫跑在未改的树上 `+0 -3`——① 桥的 `radius` 是 `null`（即包默认 6）；② 扫描整份点名两处对话框 `lib/ui/primitives/confirm_dialog.dart: 36`、`lib/ui/plan/plan_workspace.dart: 514`；③ 渲染断言 `Expected: BorderRadius.circular(16.0) Actual: <null>`。
- **后绿**：3/3；`flutter test` `+929 → +932 -2`（净增 3 条就是这个文件），两条既有失败（`app_scope_test` 的 `/var`↔`/private/var`、`plan_workspace_test` 的 `find.text('notes')`）未触碰。
- `dart format --set-exit-if-changed lib test tool spike` 无 diff；`dart analyze --fatal-infos lib test tool spike` → `No issues found!`；`dart tool/check_architecture.dart` → `architecture OK: 7 recorded, 0 new (127 files, 7 rules)`。
- 复跑普查：`grep -rn "ShadDialog" lib | grep -v "radius"` 只剩注释与 export 行。
- macOS debug 已重建并重启（PID 55888）。**肉眼那一眼仍未确认**：本机无 Screen Recording 权限截不到应用窗口，而两枚对话框与五处输入框的圆角正是可见改动——留在登记表"余"里。

## 关联（Links）

- 代码: `lib/theme/dsw_shad_bridge.dart`（`radius` 一项 + 头部那条 omission 改写）· `lib/ui/primitives/confirm_dialog.dart` · `lib/ui/plan/plan_workspace.dart`
- 令牌: `lib/theme/dsw_shape.dart:17-27`（ADR-0017 的阶梯与"第七档要改 ADR-0017"）
- 守卫: `test/shad_radius_test.dart`
- 关联 ADR: ADR-0002（本条取代其桥内省略）· ADR-0017（阶梯）· ADR-0025（令牌必须有读者；本条是"读者的档位没被执行"）· ADR-0028（同一批尺子量到的另一层皮）
