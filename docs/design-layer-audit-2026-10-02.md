# 设计层走查 2026-10-02（design-layer-audit）

> **一句话**：令牌层那五条已经收口的轴（颜色、圆角、字形、时序、菜单皮）本次实测**确实干净**，剩下的设计债集中在**三轴没有档位**（字号档位自述、间距节奏、描边宽度）、**两处判分器不一致**（AA 工具 vs AA 测试，且企划的标记色从没进过枚举），以及**企划 library 那几面各自重画同一行与同一个空态**。
>
> **方法**：`design-review` 插件 `design-debt-review` 的人工分支。插件自带的 `audit-design-debt.mjs` 走 Tailwind/CSS/arbitrary-value 路线，本仓库没有 CSS、没有 `design.qa.yaml`，**自动化覆盖率为 0**；下文每个数都是现跑命令的量法（命令都写在条目里，可复跑）。
> **基线**：`develop` @ `8058016`（量法过程中并发会话推进了三枚：`f93e7ed`/`3782f2c`/`542d233`），本机 macOS(Darwin arm64)、Flutter 3.41.9 / Dart 3.11.5。
> **口径**：与登记表一致，只对"相对基线零新增失败"负责；本次五把主题守卫跑绿 = `+47`。
> **分工**：[design-audit-2026-09.md](design-audit-2026-09.md) 量的是**令牌缺席与键盘可达**（A1/A2/A3/A4/C1），那些已由 ADR-0017…0027 收口；本篇量的是**收口之后还剩下什么**。两篇不重叠，别把本篇当成前一篇的重复。

---

## 1. 已经收口的五条轴（实测，附复跑命令）

| 轴 | 档位实况 | 实测结论 |
| --- | --- | --- |
| 颜色 | `DswAlias` 声明 **89** 枚别名（`lib/theme/dsw_alias.dart:120-239`），light `:242-335` 与 dark `:338-430` 键集等长；底版 `DswStatic` 74 枚 | **89 枚全部有 `lib/ui` 表面在读，死令牌 0**（逐名 `grep -rlE "\.<名>\b" lib/ui`） |
| 圆角 | `DswShape:38-44` 七档 16/12/10/8/6/4/999 | `lib/ui` 里数字字面量 `Radius.circular(` = **0**（131 处全读档位） |
| 字形 | `DswShape:82-102` 五档 10/12/14/16/18 | `lib/ui` 里 `size:`/`iconSize:` 的数字只剩 **≥20**（20/24/28/32/34/40），即盒子与装饰图形——ADR-0026 明确它们不入阶 |
| 时序 | `DswMotion:17-32` 四档 100/200/300/500ms + 一枚 Cubic | `lib/ui` 里 `waitDuration` = **0**；8 处 `Duration(milliseconds:)` 全在 6 个文件里（`sidebar.dart:47`、`plan_block_editor.dart:425,460,490`、`row_sweep.dart:29`、`copy_button.dart:24`、`chat_view.dart:264`、`conversation_root.dart:198`），且守卫只扫 `Animated*(` 的开句（见 §3-D4 的口径注） |
| 组件库 | shad 采纳 B6–B9 已落（`docs/shad-adoption-2026-09-30.md:77,79,81,95`） | 四条"已归零"声明**逐条复跑为 0**：裸 `TextField(`、`InputDecoration`、`PopupMenuButton`/`showMenu(`、`waitDuration` |

守卫实况：`flutter test test/theme_token_test.dart test/theme_contrast_test.dart test/shad_radius_test.dart test/tooltip_timing_test.dart test/menu_chrome_test.dart` → **`+47: All tests passed!`**。`test/amplified_text_probe.dart` 确认挂在 **21** 个测试宿主上。

**判词（值得记下来的一条）**：规则文档里写"归零"的四条，本次是真零。这条结论的价值不在于"没问题"，而在于**它把注意力准确地推到了没人守的那三条轴上**（§3）。

---

## 2. 本次量法纠正两条（先记账，别当成事实引用）

