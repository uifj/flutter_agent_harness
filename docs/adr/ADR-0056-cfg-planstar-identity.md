# ADR-0056: 产品身份统一到「企划星 / PlanStar」，并处理随 bundle id 走的应用数据

- **状态**: ACCEPTED
- **分类**: CFG
- **优先级**: P1
- **影响维度**: 认知障碍 / 安全合规 / 生产功能
- **日期**: 2026-10-04
- **来源**: 用户直接指令（品牌改名 + 桌面端图标/splash 落地），非审计发现
- **修复 commit**: 本次提交

## 背景（Context）

产品此前有三套互不相干的身份字符串，且**用户可见的那套是错的**：

1. `lib/l10n/locales.dart:37,860` 两棵字典的 `appName` 都是 `Agent Harness`；紧邻的注释（原 35-36 行）自己承认「这里曾经是 `DSH`，是被参考项目的缩写，不该出厂」。
2. `lib/ui/sidebar/sidebar.dart:596,635` 与 `lib/ui/conversation/conversation_root.dart:289` 的品牌标记是 `LucideIcons.droplet` —— **一枚水滴**，与星形品牌毫无关系。
3. `AppMeta.productName`（`lib/model/app_meta.dart:17`）值为 `agent_harness`，而 `grep -rn "AppMeta\.[a-zA-Z]*" lib test` 的字段引用计数里**它一次都没出现**（version 4 次、五个 URL 各 3 次）——一个写了没人读的常量；同时 `lib/main.dart:272` 的 `MaterialApp.title` 与 `lib/state/tray_service.dart:25` 的 tooltip 各自硬编码了一份 `Agent Harness`。三处必须相等，没有任何东西守着。

真正的风险在身份的另一半。`lib/main.dart:95` 调 `getApplicationSupportDirectory()`，实测它返回的是
`~/Library/Application Support/com.stow.agentHarness` —— **以 bundle id 命名，不是 `PRODUCT_NAME`**（同目录内实有 38 个文件 / 293,108 字节：`settings.json`、`prefs.json`、`plan_space.json`、`sessions/`、`workbench/`、`approvals.json`、`usage/`、`logs/`）。因此改 `PRODUCT_BUNDLE_IDENTIFIER`（`macos/Runner/Configs/AppInfo.xcconfig`）会让整个应用状态留在原地，而新目录是空的——空目录与「用户从没配置过」在界面上完全无法区分。

顺带量到一处 HEAD 上就已存在的缺陷：`macos/Runner.xcodeproj/project.pbxproj` 的 `TEST_HOST` 指向 `agent_harness.app`，而 HEAD 的 `PRODUCT_NAME` 是 `Agent Harness`（`git show HEAD:macos/Runner/Configs/AppInfo.xcconfig`），即 **macOS 的 RunnerTests 目标在本次改动之前就已经找不到宿主 App**。

Keychain 一侧经实测不构成风险：`lib/state/secret_store.dart:30-32` 显式 `useDataProtectionKeyChain: false`，走经典文件钥匙串；`flutter_secure_storage_macos-3.1.3/.../FlutterSecureStorage.swift:51` 只在传了 `accountName` 时才写 `kSecAttrService`，而我们没传，access group 也未设 —— **bundle id 不在查询条件里**。且 `security find-generic-password -a zcodejwttoken` 返回「未找到」，这台机器没存过密钥。

## 决策（Decision）

**统一命名**：中文 **企划星**，拉丁 **PlanStar**；pubspec 包名 `planstar`（对齐参考实现 ZCode 的约定：`_archive_project/ZCode-main/package.json:2` 就是裸小写 `"name": "zcode"`）；bundle id **`top.planstar.desktop`**（用户域名 `planstar.top` 反写，`.desktop` 留给将来的移动姊妹包）。

按平台各自的规矩分派，而不是把一张图到处塞：

| 平台 | 遮罩由谁做 | 交付形状 |
| --- | --- | --- |
| macOS | 系统**不**遮罩 | Apple 网格烘圆角：图形占画布 80.5%、圆角 22.5%，7 个尺寸 |
| Windows | shell 自己圆 | `.ico` 满幅方图（16…256） |
| HarmonyOS/移动分层 | 系统遮罩 | 1024 双层：不透明渐变背景 + 透明前景，满幅无圆角 |
| iOS | 系统遮罩 | 19 张满幅**不透明**方图（带 alpha 会被 App Store 拒） |
| Android | 系统遮罩（API 26+） | legacy mipmap 自带圆角方形 + adaptive 双层 |

