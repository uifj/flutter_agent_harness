# ADR-0017: 形状令牌契约（圆角按嵌套深度、选中态与 hover 分离）

- **状态**: IN-PROGRESS @ `c2255c6`（S1+S2 已落并进门禁守卫）+ `74ab800`/`88b9f54`（同日：守卫改成读参数起始 token、4 处漏网字面量收回、侧栏品牌行并线 + 产品名进 i18n）· S2b 输入卡三态边已落 @ `b9684f4` · **S3 文本缩放已落并带守卫 @ `3301165`/`5cbf566`/`bab3a0f`**，余该节末「没闭的口」两格：非 AppFrame 那几十处紧座位未测未改、真机四档走查待人工
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 生产功能（UI 一致性）/ 可维护性
- **日期**: 2026-09-29
- **修复 commit**: `c2255c6`（S1 形状令牌 + S2 选中态）· `74ab800`（侧栏品牌行并线与产品名）· `88b9f54`（守卫改读起始 token + 4 处漏网字面量）· `b9684f4`（S2b 输入卡三态边）· `3301165`（S3 缩放接线）· `5cbf566`（S3b 一行高的紧座位跟着步子长）· `bab3a0f`（1.8x 双向守卫）
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

**顺带欠账**：登记时 `grep -rn "textScaler|textScaleFactor|baseFontSize" lib/` = 0 命中，即 ADR-0005 登记"无文本缩放适配"那条仍然没做，ZCode 的解法是单一 `--ui-font-size: 14px` 派生 ±4/2/0/-1/-2/-4 标度且**绝不动 root font-size**（`styles.css:58,143-151`、`DESIGN.md:212`）。本 ADR 收下这条律并把实施排在 S3——**现已落地**（见下文 S3 节），且选的通道比"`TextTheme` 派生"更小：只把用户那一档合成进 `MediaQuery.textScaler`，`DswType` 那套 ramp 一个数都没动。

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

### S2 `interactiveSelected` 进 `DswAlias`（它是颜色，随明暗变）

四处一起改（ctor 参数、字段、`light`、`dark`）：light `Color.fromRGBO(38, 49, 72, 0.10)`（hover 是 0.06，选中要**明显更重**）、dark `Color.fromRGBO(255, 255, 255, 0.12)`（hover 0.08。提案写的是 0.14，落地是 0.12：0.08 → 0.12 已经是可分辨的两档，没有证据要更重那一档）。`sidebar.dart` 的选中分支从 `interactiveBgHover` 换成 `interactiveSelected`，hover 分支不动——**两个状态两个 token，这是本 ADR 的核心断言**。

> **这条底色不在对比度门禁的覆盖面里**：`tool/contrast_check.dart` 的配对全是正文/状态色，`grep -n interactive tool/contrast_check.dart` = 0 命中，所以它既不救 hover 也不救 selected。钉住 selected 的是 `theme_token_test.dart` 里"selected 的 alpha 必须严格落在 hover 与 accent 之间"那条——它守的是**可分辨**，不是 AA。低 alpha 洗色叠加行文字的实际对比度仍是人眼/真机的活（登记表口径：`contrast_check` 之外的面按 ADR-0004 方案 B 处理）。

### S2b 同一条律用在**容器**上：输入卡三态边（本批 @ `b9684f4`）

S2 说的是"两个状态两个 token"，同一条律在输入卡上一直没人执行：`composer.dart` 的卡片只有一枚**静态** `borderL2DarkmodeThin`（6% 黑），于是屏幕上没有任何东西说明"键盘在谁那里"——审计条 4 的"缺乏容器化质感、边界不清"量的就是这件事，而不是圆角或阴影。ZCode 的对应物是一条三态律（`ChatPromptEditor.tsx:347`：`border-input-border` → `hover:border-input-border-hover` → `focus-within:border-input-border-focused`），其**实测**档位是 静置 10% → hover 20%（正好 2×）→ focus 换色相（`styles.css:176-177,196-198`）。

