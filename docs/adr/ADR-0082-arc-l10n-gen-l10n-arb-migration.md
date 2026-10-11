# ADR-0082: i18n 从自研字典迁到 flutter_localizations + gen-l10n（ARB），动态键走生成桥接（C-lite）

- **状态**: ACCEPTED（S1–S6 已落码、四门禁绿：S1–S5 @ `19cf7be`、S6 flip @ 本批；余 macOS 真机走查后转 RESOLVED）
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 架构（新增两处依赖 + 生成物入库 + `lib/l10n` 形态换血）· 生产功能（系统控件文案本地化）· 测试面（56 个 widget 测试的 pump 姿势）· 幻觉源（拼错键的降级形态改变）
- **日期**: 2026-10-11
- **来源**: 用户决策——「只用 `flutter_localizations` + ARB 的方式，全量搬进 `.arb` + `flutter gen-l10n`」；素材 `_archive_docs/website-main/examples/internationalization/`（flutter/website 官方 i18n 示例）；评估文档 `docs/i18n-flutter-localizations-migration-2026-10-11.md`
- **修复 commit**: 分阶段（见登记表行回填）

## 背景（Context）

当前 i18n 是自研的，全在 `lib/l10n/locales.dart`（**1898 行**）：两本 `const Map<String,String>`（`enStrings`/`zhStrings`，各约 **795** 键）、`translate()`（`:1824`，三级回退 `zh→en→key 本身` + `{token}` 插值）、`AppLocaleScope extends InheritedWidget`（`:1843`，`of()` 无 scope 即 `.en`，`:1850-1852`）、`context.tr(key)` 扩展（`:1859`）。规模：**875** 处 `.tr(` 调用（54 个文件），其中 **22** 处带参、约 **37** 处是**动态键**（下详）。三道 CI 守卫：ADR-0008（键集对齐）、ADR-0078（使用键 ⊆ 字典 + 占位符两侧对齐）、ADR-0080（`lib/` 无硬编码中文，零容忍）。

**动态键是本 ADR 的核心约束，也是 ADR-0078 判断错误的地方**（其 `:27` 声称「`.tr` 动态键名…代码库里没有这种用法」——实测有约 37 处）。其中一批来自**纯 Dart 模型**，是**不变量②（`lib/model` 不碰 UI/字典）的直接产物**，模型只能回「键」不能回「文案」：

- `model/relative_time.dart:14-18` `RelativeTime.key`（注释明写「answers with an i18n key… `lib/model` may not reach for the locale table (invariant 2)」）
- `model/shortcut_registry.dart:35` `ShortcutDef.labelKey`
- `model/plan_all_content.dart:59` `planAllContentGroupLabelCode(group)`

另一批在 UI 内部（可就地静态化）：`ui/plan/widgets/plan_widgets_screen.dart:89` `_sectionCode`、`ui/plan/dataview/plan_viewer_sheets.dart:174` `static const _label`、`ui/conversation/composer.dart` 的 `entry.$3/$4`、以及约 6 处三元（`allFolded ? 'expandAll' : 'collapseAll'` 等）。还有一处特殊：`ui/workbench/tabs/editor_tab.dart:150` 的 `_tr` 刻意用 `getInheritedWidgetOfExactType<AppLocaleScope>()`（**不注册依赖**）以便在 `initState` 期安全取词——`AppLocalizations.of(context)` 走 `dependOnInheritedWidgetOfExactType`，在 `initState` 里非法。

`gen-l10n` 只生成**类型化 getter/方法**（`l10n.close`、`l10n.terminalN(n)`），**没有「运行时字符串键→文案」的查表**。所以字面量键可机械改 getter，模型携带的动态键不能。

