# ADR-0075: 企划笔记静默自动保存——防抖落盘，摘掉手动保存

- **状态**: ACCEPTED（2026-10-07 用户拍板：Save 按钮彻底摘除、Cmd+S 留作手动 flush、防抖时长由实现方按参照系定夺并落本档、目标 8/9 另立 ADR-0076/0077）
- **分类**: ARC（持久化行为与编辑器数据流）
- **优先级**: P1
- **影响维度**: 生产功能
- **日期**: 2026-10-07
- **来源**: 用户指令（企划模式下每次修改必须手点保存，打断沉浸式写作；对标 Obsidian 编辑体验）+ appflowy-editor 源码调研（`_archive/appflowy-editor` @ `01eccc6e`，tag 6.1.0）+ 本机 Obsidian vault（`/Users/uifj/Personal/in-sail-obsidian/.obsidian`）实测
- **修复 commit**: 本批（见登记表行回填）

## 背景（Context）

**现状（手动保存链，全在 `lib/ui/plan/plan_workspace.dart`）**：

- 保存是三扇门：Save 胶囊（`:390-395`，`enabled: _dirty && !_saving`）、Cmd/Ctrl+S（Edit 档 `:253-258`、Source 档 `:294-299`）、切档不保存。`_save()`（`:165-191`）按当前模式取真值（Edit 取 `_document.encode()`、Source 取 `controller.text`）后 `File.writeAsString` **直写，非原子**（`:178`）。
- 脏标记由两座桥驱动：`_DocumentBridge`（`:407-461`，监听 `PlanBlockDocument`，按 `revision` 计数（`plan_block_document.dart:41`，`_commit()` `:116-118` 每次变更抬一）在 build 外 `scheduleMicrotask` 置脏——undo/redo 与结构编辑都走它）；`_DirtyBridge`（`:487-521`，re_editor 的 one-frame-late 桥，理由沿 `editor_tab`）。
- 带着脏档切笔记弹确认丢弃（`:133-141`）；工具条常驻「未保存」chip（`:361-369`）与 `saving` 标签（`:391`）。

**三个把"手动保存"变成缺陷、又把"无脑自动保存"变成数据丢失的放大器**：

1. **双 buffer 不同步（现存数据丢失面，自动保存会放大它）**：模式切换只翻转枚举（`:384-387`），两份 buffer 从不互通——全文件没有一处 `controller.text =` 回写；Preview 也读的是 `controller.text`（`:251`）。今天用户在 Edit 面改完切到 Source 面再编辑，`_save()` 会把**陈旧的 `_document` 编码**盖掉 Source 面的新内容；自动保存让同一覆盖在用户无感时定时发生——从"用户手滑"升级成"产品主动丢稿"。做自动保存必须先修这个交接。
2. **工作区即 agent 工作区**：vault 就是 agent 的 `workspaceRoot`（`plan_workspace.dart:10-12` 的头部注释），agent 工具对同一批 md 有写权（`lib/genkit/tools.dart:290,418` 的 `writeAsStringSync`），外部还有 git 操作。编辑器开档时读一次（`:144`）后**从不复查盘上变化**；手动保存的覆盖窗口靠"用户手速"兜着，自动保存把它拉宽成常开。
3. **写频率上升**：现状一次保存一次直写；防抖后写频率数量级上升，直写的撕裂写风险（进程被杀、断电落在半截字节）随之上升。

**参照系（调研结论，详见来源里的两份材料）**：

- appflowy-editor 把持久化**完全留给宿主**：SDK 内零保存代码，官方示例的宿主姿势就是"监听事务流 → after 落盘"（`editor_state.dart:246-249` 的 `transactionStream` + `example/lib/pages/editor.dart:101-107`）；undo/redo 与持久化彻底解耦（基于操作取逆 + 50ms seal 防抖，`undo_manager.dart:10-23`、`editor_state.dart:722-734`），保存层叠上去碰不到它。SDK 无 dirty 标记、无版本校验——都要宿主自建。
- Obsidian 的体验契约：无保存按钮、静默写盘、脏状态只内部感知；本机 vault 实测其配置形态为"每 vault 一个 `.obsidian/` 点目录、一关注点一 JSON、UI 状态与笔记内容分离、默认值不落盘"；兜底靠独立的 file-recovery 快照插件。
- 仓库内的防抖先例：`workbench_store.dart` 布局写盘按会话防抖 200ms（`:31`），头部注释写明"匹配 better-sidebar 的同一边而不是发明第二个数"，并带 `flush()`（`:70`）。企划笔记没有既存数字可匹配——布局防抖服务的是**拖拽每帧风暴**（机器节奏），打字是**人节奏**，两类边缘不该共用一个数。

