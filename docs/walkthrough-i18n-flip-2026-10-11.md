# 真机走查签收单 — i18n flip（ADR-0082 S6）

> **这是什么**：ADR-0082 把 PlanStar 的 i18n 从自研双字典（`locales.dart` 的 `enStrings`/`zhStrings` + `translate()` + `AppLocaleScope` + `context.tr()`）全量迁到 `flutter_localizations` + `flutter gen-l10n`（ARB 为唯一盘上源），flip（S6）已退役旧 seam。代码 + 四门禁已绿（`flutter test` **+1490 −1**，唯一败 = `app_scope_test` 既有 macOS `/var`↔`/private/var` flake，与 i18n 无关）。**本单只列机器证不了、必须人眼在 macOS 真机上过一遍的那几件事**；每格标注「已由测试证过」的部分不必重复检查。
>
> **走查通过后**：把 ADR-0082 从 ACCEPTED 改 RESOLVED，回填 flip 的 commit hash，并在 debt-register 同步。

## 0. 前置

```
flutter pub get
flutter run -d macos          # 或 flutter build macos --release 后开 app
```

- 语言开关在**设置 → 语言**（`LocaleMode`：system / en / zh）。`system` 走 `Platform.localeName`，前缀 `zh` 判中文，否则英文（`main.dart` 的 `_resolveAppLocale`）。
- 走查主用**手动切到 zh**（不依赖系统语言，确定性更高），最后用 system 复验一次。

## A. 系统控件随 zh 本地化（ADR-0082 的主要用户可见收益）

旧自研 i18n 只翻 app 自己的文案，**系统控件恒英文**；gen-l10n 的 `localizationsDelegates`（含 `GlobalMaterialLocalizations` 等）把它们一并接上。切 zh 后逐项看：

- [ ] **文本选择右键菜单**：在 composer 或编辑器里选中一段文字 → 右键/长按 → 「复制/粘贴/全选/查找」应为中文。
- [ ] **输入框光标操作**：TextField 的「Select all / Copy / Paste」浮层菜单为中文。
- [ ] **日期/时间选择器**：企划的 Calendar 视图或任何 date picker（若有）——月份、星期、「取消/确定」为中文。
- [ ] **语义标签**（可选，需开 VoiceOver 或 Semantics 调试）：控件的 semantics label 为中文。

> 机器证不了：这些是 Flutter framework 自带的 `Global*Localizations`，本仓库无测试直接断言其内容。

## B. 所有 app 文案在 zh 下都是中文（无键名/无英文残留）

- [ ] 逐屏走一遍：**对话**（composer 占位符、发送/停止、审批卡、工具卡 IN/OUT、输入队列条、计划待审卡）、**工作台**（tab 栏、文件树、编辑器、终端、git 面板、diff、浏览器、右栏详情）、**企划**（vault 树、块编辑器、五种数据视图 Table/List/Gallery/Board/Calendar、All Content、对象信息、新建集合、模板、回收站、组件条）、**设置**（全屏各节 + 底部级联快捷菜单）、**侧栏**（会话分组节头/组头/右键、扩展区）。
- [ ] 特别看**是否有裸键名**渲染出来（如 `retryTitle` 这种 camelCase 直接显示）——那是 ARB 缺键、`trKey` 走了 `default` 回退。发现即记键名，回填 ARB。

> 已由测试证过：`test/hardcoded_copy_test.dart`（ADR-0080）扫 `lib/**` 零硬编码中文；`test/l10n_parity_test.dart` 断言 `trKey ≡ app_en.arb` 键集（动态键桥不缺键）。**人眼只需抓「键在 ARB 里但 zh 译文不对/漏译语境」这类机器看不出的**。

## C. overlay 路由不回退英文（ADR-0032 的老坑，flip 后结构性解决）

ADR-0032 曾因 locale 挂在 `home:` 之下、够不到 overlay 路由，导致菜单/对话框逐键回退英文。flip 后 locale 由 `MaterialApp` 的 `localizationsDelegates` 承载、**天然在 Navigator 之上**。zh 下逐个开：

- [ ] **五把下拉菜单**（模型选择、视图切换等）——条目全中文。
- [ ] **两棵右键菜单**（侧栏会话右键、文件树右键）——全中文。
- [ ] **对话框**（放弃点确认框、stuck-leave 确认、备份/恢复、更新检查）——标题与按钮全中文。
- [ ] **提示条/toast**（`ShadSonner` 的反馈条）——文案中文。

