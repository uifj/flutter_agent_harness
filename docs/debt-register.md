# 技术债与缺陷登记表（debt-register）

本文件是本仓库**唯一的状态源**：所有已登记问题的分类、优先级与当前状态在此总览，细节与证据在下钻的 ADR 里。修改规则、分类、状态机见 [README.md](README.md)。

## 已登记

| 编号 | 标题 | 分类 | 优先级 | 状态 | 日期 | ADR |
| --- | --- | --- | --- | --- | --- | --- |
| ADR-0001 | vendored `packages/flutter-shadcn-ui` 不进版本库 | DEP | P2 | RESOLVED @ d72ff4c | 2026-09-15 | [链接](adr/ADR-0001-dep-vendored-shadcn-ui.md) |
| ADR-0002 | develop 分支改造为 riverpod + shadcn_ui | ARC | P1 | IN-PROGRESS（修订 1：注解模式，riverpod 家族 3.2.1） | 2026-09-15 | [链接](adr/ADR-0002-arc-riverpod-shadcn-migration.md) |
| ADR-0003 | 增加 Windows/Linux 桌面平台目标（本机可验证） | ARC | P2 | RESOLVED @ 54e75d7 | 2026-09-16 | [链接](adr/ADR-0003-arc-windows-linux-platforms.md) |
| ADR-0004 | 亮色正文对比度 AA 修正层（A 新增 AA 别名 / B 显式豁免） | CFG | P1 | PROPOSED（待签收；回归门禁已先行落地） | 2026-09-16 | [链接](adr/ADR-0004-cfg-light-contrast-aa.md) |

> 2026-09-15 设计层审计（方法：design-review 插件手动审查模型）产出了完整证据链，见 [design-audit-2026-09.md](design-audit-2026-09.md)。阻断级/ majors 的处置归属：键盘无障碍（A1/A3）与表单控件缺口（C1）并入 ADR-0002 实施；A2（对比度）与文本缩放留下方观察表。

## ADR-0002 迁移进度（截至 2026-09-15）

- **riverpod**：Stage 1-3 完成——boot stores 经 `ProviderContainer` override（38a9949）、`AppScope` keepAlive provider（5d5aa75）、9 个 per-controller provider + read seams、`main.dart` 转纯 Consumer 树（178f941）。riverpod import 仅限 `main.dart` + `state/app_providers.dart`。
- **shadcn_ui**：Stage 4 主题桥 `theme/dsw_shad_bridge.dart`（DswAlias→ShadColorScheme，2511804）；Stage 5 CapsuleButton→ShadButton（45ddfb8）。
- **A1 键盘可达**：新增 `primitives/tappable.dart` 的 `DswHoverTap`（`FocusableActionDetector` + `MouseRegion` + `Semantics(button,onTap)`，零绘制），已收编块原语 4 + 私有图标按钮组 4 + tab strip 关闭/分屏 + settings 控件 7 + git/sidechat/diff/editor 叶按钮 + subagent 根卡。**`lib/ui` `GestureDetector` 60 → 35**；转换项均 Tab 可聚焦 / Enter·Space 激活 / VoiceOver 读 button·toggled。

## A1 键盘可达——进度与剩余（2026-09-16）

`lib/ui` 手写 `MouseRegion+GestureDetector` 交互从 **60 降到 26**（`DswHoverTap` 内部那个不算，即 **25 处手写交互件已收**，全部 Tab 可聚焦 / Enter·Space 激活 / VoiceOver 读 button·toggled·selected）。已收：capsule、4 块原语、4 私有图标按钮组、tab strip 关闭/分屏、settings 7 控件、git/sidechat/diff/editor 叶按钮、subagent 根卡、file-tree 行、hero、back-to-bottom、panel close、inspect。`_TabChip` 用附加式 `FocusableActionDetector`+`Semantics(selected)` 加键盘与 tab 语义，内部拖拽/中键/右键菜单原样保留。

剩余分类（都不该在无交互验证下盲改）：

| 类别 | 站点 | 数 | 说明 |
| --- | --- | --- | --- |
| 合法保留（非按钮） | `app_frame`/`split_view`/`pane`/`free_window` | ~8 | 分隔条拖拽/面板改尺寸/自由窗移动，本就 pointer 拖拽 |
| 输入相邻，需真机验 | `composer.dart` | 5 | 主输入 `TextField`（Material 本可访问）+ 模型座/mention，触及输入/IME |
| 复合行 | `model_settings.dart` | 4 | provider/editor/server 卡内复合行 |
| 复合行 | `subagent_tab.dart` | 3 | 子节点卡选择 + `Listener` kill 确认态 |
| 右键菜单 | `diff_tab` `_FileHeader`、`git_tab` | 2 | 折叠行/行右键 context menu |
| 终端 | `terminal_tab` | 1 | 终端聚焦/滚动，语义特殊 |
| 已加键盘但保留 GD | `workbench_tab_bar` `_TabChip` | 1 | 见上 |

