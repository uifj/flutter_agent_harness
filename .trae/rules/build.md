# Flutter 桌面端构建规则（build）

适用场景：任何构建 / 打包 / 编译失败排查 / 发布相关任务。规则在 ponytail 与 workflow.md 之上，落地本仓库（**企划星 / PlanStar**，pubspec 包名 `planstar`，三桌面目标 macOS/Windows/Linux + 两棵移动品牌脚手架）的真实构建事实；违反版本基线、擅动 entitlements、或在未真机验证前宣称出包成功，视为错误。

## 0. 版本基线与平台范围

- **Flutter 3.41.9 stable / Dart 3.11.5**（`pubspec.yaml` 要求 `sdk: ^3.11.5`）。**基线现在有两处真值**：`pubspec.yaml` 与 `.github/workflows/{pr-check,build}.yml` 的 `FLUTTER_VERSION: '3.41.9'`，改版本要三处一起改。不要为了"绕开一个报错"去换 SDK 版本；要升 SDK 先立 ADR。
- **三个桌面平台目标**：`macos/`、`windows/`、`linux/`（Windows/Linux 由 ADR-0003 于 2026-09-16 加入，为在开发机上真机验证）。另有 `android/`、`ios/` 两棵 **品牌脚手架**（ADR-0057，2026-10-04 加入）：只承载图标与启动图，**应用在其中跑不起来**。拦路的是三个只声明 linux/macos/windows 的插件——`window_manager`、`tray_manager`、`hotkey_manager`——而 `main.dart:131` 在 `runApp` 之前无条件 `await windowManager.ensureInitialized()`，第一帧就到不了。另外两个各缺一半：`pasteboard` 无 android（`composer.dart:22`）、`desktop_drop` 无 ios（`conversation_root.dart:16`）；`flutter_pty` 在 android/ios 都按 `ffiPlugin` 声明、会被打包进去，能不能真开出 pty 未验证，但它不是拦路的那个。⚠ 这条边界的陷阱是 **`flutter build ios --no-codesign` 会编译成功并产出 Runner.app**：构建绿完全不等于能运行，判据是 `grep -c WindowManager ios/Runner/GeneratedPluginRegistrant.m` 为 0。要真上移动需另立 ADR 逐门处理这三个插件（外加各缺一半的 pasteboard / desktop_drop）与 macOS 书签授权。**没有** `web/`（`dart:io` 不支持），补它仍是 ARC 级决策。
- 源项目在 Mac 上用 fvm（`spike/*.dart` 的运行注释写着 `fvm dart run`）。本仓库**不含** fvm 配置文件：机器上有 fvm 就照注释用 fvm，没有就直接 `dart` / `flutter`，不要新引入 fvm 配置。
- **开发机是哪台会变，规则不变**：本仓库在 Windows 开发机上写下过 ADR-0003/0005/0006 的走查证据；当前这台开发机是 **macOS（Darwin arm64，Flutter 3.41.9 / Dart 3.11.5 已装，无 fvm、无 `.dart_tool`）**。不变量只有一条：**没在当前这个平台真跑过的产物/签名/走查，交付说明一律标"待 <平台> 验证"**。跨平台事实要以命令输出为证，不要照抄另一台机器的结论。
- 依赖状态：仓库里 `pubspec.lock` 不入库（库型包约定，见 `.gitignore`）。任何校验命令的第一步是 `flutter pub get`；某台新机器（尤其全新 clone）可能连 `.dart_tool`/pub cache 都没有——拿到锁文件前不要声称某个包"当前解析到的版本"是多少，用 `flutter pub deps` 现场核对。
- **入库的本地包 `packages/board_panel` 是被 lint/格式化范围排除的**：`analysis_options.yaml` 排除 `packages/**`，CI 的 format/analyze 只作用于 `lib test tool spike`。它是 pubspec 的 path 依赖（ADR-0007 D5），所以 `flutter pub get` 会解析它、`flutter test` 会编译到用到它的代码，但它的源码质量不由本仓库门禁负责——改动它要在该包目录内单独验证。

## 1. 日常校验（三平台同口径 = CI 门禁）