落地按本仓库自己的标度取同一条形状：静置 `borderL2DarkmodeThin`（0.06）→ hover `borderL3`（0.12，正好 2×）→ focus-within `brandPrimary`，`AnimatedContainer` + `DswMotion.fast`（100ms，动效令牌里写明这一档就是 hover/press 反馈）且经 `DswMotion.respecting` 尊重 reduced-motion；焦点优先于 hover，因为"正在打字"才是用户需要知道的状态。

两条刻意的不做：**不换 ZCode 的 `bg-input-focused`**——那要新增一枚底色令牌 × 两个主题，而让这块边界说话的是边不是底；**不新增令牌**——三档全部复用别名层已有字段，这正是 S2 想要的结果（状态可分辨，靠选档位而不是造档位）。

守卫 `test/composer_test.dart` 的 `the card shows which surface has the keyboard`：autofocus → `Tab` 走开 → 指针进 → 指针出 → 点回字段，五段都读**画出来的** `BoxDecoration.border`（不是 widget 参数），末尾再断言三枚 token 互不相等——与 S2 的 `selected ≠ hover` 同形。反向验过：把三态换回一枚静置边即红（`Expected: brandPrimary … Actual: 0.06 black`）。

### S3 文本缩放：把系统的步子接进来，并让一行高的容器跟着长（本批落地）

接线之前的事实：字号偏好**两处都能改、能落盘**（`ui/settings/model_settings.dart:167,431,1098` 的全屏设置、`ui/settings/widgets/settings_quick_menu.dart:232-233` 的快捷菜单），`AppSettings.fontSize` 也照旧序列化，但**渲染端没有一个人读它**——`grep -rn "textScaler" lib/` 在改动前是 0 命中。这正是 ADR-0005 登记"仅持久化未接线"的三项里的字号一项，也是 design-audit A4（登记表"无文本缩放适配"）那一行。

落地只做一件事，而且是乘法不是替换：`AppFontSize.scale`（small 0.9 / **medium 1.0** / large 1.15）乘在 `MediaQuery.textScalerOf(context).scale(1)` 上，在 `MaterialApp.builder` 的 `MediaQuery` 里合成，位置在 Navigator 之上，所以对话框与设置页同标。选 medium == 1.0 是这条的锚：**默认档必须什么都不改**，否则一个说不清来源的全局缩放会先出现在截图里、再由人猜。

**不动 root font-size、不动 `TextTheme`**——ZCode 明写这条律（`styles.css:58,143-151`、`DESIGN.md:212`），本仓库的理由更具体：框架的 `textScaler` 已经乘进每一个 `Text`，`DswType` 保持它是纯 ramp 的原样。再造一条 base scalar 就会出现两处真值（ADR-0014 那条"两个必须相等的字段就是一种新的错法"）。

**S3b 才是这条的牙齿**：把系统的步子接上，立刻把原来"没人缩放所以没人撞"的容器钉高变成实测裁字。同一条守卫量出来的 7 处（1.8x，macOS 辅助功能第二大档）：

| 座位 | 需要的行高 | 给到的 | 裁的是什么 |
| --- | --- | --- | --- |
| `disclosure_row.dart` 表头 | 43.0 | 24.0 | 工具卡标题 `Read`，以及同一行里的路径摘要（它在表头自己的 `ClipRect` 后面） |
| `chat_view.dart` 进行中行 | 40.0 | 26.0 | "Deep diving…" |
| `sidebar.dart` New Session | 40.0 | 34.0 | 36 的框减去内衬后剩 34 |
| `composer.dart` 模式 chip | 25.0 | 22.0 | 11/14 的"每次询问"标签 |
| `capsule_button.dart` md/sm | 40.0 / 32.0 | 36.0 / 28.0 | 审批三键、队列 chip 两处 |

律：**一行高的 chrome，它的高度取自文字那一步，不是钉死的像素**——`height: 36 * MediaQuery.textScalerOf(context).scale(1)`。设计档（1.0）下每个座位仍然是原来那个数，`disclosure_row_test.dart` 钉的 24 就是这条"零漂移"的证明。胶囊那里还多一层：shad 的 `height:` 同时写进 `ConstrainedBox` 的 min **和** max（`shadcn_ui-0.56.3/lib/src/components/button.dart:1130-1143`），所以它不是"最小高度"而是"钉"，缩放必须乘在这个参数上。

