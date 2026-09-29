# ADR-0011: 架构不变量做成可执行门禁（ratchet baseline）

- **状态**: RESOLVED
- **分类**: TST
- **优先级**: P2
- **影响维度**: 认知障碍 / 评估阻断（规则靠人跑 = 规则会腐烂）
- **日期**: 2026-09-29
- **修复 commit**: f74417b
- **来源**: `docs/zcode-vs-agent-harness-2026-09.md` §6「架构规则即代码」与 §7 A6（评估结论：本次移植里性价比最高的工程项）

## 背景（Context）

本仓库的硬不变量只存在于文档里，验证手段是"有人去跑 grep"：

- `AGENTS.md` §3 给的是三条 grep 命令；`.qoder/rules/workflow.md` §0 把同样的三条列成表，并注明"应无输出，注释文字除外"。
- "注释文字除外"这句话本身就是机器不可执行的信号：实测 `grep -rln "package:genkit" lib/ | grep -v "^lib/genkit/"` 返回 4 个文件（`lib/model/turn_event.dart`、`conversation.dart`、`workbench.dart`、`workspace.dart`），全部是注释里提到 `package:genkit`，不是 import。人得自己判断哪条算违规。
- 后果：CI（`.github/workflows/pr-check.yml`）跑 format / analyze / test 三件事，**架构规则不在其中**。一个把 `package:genkit` 带进 `lib/ui/` 的 PR 可以全绿合入。

ZCode 那条经验里值得搬的不是它的 15 模块 `requires` 图（本仓库 116 个 lib 文件用不上），而是三件事：**规则即命令**、**指纹 baseline**、**只拦新增**。

## 决策（Decision）

新增 `tool/check_architecture.dart`（约 230 行，只用 `dart:io` + `dart:convert`，零新依赖）与 `tool/architecture_baseline.json`（入库）。

五条规则，前三条就是文档里的三条不变量，后两条是把文档里"说过但没人查"的约定也纳入：

| 规则 | 依据 | 今日违规 |
| --- | --- | --- |
| `genkit-stays-in-lib-genkit` | 不变量 1 | 0（只匹配 `^import 'package:genkit`，注释不再算） |
| `model-stays-framework-free` | 不变量 2 | 0 |
| `state-does-not-import-ui` | 不变量 3；`layout_controller.dart` 按名字放行并写明原因 | 0 |
| `ui-owns-no-direct-io` | `docs/zcode-vs-agent-harness-2026-09.md` §6「外部 I/O 收口」 | 7（已入 baseline） |
| `riverpod-stays-in-the-assembly-root` | ADR-0002：riverpod import 仅限 `main.dart` + `state/app_providers.dart` | 0 |

关键取舍：

- **指纹 = 规则 + 文件 + 命中行文本，不含行号。** 用 sha256 摘要（ZCode 的做法）在本仓库规模上是多余的：指纹本来就一行长，直接存字符串更好读、diff 更好看。挪动 import 不算修复，改文本才算。
- **baseline 记录今日实况，只有新增才失败。** 第 4 条若不这么做，第一天就有 7 条红灯，门禁会被整体忽略。
- **400 行上限只告警不阻断**，并且不参与退出码：本仓库 26 个文件已过线。评估文档对 ZCode 自己的数字（15 模块里只有 1 个 managed、最大文件 6363 行）的结论就是——规模规则当阻断器会立刻变成谎言。
- **`flutter test` 顺带跑架构检查**（`test/architecture_check_test.dart` 调 `checkRepo()`），所以 **不改 `.github/workflows/`**：pr-check 已经包含 `flutter test`，加 CI 步骤是第二份真值。
- 生成的 `*.g.dart` 不参与扫描（那是 build_runner 写的，不是人选择的 import）。
- `--update` 用与 `settings_store` 同样的 tmp + rename 落盘。

## 后果（Consequences）

- **正面**：三条不变量从"文档里的一句话"变成一条命令 + CI 里的一次测试；两条软约定第一次有了牙齿；新增违规的报错自带规则依据。
- **负面/风险**：规则靠正则匹配 import 行，绕过写法（`// ignore` 后再加、或 `export` 转发）不在覆盖面内；`lib/ui/**` 的 7 条 `dart:io` 债被 baseline 冻结——**baseline 不是豁免**，`--update` 只在债务减少时该跑（脚本在债务消失时打印"baseline can shrink"提示）。
- **中性**：`tool/` 从 1 个脚本变 2 个，且第一次被 `test/` import（相对路径，因为 `package:` URI 只解析到 `lib/`）。

## 验证（Verification）

```
dart tool/check_architecture.dart              # 架构 OK：7 recorded, 0 new
dart tool/check_architecture.dart --verbose     # 逐条列出 recorded 指纹
flutter test test/architecture_check_test.dart  # 6 例：ratchet 算术 3 + 实况 3
```

反向验证实测过：临时写 `lib/model/probe_tmp.dart` 内容 `import 'package:flutter/foundation.dart';` → 命令打印 `NEW VIOLATION model-stays-framework-free` 且退出码 1；删掉该文件 → 退出码 0。

## 关联（Links）

- 代码: `tool/check_architecture.dart`、`tool/architecture_baseline.json`、`test/architecture_check_test.dart`
- 文档: `AGENTS.md` §3、`.qoder/rules/workflow.md` §0 / §4
- 来源评估: `docs/zcode-vs-agent-harness-2026-09.md` §6「架构规则即代码」、§7 A6
- 关联 ADR: ADR-0002（riverpod 收口规则的依据）、ADR-0008（同一类"给文档规则加机器守卫"的先例）
