# i18n 迁移评估：接入 `flutter_localizations` 与其他值得做的调整

- **日期**：2026-10-11
- **素材**：`_archive_docs/website-main/examples/internationalization/`（flutter/website 官方 i18n 示例，只读副本，已进 `.gitignore`）
- **触发**：用户指令——「基于 `_archive_docs` 里的使用建议，接入 `flutter_localizations` 调整当前所有国际化文本；此外还有哪些值得做的一并落进 docs」
- **性质**：**评估与建议**，不含实现。真要动 `lib/` + 依赖 + 测试面，按 `.qoder/rules/workflow.md` §5 先立一枚 **ARC 类 ADR**（本文 §6 的 S0）。
- **姊妹文档**：`docs/flutter-website-agent-skills-integration-2026-10-11.md`（同一批 website 素材里的 agent skills 面）。i18n 与它互不重叠。

---

## 1. 结论先行（TL;DR）

1. **`flutter_localizations` 值得接，但「接它」和「把所有文案搬进 ARB」是两件事**，成本差一个数量级。建议**分两段**：
   - **P1（现在就做，便宜、有实感收益）**：只把 `flutter_localizations` 接进 **widget 层**——MaterialApp 挂 `localizationsDelegates` + `supportedLocales` + `locale`，让**系统级控件文案**（文本选择右键菜单「剪切/复制/粘贴/全选」、日期时间选择器、可访问性标签）跟着 zh 走，并铺好 `Localizations` 管线与未来 RTL 的地基。**app 自己的 ~795 条文案原地不动**，`context.tr` 与三道守卫全部保留。这正是 website 自带的 `no_app_localizations.dart` 演示的形态。
   - **P2（延后到有驱动再做，本文给完整施工表）**：把两本字典搬进 `.arb` + `flutter gen-l10n`，875 处 `context.tr('key')` 换成类型化 getter，退役 `translate`/`AppLocaleScope`。**驱动条件**见 §5.3——在第三语种、复数/性别、日期数字本地化、或外包翻译之前，P2 的收益抵不过它的成本与风险。
2. **诚实边界**：当前自研 i18n **不是负债**——它工作、有三道 CI 守卫（ADR-0008/0078/0080）、零依赖、且有一条被 102 个测试依赖的确定性（无 scope ⇒ 英文）。P2 主要买的是「编译期键安全 + ICU 复数 + 标准 `.arb` 交付」，而这三样**本 app 今天都用不上**（实测：0 处 `intl`/复数/日期数字格式化；22 处带参全是 `{token}` 纯插值）。所以本文推荐 **P1 立即做、P2 备好图纸但按下不表**。
3. **除 `flutter_localizations` 外**，website 素材里对本项目真正值得的只有少数几项（§7 逐条判定）：**无障碍测试模式**（`examples/accessibility/a11y_test.dart`，adopt，但桌面端 ROI 排 P2/P3）、**`intl` 的本地化日期/数字**（reference，仅当企划的数据视图要跟着 locale 变格式）。其余（`intl_translation`、更重的 lint 集、site 专用 skills）判 **skip**，理由在 §7 与 §8。

---

## 2. 现状：自研 i18n 长什么样（证据）

全部集中在一个文件 `lib/l10n/locales.dart`（**1898 行**，AGENTS.md 里记的 1.4k 已腐烂，引用前重算）：

| 部件 | 位置 | 作用 |
| --- | --- | --- |
| `enum AppLocaleId { en, zh }` | `locales.dart:32` | 只有两档 |
| `const enStrings` / `const zhStrings` | `:35` 起 / 中段 | 两本 `Map<String,String>` 字面量 |
| `translate(locale, key, [params])` | `:1824-1839` | 三级回退 `zh → en → key 本身`；`{token}` 用 `replaceAll` 插值 |
| `class AppLocaleScope extends InheritedWidget` | `:1843-1857` | locale 的座位；`of(context)` 在**无 scope 时回退 `.en`**（`:1850-1852`） |
| `extension AppLocaleTrX on BuildContext` | `:1859-1863` | `context.tr(key, [params])` |
| `planSeedNamesOf(id)` | `:1871-1897` | 企划 demo 种子的**家具名**也从这两本字典取（ADR-0074） |