## 决策（Decision）

六条，缺一不可：

**① 触发 = 脏 + 1s 尾沿防抖。** `PlanWorkspace` state 内挂一个小保存器（Timer 字段 + `_persist()`，几十行，不另立类），置脏时重置 1s Timer，停手即落盘；不设 max-wait（脏写永不丢，只是等一次停手；连续打字的崩溃丢失窗口 = 1s 尾巴，与 Obsidian 行为同级）。**时长依据（拍板落档）**：appflowy-editor 的宿主产品形态是**每事务立即落盘**（`saveUpdate` 回调逐事务交给宿主，`example/lib/pages/collab_editor_offline.dart:121-129`）——但它的持久化单位是二进制增量日志（几十字节），而企划星的单位是**整篇 md 重新编码写盘**，逐事务照搬就是写放大；Obsidian（同为整文件模型，闭源）的可见行为是"停止输入后约一两秒静默写盘、全程零提示"。仓库既有的三个防抖数（50ms 历史 seal / 300ms 字数 / 200ms 布局，`workbench_store.dart:31` 头部注释明确"匹配上游而不发明第二个数"）服务的都是机器节奏或派生量，没有可对齐的内容保存数。取 **1s 尾沿**：≥人类"一个停顿"的感知阈值（打着字不落盘），把连续输入的写盘压到 ≤1 次/秒，崩溃丢稿窗口收进 1 秒。备选取舍：200ms（白付 5 倍写放大）、2–3s（丢稿窗口大，超额完成防 IO 目标）。

**② flush 触发点（立即写，绕过防抖）**：切笔记（`_openPath` 先 flush 再读新文件，**确认丢弃弹窗删除**——flush 成功就没有"丢弃"这回事）、模式切换（与③同点）、workspaceRoot 变更、窗口失焦、组件卸载（切进企划扩展视图会 unmount 本件）、关窗。失焦用 `WidgetsBindingObserver.didChangeAppLifecycleState`：桌面档 `inactive/hidden/paused` 即失焦/最小化，`!= resumed` 一律 flush（不脏则空操作，误触发无害）——不依赖单一 `paused` 值。关窗是新缝：`PlanWorkspace` 增加 `onRegisterFlush` 回调（沿 `onPickWorkspace`/`onNoteConsumed` 的既有形态，PlanWorkspace 直构于 `main.dart:610`，不用穿层），main 侧 `window_manager.setPreventClose(true)` + `WindowListener.onWindowClose`（**全仓目前没有任何 onWindowClose 钩子，grep 为证**）→ await flush → destroy；托盘退出（`TrayService.onQuit` → `windowManager.close()`，`main.dart:273`）走同一条被拦截的 close，一并接住。Cmd+S 保留为手动 flush（肌肉记忆无害化）。门拦住时的关窗：flush 跳写、窗照关，本地未处置的修改随窗丢失（反馈条在门触发时已示警）——诚实边界，重载/另存的完整处置流留给后续。

**③ 模式交接 = 目标面从当前真值重建。** Edit→Source：controller 重载为 `_document.encode()`；Source→Edit：`_document` 重解码 `controller.text`；Preview 读**当前编辑面**的真值（Edit 档读文档编码，Source 档读 controller）。从此**盘上文件是唯一真值**，两个面都是它的视图。这是把放大的丢稿面先焊死，再谈自动保存。

