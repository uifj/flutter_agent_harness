# ADR-0037: 企划模式复现 Anytype 的数据视图内核（§1–§7，mock 驱动）

- **状态**: ACCEPTED
- **分类**: ARC
- **优先级**: P1
- **影响维度**: 生产功能
- **日期**: 2026-10-01
- **来源**: 用户指令（把 `docs/anytype-feature-inventory-2026-10-01.md` 的 §1–§7 完整融入企划模式）
- **修复 commit**: —（分阶段落地，逐段回填）

## 背景（Context）

企划模式现在的面板是**三份写死的投影**，不是一个数据视图内核：

- `lib/model/plan_task.dart:5-49` 是一个固定形状的 `PlanTask`：`id/title/groupIndex/order/done/dueDate`
  六个字段，没有关系、没有类型、没有视图配置。
- `lib/state/plan_task_store.dart:18` 把看板列数钉成常量 `planGroupCount = 4`；列名是 i18n 文案而不是数据
  （`plan_extensions_view.dart:4-7` 的文件头就是这么写的）。
- `lib/state/workspace_mode_controller.dart:33-44` 的 `PlanExtensionView` 是**封闭的四值枚举**
  （`none/board/calendar/table`）；`lib/main.dart:352-365` 按它 switch，`sidebar.dart:373-379`
  把三块面板硬列成三个入口。加一个视图 = 改四处。
- `lib/ui/plan/plan_extensions_view.dart:55-57` 三块面板各自 `_BoardView/_CalendarView/_TableView(store:)`
  直接吃 store，没有"记录 = 有序 id 列表 + 按行解析内容"这一层，所以筛选、排序、分组、视图管理、
  手工排序都无处可长。
- 对照清单：`docs/anytype-feature-inventory-2026-10-01.md` §1–§7 记录了 Anytype 客户端真实作答的
  6 种视图档位、14 档文本样式、16 种关系格式、23 个内置类型 key、13 种主屏组件形态与 5 档布局，
  以及"看起来有其实没有"那 23 行。本 ADR 要复现的是那张清单，不是它的营销描述。
- 可复用的底座已在仓库里：`packages/board_panel`（`board_panel.dart` 导出 `BoardPanel` +
  `BoardPanelController/BoardPanelConfig/cardBuilder/headerBuilder` 与 `MonthView` 全家）。
  宿主已经证明了两条边界：`_TaskCard extends BoardPanelGroupItem`（`plan_extensions_view.dart:147`）
  是包与 `lib/model` 之间的适配器；`ExpandableTable` 被**刻意不用**，表格在 dsw 词汇里手写
  （文件头 `:5-10` 给了理由）。

## 决策（Decision）

在企划模式内建一个 **Anytype 形状的对象—关系—视图内核**，mock 数据驱动，分七段落位；
候选方案与取舍：

1. **数据形状照 Anytype，不照 PlanTask。** 记录是 `Map<String, Object?>` 的**视图**
   （新纯 Dart 类型 `PlanStruct` + `PlanObject`，对应 `ObjectWrapper` over `Struct`），
   类型、关系、视图、模板、组件**本身也是对象**。
   被否的替代：给 `PlanTask` 加字段——那等于第 7 种硬编码投影，仍然无法承载"视图是数据"。
2. **没有 Go 核心，就把事件流换成纯函数 reducer。** Anytype 的"ack 即事件 payload + 单消费者"
   形状（清单 §架构记录）依赖中间件；本项目真相在 Dart 内存 + 盘上文件。
   决策：视图状态走 `PlanDataViewState` + `reduce(state, PlanEvent)` 纯函数（可单测，无框架），
   更新语义保持 Anytype 的两条：**先挂订阅再取快照**、**手工排序是 id 列表**。
3. **块文档以 Markdown 为盘上格式，块为内存形状。** 企划的笔记今天存 `.md` 文本。
   引入 `PlanBlock` 树（文本样式 14 档 + marks + 布局 + 表格 + 媒体/链接/书签占位 + TOC）后，
   读入解析成块、保存序列化回 Markdown；**不新增第二种盘上格式**，避免"两份必须相等的真值"
   （ADR-0014 那条理由）。不可无损往返的块（如 24 种 embed）按 Anytype 自己的答案画占位而不是造假数据。
