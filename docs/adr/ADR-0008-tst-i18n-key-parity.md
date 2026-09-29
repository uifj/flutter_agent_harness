# ADR-0008: i18n 双语键集对齐加机器守卫

- **状态**: RESOLVED（同日提案并落地：本文件与守卫测试同一批提交，登记表行带 commit hash）
- **分类**: TST
- **优先级**: P2
- **影响维度**: 评估阻断（缺口无法被 CI 发现）· 幻觉源（注释声称的"测试期对照"并不存在）
- **日期**: 2026-09-29
- **来源**: 用户决策（本会话配置校准时确认"双语对齐无守卫"要补，并按纪律先立 TST 类 ADR）
- **修复 commit**: 与本文件同批的 `test(l10n)` 提交（hash 记在 `docs/debt-register.md` 的 ADR-0008 行）

## 背景（Context）

`lib/l10n/locales.dart` 的头部注释（`:5-8`）声称契约之一是 "en is checked against it at test time"，但仓库里**没有任何测试引用这两个字典**：

```
grep -rn "enStrings\|zhStrings" test/     # 无输出（本 ADR 立项时）
```

两份字典是 `const` 顶层字面量（`locales.dart:33` `enStrings`、`:467` `zhStrings`），取值走 `translate()`（`:871`）：`zhStrings[key] ?? enStrings[key] ?? key`。因此漏加 zh 键的后果是**静默回退到英文**——UI 里混进一句英文而不是报错，运行时日志无痕；而漏加 en 键则两边都缺，把键本身渲染出来（可见但同样无门禁）。

规则文档（`.qoder/rules/workflow.md` §3 文案条）已经把这一点写成"已存在的缺口，别假设它会被 `flutter test` 拦下"，即**当前唯一的守卫是人眼**。加一条新键需要同时改两处，正是代理与人都最容易漏的操作。

## 决策（Decision）

新增 `test/l10n_parity_test.dart`，**只断言键集相等**（两个方向的差集各列出来，失败信息直接给出缺失键名）：

- 不写死键数——条数随加键漂移，是一条会腐烂的断言；"两边键集相同"才是不变量。这一点与 §3 文案条的既有约定一致。
- 不引入 `intl` / `.arb` / codegen，不改 `translate()` 的三级回退语义（zh → en → key）。回退到 en 与"渲染出键名"两种降级行为仍是被 widget 测试依赖的现状（无 `AppLocaleScope` 即英文），本 ADR 只补门禁、不动契约。
- 不检查"中文值是否真的翻译过"（值与键相同、或 zh 值等于 en 值，都可能是合法翻译结果，机器判不了；那仍是人眼的事）。

候选方案是"把 en 字典当源、生成 zh 骨架 + 待译清单"，被否：它需要新工具链与新的入库产物，而缺口本身只需要一条断言就能拦住。

## 后果（Consequences）

- **正面**: 漏加任一侧的键由 `flutter test`（以及 `.github/workflows/pr-check.yml` 的 `flutter test` 步骤）当场拦下；`locales.dart` 头部那句"checked at test time"从虚假声明变成事实。
- **负面/风险**: 无。新增文件不参与运行时，纯测试期成本。将来若引入 `.arb` 路线，本测试与那条路线冲突时需一并替换（属 ADR-0002 级别决策）。
- **中性**: 登记表里"i18n 双语对齐无守卫"这一观察行转为已闭环条目。

## 验证（Verification）

```
flutter test test/l10n_parity_test.dart     # 通过
flutter test                                 # 全套仍绿
```

反向验证（确认它真的会拦）：临时从 `zhStrings` 删任一键，该测试须失败并指名缺失键。

## 关联（Links）

- 代码: `lib/l10n/locales.dart#L5-L8`（契约声明）、`#L33`、`#L467`、`#L871-L886`（`translate()` 三级回退）
- 测试: `test/l10n_parity_test.dart`
- 关联 ADR: ADR-0002（同属 develop 改造线的测试面补齐）
- 规则: `.qoder/rules/workflow.md` §3「文案」条、§4「测试约定」
