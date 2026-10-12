# Dart / Flutter 风格（本仓库高频规则）

通用规则以 **Effective Dart** 为准，`dart analyze --fatal-infos` 与前沿模型已能应用大部分，这里只留**在本仓库容易写错**的、以及产品代码反复栽过的。完整 Dart 语言面看 `dart-*` skills，Flutter 组件面看 `flutter-*` skills 与 `shadcn-ui-flutter`。

## Match the project

- **Lints**：`analysis_options.yaml` 只 include `flutter_lints`——**别私自加规则集**（`riverpod_lint` 因 SDK meta 约束暂不可装，ADR-0002 修订 1）。
- **语言特性下限**：用较新语法前先看 `pubspec.yaml` 的 `environment.sdk`（^3.11.5）与 CI 钉的 Flutter 3.41.9——装的 SDK 可能支持包声明不支持的语法。
- **状态管理**：项目已用 `flutter_riverpod`（注解模式，`*.g.dart` 入库）；别为局部状态引入第二套架构。`ChangeNotifier` 用于不许 import riverpod 的层（如 `workspace_mode_controller`）。

## 类型与安全

- **私有优先。** 保持声明私有，只在真正是 API 的一部分时才公开——`lib/model` 里很多形状只在包内流动。每个公开符号都是维护负担。
- **用 class modifiers 控制扩展。** 公开类用 `final`/`base`/`interface`/`sealed` 声明可否被 extends/implements——否则每个公开类隐含两者，无法不破坏消费者地演进。`approval_mode`、`turn_event` 这类封闭集适合 `sealed`。
- **切换枚举/sealed 不写 `default`/`_` case**，让新增 case 在每个处理处成为编译错误。
- **不要无初始化的公开 `late final` 字段**——它静默定义了一个公开 *setter*，泄漏 API 面。
- **`rethrow`，永不 `throw e`**——`throw e` 把堆栈重置到重抛处；堆栈保真在这个产品（工具环 + 崩溃归档）里是要紧事。
- 用 `Object?` 表示"任意值"；`dynamic` 只留给故意关掉静态检查处。缺场无独立意义时返回空集合而非 `null`。

## 函数与 async

- 布尔参数与调用处含义不清的参数用**命名参数**。
- `async`/`await` 优于裸 `.then()`；每个返回的 `Future` 都要交代（await 或 return）。故意 detached 的操作包 `unawaited(...)` 并让它错误行为明确。**未 await 的 future 是 review 的 Correctness 轴头号目标。**

## Flutter 特有（本产品反复栽过的）

- **行里的自由文本必须有 flex 上界。** 侧栏行、工具卡头、状态条这类"一行装一个可变长度字符串"处，`Text` 要么是 `Expanded`/`Flexible` 的子件，否则溢出面板。**`overflow: TextOverflow.ellipsis` 单独写没有用**——Row 的非 flex 子件按无限宽量出来，ellipsis 根本没触发机会。踩实过三处：`composer.dart` 工作区状态条、`diff_tab.dart` 的 `← 旧路径`、`primitives/disclosure_row.dart` 标题（守卫 `disclosure_row_test.dart` 反向验过）。判别式只有一个：**这块内容允不允许被截断**——该让位的是标签/徽标，不是用户要打的字。
- **尊重系统文本缩放。** 一行的"座位"高度取 `设计像素 × MediaQuery.textScalerOf(context).scale(1)`，不钉死像素（ADR-0017 S3）。窄屏降级律：**先丢标签与描边，最后才丢座位**，丢了标签的名字要留在 `semanticLabel` 里。守卫 `test/amplified_text_probe.dart` 挂满二十一个测试宿主、每面跑两档（1.8x 与 2.2x）。
- **异步间隙后用 `context.mounted`**（`State` 里用 `mounted`）再 `setState`/用 context；`use_build_context_synchronously` lint 会标。`State` 拥有的控制器/focus node/notifier 要 dispose，取消自己创建的订阅。
- **`build` 无副作用**：不启动请求、不在 `build` 里造有身份的 future/controller。`FutureBuilder`/`StreamBuilder` 的 future 在 `build` 之前取得（`initState` 等）。
- 给可滚动件在 `Column`/`Row` 里有界空间（多半 `Expanded`）；优先 `const` 构造与创建点。
- **点击件只用一套原语**：`ui/primitives/tappable.dart` 的 `DswHoverTap`（指针/键盘/语义/右键四性一次到位）或 shad 的 `ShadButton`；**别再手写 `MouseRegion + GestureDetector`**（ADR-0021，`tap_affordance_test.dart` 按文件计数拦）。图标按钮只认 `ui/primitives/icon_button.dart` 的 `DswIconButton`，禁用写 `onTap: null`，不要加 `enabled`（ADR-0024）。

## 持久化 / JSON

- 手写 `toJson`/`fromJson` + `dart:convert`（`flutter-implement-json-serialization` skill 的路线正是本仓库路线，无 codegen）。`lib/model` 里那批 settings/state 模型即范例。
- 写盘用 **tmp + rename 原子写**（`settings_store.dart`/`prefs_store.dart`）；读侧宽容（`fromJson` 只问它认识的键，多余键忽略），写侧收敛。
- 序列化正确性（`toJson`/`fromJson` 往返、null 处理）是 review 威胁模型的一部分——尤其 checkpoint 的 before 镜像与会话 sidecar。

## Modern Dart（挣得了清晰度才用）

sealed class 做穷尽匹配、record 做多值返回、pattern matching / switch 表达式、extension type 做零成本包装、增强 enum。**别在普通代码读起来更清楚的地方硬塞**。
