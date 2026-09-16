# ADR-0003: 增加 Windows（及 Linux）桌面平台目标

- **状态**: RESOLVED
- **分类**: ARC
- **优先级**: P2
- **影响维度**: 生产功能（跨平台验证）· 认知障碍（规则与现实一致性）
- **日期**: 2026-09-16
- **来源**: 用户决策（用 `flutter create .` 增加平台目标并在当前 Windows 设备上真机运行；macOS 后续再验）
- **修复 commit**: 54e75d7（windows/linux 脚手架 + browser_tab 门控）；后续无障碍推进见 16bed63

## 背景（Context）

仓库此前**只有 `macos/` 平台脚手架**，`.qoder/rules/build.md` §0 明确"只有 macOS、别为'顺手跨平台'补目录"。但 ADR-0002 的迁移（riverpod + shadcn + `DswHoverTap` 键盘可达改造）产生了大量**只能在真机人眼/键盘验证**的改动：审计 A1 的无障碍修复、A2 的对比度、观感。而开发机是 Windows、macOS 暂不可用，导致这些验证一直挂"待 macOS"。加一个本机可跑的平台目标是解锁手段。

前置核查（2026-09-16 实测）：
- 工具链就绪：`flutter doctor` 显示 Visual Studio 2026 + Windows 11 + `enable-windows-desktop`。
- 原生依赖：`flutter_pty`、`pasteboard` **有 windows 实现**（终端/剪贴板可用）。`flutter_inappwebview` 是**联邦插件**：核心包无 `windows/`，但有独立的 `flutter_inappwebview_windows` 实现会被自动拉入 Windows 构建（初判"无 windows 实现"不准，实施时纠正）。
- 启动路径安全：`host/project_folder_ops.dart` 的 `isSupported = !kIsWeb && Platform.isMacOS`，`restoreWorkspaceAccess` 在非 macOS 上提前返回、不抛；`main.dart` 因此可在 Windows 正常启动。浏览器 tab 的 `InAppWebView` 仅在打开该 tab 时懒建（`browser_tab.dart:306`），不触启动。
- `_openExternal`（`browser_tab.dart:200`）写死 macOS 的 `open`，已 `Platform.isMacOS` 门控。
- **实施时实测（2026-09-16）的两个 Windows 构建坑**（详见 `build.md` §2B）：`flutter_inappwebview_windows` 需 PATH 上有 `nuget.exe`（拉 WebView2/WIL/nlohmann）；其 `<experimental/coroutine>` 被 VS2026 STL `static_assert` 拦，需 `_CL_=-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`。补上后 `flutter build windows` 成功、exe 本机稳定启动无崩。

## 决策（Decision）

用 `flutter create --platforms windows,linux .` 增加两个桌面平台目录（**不加** android/ios/web：本应用是带 PTY 终端、文件树、进程内浏览器的桌面 harness，移动/网页无法承载其核心能力，`dart:io` 依赖也不支持 web）。改动：

1. 新增 `windows/`、`linux/` 脚手架。
2. `build.md` §0 从"只有 macOS"改写为"macOS + Windows + Linux 桌面，移动/web 仍非目标"；把 §4 签名/沙箱/公证等 **macOS 专属**条款标注为"仅 macOS"，避免对不存在的 Windows 签名/沙箱约束空转。
3. `AGENTS.md` §1「只有 `macos/` 脚手架」与 §8 的"只有 macOS 目标"改为三桌面平台，并把"在 Windows 上不能跑/不得声称跑通"的旧约束替换为：Windows/Linux 本机可验证，macOS 出包仍需 macOS 真机。
4. `.qoder/` 与 `.trae/` 两份镜像同步。

**非 macOS 的已知退化（明确记录，不掩盖）**：
- **浏览器 tab**：`flutter_inappwebview` 无 windows/linux 实现。在 Windows 打开浏览器 tab 会 `MissingPluginException`。处置：`browser_tab` 需加一个"平台支持"分支——不支持时显示 `context.tr('browserUnsupportedPlatform')` 之类的占位而非抛异常（本 ADR 实施内一并做）。
- **security-scoped 工作区书签**：macOS 专属；Windows/Linux 走 `file_picker` 面板选目录（无持久化授权），`restoreWorkspaceAccess` 直接返回。功能降级但不崩。
- 终端/剪贴板：依赖有 windows 实现，预期可用，但仍需本机实测。

## 后果（Consequences）

- **正面**: Windows 本机首次可 `flutter run -d windows`，无障碍/观感/对比度改造得以及早人肉验证；Linux 顺带获得桌面目标。
- **负面/风险**: 多了两套平台脚手架要维护（CMake、插件注册）；`flutter_inappwebview` 的平台缺口必须显式降级否则打开浏览器 tab 即崩；`build.md` 的"macOS-only"论断需要连文档一起改，否则规则与事实再次分叉（正是本次系列工作要根除的问题）。
- **中性**: 三平台并存不改变架构不变量（genkit 边界、model 纯净、state 不 import ui 均不受影响）。

## 验证（Verification）

```
flutter create --platforms windows,linux .   # 生成 windows/ linux/
flutter analyze                              # 仍零告警
flutter build windows --debug                # Windows 端可编译链接出产物
flutter run -d windows                       # 真机起得来（本机验证）
```
- Windows 上打开浏览器 tab 不崩，显示平台不支持占位。
- 终端 tab、设置、审批、workbench 分栏在 Windows 上可用。
- 规则更新后：`grep -rn "只有 \`macos/\`\|flutter run -d windows\` 必然失败" .qoder/ .trae/ AGENTS.md` 为空。

**实测结果（2026-09-16）**：补 nuget + silence 宏后 `flutter build windows --debug` → `√ Built agent_harness.exe`；后台拉起 exe 存活 ~12s、Dart VM service 起来、无异常 → 本机 Windows 真机跑通。（Linux 仅生成脚手架，未在本机验证——本机是 Windows。）

## 关联（Links）

- 代码: `host/project_folder_ops.dart:46`（isSupported 门控）、`browser_tab.dart:200,306`
- 规则: `.qoder/rules/build.md` §0/§4、`AGENTS.md` §1/§8
- 关联 ADR: ADR-0002（本次平台扩展是为落地其改造服务）
