# 手写替身（`test/fake_*.dart`）

本仓库**不用 mockito/codegen 生成 mock**（那条路线已随 `dart-generate-test-mocks` 移除，与替身约定冲突）。替身一律手写——它们抗重构、可读如文档，且"测试难 fake"往往是被测代码该接受依赖而非自己构造的信号（design-first 的事）。

## 现成的三个替身

| 文件 | 顶替什么 | 用法 |
| --- | --- | --- |
| `test/fake_turn_source.dart` | genkit 的 turn 流来源（`TurnSource`） | 喂确定性的 `TurnEvent` 序列给控制器，验投影/拆分，不碰真模型 |
| `test/fake_git.dart` | `GitHost` / `GitStatusStore` 的 git 侧 | 两枚必用入口见下 |
| `test/fake_terminal_process.dart` | `flutter_pty` 真进程 | 验终端 tab 的输入/输出投影，不 spawn PTY |

另外 `test/clipboard_probe.dart` 与 `test/amplified_text_probe.dart` 是**探针不是测试**——后者除两档尺子外还导出 `unlabelledIconControls`（图标即控件的命名检查）。别把探针当测试跑。

## `FakeGit` 的两枚必用入口（ADR-0043）

`Workbench` 与 `FreeWindowLayer` 的 `status` 参数是**必填**——**别给它默认值**（默认值会构造一个真 runner，于是每条 widget 测试真去 spawn 一次 git，而 `runGit` 的 30s 进程超时计时器以 "A Timer is still pending" 弄红十条与 git 无关的测试：**失败理由和被测的东西毫无关系**）。

- **`FakeGit.inert()`** — 一条**不 spawn 进程**的 `GitStatusStore`，回答"不是仓库"。用它当"我不关心 git、只要不炸"的宿主默认。
- **`FakeGit()..stubRepo(root: …)`** — 一棵**假仓库**，能让树画徽标。

**要让树画 git 徽标，先 `await store.read(root.path)` 再 pump**——树自己不轮询，缓存里没读数它就一枚字母都不画，于是那棵守卫量为空也会**通过**（假通过）。放大文本那两档也必须先把徽标建进树里：原先用 `FakeGit.inert()`，字母根本没进树，量为空也通过——现在 seed 一棵假仓库并先断 `find.text('M')` 再量。

要走查 tab 芯片就点一棵**已经开着**的文件夹 tab，别为了一颗芯片去开 git（git tab 自己挂 30s 进程超时，pending timer 会以与命名无关的理由红）。

## 真 git 那一棵另说

`test/git_status_real_test.dart` 是全仓**唯一真 spawn `git`** 的一棵（真仓库、真符号链接、`R `/`M `/` M`/`??`/子目录五种形状）。它全是普通 `test()`（非 `testWidgets`），因此**不进 FakeAsync、也不把 30s 计时器带进任何 pump**。PATH 上没有 git 它会直接红——那不是套件坏了，是那台机器跑不了这棵。**判词：静默失效的功能，守卫要断"那一格确实画出来了"，不是断"没有报错"。**

## 造新替身的规矩

- 命名 `test/fake_<依赖>.dart`，实现的是**接口**（如 `CheckpointSink`、`GitHost` 缝），不是具体类。
- **捕获状态**供断言（记录了哪些调用、顺序、参数），而不是只返回硬编码值。
- 跨包共享的替身放不进 `lib/`——本仓库没有独立的 test 包，需要跨包工具时按 sentry 的做法另立；当前惯例是各测试文件就近或 `test/` 根。
- **别在 widget 里写"如果是 mock 就……"分支**（企划那条律：mock 只住在 provider override / 种子层 `model/plan_mock_content.dart`）。
- 需要 `planObjectStore` 之类的 provider：默认体是 `throw UnimplementedError`，**逼你在 `main`/测试里 override**——别把兜底塞回 provider body。