```
flutter pub get
dart format --set-exit-if-changed lib test tool spike packages/appunits/app_common packages/appunits/plan_editor packages/infras/stone_core
dart analyze --fatal-infos lib test tool spike packages/appunits/app_common packages/appunits/plan_editor packages/infras/stone_core
flutter test
flutter test packages/appunits/plan_editor packages/infras/stone_core
```

- **与 `.github/workflows/pr-check.yml` 逐字同口径**：范围是 `lib test tool spike` + 三个一手包（ADR-0085 D5：`app_common`/`plan_editor`/`stone_core`；board_panel/sentry/appunits_core/pudding 排除理由逐包写在 `analysis_options.yaml` 与 ADR-0083），analyze 带 `--fatal-infos`（info 级也算失败）。本地用 `flutter analyze` 快查可以，但交付前必须跑上面这条。
- 跑子集：`flutter test test/conversation_controller_test.dart`（单文件），`flutter test test/ -r expanded`（要看过程）。
- **只能用 `flutter test`**：dev 依赖只有 `flutter_test`，没有 `package:test`，`dart test` 起不来。`test/` 下**每一个** `*_test.dart` 都 import `package:flutter_test`（含纯 Dart 逻辑的 `test/file_search_test.dart`），条数会变、不作为事实引用。
- 主题相关改动另有一道确定性检查：`dart tool/contrast_check.dart`（dart:io/dart:math，无需 Flutter 工具链）。
- 交付给用户的验收门槛固定三条：analyze 无告警、format 无 diff、test 全绿。缺任何一条就不要说"改好了"。

## 2. macOS 构建

- 前置：Xcode + CocoaPods。命令：`flutter build macos --release`（另有 `--debug` / `--profile`）。**macOS 开发机上这条可本机验证**；Windows/Linux 开发机只能靠 CI 的 macos job（`runs-on: macos-latest`），而 CI 只证明编译通过，不证明走查与签名。
- 首次拉取或改了插件后：`cd macos && pod install`。`macos/Podfile` 是 `platform :osx, '10.15'`、`use_frameworks!`、target `Runner` + 嵌套 `RunnerTests`。
- 产物：`build/macos/Build/Products/Release/PlanStar.app`。`PlanStar` 来自 `macos/Runner/Configs/AppInfo.xcconfig` 的 `PRODUCT_NAME`（Finder 与 Dock 上看到的「企划星」是同文件 `Info.plist` 的 `CFBundleDisplayName`）；bundle id 同文件 `top.planstar.desktop`。**path_provider 用 bundle id 给支持目录命名**，所以再改它必须同时改 `lib/host/support_directory.dart` 里的一次性改名，否则设置、会话、工作台布局、审批与 checkpoint 会整体留在旧目录里，看起来像被清空。
- 版本号**只在 `pubspec.yaml`**（当前 `version: 0.0.1`），经 `FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER` 注入 `Runner/Info.plist`（`CFBundleShortVersionString`）。禁止在 `pbxproj` 或 xcconfig 里写死版本，那会造成两处真值。
- 部署目标 10.15 同时出现在 `Podfile` 与工程配置里；提高它要两边一起改，并立 ADR（它决定你能支持的最低 macOS）。

## 2B. Windows / Linux 构建（ADR-0003；在对应平台或 CI runner 上验证）

