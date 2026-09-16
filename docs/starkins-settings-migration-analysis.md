# starkins_app 设置页 → agent_harness 迁移分析

> 源：`D:\workspaces\stow_arch\stow-main\apps\starkins_app`（近亲架构：同 riverpod 3.2.1 + vendored `shadcn_ui` + shared_preferences，另依赖 `colorist_ui`/`appflowy_editor`/`board_panel`）。
> 目标：本项目 `agent_harness` 的 `lib/ui/settings/model_settings.dart`。
> 结论先行：**starkins 设置页不能整页照搬**（与本项目三条硬不变量冲突，且近半是占位/依赖本项目没有的子系统）；值得迁的是它"偏好设置"里本项目缺的**几项外观/行为开关**，且每一项都要**重接到本项目的 model/子系统 + dsw 令牌 + `context.tr`**，不是复制。

## 1. 两边设置页现状对照

| 维度 | starkins_app | agent_harness |
| --- | --- | --- |
| 形态 | **两层**：侧栏 `SettingsPanel`（OverlayEntry 级联弹层，quick 偏好）＋全屏 `SettingsPage`（`Navigator.push`，左 nav-rail 12 节） | 一层：模态 overlay `SettingsPanel`（800px 面板 + 188px nav-rail，5 节：general/models/workspace/workbench/extensions） |
| 状态/持久化 | `Notifier<AppPreferences>`（**纯内存**，build 里不 load；shared_preferences 是依赖但该 provider 未接）＋`SystemSettings` | `SettingsStore`（**原子 tmp+rename 落盘**）＋ `settingsDocument` read-seam；`WorkbenchPrefs`/`prefsStore` |
| 配色 | 直接 `ShadTheme.of(context).colorScheme.*` ＋ `WorkspaceMetrics/Colors` 自有 token | `DswAlias`（`context.dsw`）；ShadTheme 经 `dsw_shad_bridge` 由 DswAlias 供色，规则**禁止**读 ShadTheme 配色 |
| 文案 | **硬编码中文**字面量 | `context.tr()`＋en/zh 双字典（新增键必须两边都加） |
| 路由 | `Navigator.push(SettingsPage)` 全屏路由 | **无命名路由表**、单窗口、overlay/scope 拼装（AGENTS 明确删了 `flutter-setup-declarative-routing`） |

## 2. starkins「偏好设置」逐项 → 迁移判定

| starkins 项 | agent_harness 现状 | 判定 | 落地成本 |
| --- | --- | --- | --- |
| 语言、主题亮暗 | **已有**（General 段的 segmented：system/light/dark、system/en/zh） | ❌ 不迁（重复） | — |
| 对话宽度（normal/wide） | 有 `LayoutController`＋`ui/layout/columns.dart` 约束求解，无此开关 | ✅ **改造迁**（最值）：`AppSettings`/`WorkbenchPrefs` 加字段 → 接进列宽求解因子 | 低-中 |
| 默认展开工具调用（on/off） | `tool_card`/`disclosure_row` 有展开态但无默认开关 | ✅ **改造迁**：加 pref → `agent_runtime`/`tool_card` 初值 | 低 |
| 提示词建议（on/off） | composer 无"下一步建议"子系统 | ⚠️ 依赖未有的后端能力；**只能先存字段、行为待后端** | 行为=不可（缺子系统） |
| 预览方式（图片/Markdown） | editor/browser tab 各自处理，无统一开关 | ⚠️ 可存字段，接现有 tab 语义需设计 | 中 |
| 对话字体（无衬线/衬线）、字号 | **固定** `DswType` 刻度＋DSW 字体族栈 | ⚠️ **触及主题系统**：要做可调需引入字体档令牌＋重排刻度，非设置页级改动 | 高（架构） |
| 界面风格（默认/玻璃/经典/羊皮纸） | 单一 dsh `DswAlias` 主题 | ❌ **架构级**：4 套皮肤=4 份 alias＋切换，或不做；与"1:1 移植 dsh"冲突 | 高（需 ADR） |

## 3. starkins 其它分区 → 判定

| 分区 | 判定 | 理由 |
| --- | --- | --- |
| 个人资料（邮箱/订阅/退出登录） | ❌ | agent_harness 是本地 BYO-API-key 工具，**无账号体系**（只有 `ModelSettings.apiKey`）；无对应可接 |
| 系统设置（部分真实）/更新应用 | ❌/暂缓 | 更新检查、系统权限是 starkins 桌面分发特有；本项目 `build.md` §4 签名/公证都还没做，无"更新"子系统 |
| 语音/快照/快捷键/意识/工作台/安全/实验 | ❌ | starkins 自己多为 `PlaceholderSection` 空壳，或绑 `colorist_ui`/`board_panel` 等本项目不引的库 |

## 4. 通用控件（`settings_controls.dart`）

`SettingsPageTitle`/`SettingsCard`/`SettingRow`（leading/图标+标题+副标题+trailing+badge、卡片带分隔线）设计干净、可参考；但**照抄违反本项目三条约定**（读 ShadTheme 配色、硬编码中文、自带 radius token）。可行做法：改造成本项目版本（`context.dsw` 取色、`DswType` 取字、`context.tr` 取文案、圆角走 dsw 令牌），用它**统一** `model_settings.dart` 里现存的行/卡片写法——属"控件层重构"，非"迁移 starkins 页面"。

## 5. 推荐落地（不变量安全的增量，非整页照搬）

1. **给 `AppSettings`（或 `WorkbenchPrefs`）加 3 个真能用上的开关**：对话宽度、默认展开工具调用、预览方式；每个进 `SettingsStore` 落盘＋`context.tr` 双字典。
2. **General 段加对应行**，复用 `model_settings.dart` 已有 segmented/switch 控件（不引 starkins 控件）。对话宽度接 `LayoutController`、展开态接 `tool_card`/`_RowState`、预览接现有 tab。
3. **"提示词建议"只存字段**，行为待后端能力到位再接（别造假开关）。
4. 字体/字号、界面风格、账号、更新、各占位分区 → **不迁**，在本表留痕即可。

## 6. 需要拍板的点（不擅自决定）

- 是否接受"加 3 个偏好开关"这种**改造式合并**，而不是"把 starkins 设置页整页搬过来"（后者会同时破坏 no-router / 自研 i18n / dsw 令牌 三条硬约束，且近半为空壳）。
- 对话宽度是放 `AppSettings`（跨重启、影响布局）还是 `WorkbenchPrefs`（工作区级）——取决于希望它跟"账号"还是跟"会话布局"走。
- 界面风格(玻璃/羊皮纸)若真要，需单开 ADR（多皮肤 = 多套 DswAlias，架构决策）。

> 本文件是分析/决策文档；未改任何代码。按第 5 节实施前，请确认第 6 节三点。
