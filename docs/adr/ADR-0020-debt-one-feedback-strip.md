# ADR-0020: 反馈条只有一把，长在 shad 的 Sonner 上

- **状态**: ACCEPTED
- **分类**: DEBT（观感统一 + 缺验证）
- **优先级**: P2（不影响正确性，影响"商用观感"与"每个功能都要验证"）
- **影响维度**: 生产功能 / 认知障碍
- **日期**: 2026-09-30
- **来源**: UI 生产化审计（`docs/ui-production-audit-2026-09.md` §4 的"结合 shadcn_ui 统一风格"面）+ 一次逐原语普查
- **修复 commit**: —

## 背景（Context）

普查 `lib/ui` 的交互原语，Material 那套只剩一种，而且正好是最显眼的那种：

```
grep -rn "ScaffoldMessenger\.\|SnackBar(" lib/   → 9 处调用点（本 ADR 采纳前）
  lib/ui/conversation/composer.dart:416   模型不收图时的拒绝（ADR-0010 的能力门）
  lib/ui/tool/tool_card.dart:268          rewind 的报告与逐文件跳过理由（ADR-0014）
  lib/ui/plan/plan_workspace.dart:460,485 重名文件 / 重名目录
  lib/ui/workbench/tabs/editor_tab.dart:307 保存失败
  lib/ui/settings/model_settings.dart:1330,1339,1357,1366 备份/恢复的成功与失败
```

同一普查里 shad 与自研原语有 127 处（`ShadButton|ShadInput|ShadDialog|DswHoverTap|CapsuleButton…`，29 个文件）。也就是说**其余交互面都已经走桥接后的 `DswAlias` 配色，只有这 9 处仍由框架自己画**：Material 的圆角、`Typography`、动画、暗底条，全都不在 `lib/theme/dsw_*` 的词表里。

三条让它比"又一处不一致"更严重的证据：

1. **这 9 处是用户最常遇到的反馈**：保存失败、备份结果、重名、写入被拒、能力门拒绝。它们是"应用有没有听懂我"的主要证据面，却是唯一不受设计系统约束的表面。
2. **零覆盖**：`grep -rn "SnackBar\|ScaffoldMessenger" test/` 结果为空——但反过来，`rewind_pill_test` 与 `composer_test` 里有 5 条断言按文案去找那条提示。它们此前能过，是因为 `MaterialApp` 自带 `ScaffoldMessenger`，**提示确实在树上**；一旦宿主换了承载方式，这 5 条立刻红——这条事实被本次改动当场证实（见"验证"）。
3. shad 的 Sonner **已经在依赖里**（`shadcn_ui 0.56.3`，`lib/src/components/sonner.dart` + `toast.dart`），`ShadToastVariant` 只有 `primary`/`destructive` 两档；`theme/dsw_shad_bridge.dart` 已把 `ShadColorScheme` 逐字段映射到 `DswAlias`。所以这不是"引新依赖"，而是把已有依赖的最后一个面接上。

对照 ZCode：`grep -i toast _archive_project/ZCode-main/package.json` 无命中——它没有 toast 库可抄。因此位置取 shad 自己的默认（`Alignment.bottomRight`），**这是一处有意的偏离**：Material 的 `SnackBar` 贴左下且横满宽度，Sonner 在右下堆叠、最多 3 条、可悬停驻留。

## 决策（Decision）

1. **一个入口**：新增 `lib/ui/primitives/feedback.dart` 的 `showFeedback(context, message, {destructive})`。这是 `lib/` 里唯一允许出现"把消息交给用户看"这件事的地方；调用方只给文案与"是不是失败"。
2. **承载用 shad 的 Sonner**，两档变体直接沿用库的语义：`destructive: true` → `ShadToast.destructive`（备份失败、保存失败、重名、能力门拒绝），其余 → 默认 `primary`。文案字体仍取 `DswType.s14`——**组件用 shad，排版仍用 dsw**，与 ADR-0002 的约束一致。
3. **宿主挂在 `main.dart` 的 `MaterialApp.builder`**，顺序是 `MediaQuery(步子) → ShadTheme → ShadSonner → Navigator`。两条理由：步子必须挂在 Navigator 之上（ADR-0017 S3 的 overlay 律），而 `ShadSonner` 必须在这条子树之上，弹出的 toast 才会既拿到桥接配色又拿到用户的字号档。**同一个缝**已经住着字号、`ShadTheme`、窗口标题服务，不再新开一处装配点。
4. **没有 `ShadSonner` 的宿主就丢掉提示**（`maybeOf` + return），沿用此前 `ScaffoldMessenger.maybeOf` 的行为，previews 与不关心提示的 widget 测试不会被一枚 toast 崩掉。代价是"提示是否送达"必须由**挂了 strip 的宿主**来证明，所以本 ADR 同时立第 5 条。
5. **进门禁**：`tool/check_architecture.dart` 第 **7** 条规则 `one-feedback-strip`（`appliesTo: lib/`，`pattern: ScaffoldMessenger\.|SnackBar\(`）。存量已经清零，所以这条是**绝对断言**而非 baseline 豁免——与 ADR-0017 圆角律同一口径（"存量一次清完就可以做成硬断言"）。

