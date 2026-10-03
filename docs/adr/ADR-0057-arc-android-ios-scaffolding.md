# ADR-0057: 加入 android/ 与 ios/ 平台目标，作为「只带品牌、不保证运行」的脚手架

- **状态**: ACCEPTED
- **分类**: ARC
- **优先级**: P2
- **影响维度**: 评估阻断 / 生产功能
- **日期**: 2026-10-04
- **来源**: 用户直接指令（明示「暂不确保能真实运行」），非审计发现
- **修复 commit**: 本次提交

## 背景（Context）

`build.md` §0 此前明文禁止这两个目录：「**没有** `android/`、`ios/`、`web/`……别去补这些目录，那仍是 ARC 级决策」。本 ADR 就是那条规则要求的那份决策。

加入的理由是品牌交付：企划星需要一个移动端外壳来承载 ADR-0055 之后确定的图标与 splash 资产（分层图标、各尺寸启动页、宠物形象），而它们此前只能躺在仓库外的一个下载目录里，没有任何平台消费它们。

**为什么它现在跑不起来，有精确证据。** `flutter create --platforms=android,ios` 后 iOS 侧生成的注册表 `ios/Runner/GeneratedPluginRegistrant.m` 只注册了 5 个插件：

```
FilePickerPlugin  FlutterSecureStoragePlugin  InAppWebViewFlutterPlugin
PasteboardPlugin  URLLauncherPlugin
```

拦路的是三个：**`window_manager`、`tray_manager`、`hotkey_manager`** —— 它们的 pubspec `flutter.plugin.platforms` 只声明 linux/macos/windows，两档移动注册表里都没有它们（实测 `grep -c "WindowManager\|TrayManager\|HotKeyManager"` 在 iOS 与 Android 两份 `GeneratedPluginRegistrant` 上都是 **0**）。而 `lib/main.dart:131` 在 `runApp` 之前无条件执行

```dart
await windowManager.ensureInitialized();
```

`lib/main.dart:210` 之后的首帧回调里还接着起 `_initHotkeys()` 与 `_initTray()`（`lib/state/tray_service.dart:10-11`、`lib/state/hotkey_service.dart:13`）。终端在 `lib/host/terminal_manager.dart:20` 直接 import `package:flutter_pty`——注意它**不是**拦路的那个：它在 android/ios 都按 `ffiPlugin: true` 声明、会被打包进去（所以不出现在注册表里是正常的），运行时能否真开出 pty 未验证（iOS 禁 `fork`），但执行顺序上排在 `windowManager.ensureInitialized()` 之后，还轮不到它。另外两个各缺一半：`lib/ui/conversation/composer.dart:22` 用 `pasteboard`（只缺 android，iOS 注册表里有它），`lib/ui/conversation/conversation_root.dart:16` 用 `desktop_drop`（只缺 ios，Android 注册表里有 `DesktopDropPlugin`）。`lib/host/project_folder_ops.dart` 的 security-scoped bookmark 是 macOS 专属。

**编译与运行是两件事，两个平台都实测过。** `flutter build ios --debug --no-codesign` 成功产出 `build/ios/iphoneos/Runner.app`（209M，`Building top.planstar.desktop for device (ios)...`）；`flutter build apk --debug` 同样成功，产出 `build/app/outputs/flutter-apk/app-debug.apk`（197,779,066 字节）。也就是说 Dart 侧能为两个移动目标编译通过，**插件缺失完全不在编译期暴露**；它会在启动第一行以 `MissingPluginException` 炸掉，永远到不了第一帧。所以「构建绿」在这两个目标上**一点都不**代表「能跑」，而 CI 若加上移动构建会给出假绿。

**两个 `flutter create` 陷阱，实测踩到：**

1. 它**改写了 `.metadata` 并丢掉未列出平台的记录**——加 android/ios 时，`migration.platforms` 里的 `linux` 与 `windows` 两行被替换掉。已手工补回五棵（root/linux/windows/android/ios）。
2. 它往 `test/` 扔了一个模板 `widget_test.dart`，内容引用本项目不存在的 `MyApp`，当场把 `dart analyze --fatal-infos` 打成 `error - test/widget_test.dart:16:35 - The name 'MyApp' isn't a class`。已删除。
3. （环境而非代码）首次 `flutter build apk` 失败在 `pdfrx` 的 pdfium 取包：其 `android/CMakeLists.txt:43` 的 `file(DOWNLOAD …)` **不检查 STATUS**，下载失败是静默的，错误延后到 `:59` 的 `file COPY cannot find …/libpdfium.so` 才现形。根因是这台机器直连 GitHub 不通（`curl -sIL` 得 `http=000`），走 `127.0.0.1:7897` 代理则 `http=200`；导出 `http_proxy/https_proxy/ALL_PROXY` 后构建通过。与本次改动无关，但会伪装成"加了 android 就构建失败"。

## 决策（Decision）

加入 `android/` 与 `ios/`，**定位为品牌脚手架**：它们消费品牌资产、参与三平台门禁的静态检查，但**明确不保证可运行**，任何交付说明里不得称其为可用平台。

身份对齐：Android `namespace` 与 `applicationId` 均为 `top.planstar.desktop`（`MainActivity.kt` 随之移到 `kotlin/top/planstar/desktop/`），iOS 6 处 `PRODUCT_BUNDLE_IDENTIFIER` 同值，`CFBundleDisplayName = 企划星`。与 ADR-0056 的桌面 bundle id 保持一致。