**规模（2026-10-11 实测，会腐烂，重算用 §2 末命令）**：

- `.tr(` 调用点 **875** 处，分布在 **54** 个文件
- 去重后代码实际用到的键 **629** 个；字典每本约 **795** 键（两本共 1590 条 `'key':` 字面量）
- 带参（`{token}` 插值）调用 **22** 处——全部是简单字符串替换，**无一**用到复数/性别/数字或日期格式化
- `lib/` 内 `intl` / `Intl.` / `numberFormat` / `plural` 用量 **0**（grep 命中的 `dateFormat` 全是企划域自己的 `PlanDateFormat` 枚举，与 `intl` 无关）

**接线（`lib/main.dart`）**：`MaterialApp`（`:403`）→ `builder`（`:413`）里按 `MediaQuery(字号) → ShadTheme → AppLocaleScope → ShadSonner` 顺序包；`AppLocaleScope.locale`（`:440-448`）由 `doc.locale` 三态开关（en/zh/system→`Platform.localeName`）解一次。**MaterialApp 今天没有 `localizationsDelegates` / `supportedLocales` / `locale`**——即系统控件文案恒为英文，app 文案全走自研 scope。locale 座位刻意挂在 Navigator 之上（ADR-0032：否则覆盖层路由会逐键退回英文）。

**三道守卫（都在 CI 上跑）**：

- `test/l10n_parity_test.dart`：① en/zh 键集相等（ADR-0008）② 代码用到的每个 `.tr('key')` 都在字典里 ③ 每个键的 `{token}` 占位符两侧集合相等（后两道 ADR-0078）。
- `test/hardcoded_copy_test.dart`：`lib/` 内不许出现硬编码中文 UI 文案（`Text('确定')` 这类绕过字典的），零容忍基线（ADR-0080）。
- 关键教训（ADR-0078）：`planLinkPrompt` 曾因**代码用了、字典没有**而把驼峰键名当标题渲染给用户——这正是「编译期键安全」想根治的缺陷类型，但目前**已由测试兜住**。

**测试确定性（P2 的最大隐性成本）**：`AppLocaleScope.of()` 无 scope 即 `.en`，所以 widget 测试**不挂任何本地化管线**就能断言英文文案。实测：`test/` 里 **56** 个文件建 `MaterialApp`、**0** 个设 `localizationsDelegates`、**57** 个用 `pumpWidget`、**10** 个引用 `AppLocaleScope`。换成 `AppLocalizations.of(context)!`（生成类，无 delegate 时返回 **null**）后，这 56 个测试只要渲染到本地化文案就会 `!` 崩，必须逐个补 delegate。

> 重算命令：`grep -rn "\.tr(" lib | wc -l`、`grep -rhoE "\.tr\(\s*'[a-zA-Z0-9_]+'" lib | sort -u | wc -l`、`grep -cE "^\s*'[a-zA-Z0-9_]+':" lib/l10n/locales.dart`、`grep -rln MaterialApp test | wc -l`。

---

## 3. website 的建议是什么（证据）

`examples/internationalization/` 下四个样例。注意其 `README.md` 自述这些样例「曾位于 `src/_includes/code`、并未真正被站点引用、需逐个复核」——是**参考级**而非金科玉律；且样例 `pubspec.yaml` 钉 `sdk: ^3.13.0-0`，**比本项目（Dart `^3.11.5` / Flutter 3.41.9）新**，落地前一切以本机 SDK 实测为准。

**主推形态 = `flutter gen-l10n` + ARB（`gen_l10n_example/`）**：