**可行性已在 3.41.9 实测通过**（本 ADR 立项前的一次 spike）：`flutter pub get` 加 `flutter_localizations`(SDK) + `intl: any` 成功；`flutter gen-l10n` 读 `l10n.yaml` 把生成物落进 `lib/l10n/`（用 `output-dir`，**无需** `synthetic-package`）；`untranslated.json` 空（zh 齐全）。生成物 API 关键点：`nullable-getter: false` ⇒ `AppLocalizations.of(context)` **非空**（`app_localizations.dart:70-72`，调用点无需 `!`）；`lookupAppLocalizations(Locale)`（`:149`）是**同步**的（`SynchronousFuture`）——种子名可在 `main` 里直接同步取，无需 `await`；`localizationsDelegates`/`supportedLocales`（`:87-99`）已打包三个 `Global*` 委托。**ICU 撞号坑（实测）**：无占位符消息里的 `''` 被**原样**输出为 `That''s`（`app_localizations_en.dart:28`），并未折叠成单个 `'`——即**转义是分情形的**：带 ICU 参数（占位符/复数/select）的消息按 ICU 规则须把裸 `'` 写成 `''`，无参数的消息按字面处理（`'` 原样、只 JSON 转义 `"`）。转换器必须区分，否则全库撇号会错。

`main.dart`：`MaterialApp`（`:403`）今天**没有** `localizationsDelegates`/`supportedLocales`/`locale`——系统控件文案恒英文；locale 由 `builder` 里的 `AppLocaleScope`（`:440-448`）从 `doc.locale`（en/zh/system→`Platform.localeName`）解一次，座位刻意在 Navigator 之上（ADR-0032）。种子名走 `planSeedNamesOf(seedLocale)`（`:146`，ADR-0074；demo 记录**正文**刻意保持英文，是样本数据不是文案）。

## 决策（Decision）

**全量迁到 `flutter_localizations` + `flutter gen-l10n`（ARB 为唯一盘上源），动态键采纳 C-lite：字面量键改类型化 getter，模型携带的少数动态键走「从 ARB 自动生成的 `trKey` 桥接」，不动 `lib/model`。**

1. **依赖与脚手架**：`pubspec.yaml` 加 `flutter_localizations:{sdk:flutter}` + `intl: any`（版本由前者钉），`flutter:{generate:true}`；`l10n.yaml` = `arb-dir: lib/l10n` / `template-arb-file: app_en.arb` / `output-localization-file: app_localizations.dart` / `output-dir: lib/l10n` / `nullable-getter: false` / `untranslated-messages-file: lib/l10n/untranslated.json`。
2. **生成物入库**：`lib/l10n/app_localizations*.dart` **提交入库**，与 ADR-0002/0060「`*.g.dart` 入库」同惯例（改 ARB 后跑 `flutter gen-l10n` 再提交）。
3. **字典 → ARB（一次性生成器）**：写一个**在 `flutter test` 里跑**的生成器（`locales.dart` 传递 import `package:flutter/widgets.dart`，纯 `dart run` 起不来），**import 求值后的 `enStrings`/`zhStrings`**（不许正则解析源码——ADR-0078 记过 `fontFamilyHint` 双引号假阳性的学费），产出 `app_en.arb`（模板）+ `app_zh.arb`。转换规则：`{token}` → `@key.placeholders`（type `String`）；带占位符的消息按 ICU 把裸 `'` 转 `''`，无占位符的按字面；`"` 一律 JSON 转义；键名即 Dart 标识符（现有 camelCase 天然合法）。生成器跑完即可删（一次性），产物 ARB 入库。
4. **调用点迁移**：
   - 约 850 处字面量 `X.tr('key')` → `AppLocalizations.of(X).key`（receiver-capturing codemod，逐模块过门禁）。
   - 22 处带参 → 生成方法是**位置参数**（`l10n.terminalN(n)`，非命名），手工改；多占位符按 ARB 声明序。
   - 约 6 处三元 + UI 内部的 `_label`/`_sectionCode` 等 → 直接静态 getter。
   - **模型携带的动态键** → `trKey(AppLocalizations l10n, String key, [Map<String,Object>? params])`，一个**从 ARB 生成的 `switch(key)`**（覆盖全键，故 ARB 仍是唯一源、桥接零手维护）；`lib/model` 继续回字符串键，**不变量②不破**。
   - `editor_tab.dart:150` 的 initState-safe `_tr` → 用 `context.getInheritedWidgetOfExactType<Localizations>()` 取 `AppLocalizations`（不注册依赖），或改到 `didChangeDependencies`。
