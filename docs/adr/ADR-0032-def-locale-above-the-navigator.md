# ADR-0032: 语言要挂在覆盖层够得着的缝上

- **状态**: ACCEPTED
- **分类**: DEF
- **优先级**: P1
- **影响维度**: 生产功能 / 认知障碍
- **日期**: 2026-09-30
- **来源**: [ui-consistency-audit-2026-09-30.md](../ui-consistency-audit-2026-09-30.md) §U2（真机窗口截图 `bf783e32`）
- **修复 commit**: ad7b650（那道缝）· ff19b88（守卫）

## 背景（Context）

模型选择菜单里同屏出现两行：`载入服务端的模型列表`（中）与 **`Retry`**（英）。不是缺键——`lib/l10n/locales.dart:42` 是 `'retry': 'Retry'`、`:493` 是 `'retry': '重试'`，两侧都在；调用点也规矩地走了 `context.tr('retry')`（`lib/ui/conversation/composer.dart:1506`）。

病在**取键时用的是谁的 context**：

```
lib/main.dart:233   body: AppLocaleScope(   ← 挂在 home: 的 Scaffold 里
lib/l10n/locales.dart:928-939   AppLocaleScope.of(context) ?? 逐键回退 en
```

`PopupMenuButton` / `showMenu` / 对话框的条目活在 **overlay 路由**里，由 `Navigator` 之上的 Overlay 承载，**不是 `home:` 的子树**。于是 `AppLocaleScope.of` 在那条 context 分支上返回 null，`translate()` 按文档化的兜底走英文（`l10n_parity_test.dart` 甚至依赖"不挂 scope 即英文"来让 widget 测试不关心 i18n——兜底本身是对的，错的是**应用把自己的菜单也放进了兜底**）。

这条律本仓库已经学过一次：ADR-0017 的 `28f40df`/`e68893b` 量到"`MediaQuery` 写在 `home:` 里进不了 overlay 路由——此前所有'点开菜单再量'的面，量的都是没放大的菜单，并且报成通过"。同一道缝，上次漏的是字号，这次漏的是文案。**同一个错误在两个通道上发作，说明缺的不是那一次修补，是一条守卫。**

## 决策（Decision）

1. **`AppLocaleScope` 从 `home:` 挪进 `MaterialApp.builder`**，顺序变成 `MediaQuery(字号) → ShadTheme → AppLocaleScope → ShadSonner → child`。放在 `ShadSonner` 之外侧：提示条的文案也是文案，它同样要走用户的语言。
2. **全应用只留一枚 locale 座位**：守卫断言 `lib/main.dart` 里 `AppLocaleScope(` 出现次数为 1。两处座位就是两个"用户说的是哪种语言"的真值，与 ADR-0014/0022 那条"两个必须相等的字段就是一种新的错法"同族。
3. **守卫两条，各守一件事**（`test/i18n_overlay_test.dart`）：
   - **结构**：读 `lib/main.dart`，要求 `AppLocaleScope(` 的下标落在 `builder: (context, child) =>` 与 `home: Scaffold(` 之间。锚点用整段特征串而不是裸词 `builder:`——文件里 `itemBuilder:`、注释里的 "builder:" 都会先命中，那种守卫会为错误的理由通过或失败。
   - **机制**：真开一次 `PopupMenuButton`，断条目在 zh 下渲染 `重试`。它守的不是应用的接线（结构那条守），而是**结构规则所依赖的框架事实**：scope 在 Navigator 之上就真的进得了 overlay。没有它，结构断言只是一句对框架的猜测。
4. **明确不做**：不给 `context.tr` 加"读不到 scope 就抛"的硬失败（那会让所有不关心 i18n 的 widget 测试与 previews 全崩，兜底是 ADR-0008 定的）；不把 i18n 换成 `flutter_localizations`（workflow.md §2 已裁掉那条路）；不去逐点给菜单传语言参数（那是把一处真值拆成 N 处）。

## 后果（Consequences）

- **正面**：所有 overlay 表面（13 个菜单入口、两枚对话框、Sonner 提示条）第一次说用户选的语言；`Settings → 语言` 从此对菜单也生效——此前它只改**内容层**的文案，用户在菜单上仍会看到英文，属于"设置只管一半"。
- **负面/风险**：可见改动（中文界面里若干英文条目会翻过来），需真机走查确认没有条目反过来变英文；`AppLocaleScope` 挪位后，任何**依赖"菜单里读到英文"的既有测试**都会红——全量套件跑下来没有这类断言（`+936 → +938 -2`）。
- **中性**：`home:` 的注释里那句"scope 包住整个 body"不再成立，已随改动删掉，不留过期说明。

## 验证（Verification）

- **先红**：结构断言跑在未改的 `lib/main.dart`（HEAD）上 → `+1 -1`，失败输出 `Expected: be in range from 8228 to 9690  Actual: <10001>`（scope 在 `home:` 之后）；机制断言在同一棵树上**本来就绿**，正说明它守的是框架而不是接线，两者不能互相替代。
- **后绿**：2/2；`flutter test` `+936 → +938 -2`（净增 2 条即此文件），两条既有失败未触碰。
- `dart format --set-exit-if-changed lib test tool spike` → `0 changed`；`dart analyze --fatal-infos lib test tool spike` → `No issues found!`。
- 反向验：把 `AppLocaleScope` 挪回 `home:`（`git stash` 的方式跑在真接线上），结构断言立刻红并给出上面那对下标。
- macOS debug 已重建并重启（PID 64932）；**余用户走查**：中文档下把五把下拉与两棵右键菜单各开一遍，看是否还有英文残留。

## 关联（Links）

- 代码: `lib/main.dart`（`MaterialApp.builder` 那道缝）· `lib/l10n/locales.dart:920-939`（scope 与兜底）· `lib/ui/conversation/composer.dart:1506`（截图里那枚 `Retry`）
- 守卫: `test/i18n_overlay_test.dart`
- 关联 ADR: ADR-0017（同一道缝的第一次教训：`MediaQuery` 在 `home:` 进不了 overlay）· ADR-0008（双语键集对齐与"无 scope 即英文"的测试兜底）· ADR-0020（`ShadSonner` 也挂在这道缝上）· ADR-0014/0022（两处真值即错法）