- `l10n.yaml`：`arb-dir: lib/l10n` / `template-arb-file: app_en.arb` / `output-localization-file: app_localizations.dart`。
- `pubspec.yaml`：加 `flutter_localizations: {sdk: flutter}` + `intl: any`（用 flutter_localizations 钉的版本），并在 `flutter:` 下加 `generate: true`。
- `lib/l10n/app_en.arb`：模板语种，每条带 `@key` 元数据（`description`、`placeholders` 的 `type`/`format`/`example`）。ARB 原生支持 **ICU**：`{count, plural, =0{…} =1{…} other{…}}`、`{gender, select, male{he} …}`、以及带格式占位符（`format: compact` / `compactCurrency` / `decimalDigits`）。
- `lib/main.dart` 的 `#docregion material-app`：`localizationsDelegates: [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates]`、`supportedLocales: [Locale('en'), Locale('es')]`；取词 `AppLocalizations.of(context)!.hello('John')`。
- 生成物 `lib/l10n/app_localizations.dart` 的公开面（实测行号）：`of(context)` 返回**可空** `AppLocalizations?`（`:70`）、`delegate`（`:74`）、**`localizationsDelegates`**（`:87`，已含 AppLocalizations + 三个 Global\* 委托）、**`supportedLocales`**（`:96`）、`load(locale)`（`:137`，无 context 直接按 locale 载入——种子名可用它）。最省心的接线就是 `localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales`。

**只接 widget 层、不搬 app 文案的形态（`gen_l10n_example/lib/no_app_localizations.dart`）**：`localizationsDelegates: GlobalMaterialLocalizations.delegates` + `supportedLocales: [...]`，**没有** `AppLocalizations`。——**这就是本文 P1 的官方依据**：`flutter_localizations` 的收益（系统控件本地化 + RTL 地基）可以独立于「把 app 文案搬进 ARB」拿到。

**locale 解析（`gen_l10n_example/lib/examples.dart` 的 `#docregion locale-resolution`）**：`localeResolutionCallback` / `locale` 用来把「系统 locale」收敛到「app 支持的 locale」——本项目要和既有的 `doc.locale`（用户在设置里选的 en/zh/system）**对齐成同一个真值源**。

**加自定义语种（`add_language/`）**：给 Flutter **未内置**的语种（示例是挪威新挪威语 `nn`）写自定义 `NnMaterialLocalizations` 委托。**中文 `zh` 是 Flutter 内置的**，`GlobalMaterialLocalizations` 直接支持，本项目用不到这条。

**旧路线已冻结（`intl_example/`）**：它用 `intl` + `flutter_localizations`，但 `intl_translation` 被**注释掉**并标 `TODO: Add back when analyzer constraints allow`——即 `intl_translation`/`intl_utils` 那套「ARB→代码」的老工具链处于冻结态。**别走它**，要 codegen 就用 SDK 自带的 `flutter gen-l10n`。

---

## 4. `flutter_localizations` 到底补了什么当前没有的

| 能力 | 现状 | 接入后 |
| --- | --- | --- |
| **系统控件文案本地化** | 恒英文：文本选择右键菜单（剪切/复制/粘贴/全选）、`showDatePicker`/`showTimePicker`、`Cupertino*` 控件、可访问性语义标签 | 跟 `supportedLocales` 里的 zh 走——**P1 唯一但真实的用户可见收益** |
| **`Localizations` 标准管线** | 无；自研 `AppLocaleScope`（一个 `InheritedWidget`） | 框架级 `Localizations` + `Locale` 解析，生态工具（含 gen-l10n）都认 |
| **RTL 地基** | 无（`GlobalWidgetsLocalizations` 提供文本方向与本地化控件文案） | 铺好；但 en/zh 都是 LTR，**今天无实感**（YAGNI，见 §8） |
| **ICU 复数/性别/数字日期格式** | 无（22 处带参全是纯 `{token}`） | ARB 原生支持；**但 app 今天 0 需求**（P2 才用得上） |
| **编译期键安全** | 靠 ADR-0078 的测试扫描（运行时才红→其实 CI 红） | gen-l10n 后拼错键 = 编译错；**边际收益小**，因为测试已兜住 |

一句话：**P1 拿的是第 1、2 行（widget 层 + 管线），便宜且立刻可见；第 3、4、5 行要 P2，且当前无驱动。**

---

## 5. 迁移路线

### 5.1 路线 A —— 只接 widget 层（**推荐先做**，= website `no_app_localizations.dart`）

**改动面**：`pubspec.yaml`（+2 依赖）、`lib/main.dart`（MaterialApp 接线）、可能一个共享测试助手。**不碰** `locales.dart`、不碰 875 个调用点、不碰三道守卫。