- Windows 前置：Visual Studio（含 "使用 C++ 的桌面开发" 工作负载）+ CMake；命令 `flutter build windows`（`--debug` / `--release`）。产物在 `build\windows\x64\runner\Debug\planstar.exe`（release 对应 `...\Release\`）。
- Linux 前置：GTK 工具链（clang/cmake/ninja/pkg-config + GTK3）；命令 `flutter build linux`。产物 `build/linux/x64/debug/bundle/`。
- 首次拉取或改插件后先 `flutter pub get` 生成 ephemeral；本机验证直接 `flutter run -d windows`。
- **`flutter create --platforms=…` 会改写 `.metadata` 并丢掉未列出平台的 `migration.platforms` 记录**（2026-10-04 实测：加 android/ios 时 linux 与 windows 两行被替换掉）。跑完必查 `git diff .metadata`，五棵平台（root/linux/windows/android/ios）都要在。
- **下面两条 Windows 坑是 2026-09-16 在 Windows 开发机上实测跑通的结论，不是当前 macOS 开发机的现状**：在 mac 上碰不到它们（交叉不过去），但要改 Windows 目标或 CI 的 windows job 时照用。
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

## 4B. CI 的构建事实（`.github/workflows/`，2026-09 起存在）

- **`pr-check.yml`**：`push`/`pull_request` 到 `develop`·`main`，`runs-on: ubuntu-latest`，Flutter 由 `subosito/flutter-action@v2` 钉 `FLUTTER_VERSION: '3.41.9'`，依次跑 `flutter pub get` → `dart format --set-exit-if-changed` / `dart analyze --fatal-infos`（范围 = `lib test tool spike` + 三个一手包，见 §1）→ `flutter test` → `flutter test packages/appunits/plan_editor packages/infras/stone_core`。**它就是 §1 那组命令的权威口径**。
- **`build.yml`**：**只有 `workflow_dispatch`**（不会自动跑），四个输入开关：`build_windows` / `build_macos` / `build_linux` / `publish_release` + `release_tag`。三个 job 分别 `runs-on: windows-latest` / `macos-latest` / `ubuntu-latest`（linux job 先 `apt-get install ninja-build libgtk-3-dev pkg-config libsecret-1-dev`；macos job 会 `cd macos && pod install`）。
- 产物与打包：artifact 名 `windows-x64` / `macos` / `linux-x64`；`publish_release == true` 时 macos 用 `hdiutil` 造 `agent-harness-macos.dmg`、windows 用 7z 造 zip、linux 造 tar.gz，再由 `softprops/action-gh-release@v2` 发到 GitHub Release（tag 用输入框里的 `release_tag`，如 `v0.1.0`）。
- **CI 里没有任何签名/公证步骤**（`grep -c "codesign\|notarytool\|CERTIFICATE\|secrets\." .github/workflows/build.yml` = 0，仓库不配 secrets）。所以"CI 绿"或"GitHub Release 有产物"**都不等于可对外分发**——macOS 产物仍 ad-hoc（§4），Gatekeeper 会拦，未公证。别把这两件事混为一谈。
- CI 也不跑 `spike/*` 与 `dart tool/contrast_check.dart`（它们不在 pr-check 的步骤里），这两类证据仍要本地跑或按 §7 立 TST/CFG 类 ADR 补进门禁。
- **pr-check 还有第二个 job `build-macos`**（ADR-0085 D6）：`runs-on: macos-latest`，`pod install` 后 `flutter build macos --debug`——macOS 目标（Swift pods/entitlements/打包）从此每 push 真编译一次；签名的现状缺口不受它影响（§4）。

## 5. 出包检查清单（发布前逐项过，都要给证据）

1. 在当前开发机上：§1 那组命令（format / analyze / 两侧 test）全绿（= pr-check 同口径），且 pr-check 在目标分支上确实绿。
2. `dart run spike/agent_spike.dart` 重跑，头部 FINDINGS 仍然成立（genkit 版本没动过；或动过且 `lib/genkit/` 投影已适配）。
3. 真实链路冒烟：`DEEPSEEK_API_KEY=... dart run spike/runtime_smoke.dart`，按该文件头的顺序验：流式回答 → 工具环（**哪一个工具由模型自己挑**，"列一下文件"很可能变成被审批挡住的 `bash ls`，脚本逐个应答）→ 审批往返（interrupt → resume）→ 覆盖写的 before 镜像断言（字节等于写前盘上内容、after 指纹等于写后、工具返回带 `checkpoint` id，ADR-0014）→ 会话从盘上恢复。判成败**不要接管道**：`… | tail` 会把退出码换成 tail 的，这道门第一次"通过"就是这么来的。它能编译的前提是 `lib/genkit/` 保持无 Flutter（ADR-0015 把共享的文件版本号放进了纯 Dart 的 `lib/model/fs_revision.dart`，并由 `check_architecture` 第 6 条规则守着）——若有人让 runtime 又摸到 `package:flutter`，这道门会在 `flutter test` 里红，而不是悄悄断掉。
4. `flutter build macos --release` 成功且 `PlanStar.app` 能起；首次经 hero picker 授权工作区后，terminal / git / editor / browser 四类 tab 各至少打开一次不崩，并且**新加的表面也各走一遍**：双树（右栏 + 下栏各开 tab、跨树拖拽/右键移动）、企划模式（vault 树 + 块编辑器；一个集合的五档投影 Table/List/Gallery/Board/Calendar 与它的视图配置抽屉；侧栏扩展区的集合列表与 All Content／组件条／回收站／Gallery 四面——ADR-0037 之后按这些点名，"看板/日程/表格三块扩展面板"那套已经不存在了）、全屏设置与底部快捷菜单、托盘显示/隐藏与全局热键（`Cmd/Ctrl+Shift+H` 系统级、`Cmd/Ctrl+N`、`Cmd/Ctrl+,`）、拖文件入 composer 与 PDF 抽文本、LaTeX/Mermaid 渲染、本地备份/恢复（zip 里带 `checkpoints/` 与 `sessions/`——含 ADR-0039 那份 `sessions.json` 侧车；restore 现在会拒绝一个条目名越出支持目录的归档（ADR-0042 的 zip-slip 门），走查时可以拿一份手工改过条目名的 zip 试一次，看它是不是整次都不落地）、写入卡片上的回退 pill（预览 → 确认 → 报告，含"被用户自己的编辑挡住"与"镜像没存"那两格）。browser tab 在非 macOS 上是占位降级（§2B），那一格标"待 macOS 验证"或直接在 macOS 上验。
5. 版本号只在 `pubspec.yaml` 递增过。
6. `git diff macos/Runner/*.entitlements` 为空（或存在已 ACCEPTED 的 ADR 解释改动）。
7. 无 key、无证书、无描述文件进入提交（`git status` 与 `git diff --cached` 双查）。
8. 签名与公证缺口未解决前（见 §4），不得声称"可对外分发"。

## 6. 已知坑（先查这里再排障）

- Podfile 抛 `.../Flutter/ephemeral/Flutter-Generated.xcconfig must exist`：先 `flutter pub get`（该 xcconfig 由它生成，Podfile 的 raise 原文就是这么提示的）。
- `flutter test` 报找不到包 / 缺 `.dart_tool` / pub cache 不存在：先 `flutter pub get`（新 clone 或换机器时缓存可能为空）。
- 换 Xcode / macOS 版本后 pod 报错：`cd macos && pod deintegrate && pod install`，仍不行再 `flutter clean`。不要手动删 `macos/Flutter/ephemeral/`。
- Kotlin/Gradle transforms 缓存竞态、`android/.gradle`、`abiFilters` 那类 Android 调优**目前与本仓库无关**：`android/` 只是 ADR-0057 的品牌脚手架，应用跑不起来，所以别照抄其他项目的构建经验过来；真要让它运行，先立 ADR。
- terminal tab 起不来：先确认不是 entitlements/沙箱被动过（§3），再看 `lib/host/terminal_manager.dart`。
- `flutter_pty`、`pasteboard`、`xterm` 有 windows 实现（终端/剪贴板跨桌面可用，仍待本机实测）；`flutter_inappwebview` **无** windows/linux 实现——浏览器 tab 已在 `browser_tab.dart` 门控降级（见 §2B）。给这些依赖加新平台分支前，先回到 §0 的平台范围（三桌面可运行 + 移动仅品牌脚手架，不含 web）。
- 布局溢出、RenderFlex 报错属 UI 层问题，走 `flutter-fix-layout-issues`，别误判成构建失败。
- **换开发机平台后第一条命令失败通常是没 `flutter pub get`**：`.dart_tool/`、`pubspec.lock`、macOS 的 `ephemeral` 都不入库，clone 里根本没有它们；`packages/board_panel` 是 path 依赖，同样依赖这一步解析。
- **tray / 全局热键 / 窗口隐藏不起作用**：先确认接线仍在 `lib/main.dart`（`tray_service`、`hotkey_service`、`window_manager`），再看 `lib/state/tray_service.dart`·`hotkey_service.dart`。这类症状不是构建失败，别去动 entitlements 或 Podfile。
