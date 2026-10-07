# ADR-0078: l10n 守卫补全——使用键必须入字典、占位符两侧对齐

- **状态**: ACCEPTED（本批落地）
- **分类**: TST
- **优先级**: P2
- **影响维度**: 生产功能 / 幻觉源
- **日期**: 2026-10-07
- **来源**: 用户指令（深入检查 i18n、补充中英文别落下、结合 lint 持续精进）+ i18n 全量审计（Dart 本体跑 `enStrings/zhStrings` 对 lib/** 全量 `.tr('…')` 扫描）
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

ADR-0008 立的 `l10n_parity_test` 只守**键集对齐**（en/zh 键集差集为空）。workflow §3「文案」条自己承认两件事没进守卫："守卫只管键不管值"，且"`{name}` 占位符名两侧是否一致也没进守卫（要加就再立 TST 类 ADR）"。本批审计把代价兑了出来：

- **使用键不在字典（真缺陷，已上线形态）**：`lib/ui/plan/blocks/plan_block_editor.dart:132` 用 `context.tr('planLinkPrompt')` 作链接对话框标题，而该键在两本字典里都不存在——`translate()` 的兜底链（zh→en→键本身，`locales.dart:1816-1818`）把字面量 **"planLinkPrompt"** 渲染给用户，中英文都中招。每次给文字加链接（工具栏高频动作）都会看到。键集对齐守卫管不到它：它不检查"代码用的键"这一侧。
- **占位符不对齐（未发现现行违例，但无守卫）**：`translate` 按 `{token}` 名替换——zh 侧丢一个占位符，用户看到字面量 `{name}` 残留在文案里；多一个是死参数。ADR-0008 只对 `openSidebar`/`collapseSidebar` 两键做过点名单断言。
- **审计方法的教训**：第一轮用正则解析 `locales.dart` 源码报了 `fontFamilyHint` 缺失——**假阳性**，该键的值用双引号书写（`"'' follows the theme's code font"`），正则只认单引号。守卫必须 import 字典本体（Dart 求值），不许用正则解析字典源码。
- zh=en 同文（9 键）为专名与格式串（Anthropic/Google/API key/yyyy-mm-dd 等），**不设守卫**——同文是否该翻译是人眼判断，一个会一次红九条的守卫只会逼人塞 `// ignore`（ADR-0017 追记的同款学费）。
- 企划 UI 裸字符串扫描：`lib/ui/plan/**` 与 sidebar 无硬编码文案（仅数据值插值）✓。

## 决策（Decision）

`l10n_parity_test` 增加两条守卫，加上原键集对齐共三道：

1. **使用键 ⊆ 字典**：文本扫描 `lib/**/*.dart` 的 `.tr('key')` 调用形状（与 `check_architecture.dart` 同款的文件系统扫描惯例），断言每个键 ∈ `enStrings`。文本扫描刻意不 import 调用方——覆盖的正是代码库实际使用的调用形状。
2. **占位符两侧对齐**：对全部键断言 en/zh 的 `{token}` 集合相等，取代 ADR-0008 的两键点名单断言（那两键的值级断言保留——快捷键可见性仍值得逐字校验）。
3. **不做**：zh 值是否真的翻译了（人眼事，守卫只管键与占位符）；`.tr` 动态键名（`tr(someVar)`）扫不到——代码库里没有这种用法，出现时是新的调用形状，先立 ADR。

## 后果（Consequences）

- **正面**：拼错/漏配的键在 CI 上红，而不是用户在对话框标题上读到驼峰键名；占位符漂移（zh 侧改写时丢 `{name}`）在 CI 上红。
- **负面/风险**：文本扫描对 `.tr` 调用形状敏感（换行/双引号键名会漏——现状代码库无此形状）；新增键的成本不变，删键时若有残留调用会红（这正是想要的）。
- **中性**：ADR-0008 的地位不变（键集对齐仍是第一道），本 ADR 是它的第三、四道。

## 验证（Verification）

`flutter test test/l10n_parity_test.dart` 4 棵全绿（键集/使用键/占位符/加速键值级）。本批同时修复审计抓出的唯一违例（`planLinkPrompt` 入双语字典）。

## 关联（Links）

- 代码: `test/l10n_parity_test.dart`、`lib/l10n/locales.dart:1816-1818`（兜底链）、`lib/ui/plan/blocks/plan_block_editor.dart:132`（事发点）
- 关联 ADR: ADR-0008（键集对齐——第一道）、ADR-0033（hint 不编绝对路径——fontFamilyHint 文案的依据）
