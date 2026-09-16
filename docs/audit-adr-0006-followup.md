# ADR-0006 落地后追加审计（2026-09-16）

> 方法：对 ADR-0006 五个 commit（`76ceddd`/`acf5991`/`0e0ce99`/`6fa85d6`）新增/改动代码做逐文件复查——键盘/语义可达性（对照已闭环的 A1 政策）、overlay 生命周期、riverpod 用法（人工对照 `riverpod_lint` 核心规则；该 lint 包在 Dart 3.11.5 基线下不可安装，见 ADR-0002 修订 1）、与既有 dsw/DswHoverTap 视觉语言的一致性。**修复随本审计同批落地，闭环状态见文末。**

## 发现（证据均为 `文件:行号`）

### F1｜快捷菜单芯片/行是裸 GestureDetector —— A1 键盘可达性回归（阻断）

`ui/settings/widgets/settings_quick_menu.dart:245`（`_Chip`）、`:275`（`_OpenSettingsRow`）用裸 `GestureDetector`：不进焦点遍历（Tab/Enter/Space 不可用）、无 `Semantics`（读屏只见文本）、无 hover/焦点视觉。违反 AGENTS §6"新交互控件走 shad 或 `DswHoverTap`，不要再手写 `MouseRegion + GestureDetector`"，等于在**新表面**上重开已闭环的 A1 缺口。菜单打开动作本身（sidebar 的 `DswHoverTap`）可达，但打开后**里面的所有选项都不可达**——比不可打开更糟。

### F2｜OverlayEntry 无属主 —— 生命周期泄漏（真 bug）

`settings_quick_menu.dart` 的 `showSettingsQuickMenu` 插入 `OverlayEntry` 后无人持有。复现：菜单开着 → 点 footer 的设置按钮 → body 整体切到全屏设置页，sidebar 卸载，菜单**仍浮在新页面上方**（幽灵菜单，还能点）。同理任何导致 sidebar 卸载的路径都泄漏。修法：entry 归 sidebar State 持有，`dispose()` 与 `onOpenSettings` 前移除。

### F3｜快捷菜单无 Escape 关闭（键盘 a11y）

设置面板有 `CallbackShortcuts(Escape)`（`model_settings.dart` build），快捷菜单只能点 scrim 关闭——键盘用户打开后**无法关闭**（Tab 也进不去，见 F1）。两个缺陷叠加。

### F4｜触发器语义标签错误

`sidebar.dart:427` 快捷菜单触发器的 `semanticLabel: context.tr('settings')`——它打开的是"快捷偏好"菜单而非设置页，读屏用户听到的是错误的名字。需要独立 i18n 键。

### F5｜收起栏（rail）模式下快捷菜单不可达

`sidebar.dart` 折叠态 footer 画了头像（`_UserAvatar`）但没包触发器——菜单只在宽栏可开。行为不一致：同一头像，宽栏能点、收起后不能。

### F6｜全屏设置内容列左贴（现代 UI/风格统一）

`model_settings.dart` `_content` 的 `ConstrainedBox(maxWidth:720)` 在 stretch 布局下**左对齐**——800px 居中卡片时代合理，全屏后宽窗口右侧大片留白，观感失衡。starkins 的内容区也是居中的。修法：内容列居中。

### F7｜riverpod 用法（人工 lint，非阻断）

`main.dart` `onSettingsChanged: (next) => scope.save(next)` 捕获了 build 期 `ref.watch` 的 `scope`。`appScope` 是 keepAlive、永不换实例，**无实际风险**；但按 `riverpod_lint` 的惯例（回调内用 `ref.read`）改为闭包内 `ref.read(appScopeProvider).save(next)` 更正。其余核对：所有 `ref.watch` 均在 build 期（无回调内 watch）、provider 命名规范、无 widget 内建 container —— 通过。`riverpod_lint` 本体在 Dart 3.11.5 不可安装（ADR-0002 修订 1），待 SDK 升级 ADR 一并引入。

## 修复（同批 commit）

| 发现 | 修复（✅ 已落地） | 验证 |
| --- | --- | --- |
| F1 | `_Chip`/`_OpenSettingsRow` 改 `DswHoverTap`（键盘激活 + `Semantics(button)` + hover/焦点视觉；芯片带 `toggled` 播报选中态） | ✅ `settings_quick_menu_test` 键盘激活断言（Tab+Enter 经 FocusableActionDetector 写文档） |
| F2 | `showSettingsQuickMenu` 返回 entry；sidebar State 持有并在 `dispose()`/打开设置前移除；重复打开先移除旧 entry | ✅ 代码走查 + 全量测试零回归 |
| F3 | `CallbackShortcuts(Escape)` + **Stateful 锚点 FocusNode**：菜单打开即 post-frame `requestFocus`（实测 `FocusScope(autofocus)` 不会从已聚焦节点抢焦点，Escape 根本到不了 bindings——修复过程中两次测试失败钉死了这一点） | ✅ Escape 关闭断言（entry.mounted == false） |
| F4 | 新 i18n 键 `quickPreferences`（en/zh），触发器 `semanticLabel` 改用之 | ✅ 双字典同键 |
| F5 | rail 态头像同样包 `DswHoverTap` 触发器（复用同一 LayerLink） | ✅ 代码 + analyze；观感待下次真机走查 |
| F6 | `_content` 滚动区内 `Center` 包 720 列 | ✅ settings_test 零回归；观感待下次真机走查 |
| F7 | `onSettingsChanged` 闭包内 `ref.read(appScopeProvider)` | ✅ analyze 零告警 |

> 本审计属 ADR-0006 的质量收尾，不占新 ADR 编号；发现-修复闭环在同批 commit 里可见。F1–F3 若不修，等于 ADR-0006 交付了一个键盘/读屏不可用的新表面——与 A1 已闭环的结论冲突，故列为阻断级优先处理。
>
> 门禁：`flutter analyze` 零告警 · format 零 diff · `flutter test` **669 通过（+2 守卫）/ 13 既有 Windows-only 失败零新增**。
