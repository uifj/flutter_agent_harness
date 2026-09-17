# UI 设计优化方案（2026-09-17）

> 参考：Qoder / Zcode 的现代化极简设计 + shadcn_ui 的组件美学。
> 目标：在保留 dsh 视觉身份（令牌体系、品牌色）的前提下，让界面更轻盈、更现代。
> 原则：**减法优先** —— 减少视觉噪音，增加呼吸感，不动架构。

## 现状诊断

当前 UI 是 dsh（DeepSeek Harness）的忠实端口，令牌体系纪律良好（无越界 BoxShadow、无魔数、暗色对比度几乎全过），但存在以下"看起来不够现代"的问题：

| 问题 | 原因 | 影响 |
| --- | --- | --- |
| 边框过重 | 每个面板/卡片都有 `borderL1`/`borderL2` 描边，视觉噪音大 | 界面"方框感"强，不够通透 |
| 间距偏紧 | sidebar 行高 32px、padding 8px，tab strip 34px | 内容挤在一起，缺少呼吸感 |
| Composer 胶囊过重 | r22 大圆角 + `DswShadow.lv2` 双层阴影 | 像 floating bubble，不像现代输入框 |
| Tab 活跃态过显 | 2px `brandPrimary` 顶边 + `bgLayer2` 填充 | 视觉重量过大，抢注意力 |
| 按钮/控件尺寸偏小 | 28px 圆形按钮、12px 图标 | 在高分屏上显得局促 |
| Hero 状态平淡 | 居中 composer + 简单 headline | 缺少现代产品的欢迎感 |
| 表面层次不清晰 | bgLayer1/2/3 在亮色下全部塌陷为白色 | 面板之间缺少微妙的深度差异 |

## 优化项（按优先级排序）

### P0 — 边框轻量化

**现状**：面板分隔线用 `borderL1`（4% 不透明）和 `borderL2`（10% 不透明），在亮色下已经比较淡，但多个边框叠加仍产生"格子"感。

**优化**：
- 面板间的主分隔线保持 `borderL1`（4%），但将 `borderL2`（内部控件边框）降至 6% 不透明
- 去掉不必要的边框：session row 选中态去掉边框只用背景色 wash，composer 卡片用更淡的边框替代阴影
- 参考 shadcn_ui：用 `border` 令牌统一为 1px + 极低不透明度，靠背景色差异区分层次

**涉及文件**：`dsw_alias.dart`（调整 `borderL2` 亮色值）、`app_frame.dart`、`sidebar.dart`、`composer.dart`

### P0 — 间距与呼吸感

**现状**：sidebar 行高 32px、session row padding 8px、tab strip 34px。

**优化**：
- Session row 高度 32px → 36px，padding 8px → 10px
- Sidebar 内部 vertical padding 6px → 8px
- Tab strip 高度 34px → 36px，tab chip 内部 padding 增加 2px
- Composer 内部 padding 适当增加
- 面板间 divider 的 pill 尺寸保持，但增加 hover 区域的视觉反馈

**涉及文件**：`sidebar.dart`、`workbench_tab_bar.dart`、`composer.dart`

### P1 — Composer 现代化

**现状**：r22 胶囊 + `DswShadow.lv2` 双层阴影 + `borderL2DarkmodeThin` 边框。

**优化**：
- 圆角 r22 → r16（更克制的圆角，接近 shadcn 的 `--radius` 默认值）
- 阴影 `lv2` → `lv1`（单层轻阴影）或完全去掉阴影改用更明显的边框
- 在 hero 状态下保持胶囊感，在 active（docked）状态下改为更方正的矩形卡片
- 发送按钮从 34px 圆形改为更紧凑的设计

**涉及文件**：`composer.dart`

### P1 — Tab Strip 轻量化

**现状**：活跃 tab 有 2px brandPrimary 顶边 + bgLayer2 填充 + 右侧 borderL1 分隔。

**优化**：
- 活跃 tab 顶边 2px → 1.5px，颜色从 `brandPrimary` 改为 `labelPrimary`（更克制）
- 去掉 tab 之间的右侧分隔线，改用 hover 时的微妙背景区分
- Tab chip 圆角从直角改为 r6（顶部圆角），更接近现代编辑器的 tab 风格
- 关闭按钮从 r3 改为 r4，尺寸从 16px 改为 18px

