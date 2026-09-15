# ADR-0002: develop 分支改造为 riverpod + shadcn_ui

- **状态**: ACCEPTED
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 认知障碍 · 生产功能（键盘/无障碍可达性）· 依赖面扩大
- **日期**: 2026-09-15
- **来源**: 用户决策（develop 分支将使用最新 riverpod 与 shadcn_ui 改造）+ 2026-09 设计层审计（[design-audit-2026-09.md](../design-audit-2026-09.md)）
- **修复 commit**: —（改造实施后回填）

## 背景（Context）

用户决定：`develop` 分支的后续开发采用 **最新 riverpod（状态管理）与 shadcn_ui（组件库）** 改造现有实现。此决定与仓库现行约定存在四处正面冲突，必须以本 ADR 记录取舍：

1. **新依赖红线**：`.qoder/rules/workflow.md` §7 与 AGENTS.md §7 规定"不新增依赖……除非已立 ADR"。riverpod 与 shadcn_ui 均为新增直接依赖。
2. **版本约束（pub.dev 核实，2026-09-15）**：
   - `flutter_riverpod` 最新稳定 3.4.3 **要求 Dart ≥3.12**；本仓库基线是 Dart 3.11.5（`pubspec.yaml` `sdk: ^3.11.5`，Flutter 3.41.9）。
   - `shadcn_ui` 最新 0.56.3（2026-09-03）即 `packages/flutter-shadcn-ui` vendored 副本；约束 Dart ≥3.11 / Flutter ≥3.41，**与当前基线兼容**。
3. **codegen 红线**：riverpod 惯用路径含 `riverpod_generator` + `build_runner`，与"不引入代码生成器"冲突。
4. **shadcn-ui-flutter 守卫**：workflow.md §2 将 `shadcn-ui-flutter` skill 标为"仅参考文档"；改造后它成为**实际组件库**，守卫条件反转。

审计证据（详见报告，均为文件:行号级）：

- 全应用 60 个交互元素全部 `GestureDetector`、`InkWell` 0、`Semantics` 3——键盘与屏幕阅读器不可用（阻断级）。
- 39 处裸 Material 表单控件（IconButton 17 / TextField 6 / TextButton 5 / PopupMenuButton 7 / AlertDialog 4）无 primitives 覆盖，恰为 shadcn 补齐层。
- 亮色主题 6 组正文令牌对比度低于 WCAG AA（最低 1.26:1，dsh 原版调色板固有）。
- state 层为 13 文件 2,194 行手写 ChangeNotifier 体系 + `app_scope.dart`（355 行）组合根；流式拆分是唯一性能契约，由 `test/conversation_controller_test.dart` 守护。

## 决策（Decision）

在 `develop` 分支实施改造，要点如下（版本与主题两条为硬约束决策）：

1. **riverpod 版本**：`flutter_riverpod ^3.3.2`（当前基线可用的最新稳定线）。升到 3.4.x 需先升 Dart SDK，那是独立决策（build.md §0 的版本基线条款），**不在本 ADR 范围内捆绑执行**；待 SDK 升级时另立 ADR。
2. **无 codegen 路线**：手写 `Provider`/`Notifier`，不引入 `riverpod_generator`/`riverpod_annotation`/`build_runner`。守住现有红线。
3. **shadcn_ui 版本**：`^0.56.3`。
4. **主题路线 A**：`ShadThemeData.custom` 包裹现有 `DswAlias` 令牌——shadcn 出组件架构，dsw 出颜色与字体；dsh 视觉身份不变，118 个语义别名与 97 处 `labelTertiary` 等消费点不重映射。（备选 B"整体采纳 shadcn 调色板"被否：工作量大一档且丢失与上游 design-platform.css 的可 diff 性。）
5. **组件替换范围**：capsule_button→ShadButton、pill→ShadBadge、对话框/菜单/输入/图标按钮/tooltip 按 [审计报告映射表](../design-audit-2026-09.md) 逐项替换；**11 个内容块 primitives（code/diff/read/search/terminal block、disclosure_row、state_dot、row_sweep、head_tail_cap、block_chrome、copy_button）保留自绘**，仅重刷表面令牌——它们是领域表面，shadcn 无对应物。
6. **键盘/语义随迁**：组件替换必须同步消除 `GestureDetector` 交互层（A1 阻断项），shadcn 组件自带焦点与语义。
7. **图标二选一**：shadcn_ui 传递依赖 `lucide_icons_flutter`，与现有直接依赖 `flutter_lucide` 重复——统一到一套（迁移期间可暂容忍并存，收尾前必须合并）。
8. **亮色对比度**：随主题改造一并决策（接受内部工具豁免并书面记录，或引入 AA 修正版别名层）；不在各消费点就地调色。

## 后果（Consequences）

- **正面**: 表单控件层获得焦点/语义/状态覆盖（解决审计 A1/A3/C1）；状态管理获得标准化的测试 override 与依赖注入；`shadcn-ui-flutter` skill 从"守卫项"转为正当地位。
- **负面/风险**:
  - 依赖面扩大：shadcn_ui 传递引入 boxy、collection、flutter_animate、flutter_svg、intl、slang、lucide_icons_flutter——其中 intl 与本仓库"自研 i18n、不引 intl"的约定在**直接依赖层面**仍不冲突（仅为传递依赖），但需在 PR 检查中盯住不得直接 import。
  - `app_scope.dart` 的装配链（settings 保存 → runtime 重建 → side chat 重新 adopt）拆 provider 时最容易断链；流式拆分契约存在被 riverpod 重建语义静默破坏的风险。
  - 迁移期双图标库并存（见决策 7）。
  - 39 个测试的 fake 注入方式全部要改写为 `ProviderScope(overrides:)`。
- **中性**: 三条硬不变量不受影响（genkit 边界、model 纯 Dart、state 不 import ui 的 layout_controller 例外照旧）；ADR-0001 的 vendored 副本从"纯参考"升格为"依赖的本地源码镜像"，仍不入库。

## 验证（Verification）

- `flutter pub deps` 中出现 `flutter_riverpod 3.3.x`、`shadcn_ui 0.56.x`，无 `build_runner`/`riverpod_generator`。
- `grep -rn "riverpod_annotation\|part '" lib/` 为空（无 codegen）。
- `flutter test` 全绿，特别地 `flutter test test/conversation_controller_test.dart`（流式契约）。
- `grep -c "GestureDetector(" lib/ui/` 相对 60 大幅下降且剩余项有书面理由。
- `grep -rn "package:genkit" lib/ | grep -v "^lib/genkit/"` 仍为空。
- macOS 真机：Full Keyboard Access 与 VoiceOver 走通「发送 → 审批 → 终端」主流程。
- 视觉回归：无（Windows 侧无法执行），按审计报告 Inconclusive 处理，macOS 验收时人工对照迁移前截图。

## 关联（Links）

- 证据: [docs/design-audit-2026-09.md](../design-audit-2026-09.md)（对比度计算、组件映射表、版本核实）
- 代码: `lib/state/app_scope.dart`（组合根）、`lib/ui/primitives/`（13 自绘件）、`pubspec.yaml`（依赖）
- 关联 ADR: ADR-0001（vendored shadcn 副本不入库——本 ADR 不改变该决定）
- 规则联动: 实施时需同步更新 `.qoder/rules/workflow.md` §2（shadcn-ui-flutter 守卫条件反转）与 AGENTS.md §6；两份镜像同改