**先试过的 `minHeight` 地板是错的，这条要记住**：把表头改成 `ConstrainedBox(minHeight: 24)` 后 `disclosure_row_test.dart` 立刻红——`collapsed` 槽位装的是**外部传进来的任意 widget**，一旦给它不设上限的行，那句 `Text('2 files changed')` 折成四行、把整行撑到 88px。这些座位的"就一行"本来就是语义（多行的摘要要裁剪，不是把行撑高），所以正确的形状是**跟着文字缩放的紧高度**，而不是地板。横向同理但相反：侧栏 New Session 的标签改 `Flexible`（截断才是想要的），审批三键改 `Wrap`（换行才是想要的）——量的都是同一件事，处置方向由"这个控件的内容能不能多占一格"决定。

守卫两条，一条测几何一条测值：
- `test/app_frame_test.dart` 的 `nothing spills when the system amplifies text`：把整副外壳在 1.8x 下摆五个阶段（hero／长标题会话／进行中的工具卡／三键审批面板／排队草稿），每个阶段查**两个方向**——横向把 `RenderFlex` 的子宽求和 vs `constraints.maxWidth`（溢出的 flex 自己被约束裁成等宽，所以只能加子节点），纵向用 `RenderParagraph.getMaxIntrinsicHeight(width)` vs 它拿到的 box 高度（被裁不报错，只能这么量）。反向验证：把表头与胶囊换回钉高即红，并指名 `"Read" 43.0 vs 24.0`。
- `test/settings_test.dart` 的 `the text-size steps compose onto the platform scaler`：`medium == 1.0`、三档互不相等、默认文档落在 medium。

**没闭的口（诚实）**：这条守卫只覆盖 `AppFrame` 这一棵树。`grep -rhoE "height: (2[0-9]|[3-9][0-9]|1[0-9][0-9])," lib/ui | wc -l` 现在仍是 **73 处** ≥20px 的紧座位（分布在 18 个文件；本批把它们其中 5 处接上了文字步子），工作台四棵树（文件树/编辑器/终端/git/diff）、全屏设置页、企划工作台那几十处放大文本下同样会裁，本批**既没测也没改**——把守卫挂到那些树上之前，它们只是"看起来没问题"。真机 macOS「放大文本」四档走查也仍待人工（本机无 Screen Recording 权限）。这两格按 ADR-0017 的口径留在登记表，不算这条已闭。


### 明确不做

- **不把圆角塞进 `DswAlias`**（见背景段：会造出两个必须相等的字段）。
- **不做 87 处的机械替换以外的视觉改版**：本 ADR 只保证"同一个语义同一个值"，具体哪个容器该用哪一档在 P2/P3 批里逐屏定。
- **不抄 ZCode 的 `*:focus{outline:none!important}`**（`styles.css:120-124`）——它连自家 `DESIGN.md:504` 都违背，而本仓库有 `dsw_hover_tap_test.dart` 守着键盘/语义可达，退化它是倒退。

## 后果（Consequences）

- **正面**：圆角第一次有单一真值源；选中态与 hover 可分辨；"对齐不精准"有了可执行的定义（同行控件同高）；新页面照律取值而不再现场发明。
- **负面/风险**：87 处替换会**改变现有外观**（6→8、12→10 之类），属于有意的统一，不是回归——但必须有前后截图才算交代，否则无法区分"统一了"与"改坏了"。低 alpha 的选中底色会轻微改变文字对比度，需跑 `contrast_check`。
- **中性**：`DswShape` 是 `lib/theme/` 第一个非颜色令牌文件，`dsw_static.dart` 的"feature 代码不许直接用"这条规则对它**不适用**（它就是要给 feature 代码用）；这个区别要写在新文件头部，否则下一个人会照 static 的规矩绕开它。

## 验证（Verification）

