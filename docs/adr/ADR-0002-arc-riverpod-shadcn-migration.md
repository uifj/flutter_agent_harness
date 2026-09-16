# ADR-0002: develop 分支改造为 riverpod + shadcn_ui

- **状态**: IN-PROGRESS（riverpod 读侧 Stage 1–3 + shadcn Stage 4/5a–5c 已落；Stage 4 热替换链 provider 化经论证"保持命令式"关闭，见修订 2；余下为 macOS 真机验收 + 刻意暂缓的深层组件替换）
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

1. **riverpod 版本**：`flutter_riverpod ^3.2.1`（见修订 1——注解模式把整条家族线从 3.3.2 对齐到 3.2.1）。
2. **注解模式（修订 1 取代原"无 codegen"决定）**：见下方修订 1。
3. **shadcn_ui 版本**：`^0.56.3`。
4. **主题路线 A**：`ShadThemeData.custom` 包裹现有 `DswAlias` 令牌——shadcn 出组件架构，dsw 出颜色与字体；dsh 视觉身份不变，118 个语义别名与 97 处 `labelTertiary` 等消费点不重映射。（备选 B"整体采纳 shadcn 调色板"被否：工作量大一档且丢失与上游 design-platform.css 的可 diff 性。）
5. **组件替换范围**：capsule_button→ShadButton、pill→ShadBadge、对话框/菜单/输入/图标按钮/tooltip 按 [审计报告映射表](../design-audit-2026-09.md) 逐项替换；**11 个内容块 primitives（code/diff/read/search/terminal block、disclosure_row、state_dot、row_sweep、head_tail_cap、block_chrome、copy_button）保留自绘**，仅重刷表面令牌——它们是领域表面，shadcn 无对应物。
6. **键盘/语义随迁**：组件替换必须同步消除 `GestureDetector` 交互层（A1 阻断项），shadcn 组件自带焦点与语义。
7. **图标二选一**：shadcn_ui 传递依赖 `lucide_icons_flutter`，与现有直接依赖 `flutter_lucide` 重复——统一到一套（迁移期间可暂容忍并存，收尾前必须合并）。
8. **亮色对比度**：随主题改造一并决策（接受内部工具豁免并书面记录，或引入 AA 修正版别名层）；不在各消费点就地调色。

### 修订 1（2026-09-15，实施启动时）：改用注解模式

用户决策：riverpod 采用**注解模式**（`riverpod_annotation` + `riverpod_generator` + `build_runner`），取代本 ADR 原第 2 条"手写 provider、不引入生成器"的红线遵守。据此产生三个版本事实（pub solver 全量推导，Dart 3.11.5 / Flutter 3.41.9 基线）：

- **riverpod 家族必须整线对齐到 3.2.1**：`riverpod_generator ≥4.0.4-dev.1` 需要 analyzer ^12 → meta ^1.18，与 Flutter 3.41.9 SDK 钉死的 meta 1.17.0 冲突；`≥4.0.6` 需要 Dart ≥3.12；而 `riverpod_generator 4.0.3` 精确依赖 `riverpod_annotation 4.0.2`，后者又钉死 `riverpod 3.2.1`。因此最终解析为 **flutter_riverpod 3.2.1 / riverpod_annotation 4.0.2 / riverpod_generator 4.0.3 / build_runner 2.15.1**——这是 Dart 3.11.5 下唯一自洽的注解线。原决策的 `^3.3.2` 与注解模式互斥，3.3.x 手写线留作 SDK 升级后的重评对象。
- **`riverpod_lint` 当前不可安装**（含指定的 3.1.4）：`≥3.1.6` 要求 Dart ≥3.12；`3.1.4–3.1.5` 要求 analyzer ^12（同上 meta 冲突）；更早版本钉死 riverpod 3.0.x/3.2.0/3.2.1 之外的精确版本。**推迟到 SDK 升级 ADR 落地时一并引入**（与 riverpod 3.4.x、`custom_lint` 同批）。
- **生成文件入库**：`*.g.dart` 随源码提交；`analysis_options.yaml` 排除 `**/*.g.dart` 与 `packages/**`（vendored 副本首次进入 analyzer 视野时一并排除）。genkit 工具 schema 仍是运行时构造（`SchemanticType.from`），与本次 codegen 无关。

