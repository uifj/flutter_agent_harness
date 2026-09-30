# ADR-0033: 字段提示是用户能照着做事实的声明

- **状态**: ACCEPTED
- **分类**: DEF
- **优先级**: P1
- **影响维度**: 认知障碍 / 生产功能
- **日期**: 2026-09-30
- **来源**: [ui-consistency-audit-2026-09-30.md](../ui-consistency-audit-2026-09-30.md) §U5（真机窗口截图 `e68d068b`）
- **修复 commit**: b5e8d7d（接线、两枚提示与三条守卫同批）

## 背景（Context）

设置页 · 扩展 那一屏，同一段里出现了两个互相矛盾的目录：

- 描述（两侧字典都写了）：`…为空表示 <应用程序支持目录>/skills。`（`lib/l10n/locales.dart:808`，en 在 `:392`）
- 字段提示：`hint: '/Users/you/.dsh/skills'`（`lib/ui/settings/model_settings.dart:1169`）

`.dsh` 是**被参考的另一个产品**的名字（本仓库多处注释引用 dsh 的设计，但运行时数据不落在 `.dsh`）；`/Users/you` 也不存在。用户按提示去建目录，会建到一个本应用永远不看的地方；而它上方那句话刚刚说了正确的目录。**同一屏两处真值，其中一处是假的**——这正是 ADR-0022 那条"一条自我辩解的文案仍是一枚假开关"的姊妹形态：提示不是装饰，是用户可以照着敲进去的东西。

同一文件的 `:1038` 还有 `hint: '/Users/you/project'`（工作区字段），同一种病。

运行时其实**早就知道**真路径：`lib/state/app_providers.dart:53` 有 `supportDirectory` provider（默认体 `throw UnimplementedError`，由 `main` override），`AppScope` 也持有它（`:86`）。只是设置页从没去读——架构规则 5 禁止 widget 直接 watch provider，所以路径要由 `main.dart` 递进去，那里已经在递 `approvals`、`workbenchPrefs` 这些同类的东西。

## 决策（Decision）

1. **`SettingsPanel` 多一个必填参数 `supportPath`**，由 `main.dart` 用 `ref.watch(supportDirectoryProvider).path` 传入（读 provider 的动作留在装配根，widget 树不碰 riverpod）。技能字段提示改成 `'${widget.supportPath}/skills'`——提示与它上方的描述现在**同源**，不可能再互相打脸。
2. **工作区字段提示改成 `~/projects/my-app`**：那是一个"长这样"的例子，不是一个可去创建的绝对路径；`~` 不会被本应用解析，所以它不构成事实声明。
3. **守卫三条**（两条在 `test/settings_reach_test.dart` 的新 `a hint is a fact the user can act on` 一节，一条行为断言在 `test/settings_test.dart`）：
   - `lib/ui` 里任何**非注释行**出现 `.dsh` 即红，并指名 `文件: 行号`；
   - `lib/ui` 里任何 `hint: '/…'`（以斜杠开头的字面量提示）即红——一个绝对路径提示就是"请照这个建"；
   - 真开一次设置页、进到 扩展 一节，断言技能字段的提示**等于传进来的 supportPath + `/skills`**，并断言屏上不含 `.dsh`。前两条是结构，第三条证明值真的渲染到了屏幕（ADR-0028/0029 学到的同一条：写了不等于挂上了）。

## 后果（Consequences）

- **正面**：设置页不再有"提示与描述各说一套"的字段；新增字段若想写死一个绝对路径，会被扫描当场拦下；`SettingsPanel` 的必填参数让"没有真路径可显示"变成编译错误而不是又一篇作文。
- **负面/风险**：三个测试宿主（`settings_test` 一处 `pump` 助手、`models_endpoint_test` 两处）要跟着传 `supportPath`；提示文字变长（真实路径比 `/Users/you/.dsh/skills` 长），在窄窗下会更早触发省略号——`_Field` 的提示本就有 ellipsis 处理，且 700px 那棵放大文本守卫原样通过。
- **中性**：`.dsh` 在**注释**里仍然大量存在（那是设计来源的说明，不是用户可见文案），守卫刻意只拦非注释行；不做全局禁字，那是把参考历史一起抹掉。

## 验证（Verification）

- **反向验**：把两处 hint 原样种回缺陷值（其余接线不动），三条守卫立刻红并给出证据——`Expected: empty  Actual: ['lib/ui/settings/model_settings.dart: 1178']`、第二条整份列出行号、行为那条 `Found 0 widgets with text "/var/app-support/skills"`；恢复后 `test/settings_reach_test.dart` + `test/settings_test.dart` 共 30 条全绿。
- 门禁四条：`dart format --set-exit-if-changed lib test tool spike`、`dart analyze --fatal-infos lib test tool spike`、`flutter test`（基线 `+938 -2` → 见登记表行）、`dart tool/check_architecture.dart`。
- `dart tool/check_architecture.dart` → `architecture OK: 7 recorded, 0 new`。
- macOS debug 已重建并重启（PID 66313）。**这条是可见改动**（两枚字段的提示文字变了），真机走查与 U6/U7 一并看。

## 关联（Links）

- 代码: `lib/ui/settings/model_settings.dart`（`supportPath` + 两枚 hint）· `lib/main.dart`（装配根读 provider 递进去）· `lib/state/app_providers.dart:53`（`supportDirectory`）
- 守卫: `test/settings_reach_test.dart` 的 `a hint is a fact the user can act on` · `test/settings_test.dart` 的 `the skills hint is the directory this app actually uses`
- 关联 ADR: ADR-0022（文案不许替缺陷辩护；设置页三处接完还要有读取点）· ADR-0008（双语键集，本条的两侧描述本来就对齐，错的是提示）· ADR-0028/0029（"写了不等于挂上了"的守卫形状）