**涉及文件**：`workbench_tab_bar.dart`

### P1 — 按钮与控件尺寸

**现状**：Toggle cluster 按钮 28px，图标 16px；sidebar 图标按钮 28px/36px。

**优化**：
- Toggle cluster 按钮 28px → 32px，图标 16px → 18px
- Sidebar 图标按钮保持 28px（rail 36px 不变），但增加 hover 时的微妙缩放或颜色过渡
- New Session 按钮高度 38px → 36px（与 shadcn Button sm 对齐）

**涉及文件**：`app_frame.dart`、`sidebar.dart`

### P2 — Hero 状态增强

**现状**：居中 composer + 简单 headline（34px icon + 26/32/500 text）。

**优化**：
- 增加一个微妙的背景装饰（如极淡的渐变或网格纹理）
- Headline 下方增加一行描述性文字（labelTertiary，xxs12）
- Composer 在 hero 状态下保持胶囊但增加更明显的 hover 态
- 参考 Qoder 的欢迎页：简洁但有品牌感

**涉及文件**：`conversation_root.dart`、`composer.dart`、`hero_workspace_picker.dart`

### P2 — 表面层次细化

**现状**：亮色下 bgLayer1/2/3 全部塌陷为 `neutralBluish00`（纯白），只有暗色下才有层次。

**优化**：
- 亮色下给 bgLayer2 一个极淡的灰度（如 `neutralBluish25` 如果 palette 有的话，或用 `rgba(0,0,0,0.01)`）
- 让面板之间有微妙的深度差异，而不是全靠边框区分
- 注意：这需要新增 static color 或 alias token，需评估是否破坏 1:1 端口纪律

**涉及文件**：`dsw_static.dart`、`dsw_alias.dart`

### P2 — 微动效增强

**现状**：只有 `DswMotion` 的 100/200/300ms 三档，曲线 `Cubic(0.4, 0, 0.2, 1)`。

**优化**：
- 按钮 hover 增加 50ms 的颜色过渡（当前是瞬时切换）
- Tab 切换增加微妙的 fade 过渡
- Panel open/close 保持现有 300ms 但曲线改为更弹性的 `Cubic(0.34, 1.56, 0.64, 1)`（仅用于 panel 尺寸变化）

**涉及文件**：`dsw_motion.dart`、各组件的 `AnimatedContainer`/`AnimatedOpacity`

## 不动的部分

以下设计决策**保持不变**，因为它们是有意的产品身份：

- **dsh 令牌体系**：89+ 语义别名、11 档 UI 刻度、4 级阴影 ramp —— 这是设计系统的骨架
- **品牌色**：`deepseek500` 作为信息/主按钮色 —— 这是品牌识别
- **暗色主题**：当前暗色主题对比度几乎全过 AA，视觉已经很好
- **约束求解布局**：`computeColumns` 的五区域布局 —— 这是架构决策
- **Keep-alive 面板**：关闭面板不销毁状态 —— 这是功能需求

## 执行策略

按优先级分三批执行：

**Batch 1（P0）**：边框轻量化 + 间距调整 —— 影响面大但改动小，主要是令牌值和小幅尺寸调整
**Batch 2（P1）**：Composer 现代化 + Tab Strip 轻量化 + 按钮尺寸 —— 需要改组件样式
**Batch 3（P2）**：Hero 增强 + 表面层次 + 微动效 —— 锦上添花，可酌情裁剪

每批执行后跑 `flutter analyze` + `flutter test` 确保无回归。

## 风险

- 调整 `borderL2` 等令牌值会影响所有消费点（97 处 `labelTertiary` 级别的扩散风险），但边框令牌消费点较少，风险可控
- Composer 圆角和阴影改动只影响 `composer.dart`，风险低
- Tab strip 改动只影响 `workbench_tab_bar.dart`，风险低
- 表面层次细化如果需要新增令牌，需要评估是否破坏 dsh 1:1 端口纪律
