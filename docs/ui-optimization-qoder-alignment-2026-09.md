# UI 优化：Qoder 风格对齐（2026-09-17）

> 参考：Qoder 设置页与聊天页截图（4 张），红色标注为具体修改点。
> 目标：在现有 dsh 令牌体系 + shadcn_ui 组件约束下，补齐 4 处与 Qoder 的视觉差距。
> 原则：减法优先，不动架构，令牌体系不变。

## 修改清单

### 1. Sidebar Footer 合并为一行

**现状**（`lib/ui/sidebar/sidebar.dart:540-626`）：
- Wide 模式下 footer 有两行：`_profileRow()`（头像 + 姓名 + 邮箱）+ 第二行（设置按钮 + details toggle）
- 设置按钮带齿轮 icon + "设置" 文字，占一整行

**目标**（参考 Qoder 截图 2 底部）：
- 合并为一行：左侧头像 + 姓名/邮箱，右侧齿轮 icon（无文字）+ details toggle
- 去掉 "设置" 文字，只保留齿轮 icon

**实现**：
- 修改 `_footer()` wide 分支：将 `_profileRow()` 与设置按钮合并为单个 `Row`
- 设置按钮去掉 `Text('settings')`，只留 `Icon(LucideIcons.settings, size: 16)`
- Rail 模式（collapsed）保持不变：头像 + 齿轮 icon + details toggle 纵向排列

**涉及文件**：`lib/ui/sidebar/sidebar.dart`

---

### 2. Composer 右侧对齐

**现状**（`lib/ui/conversation/composer.dart:616-664`）：
- `_row()` 使用 `Spacer()` 分隔左右，但 model chip + send button 未贴到最右边
- 右侧有 8px padding + chip 间距，视觉上离右边缘有距离

**目标**（参考 Qoder 截图 2 右下角红色标注）：
- Model chip + send button 贴近 composer 卡片右边缘
- 去掉右侧多余间距，让 send button 与卡片右边缘对齐

**实现**：
- 调整 `_row()` 的 `padding`：右侧从 8px 减至 4px（与左侧 attach 按钮对称）
- 调整 model chip 与 send button 之间的 `SizedBox` 间距（12px → 8px）
- 确保 `Spacer()` 正确推挤右侧元素到最右

**涉及文件**：`lib/ui/conversation/composer.dart`

---

### 3. 工作区 / Git 分支状态栏

**现状**：
- Composer 下方没有工作区信息栏
- 工作区名称只在 hero picker 和 settings 中出现

**目标**（参考 Qoder 截图 2 底部红色标注 + Qoder 截图 3 底部）：
- 在 composer 卡片下方添加一行状态栏
- 显示：工作区名称（文件夹名）+ git 分支名（如果有）
- 格式：`flutter_agent_harness  本地  develop`（Qoder 风格）
- 点击可触发工作区切换（复用 hero picker 逻辑）

**实现**：
- 新增 `_WorkspaceStatusBar` widget，放在 composer `_card()` 下方
- 数据来源：`widget.workbench.workspaceRoot`（工作区路径）+ `git.branch()`（当前分支）
- 工作区名称取路径最后一段（`path.split('/').last`）
- Git 分支通过 `GitProcess` 查询，失败时不显示分支
- 样式：28px 高度，labelTertiary 文字，hover 时背景变化，点击触发 `onPickWorkspace`

**涉及文件**：
- `lib/ui/conversation/composer.dart`（添加状态栏）
- `lib/l10n/locales.dart`（新增文案键：`workspaceStatusBar`、`localBranch`）

---

### 4. 设置页视觉优化

**现状**（`lib/ui/settings/model_settings.dart`）：
- 已有 6 个分类导航（常规/外观/模型/工作区/工作台/扩展）
- Nav cell 有 icon + label，选中态有背景色
- 内容区是卡片式布局

**目标**（参考 Qoder 截图 1 + 截图 4）：
- 导航栏增加搜索框（顶部）
- Nav cell 选中态更明显（圆角 + 背景色 + 左侧 accent）
- 内容区每个设置项左侧加 icon（与导航 icon 呼应）
- 设置项之间用细分隔线而非卡片边框

**实现**：
- 在 `_nav()` 顶部添加搜索框（`ShadInput` + search icon）
- 修改 `_NavCell` 选中态：左侧 3px accent bar + 圆角背景
- 内容区设置项（如主题/语言行）左侧添加对应 icon
- 设置项之间用 `borderL1` 细分隔线替代卡片边框

**涉及文件**：
- `lib/ui/settings/model_settings.dart`
- `lib/l10n/locales.dart`（新增：`searchSettings`）

---

## 执行顺序

1. Sidebar footer 合并（改动最小，风险最低）
2. Composer 右侧对齐（纯样式调整）
3. 工作区状态栏（新增组件，需要 git 分支查询）
4. 设置页优化（改动最大，分步进行）

每步完成后跑 `flutter analyze` + `flutter test` 确保无回归。

## 不动的部分

- dsh 令牌体系（颜色/字号/阴影/动效）
- 品牌色 `deepseek500`
- 约束求解布局 `computeColumns()`
- Keep-alive 面板机制
- Genkit 只在 `lib/genkit/`
