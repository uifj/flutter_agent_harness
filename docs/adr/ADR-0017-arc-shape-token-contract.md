# ADR-0017: 形状令牌契约（圆角按嵌套深度、选中态与 hover 分离）

- **状态**: IN-PROGRESS @ `c2255c6`（S1+S2 已落并进门禁守卫；S3 文本缩放未动）
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 生产功能（UI 一致性）/ 可维护性
- **日期**: 2026-09-29
- **修复 commit**: `c2255c6`（S1 形状令牌 + S2 选中态；S3 待做）
- **来源**: `docs/ui-production-audit-2026-09.md` §2 条 2b、§4.2、§4.6；ZCode `DESIGN.md` 的 radius-by-nesting 律

## 背景（Evidence）

**圆角没有真值源，只有 87 个现场决定。** 实测：

```
grep -rn "BorderRadius.circular(" lib/ui lib/theme | grep -oE "circular\([0-9.]+\)" | sort | uniq -c | sort -rn
  24 circular(8)     17 circular(12)    3 circular(999)   2 circular(20)   1 circular(5)
  20 circular(6)     11 circular(4)     3 circular(10)    2 circular(14)   1 circular(22)
                                        1 circular(18)    1 circular(1)
```

**12 个不同数值、87 处硬编码，而 `lib/theme/` 里圆角令牌数量为 0**（`grep -n "radius|Radius" lib/theme/dsw_alias.dart` 无输出）。这不是"还没整理"，是**同一个语义在不同文件里长得不一样**：会话行 `sidebar.dart:727` 用 8，工作区状态条 `composer.dart:928` 用 6，代码块 `assistant_markdown.dart:106` 用 6 而 `:115` 用 12。用户报告条 4 的"缺乏容器化质感"与条 3 的"层级模糊"，机制上就是这一条：**没有一套可读的嵌套律，容器与控件看起来就不像同一套系统里的东西。**

**`DswAlias` 装不下它，这是设计而不是疏忽。** 别名层（`dsw_alias.dart:236` 的 `light` 与 `:331` 的 `dark`）**每个字段都要写两遍**，因为它是颜色、随明暗变。圆角与间距**不随明暗变**——把它们塞进 `DswAlias` 会造出两个必须永远相等的字段，那正是 ADR-0014 拒绝"两个必须相等的字段"的同一个理由。`dsw_static.dart` 已经立了非颜色令牌的先例（`abstract final class` + `static const`），形状令牌该走这条路。

**选中态与 hover 是同一个颜色，这是可证的可用性缺陷。** `sidebar.dart:731` `color: selected ? color.interactiveBgHover : null`，而 hover 用的也是 `interactiveBgHover`（`:560`、`:603`）。后果不是"不好看"，是**鼠标划过哪一行，哪一行就像当前会话**——用户无法在不点的情况下判断自己在哪。用户报告条 2 说的"无活跃状态指示"，实情是**有指示但和另一个状态同色**。

**ZCode 的律是可抄的，它的"选中"做法也是。** `DESIGN.md:285-334` 给的是 radius 随嵌套深度递减（外层 `xl` → 内层 `sm`）加一张控件对照表；`TaskListItem.tsx:550` 的选中态是**独立的 `bg-selected` token（= 10% neutral-950）而不是 hover 色加深**，hover 只改亮度不改身份。**注意不要抄错**：ZCode 选中态**没有**左侧强调条（评估文档 §3 与本仓库初稿都误记过一次，audit §4.2 已更正）。

**顺带欠账**：`grep -rn "textScaler|textScaleFactor|baseFontSize" lib/` = 0 命中，即 ADR-0005 登记"无文本缩放适配"那条仍然没做，ZCode 的解法是单一 `--ui-font-size: 14px` 派生 ±4/2/0/-1/-2/-4 标度且**绝不动 root font-size**（`styles.css:58,143-151`、`DESIGN.md:212`）。本 ADR 收下这条律但**把实施排在 S3**，因为它要动 `TextTheme` 与 `MediaQuery`，面比圆角大得多。

## 决策（Decision）

### S1 新建 `lib/theme/dsw_shape.dart`：非颜色形状令牌

`abstract final class DswShape`，与 `DswStatic` 同构（`static const`，无明暗分支）。三组：

```dart
/// 圆角 = 嵌套深度。外层容器最大，越往里越小，控件胶囊最小。
static const shell = 12.0;   // 窗口级容器：工作台面板、浮层、下拉菜单
static const card = 10.0;    // 卡片级：composer 容器、消息块、代码块
static const control = 8.0;  // 控件级：按钮、输入、会话行、chip
static const inner = 6.0;    // 控件内部：行内高亮、小徽标
static const inset = 4.0;    // 最内层：tab 角标、状态点容器
static const pill = 999.0;   // 完全圆头（胶囊）

/// 间距基 4px，只用这一串（ZCode DESIGN.md:265-273 的节奏）。
static const xs = 4.0;  static const sm = 8.0;  static const md = 12.0;
static const lg = 16.0; static const xl = 24.0;

/// 控件尺寸：同一行里的可点件必须同高，这是"对齐不精准"那条的真因。
static const rowSession = 36.0;   static const iconSm = 14.0;
static const controlMd = 28.0;    static const hitSlop = 4.0;  // 透明命中区
```

