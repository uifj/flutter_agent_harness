# Flutter 桌面端构建规则（build）

适用场景：任何构建 / 打包 / 编译失败排查 / 发布相关任务。规则在 ponytail 与 workflow.md 之上，落地本仓库（`agent_harness`，桌面端：macOS 为主 + Windows/Linux 可本机验证）的真实构建事实；违反版本基线、擅动 entitlements、或在未真机验证前宣称出包成功，视为错误。

## 0. 版本基线与平台范围

- **Flutter 3.41.9 stable / Dart 3.11.5**（`pubspec.yaml` 要求 `sdk: ^3.11.5`）。不要为了"绕开一个报错"去换 SDK 版本；要升 SDK 先立 ADR。
- **三个桌面平台目标**：`macos/`、`windows/`、`linux/`（Windows/Linux 由 ADR-0003 于 2026-09-16 加入，为在开发机上真机验证）。**没有** `android/`、`ios/`、`web/`——本应用是带 PTY 终端、文件树、进程内浏览器的桌面 harness，移动/web 承载不了其核心能力（`dart:io` 也不支持 web），别去补这些目录，那仍是 ARC 级决策。
- 源项目在 Mac 上用 fvm（`spike/*.dart` 的运行注释写着 `fvm dart run`）。本仓库**不含** fvm 配置文件：机器上有 fvm 就照注释用 fvm，没有就直接 `dart` / `flutter`，不要新引入 fvm 配置。
- **开发机是 Windows**：Windows/Linux 目标本机可 `flutter build` / `flutter run` 真机验证；但 **macOS 构建/出包仍禁止在没有 macOS 真机时宣称通过**——没在 macOS 上真跑过的 macOS 产物/签名/公证，交付说明一律标"待 macOS 验证"。
- 依赖状态：仓库里 `pubspec.lock` 不入库（库型包约定，见 `.gitignore`）。任何校验命令的第一步是 `flutter pub get`；某台新机器（尤其全新 clone）可能连 `.dart_tool`/pub cache 都没有——拿到锁文件前不要声称某个包"当前解析到的版本"是多少，用 `flutter pub deps` 现场核对。

## 1. 在 Windows 上就能跑的校验（日常工作面）

```
flutter pub get
flutter analyze
dart format --set-exit-if-changed .
flutter test
```

- 跑子集：`flutter test test/conversation_controller_test.dart`（单文件），`flutter test test/ -r expanded`（要看过程）。
- **只能用 `flutter test`**：dev 依赖只有 `flutter_test`，没有 `package:test`，`dart test` 起不来。39 个 `*_test.dart` 全部 import `package:flutter_test`，包括纯 Dart 逻辑的 `test/file_search_test.dart`。
- 交付给用户的验收门槛固定三条：analyze 无告警、format 无 diff、test 全绿。缺任何一条就不要说"改好了"。

## 2. macOS 构建

- 前置：Xcode + CocoaPods。命令：`flutter build macos --release`（另有 `--debug` / `--profile`）。
- 首次拉取或改了插件后：`cd macos && pod install`。`macos/Podfile` 是 `platform :osx, '10.15'`、`use_frameworks!`、target `Runner` + 嵌套 `RunnerTests`。
- 产物：`build/macos/Build/Products/Release/Agent Harness.app`。`Agent Harness` 来自 `macos/Runner/Configs/AppInfo.xcconfig` 的 `PRODUCT_NAME`；bundle id 同文件 `com.stow.agentHarness`。
- 版本号**只在 `pubspec.yaml`**（当前 `version: 0.0.1`），经 `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` 注入 `Runner/Info.plist`（`CFBundleShortVersionString`）。禁止在 `pbxproj` 或 xcconfig 里写死版本，那会造成两处真值。
- 部署目标 10.15 同时出现在 `Podfile` 与工程配置里；提高它要两边一起改，并立 ADR（它决定你能支持的最低 macOS）。

## 2B. Windows / Linux 构建（开发机可本机验证，ADR-0003）

- Windows 前置：Visual Studio（含 "使用 C++ 的桌面开发" 工作负载）+ CMake；命令 `flutter build windows`（`--debug` / `--release`）。产物在 `build\windows\x64\runner\Debug\agent_harness.exe`。
- Linux 前置：GTK 工具链（clang/cmake/ninja/pkg-config + GTK3）；命令 `flutter build linux`。产物 `build/linux/x64/debug/bundle/`。
- 首次拉取或改插件后先 `flutter pub get` 生成 ephemeral；本机验证直接 `flutter run -d windows`。
- **`flutter_inappwebview_windows` 的两个必踩坑（已在 2026-09-16 实测跑通，别重复排查）**：
  1. 它用 `nuget install` 拉 WebView2/WIL/nlohmann 依赖，**PATH 上要有 `nuget.exe`**（本机 `dotnet tool install` 不适用，直接下 `curl --ssl-no-revoke -o ~/.dotnet/tools/nuget.exe https://dist.nuget.org/win-x86-commandline/latest/nuget.exe`，该目录已在 PATH）。
  2. 它含 `<experimental/coroutine>`，被 VS2026(MSVC 14.51) STL 用 `static_assert` 硬拦。构建前设环境（**用 `-D` 不能用 `/D`**，Git Bash 会把 `/D_...` 当路径转换）：`export MSYS2_ARG_CONV_EXCL="*"; export _CL_="-D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"`，再 `flutter build windows`。
- **非 macOS 的已知退化（勿掩盖）**：`flutter_inappwebview` 无 windows/linux 实现——浏览器 tab 已在 `browser_tab.dart` 门控为"平台不支持"占位（`t('browserUnsupported')`），不再崩；`host/project_folder_ops.dart` 的 security-scoped 书签是 macOS 专属，非 macOS 上 `isSupported=false`、`restoreWorkspaceAccess` 直接返回，工作区靠 `file_picker` 现场选（无持久授权）。`flutter_pty`/`pasteboard` 有 windows 实现，终端与剪贴板预期可用（仍需本机实测确认）。