- **守卫（本 ADR 的长期牙齿）**：`test/theme_token_test.dart` 新增一组，扫 `lib/ui/**` 里每一处 `Radius.circular(`，要求括号之后的第一个非空 token **必须是 `DswShape.`**，命中数必须为 0。因为 87 处在本次一并转换，所以守卫可以做成绝对断言而不是 ADR-0011 那种 baseline ratchet。同时断言 `DswShape` 的递减律（`inset < inner < control < card < shell`）——律本身也要被测。
  > **首版守卫是漏的，这条要记住**：它当时写的是 `Radius\.circular\([0-9]`——只认括号后紧跟数字。于是 `BorderRadius.circular(wide ? 12 : 999)`（侧栏 New Session 两处）与 `BorderRadius.circular(_dense ? 14 : 18)`（`capsule_button` 两处）**带着字面量从它眼皮底下过了 4 处**，"94 处清零"那句因此并不成立。改成"读参数起始 token"后，反向验证是做回去：把 `wide ? 12 : 999` 塞回侧栏，守卫立刻红并指名行号。**只认数字形状的正则，等于给"三元里的数字"开了后门**——这一条对任何 `grep` 式门禁都适用。
- `interactiveSelected` 与 `interactiveBgHover` **必须不相等**（一条断言钉住"两个状态两个 token"，防止以后有人"顺手合并"）。S2b 同形：`composer_test.dart` 的 `the card shows which surface has the keyboard` 走 autofocus／`Tab`／指针进出／点回字段五段，读的是**画出来的** `BoxDecoration.border`，末尾断言三枚 token 互不相等；反向验过是把三态换回一枚静置边，红。
- `dart tool/contrast_check.dart` 与 `test/theme_contrast_test.dart` 仍绿（ADR-0004 口径）：S2b 只动**边**不动正文色，`contrast_check` 的配对里本来就没有 `border*`，前后同为 9 对低于 4.5:1。
- 门禁同口径：format / `--fatal-infos` analyze / `check_architecture`（7 recorded, 0 new）/ `flutter test` 相对基线（本批 **`+836 -2`**，仍是登记的那两条既有失败）零新增失败。`dart tool/contrast_check.dart` 与 `test/theme_contrast_test.dart` 不受影响（9 对低于 4.5:1 全是 ADR-0004 方案 B 的 light 旧账，DARK 无回归）——本批一个颜色都没动。
- 真机前后截图：侧栏（选中 vs 悬停）、composer 容器、代码块三处。终端无 Screen Recording 权限时标"待人工走查"。**S2b 之后这一条对 composer 只剩"好不好看"**：状态律本身已经可测并且已测，它不再依赖眼睛。

## 关联（Links）

- 依据: `docs/ui-production-audit-2026-09.md` §2 条 2b、§4.2（ZCode 选中态与 rail）、§4.6（radius-by-nesting 与 4px 节奏）
- 代码: S3 的接线点 `lib/main.dart:181-197` · `lib/model/app_settings.dart`（`AppFontSize.scale`）· S3b 的六枚座位 `lib/ui/primitives/capsule_button.dart:82-87`、`lib/ui/primitives/disclosure_row.dart:70-105`、`lib/ui/sidebar/sidebar.dart:469-475`、`lib/ui/conversation/chat_view.dart:296-303`、`lib/ui/conversation/composer.dart:1650-1657`、`lib/ui/conversation/approval_panel.dart:212-240` · 原有：`lib/theme/dsw_alias.dart:236,278,331,373` · `lib/theme/dsw_static.dart:1-22`（文件先例）· `lib/ui/sidebar/sidebar.dart:560,603,727,731` · `lib/ui/conversation/composer.dart:928` · `lib/ui/conversation/assistant_markdown.dart:106,115`
- 关联 ADR: ADR-0004（对比度豁免面，新底色要过它）· ADR-0005（欠的文本缩放，S3 收下）· ADR-0011（ratchet 先例；本 ADR 用绝对断言替代，因为存量一次清完）· ADR-0014（"两个必须相等的字段就是一种新的错法"，本 ADR 据此拒绝把形状塞进别名层）