第一轮扫描（委托的检索代理）交回两个数，都**不成立**，且失败原因不同——两者都是"结构守卫的扫描面与它声称的判据不同轴"，正是本仓库反复付学费的那一类：

1. **"89 枚里 31 枚无人读"→ 实测 0**。错因：按"在 `lib/` 里是否有读者"数，而 `dsw_theme.dart` 把 89 枚全部绑进 `ThemeData`，绑定点本身就是读者；那个口径下永远数不出"没人画"。**判词：颜色令牌的'有没有读者'要问 `lib/ui`，不能问 `lib/`。** 顺带说清：`theme_token_test.dart:374-404` 的"每枚令牌都要有读者"只管 `DswShape` 的 `static const`，**别名层没有等价守卫**——今天恰好不需要（实测 0 枚死色），但它是一次"律写在 ADR-0025、覆盖面只在形状层"的落差。
2. **"148 处裸描边宽度"→ 实测 10**。错因：直方图用的是 `width: <数字>`，把 `SizedBox(width:)`/`Container(width:)` 的布局宽一起算了。**判词：量一个属性要按它的承载点收口（`BorderSide(` 而不是 `width:`），否则一条布局宽就伪装成一条描边。**

---

## 3. 发现（D1–D8）

### D1 [DEBT P2] 字号阶梯里唯一那枚说谎的名字，而守卫看不见档位定义本身
- **证据**：`lib/theme/dsw_typography.dart:90` `static final m18 = _ui(16, 28, FontWeight.w500)`（名字说 18、渲染 16）；它被绑进 Material 当 `titleLarge`（`lib/theme/dsw_theme.dart:160`）。阶梯其余 15 枚 UI 档名实相符（`:85-110`）。
- **为什么漏**：ADR-0027 的守卫只扫 `DswType.<名>.copyWith(fontSize:` 之后六行（`test/theme_token_test.dart:329-330`），**档位定义本身不在扫描面内**。所以"名字不许对字号撒谎"这条律对阶梯的**声明**是空转的。
- **风险**：任何读 `titleLarge` 的框架件拿到的是 16 而名字说 18；下一个想"补齐 18"的人写一次 `copyWith`，就是同一档两处真值——ADR-0027 立律要拦的正是这个形状。
- **备选**：① 改名为它实际的数（像素不变）；② 并入既有档（`baseStrong16 = _ui(16, 24, w500)`，**沟高 24 与 28 不同，不是同一档**，故不成立）。→ 采 ①。
- **建议修法**：改名 + 把守卫从"调用点"扩到"档位自述"（解析 `_ui(` 的第一个实参与该档名里的数字，不等即红）。改完守卫在**未修的树上必红**，即反向验过。
- **验证**：`flutter test test/theme_token_test.dart`；像素不变故**不需要真机走查**（同 ADR-0027 的判据）。
- **建议编号**：取号以 `ls docs/adr/` 现场为准。