## 3. Entitlements 与沙箱（本项目最关键的能力边界，勿擅自改）

- `macos/Runner/DebugProfile.entitlements`：`allow-jit`、`network.server`、`network.client`、`files.user-selected.read-write`、`files.bookmarks.app-scope`。
- `macos/Runner/Release.entitlements`：**同一组键，且刻意不写 `com.apple.security.app-sandbox`**。原因就写在该文件的注释里：terminal tab 用 `flutter_pty` 起子进程，开了沙箱会被拒。JIT/网络保留，文件类 entitlements 是为"将来的沙箱化构建"预留（那种构建要牺牲 PTY，或把它改到 NSOpenPanel + bookmark 授权路径上）。
- 因此：**改这两个文件 = 改产品能力边界**，必须先有 ACCEPTED 的 ADR（分类 ARC 或 SEC）。`git diff macos/Runner/*.entitlements` 应当在普通改动里为空。
- `files.bookmarks.app-scope` 不可丢：`main()` 在任何读操作之前调 `restoreWorkspaceAccess`（`lib/host/project_folder_ops.dart`）恢复上次记录的工作区授权。丢了它 = 重启后访问失效，而唯一的"再授权"入口是 hero picker。
- 新增 Swift/ObjC 代码必须过 `macos/Runner/Configs/Warnings.xcconfig` 的严格警告集（`-Wall`、`-Wconditional-uninitialized`、`-Wnullable-to-nonnull-conversion`、UBSAN nullability、`CLANG_WARN_UNGUARDED_AVAILABILITY=YES_AGGRESSIVE` 等）。不要靠关掉警告来"通过编译"。

## 4. 签名与分发（现状：只够本机运行）

- 现状事实：`project.pbxproj` 里工程级配置 `CODE_SIGN_IDENTITY = "-"`（ad-hoc），`Automatic` 与 `Manual` 两种 style 并存，`PROVISIONING_PROFILE_SPECIFIER` 为空，**没有 `DEVELOPMENT_TEAM`**。Runner target 的 Debug/Profile 挂 `DebugProfile.entitlements`、Release 挂 `Release.entitlements`，均为 `Automatic`。
- 结论：`flutter build macos --release` 的产物只能在本机跑。要对外分发（直链或 App Store），需要先配 Developer ID 团队 + 证书 + Provisioning、开 hardened runtime、再用 `notarytool` 公证。
- 做上面这一步时的两条硬要求：① 先把 `*.p12`、`*.cer`、`*.mobileprovision` 加进 `.gitignore`（当前默认模板里**没有**这几条），证书与描述文件永不入库；② 不要把任何 API key 写进仓库——模型 key 由 `SettingsStore` 落在 Application Support（不是 Documents：那是应用状态不是用户文件，且在沙箱容器内无需额外 entitlement）。

## 5. 出包检查清单（发布前逐项过，都要给证据）

1. macOS 上：`flutter pub get` → `flutter analyze` → `dart format --set-exit-if-changed .` → `flutter test` 全绿。
2. `dart run spike/agent_spike.dart` 重跑，头部 FINDINGS 仍然成立（genkit 版本没动过；或动过且 `lib/genkit/` 投影已适配）。
3. 真实链路冒烟：`DEEPSEEK_API_KEY=... dart run spike/runtime_smoke.dart`，按该文件头的顺序验：流式回答 → 工具环（listDir + readFile）→ 审批往返（writeFile → interrupt → resume）→ 会话从盘上恢复。
4. `flutter build macos --release` 成功且 `Agent Harness.app` 能起；首次经 hero picker 授权工作区后，terminal / git / editor / browser 四类 tab 各至少打开一次不崩。
5. 版本号只在 `pubspec.yaml` 递增过。
6. `git diff macos/Runner/*.entitlements` 为空（或存在已 ACCEPTED 的 ADR 解释改动）。
7. 无 key、无证书、无描述文件进入提交（`git status` 与 `git diff --cached` 双查）。
8. 签名与公证缺口未解决前（见 §4），不得声称"可对外分发"。

## 6. 已知坑（先查这里再排障）

- Podfile 抛 `.../Flutter/ephemeral/Flutter-Generated.xcconfig must exist`：先 `flutter pub get`（该 xcconfig 由它生成，Podfile 的 raise 原文就是这么提示的）。
- `flutter test` 报找不到包 / 缺 `.dart_tool` / pub cache 不存在：先 `flutter pub get`（新 clone 或换机器时缓存可能为空）。
- 换 Xcode / macOS 版本后 pod 报错：`cd macos && pod deintegrate && pod install`，仍不行再 `flutter clean`。不要手动删 `macos/Flutter/ephemeral/`。
- Kotlin/Gradle transforms 缓存竞态、`android/.gradle`、`abiFilters` 那类 Android 调优**与本仓库无关**，别照抄其他项目的构建经验过来。
- terminal tab 起不来：先确认不是 entitlements/沙箱被动过（§3），再看 `lib/host/terminal_manager.dart`。
- `flutter_pty`、`pasteboard`、`xterm` 有 windows 实现（终端/剪贴板跨桌面可用，仍待本机实测）；`flutter_inappwebview` **无** windows/linux 实现——浏览器 tab 已在 `browser_tab.dart` 门控降级（见 §2B）。给这些依赖加新平台分支前，先回到 §0 的平台范围（三桌面，不含移动/web）。
- 布局溢出、RenderFlex 报错属 UI 层问题，走 `flutter-fix-layout-issues`，别误判成构建失败。