**要点**：

1. `pubspec.yaml` 加：
   ```yaml
   dependencies:
     flutter_localizations:
       sdk: flutter
     intl: any            # 用 flutter_localizations 钉住的版本
   ```
2. `main.dart` 的 `MaterialApp` 补三个参数，并让 locale **只有一个真值源 = `doc.locale`**（今天 `AppLocaleScope.locale` 已经从它解，复用同一段 switch）：
   ```dart
   localizationsDelegates: GlobalMaterialLocalizations.delegates,
   supportedLocales: const [Locale('en'), Locale('zh')],
   locale: <由 doc.locale 解出的 Locale>,   // en→Locale('en'), zh→Locale('zh'), system→交给 localeResolutionCallback 或沿用 Platform.localeName 判断
   ```
   - `GlobalMaterialLocalizations.delegates`（复数 getter）是**较新 SDK 的简写**，等价于显式三委托 `[GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate]`。**3.41.9 上先验证复数 getter 存在**；不确定就用显式三委托（全版本可用）。
3. **两个 locale 座位必须同源**：MaterialApp 的 `locale`（驱动 widget 层）与 `AppLocaleScope.locale`（驱动 app 文案）都从 `doc.locale` 派生。否则会出现「右键菜单中文、按钮英文」或反之的错位。ADR-0032 已经教训过 locale 座位的位置——保持在 Navigator 之上。
4. **测试**：路线 A **不要求**给 56 个测试补 delegate（app 文案仍走 `AppLocaleScope.of()→.en` 的确定性回退）。但若某测试直接渲染 Material `TextField` 的选择菜单并断言其文案，需在该测试的 MaterialApp 上补 delegate——面很小。建议顺手加一个共享 `pumpApp` 助手把 delegate 一次接好，为 P2 铺路。

**成本**：小时级。**风险**：低（新增依赖 + 接线；不改文案路径）。**收益**：zh 下系统控件文案本地化 + 标准管线 + RTL 地基。

### 5.2 路线 B —— 全量搬进 ARB（用户「所有文本」的字面诉求，= website `gen_l10n_example`）

在路线 A 之上继续，把 ~795 键 × 2 语种搬进 `.arb`，退役自研 seam。施工表见 §6。**成本**：人日级（875 调用点 + 56 测试 + 种子名特殊路径 + 三道守卫替换）。**风险**：中-高（面广、丢可见缺口回退、测试确定性重建）。**收益**：编译期键安全 + ICU + 标准 `.arb` 外包交付 + IDE 补全。

### 5.3 何时才值得做 B（触发条件，满足任一再启动）

- 要加**第三语种**（此时人肉维护三本 `Map` 的键集对齐开始真的痛，`.arb` + `untranslated-messages-file` 的待译清单才划算）；
- 出现**复数/性别**文案（如「N 个文件」要按语种变形态），或要把**日期/数字**按 locale 格式化（企划数据视图/日历）；
- 文案要**交给外部译者/本地化平台**（`.arb` 是行业标准交换格式，两本 Dart `Map` 不是）；
- 自研守卫反复漏（目前 ADR-0078/0080 三道都还兜得住，未达此条）。

在以上都没发生前，**B 是 YAGNI**（ponytail：最简够用优先）。

---

## 6. 路线 B 完整施工表（备好图纸，触发即按此走）

> 每一步都要能独立过门禁（`dart format --set-exit-if-changed lib test tool spike` → `dart analyze --fatal-infos …` → `flutter test` → `dart tool/check_architecture.dart`）。

**S0 · 立 ARC 类 ADR**（前置，`.qoder/rules/workflow.md` §5）。内容：为何从自研 seam 迁到 gen-l10n、两个 locale 座位如何收敛成一个、三道守卫的去留、种子名的处理、回滚策略。ADR 状态机走完再动手。

**S1 · 依赖与脚手架**：`pubspec.yaml` 加 `flutter_localizations` + `intl: any`；`flutter: {generate: true}`；新建 `l10n.yaml`（`arb-dir: lib/l10n`、`template-arb-file: app_en.arb`、`output-localization-file: app_localizations.dart`、建议加 `untranslated-messages-file: lib/l10n/untranslated.json` 供待译清单）。确认生成物落点（默认 `.dart_tool/flutter_gen/`，或 `synthetic-package: false` 落进 `lib/l10n/`——**建议后者**，与本项目「`*.g.dart` 入库」的惯例一致，见 ADR-0002/0060）。

