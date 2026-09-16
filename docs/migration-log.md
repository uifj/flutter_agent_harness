# 迁移台账（ADR-0002 / 0003 / 0004）

> 本文件是**执行台账**：阶段、commit、门禁与"已机器验证 vs 待人签收"。决策理由不在此重复——见对应 [ADR](adr/) 与 [debt-register.md](debt-register.md)。分支 `develop`。

## riverpod 迁移（ADR-0002）

| 阶段 | 内容 | commit |
| --- | --- | --- |
| 0 | 注解工具链落地（flutter_riverpod 3.2.1 + annotation 4.0.2 + generator 4.0.3 + build_runner；shadcn_ui 0.56.3）；ADR 修订1（改注解模式，推翻"无 codegen"） | `38a9949` |
| 1 | boot stores（support/settings/prefs）override 进 `ProviderContainer` + `UncontrolledProviderScope` | `c62b3f5` |
| 2 | `AppScope` 升 keepAlive provider，`DshApp` 转 `ConsumerStatefulWidget` | `5d5aa75` |
| 3 | read seams（`settingsDocument`/`workbenchPrefs`）+ 9 个 per-controller provider；`main.dart` 转纯 Consumer 树（零 `ListenableBuilder`） | `178f941` |
| 4 | runtime 热替换链 provider 化：**经论证否决，保持命令式组合根**（`AppScope.save` 的"新 runtime adopt 完 → 旧 runtime 最后 dispose"顺序 riverpod 的 `ref.onDispose` 无法表达，provider 化会 use-after-dispose 静默破坏流式契约）。补守卫测试 `test/app_scope_test.dart` 钉住重建契约（workspace=活 setter / model·skills=重建 / 外观=永不重建）。读侧 Stage 1–3 已全量 provider 化，`appScopeProvider` 已把 scope 挂进容器。见 ADR-0002 修订 2 | `f09576f` |

边界不变量：`package:riverpod*` 仅 `main.dart` + `state/app_providers.dart`；`*.g.dart` 仅 riverpod 一处。

## shadcn_ui 迁移（ADR-0002）

| 阶段 | 内容 | commit |
| --- | --- | --- |
| 4 | `theme/dsw_shad_bridge.dart`：`DswAlias`→`ShadColorScheme`（20 字段），`ShadTheme` 经 `MaterialApp.builder` 挂载；组件用 shad、配色仍走 dsw | `2511804` |
| 5a | `CapsuleButton` 内部换 `ShadButton`（公开 API 不变） | `45ddfb8` |
| 5b | 两处 Material 确认对话框（editor 重载丢弃 + git 破坏性操作）合并为一个 `primitives/confirm_dialog.dart` 的 `showConfirmDialog`，走 `ShadDialog.alert` + `ShadButton`（outline/destructive，destructive 填充经桥=stateErrorPrimary）；lib/ui 的 `showDialog/AlertDialog` 与 `TextButton` 归零。两个 tab 测试 harness 经 `MaterialApp.builder` 挂 `ShadTheme`（showShadDialog 读调用方 context 主题） | `1dadca0` |
| 5c | settings `_Field`（所有设置文本框的唯一包装：API key/base URL/model/工作区/skills/终端字体）内部 Material `TextField` → `ShadInput`，弃手写 `InputDecoration` 改吃桥接色、`trailing` 归入 ShadInput 自带槽。settings 的 `TextField(` 归零。`settings_test`/`models_endpoint_test` 经 `MaterialApp.builder` 挂 `ShadTheme`，`find.byType(TextField)`→`ShadInput`（ShadInput 内部是 EditableText，非 TextField） | `7c1549b` |

> 剩余 C1 目标（composer 主输入 `TextField`、`PopupMenuButton`×7、`Tooltip`×25）刻意暂缓：它们与测试耦合更深（ShadInput 用 EditableText 会打断 `find.byType(TextField)`；shad 菜单/浮层与 `PopupMenuButton` 的打开/命中语义不同；25 处 Tooltip 会让一批裸 `MaterialApp` 测试补挂 ShadTheme），不是"低风险优先"该顺手做的。

## 无障碍 A1（审计阻断项）— 已闭环