### D2 [DEF P2] AA 门禁有两个判分器、差 0.004，且企划的标记色从没进过枚举
- **证据（判分器分叉）**：`dart tool/contrast_check.dart` 末行打印 **`9 pair(s) below 4.5:1`**；`test/theme_contrast_test.dart:74-82` 的豁免表是 **8** 条。分歧点是 `light stateErrorPrimary/bgBase = 4.4996`——工具按原始比较（`tool/contrast_check.dart:123-124`）算 FAIL，测试按百分位取整（`:109-110`）算 PASS，并把同一行打印成 `4.50:1 LARGE-ONLY`。
- **证据（枚举缺口）**：工具评的是**硬编码的 13 对**（`tool/contrast_check.dart:101`，2026-09 审计命名的配对）。而企划的 11 档文字色 `planLadderColor`（定义 `lib/ui/plan/dataview/plan_cell_value.dart:187`，读者 `:180` 与 `lib/ui/plan/blocks/plan_block_view.dart:842,976,985,1210`）+ 链接色（`plan_block_view.dart:970-973`，`brandPrimary` + 下划线）都是**这之后新长出来的"文字压在某层底上"**，从没进过那 13 对；`grep ladder test/theme_contrast_test.dart test/plan_blocks_test.dart` = **0**。
- **风险**：ADR-0004 采纳的是"方案 B 显式豁免"，整个决策的可信度就挂在那个数字与那张豁免表上；两个判分器给出不同的数，豁免表就无法自证诚实（同文件 `allowlist stays honest` 那条守的是集合方向，不是与工具一致）。标记色低于 AA 不会红任何东西——走查单 `docs/walkthrough-plan-editor-2026-10-02.md` 的 A2 自己就把它列成纯人眼格。
- **建议修法**：① 工具与测试共用一个比较函数（一处取整口径）；② 把 11 档标记色 × 亮暗两档 × 块底、以及链接色，按对枚举进 `pairs`。**先说好：这一步大概率当场报出新FAIL，那是要的产出，不是回归**；加豁免行按 ADR-0004 的口径显式登记。
- **验证**：两条命令报同一个数；`git diff` 只应动 `tool/contrast_check.dart` 与测试的枚举/取整处。
- **建议编号**：取号以 `ls docs/adr/` 现场为准（分类 DEF·优先级建议 P1，因为它是 ADR-0004 决策面的完整性，而不是又一处观感）。

### D3 [DEBT P2] 企划 library 四面各自重画同一行，空态有六种画法
- **证据（行）**：`lib/ui/plan/library/plan_all_content_screen.dart:313`、`plan_bin_screen.dart:152`、`plan_date_screen.dart:155` 三处各写一份 `DswShape.rowSession * textScaler` + 同一套 padding/hover/半径/图标+名+尾部；`plan_templates_screen.dart:179` 又换成带描边的卡片行。
- **证据（空态）**：`dataview/plan_viewers.dart:367,380`（`_EmptyRow`）、`:565-571`（内联 `planNoRecords`）、`plan_date_screen.dart:126`（`planDateNoObjects`）、`plan_widgets_screen.dart:60`、`plan_object_info_screen.dart:47` — 同一角色 6 份。
- **对照（这里做得对的地方，别一起改掉）**：五档投影**有**共享词汇——`planRowSeat()`（`dataview/plan_viewers.dart:34`）被 Table/List/Gallery（`:138`、`:416`）、看板分组头（`plan_board_viewer.dart:201`）、视图条（`plan_viewer_bar.dart:63,117`）共读。散的就散在 library 那几面。
- **风险**：ADR-0017 S3 的座位律（高度必须乘字号步子）在此有四份必须相等的实现；探针按面挂，面与面之间没有"同一行"的守卫，所以一处改座位另三处静默腐烂。
- **建议修法**：抽一枚共享的"记录行"件（先例：`lib/ui/primitives/disclosure_row.dart` 是"共享行"的既有形态），与一枚带 `messageKey` 的空态件。**这是本篇最大的一片**，按 §5 排在最后。
- **验证**：`flutter test test/plan_all_content_test.dart test/plan_date_gallery_test.dart test/plan_object_info_test.dart` + `amplified_text_probe` 两档各挂一次。
- **建议编号**：取号以 `ls docs/adr/` 现场为准。