**S2 · 由字典生成 ARB（一次性脚本，别手抄 1590 条）**：
- `app_en.arb` = `enStrings`，`app_zh.arb` = `zhStrings`。`l10n_parity_test` 已保证两本键集相等——**迁移前它绿，就意味着可以安全机器转换**。
- 键名即 Dart 标识符：现有 camelCase 键（`appName`、`reloadDirtyTitle`…）天然合法，直接做 getter 名。
- **ICU 转义（真坑）**：ARB 用 ICU MessageFormat，单引号 `'` 是转义符、`{`/`}` 是占位符定界。英文文案里的撇号（`That's`、`don't`）必须写成 `''`；字面花括号要转义。转换脚本必须处理，否则生成即错。
- **22 个带参键**：为每个生成 `@key.placeholders`，类型先统一 `String`（当前都是 `toString` 插值，无数字/日期格式化需求）；将来要数字/日期格式再改 `type`/`format`。
- 脚本放 `tool/`（与 `import_agent_skill.dart` 同级惯例），跑完把 ARB 入库，脚本可留作回归。

**S3 · 种子名（`planSeedNamesOf`）特殊路径**：这 ~21 个 `seed*` 键是**数据**（在 `main.dart:135` 按 `seedLocale` 解一次，早于任何 `BuildContext`），不是 context 驱动的 UI 文案。两个选择：
- (a) 用生成类的 `AppLocalizations.delegate.load(locale)`（`:137`，返回 `Future`）在 main 里 `await` 后取 `.seedDeliveryBoard` 等——统一进 ARB，但给启动链加一次异步载入；
- (b) **把这 21 条留在一个独立的小 `const` map**（推荐，ponytail：数据归数据，别硬塞进 context 本地化）。
- 无论哪种，**demo 记录的正文内容**（17 条示例笔记标题）刻意保持英文——是样本数据不是文案（`locales.dart:1868-1870` 注释 + ADR-0074），迁移时不要误搬。

**S4 · 调用点迁移（875 处）**：`context.tr('key')` → `AppLocalizations.of(context)!.key`；`context.tr('key', {'n': x})` → `AppLocalizations.of(context)!.key(n: x)`。
- **不建议**保留 `context.tr(String)` 字符串 shim 去查生成类：那样等于放弃编译期键安全（B 的主要卖点），还要额外维护一张 `Map<String, …>`。要 B 的收益就走类型化 getter。
- 量大但机械，可脚本辅助 + 分模块提交（`lib/ui/conversation` → `workbench` → `plan` → `settings` → …），每模块过一遍门禁。
- `import 'package:planstar/l10n/locales.dart'` 换成 `import '…/app_localizations.dart'`（或生成的 `.dart_tool/flutter_gen/gen_l10n/…`，取决于 S1 落点选择）。

**S5 · 测试迁移（56 个 MaterialApp）**：
- 引入共享助手（如 `test/helpers/pump_app.dart`），把 `MaterialApp(localizationsDelegates: AppLocalizations.localizationsDelegates, supportedLocales: AppLocalizations.supportedLocales, locale: …, home: …)` 封一层；逐个测试改用它。这是 B 的**主要工作量**。
- 需要断言中文的测试，用 `locale: Locale('zh')` pump；断言英文的用 `Locale('en')`。**「无 scope⇒英文」的旧确定性消失**，改为「显式给 locale」——更啰嗦但更真实。
- 守卫去留：
  - 键集对齐（ADR-0008）→ **退役**：gen-l10n 下缺译 = 编译错 + `untranslated-messages-file` 报告，比测试更强。
  - 使用键 ⊆ 字典（ADR-0078 第①道）→ **退役**：拼错键 = 编译错。
  - 占位符两侧对齐（ADR-0078 第③道）→ **退役**：占位符由模板 ARB 定义，各语种共用同一签名。
  - **`hardcoded_copy_test`（ADR-0080）保留**：ARB **不阻止** `Text('确定')` 这种绕过本地化的硬编码，这道守卫与用哪套 i18n 无关，继续零容忍。
  - `l10n_parity_test` 里那两条**值级**断言（快捷键加速键在 zh 里可见）改成对生成类的断言，或迁进新的 zh 渲染测试。