明确不做：不引第三方 toast 包；不给 toast 加图标/动作按钮/进度（没有消费者，`ShadToast` 的 `action` 先不接）；不把 `Tooltip`／`PopupMenuButton` 一起换掉——它们是 material 里**没有**桥接问题的部分（`Tooltip` 无表面绘制、`PopupMenuButton` 的下拉菜单已被 ADR-0017 的座位律接管并量过），换它们只制造 diff。

## 后果（Consequences）

- **正面**：用户最常看到的反馈条第一次和它报告的界面同源——配色走 `dsw_shad_bridge`、圆角走 `DswShape` 档位、高度跟用户的字号档走；"成功还是失败"有了两档可分辨的形状而不是同一块黑条；`lib/ui` 的 Material 交互原语计数从 1 降到 **0**；提示可达性从"没有测试"变成 5 条断言 + 1 条门禁。
- **负面/风险**：位置从左下横条变成右下堆叠卡片，是一处**可见的**行为改变（有意的统一，不是回归），需要真机走查一眼；宿主若忘记挂 `ShadSonner`，提示会被静默丢掉——由"挂了 strip 的宿主才有 5 条断言"这条纪律承担，门禁只能保证代码不再回到 material。9 个调用点里成功/失败的判定靠调用方传 `destructive`，**这条分类本身没有机器可验的真值**（只有人眼能看出"这是不是失败"）。
- **中性**：`check_architecture` 从 6 条规则变 7 条（`architecture OK: 7 recorded, 0 new (126 files, 7 rules)`）；`tool/architecture_baseline.json` 未变（新规则贡献 0 条记录）。

## 验证（Verification）

- **反向验过（门禁）**：把 `tool_card.dart` 的 `_report` 改回 `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` 并原样跑 `dart tool/check_architecture.dart` → `NEW VIOLATION one-feedback-strip: lib/ui/tool/tool_card.dart`；恢复后回到 `architecture OK: 7 recorded, 0 new (126 files, 7 rules)`。
- **守卫**：`test/feedback_test.dart` 四条——① 提示把调用方给的文案画上屏，并且会自动退场；② `destructive` 与默认变体**可分辨**（两侧都点名：`ShadToastVariant.primary` vs `.destructive`，只断"不相等"会在默认也是 destructive 时空转）；③ 没有 strip 的宿主不崩也不画；④ 1.8x／2.2x 两档下 `textDefects` 为空，且**先量 1.0 再量放大档**，断言提示那一行确实变高了——这条是给宿主自己设的哨兵：`chat_view_test` 刚刚因为宿主自己写了一枚新的 `MediaQueryData` 而把 `textScaler` 抹掉、量着 1.0 报通过（见 ADR-0017 关联段）。
- **改造当场自证**：把 `composer_test`／`rewind_pill_test` 的宿主按 `main.dart` 挂上 `ShadSonner` 之前，全量套件是 `+903 -7`——**新增的 5 条红正是那 5 条按文案找提示的断言**，说明"提示送达"此前是被 `MaterialApp` 的默认 messenger 顺带满足的，而不是被设计并验证的。挂上之后回到只有登记的 2 条失败。
- 门禁同口径：`dart format --set-exit-if-changed lib test tool spike`（0 changed）、`dart analyze --fatal-infos lib test tool spike`（No issues found!）、`flutter test` = **`+908 -2`**（那 2 条为 `app_scope_test` 的 `/var`↔`/private/var` 与 `plan_workspace_test` 的 `find.text('notes')`，均为登记项，未被本次改动触碰）。
- **待 macOS 真机走查**：右下堆叠、最多 3 条、悬停驻留的实际观感，以及"备份成功"这类提示在真实窗口里的位置是否合适。本条不可由 widget 测试替代。

## 关联（Links）

- 依据: `docs/ui-production-audit-2026-09.md` §2（条 4「边界不清」同一条观感律）· §4（ZCode 令牌与组件分工：组件用 shad、配色用 dsw）
- 关联 ADR: ADR-0002（riverpod + shadcn 迁移，本 ADR 是它"最后一个 material 交互面"的收口）· ADR-0011/0015（`check_architecture` 规则与 baseline ratchet 的先例）· ADR-0017（S2 一个状态一枚 token；S3 座位随字号长，第 4 条断言就是它的应用）· ADR-0014（rewind 的报告措辞与确认框同源，本次只换承载不换措辞）· ADR-0010（能力门拒绝的提示）
- 代码: `lib/ui/primitives/feedback.dart`（唯一入口）· `lib/main.dart:212-218`（宿主挂载缝）· `tool/check_architecture.dart`（规则 7）· `test/feedback_test.dart`