### D4 [DEBT P2] 间距有档位、没有守卫：`lib/ui` 实测 101 处离阶（**登记不修，但要写清判据**）
- **证据**：`DswShape:54-64` 给了 4/8/12/16/24 五档，`theme_token_test.dart` 只查"档位有没有读者"（`:374-404`），从不看 `EdgeInsets` 的实参。实测（`grep -rhoE "(all|horizontal|vertical|left|right|top|bottom): [0-9]+" lib/ui`）：在阶 4×30 / 8×42 / 12×34 / 16×23 / 24×5，**离阶合计 101**（10 用 23 次、14 用 20 次、6 用 14 次、2 用 11 次、5 用 9 次、3 用 7 次、9 用 6 次、20×2、32×3、22×1、100×1）。
- **判词（为什么不建议批量上阶）**：其中相当一部分是**光学微调**而不是错——14 常用来贴着 12/16 做视觉对齐，2/3 常做描边补偿。本仓库在圆角那条守卫上已经记过同族教训："只认数字的正则拦不住 `wide ? 12 : 999`"（ADR-0017 追记）。一条会一次红 101 条的守卫不会提高质量，只会逼人把数字塞进 `// ignore`。
- **建议处置**：① 在 `dsw_shape.dart` 头部写清这五档管的是**块与块之间**、不管描边补偿与光学微调；② 只挑 3 个**新写或刚改过**的面把明显的 `10`/`14` 上阶；③ 不建守卫。若日后要建，口径必须是"按文件的增量"，不是全仓计数。
- **验证**：`grep` 复跑，离阶数下降即可，不要求为 0。
- **建议编号**：取号以 `ls docs/adr/` 现场为准（也可以只留观察行、不立 ADR——如果按①③处置，就没有需要批准的方案）。

### D5 [DEBT P2] 描边宽度没有档位，10 处数字实参里有一枚半像素
- **证据**：`DswShape` 有半径/间距/行高/字形四把档位，**没有宽度档**。全 `lib/ui` 的 `BorderSide(` 共 35 处，其中数字宽度 **10 处**：`1`×3（发丝）、`2`×3（拖拽落点线 `plan/blocks/plan_block_drag.dart:169`，块范围线 `plan_block_view.dart:628,1084`）、`3`×1（左侧强调条 `settings/model_settings.dart:1849`）、**`0.5`×1**（`plan/library/plan_widgets_screen.dart:347`）。
- **风险**：`2` 那三处语义相同（"一条落点/范围线"）却分散两文件；`0.5` 在 1x DPR 上会被合成器吃掉，属于"我这台好使"的值。
- **建议修法**（懒惰优先）：**先只把 `0.5` 收到 1**，并给 `plan_block_drag.dart:169` 加一句"这条线与 `plan_block_view` 的两条是同一件事"的头注。**开一档 `hairline`/`accent` 是 ADR-0017 的门槛**（"加一档要改 ADR-0017"），10 处的量不值得为一个数字档开一档——真要开，就把它并进 D4 的"间距与描边口径"那一篇一起说。
- **验证**：`grep -rnE "BorderSide\(" lib/ui | grep "width: 0.5"` 为空。
- **建议编号**：可与 D4 并号（同为"没有档位的轴"），或独立一篇——取号以 `ls docs/adr/` 现场为准。

### D6 [DEBT P2] Calendar 那一面不在共享词汇上，且**这个例外没有登记**
- **证据**：`dataview/plan_calendar_viewer.dart:196,197,207,224,247` 用裸像素画日期格（`EdgeInsets.all(1)`、`all(2)`、`left: 2, top: 1`、`width: 2`），而其余四档投影走 `planRowSeat()`。
- **为什么这是"未登记"而不是"漂移"**：日期格是宿主用 `MonthView.cellBuilder` 替 `packages/board_panel` 画的（AGENTS.md §2 与 `21dc359` 的理由仍然成立——被 lint/format 排除的入库包不动，修在宿主侧，见 `.qoder/rules/build.md` §0）。格子内边距那件东西**包里根本没有**，所以宿主必须自己给数。缺的只是那句话。
- **建议修法**：在 `plan_calendar_viewer.dart` 头部补一句为什么它不走 `planRowSeat()`。**一行注释，不占 ADR 号。**
- **判词**：**"看起来像漂移"的东西，如果它有正当成因，就必须把成因写在那个文件里**——否则下一个读者只能把它当成待修项（ADR-0022 那条"自我辩解的注释仍是一枚假开关"的反面：这次注释根本没有）。

