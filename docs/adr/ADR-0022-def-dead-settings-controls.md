# ADR-0022: 设置页不许出现运行时不读的控件

- **状态**: ACCEPTED
- **分类**: DEF（承诺与行为分叉；商用产品的设置页不能有假开关）
- **优先级**: P1（用户按了没反应，且没有任何地方说明没反应——真实使用里就是"设置坏了"）
- **影响维度**: 生产功能 / 可信度
- **日期**: 2026-09-30
- **来源**: 「每个功能都要验证」的设置页逐字段普查；ADR-0005 S4 遗留的"仅持久化未接线"那三项
- **修复 commit**: 79de208（四行 + 字段 + 枚举 + 双字典键）· 24059ee（守卫）

## 背景（Context）

`AppSettings` 的每一个字段都在设置页有一行，但"有一行"不等于"有人读"。普查方法就是按字段名 grep 全 `lib/`，再排除它自己的定义文件与唯一写它的设置页：

```
for f in <AppSettings 的 15 个字段>; do
  grep -rn "\.$f\b" lib --include='*.dart' \
    | grep -v lib/model/app_settings.dart | grep -v lib/ui/settings/model_settings.dart
done

model 22 · workspaceRoot 59 · locale 6 · conversationWidth 3 · theme 2 ·
workspaceBookmark 2 · mcpServers 2 · fontSize 2 · recentWorkspaces 1 ·
skillsRoot 1 · expandToolCalls 4
fontFamily 0 · interfaceStyle 0 · previewMode 0 · promptSuggestions 0
```

四条是死的，而设置页把它们的选项摆得和活的完全一样（`model_settings.dart:742/778/792/818`）：

| 行 | 用户看到的承诺 | 盘上发生了什么 |
| --- | --- | --- |
| Text font：Sans serif / Serif | 正文换字体 | 只有 `settings.json` 里多一个键；`DswType` 的字体永远来自 `dswFontFamily` 常量（`dsw_typography.dart:60`） |
| Interface style：Standard / Glass / Classic / Parchment | 换一整套界面配色 | `DswAlias` 只有两套（亮/暗），另三套**不存在** |
| Preview mode：New window / Side panel / Inline | 生成的文件在何处打开 | 没有任何代码因为一次 `write`/`edit` 去开 tab；这行描述的机制根本没有 |
| Prompt suggestions（开关） | 智能体给出后续提示 | 运行时从不读它，因此开与关同一条链路 |

三条必须记住的旁证，避免下次把它们当成"顺带能修的"：

1. **同名的代码字体行是活的**。`model_settings.dart:1124` 那个 "Font family" 文本框写的是 `workbenchPrefs.terminalFontFamily`，被 `terminal_tab.dart:66` 真读。死的是 `_SettingCellRow<AppFontFamily>` 那一行。两行文案相近，普查时极易混成一件事。
2. **`fontSize` 与 `conversationWidth` 已由 ADR-0017 S3 / §3-C 接线**（字号档乘进根 `MediaQuery.textScaler`；宽度档进中列约束），所以这不是"设置页整体没接"的旧账，而是**四条具体承诺**没接。
3. **`interfaceStyle` 只在 zh 文案里承认了做不到**（`locales.dart:858`「目前仅"标准"有完整配色，其余会保存待未来的配色方案」），en 侧（`:422`）和其余三行都在假装可用。**"分叉"如果只在一边承认，就等于没承认**——这与 ADR-0008 守的是同一件事的两面：键对齐是机器可验的，**承诺与行为对齐不是**，所以只能靠这种普查与守卫。

ADR-0005 当时把这三项记成"仅持久化未接线"的待办，本 ADR 是它的处置：不是"以后接"，而是**现在停止承诺**。

## 决策（Decision）

1. **四条全部撤下**，而不是补实现。每条都要新增一个真实机制（serif 字体族名在三平台各自叫什么、另外三套配色要过 ADR-0004 的对比度门禁、"生成文件在哪打开"要先有"生成文件自动打开"这条产品行为、后续提示要一次额外模型调用），四个都不在"把已有 UI 与已有功能对齐"的范围内。ponytail 的顺序在这里就是删除优先于新增：**一枚说谎的开关比没有开关更坏**，因为它把用户对产品的信任花在了一次不会发生的改变上。
2. **连字段一起删，不只隐藏行**。留着 `AppSettings.previewMode` 而删掉它的行，就是留一份"必须有人写它却没人读它"的真值——正是 ADR-0014 那条"两个必须相等的字段就是一种新的错法"的同一形状。删的范围：3 个枚举（`AppFontFamily`/`AppInterfaceStyle`/`AppPreviewMode`）、4 个字段（含 `promptSuggestions` 这个 bool）及其 `fromJson`/`toJson`/`copyWith`/`==`/`hashCode`、设置页的 4 行与对应 `late` 变量、`locales.dart` 两侧的同名键（en/zh 同时删，`l10n_parity_test` 会验键集仍对齐）。
3. **旧偏好文件不用迁移**：`fromJson` 只读它认识的键，多出来的 `interfaceStyle` 等会被自然忽略；`toJson` 只在值非默认时写键，删掉后也不再写。这是**读侧宽容、写侧收敛**，不需要版本号。
4. **立一条守卫**：`test/settings_reach_test.dart` 从 `lib/model/app_settings.dart` 的源码解析出 `AppSettings` 的全部字段名，逐个要求在 `lib/` 里存在**除定义文件与设置页之外**的读取点。这条守卫守的是"以后别再长出第五枚假开关"，而不是本次这四条——本次四条已经不在树里，守卫对它们是空过。

