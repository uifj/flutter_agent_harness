---
name: testing
description: Enforce PlanStar's test conventions — flutter test only, handwritten fakes, guard-per-invariant, reverse-verification, the known baseline failures. Use when writing tests, adding coverage, reproducing bugs with a failing test, TDD / red-green, regression tests, or refactoring tests. Apply alongside the architecture skill; load design-first for where the seams go.
---

把这些约定应用到本次改动新增或修改的所有测试。既有测试可能不遵循——**未被要求别顺手重构它们**。

测试最好对着**设计成接受其依赖**的代码来写——写被测代码时先载 **design-first**（接缝在哪）与 **architecture**（规则）。

## 只有一种跑法：`flutter test`

- 一律 `flutter test`。dev 依赖只有 `flutter_test`，**`dart test` 跑不起来**（`test/` 下每一个 `*_test.dart` 都 import `package:flutter_test`，包括纯逻辑的 `file_search_test.dart`）。
- **CI 已经在跑这套门禁**（`.github/workflows/pr-check.yml`）：`dart format --set-exit-if-changed lib test tool spike` + `dart analyze --fatal-infos lib test tool spike` + `flutter test`。本地三条命令与它同口径。
- 跑法排除 `test/probe_*_test.dart` 那几棵**未入库的一次性探针**（各带 10 分钟超时，会把套件数字变成 `-5`）。

## 基线口径：验收 = 相对零新增失败，不是"全绿"

当前基线不是绝对全绿。macOS 开发机 2026-10-04 现场跑 `flutter test` 得 **`+1349 -2`**；那 **2 个失败始终是同样两条**，都已登记在 `docs/debt-register.md` 待立 ADR 观察里：

- `test/app_scope_test.dart` 的 `a workspace-only save re-points the live runtime, no rebuild`（macOS temp 路径 `/var`↔`/private/var` 规范化）。
- `test/plan_workspace_test.dart` 的 `lists only the markdown files, folder as the second line`（`find.text('notes')` 命中两个 widget）。

**通过条数会随加测试漂移，别把它当常数引用**——交付前跑一次记下失败集，只对"零新增失败"负责。别把它们说成自己改坏的，**也别为了让套件变绿去改那两条断言**。

## Test-First Loop（垂直切片）

按**垂直切片**工作，不是水平的：一个失败测试 → 让它过的最小代码 → 重复。每个测试是一枚 **tracer bullet**——证一条薄的端到端路径，你从它学到的塑造下一个。**别**先写完所有测试再写所有实现（那种水平切片测的是*想象*的行为）。修 bug？先用一个失败测试复现它。

## 每个测试文件守住"那一句话"

- 文件头部用注释写清"**本文件要守住的那句话**"以及它存在的理由（参考 `conversation_controller_test.dart`、`file_search_test.dart`）。
- **流式拆分是本仓库唯一的性能契约**：token delta 只能通知 tail 的 notifier，不得通知 conversation controller（由 `flutter test test/conversation_controller_test.dart` 守着）。
- 每个测试文件单一 `void main()`；文件级 collector（`final folded = <String>[]` 这类"谁按了什么"清单）**必须在 `setUp` 里 `clear()`**——它们活在整个文件共享作用域，每棵守卫按精确相等断言，不清就会把上一棵的手势读成自己这棵的（红在错误理由上比不红更坏）。

## 反向验证文化（守卫的守卫）

本仓库最看重的一条：**一条守卫必须能证明它看得见东西**。

- 源码扫描类守卫（扫 `lib/**` 找违规）要额外有一条"**扫描对象非空**"的断言——**扫描对象为空也会绿**（`shad_menu_adoption_test.dart` 的 `the scan is looking at a tree that has menus in it`）。
- 画出来的功能要断"**那一格确实画出来了**"，不是断"没报错"——静默失效的功能看起来像没这个功能。徽标写死 `null` 应红在 `Found 0 widgets with text "M"`。
- 新写/改动守卫时**先红后绿验一遍**（把被守的东西种回缺陷，看它当场点名）。`回调被接住 ≠ 门被走过`：一个从没被任何断言按过的回调就是缺口。

## Fake 而不是 Mock

**替身一律手写** `test/fake_*.dart`（mockito 那套 codegen 路线与仓库约定冲突，已随 `dart-generate-test-mocks` 移除）。现成三个：`fake_turn_source.dart`、`fake_git.dart`、`fake_terminal_process.dart`。手写 fake 抗重构、可读如文档。测试难 fake 通常是被测代码该接受依赖而非自己造（design-first 的事）。`FakeGit` 有**两枚必用入口**（`inert()` / `stubRepo`）——见 [references/fakes.md](references/fakes.md)。

## 文件系统与真进程

- 文件系统类测试走**真实临时目录**——要验的是 mtime 排序、跳过 VCS 元数据、二进制早退这类**文件系统事实**，fake 证不出来。
- `test/git_status_real_test.dart` 是全仓**唯一真 spawn `git`** 的一棵（真仓库 + 真符号链接 + 五种形状）。它全是普通 `test()`，故**不进 FakeAsync**、不把 `runGit` 那 30s 进程超时带进任何 pump。**PATH 上没有 git 时它会红——那不是套件坏了，是那台机器跑不了这棵。**

## 两个必踩过的坑

1. **FakeAsync 挂死**：把 `await store.add(...)` 放进 `testWidgets` 体内会整轮挂死——FakeAsync 从不把控制权交回真实事件循环，store 的 tmp+rename 因此永不完成，没有失败也没有栈。要么在 `setUp` 里 await，要么按 `plan_workspace_test` 的 `pumpUntil` 用 `tester.runAsync` 排空。
2. **失败理由和被测的东西毫无关系**：给必填的 `status`/runner 传了会构造真 runner 的默认值 → 每条 widget 测试真跑一次 git，30s 超时计时器以 "A Timer is still pending" 弄红十条与 git 无关的测试（与上一条同族）。

## 断言

- 用 `expect()` + 具体 matcher（`throwsArgumentError`、`isA<X>()`）胜过泛型 matcher。一个逻辑断言一个测试（多个 `expect` 验同一行为可以）。
- **避免同义反复的测试**：断言字面期望值，不是生产代码用来产出它的同一个常量。常量当查找 *键* 可以；期望 *值* 钉成字面量。
- **保持确定性**：不依赖真时钟/网络/文件系统（除非写真跑那棵）。widget 测试不挂 `AppLocaleScope`（i18n flip 后现显式挂 `localizationsDelegates`+`supportedLocales`+`locale:`，`AppLocalizations.of` 无 delegate 会抛 = 响亮失败）。
- **宽度/时序类断言要开对了才覆盖**：菜单只在打开时才进树——"点开再量"；**widget 测试量不出 hover 时序**（合成指针不启动 Tooltip 计时器，"400ms 时还不该出现"永远为真），这类只能写成结构断言 + SDK 取值顺序引用，观感归真机走查——**别补一条看起来像行为验证的空测试**。

## 不变量 → 守卫文件对照

每条被专门守卫的不变量对应哪个 `*_test.dart`，改相关面前必跑：见 [references/guards.md](references/guards.md)。
