# 本仓已知的接缝与"一处答案多处读者"

设计新东西前先看这里有没有**已经存在的接缝**可以复用。别在 widget 树里新造第二道服务递到手里的缝，也别给一个已有单一读者的东西加第二个不等的真值。

## 服务→界面的既有接缝（用现成的，别新造）

| 接缝 | 住在 | 谁用它 | 加新读者时 |
| --- | --- | --- | --- |
| `GitHost` | `ui/workbench/tabs/git_tab.dart`（`InheritedWidget`，由 `workbench.dart`/`free_window_layer.dart` 供） | git 面板 + 文件树读同一份 `GitStatusStore` 读数（ADR-0043） | `GitHost.statusOf(context)`，**不**新建第二道缝、**不**在 widget 里自己 `openRepo().status()` |
| `checkpoint_scope` | `ui/tool/checkpoint_scope.dart`（`InheritedWidget`） | 工具卡上的 rewind pill 拿到 store | 沿 `DetailsSelectionScope` 先例；**riverpod 不许进 widget 树** |
| `AppSettings` / `AppScope` | `state/app_scope.dart`（组合根，runtime 热替换链 + 打开 approval_rule_store / checkpoint_store + 持有一份 `GitStatusStore`） | 装配与运行时 | 换工作区只有 `AppScope.setWorkspace` 一条路 |
| `readOnlyToolNames` | `genkit/tools.dart` 的 `WorkspaceTools` | 工具"是否只读"的唯一声明；子 agent 工具集由它派生 | 加只读工具就把它加进这个集合，**别**在 `agent_runtime.dart` 再补一份列表 |
| `decideGate` | `genkit/tools.dart` 顶层函数 | 三个可写工具经 `gateFor`，MCP 外部工具经 `_ToolGate` | 新工具过门只问它，**别**自己拼 `shouldInterrupt` |

## 纯函数接缝（可单测，答案只在一处）

- `model/plan_filter_engine.dart` — filter/sort/group 的**唯一答案处**（纯 Dart、无副作用）。
- `model/session_groups.dart` — 分组纯函数；`model/relative_time.dart` — 四档"多久以前"，答的是 i18n 键加参数（因为 `lib/model` 不碰字典，ADR-0082）。
- `model/window_title.dart` 的 `composeWindowTitle` — 窗口标题字符串的唯一产出点。
- `model/checkpoint.dart` 的 `CheckpointSink` — 接口在 model（纯 Dart），实现在 `state/checkpoint_store.dart`，`lib/genkit` 只认接口——不变量 1/2 都不破。

## "一处答案多处读者"栽过的地方（ADR-0035 那条律）

改一个共享的东西**必须问它所有的读者**，判据不是"两处一模一样"，而是**被读的地方一份答案，被抄的地方留原文**：

- `formatToolOutput`（`ui/tool/tool_card.dart`，库级）——卡片与右栏详情栏共用；发给模型的 JSON 一字不动（Input 仍是 `CodeBlock(_pretty(arguments))`，复制出去的必须是模型形状）。
- `git status` 读数——`state/git_status_store.dart` 一份，XY 字母词汇住在 `host/git.dart`（是 `GitStatusEntry` 的性质，不是某棵视图的词汇）。
- 主题令牌——`lib/theme/dsw_*` 一处定义，**新增令牌必须带读者一起提交**（`test/theme_token_test.dart` 的 `every shape token has a reader`）。
- `AppSettings` 偏好字段——读取点、全屏设置页、级联快捷菜单**三处都要接**，只接一处就是分叉（ADR-0022）。

## 分层落位速查（东西该进哪一层）

- `lib/model/` — 纯 Dart 领域词汇；运行时与 UI 之间的**唯一**词汇表。需要给 runtime 用的跨层共享状态放这里、保持纯 Dart（`fs_revision` 是 `lib/model` 第一个全局可变单例，ADR-0015）。
- `lib/genkit/` — Genkit 唯一的家；不 import `package:flutter*`、不 import `lib/state/`（保证 `spike/runtime_smoke.dart` 还能编译）。
- `lib/state/` — 控制器与持久化；原则上不 import `lib/ui/`（唯一例外 `layout_controller.dart` 读约束表达式）。
- `lib/ui/` — 界面；不直接 `dart:io`（走 `lib/host/`，经 `ui/primitives/*`，`check_architecture` 规则 4 拦）。
- `lib/host/` — 宿主能力（git、terminal、reveal、bookmark、support_directory）。
- riverpod import 只允许出现在 `main.dart` + `state/app_providers.dart`（`workspace_mode_controller` 是 `ChangeNotifier` 正因如此）。