**S6 · 退役旧 seam**：删 `translate`、`AppLocaleScope`、`AppLocaleTrX`、两本字典（保留 S3 选定的种子名结构）。`main.dart` 的 `AppLocaleScope` 座位由 MaterialApp 的 `locale`/`localizationsDelegates` 取代；确认覆盖层路由（dialog/sheet）仍在 `Localizations` 之下（ADR-0032 的老坑，用 `builder` 或 MaterialApp 自身保证）。

**S7 · 收尾门禁 + 真机走查**：四道命令全绿；`dart tool/check_architecture.dart` 不因新 import 破线（gen_l10n 生成物在 `lib/` 时注意别踩「riverpod 只在装配根」等规则——本项目 `lib/l10n` 本就无 riverpod，风险低）。**待 macOS 真机验证**：切到 zh，确认①右键菜单/日期选择器中文 ②所有 app 文案中文 ③覆盖层路由不回退英文 ④`untranslated.json` 为空。

---

## 7. 除 `flutter_localizations` 外，还值得做什么（逐条判定）

判定口径沿用本仓库其它对比文档：**adopt（值得做）/ reference（参考，按需）/ skip（不做，带理由）**。

| 来源（`_archive_docs/website-main/`） | 判定 | 说明 |
| --- | --- | --- |
| `examples/accessibility/`（`a11y_test.dart` + `meetsGuideline` 匹配器、Semantics） | **adopt（P2/P3）** | 桌面端也有读屏需求；可给关键屏（对话列、设置、企划数据视图）加**无障碍冒烟测试**（`meetsTapTargetGuideline`/`meetsContrastGuideline`/`labeledTapTarget`）。但桌面 a11y 的 ROI 低于移动，排在 i18n 之后。**先立 TST 类 ADR**。 |
| `intl` 的本地化**日期/数字格式化**（随 `flutter_localizations` 一并进来） | **reference** | 仅当企划的数据视图/日历要让日期数字**跟着 locale 变格式**时才用（今天是固定格式的 `PlanDateFormat` 枚举，`lib/model/plan_*`）。别为了「用 intl 而用 intl」重构现有格式枚举。 |
| `examples/app-architecture/`（`result`、`command`、`offline_first`、`optimistic_state`、`todo_data_service`） | **reference** | 本项目已是 riverpod + 自有分层。`result`（把失败当值返回）模式可**参考**用于工具调用/IO 的错误处理表达，但不是迁移项。 |
| `examples/testing/`（`common_errors`、`integration_test`、`code_debugging`） | **reference** | 已有 102 个 `*_test.dart` + `spike/runtime_smoke.dart`。`integration_test` 对**桌面**支持有限；`common_errors` 可作排障阅读材料。 |
| `.agents/skills/write-flutter`、`write-dart` | **done** | 已在姊妹文档 P0-1 落地安装（`~/.planstar/skills` 或工作区 `.agents/skills`），本文不重复。 |
| `.agents/skills/update-llms-text`（llms.txt） | **reference** | 姊妹文档已记为 P2-1；与 i18n 无关。 |
| `.agents/skills/validate-pr`、`format-markdown`、`write-technical-docs`、`contribute-blog`、`update_whats_new` | **skip** | 面向 website 仓库自身的贡献流程（PR 校验、博客、What's New）；本项目已有 `pr-check.yml`（format+analyze+test）与 `docs/README.md` 的 ADR 规范，无需引入。 |
| `sites/www/.agents/skills/`（`extract-to-jaspr`、`generate-showcase-from-video`、`data-model`） | **skip** | 站点构建（Jaspr）专用，与桌面 app 无关。 |
| `examples/internationalization/intl_example`（`intl_translation`） | **skip** | 老工具链，`intl_translation` 在样例里已被注释冻结（§3）。要 codegen 只用 `flutter gen-l10n`。 |
| website 的 `analysis_options.yaml`（更重的 lint 集） | **skip** | 本项目刻意只用 `flutter_lints`（`riverpod_lint` 因 SDK meta 约束暂不可装，ADR-0002 修订 1）。无驱动不加重 lint 面——会制造一批 `// ignore`（ADR-0017 的同款学费）。 |