**数据迁移随身份同批落地**（`lib/host/support_directory.dart`）：解析出支持目录后、任何读取之前，把旧的兄弟目录整体 `rename` 到新的身份上；目标已有数据就绝不动；rename 失败（跨设备）退化为复制并保留原件。放在 `lib/host/` 是因为 `check_architecture` 规则 5 只禁 `lib/ui` 直接 `dart:io`。

**候选方案与否决**：
- *不改 bundle id*（只改显示名）——被否：一个要上架的商用产品（ADR-0045 形态②）顶着 `com.stow.agentHarness` 与 `Runner.rc` 里的 `CompanyName = com.example`，签名/公证阶段必须再动一次，届时同样要迁移，只是把代价推到更贵的时候。
- *保留旧目录并双读*——被否：两份必须相等的状态正是本仓库反复立律要消除的东西（ADR-0014「两个必须相等的字段就是一种新的错法」）。
- *给 `~/.agent_harness` 加旧路径回退*——被否：外部用户 0，这台机器上该目录实测不存在，加回退就是加一条没人走的分支。

**品牌标记不换成位图**：侧栏那格是 24px、且底色随主题变。实测品牌蓝压在深色侧栏上只有 1.19:1（与 ADR-0056 同期量到的宠物对比度同一条律），所以改用 `LucideIcons.sparkle` 继续吃 `color.labelPrimary`；同时刻意**不**用 `LucideIcons.star`——那枚已经是企划里「收藏」的字形（`plan_data_view_screen.dart:439`、`plan_templates_screen.dart:136`、`plan_object_info_screen.dart:206`）。真正的位星形标记只出现在够大、底色已定的表面：应用图标、托盘、splash。

**单一真值**：`MaterialApp.title` 与托盘 tooltip 改为读 `AppMeta.productName`，那个死常量从此有了读者，硬编码副本从 3 降到 1。

## 后果（Consequences）

- **正面**: 用户可见的名字与图标终于一致；`productName` 不再是没人读的常量；macOS RunnerTests 的 `TEST_HOST` 与 `Runner.xcscheme` 的 4 处 `BuildableName` 一并修好；换 bundle id 不再丢数据。
- **负面/风险**: ① 真机首启的迁移**未在原作者目录上实跑过**（只在副本上跑通），需人工签收「新目录出现、旧目录消失、设置与会话都在」。② 将来签名落地、`useDataProtectionKeyChain` 翻成 true 之后，bundle id 就**会**进入钥匙串 access group——那时再改身份开始吃 API key。③ 包名 `agent_harness → planstar` 改了 479 行 import / 111 个文件，与同期任何分支合并必冲突。
- **中性**: 三处仍写作 `agent_harness` 且是故意的——GitHub 仓库名 `flutter_agent_harness`（改它是对外动作）、两篇带日期分析文档的**文件名**（磁盘上真实存在，改引用不改文件就断链）、以及 `legacySupportNames` 里那条旧 bundle id（迁移就靠它）。

## 验证（Verification）

```
test/support_directory_test.dart           5 棵：整体搬迁 / 已有数据不许动 / 无事可做 /
                                           空 legacy 不误搬 / 当前身份不会把自己搬走
```
红-先验证：删掉「目标已有数据就不动」那道闸，测试当场红在
`Expected: null  Actual: 'com.stow.agentHarness (copied)'`，恢复后绿。

真数据演练：把本机真实的 `com.stow.agentHarness` 复制进临时目录后跑真实函数——
`MIGRATED 38 files, 293108 bytes`，相对路径集合与总字节完全守恒，旧副本不残留。

门禁：`dart format` 0 changed、`dart analyze --fatal-infos` No issues、
`dart tool/check_architecture.dart` = 7 recorded / 0 new、`flutter test` 相对基线零新增失败、
`flutter build macos --debug` 出 `PlanStar.app`，`plutil -p` 读回
`CFBundleIdentifier = top.planstar.desktop` / `CFBundleName = PlanStar` / `CFBundleDisplayName = 企划星`。

## 关联（Links）

- 代码: `lib/host/support_directory.dart`、`lib/main.dart#L95-L101`、`lib/model/app_meta.dart#L17`、`macos/Runner/Configs/AppInfo.xcconfig`、`macos/Runner/Info.plist`
- 测试: `test/support_directory_test.dart`、`test/sidebar_test.dart`（品牌行那棵守卫原名即「wears our name」）
- 关联 ADR: ADR-0057（同期把 android/ios 作为品牌脚手架加入）· ADR-0045（商用形态②，本次身份统一的动机）· ADR-0014（「两个必须相等的字段就是一种新的错法」，否决双读方案）