明确不做：① 不实现 serif/glass/preview/follow-ups 中任何一条（要做按 §7 另立 ADR，且各自的门禁不同：配色要过 `contrast_check`，后续提示要带 key 真跑）；② 不动 `terminalFontFamily`（活的）与 `AppFontSize`/`AppConversationWidth`（活的）；③ 不给死行加"暂不生效"的说明文案——那正是本 ADR 要消除的状态，一行自我辩解的 description 仍是一枚假开关。

## 后果（Consequences）

- **正面**：设置页每一行都对应一个能被观察到的行为；`grep` 出来的"两处真值"少了一种；用户不再能选出一个什么都不会发生的界面风格。
- **负面/风险**：这是**减少用户可见功能**的一次改动。若用户其实想要 serif 正文或四套配色，本 ADR 删掉的是入口而不是可能性——所以四条能力连同"要接哪些线"写在这里和登记表里，重新实现时按本 ADR 反查即可。已保存过这些选择的机器上，那个选择会静默失效（回到默认），因为没人再读它。
- **中性**：`AppSettings` 从 15 个字段降到 11 个；设置页 Appearance 卡片少 3 行、Behaviour 少 1 个开关。守卫是**源码扫描**，它判"有没有读取点"，不判"读取点是否真的作用到用户看得见的那一处"——`themeMode` 若被读了但没挂进 `MaterialApp`，这条守卫仍会绿。那类缺口仍只能靠走查。

## 验证（Verification）

- **守卫先红后绿**（这是它的反向验证，不是补测）：`test/settings_reach_test.dart` 挂在**删除之前**的树上跑，当场点名四条——
  `Actual: ['fontFamily', 'interfaceStyle', 'previewMode', 'promptSuggestions']`，理由句直接引用本 ADR。删掉之后同一文件绿，说明它既不是空的也不是靠 `expect(fields.length > 8)` 蒙过去的。
- `flutter test` 由 `+909 -2` 到 **`+910 -2`**（净增就是这条守卫），那 2 个失败仍是 `app_scope_test` 的 `/var`↔`/private/var` 与 `plan_workspace_test` 的 `find.text('notes')`，未被触碰。设置页那侧的既有断言全部原样通过：`settings_test.dart` 的 34 条（含"appearance section commits width and tool-call toggles"与两档放大文本那三面）里没有任何一条按文案去找被删掉的四行，所以**这次删除没有替套件"顺手改断言"**。
- 只改了测试里两处**字段级**引用（round-trip 那格从 `fontFamily` 换成还活着的 `fontSize`；"未触碰的偏好保持默认"那句从 `previewMode` 换成 `locale`），不是为了让套件变绿而改口径。
- 门禁同口径：`dart format --set-exit-if-changed lib test tool spike`（205 files, 0 changed）、`dart analyze --fatal-infos lib test tool spike`（No issues found!）、`dart tool/check_architecture.dart`（`architecture OK: 7 recorded, 0 new (126 files, 7 rules)`）。
- 落地面：`lib/model/app_settings.dart` −104 行、`lib/ui/settings/model_settings.dart` −60 行、`lib/l10n/locales.dart` −36 行（两侧各 18 键），`AppSettings` 字段 15 → 11。
- 守卫普查的复跑命令写在"背景"里，任何人可以对着改前/改后的 `lib/` 重算一次。
- **待 macOS 真机走查**：Appearance 卡片去掉三行后的排版是否仍读得住（`settings_test.dart` 里那把打开着的主题菜单与七个分区的放大文本守卫会跟着改，但"少三行之后这一屏看起来空不空"是眼睛的活）。

## 关联（Links）

- 依据: ADR-0005 S4（"仅持久化未接线"那三项的原始登记）· ADR-0006（设置页与快捷菜单两处真值必须同接）· ADR-0008（键对齐可测，承诺对齐不可测）· ADR-0014（两个必须相等的字段就是一种新的错法）
- 关联 ADR: ADR-0017 S3（`fontSize` 那条**活着的**接线长什么样，可当实现范本）· ADR-0020/0021（同一批普查里的另两条"只用一套"律）
- 代码: `lib/model/app_settings.dart` · `lib/ui/settings/model_settings.dart`（Appearance/Behaviour 两卡）· `lib/l10n/locales.dart`（两侧同名键）· 守卫 `test/settings_reach_test.dart`
