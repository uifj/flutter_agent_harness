# ADR-0080: 硬编码用户可见中文的零容忍守卫

- **状态**: ACCEPTED（本批落地）
- **分类**: TST
- **优先级**: P2
- **影响维度**: 生产功能
- **日期**: 2026-10-07
- **来源**: hunnu-app-osos 评估 §1.2（check_hardcoded_strings.sh 的方法论——基线看护 + self-test + 盲区自述）+ 用户指令（深入检查 i18n、结合 lint 持续精进）
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

ADR-0078 的两条守卫管「**代码用的键**必须入字典」与「**占位符**两侧对齐」，但管不到第三件事：
**文案压根没进字典**——`Text('确定')` 这种硬编码绕过 `context.tr` 整条链，键集对齐看不见它（它没有键）。
hunnu 的 `tool/check_hardcoded_strings.sh` 证明此事有方法论：扫描器 + **基线只降不升** + `--ci` 门禁 +
`--self-test` 防扫描器静默失效 + **头部自述已知盲区**（"PATTERN 只认同行 UI 关键字后紧跟引号的形态，
ADR-0052 的 27 处里只有 19 处落在计数内"）——对自家守卫局限的诚实，与企划星 `tap_affordance_test`
按文件计数的自律同源。

**实测（本批）**：`lib/` 全量 333 个 Dart 文件按 hunnu 同族 PATTERN（Text/label/tooltip/hint/title/
description/message 七个 UI 关键字后紧跟字符串字面量且含 CJK）扫描，**违规数为 0**——企划星
比 hunnu 干净（它的基线还有 74），所以守卫直接落**零容忍**：新增一例即红，不需要递减基线的
历史包袱。零容忍还有一个附带好处：没有"这个基线数字该不该降"的谈判空间，守卫只认一个真值。

## 决策（Decision）

1. **新守卫 `test/hardcoded_copy_test.dart`**（沿 `l10n_parity_test` 的扫描惯例，跑在 `flutter test` 里）：
   文本扫描 `lib/**/*.dart`，PATTERN = 七个 UI 关键字（Text/label/tooltip/hint/title/description/
   message）后跟**同一行**字符串字面量且含 CJK（`[\u4e00-\u9fff]`），跳过注释行。任何命中 → 测试红，
   报文件:行号与片段。零容忍：没有基线文件、没有豁免表。
2. **盲区自述（守卫自己的注释，学 hunnu 的诚实）**：PATTERN 只认「同一行 UI 关键字后紧跟引号」形态——
   `Text(` 与字面量分行、自定义封装函数（`_sectionHeader('中文')`）、`{...}` 插值里的中文、`tr()` 动态键
   都扫不到。出现新形态时**先扩 PATTERN 再动手**，扩 PATTERN 本身若引发存量爆红，先立 ADR 处置存量再上守卫。
3. **不扫**：`test/`（测试断言的中文是断言不是产品文案）、`packages/`（board_panel 不受本仓 lint 门禁，
   build.md §0）、mock 种子中文（`lib/model/plan_mock_content.dart` 的演示数据——ADR-0074 裁决过：
   样例数据不是 UI 文案；且它是 dict 值不落 PATTERN 形态，若某天改写成 UI 构造再议）。

## 后果（Consequences）

- **正面**：硬编码文案在 CI 红，而不是 zh 界面里混一行未走字典的死文案；零容忍省掉基线维护的谈判成本。
- **负面/风险**：PATTERN 形态敏感（新增"Text(\n '中文'...)"写法即漏）；七个关键字表若不覆盖新控件
  （如 shadcn 的 `text:` 命名参数）会漏——**漏是盲区，不是误杀**，方向性安全（宁可漏杀不误杀）。
- **中性**：与 ADR-0078 的两条守卫合成"文案→键→字典"的三连环：硬编码零容忍（本 ADR）→ 使用键必须
  入字典（0078 ①）→ 键集与占位符对齐（0008 + 0078 ②）。

## 验证（Verification）

`flutter test test/hardcoded_copy_test.dart` 绿（当前零违规）。真机回归面：新增任意含中文字面量的
UI 代码 → 红。四道门禁同口径。

## 关联（Links）

- 代码: `test/hardcoded_copy_test.dart`、`test/l10n_parity_test.dart`（扫描惯例同源）
- 关联 ADR: ADR-0008（键集对齐）、ADR-0078（使用键⊆字典 + 占位符）、ADR-0074（mock 种子中文的裁决）
- 上游研究: `docs/hunnu-app-osos-vs-planstar-2026-10.md` §1.2（hunnu `tool/check_hardcoded_strings.sh`）