### D7 [TST P2] `packages/**` 落在所有门禁之外：`plan_editor` 的格式与分析没人跑
- **证据**：根 `analysis_options.yaml:8` 排除 `packages/**`；CI（`.github/workflows/pr-check.yml`）的 format/analyze 范围是 `lib test tool spike`（`.qoder/rules/build.md` §1 明确"不是 `.`"）。`packages/plan_editor/analysis_options.yaml` 与根**同基线**（`include: package:flutter_lints/flutter.yaml`），但没有任何一条命令会去包目录里跑它。
- **同时把一条好消息记清（免得下一个读者重查）**：`packages/plan_editor` **不是第二套设计系统**——包内 `lib/` 共 434 行、**0 枚 Widget**、读 `dsw_*` 0 处、`Color(0x`/`Duration(milliseconds:`/`Radius.circular(`/`height:` 字面量各 0（唯一一枚 `fontSize:` 是测试夹具 `packages/plan_editor/test/plan_editor_controller_test.dart:280`）；样式答案由宿主经 `EditorStyleResolver` 注入（`lib/ui/plan/blocks/plan_block_view.dart:863-865,944-996`）；点击件/图标钮/菜单/对话框全用宿主原语（`plan_block_editor.dart` 里 `DswIconButton`×10、`DswHoverTap`×4、`DswContextMenu`、`ShadDialog`），包内手写命中区 0 枚。**这是 ADR-0044 决策段的意图，本次实测成立。**
- **风险**：包自己腐烂时不会有任何命令报警；`test/amplified_text_probe.dart` 没挂进包（宿主侧 `test/plan_blocks_test.dart:58`、`:718` 有两档步子的走查，但标记本身在两档下的裁剪没被证过）。
- **建议修法**：`build.md` §0 已经把"改它要在包目录内单独验证"写成规则，缺的是**一条可跑命令**。最小做法：把 `dart format --set-exit-if-changed packages/plan_editor && dart analyze --fatal-infos packages/plan_editor` 写进 §5 出包清单的"动过包就必跑"那一格（或加进 pr-check 的条件步骤——那是 CI 改动，按 §7 要 ADR）。
- **验证**：命令在包目录内跑通并返回 0。
- **建议编号**：取号以 `ls docs/adr/` 现场为准（分类 TST；若只做文档补一句则不立 ADR，只留观察行）。

### D8 [观察] 编辑面新增的观感格，机器量不到，别混进上面的账
- **证据**：`docs/walkthrough-plan-editor-2026-10-02.md` 要人签收 15 格（A1–A5、B1–B5、C1–C5、D1–D2），其中**设计层的**是：亮暗两档下 8 种标记与阶梯色的**和谐度**（A1）、11 档阶梯**对比度**（A2，本篇 D2 把它变成可量的）、bold-on-type 是否真所见即所得（A3）、composing 下划线（A4）、链接在 run 末尾不误拖（A5）、拆块闪动（B1）、跨块方向键落点（B3）、CJK 快捷键冲突（B4/B5）、2px 落点线的可辨识度（C1）、自动滚动顺不顺（C2）、嵌套缩进（C3）。本机无 Screen Recording 权限，**这些格只能由人填**（见项目记忆：这个应用能跑但截不到）。
- **判词**：D2 修完之后，A1/A2 里"低于 AA"的那一半会从纯人眼变成有门禁；剩下的**和谐度与手感**仍是人眼，别在文档里把它们写成"已由测试证明"。

---

## 4. 明确不动的（这些是决策，不是债）

