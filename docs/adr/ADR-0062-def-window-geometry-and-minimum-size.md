# ADR-0062: 窗口几何持久化与最小尺寸——重启回到上次的形状，且不再有 430px 卡片

- **状态**: ACCEPTED
- **分类**: DEF
- **优先级**: P2
- **影响维度**: 生产功能 / 认知障碍
- **日期**: 2026-10-04
- **来源**: kelivo 评估 §7 A9（kelivo `desktop_window_controller.dart` 的几何恢复与 min 960×640；其 macOS 交原生 autosave 的判断）+ 登记表观察行"窄窗（约 430px 卡片）"——外壳没设最小窗口尺寸是那串窄窗缺陷的产品前提
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

`windowManager.ensureInitialized()`（`lib/main.dart:131`）之后没有任何几何管理：重启回到平台默认尺寸与位置，`setMinimumSize` 从未设置——登记表窄窗观察行量到的 430px 卡片、`_SettingCellRow` 被压成 0.0px 宽，都发生在"应用允许被拉到任意窄"的前提下。kelivo 的对照实现：尺寸位置防抖落盘 + 恢复时按显示枚举防越界 + min 960×640；其 macOS 特判（Dart 侧不 setPosition、交原生 autosave）针对的是它自带的 bitsdojo 原生层，本仓库没有那层，window_manager 的 setPosition 在 macOS 直接可用。

## 决策（Decision）

**自持久化：拖动/缩放防抖 400ms 落盘，启动恢复 + 屏幕防越界 + `setMinimumSize(960×640)`。**

1. **存储**：`<support>/window.json`，独立小文件 + 同步 tmp+rename 原子写（`SessionRegistry` 的既有形状）；撕裂/损坏按"文件不存在"处理——几何不是必须带着走的数据。不进 prefs 文档：WorkbenchPrefs 是工作台 UI 偏好，窗口形状是另一类东西；不进 settings：它不该出现在备份里跟着会话跨机器（目标机器的屏幕不一样）。
2. **恢复防越界**：`screen_retriever`（window_manager 的既有传递依赖，升格为直接依赖——树上不进新包）取主显示器 `visiblePosition/visibleSize`，把恢复的边界夹回可见区：宽度/高度夹进可见矩形、位置保证标题条至少 80px 留在屏内。纯函数 + 测试。多显示器只按主屏夹——夹错的代价是窗口离主屏远一点，不是丢数据。
3. **最小尺寸 960×640**：kelivo 同值。登记表那条窄窗观察行的三条出路里，这正是出路①（"由组合根设最小窗口宽度"），该行随之可以销账一半。
4. **不动 show 流程**：不引入 `waitUntilReadyToShow` 重构——今天窗口的显示时序是三平台都跑着的现状，几何恢复用 `setBounds` 在首帧前追加，不赌重构。
5. **明确不做**：最大化/全屏状态的记忆（window_manager 的回调覆盖面在三平台有差异，S2 看需求）；macOS 原生 autosave（那是 kelivo 对它的 bitsdojo 层的绕行，我们没有那一层）。

## 后果（Consequences）

- **正面**：重启回到上次的形状；窄窗缺陷族失去产品前提；登记表观察行的一半（最小宽度）就地闭环。
- **负面/风险**：macOS 的 setPosition 时序在真机上待签收（ kelivo 在它们的原生层见过跳动，我们用 window_manager，行为待验）；防抖保存意味着强杀进程可能丢最后一次拖动——可接受。
- **中性**：`lib/state` +2 个小文件；`pubspec` 声明 `screen_retriever`（传递依赖升格）。

## 验证（Verification）

- `test/window_geometry_test.dart`：JSON 往返；clamp 纯函数（越界矩形夹回可见区、标题条保底）；store 往返 + 撕裂文件容忍。
- 四道门禁同口径；真机走查（重启恢复 + 拉到 960 以下被夹住）待人工。

## 关联（Links）

- 代码: `lib/state/window_geometry.dart`、`lib/state/window_geometry_store.dart`、`lib/main.dart`
- 关联 ADR: ADR-0048（中列顶部条的流内 chrome——几何变的是外壳不是内容）、登记表"窄窗胶囊 2.2x"观察行（本 ADR 处置其前提）
- 来源评估: `docs/kelivo-vs-agent-harness-2026-10.md` §7 A9
