---
name: architecture
description: Enforce PlanStar's layering and code guidelines for implementation, refactoring, and review. Use when implementing features, adding agent tools or workbench tabs, designing APIs, crossing a genkit/model/state/ui/theme/host/l10n boundary, handling persistence, or making architecture decisions. Apply alongside the testing skill; load design-first for non-trivial shape.
---

把这些约束应用到本次改动新增或修改的所有代码。既有代码可能不遵循——**未被要求别顺手重构它**（ponytail）。

只用 `AGENTS.md` 里指定版本（Dart ^3.11.5 / Flutter 3.41.9 / genkit 0.16.1）可用的语言特性。非平凡工作——新特性、新工具、跨层改动——先载 **design-first** 定形状，再写代码；写测试时同时载 **testing**。

## 分层与不变量（皇冠）

本仓库的分层不是建议，是**可执行门禁**。动手前先确认没踩：

- **`lib/model/` 是运行时与 UI 之间的唯一词汇表**——纯 Dart，不 import `package:flutter`。
- **`lib/genkit/` 既不碰 Flutter 也不伸进 `lib/state/`**（ADR-0015）——它保证 `dart run spike/runtime_smoke.dart` 还能编译。需要给 runtime 用的跨层共享状态，把纯 Dart 形状放进 `lib/model/`，别去 import state。
- **`lib/state/` 不反向依赖 `lib/ui/`**——唯一已知例外 `layout_controller.dart`（读约束表达式）。
- **`lib/ui/` 不直接 `dart:io`**——宿主操作走 `lib/host/`，界面经 `ui/primitives/*`。
- **riverpod 只在装配根**——import 只出现在 `main.dart` + `state/app_providers.dart`。

四条 grep 与七条 `check_architecture` 规则的完整表述、基线口径、以及"指纹 baseline + 只拦新增"的运作方式，见 [references/invariants.md](references/invariants.md)。**每次交付前跑 `dart tool/check_architecture.dart`（应得"7 recorded, 0 new"）与 `flutter test`（CI 也跑同一口径）。**

## File Organization

**按概念分组，不按类型分桶。** 一个特性拥有的处理器住在该特性目录里；内聚子系统把模型、生命周期、pipeline 作为**一个概念**放一起（企划的 `model/plan_*` + `ui/plan/`、Genkit 全在 `lib/genkit/`）。两种形状是 **scatter**，别长它、也别把仓库当前的使用当成目标：

- **按类型分桶**（为共享基类收集类）——把接口留在 `lib/` 根，特性代码不堆进桶。
- **松散的 `src/` 根**——核心原语留根，特性代码不。

*某块东西具体放哪* 是 locality 判断——见 **design-first**（Shape the modules）与 `../design-first/references/seams.md`。

## 工具与运行时契约（genkit 是本产品的心脏）

- **加/改 agent 工具**：只在 `lib/genkit/tools.dart` 的 `WorkspaceTools` 注册一次（工具在调用时读 workspace，换文件夹不重注册）→ 新事件形状进 `model/turn_event.dart`/`conversation.dart` → `genkit/agent_runtime.dart` 做投影 → UI 侧 `ui/tool/tool_card.dart`。
- **审批门禁只有一个顺序**：判定只问 `decideGate`（plan 先拒 → deny 规则带理由拒 → allow 规则静默放行 → 非 ask 放行 → 否则 interrupt）。**别在新工具里自己拼 `shouldInterrupt`**。规则 subject 必须与审批面板显示的那串一致（文件 `ws.relative(path)`、命令原文、外部工具 `server/tool`）。
- **文件写入只有一个回退闸门**：`write`/`edit` 在覆盖写之前把 before 镜像交给 `CheckpointSink`（接口在 model、实现在 `state/checkpoint_store.dart`）；`bash`/MCP 改的文件**没有**镜像，报告必须明说。
- 工具的 `description` 与返回给模型的 error 文本**不进 i18n**——那是模型读的，不是 UI 文案。
- genkit 全系是 0.x，**以 pub-cache 里的包源码为准**，别信记忆里的写法；升版必跑 `dart run spike/agent_spike.dart` 核对头部 FINDINGS。

## Dart 风格 / i18n / 主题 / 持久化

命名、类型、null/不可变、控制流、async、modern Dart、私有优先、`rethrow` 不 `throw e`——见 [references/dart-style.md](references/dart-style.md)（含本仓库特有的坑）。几条高频红线先记住：

- **文案**：新增/修改 UI 字符串必须同时进 `lib/l10n/app_en.arb` + `app_zh.arb`，跑 `flutter gen-l10n` 把生成物一并提交（ADR-0082）。取值走类型化 getter `AppLocalizations.of(context).key`，动态键走 `trKey` 桥（`lib/model` 只回键、不碰 Flutter）。硬编码中文由 `test/hardcoded_copy_test.dart` 零容忍拦下。
- **主题**：颜色/字号/动效/阴影/圆角**只从 `lib/theme/dsw_*` 取**；改对比度相关色值后跑 `dart tool/contrast_check.dart`。**组件用 shad、配色用 dsw**——别 `import 'package:shadcn_ui/...'` 去读它的调色板配色。新令牌必须带读者一起提交。
- **持久化**：手写 `toJson`/`fromJson` + `dart:convert`（`lib/model/` 那批 settings/state 模型即范例，无 codegen）；写盘沿用 `settings_store.dart`/`prefs_store.dart` 的 **tmp + rename 原子写**。

## 文档注释

偏好自解释代码——清楚的名字与结构让注释变得多余。**该注释时**：公开 API、不显然的*为什么*（绕法、边界、约束）。**别注释**：显然的行为、逐步 play-by-play。Dartdoc 风格与 `{@example}`/`[bracket]` 引用见 testing/dart-style 与 `dart-write-documentation` skill。

## 不做项（除非已立 ACCEPTED 的 ADR）

不新增依赖、不加抽象、不引入代码生成器（`build_runner` 等）、不往 `packages/` 塞第二个入库包、不动 `macos/Runner/*.entitlements`、不增删桌面平台目标。加载 skill ≠ 停止思考：仍按任务范围最小实现（ponytail）。
