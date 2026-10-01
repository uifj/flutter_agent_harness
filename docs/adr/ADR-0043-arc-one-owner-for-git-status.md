# ADR-0043: 一次 git status 只有一个持有者

- 分类: ARC
- 优先级: P2
- 状态: ACCEPTED（2026-10-02，用户目标里「还有一些相关功能值得补充到"代码"模式中」剩下最大的一格：文件树里的变更标记）

## 背景

**参照实现有，且是活的。** ZCode 的文件树每一行都带 git 状态：文件是字母徽标
（`_archive_project/ZCode-main/packages/ui/src/workspace-file-tree/WorkspaceFileTreeRowView.tsx:288`），
目录是"下面有变更"的聚合点（`:307`），头部还有一枚"只看变更"的开关，且**只有当 git 状态可用时才画**
（`WorkspaceFileTree.tsx:693`，`gitStatusAvailable`）。上游那份状态不是每棵视图各自去取的：
它由一个 store 持有，树与 git 面板都是读者。

**这里现在是一份私有状态。** `lib/host/git.dart` 的 `status()` 全仓库**只有一个调用点**
（`lib/ui/workbench/tabs/git_tab.dart:291`，实测 `grep -rn "\.status()" lib/` 就这一条），
结果存在 `_GitTabState._status` 里，由那棵面板自己的 2s 定时器驱动（`git_tab.dart:200`），
并且**只在这棵 tab 是 pane 的当前 tab 时才轮**（`:233-236` 的 `_visible` 门）。
文件树（`lib/ui/workbench/tabs/file_tree_tab.dart`）整棵不认识 git：它只认盘（`Directory.list`）
与 agent 写入的 `fsRevision`。所以树里的一个文件改了没改，用户只能切去 git 面板看列表，
或者右键"在文件树里展开"（ADR-0041）之后仍然看不到哪一行是脏的。

**ADR-0041 为什么不顺手做掉**：那一批的判据是"上游真的有消费者的才搬"。徽标本身有消费者，
但它要的是一份**被两个读者共享的 status**；当时若直接让树也调 `repo.status()`，就是同一个问题两条轮询、
两份 `_status`，正是 ADR-0023「一处时序只有一处真值」在 git 侧的同型病。所以那批把它写进了观察表，
本 ADR 就是那张观察表的这一条。

**一条已经存在的便利**：`badgeOf` / `isStagedEntry` / `isUntracked` 这四枚 XY 字母助手是纯函数，
已经有单测（`test/git_test.dart:67-69`），只是它们住在 git 面板的文件里——`git_tab.dart:19-22` 的注释写着
"因为它们是**这棵视图**的词汇，正如它们住在上游的 GitView.tsx 里"。这句话在只有一个读者的时候成立，
第二个读者出现时它就是 ADR-0035 那条律的反面：**一份答案要有它唯一的一处**。

## 决策

1. **status 归一个 store。** 新建 `lib/state/git_status_store.dart`：
   `GitStatusStore`（`ChangeNotifier`）按 repo root 持有一份 `GitStatusResult` + 抓取时刻，
   对外只有 `refresh(root)` / `value(root)` / `invalidate(root)`。
   并发去重：同一 root 在飞时第二个 `refresh` 等同第一个，不重跑进程。
   它住在 `lib/state/`（控制器与持久化的家），不进口 widget 树；两棵 tab 通过**已有的** `GitHost`
   （`git_tab.dart:135-152`，`InheritedWidget`，已由 `workbench.dart:186` 与 `free_window_layer.dart:86` 供好）
   拿到它——`GitHost` 多一个字段，不多造第二道缝。
2. **时序只有一处。** 2s 那一档从 git 面板的定时器里搬进 store 的一个命名常量，
   面板仍决定**什么时候需要新鲜**（它是当前 tab 时），store 决定**多久算过期**。
   文件树**永远不轮询**：它只在两种时刻要一份新的——自己第一次挂上、以及 `fsRevision` 抬过
   （agent 写过文件，这本来就是把树整棵重列的那条路，`file_tree_tab.dart:97-115`）。
   于是触发器有两个、缓存只有一份、间隔只有一个数字。
3. **XY 词汇搬到它的主人那里。** `badgeOf` / `isStagedEntry` / `isUntracked` / `isStagedEntry` 四枚纯函数
   从 `git_tab.dart` 移到 `lib/host/git.dart`（`GitStatusEntry` 就在那儿，XY 字母是它的一个性质），
   两个读者各自 import 同一处。`git_tab.dart:19-22` 那句"它们是这棵视图的词汇"要改掉，
   理由就是本 ADR 的判据。
4. **树里的画法。** 文件行右端一枚字母徽标（复用 git 面板已有的字母→颜色档位，不新造色）；
   目录行只在**其下有任一变更**时画一枚点（上游同律）；
   头部那枚"只看变更"开关**只在 store 报告这是一个 repo 且有变更时出现**（上游的 `gitStatusAvailable` 同判据），
   开启时树只列变更路径及其祖先——这与已有的搜索匹配模式是同一棵 `_matchRows` 的形状，复用它，不另写一遍。
5. **失败要说，但不能吵。** 非 repo / git 不可用时 store 缓存"没有状态"这个事实，树就一行徽标都不画；
   **不弹提示**（用户没要求 git，弹一条就是噪音）。git 面板照旧显示它自己的错误框——那是它主动要的状态。

## 后果

- 树与 git 面板第一次看同一份状态：面板里 stage 一个文件，树里那行的字母当场变（`invalidate` 由面板在
  每次动作后调一次，与它现在 `_refresh` 的位置同一条路径）。
- 多出来的成本是**打开一个有 repo 的工作区时，树会要一次 `git status`**。这是一次真实开销
  （`git status` 在大仓里百毫秒级），所以它只在树 tab 真的挂在屏上时发生，且被 store 合并；
  非 repo 目录一次 `rev-parse` 就否掉，之后不再试。
- `truncated`（超过 `gitStatusLimit` 的仓库）时树**照常画**，只是画的是截断集合里的行——
  这个不完整必须在 git 面板说（它已经说了 `gitTooManyChanges`），树不重复说。
- 守卫：`test/git_status_store_test.dart`（缓存/去重/invalidate/非 repo）、
  `test/workbench_ui_test.dart`（假 GitHost 下：变更文件有字母、干净文件没有、目录点、"只看变更"只在有变更时出现且过滤后只剩变更行）、
  `test/git_tab_test.dart`（现有 16 棵不许红——面板改读 store 之后行为不变）。
- 真机要看的：大仓里第一次打开树的停顿是否可接受、以及字母与 git 面板的字母是否读成同一件事。

## 明确不做

- **不做 stage/unstage/discard 的树内入口**：那是 git 面板的动作，树里放一份就是两个地方教同一件事
  （上游也没有）。
- **不做 HEAD 差异之外的状态**（stash、bisect、submodule）：`lib/host/git.dart` 没有这些命令，
  要加是独立能力。
- **不给树加 `Directory.watch`**：`file_tree_tab.dart:12-17` 的取舍不变，本 ADR 也不改它。