该修订同时触发的首个副作用（已在实施提交中处理）：仓库首次通过 `flutter analyze` 门禁后暴露两处潜伏问题——`LucideIcons.trash_2` 在 flutter_lucide 1.45.0 中已更名 `trash`（此前该错误使 git_tab/workbench 两个测试文件**根本无法编译**），以及 13 个 Windows 平台性测试失败（`/bin/bash` 路径、POSIX 路径分隔符、temp 目录锁），均先于本迁移存在，登记于 debt-register。

### 修订 2（2026-09-16）：Stage 4 热替换链保持命令式（provider 化经论证否决）

Stage 4 原设想把 `app_scope.dart` 的 runtime 热替换链改成 provider 刷新。逐行读 `AppScope.save` 后判定：**这条链不该 provider 化，保持命令式组合根**。

证据（`lib/state/app_scope.dart` save 的既定顺序）：

```
build new runtime → _conversation.adoptRuntime(new) → _sideChat.adoptSource(new.side)
→ await _workbench.bindSession(null) → await _sessions.adoptRuntime(new)
→ await replaced.dispose()   // 最后 dispose：它可能还在收尾被这次切换抛弃的那一轮
```

"旧 runtime 最后 dispose" 是刻意的，正是本 ADR「后果」里点名的"流式拆分契约存在被 riverpod 重建语义静默破坏的风险"。而 riverpod 的 provider 在依赖变化重算时经 `ref.onDispose` **在重算那一刻**就销毁旧值，无法把销毁推迟到 N 个 `await adopt*` 之后——provider 化会让 conversation/sideChat 尚在改指新 runtime 时旧 runtime 已被销毁，触发 use-after-dispose 与流式静默断裂。没有干净的 riverpod 生命周期表达能保住这个顺序。

同时：读侧（`settingsDocument`/`workbenchPrefs` + 9 个 per-controller provider）在 Stage 1–3 已全量 provider 化，`appScopeProvider`（keepAlive）已把 scope 挂进容器，runtime 经 `scope.runtime` 可达，无需把它的生命周期搬进 riverpod 来获得 DI 收益。

据此 Stage 4 以"保持命令式"关闭，并补守卫测试 `test/app_scope_test.dart`（`f09576f`）钉住可观测的重建契约：仅改 workspace = 活 setter 不重建、改 model/skills = 重建、改外观 = 永不重建。dispose 顺序本身仍由 `conversation_controller_test.dart` 的流式契约 + 人工评审守。

至此 ADR-0002 的 riverpod 迁移在本机可验证面上**实质完成**；剩余为 macOS 真机 VoiceOver/Full Keyboard 验收，以及刻意暂缓的深层组件替换（composer 主输入 `TextField`、`PopupMenuButton`×7、`Tooltip`×25——与测试耦合更深，见 migration-log 注记）。

### 修订 3（2026-09-16）：shadcn 深层组件替换到此为止（逐条错配证据）

Stage 5b（确认对话框→ShadDialog）、5c（设置带框字段→ShadInput）、5d（git 提交框→ShadInput）已落。逐条读完剩余 C1 站点后判定：**"不回退"的非回退子集已用尽**，其余控件都是手工贴合自定义 chrome 的，换 shad 会回退。证据：

1. **borderless 嵌入输入**（composer 主输入、browser URL 栏、file-tree 搜索、sidechat）：都是 `border: InputBorder.none` 嵌在自定义 chrome 里（卡片/栏自带边框）。`ShadInput` 自带内边距/最小高（即便 `ShadDecoration.none` 也去不干净），塞进这些紧凑行会挤动布局。
2. **紧凑 pill 值选择器**（git 分支 26px pill、composer 审批 pill）：`ShadSelect` 的触发框比 pill 高，会顶高 git 头栏 / composer 行。
3. **Tooltip×25**：skill 明说 ShadTooltip 的 hover 只在子件是 `ShadGestureDetector`/`ShadButton` 时生效；这里每个 Tooltip 包的是 `DswHoverTap`（A1 键盘可达原语，故意用裸 `MouseRegion+FocusableActionDetector`），换 ShadTooltip 会静默破 hover，除非把 DswHoverTap 重接成 shad 手势模型（危及已闭环的 A1）。
4. **Pill**：自定义文字色 + 22px 高的 chip；`ShadBadge` 的 variant/填充模型无法忠实复现。

真正的独立控件（按钮、对话框、带框表单输入）都是 shad 的正当落点，且已全部换完。其余刻意保留为"正确自定义"。shadcn 迁移到此达**自然边界**——与用户"只换不回退"的口径一致。

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