**④ 外部变更门 = 写前 stat。** 保存器记住开档/上次成功保存时的 `modified` + `size`，每次落盘前 stat 比对：不符（agent 改过、git 动过、外部编辑器动过）则**跳过本次写**、进入「卡住」态——chip 换文案 + `showFeedback` 一条（唯一反馈入口，workflow §3）。哲学沿 ADR-0014 冲突闸门：**宁可什么都不写，也不盖别人的编辑**。v1 的处置闭环：① 卡住后继续编辑 → 每次防抖到点重试，门仍拦（不重复弹反馈，只在进入卡住态的边沿提示一次）；② chip 文案统一为「修改未写入盘」（不区分门拦与写失败——后者同样进卡住态，措辞通用才不撒谎），反馈条区分原因（门拦说盘上已变、写失败说保存失败）；③ 放弃该笔记的动作（切笔记/换工作区）若带着未写入修改 → 确认对话框「继续将丢弃」（复用 `showConfirmDialog`，只在冲突时出现，不是日常摩擦）；④ 重新打开该笔记即重读盘上版本（既有 `_openPath` 流，等于"丢弃本地重读"）。自动合并、增量 rebase、强制覆盖明确不做。

**⑤ 落盘改 tmp + rename 原子写**（`settings_store.dart`/`prefs_store.dart` 既有形，workflow §3「持久化」条的同口径）——写频率上升后这是底线而非优化。

**⑥ UI 摘除**：Save 胶囊删除（连带 `enabled: _dirty && !_saving` 的门死掉，`_saving` 字段退役）；「未保存」chip 撤下——防抖窗口内的待写状态**内部感知、不外显**（对标目标 3"脏状态只内部感知"与目标 6"无提示"，一个每秒闪现又消失的 chip 是噪声）；chip 只在卡住态出现（④）。保存成功零提示零弹窗（目标：静默）；写失败保留脏标记 + `showFeedback` destructive。`save`/`saving` 键**保留**（设置页与 editor_tab 是在读者，`model_settings.dart:790`、`editor_tab.dart:649`）；`planUnsaved` 键删除；`planDiscardTitle/planDiscardDesc` 两键随确认弹窗删除（零他处读者）；`discardChanges` 键保留（editor_tab/git_tab 在读）。

**明确不做（要做得另立 ADR）**：md frontmatter 文档属性（对标目标 8；appflowy-editor 的 md 编解码已证实不支持，企划星自有 `<!-- plan:{json} -->` 信封是同类问题的自家解法）、每工作区 `.planstar/` 配置目录（目标 9）、工作台 `editor_tab` 的自动保存（它服务的是 agent 文件查看/编辑，人群与风险面不同）、同档多窗口/协作编辑。

## 后果（Consequences）

- **正面**：沉浸式写作不再被保存打断（核心诉求）；切笔记零确认；agent 改过的文件不会被编辑器静默回滚（④补上了现存盲区）；双面真值统一（③顺带修掉一个现存丢稿面）；崩溃丢稿窗口从"无限（永不点保存就全丢）"缩到 1s。
- **负面/风险**：写频率上升（1 次/停手，SSD 上无感但存在）；mtime 门在分辨率粗糙的文件系统上有理论误报（跳过写，不会错写，向保守侧偏）；关窗 flush 引入 main ↔ PlanWorkspace 的一条新回调缝（`onRegisterFlush`）；卡住态的关窗即丢本地未写入修改（反馈条已示警，完整处置流留后续）；模式交接重建文档会**重置本地 undo 栈**（与今天 Source 档保存后重建文档的既有行为一致，`plan_workspace.dart:180-181`）；macOS 的 Cmd+Q 走应用终止而非窗口 close，`onWindowClose` 是否接得住属平台行为——blur flush 覆盖大多数路径，真机走查核对（标"待 macOS 验证"）。
- **中性**：`plan_workspace.dart` 头部"save/dirty machinery follows editor_tab's shapes"的谱系注释要改写（脏桥保留，保存时机换主）；`_DocumentBridge`/`_DirtyBridge` 原样保留——它们继续是脏信号的唯一来源，保存器只是脏信号的消费者之一（Timer、chip）；防抖时长 1s 是新数字，构造参数注入（`autosaveDebounce`）供测试提速。

## 验证（Verification）

