# 不变量与架构门禁（完整表述）

> 皇冠内容：这四行 grep + 七条规则是本仓库分层的地基，逐字对齐 `AGENTS.md` §3 与 `.qoder/rules/workflow.md` §0。

## 四条 grep（应无输出，注释文字除外）

```
grep -rn "package:genkit" lib/ | grep -v "^lib/genkit/"   # 必须为空（注释文字除外）
grep -rln "package:flutter" lib/model/                    # 必须为空
grep -rn "\.\./ui/" lib/state/                            # 只有 layout_controller 一条已知例外
grep -rn "package:flutter\|\.\./state/" lib/genkit/       # 必须为空：运行时不许碰 Flutter，也不许伸进 lib/state（ADR-0015）
```

- Genkit 变更只应砸 `lib/genkit/` 两个文件，而不是穿过整棵 widget 树。
- `lib/model/` 是运行时与 UI 之间的唯一词汇表。
- 第四条（ADR-0015）保证 `dart run spike/runtime_smoke.dart` 还能编译：那条链曾经 `state/fs_revision.dart`（一个 `ValueNotifier`）摸到 `dart:ui`，把工具改动的验收门静默弄断过。

## 已登记例外（别"顺手清理"）

- **第一条的人工放行例外**：`test/restore_projection_test.dart` 是全仓唯一在 `lib/genkit/` 之外 import `package:genkit` 的测试文件（它要构造持久化形状）。刻意，别清。
- **第三条的唯一已知例外**：`lib/state/layout_controller.dart` import `ui/layout/columns.dart`（列宽求解要读约束表达式）。要新增例外，先立 ADR。

## `dart tool/check_architecture.dart`（可执行门禁，ADR-0011）

这四行 grep 现在由一条命令代替，共**七条规则**（三条不变量 + 运行时不碰 Flutter/state + `lib/ui` 不直接 `dart:io` + riverpod 只在 `main.dart`/`app_providers.dart` + 反馈条只有一个入口）：

- 按**指纹 baseline + 只拦新增**运作——`tool/architecture_baseline.json` 是**今日实况，不是豁免清单**。
- 2026-10-01 实况：7 条全部是 `lib/ui` 直接 `dart:io`；新 clone 后跑 `dart tool/check_architecture.dart` 应得 **"7 recorded, 0 new"**。
- 债务修掉了要 `dart tool/check_architecture.dart --update` 把 baseline 缩小（只在债务减少时跑）。
- `test/architecture_check_test.dart` 调同一段代码，所以 `flutter test`（= CI）已经在跑它——**不必往 `.github/workflows/` 里加步骤**。

## 主题时序/形状的姊妹律（同族"一个数字出现在两处就是两份真值"）

这些不是 `check_architecture` 规则，由各自的源码扫描测试拦，改相关面前必跑：

- `lib/ui` 里出现 `waitDuration` 即红（`DswMotion.tooltipDelay` 是唯一真值，ADR-0023，守卫 `tooltip_timing_test.dart`）。
- `lib/ui` 里 `Radius.circular(` 后面不是 `DswShape.` 即红（ADR-0017/0029，守卫 `theme_token_test.dart`）。
- 每枚 `DswShape` 常量都要有读者（ADR-0025）；字形尺寸必须在五档阶梯上（ADR-0026）；样式名不许对它渲染的字号撒谎（ADR-0027）。
- `lib/ui` 不许留 Material 菜单 / 手写 `MouseRegion + GestureDetector`（ADR-0036 B6 / ADR-0021，守卫 `shad_menu_adoption_test.dart`·`tap_affordance_test.dart` 按文件计数——**扫描对象为空也会绿，所以必须反向证一次它看得见东西**）。

完整清单见 testing 技能的 `references/guards.md`。
