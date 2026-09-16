# 技术债与缺陷登记表（debt-register）

本文件是本仓库**唯一的状态源**：所有已登记问题的分类、优先级与当前状态在此总览，细节与证据在下钻的 ADR 里。修改规则、分类、状态机见 [README.md](README.md)。迁移的逐阶段执行台账（commit/门禁/待签收）见 [migration-log.md](migration-log.md)。

## 已登记

| 编号 | 标题 | 分类 | 优先级 | 状态 | 日期 | ADR |
| --- | --- | --- | --- | --- | --- | --- |
| ADR-0001 | vendored `packages/flutter-shadcn-ui` 不进版本库 | DEP | P2 | RESOLVED @ d72ff4c | 2026-09-15 | [链接](adr/ADR-0001-dep-vendored-shadcn-ui.md) |
| ADR-0002 | develop 分支改造为 riverpod + shadcn_ui | ARC | P1 | IN-PROGRESS（riverpod 读侧 Stage 1–3 完成；Stage 4 热替换链经论证保持命令式·修订 2；shadcn Stage 4/5a–5c 已落；余 macOS 真机验收 + 暂缓的深层组件替换） | 2026-09-15 | [链接](adr/ADR-0002-arc-riverpod-shadcn-migration.md) |
| ADR-0003 | 增加 Windows/Linux 桌面平台目标（本机可验证） | ARC | P2 | RESOLVED @ 54e75d7 | 2026-09-16 | [链接](adr/ADR-0003-arc-windows-linux-platforms.md) |
| ADR-0004 | 亮色正文对比度 AA 修正层（A 新增 AA 别名 / B 显式豁免） | CFG | P1 | PROPOSED（待签收；回归门禁已先行落地） | 2026-09-16 | [链接](adr/ADR-0004-cfg-light-contrast-aa.md) |
| ADR-0005 | 以 starkins 设置页为蓝本重建设置界面（重接本项目栈） | ARC | P1 | RESOLVED（S1–S5 落地，S5 真机走查通过；未接线的 previewMode/字体/皮肤见下方观察行） | 2026-09-16 | [链接](adr/ADR-0005-arc-starkins-settings-rebuild.md) |

> 2026-09-15 设计层审计（方法：design-review 插件手动审查模型）产出了完整证据链，见 [design-audit-2026-09.md](design-audit-2026-09.md)。阻断级/ majors 的处置归属：键盘无障碍（A1/A3）与表单控件缺口（C1）并入 ADR-0002 实施；A2（对比度）与文本缩放留下方观察表。

## ADR-0002 迁移进度（截至 2026-09-15）

- **riverpod**：Stage 1-3 完成——boot stores 经 `ProviderContainer` override（38a9949）、`AppScope` keepAlive provider（5d5aa75）、9 个 per-controller provider + read seams、`main.dart` 转纯 Consumer 树（178f941）。riverpod import 仅限 `main.dart` + `state/app_providers.dart`。
- **shadcn_ui**：Stage 4 主题桥 `theme/dsw_shad_bridge.dart`（DswAlias→ShadColorScheme，2511804）；Stage 5 CapsuleButton→ShadButton（45ddfb8）。
- **A1 键盘可达**：新增 `primitives/tappable.dart` 的 `DswHoverTap`（`FocusableActionDetector` + `MouseRegion` + `Semantics(button,onTap)`，零绘制），已收编块原语 4 + 私有图标按钮组 4 + tab strip 关闭/分屏 + settings 控件 7 + git/sidechat/diff/editor 叶按钮 + subagent 根卡。**`lib/ui` `GestureDetector` 60 → 35**；转换项均 Tab 可聚焦 / Enter·Space 激活 / VoiceOver 读 button·toggled。

## A1 键盘可达——已闭环（2026-09-16）

`lib/ui` 手写 `MouseRegion+GestureDetector` 交互件 **60 → 11**。**所有** 手写动作按钮/行现均 Tab 可聚焦、Enter·Space 激活、读屏可读（button/toggled/selected 语义）：capsule、4 块原语、4 私有图标按钮组、tab strip 关闭/分屏/`_TabChip`(附加式 FocusableActionDetector+tab 语义)、settings 全控件、git 文件/历史/提交按钮、diff 折叠+文件头、sidechat/chat/hero/file-tree/inspect/close、composer mention/command/image-chip/remove/send/retry、subagent 根卡/子卡/kill/关闭。共享件 `primitives/tappable.dart` 的 `DswHoverTap` 是唯一入口，`dsw_hover_tap_test.dart` 钉住指针/键盘/语义/右键四性。

**剩余 11 处全部合法、非动作件**：`app_frame`3 + `pane`2 + `free_window`2 + `split_view`1 = 分隔条拖拽/面板改尺寸/自由窗移动（本就不是可聚焦按钮）；`model_settings`1 = 设置遮罩点空白处关闭（Escape 已绑 `FocusScope` 提供键盘路径，全屏遮罩不该占 tab 停靠）；`tappable`1 = `DswHoverTap` 自身内部；`workbench_tab_bar`1 = `_TabChip` 的拖拽/右键菜单内部 `GestureDetector`（键盘激活已由其外层 `FocusableActionDetector` 提供）。

> A1 视为达成。仍建议 macOS（及现在可跑的 Windows）上人工走一遍 Full Keyboard Access + VoiceOver 复核观感，尤其 tab 重排与右键菜单未回归。

## 待立 ADR 的观察

以下是已经确认存在、但尚未走完"提案 → 批准"流程的问题。**修任何一个之前先补 ADR 并置 ACCEPTED**（纪律见 [README.md](README.md)）。