图标与 splash 按各平台遮罩规则分别产出，不复用同一张图：

| 平台 | 遮罩 | 交付 |
| --- | --- | --- |
| iOS | 系统遮罩 | 19 张满幅**不透明**方图（带 alpha 会被 App Store 拒）；`LaunchLogo.imageset` 1x/2x/3x + `LaunchScreen.storyboard` 背景换成品牌蓝 |
| Android ≤25 | 无遮罩 | `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png` 自带圆角方形 + `ic_launcher_round.png` 圆形 |
| Android 26+ | 系统遮罩 | `mipmap-anydpi-v26/ic_launcher.xml` 引 `ic_launcher_background`（渐变）+ `ic_launcher_foreground`（前景），432×432 |
| Android 31+ | 系统 SplashScreen | `values-v31/styles.xml` 的 `windowSplashScreenBackground` / `windowSplashScreenAnimatedIcon` |

分层图标的前景内容实测占 432 画布的 **63.4% × 59.3%**，在 Android 66.7% 安全区内，无需缩放。

**候选方案与否决**：
- *先做平台门控再加目录*——被否：那是把 ADR-0056 之外的第二个大工程（要动 `main()` 启动链、终端、剪贴板、拖拽、书签授权五条线）塞进一次品牌交付；用户明确只要脚手架。
- *只放图标不放目录*——被否：Android/iOS 的图标必须活在平台自己的资源树里才会被工具链消费，放在仓库外等于没有。
- *加 `web/`*——被否：`dart:io` 在 web 不可用，且没有任何 web 消费者。

## 后果（Consequences）

- **正面**: 品牌资产第一次进入可构建的平台树并被平台工具链校验（iOS 图标无 alpha、Android adaptive 安全区都过了）；三桌面 + 两移动的身份字符串从此同一来源；`flutter create` 的模板产物完整。
- **负面/风险**: ① **这两个平台不能运行**，且这一点**没有任何自动检查能发现**——iOS 与 Android 的构建都是绿的。自动化越完整，误判越确信，因此本 ADR 是这条边界的唯一记录处，判据只能是 `GeneratedPluginRegistrant` 里缺不缺那五个插件。② `build.md` §0 的「没有 android/ios」失效，必须同步改写，否则下一个读规则的人会以为它们不存在。③ 真正要跑起来需要一份新 ADR，逐门处理 window_manager / tray_manager / hotkey_manager / flutter_pty / pasteboard / desktop_drop / 书签授权。④ `.metadata` 与模板 `widget_test.dart` 两处会被 `flutter create` 悄悄改动（见背景三条陷阱），下次再跑必须复查。
- **中性**: 移动端的图标尺寸表与桌面不同源，未来若引入 `flutter_launcher_icons` 之类生成器需另立 DEP 类 ADR（本仓库不新增依赖）。

## 验证（Verification）

```bash
# 目录与身份
ls -d android ios && grep -rn "top.planstar.desktop" android/app/build.gradle.kts ios/Runner.xcodeproj/project.pbxproj | wc -l
# iOS 图标必须不透明
python3 -c "from PIL import Image;import glob;print([p for p in glob.glob('ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png') if Image.open(p).mode!='RGB'])"   # 期望 []
# Android adaptive 前景须落在 66.7% 安全区内
python3 -c "from PIL import Image;im=Image.open('android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png');b=im.getbbox();print((b[2]-b[0])/432,(b[3]-b[1])/432)"
# 编译能过（但这不代表能运行）
flutter build ios --debug --no-codesign
flutter build apk --debug          # 需先 export http_proxy/https_proxy/ALL_PROXY，见背景第 3 条陷阱
# 缺失的插件——这条才是「不能跑」的判据，两个平台都要查
grep -c "WindowManager\|TrayManager\|HotKeyManager" ios/Runner/GeneratedPluginRegistrant.m   # 期望 0
grep -rn "window_manager\|tray_manager\|hotkey_manager" android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java   # 期望无输出
# flutter create 塞进来的模板测试必须不在树里
ls test/widget_test.dart 2>&1 | grep -q "No such file" && echo "widget_test.dart absent"
# .metadata 五棵平台都要在
grep -c "platform: " .metadata   # 期望 5
```

三桌面门禁（format / analyze --fatal-infos / flutter test / check_architecture）须保持与基线一致；`flutter test` 与平台目录无关，不会因本次改动变红。

实测本次：format 0 changed（304 files）、analyze No issues、check_architecture 7 recorded / 0 new（182 files）、`flutter test` 相对基线零新增失败、`.metadata` 补回 5 棵、`test/widget_test.dart` 已删。

## 关联（Links）

- 代码: `android/app/build.gradle.kts`、`android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`、`android/app/src/main/res/values-v31/styles.xml`、`ios/Runner/Assets.xcassets/AppIcon.appiconset/`、`ios/Runner/Base.lproj/LaunchScreen.storyboard`
- 阻断点: `lib/main.dart#L131`、`lib/state/tray_service.dart#L10-L11`、`lib/state/hotkey_service.dart#L13`、`lib/host/terminal_manager.dart#L20`、`lib/host/project_folder_ops.dart`
- 关联 ADR: ADR-0003（增加桌面平台目标的先例，本 ADR 沿用其分类与写法）· ADR-0056（同期身份统一，bundle id 同源）· ADR-0002 修订 1（`build.md` §0 的平台范围条款由本 ADR 取代其「没有 android/ios」一句）