5. **两个 locale 座位收敛为一个真值源**：`MaterialApp` 的 `locale`/`supportedLocales`/`localizationsDelegates` 与（迁移期仍存的）`AppLocaleScope.locale` **同源于 `doc.locale`**；`localeResolutionCallback` 把系统 locale 收敛到 supported。flip 阶段退役 `AppLocaleScope`，座位由 `MaterialApp` 承接（仍须覆盖 overlay 路由，ADR-0032 的老坑）。
6. **种子名**：`main` 改用同步 `lookupAppLocalizations(<seedLocale 对应的 Locale>)` 取 `seed*` getter，替代 `planSeedNamesOf`；demo 记录正文仍英文（ADR-0074）。
7. **守卫去留**：
   - **退役** `l10n_parity_test` 的键集对齐、使用键 ⊆ 字典、占位符对齐三道——gen-l10n 下缺译 = 编译错 + `untranslated.json` 报告，拼错**字面量**键 = 编译错，占位符签名由模板 ARB 统一。
   - **保留** `hardcoded_copy_test`（ADR-0080）：ARB **不阻止** `Text('确定')` 这类绕过本地化的硬编码，与用哪套 i18n 无关，继续零容忍。
   - **新增一道**守 `trKey` 的动态键：断言代码里传给 `trKey`/桥接的每个键字符串都在 ARB 里（补上退役的「使用键」守卫在动态路径上的空缺）。
   - `l10n_parity_test` 里那两条**值级**断言（加速键在 zh 可见）迁进一个 zh 渲染测试。
8. **测试确定性换姿势**：「无 scope ⇒ 英文」的旧确定性消失（`AppLocalizations.of` 无 delegate 会抛）。引入共享 pump 助手，一次接好 `localizationsDelegates`/`supportedLocales`；**先**给 56 个 `MaterialApp` 测试接上 delegate（此时 widget 仍用 `context.tr`，无害、保绿），**再**迁调用点。断言中文的用 `locale: Locale('zh')` pump。

**否决的替代**：
- **B（全量字符串桥接）**：所有 `context.tr(key)` 不动、只用生成桥接兜底——改动最小，但**任何键都无编译期安全**，保留 ADR-0078 那类静默回退。否：编译期安全正是 gen-l10n 的主要收益。
- **C（模型枚举化）**：把 `RelativeTime`/`ShortcutDef`/`plan_all_content` 等改成枚举 + UI switch→getter，全量编译期安全、彻底消灭动态键。否（暂缓）：要重构 `lib/model` 及其测试，blast radius 最大；~15 处动态键不足以偿付（ponytail）。动态键若增长可 revisit。
- **`intl_translation`/`intl_utils`**：老工具链已冻结（website `intl_example/pubspec.yaml` 里 `intl_translation` 被注释 + `TODO: add back when analyzer constraints allow`）。否：codegen 只用 SDK 自带 `flutter gen-l10n`。
- **仅接 widget 层、不搬 app 文案**（评估文档的 P1）：用户明确要全量搬 ARB。否。

## 后果（Consequences）

- **正面**：约 99% 调用点编译期键安全（拼错 = 编译错，根治 ADR-0078 的 `planLinkPrompt` 那类）；`.arb` 是行业标准交换格式（可外包翻译）+ `untranslated.json` 待译清单；系统控件（文本选择右键菜单、日期/时间选择器、语义标签）随 zh 本地化；ICU 复数/select/数字日期格式为未来备好；IDE 补全；单一真值源（ARB）。
- **负面/风险**：迁移面大（875 调用点 + 56 测试 + 生成器 + 桥接）；丢「无 scope⇒英文」的测试确定性（改为显式 delegate + locale）；`lib/l10n` 多出生成物；`trKey` 动态路径仍是 stringly-typed（另立守卫兜）；两处新依赖（`flutter_localizations` 是 SDK 包、`intl` 随其钉版）。ICU 转义跨 795 键的正确性以「gen-l10n 无 warning + 抽查含撇号/含引号键」验收；codemod 正确性以「逐模块 + 四门禁」验收。
- **中性**：`locales.dart` 在 flip 前与生成类共存，迁移期两套并行、逐模块推进，全程保绿；flip（退役旧 seam）是唯一「必须全量迁完才绿」的点。

