# ADR-0038: 输入框聚焦不改变边框颜色

- 分类: ARC
- 优先级: P2
- 状态: ACCEPTED（2026-10-01，用户走查拍板）

## 背景

UI 审计条 4 曾把 composer 输入卡记为"边界不清"（仅一枚 6% 静态描边），
b9684f4 据此给输入卡立了三态边框：静置 `borderL2DarkmodeThin`（6%）、
hover `borderL3`（2×）、**focus `brandPrimary`**（对齐 ZCode
`ChatPromptEditor.tsx:347` 的 `focus-within:`），并由
`composer_test.dart` 的 "the card shows which surface has the keyboard"
守卫钉住；桥的 `inputTheme` 随后给了 ShadInput 同一对步骤
（静置 `borderL2`、聚焦 `brandPrimary`，ADR-0017 S2b）。

2026-10-01 真机走查（第二窗截图）：用户判定**聚焦后边框变色是噪音**——
光标已经在说"键盘在这里"，边框再变深色（暗色主题下 brandPrimary 呈现为
一道黑边）没有信息量，反而打扰；要求"输入时边框还是原本的"。

## 决策

1. **composer 输入卡**：三态改两态——静置 `borderL2DarkmodeThin`、
   hover `borderL3`；**聚焦不再改变描边颜色**（聚焦时 hover 态也随指针
   位置自然表现，键盘状态不单独表达）。
2. **桥的 `inputTheme`**：`focusedBorder` 与 `border` 同为
   `borderL2` 一档——所有 ShadInput 聚焦时边框保持原样。
3. `dswBareInput`（无边框字段）不变——聚焦同样不出现边框。
4. 守卫 `composer_test.dart` 改写为反向验证：**聚焦态与静置态描边逐像素
   相同**；hover 仍亮一档（指针反馈保留）。

## 后果

- 推翻 b9684f4 与 ADR-0017 S2b 中"focus 落 brandPrimary"的一半决策；
  "interactiveSelected 与 hover 不同色"的律**不受影响**（那是选中态，
  非键盘焦点态）。
- 全仓聚焦视觉 = 光标 + 光标色（`stateBusinessPrimary`），无边框变化。
- 若未来需要键盘焦点指示（无障碍审计要求时），应回到
  `brandPrimary` 但作为 2px ring 而非替换描边——重新立 ADR。

## 证据

- 走查截图 2026-10-01（composer 聚焦，深色描边）。
- 旧实现：`composer.dart` `_card` 三态、`dsw_shad_bridge.dart`
  `inputTheme.decoration.focusedBorder`。