新增 `primitives/tappable.dart` 的 `DswHoverTap`（`FocusableActionDetector` + `MouseRegion` + `Semantics(button/toggled/selected,onTap)`，零绘制）。`lib/ui` 手写 `GestureDetector` **60 → 11**，剩 11 全为拖拽/改尺寸/遮罩/wrapper 内部（非动作件）。分批 commit：块原语 `e122845`、图标按钮组 `e978a13`、tab strip `273f808`/`dbd715d`、settings `4272912`、editor `87e33b2`、sidechat/subagent `8ef11e4`、diff 头 `79c28ff`、mention/kill `50e76a3`、command/附件/发送 `f1301e6`、settings 行 `2434663`、提交/terminal/子卡/关闭/重试 `a32582a`。`_TabChip` 附加式 `FocusableActionDetector`+tab 语义（`16bed63`）。`dsw_hover_tap_test.dart` 钉指针/键盘/语义/右键四性。

## 平台 ADR-0003（Windows/Linux）— RESOLVED

`flutter create --platforms=windows,linux` + 浏览器 tab 平台门控（`54e75d7`）。构建配方与退化项见 [build.md §2B](../.qoder/rules/build.md)（nuget.exe + `-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`；`flutter_inappwebview` 非 macOS 不可用已门控）。

## 对比度 A2 / ADR-0004 — 决策 B（显式豁免）

`theme_contrast_test.dart` 作回归门禁 + allowlist；palette 不改（A 会抹平亮色三级文字层次，需设计肉眼）。`4703b8c`。

## 设置页迁移 ADR-0005（starkins 版式 → 本项目栈）

借 starkins 设置页的"形"（卡片分组 + 下拉/开关行），落本项目的"实"（dsw 配色、自研 i18n、overlay 无路由、`AppSettings` 单一持久化）。逐阶段：

| 阶段 | 内容 | commit |
| --- | --- | --- |
| S1 | `AppSettings` 扩 5 枚举 + 2 开关（字体族/字号、对话宽度、界面风格、预览方式、展开工具调用、提示建议）+ 序列化往返测试 | `c56bb02` |
| S2 | 审计后**塌缩为一个 `SettingsCard` 分组框**——starkins 的 SettingRow/Select/Toggle/PageTitle 本项目已有 dsw 重接版（`_SettingCellRow`/`_SwitchRow`/`_heading`），不重复造 | `a59bcdc` |
| S3 | nav 增「外观」节（5 下拉 + 2 开关）、「常规」节两行包进 `SettingsCard`、en/zh 补键；默认节与 `find.text('Follow system')` 计数不变，既有测试零改动 | `f6c074c` |
| S4 | 新增 `ui/appearance_scope.dart`（`WorkbenchPrefsScope` 式 InheritedWidget）驱动 `conversationWidth`（chat_view/composer/审批·计划卡同步加宽）与 `expandToolCalls`（ToolCard 初次展开）；无 scope 回退旧默认（748/折叠）。**未接线（仅持久化意图）**：`previewMode`、正文字体族/字号、`interfaceStyle` 皮肤 | `07ead77` |
| S5 | ✅ Windows `flutter build windows --debug` 通过并真机运行：外观节 7 项偏好渲染于单个 `SettingsCard`、常规节卡片分组、中文文案、展开工具调用默认开、界面风格"仅标准生效"提示均正常、无溢出；`contrast_check` 暗色零回退。宽模式像素效果与下拉交互以 widget 测试覆盖（未真机点选，避免写脏 `settings.json`） | 真机走查 |

## 每阶段门禁口径

`flutter analyze` 零告警 · `dart format --set-exit-if-changed lib test tool spike` 零 diff · `flutter test` **658 通过 / 13 既有 Windows-only 失败（bash 路径/POSIX 分隔符/temp 锁）零新增**（本机门禁定义；随 ADR-0005 加测增长，macOS 全绿仍是权威）。

## 待人签收（机器验不了的）

- [ ] **Windows 本机**：`flutter run -d windows` → Full Keyboard Access 走发送/审批/设置/tab 重排/文件树/右键菜单，确认既可达又无回归；观感（capsule、焦点环）。
- [ ] **macOS**：`flutter build macos --release` + VoiceOver + 出包 → 达成后 ADR-0002 置 RESOLVED 并回填 hash。
- [ ] 若优先级视力可读于层次：ADR-0004 改走方案 A（新增 `*AA` 别名）。
- [ ] composer 主输入 `TextField`（Material 本可访问）不盲改；`runtime` 热替换链 provider 化仍属 ADR-0002 Stage4 待办（承重流式契约，需专轮）。