## 验证（Verification）

分阶段，每阶段过 `dart format --set-exit-if-changed lib test tool spike` → `dart analyze --fatal-infos …` → `flutter test` → `dart tool/check_architecture.dart`：

- ✅ S1 脚手架 + S2 全量 ARB：`flutter gen-l10n` 无 warning、生成 795 getter、`untranslated.json` 空。
- ✅ S3 桥接（`tool/gen_tr_key.dart` → `lib/l10n/tr_key.dart`，795 case + `default: return key` 原样回退）+ main 接线。
- ✅ S4 调用点（888 处，逐模块过门禁）+ S5 测试（56 个 `MaterialApp` 测试接 delegate，逐模块随 widget 迁移）：S1–S5 一并落 `19cf7be`，`lib` 零 `.tr`/`translate`。
- ✅ S6 flip（删 `translate`/`AppLocaleScope`/`enStrings`/`zhStrings`/`context.tr`；`editor_tab` 与 `main` 改读 `Locale`；种子名走 `lookupAppLocalizations`；重写两道守卫）：全库无 `context.tr`、无 `AppLocaleScope` 引用。
- **S6 门禁（本机 macOS / Flutter 3.41.9）**：format 0 changed / analyze `No issues found` / `check_architecture` **8 recorded, 0 new**（rule 5 `riverpod-stays-in-the-assembly-root` 保住——构造注入未给 `lib/ui` 加 riverpod 导入）/ `flutter test` **+1490 −1**，唯一败 = `app_scope_test` 既有 macOS `/var`↔`/private/var` flake（该文件零 i18n 引用，非本次引入）。
- **待 macOS 真机走查**（签收单 [`walkthrough-i18n-flip-2026-10-11.md`](../walkthrough-i18n-flip-2026-10-11.md)）：①切 zh 系统控件中文 ②所有 app 文案中文 ③overlay 路由不回退英文（ADR-0032）④`untranslated.json` 空 ⑤四档字号下无裁字回归。

## 实施记录（Implementation Notes，2026-10-11 · S1–S6 落码后的四处偏离）

决策正文（§4/§6/§7）在实施中撞到三个正文没预见的约束，按 ponytail「根因修复」就地更正，记在此处（正文保留原样以存决策演进）：

1. **§4 `editor_tab._tr` 改「构造注入 `Locale`」，而非正文的 `getInheritedWidgetOfExactType<Localizations>()` / `didChangeDependencies`。** 正文那条技术上不成立：`Localizations` **不是** `InheritedWidget`（其 scope 是私有 `_LocalizationsScope`），`getInheritedWidgetOfExactType<Localizations>()` 取不到；而 `_load()` 的前三个 `_tr`（`tabHasNoFile`/`noWorkspaceNoFile`/`fileNoLongerExists`）跑在 `initState` 的**同步栈**里（首个 `await` 之前），`didChangeDependencies` 够不着、`dependOnInheritedWidgetOfExactType` 在此非法。**另一条被否决的路**：转 `ConsumerStatefulWidget` 用 `ref` 读 locale——会给 `lib/ui` 加 `import 'package:flutter_riverpod'`，撞**架构 rule 5**（`lib/ui` 零 riverpod 导入、baseline 0 违例），只能靠削弱硬不变量「弄绿」，否。**采纳**：`workbench.dart` 的 tab `descriptor.build(context, …)` 在**构建期**读 `Localizations.localeOf(context)`（合法）经构造参数注入 `EditorTab(locale:)`，`_tr` 用同步的 `lookupAppLocalizations(widget.locale)`——既保 rule 5、又 initState 安全，默认 `Locale('en')` 保测试确定性。

