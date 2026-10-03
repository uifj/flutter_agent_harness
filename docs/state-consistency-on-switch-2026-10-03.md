# 切换之后，状态必须一致（2026-10-03）

> 触发：用户两张截图。① 侧栏选中 `eplan-web / 1`，顶部条却写着 `123`；② 从顶部条那枚 `⋯` 里
> 「复制工作区路径」，粘出来的是 `/Users/uifj/Workspace/Learning/pinplan/flutter_tiptap_test`
> ——上一条对话的文件夹。
>
> 这一页不是缺陷登记，是**判据**：应用里只有两个"当前"——当前文件夹（`AppSettings.workspaceRoot`）
> 与当前对话（`SessionIndex.activeId`）。凡是读它们的表面，都必须在这两个值变化时跟着变，
> 或者写明它为什么不跟。逐条列出，是为了下一次加表面时不必重新走查整棵树。

## 1. 那两个"当前"分别由谁宣布

| 事实 | 真值在哪 | 谁改它 | 表面怎么知道它变了 |
| --- | --- | --- | --- |
| 当前文件夹 | `SettingsStore`（`ChangeNotifier`）→ `settingsDocument` provider（用 `invalidateSelf` 重发，见 `app_providers.dart:164-170`） | `AppScope.save(withWorkspace)`，唯一入口（`adoptRecent` / `pickFromHero` / 设置页） | provider 重发 → 装配它的 builder 重建 |
| 当前对话 | `SessionIndex`（`ChangeNotifier`，`activeId` / `active`） | `AppScope.openSession` / `newSession` | **只有 `sessions.addListener` 或 `ListenableBuilder(sessions)`**——provider 永远给回同一个实例，`ref.watch` 不会再发 |

**这一行表就是这次两个症状的全部原因**：`main.dart` 曾把 `ref.watch(sessionsProvider).active` 当参数递给
`AppFrame`。那是一次**装配时的读数**，而 `sessionsProvider` 永不重发（ADR-0002 的 riverpod 读缝那条笔记
说的是同一件事的另一半：函数式 provider 拿到的是同一个对象，值变了不会重跑 body）。所以：

> **律：从 ChangeNotifier 里读出来的"值"是快照；只有那个 notifier 本身是活的。**
> 需要跟随的表面要么听 notifier（`ListenableBuilder`/`addListener`），要么每次 build 现读
> （`sessions.active`）；把值当参数往下递，只有在上游会重发时才成立。

## 2. 逐表面走查（谁读哪个"当前"，跟不跟）

### 跟得上的（已核到行号）

| 表面 | 读什么 | 为什么跟 |
| --- | --- | --- |
| 侧栏会话行与选中高亮 | `sidebar.dart:287` `ListenableBuilder(widget.sessions)`，`:808` 现读 `activeId` | 两个都跟 |
| 侧栏工作区分组 | `main.dart:457-458` 从 `doc` 取 | 文件夹跟（provider 重发） |
| 窗口标题 | `window_title_service.dart:25` `sessions.addListener(_publish)` | 两个都跟（ADR-0019 ③） |
| git tab 的仓库 | `git_tab.dart:233-235` 比较 `workbench.workspaceRoot != _probedRoot` 后重开 | 文件夹跟 |
| diff tab | `diff_tab.dart:446-447` 同一条探针 | 文件夹跟 |
| 右侧详情栏 | `details_panel.dart:83` 合并 listenable，`:205` 在活节点里查调用 | 对话跟 |
| 转录列 | `conversation_root.dart:182` 听控制器 | 对话跟 |
| 草稿归属 | `composer.dart:188-210`（ADR-0051） | 对话跟 |
| 模型芯片 | `composer.dart:1442` 听 `ModelDirectory`，每次 save 重新接管（`app_scope.dart:316-323`） | 两个都跟 |
| 审批面板 / 队列条 / 企划待审卡 | `conversation_root.dart:441/487/510` 每次 build 现读控制器 getter | 对话跟 |
| 工作台布局 | `workbench_controller.dart:83-115` `bindSession` 整棵换 | 对话跟 |
| 回退路径 | `app_scope.dart:186-208` 调用时现读 `settings.value` 与 `_conversationToken` | 两个都跟 |
| 审批簿 / 回退镜像 / git 读数缓存 | `app_scope.dart:403-409` 按 root 重挂；`git_status_store.dart:37,56` 以仓库顶层为键 | 文件夹跟 |
| 企划工作台 | `plan_workspace.dart:107-121` 重载 vault 并清选择 | 文件夹跟 |
| 侧聊 tab | `sidechat_tab.dart:90-98` 宿主换了就重新订阅 | 对话跟 |

### 这次修掉的三处