| 现象 | 证据 | 建议分类 | 建议优先级 |
| --- | --- | --- | --- |
| 测试套件不可在 Windows 移植（13/657 失败） | 2026-09-15 首次在本机跑全套：`shell_run_test` 8 个（写死 `/bin/bash`）、`editor_tab_test` 1 个（temp 目录删除遇 Windows 文件锁 errno 32）、`git_tab_test` 2 个与 `workbench_ui_test` 2 个（tab id / 断言用 POSIX 路径分隔符拼接 `support.path`）。全部先于 riverpod 迁移存在；其中 git_tab/workbench 4 个此前被 `trash_2` 编译错误掩盖（该错已修）。macOS 上的全绿仍是权威门禁；本机门禁为"相对基线零新增失败" | TST | P1 |
| 亮色主题 6 组正文令牌对比度低于 WCAG AA | 确定性计算（`tool/contrast_check.dart` / `test/theme_contrast_test.dart`）：`labelDimmed` 1.26、`labelCaption` 2.13、`labelTertiary` 3.71（97 处）、`stateWarnLabel` 2.79、审批条 `stateWarnPrimary` 1.99（`approval_panel.dart:104-118`）、`stateSuccessPrimary` 2.28。dsh 原版调色板固有。**[ADR-0004](adr/ADR-0004-cfg-light-contrast-aa.md) 已决策：采纳 B 显式豁免（A 会抹平亮色三级文字层次，需设计肉眼权衡），palette 不改；回归门禁 `theme_contrast_test.dart` 已落地防恶化** | CFG | P1（已豁免） |
| 无文本缩放适配 | `textScaler|textScaleFactor` 全仓库 0 处；disclosure_row 等自绘件固定高度（24px header），macOS 辅助功能放大文本时裁切 | DEF | P2 |
| i18n 双语对齐无守卫 | `lib/l10n/locales.dart:11-13` 注释声称 en 会"在 test 时对照校验"，但 `grep -rn "enStrings\|zhStrings" test/` 零命中；当前键集恰好对齐（不写死条数，加键即失真故刻意省略），纯靠手动维持 | TST | P2 |
| `README.md` 仍是 Flutter 包模板 | 文件通篇 `TODO:`，无一句项目说明；新人和代理拿它当入口会拿到零信息 | DEBT | P2 |
| macOS 分发缺口 | `CODE_SIGN_IDENTITY = "-"`、无 `DEVELOPMENT_TEAM`、未配 hardened runtime / `notarytool` 公证 → 产物只能本机运行；且 `.gitignore` 缺 `*.p12`/`*.cer`/`*.mobileprovision`，一旦有人放证书就会入库 | CFG | P1（若要对外发布） |
| 无 CI / 无版本推进 | 仓库无工作流文件，`pubspec.yaml` 仍 `version: 0.0.1`；analyze/format/test 全绿只靠人自觉 | DEBT | P2 |
| workbench store 防抖测试负载下 flaky | `test/workbench_controller_test.dart` 的 "store collapses a burst into the last value" 在 `flutter test` 全套并发下偶发失败（2026-09-16 遇到一次，单跑 3/3 通过、重跑全套即消失）。debounce/计时对调度敏感，非确定性 | TST | P2 |
| ADR-0005 S4 未接线的偏好（仅持久化意图） | `AppSettings` 已存 `previewMode`/`fontFamily`/`fontSize`/`interfaceStyle`，外观节也能改并落盘，但渲染端忽略：`conversationWidth`+`expandToolCalls` 已经 `ui/appearance_scope.dart` 生效，其余三项未接。`previewMode` 需先定"生成文件预览流"规格且"新窗口"要多窗口；正文字体族/字号需真正作用于 conversation 排版；`interfaceStyle` 的 glass/classic/parchment 各需自己的 DswAlias 调色板（见 `app_settings.dart` 内注释） | DEBT | P2 |

## 已闭环

| 编号 | 标题 | 分类 | 闭环方式 | 日期 |
| --- | --- | --- | --- | --- |
| — | AI 代理配置（`.qoder`/`.trae`/`AGENTS.md`）内容全属另一项目 | CFG | 按本仓库事实重写三份规则与入口文档，并裁掉 7 个与现状冲突的 skill | 2026-09-15 |
| — | 设置页切主题/中英文失效、首页选文件夹后状态不更新 | DEF | riverpod read-seam 误用 `ref.notifyListeners()`：函数式 provider 下它只重通知**旧缓存值**、不重跑 body，故 store 保存传不到读者。改 `ref.invalidateSelf()`（重跑 body 返回新值）。`state/app_providers.dart`。新增 `test/app_providers_test.dart` 用真 store 断言 store→provider 传播（正是能抓住此 bug 的守卫——旧的 widget 测试直接构造 controller、且没有 store→provider 传播断言，故漏网）。本机 `flutter run -d windows` 复验中 | 2026-09-16 |

> riverpod 坑（记入 memory/规则）：把 `ChangeNotifier`/`Listenable` 桥成**函数式 provider** 时，值同步用 `ref.invalidateSelf()`，**不是** `ref.notifyListeners()`（后者不重跑函数式 body）。`main.dart` 迁纯 Consumer 树时删掉的 `ListenableBuilder(settings/prefs)` 靠这两个 read-seam 顶替，一旦用错 API 就静默失效、且不进运行日志（非异常），只能真机点出来。

> 前两条不占 ADR 编号：均为一次性纠正/在途 bug 修复，无遗留状态。若日后再现同类代理配置漂移或迁移回归，按 README 流程立 ADR。