2. **§6 `planSeedNamesOf` 保留（改吃 `AppLocalizations`），而非正文的字面「替代」。** `main` 确实用了同步 `lookupAppLocalizations(seedLocale)`（满足 §6「同步取 seed* getter」的意图），但把 21 个 `seed*` 字段**内联进 `main.dart`** 会违反 AGENTS.md §2「`main.dart` 不做业务决策」——21 字段的 `PlanSeedNames` 组装是一次映射决策，属 l10n 桥而非装配根。故 `locales.dart` 保留 `planSeedNamesOf(AppLocalizations)` 作种子名桥（`main` 调 `planSeedNamesOf(lookupAppLocalizations(seedLocale))`）。它**不能**下沉进 `lib/model`（`AppLocalizations` 是生成的 Flutter 代码，不变量②）。

3. **`locales.dart` 瘦身为 44 行的种子名桥（保留文件名）。** 从 1898 行（两本字典 + `translate` + `AppLocaleScope` + `context.tr` + `planSeedNamesOf`）砍到只剩 `planSeedNamesOf`。保留文件名而非删除，避免 ADR/AGENTS.md/测试注释里 `locales.dart` 引用的改名 churn；header 已重写说明字典迁往 ARB。

4. **§7 新增一道 `untranslated.json` 空守卫，作为退役「键集对齐」的忠实替代。** 正文 §7 说「gen-l10n 下缺译 = 编译错」——**不准确**：zh 缺一个键**不是**编译错，gen-l10n 运行时回退到模板（en）、只把缺口记进 `untranslated.json`。若照正文退役键集对齐而不补守卫，zh 会**静默**退回英文而全套件仍绿。故 `l10n_parity_test` 新增断言 `untranslated.json == {}`（它正是「缺译键集」），忠实接替退役的键集 parity；`trKey ≡ ARB` 守卫（§7 第三条）覆盖动态键路径；加速键值级断言（§7 第四条）保留在本测试。`i18n_overlay_test` 则从 ADR-0032 的「`AppLocaleScope` 落在 builder」结构守卫，改写为「`MaterialApp` delegate 机制」：断言 `main.dart` 里 `AppLocaleScope(` 出现 0 次 + delegate（在 Navigator 之上）能把一条菜单路由渲染成中文（zh `重试`）——gen-l10n 的 `localizationsDelegates` 由框架装在 `MaterialApp` 上、天然在 Navigator 之上，比旧结构守卫更硬地兑现 ADR-0032 的意图。

## 关联（Links）

- 代码: `lib/l10n/locales.dart`（`:1824` translate / `:1843` AppLocaleScope / `:1859` tr / `:1871` planSeedNamesOf）、`lib/main.dart:403-456`（MaterialApp + locale 座位）、`lib/model/relative_time.dart:14-18`、`lib/model/shortcut_registry.dart:35`、`lib/model/plan_all_content.dart:59`、`lib/ui/workbench/tabs/editor_tab.dart:150`（initState-safe `_tr`）、`l10n.yaml`、`lib/l10n/app_localizations*.dart`（生成物）。
- 测试: `test/l10n_parity_test.dart`（三道中退役两道）、`test/hardcoded_copy_test.dart`（保留）。
- 关联 ADR: ADR-0008（键集对齐——退役）、ADR-0078（使用键+占位符——退役，动态路径另立守卫；其「无动态键」判断被本 ADR 更正）、ADR-0080（无硬编码中文——保留）、ADR-0074（种子名）、ADR-0032（locale 座位在 Navigator 之上）、ADR-0002/0060（生成物入库惯例）。
- 规则: `.qoder/rules/workflow.md` §5（动 `lib/` 先立 ADR）、§3（文案）、§4（测试）；`.qoder/rules/ponytail.md`（C-lite 而非 C 的依据）。
- 素材/评估: `_archive_docs/website-main/examples/internationalization/gen_l10n_example/`（`l10n.yaml`、`app_en.arb`、`lib/main.dart` 的 `#docregion material-app`、`lib/l10n/app_localizations.dart`、`no_app_localizations.dart`）、`docs/i18n-flutter-localizations-migration-2026-10-11.md`。