> 已由测试证过：`test/i18n_overlay_test.dart` 真开一次 PopupMenu 断言 zh `重试` 渲染（delegate 在 Navigator 之上够到菜单路由）+ 断言 `main.dart` 里 `AppLocaleScope(` 出现 0 次。**人眼复验真实那几把菜单/对话框无遗漏**。

## D. `untranslated.json` 为空（zh 无缺译）

- [ ] `cat lib/l10n/untranslated.json` 应为 `{}`。非空即 zh 缺键（运行时静默回退 en），按报告补 `app_zh.arb` 后重跑 `flutter gen-l10n`。

> **已由测试证过**：`test/l10n_parity_test.dart` 断言 `untranslated.json == {}`。此格 CI 已守，真机无需重复——列在此仅为完整。

## E. 四档字号下无裁字回归

flip 只换了取词机制、没动排版，但**中文比英文短/长不一**，某些容器在 zh + 大字号下可能新裁字。设置里把字号拉到最大档，复查：

- [ ] 侧栏行、工具卡头、状态条、按钮标签、tab 标题在 zh 最大档下不被 ellipsis 截断到读不懂（`disclosure_row`/`composer` 状态条/`diff_tab` 那三处历史溢出点重点看）。

> 已由测试证过：`test/disclosure_row_test.dart` 等把 flex 上界机制反向验死；放大文本各档有守卫。**人眼看 zh 特有长度**。

## F. `editor_tab` 的 Locale 注入（§4 实施偏离的专项复验）

flip 里 `editor_tab._tr` 改成**构造注入 `Locale`**（`workbench.dart` 传 `Localizations.localeOf(context)`），因为它的前三个 `_tr` 跑在 `initState` 同步栈、够不到 `dependOnInheritedWidgetOfExactType`。zh 下专项验：

- [ ] 打开一个**不存在的文件** tab（或删掉已打开文件再切回）——「此 tab 没有文件 / 无工作区 / 文件已不存在」那几句应为**中文**（这几句正是 initState 期同步取词的，是本次偏离的风险面）。
- [ ] 正常打开文件、编辑、折行、reveal 等编辑器动作的文案中文。

> 已由测试证过：`test/editor_tab_test.dart` 在 en 下验这几条路径（默认 `Locale('en')` 保确定性）。**zh 下的这三句需真机确认**（测试泵的是 en）。

## G. 种子名本地化（ADR-0074 + §6 实施偏离）

`planSeedNamesOf(AppLocalizations)` 保留为种子名桥（未内联进 `main`）。zh 下：

- [ ] **全新安装**（或触发 re-seed：`plan_space.json` 的 `seedVersion` 低于当前且指纹一致）时，企划演示种子的**集合名/视图名/关系名/选项名**（Delivery board、Reading inbox、Todo/Doing/Blocked…）应为中文。
- [ ] demo 记录的**正文**（17 条记录名）刻意保持英文——那是样本数据不是 UI 文案（ADR-0074 裁决），不应变中文。

> 已由测试证过：`plan_object_store` 的 i18n/换血守卫（ADR-0074）。**人眼确认 zh 首启的种子名 + 正文仍英文的边界**。

## H. 动态键路径（`trKey` 桥）渲染中文

`lib/model` 携带的动态键经 `trKey(l10n, key, params)` 取词。zh 下验这几处：

- [ ] **「多久以前」**（`RelativeTime.key` → 侧栏会话时间戳）：刚刚/几分钟前/几小时前/几天前 为中文。
- [ ] **快捷键标签**（`ShortcutDef.labelKey`）：设置或快捷键提示里的键名描述中文。
- [ ] **All Content 分组标签**（`planAllContentGroupLabelCode`）：企划 All Content 的分组头中文。

> 已由测试证过：`test/l10n_parity_test.dart` 的加速键值断言（`collapseSidebar(accel)`/`openSidebar(accel)` 在 zh 含加速键）+ `trKey ≡ ARB` 键集。**人眼确认这些动态键在真实界面上确实走中文**。

---

## 签收

| 段 | 结论（通过/问题） | 备注 |
| --- | --- | --- |
| A 系统控件 | | |
| B app 文案 | | |
| C overlay | | |
| D untranslated 空 | | CI 已守 |
| E 四档字号 | | |
| F editor_tab 注入 | | |
| G 种子名 | | |
| H 动态键 | | |

走查全绿后：ADR-0082 → RESOLVED（回填 flip commit），debt-register 同步，本单归档。