4. **视图渲染的复用线**：Board 与 MonthView 继续用 `packages/board_panel`；
   Table / List / Gallery / 视图条 / 单元格编辑 / 抽屉全部宿主画（shadcn_ui 组件 + `dsw_*` 配色），
   `ExpandableTable` 继续不用。日历与图形视图**按 Anytype 的诚实答案实现为"不支持占位"**
   ——除非它正好是 MonthView 的等价能力，那一档才真做（见设计文档 §1 的判定）。
5. **组件（§7）落在企划首页。** `PlanExtensionView.none` 时不再只画"树 + 编辑器"，
   而是 Anytype 的主屏组件区（13 形态按可复现度映射，聊天类组件以本 app 的会话列表为源）。
6. **mock 是数据源，不是降级层。** 一个 `planMockStoreProvider`（`@Riverpod` 注解，
   codegen 现成：`dart run build_runner build` 已验证可用且幂等）给内存种子；
   store 的写路径与未来落盘路径同一形状，替换成真源时**只换 provider override**，不动 UI。
7. **riverpod 只在 `main.dart` + `app_providers.dart`**（检查器第 6 条）：控制器与 store 仍是
   `ChangeNotifier`，widget 通过 provider 读；值同步一律 `ref.invalidateSelf()`，不用
   `ref.notifyListeners()`（`app_providers.dart:101-106` 已把这条坑写成注释）。

## 后果（Consequences）

- **正面**: 加视图不再改四处；筛选/排序/分组/视图管理/手工排序第一次有地方长；
  企划从"三块演示面板"变成可验证的对象模型（纯 Dart 可单测），与代理模式共享同一套分层纪律。
- **负面/风险**:
  - 工作量集中在 UI（shad 抽屉 + 四视图 + 块渲染 + 组件区），需分七段提交，每段都跑三门禁。
  - mock 与真源的差别如果写进 UI 分支就是第二份真值——所以 mock 只允许出现在 provider 的 override 层。
  - 现有 `PlanTaskStore` 与 `plan_tasks.json` 仍在用；本次**不删不改它的语义**，
    Task 类型对象以适配层投影它（迁移真数据属后续 ADR）。
- **中性**: `PlanExtensionView` 从封闭枚举变成"视图 id + 集合 id"两参数；
  `sidebar.dart` 的三行入口换成集合列表；`packages/board_panel` 的 lint 排除面不变。

## 验证（Verification）

每段提交前跑（= CI 口径）：

```
flutter pub get
dart format --set-exit-if-changed lib test tool spike
dart analyze --fatal-infos lib test tool spike
flutter test
```

- 基线（2026-10-01 本机）：`+963 -2`，两条既有失败为 `app_scope_test` 的 `/var`↔`/private/var`
  与 `plan_workspace_test` 的 `find.text('notes')` 命中两处；验收口径是**零新增失败**。
- 新能力必须带守卫，逐段清单见 `docs/plan-mode-anytype-dataview-migration-2026-10-01.md` §7：
  reducer/筛选/排序/分组的纯 Dart 单测；四视图 + 视图条 + 抽屉的 widget 测试；
  新面挂进 `test/amplified_text_probe.dart` 的两档（1.8x / 2.2x）尺子；
  `theme_token_test.dart`（新令牌要有读者、半径在阶、样式名不许说谎）、
  `tap_affordance_test.dart`（不许手写第三套点击件）、`l10n_parity_test.dart`（双语同键）、
  `architecture_check_test.dart`（四条不变量 + 六条规则）。
- 若动正文级配色：`dart tool/contrast_check.dart` + `test/theme_contrast_test.dart`。

## 关联（Links）

- 清单真值: `docs/anytype-feature-inventory-2026-10-01.md` §1–§7、§17（"看起来有其实没有"）
- 设计文档: `docs/plan-mode-anytype-dataview-migration-2026-10-01.md`
- 现有代码: `lib/model/plan_task.dart#L5-L49`、`lib/state/plan_task_store.dart#L18`、
  `lib/state/workspace_mode_controller.dart#L33-L44`、`lib/main.dart#L352-L365`、
  `lib/ui/plan/plan_extensions_view.dart#L1-L60`、`lib/ui/sidebar/sidebar.dart#L373-L379`
- 关联 ADR: ADR-0007（企划/代理两模式与扩展面板；本 ADR 把"面板"升级为"视图"）、
  ADR-0002（riverpod 注解模式与 codegen）、ADR-0036（shad 组件三档判定：有则用 / 无则封装 /
  保留必带理由）、ADR-0017（形状令牌与字号档位）、ADR-0025（令牌必须带读者）