- `test/plan_workspace_test.dart` 同族扩展（widget 测试 + 临时目录，注意 §3 已记的 FakeAsync 坑——`await` 放 setUp 或用 `pumpUntil` 排空）：① 打字后停手 1s 落盘（防抖，时长构造注入提速）；② flush 点各一例（切笔记/切模式/失焦/组件卸载/关窗——关窗测 `onRegisterFlush` 注册的回调契约，native 侧标待 macOS）；③ 模式交接两档（Edit→Source 后 Source 面内容 == 文档编码；Preview→Edit 反向同理）；④ 外部变更门（落盘后改盘上文件再触发保存 → 断言盘上内容 == 外部版本、feedback 出现、chip 出现）；⑤ 写失败（dart:io 无 chmod——在同目录预置一个与 `.tmp` 同名的目录，`writeAsString` 必抛 `FileSystemException`）→ 脏保留 + feedback；⑥ 原子写（落盘后目录内无残留 tmp）；⑦ 卡住态切笔记的确认对话框两档。
- 四道门禁同口径：`dart format --set-exit-if-changed lib test`、`dart analyze --fatal-infos lib test tool spike`、`flutter test`（相对基线零新增失败）、`dart tool/check_architecture.dart`。
- macOS 真机走查：连续打字无感、Cmd+Q 落盘、agent 边写边看的场景（标"待 macOS 验证"前不签收）。

## 关联（Links）

- 代码: `lib/ui/plan/plan_workspace.dart:131-141,165-196,251-258,390-395,407-461,487-521`、`lib/state/plan_block_document.dart:41,116-118,142-152`、`lib/genkit/tools.dart:290,418`、`lib/state/workbench_store.dart:31,70`（防抖+flush 先例）、`lib/model/fs_revision.dart`（外部变更信号的既有词汇）
- 关联 ADR: ADR-0037（笔记块编辑器与 md 信封——保存的编码方）、ADR-0014（冲突闸门——④的哲学来源）、ADR-0020（反馈条唯一入口）、ADR-0073（侧栏 vault 树——切笔记 flush 的对端）
- 研究: `_archive/appflowy-editor`（`lib/src/editor_state.dart:246-249,431-494,722-734`、`example/lib/pages/editor.dart:101-107`、`lib/src/history/undo_manager.dart:10-23`；SDK 零持久化、md 编解码无 frontmatter 均已实证）、本机 `.obsidian` 实测（四文件、frontmatter 模板、file-recovery 开关）

## 追记（实施回填，2026-10-07）

- **③ 的交接通知过滤换了机制**：原文的"交接通知被抑制一次"不可实现——Source 面的脏桥是 postFrame 晚挂（one-frame-late，沿 editor_tab），Edit→Source 交接时 `controller.text = encode()` 的同步通知**无人接收**，抑制旗漏到下一笔真实编辑头上把它吞掉（测试实锤：脏标记永不置位）。改为**内容相等跳写**：persist 记住盘上已有的字节（`_lastWritten`，开档时=文件原文，写成功后=刚写的文本），文本相等直接清脏、不落盘。比抑制旗更强：任何"重新推导出同一内容"的通知（模式交接、undo 回原点）都不产生写——只打开看了一眼的笔记不会有 git 噪声 diff。代价：内存多一份笔记文本副本。
- **卸载期 persist 的 setState 守卫**：dispose 启动的 fire-and-forget 写在 unmount 窗口内收尾时，`mounted` 仍回答 true 而 element 已 defunct，`setState` 直接炸。加 `_disposed` 旗（dispose 第一行置位），`_markStuck`/`_markClean` 以它守卫。这不是测试权宜：真机"切扩展视图 + 门恰好拦住"走同一路径必炸。
- **防抖时长落定 1s**（决策 ①），构造参数 `autosaveDebounce` 注入，测试用 100ms。
- **测试侧新知**：re_editor 的移动分支（widget 测试默认平台即 android）每次 `startBlink` 排一个**不可取消**的 100ms `value = true` future——编辑器卸载后它仍会打在已 dispose 的 notifier 上。唯一解法是让它在编辑器还活着时烧掉（`settle` 的 360ms 顺带把测试防抖也点了，所以需要"待写"断言的测试在 settle 后重新输入）。