> 收这批的前提已具备（App 现能本机 Windows 跑，ADR-0003）；正确姿势是边改边用 Full Keyboard Access + VoiceOver 在屏幕上验，需要人眼，故留作交互签收轮，非盲扫。

## 待立 ADR 的观察

以下是已经确认存在、但尚未走完"提案 → 批准"流程的问题。**修任何一个之前先补 ADR 并置 ACCEPTED**（纪律见 [README.md](README.md)）。

| 现象 | 证据 | 建议分类 | 建议优先级 |
| --- | --- | --- | --- |
| 测试套件不可在 Windows 移植（13/657 失败） | 2026-09-15 首次在本机跑全套：`shell_run_test` 8 个（写死 `/bin/bash`）、`editor_tab_test` 1 个（temp 目录删除遇 Windows 文件锁 errno 32）、`git_tab_test` 2 个与 `workbench_ui_test` 2 个（tab id / 断言用 POSIX 路径分隔符拼接 `support.path`）。全部先于 riverpod 迁移存在；其中 git_tab/workbench 4 个此前被 `trash_2` 编译错误掩盖（该错已修）。macOS 上的全绿仍是权威门禁；本机门禁为"相对基线零新增失败" | TST | P1 |
| 亮色主题 6 组正文令牌对比度低于 WCAG AA | 确定性计算（`tool/contrast_check.dart` / `test/theme_contrast_test.dart`）：`labelDimmed` 1.26、`labelCaption` 2.13、`labelTertiary` 3.71（97 处）、`stateWarnLabel` 2.79、审批条 `stateWarnPrimary` 1.99（`approval_panel.dart:104-118`）、`stateSuccessPrimary` 2.28。dsh 原版调色板固有。**已升格为 [ADR-0004](adr/ADR-0004-cfg-light-contrast-aa.md)（PROPOSED，A 加 AA 别名 / B 显式豁免二选一）；回归门禁 `theme_contrast_test.dart` 已先行落地（非豁免的新跌破 AA 即 fail）** | CFG | P1 |
| 无文本缩放适配 | `textScaler|textScaleFactor` 全仓库 0 处；disclosure_row 等自绘件固定高度（24px header），macOS 辅助功能放大文本时裁切 | DEF | P2 |
| i18n 双语对齐无守卫 | `lib/l10n/locales.dart:11-13` 注释声称 en 会"在 test 时对照校验"，但 `grep -rn "enStrings\|zhStrings" test/` 零命中；当前键集恰好对齐（不写死条数，加键即失真故刻意省略），纯靠手动维持 | TST | P2 |
| `README.md` 仍是 Flutter 包模板 | 文件通篇 `TODO:`，无一句项目说明；新人和代理拿它当入口会拿到零信息 | DEBT | P2 |
| macOS 分发缺口 | `CODE_SIGN_IDENTITY = "-"`、无 `DEVELOPMENT_TEAM`、未配 hardened runtime / `notarytool` 公证 → 产物只能本机运行；且 `.gitignore` 缺 `*.p12`/`*.cer`/`*.mobileprovision`，一旦有人放证书就会入库 | CFG | P1（若要对外发布） |
| 无 CI / 无版本推进 | 仓库无工作流文件，`pubspec.yaml` 仍 `version: 0.0.1`；analyze/format/test 全绿只靠人自觉 | DEBT | P2 |
| workbench store 防抖测试负载下 flaky | `test/workbench_controller_test.dart` 的 "store collapses a burst into the last value" 在 `flutter test` 全套并发下偶发失败（2026-09-16 遇到一次，单跑 3/3 通过、重跑全套即消失）。debounce/计时对调度敏感，非确定性 | TST | P2 |

## 已闭环

| 编号 | 标题 | 分类 | 闭环方式 | 日期 |
| --- | --- | --- | --- | --- |
| — | AI 代理配置（`.qoder`/`.trae`/`AGENTS.md`）内容全属另一项目 | CFG | 按本仓库事实重写三份规则与入口文档，并裁掉 7 个与现状冲突的 skill | 2026-09-15 |

> 该条不占 ADR 编号：它是配置层的一次性纠正，无代码改动、无遗留状态。若日后再次发现代理配置漂移，按 README 流程立 ADR。