---

## 8. 明确不做 / YAGNI（诚实边界）

- **不为「标准」而做 P2**：在 §5.3 的触发条件出现前，全量 ARB 迁移是负 ROI——它买的能力（ICU 复数、编译期键安全、外包交付）本 app 今天 0 需求，而它要付的成本（875 调用点 + 56 测试 + 丢失「无 scope⇒英文」的确定性 + 三道守卫重建）是实打实的。
- **不追 RTL**：en/zh 皆 LTR，`GlobalWidgetsLocalizations` 的方向支持是地基不是需求；等真要上阿拉伯语/希伯来语再谈。
- **不走 `intl_translation`/`intl_utils`**：已冻结（§3、§7）。
- **不动 genkit 工具描述与错误串**：那是给模型读的 prompt，不是 UI 文案，`locales.dart:20-21` 已明确排除，迁移时同样排除。
- **不动持久化的 tab 标题**（`Terminal 3`、文件 basename）：数据不随语言翻转（`locales.dart:22-25`），迁移时同样排除。
- **不为了本评估引入任何依赖**：本文只读 website 副本 + 读本仓库，未改 `pubspec.yaml`/`lib/`。

---

## 9. 风险与回滚

- **两个 locale 座位错位**（P1 主要风险）：MaterialApp `locale` 与 `AppLocaleScope.locale` 必须同源于 `doc.locale`。回滚：P1 是纯增量（新增依赖 + 三个参数），删掉即回到现状，零残留。
- **`GlobalMaterialLocalizations.delegates` 复数 getter 在 3.41.9 是否存在**：落地前用本机 SDK 实测；不确定就用显式三委托。
- **ICU 转义漏网**（P2/S2）：撇号/花括号未转义会让生成物错乱——转换脚本必须覆盖，且以「生成后 `flutter gen-l10n` 无 warning + 抽查含撇号键」为验收。
- **测试确定性重建**（P2/S5）：56 个测试改 pump 姿势，量大但机械；以共享助手收敛，逐模块提交、逐模块过门禁，避免一次性大爆炸。
- **回滚（P2）**：因 S2 由字典机器生成 ARB，旧 `locales.dart` 在迁移分支保留到 S7 真机签收前不删；出问题回退到路线 A 状态（widget 层已接、app 文案仍走 `context.tr`）。

---

## 10. 关联

- **本仓库现状**：`lib/l10n/locales.dart`（`:1824` translate、`:1843` AppLocaleScope、`:1859` tr、`:1871` planSeedNamesOf）、`lib/main.dart:403-456`（MaterialApp + locale 座位）、`test/l10n_parity_test.dart`、`test/hardcoded_copy_test.dart`。
- **相关 ADR**：ADR-0008（键集对齐守卫）、ADR-0078（使用键 + 占位符守卫）、ADR-0080（无硬编码中文）、ADR-0074（种子名随字典）、ADR-0032（locale 座位在 Navigator 之上）、ADR-0002/0060（`*.g.dart`/生成物入库惯例，供 S1 落点参考）。
- **规则**：`.qoder/rules/workflow.md` §5（动 `lib/` 先立 ADR）、§3（文案约定）、§4（测试约定）；`.qoder/rules/ponytail.md`（YAGNI/最简优先——本文推荐分段的依据）。
- **website 证据**：`_archive_docs/website-main/examples/internationalization/`（`gen_l10n_example/{l10n.yaml,pubspec.yaml,lib/l10n/app_en.arb,lib/main.dart,lib/l10n/app_localizations.dart,lib/no_app_localizations.dart,lib/examples.dart}`、`add_language/`、`intl_example/pubspec.yaml`、`README.md`）、`examples/accessibility/`。
- **姊妹文档**：`docs/flutter-website-agent-skills-integration-2026-10-11.md`。