## 追记 #2（能力面补全：远端应用落地，2026-10-07）

对标 appflowy-editor 的核心能力——**编辑器是存储之上的活视图**（远端更新走 `apply(isRemote: true)` 实时进文档，`editor_state.dart:454-456,757-801`；协作示例的 `getUpdatesStream`/`saveUpdate`，`example/lib/pages/collab_editor_offline.dart:114-151`）——首批只做了写侧（门），本批补上读侧：

- **fsRevision 驱动的活重载**：监听 `fsRevision`（`lib/model/fs_revision.dart` 的全局计数，agent 的 write/edit 工具与 rewind 每次落盘都 `bumpFsRevision()`）→ stat 比对开档笔记。**干净缓冲 → 静默重载**（换新 `PlanBlockDocument` + controller，编辑器保持文件的活视图——用户让 agent 改这篇笔记，改完当场可见）；**有未写修改 → 不等防抖、立即进卡住态**（冲突在发生时现身，不是在下次保存时）；**文件消失 → 关闭笔记**而不是在下一次写盘时复活它（vault 树自己没有删除流，笔记消失只可能来自外部，这条补的正是僵尸编辑器）。同内容 touch（git checkout）只采纳新 stat 不重建文档——保住 undo 栈，也省一次重解码。
- **Source 桥的重绑**：重载会换新 `CodeLineEditingController` 实例，而 `_DirtyBridge` 原本没有 `didUpdateWidget`——重载后 Source 档的每次编辑都永远不会保存。补上换绑（沿 initState 的 postFrame 晚挂形状）。
- **写前二次 stat 复核**：门是 check-then-write，写本身有真实耗时——tmp 写完、rename 之前再 stat 一次，agent 的写入落在中途就放弃 rename 交给活重载接手。rename 到落盘之间仍有不可关闭的缝（微秒级，任何无锁方案都一样），窗口从"整个写盘耗时"缩到"一次 rename"。
- **卡住态的反馈边沿化**：首批实现里门/写失败的 toast 在每次重试都会重弹，与 ④"只在进入卡住态的边沿提示一次"不符——`_markStuck()` 改为回答"是否本次转入"，只有边沿弹条。
- **诚实边界**：fsRevision 只由 agent 工具与 rewind 抬——用户的 git 操作、外部编辑器的改动不在信号里，仍由写盘时的门兜住；重载会丢光标与 undo 栈（干净缓冲下无稿可丢，可接受）；vault 树删除不 bump（它没有删除流）。

## 追记 #3（TDD 全链路走查，2026-10-07）

以终端用户视角逐旅程走查（走查单 `docs/walkthrough-plan-autosave-2026-10-07.md`，每步标注哪一半由测试证过），先写测试后修代码，四个候选断层两个是真、两个转正为守卫：

- **真断层①：三面往返丢 undo**。preview→edit 无条件重建文档——瞥一眼 Source/Preview 回来，undo 栈清零（"看一眼不是编辑"；Obsidian 的面切换从不重置 undo）。修：仅当 buffer 与 `document.encode()` 分歧（真在 Source 面改过字）才重建。
- **真断层②（反直觉）：Cmd+S 在 Preview 面静默失效**。快捷键原本只绑 Edit/Source 两面；功能上 Preview 永远没有 pending（切面时已 flush），但快捷键不能让肌肉记忆在一个面上失灵。修：CallbackShortcuts 提升为三面通用。
- **转正守卫①：新建空笔记可立即打字**——树建的是空文件，但解码器对空行补一个空段落（`plan_markdown_codec.dart:89-96`），打开即可打字（Anytype"新对象必落可编辑面"的直觉）。
- **转正守卫②：撤销回原点自动消解冲突**——卡住后把内容退回已存文本，内容跳写（在门之前）清脏清卡住，切笔记不再弹确认。两个行为都对，此前无测试钉住。

门禁：format 0 / analyze 0 / arch 8 recorded 0 new / `flutter test` **+1444 −1**（唯一败 = app_scope 既有基线）。
