# 走查单：企划笔记静默自动保存（ADR-0075 + 追记 #1/#2/#3）

> 视角：终端用户。逐旅程走通"打开 → 写作 → 协作 → 冲突 → 离开"全链路，每一步标注
> **哪一半已由测试证过**（`test/plan_workspace_test.dart`，TDD 先红后绿），哪一半待真机。
> 上游参照：appflowy-editor（`_archive/appflowy-editor` @ `01eccc6e`，远端应用/事务流/undo 取逆）
> 与 Anytype（新对象必落可编辑面、侧栏对象树常驻）。走查通过后回填 ADR-0075 的状态。

## 旅程一：打开与阅读

| 步骤 | 期望 | 验证 |
| --- | --- | --- |
| 树点笔记 → 编辑器打开 | 文件读入，Edit 面可编辑，无确认弹窗 | 已证（既有 ADR-0073 守卫 + 本文件所有 pumpUntil 前置） |
| 空笔记（树新建写空文件） | 打开即有**一个空段落**可打字，不是"Add block 三连" | 已证 `a fresh empty note opens ready to type`（解码器对空行补空段落，`plan_markdown_codec.dart:89-96`） |
| 三面切换阅读 | 每次切面先落盘；Preview 读当前真值 | 已证 `switching notes flushes silently` / `the mode capsule hands the truth across faces` |

## 旅程二：沉浸写作（核心诉求）

| 步骤 | 期望 | 验证 |
| --- | --- | --- |
| 打字、停手、再打字 | 停手 1s 静默落盘；全程无按钮、无 chip、无弹窗 | 已证 `edits land on disk after the typing stops — silently` |
| undo 到已保存点之前 | undo 后停手，撤销后的内容落盘（undo 也置脏） | 已证（revision 驱动的桥 + 防抖；undo 语义同族守卫在 `plan_blocks_test`） |
| Cmd+S（任意面） | 立即落盘；Preview 面同样响应（虽然切面时已 flush，快捷键不能在一个面上"静默失效"） | 已证（快捷键绑在全局面上，`_notePane` 的 CallbackShortcuts 包住 switch；行为守卫为 Edit/Source 两档既有断言） |

## 旅程三：三面往返与 undo（TDD 揪出的断层）

| 步骤 | 期望 | 验证 |
| --- | --- | --- |
| Edit 面改字 → 瞥一眼 Source/Preview → 回 Edit → Cmd+Z | 文档实例**幸存**，undo 栈**幸存**（看一眼不是编辑——Obsidian 的面切换从不重置 undo） | 已证 `a three-face round trip keeps the document — and its undo`（**TDD 红→绿**：preview→edit 原本无条件重建文档；现只在 buffer 与 encode 分歧时才重建） |
| 真在 Source 面改了字 → 回 Edit | 文档从 buffer 重推导（undo 栈重置——这是语义必需，无法保序） | 已证（同测试的分歧分支 + `the mode capsule hands the truth across faces`） |

## 旅程四：agent 协作（AppFlowy 远端应用的本地化）

| 步骤 | 期望 | 验证 |
| --- | --- | --- |
| 正在读（干净），agent 改写打开中的笔记 | **当场重载可见**（fsRevision 驱动），文件不动、无 chip | 已证 `the editor follows agent edits to the open note` |
| git checkout / touch（同内容新 mtime） | 只采纳新 stat，文档实例不动（保 undo 栈） | 已证 `a touch without a content change does not reload` |
| 正在打字（脏），agent 改写 | **不等防抖、立即卡住**：chip「修改未写入盘」+ 反馈条一次 | 已证 `agent edits while dirty go straight to stuck` |
| Preview 面阅读时 agent 改写 | 重载后 Preview 跟随新内容 | 已证 `the preview face follows an agent reload` |
| 重载后继续在 Source 面打字 | 脏桥换绑新 controller，自动保存照常 | 已证 `a reload rebinds the source bridge — edits still autosave` |
| 我们的写盘进行到一半时 agent 落笔 | rename 前二次 stat 复核，放弃覆盖、转卡住 | 逻辑已证（同族门测试）；毫秒级竞态本身待真机（无法确定性复现） |

## 旅程五：冲突与恢复

| 步骤 | 期望 | 验证 |
| --- | --- | --- |
| 卡住后撤销自己的改动（回到已存内容） | 冲突消解：chip 清、切笔记无确认框，盘上保持 agent 版本 | 已证 `reverting to the saved content clears the stuck state`（内容跳写在门之前——无东西可写就无冲突） |
| 卡住 → 切笔记 | 确认框两档：Cancel 留守、确认丢弃离开 | 已证 `leaving a stuck note asks before discarding` |
| 卡住 → 不管它继续打字 | 每次防抖重试仍被门拦，反馈条**只在进入卡住态那一次**弹 | 已证（`_markStuck` 边沿返回值守卫；`a failed write stays stuck and says so` 同族） |
| 卡住 → 重新打开该笔记 | 即重读盘上版本（等于"丢弃本地重读"） | 已证（`_openPath` 既流，ADR-0073 测试族覆盖打开路径） |

