# ADR-0034: 用户气泡是气泡，不是头像（`pill` 会随文字变短而变圆）

- **状态**: ACCEPTED
- **分类**: DEBT
- **优先级**: P2
- **影响维度**: 观感 / 认知障碍
- **日期**: 2026-09-30
- **来源**: [ui-consistency-audit-2026-09-30.md](../ui-consistency-audit-2026-09-30.md) §U4（真机窗口截图 `86e0bd57` 右上角）；§U3 在同一次复核里被**撤回**（见 §明确不做）
- **修复 commit**: `daa22fc`（气泡形状 + 发丝，`chat_view_test` 的认法随之改）· `7d87f73`（守卫 `test/user_bubble_test.dart`，三条，先红 `+1 -2`）

## 背景（Context）

截图里会话的第一条用户消息只有三个字符 `h'i`，渲染成**一枚淡蓝圆形**，贴在右上角两个面板开关下面，视觉上像头像，不像"人刚说的话"。

代码：`lib/ui/conversation/message_item.dart` 的 `_UserBubble`（修后 `:64-76`）原本要的是 `BorderRadius.circular(DswShape.pill)`（999），而 **Flutter 把半径夹到盒子的一半**（`BorderRadius` 文档与 `RRect` 的构造行为）——于是盒子越短，圆角占比越大，三个字符时四角相接成为圆盘。阶梯对 `pill` 的判词是：

```
dsw_shape.dart:27-29
pill  999 完全圆。也是点和头像的正确答案 —— Flutter 会把半径夹到盒子的一半，
           所以 2px 的点与 44px 的头像都无需专数就正好是圆的。
```

同一枚令牌在头像上是律，在气泡上就成了事故：**这条注释说的"无需专数"依赖的是盒子接近正方**，而消息气泡的宽是内容决定的。

参考实现给了另一答（`_archive_project/ZCode-main/packages/ui/src/v4/ConversationRowView.tsx:1253-1258`）：

```
rounded-xl rounded-tr-xs border border-border bg-surface px-4 py-3 text-ui-base
```

即 **12px 圆角 + 右上角近乎直角 + 发丝边框**：那个方向性的小圆角让气泡"指向消息来的那条边"，短消息也仍是一枚圆角矩形。对应本仓库阶梯：`shell 12` 与 `inset 4`，发丝用 `borderL2`（与 `settings_quick_menu.dart:141-147` 的浮层同一档位）。

## 决策（Decision）

1. **气泡圆角改由阶梯回答**：`BorderRadius.only(topLeft: shell, topRight: inset, bottomRight: shell, bottomLeft: shell)`。方向性右上角照 ZCode 的 `rounded-tr-xs`。
2. **加 `Border.all(color.borderL2)` 发丝**：本应用每一层表面都自己声明边界（popover、菜单、卡片），只有用户气泡是纯底色浮在纯白页面上。
3. **不加最小宽度**（原本 §U4 预备的第二个数字）：把半径封顶之后，圆盘的成因就消失了——探针在 320px 列里量到 `h'i` 的盒子是 **83.7 × 44.0**（宽由内容决定，高由 `py` 加一行 16/22 的字决定；改形之前那枚 `pill` 被夹成 22 = 半个高度，四角相接所以是圆；改形之后同一只盒子读到的是 `12 / 4 / 12 / 12` 的圆角矩形，宽高一字未动）。**少一个数字就是少一处真值**（ponytail），且最小宽度会反过来把长消息的观感带偏。
4. **字号一字不动**：气泡内仍是 `DswType.base16`（与本应用正文同档）。ZCode 全站 14px，本应用正文是 16px——那是 ADR-0017 移植的 Figma 阶梯，不是分叉；改字号会牵动十七面两档的放大文本守卫，属另一件事。
5. **明确不做 / 撤回**：
   - **§U3（"对话列底部三条信息各用一条轴"）撤回**。复核代码后：`_statsLine()` 居中在内容轴上（`conversation_root.dart:330-335` 的注释写明是 dsh 的 StatsLine，且座位常驻以免卡片跳动），工作区状态条是 `Row` 撑满同一列 ⇒ 它的左沿就是卡片的左沿（`composer.dart:963-977`）。**两者同轴，只是一个居中一个左对齐**，而这是内容语义（会话计数 vs 可点击的工作区入口）。审计里那句"三段轴"是把"两种对齐"误当成"三条轴"，与 §3-C 那次撤回同一处理方式：先问这块本来该不该居中，再立缺陷。
   - 不动气泡底色（`color.bubble` 是 Figma 移植的"用户旁白"色，ADR-0004 的对比度面已覆盖）。
   - 不做"仅右下角小圆角"之类的多角变体（ZCode 只有一个方向性角，照抄一个就够）。

## 后果（Consequences）

- **正面**：短消息不再退化成圆；用户气泡与 popover／菜单／卡片共用同一档圆角与同一条发丝，"同一层表面"看起来终于是一层；`pill` 回到它被定义的职责（点与头像）。
- **负面/风险**：**可见改动**，每条用户消息的外观都变（圆角、右上角方向性的一角、多一条发丝；盒子尺寸不变，因为 `DecoratedBox` 的边框画在盒子内部而不是把它撑大——探针量到的 83.7 × 44.0 在改前改后是同一只盒子）。需要真机走查。既有守卫里 `chat_view_test.dart` 的"两条轴"那条**用 `pill` 认气泡**，已把认法改成用气泡底色认（它断言的轴关系一字未改）——记在这里，因为"改测试"必须说清改的是认法还是断言。
- **中性**：`DswShape.pill` 仍有其它读者（点、头像、`CapsuleButton` 一类），不会变成死令牌（ADR-0025 的读者守卫会盯着）。

## 验证（Verification）

- **先红**：`test/user_bubble_test.dart` 在未改的树上 `+1 -2`——`Expected: BorderRadius.only(12, 4, 12, 12)  Actual: BorderRadius.circular(999.0)`、`Expected: not null  Actual: <null>`（边框）；第三条"字号未动"在未修树上就绿，作无回归对照。
- **后绿**：3/3；`chat_view_test.dart` 13 条全绿（含那条轴断言）；全量套件见登记表行，两条既有失败未变多。
- 门禁四条同口径（本次实跑：format `213 files (0 changed)` / analyze `No issues found!` / `flutter test` `+944 -2`（仅两条既有失败，未变多）/ `check_architecture` `7 recorded, 0 new (7 rules)`）。
- macOS debug 重建并重启（旧 PID 66313 → 新 PID 69068）；**这条必须真机看**：短消息气泡、长消息气泡、以及亮暗两档下发丝是否过强。

## 关联（Links）

- 代码: `lib/ui/conversation/message_item.dart`（`_UserBubble`）
- 令牌: `lib/theme/dsw_shape.dart:21-29`（`shell` / `inset` / `pill` 各自的职责）
- 守卫: `test/user_bubble_test.dart` · `test/chat_view_test.dart`（认法改为按气泡底色）
- 关联 ADR: ADR-0017（阶梯与"selected≠hover"）· ADR-0025（令牌要有读者）· ADR-0028/0029（同一族"一层表面一层皮"）· ADR-0004（对比度豁免面）