**取值规则**（写进文件头注释，因为这是唯一可能腐烂的部分）：`shell 12 / card 10 / control 8 / inner 6 / inset 4` 是**递减**的；任何一处圆角若与它所在容器的嵌套深度不符，就是 bug 而不是"新数值"。**不许再加第 13 个值**——要加就改这条律并回到本 ADR。

### S2 `bgSelected` 进 `DswAlias`（它是颜色，随明暗变）

四处一起改（ctor 参数、字段、`light`、`dark`）：light `Color.fromRGBO(38, 49, 72, 0.10)`（hover 是 0.06，选中要**明显更重**）、dark `Color.fromRGBO(255, 255, 255, 0.14)`（hover 0.08）。`sidebar.dart` 的选中分支从 `interactiveBgHover` 换成 `bgSelected`，hover 分支不动——**两个状态两个 token，这是本 ADR 的核心断言**。

### S3 文本缩放（排在后面，本 ADR 只立约不实施）

一个 base scalar → `TextTheme` 全量派生 + `MediaQuery.textScaler` 接住系统缩放。**不许**动 root font-size（ZCode 明写这条，理由是它会让整页比例失衡）。做完即闭环 ADR-0005 的"无文本缩放适配"。

### 明确不做

- **不把圆角塞进 `DswAlias`**（见背景段：会造出两个必须相等的字段）。
- **不做 87 处的机械替换以外的视觉改版**：本 ADR 只保证"同一个语义同一个值"，具体哪个容器该用哪一档在 P2/P3 批里逐屏定。
- **不抄 ZCode 的 `*:focus{outline:none!important}`**（`styles.css:120-124`）——它连自家 `DESIGN.md:504` 都违背，而本仓库有 `dsw_hover_tap_test.dart` 守着键盘/语义可达，退化它是倒退。

## 后果（Consequences）

- **正面**：圆角第一次有单一真值源；选中态与 hover 可分辨；"对齐不精准"有了可执行的定义（同行控件同高）；新页面照律取值而不再现场发明。
- **负面/风险**：87 处替换会**改变现有外观**（6→8、12→10 之类），属于有意的统一，不是回归——但必须有前后截图才算交代，否则无法区分"统一了"与"改坏了"。低 alpha 的选中底色会轻微改变文字对比度，需跑 `contrast_check`。
- **中性**：`DswShape` 是 `lib/theme/` 第一个非颜色令牌文件，`dsw_static.dart` 的"feature 代码不许直接用"这条规则对它**不适用**（它就是要给 feature 代码用）；这个区别要写在新文件头部，否则下一个人会照 static 的规矩绕开它。

## 验证（Verification）

- **守卫（本 ADR 的长期牙齿）**：`test/theme_token_test.dart` 新增一组，扫 `lib/ui/**` 里的 `BorderRadius.circular(<数字字面量>)`，**命中数必须为 0**。因为 87 处在本次一并转换，所以守卫可以做成绝对断言而不是 ADR-0011 那种 baseline ratchet。同时断言 `DswShape` 的递减律（`inset < inner < control < card < shell`）——律本身也要被测。
- `bgSelected` 与 `interactiveBgHover` **必须不相等**（一条断言钉住"两个状态两个 token"，防止以后有人"顺手合并"）。
- `dart tool/contrast_check.dart` 与 `test/theme_contrast_test.dart` 仍绿（ADR-0004 口径）。
- 门禁同口径：format / `--fatal-infos` analyze / `check_architecture` / `flutter test` 相对基线（当前 `+816 -2`）零新增失败。
- 真机前后截图：侧栏（选中 vs 悬停）、composer 容器、代码块三处。终端无 Screen Recording 权限时标"待人工走查"。

## 关联（Links）

- 依据: `docs/ui-production-audit-2026-09.md` §2 条 2b、§4.2（ZCode 选中态与 rail）、§4.6（radius-by-nesting 与 4px 节奏）
- 代码: `lib/theme/dsw_alias.dart:236,278,331,373` · `lib/theme/dsw_static.dart:1-22`（文件先例）· `lib/ui/sidebar/sidebar.dart:560,603,727,731` · `lib/ui/conversation/composer.dart:928` · `lib/ui/conversation/assistant_markdown.dart:106,115`
- 关联 ADR: ADR-0004（对比度豁免面，新底色要过它）· ADR-0005（欠的文本缩放，S3 收下）· ADR-0011（ratchet 先例；本 ADR 用绝对断言替代，因为存量一次清完）· ADR-0014（"两个必须相等的字段就是一种新的错法"，本 ADR 据此拒绝把形状塞进别名层）