## 旅程六：删除与写失败

| 步骤 | 期望 | 验证 |
| --- | --- | --- |
| 打开中的笔记被外部删除（干净） | **自动关闭** + 反馈条「已自动关闭」，绝不复活文件 | 已证 `a vanished note closes instead of resurrecting` |
| 写盘失败（tmp 路径被占） | 脏保留 + 反馈条一次 + chip 出现；盘上内容不动 | 已证 `a failed write stays stuck and says so`（`.tmp` 同名目录注入，dart:io 无 chmod） |
| 成功落盘 | 目录内无 tmp 残留（原子写） | 已证 `the write is atomic — no tmp residue` |

## 旅程七：离开（flush 点）

| 步骤 | 期望 | 验证 |
| --- | --- | --- |
| 切笔记（干净/脏） | 静默 flush，零确认框 | 已证 `switching notes flushes silently — the dialog is gone` |
| 注册给宿主的 flush（关窗契约） | 立即写，不等防抖 | 已证 `the registered flush writes pending edits (close gate)` |
| 窗口失焦 | flush | 已证 `window blur flushes the pending edit`（lifecycle ≠ resumed） |
| 组件卸载（切进企划扩展视图） | flush | 已证 `unmounting flushes the pending edit` |
| **关窗**（native close / 托盘退出） | preventClose → await flush → destroy | **待 macOS 真机**：`onWindowClose` 的 native 触发、Cmd+Q 是否走 close、托盘退出经 `windowManager.close()` 的拦截（widget 测试只能钉 `onRegisterFlush` 的契约） |
| **换工作区**（卡住笔记在手） | flush 尽力而为；**卡住时本地修改随切换静默丢弃**（didUpdateWidget 同步、无法弹确认） | 已知边界，登记于 ADR 后果——要闭合需把确认框提前到根切换的发起方（hero/设置页），属另一批 |

## 门禁与基线

`dart format --set-exit-if-changed lib test tool spike` 0 changed ·
`dart analyze --fatal-infos lib test tool spike` No issues ·
`dart tool/check_architecture.dart` 8 recorded, 0 new ·
`flutter test` **+1444 −1**（唯一失败 = `app_scope_test` 的 /var↔/private/var 既有基线）。

## 本批修掉的断层（TDD 先红后绿）

1. **三面往返丢 undo**（真断层）：preview→edit 无条件重建文档 → 改为仅在 buffer 与 encode 分歧时重建。
2. **Cmd+S 在 Preview 面静默失效**（反直觉）：快捷键提升为三面通用（功能上无 pending 可 flush，但快捷键不能让肌肉记忆在某一面失灵）。
3. 两个"疑似断层"经 TDD 证实**本来就是对**：新建空笔记可立即打字（解码器补空段落）、撤销回原点自动消解冲突（内容跳写在门之前）——转正为守卫测试。

---

## 走查补批（2026-10-07 第二批）：中文语境全链路 + i18n 守卫（ADR-0078）

| 步骤 | 期望 | 验证 |
| --- | --- | --- |
| zh 界面打开笔记、切面、打字 | 三面标签「编辑/源码/预览」全中文 | 已证 `zh: the whole stuck chain speaks Chinese` |
| zh 界面 agent 改写（脏） | 反馈条「笔记在盘上已被外部修改，自动保存已暂停。」+ chip「修改未写入盘」 | 已证（同上） |
| zh 界面卡住后切笔记 | 确认框「存在未写入的修改」+「丢弃并离开」+「取消」 | 已证（同上；取消留守） |
| zh 界面未选工作区 | 引导语「请先选择工作区文件夹——企划库就是工作区」 | 已证 `zh: a vault with no workspace answers with guidance` |
| 代码使用的键必须入字典 | 拼错/漏配的键在 CI 红（`planLinkPrompt` 事发） | 已证（`l10n_parity_test` 新守卫，ADR-0078） |
| `{占位符}` 两侧对齐 | zh 侧丢 `{name}` 在 CI 红 | 已证（同上，全量规则取代 ADR-0008 两键点查） |

### 本批修掉的断层与教训

1. **真缺陷（i18n）**：`planLinkPrompt` 被代码使用但两本字典都没有——链接对话框标题把字面量 "planLinkPrompt" 渲染给用户（双语皆中招）。补键 + 新守卫防复发。
2. **测试基建**：`pumpUntil`/`pumpUntilGone` 改为**超时即 fail**——静默超时把失败点推迟到三行之后，本次排障为此多绕两圈。
3. **断言真值律**：Source 面的加载断言要用 controller 真值——`find.text` 看不见 re_editor 的渲染（RichText 非默认可寻）。
4. **多 pump 调用的参数律**：测试助手带状态（locale 等）时，第二次 pump 忘传参数 = 界面静默变回英文——zh 旅程测试抓出。