1. **顶部条读快照**（`app_frame.dart`）——参数 `session` 删掉，`_header` 每棵 build 现读
   `sessions?.active`；`ListenableBuilder(listenable: sessions)` 负责触发重建。守卫
   `the header names the workspace and the conversation` 换 `setActive('s2')` 后断标题跟着换，
   并**按下**「复制工作区路径」用 `ClipboardProbe` 断粘出来的是 `/work/beta`。反向验：把读数换成
   `sessions.firstOrNull` 即红在 `Found 0 widgets with text "Ship the drawer"`。
2. **换文件夹不结束对话**（`app_scope.dart:400-431`）——ADR-0054 是"点开对话 → 走进它的文件夹"，
   反方向此前没人管：`save` 的工作区分支只重挂了审批簿与回退镜像，**没动当前对话**，于是转录留在
   上一个项目里，而工具的门、`read`/`grep`/`bash` 与 git 面板已经指向新文件夹。现在工作区变化即
   `newSession()`（旧对话仍在盘上、仍在侧栏它自己那一组里，一点就回来）。守卫
   `choosing a folder ends the conversation about the old one`。
   顺带修掉同一段里另一处：runtime 重启分支自己写了 `setActive(null)` + `bindSession(null)`
   却**没重铸未保存令牌**，下一次持久化会 `adoptConversation(旧, 新)` 把上一条对话的镜像认领过来
   ——回退卡片会提议撤销别人家的写入。现在两条分支都走同一个 `newSession()`。
3. **`@` 索引属于上一个文件夹**（`composer.dart:184-197`）——那张卡跨文件夹活着，而索引只在
   打字时取（`_onDraftChanged:380`）。现在换 root 就清缓存、抬 generation（挡住已在飞的旧响应），
   且菜单开着就当场重取。守卫 `a folder change drops the index the old folder built`
   （反向验：不清缓存即红在 `Expected: <2> Actual: <1>`）。

### 附带修掉的一处判据（因为它现在会伤人）

`adoptRecent` 与 `save` 过去比的是**原始字符串**。macOS 上 `/var/…` 与 `/private/var/…` 是同一个目录
（就是既有基线失败 `app_scope_test` 那一对）。以前拼法不同只是"多存一次"，现在它会**结束对话**——
所以判断改用 `model/session_groups.dart` 已有的 `workspaceKey`（侧栏分组用的同一个答案）。
守卫 `one folder spelled two ways is still one folder`。
**没做**的更彻底一步：把盘上存的 root 统一成解析后的拼法（那要动 settings 的写侧与既有文档，
另立 ADR）。

## 3. 看过但这次不改的，以及为什么

| 现象 | 证据 | 判词 |
| --- | --- | --- |
| 换文件夹后，**上一会话**的编辑器 tab 仍显示旧项目的文件、保存报"无法保存" | `editor_tab.dart:166-179` 内容只在 initState 载入；`file_tree_tab.dart:170` 的 `_root` 优先用 tab 自己钉的路径 | 不改：布局按会话绑定（`bindSession`），而 §2 的第 2 项已经让"换文件夹"必然换会话——回到那条对话时它的 tab 与它自己的文件夹一起回来，这才是自洽的 |
| 已开着的 shell 停在上一个目录 | `terminal_manager.dart:219-220` 重挂时忽略 `workingDirectory`；`terminal_tab.dart:150-173` 只在会话换了时重挂 | 不改：活进程的 cwd 不是 UI 能改的（任何终端都一样），要新目录就开新 shell。写在这里是为了别把它当 bug 修 |
| 顶部条的分支/提交信息在别处 `git checkout` 之后不刷新 | `composer.dart:216` 只在挂载与 root 变化时探针 | 另案：触发条件不是"切换"，属 ADR-0043 那条"改了工作树就要 invalidate"的延伸，要动先补登记 |
| 设置页的用量数字一次运行内不动 | `main.dart:106/140` 把启动时的 `UsageLedger.summarize` 用 `overrideWithValue` 钉住，而 AppScope 写的是另一个 ledger 实例（`app_scope.dart:60`） | 另案：这是"启动快照当实时值"，与切换无关，但同一族病（值没有读者/读者不重取），要修先立 ADR |
| 子代理 dock 的选中项在换会话后落空 | `subagent_tab.dart:192,211-219` 只在宿主实例换了时清 `_selected`，而宿主永不换 | 低：不会显示错数据，只是选中丢失；记此，遇到再收 |

## 4. 下一次加表面时要问的两句话

1. 它读的是**当前文件夹**还是**当前对话**？两者的宣布方式不同（§1 表最后一列），别混用。
2. 它是**每棵 build 现读**、**听了 notifier**，还是**在装配时收了一个值**？第三种只在上游会重发时成立——
   `SettingsStore` 会，`SessionIndex` 的 provider 不会。

守卫的写法照 `test/app_frame_test.dart` 那条：换值之后**断言屏幕上出现的是新值**，并且
**按下**那个动作、验它真的作用在新对象上（`ClipboardProbe`），不是断"回调被接住了"。
