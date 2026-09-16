# 迁移台账（ADR-0002 / 0003 / 0004）

> 本文件是**执行台账**：阶段、commit、门禁与"已机器验证 vs 待人签收"。决策理由不在此重复——见对应 [ADR](adr/) 与 [debt-register.md](debt-register.md)。分支 `develop`。

## riverpod 迁移（ADR-0002）

| 阶段 | 内容 | commit |
| --- | --- | --- |
| 0 | 注解工具链落地（flutter_riverpod 3.2.1 + annotation 4.0.2 + generator 4.0.3 + build_runner；shadcn_ui 0.56.3）；ADR 修订1（改注解模式，推翻"无 codegen"） | `38a9949` |
| 1 | boot stores（support/settings/prefs）override 进 `ProviderContainer` + `UncontrolledProviderScope` | `c62b3f5` |
| 2 | `AppScope` 升 keepAlive provider，`DshApp` 转 `ConsumerStatefulWidget` | `5d5aa75` |
| 3 | read seams（`settingsDocument`/`workbenchPrefs`）+ 9 个 per-controller provider；`main.dart` 转纯 Consumer 树（零 `ListenableBuilder`） | `178f941` |

边界不变量：`package:riverpod*` 仅 `main.dart` + `state/app_providers.dart`；`*.g.dart` 仅 riverpod 一处。

## shadcn_ui 迁移（ADR-0002）

| 阶段 | 内容 | commit |
| --- | --- | --- |
| 4 | `theme/dsw_shad_bridge.dart`：`DswAlias`→`ShadColorScheme`（20 字段），`ShadTheme` 经 `MaterialApp.builder` 挂载；组件用 shad、配色仍走 dsw | `2511804` |
| 5a | `CapsuleButton` 内部换 `ShadButton`（公开 API 不变） | `45ddfb8` |

## 无障碍 A1（审计阻断项）— 已闭环

新增 `primitives/tappable.dart` 的 `DswHoverTap`（`FocusableActionDetector` + `MouseRegion` + `Semantics(button/toggled/selected,onTap)`，零绘制）。`lib/ui` 手写 `GestureDetector` **60 → 11**，剩 11 全为拖拽/改尺寸/遮罩/wrapper 内部（非动作件）。分批 commit：块原语 `e122845`、图标按钮组 `e978a13`、tab strip `273f808`/`dbd715d`、settings `4272912`、editor `87e33b2`、sidechat/subagent `8ef11e4`、diff 头 `79c28ff`、mention/kill `50e76a3`、command/附件/发送 `f1301e6`、settings 行 `2434663`、提交/terminal/子卡/关闭/重试 `a32582a`。`_TabChip` 附加式 `FocusableActionDetector`+tab 语义（`16bed63`）。`dsw_hover_tap_test.dart` 钉指针/键盘/语义/右键四性。

## 平台 ADR-0003（Windows/Linux）— RESOLVED

`flutter create --platforms=windows,linux` + 浏览器 tab 平台门控（`54e75d7`）。构建配方与退化项见 [build.md §2B](../.qoder/rules/build.md)（nuget.exe + `-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`；`flutter_inappwebview` 非 macOS 不可用已门控）。

## 对比度 A2 / ADR-0004 — 决策 B（显式豁免）

`theme_contrast_test.dart` 作回归门禁 + allowlist；palette 不改（A 会抹平亮色三级文字层次，需设计肉眼）。`4703b8c`。

## 每阶段门禁口径

`flutter analyze` 零告警 · `dart format --set-exit-if-changed lib test tool spike` 零 diff · `flutter test` **651 通过 / 13 既有 Windows-only 失败（bash 路径/POSIX 分隔符/temp 锁）零新增**（本机门禁定义；macOS 全绿仍是权威）。

## 待人签收（机器验不了的）

- [ ] **Windows 本机**：`flutter run -d windows` → Full Keyboard Access 走发送/审批/设置/tab 重排/文件树/右键菜单，确认既可达又无回归；观感（capsule、焦点环）。
- [ ] **macOS**：`flutter build macos --release` + VoiceOver + 出包 → 达成后 ADR-0002 置 RESOLVED 并回填 hash。
- [ ] 若优先级视力可读于层次：ADR-0004 改走方案 A（新增 `*AA` 别名）。
- [ ] composer 主输入 `TextField`（Material 本可访问）不盲改；`runtime` 热替换链 provider 化仍属 ADR-0002 Stage4 待办（承重流式契约，需专轮）。