| 项 | 为什么不动 | 出处 |
| --- | --- | --- |
| 11 枚主题不变色别名、亮色档低于 AA 的 8/9 对 | ADR-0004 采纳"方案 B 显式豁免"，是决策 | `docs/adr/ADR-0004-cfg-light-contrast-aa.md` |
| `terminal_tab`/`editor_tab`/Mermaid 三处按亮度手挑色（`:292-298`、`:434,470`、`assistant_markdown.dart:60-62`） | ANSI 与语法高亮主题本就不属于令牌层 | 本轮实测确认这三处是仅存的手挑点 |
| shad 保留清单：composer 卡（三态动画边）、投递药丸（`ShadBadge` 无 decoration 入口，`badge.dart:26-38`）、级联菜单、tab chip、不换 `ShadApp` 根 | ADR-0036 三档判定里"保留必带理由"，理由已写 | `docs/shad-adoption-2026-09-30.md` §4:122 |
| 24 种 embed 与 GRAPH 视图的"不支持"占位、嵌套筛选占位 | 按**上游答案**做占位，不是待修 bug | `docs/anytype-feature-inventory-2026-10-01.md` §17；`plan_viewers.dart:698-724`、`plan_block_view.dart:1424-1453` |
| `packages/board_panel` 的内部实现 | 入库包不受本仓库 lint/format 门禁 | `.qoder/rules/build.md` §0 |
| `CapsuleButton` 的删除（映射表 row 35"登记不强制"） | 未做且被明确判为不强制；文件仍在 `lib/ui/primitives/capsule_button.dart` | `docs/shad-adoption-2026-09-30.md` |

## 5. 处置顺序（成本升序，每条都能单独提交）

1. **D6** 一行头注（Calendar 为什么不走 `planRowSeat()`）。
2. **D5** `0.5` → `1` + 一句同源注释。
3. **D1** `m18` 改名 + 守卫扩到档位自述（像素不变，**必红在**未改的树上）。
4. **D2** 合并两个 AA 判分器 + 枚举标记阶梯/链接色（会**新增 FAIL**，那是要的产出；豁免行按 ADR-0004 显式加）。
5. **D7** 给 `packages/plan_editor` 补一条可跑的 format/analyze 命令（先写进 `build.md` §5 的清单格，不动 CI）。
6. **D4** 只补 `dsw_shape.dart` 的口径头注 + 挑三个面局部上阶；**不建守卫**。
7. **D3** library 四面的行件与空态件合一（最大的一片，消掉 4 份座位实现与 6 份空态）。

## 6. 文档卫生：编号只能现场取，且本篇自己也有三条过期了

**取号这件事在本仓库里不能预留。** 本篇写下 0045–0050 那几个"建议编号"之后的几小时内，`docs/adr/` 就多出了 `ADR-0045-arc-production-readiness-form2-zcode-compat.md`（生产化总纲——形态② 自建后端 + ZCode 兼容参数层，ACCEPTED），于是本篇与 `docs/debt-register.md` 里预留的号全部作废。登记表已同步改成"取号以 `ls docs/adr/` 现场为准"，并新增一行把这条写成判词。**AGENTS.md:14 那句"下一编号 ADR-0044"同样是过期串（盘上 0044 与 0045 都在）**——我仍然没动 `AGENTS.md` 与 `.qoder/`/`.trae/` 规则文档，那要你先定口径。

**本篇 §3 里有三条事实需要按现状更正（并发会话已推进，证据在下列行号）**：

| 本篇原判断 | 现状（2026-10-02 复核） | 证据 |
| --- | --- | --- |
| D2 附属："企划的 11 档标记色没进 AA 枚举" | 仍然成立，未动 | `tool/contrast_check.dart:101` 仍是那 13 对；`planLadderColor`（`lib/ui/plan/dataview/plan_cell_value.dart:187`）无对应配对 |
| （上一轮我口头说过"API key 明文落盘是商用第一件事"） | **已闭**：密钥进 keychain，legacy 明文自动迁移并把盘上文档置空，损坏文件走 `.corrupt-<stamp>` 隔离，另有 `resetToDefaults()` | `lib/state/secret_store.dart:20-32`、`lib/model/app_settings_migration.dart:46-59`、`lib/state/settings_store.dart:52-62`、`:83-90`、`:130-141`；`test/settings_hardening_test.dart:73-87` 读的是**盘上字节** |
| （上一轮我口头说过"usage 完全没有"） | **已过时**：账本 + 设置里的 usage 一节都在（还多了可编辑的快捷键节）；缺的只剩**服务端配额语义** | `lib/state/usage_ledger.dart:69-77`、`lib/main.dart:94-98`、`lib/ui/settings/model_settings.dart:569`/`:574`/`:1374`（ADR-0045 PC @ `2c8fe74`） |

