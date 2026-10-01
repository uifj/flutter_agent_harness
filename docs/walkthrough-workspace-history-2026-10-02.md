# 走查页：按工作区划分的历史 + 代码侧走到文件（2026-10-02）

ADR-0039 / ADR-0041 / ADR-0042 三批改动的**真机签收单**。只列这台机器证不了的事：
每条都是"眼睛/键盘/操作系统"那一类，widget 测试已经证过的部分写在最后一列，**不必重复检查**。

用法：按顺序走，一格一行；不通过就在那格后面写一句现象（哪一档亮度、什么窗口宽），
我按现象立 ADR 再改。全绿之后把 ADR-0039 从 IN-PROGRESS 改 RESOLVED，并回填这一页的链接。

## 1. 侧栏的历史（ADR-0039）

| # | 步骤 | 应当看到 | 已由测试证过 |
| --- | --- | --- | --- |
| 1.1 | 打开两个不同文件夹各起 2–3 次会话，回到侧栏 | 一个文件夹一个组头，当前工作区那组排第一；组头是 `文件夹字形 + 名字`，会话行缩进一级 | `workspace_history_test`「one folder per header」「the folder the user is in leads」 |
| 1.2 | 亮/暗两档各看一次组头与行 | 组头底色与行底色不同档；选中行是整条圆角高亮，hover 只是加深一档，两者可分辨 | `sidebar_test`「the active row is marked by shape and semantics, not only wash」（读的是行自己的 `Semantics.selected`，两态取不同令牌这条没有机器证明——纯观感） |
| 1.3 | 点组头折叠，再点展开；然后 `⋮` → 全部收起 / 全部展开 | 折叠只留表头不建行；整列仍可滚动，页脚钉在底部；**放大字号时列表不会被挤到 0 高** | `a folded group keeps its header and builds no rows`、`collapse all…`、侧栏放大文本两档 |
| 1.4 | 右键任意一行 | 六项：置顶/取消置顶、重命名、复制会话 id、复制工作区路径、在文件管理器中显示、删除 | `a conversation right-click can pin, rename and delete` |
| 1.5 | 置顶一条 → 重启应用 | 它仍在组内最前；相对时间从 `刚刚` 依次变 `59分`/`23天` | `a pinned conversation sits above a newer one`、`relative_time_test` 四档边界 |
| 1.6 | 删除一条 | 行消失、弹一条"已从列表移除该会话"；**盘上快照还在**（`<support>/sessions/…` 未被动过），重启后仍不在列表里 | `deleting a row leaves the snapshot listing alone` |
| 1.7 | 组头 `⋮` 四格逐一点 | 显示文件树 → 右栏开出该文件夹的树；复制工作区路径 → 粘出来是那个绝对路径；在文件管理器中显示 → Finder 真的打开；从列表中移除 → 只少这一组，会话还在 | 前三格由 `the group menu offers the tree, the path, the reveal and the removal` 守住（剪贴板读的是值本身）；**Finder 真打开只能你看** |
| 1.8 | 老会话（这次改动之前建的） | 落在最末一档「未归属」，不丢、不报错 | `a session with no folder lands in the unassigned bucket` |
| 1.9 | 侧栏收起成 rail，再展开 | 收起时 rail 上没有一个字；展开后分组原样回来（淡入未 settle 时点在空气上——测试里踩过，所以真机请慢一点） | `both forms carry a working collapse control` |
| 1.10 | macOS 系统设置里把文字调大（四档各一次） | 组头、行、时间列都不被裁；整列还能滚到最后一行 | 两档（1.8x/2.2x）机器量过；**四档真机没量过** |

## 2. 代码侧走到文件（ADR-0041）

| # | 步骤 | 应当看到 |
| --- | --- | --- |
| 2.1 | 右栏文件树里右键一个**文件** → 在文件管理器中显示 | Finder 打开它的所在文件夹并**选中这个文件**（macOS 走 `open -R`） |
| 2.2 | 同样右键一个**文件夹** | 直接打开那个文件夹 |
| 2.3 | 把窗口拉到 Windows/Linux 上试 2.1（若你在别的机器） | Windows `/select,` 选中；**Linux 只会打开所在目录、不选中**——这是明说的退化，不是 bug |
| 2.4 | git 面板右键一条变更 → 在文件树里展开 | 右栏出现（或聚焦）工作区的文件树 tab，并展开到那个文件所在的目录；树 tab 被关掉时这一格**不出现**（不是按下去没反应） |
| 2.5 | 编辑器条上那枚折行图标 | 长行在窄列里折起来；再点回原样；markdown 切到预览时这枚图标消失（预览本来就折行） |

## 3. 备份与恢复（ADR-0042，顺手一起走）

| # | 步骤 | 应当看到 |
| --- | --- | --- |
| 3.1 | 设置 → 备份，导出 zip | 成功提示带文件数；zip 里有 `sessions/sessions.json` 与 `sessions/global/.pointers/…` |
| 3.2 | 换一台机器（或先删掉支持目录）导入那份 zip | 分组、置顶、改名、墓碑都回来 |
| 3.3 | 用归档工具把某个条目改名成 `../../evil.txt` 再导入 | **整次恢复都不落地**并弹一条失败提示；`~/` 下不应出现 `evil.txt`，应用数据也不应被半改 |

## 4. 还没做、等你点的候选（都带判据，不是待修 bug）

- **文件树里的 git 徽标 / 只看变更**：缺的不是那格像素，是一个 `git status` 的持有者——现在 git tab 自己 2s 一轮，
  树再去要一份就是同一个问题两条轮询（ADR-0023 那条律在 git 侧的同型病）。要做就先立"status 归谁"的 ADR。
- **对话流的"全部展开/收起工具卡"与卡内搜索**：上游有（`ModelTrajectoryPane` 头部那排），
  但它那棵的正文要读服务端持久化的 transcript 目录，我们只有一半可搬。要哪一半请点一下。
- **窄窗胶囊的三条出口**（最小窗口宽 / 改吃 `constraints` / 接受为文档化退化）：仍无人拍板，
  所以窄窗守卫只跑到 1.8x。
- **树内重命名 / 新建文件 / 新建文件夹**：上游 `workspace-file-tree/` 里 grep `rename|newFile|createFolder|mkdir` 命中 0，
  它自己没接——要做是**新功能**（要写盘、要审批、要 i18n），不是"移植漏了"。