**再一条时效性更正**：本篇写完后的几小时内，并发会话又落了 PC/PD 两批（`2c8fe74`/`751f779`）——崩溃归档（`lib/state/crash_archive.dart` + `main.dart:74`）、设置页的 usage 与 shortcuts 两节（`lib/ui/settings/model_settings.dart:569`、`:574`）、版本号 `0.1.0` 与真 README/CHANGELOG。所以 `docs/production-readiness-gap-2026-10-02.md` 与 `AGENTS.md` §8 里「README 仍是模板 / 版本仍 0.0.1 / 无崩溃留痕 / 快捷键硬编码」四句**当下已过期**（我没动这两份文档，登记在 user-research 的 §0）。

**新增一条与本篇同一族但更硬的观察（防御深度，非现行缺陷）**：`SettingsStore.open()` 里那份"重写不含密钥的文档"用的是 `value.toJson()`（`settings_store.dart:61`），而 `save()`/`resetToDefaults()` 用 `toJsonWithoutSecrets()`（`:119`、`:142`）。今天安全**依赖迁移先把 `apiKey` 置空**（`app_settings_migration.dart:54`），不依赖写盘调用点收敛——未来再加一个带密钥的字段而忘记置空，`:61` 就会写出明文。已登记进 `docs/debt-register.md` 观察表。

**产品与商用形态的研究证据基础另见** [`docs/user-research/`](user-research/README.md)（2026-10-02 新建：章程 + 出实效大纲 + 深入研究）。其中一条与本仓库结构直接相关：**"两面共享工作区"只在文件层为真**——对象库是 Application Support 下唯一一份 `plan_space.json`（`lib/main.dart:106`），切工作区不动它，而笔记正文按工作区相对路径读写（`lib/ui/plan/plan_workspace.dart:219`、`:247`）。详见 `user-research/deep-dive-2026-10-02.md` §2。

## 7. 待精查（记数但不作结论）

- **桥只映射别名层的一小部分**：`lib/theme/dsw_shad_bridge.dart` 把 DswAlias 并进 `ShadColorScheme`，按前缀去重粗数约 16 枚，而 `ShadColorScheme` 自身字段数远多于此。若成立，则大量颜色别名**到不了 shad 组件内部画的表面**。本次没做精确普查（正则按前缀数，不严谨），**先不当成发现**，留给下一篇：判据应写成"每一枚 shad 表面的色都来自别名层的哪一枚"，而不是"映射了几枚"。

---

**复跑口径**（本篇每个数都能这样再生一次）：

```
dart format --set-exit-if-changed lib test tool spike && dart analyze --fatal-infos lib test tool spike
flutter test test/theme_token_test.dart test/theme_contrast_test.dart test/shad_radius_test.dart test/tooltip_timing_test.dart test/menu_chrome_test.dart
dart tool/contrast_check.dart | tail -3
dart tool/check_architecture.dart
# 令牌消费面（89 枚逐名查 lib/ui 是否有读者）
grep -oE '^  final Color [a-zA-Z0-9_]+;' lib/theme/dsw_alias.dart | awk '{print $3}' | tr -d ';' \
  | while read x; do grep -rlE "\.$x\b" lib/ui --include="*.dart" | grep -q . || echo "DEAD $x"; done
grep -rnE "Radius\.circular\([0-9]" lib/ui | wc -l
grep -rnE "(^|[^_A-Za-z])TextField\(|InputDecoration|PopupMenuButton|showMenu\(|waitDuration" lib/ui | wc -l
grep -rhoE "(all|horizontal|vertical|left|right|top|bottom): [0-9]+" lib/ui --include="*.dart" | awk -F': ' '{print $2}' | sort -n | uniq -c
grep -rnE "BorderSide\(" lib/ui | grep -oE "width: [0-9.]+" | sort | uniq -c
```
