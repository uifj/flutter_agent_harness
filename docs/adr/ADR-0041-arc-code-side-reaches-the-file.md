# ADR-0041: 代码侧也要能走到那个文件

- 分类: ARC
- 优先级: P2
- 状态: ACCEPTED（2026-10-02，ADR-0039 的第二段：「还有一些相关功能值得补充到『代码』模式中」）

## 背景

ADR-0039 把「按工作区走到一次对话」做完了：历史分组、组头能展开文件树、能在文件管理器里露出那个文件夹。
剩下的问题是**进了工作台之后走不到那个文件**。参照实现 ZCode-main（`_archive_project/ZCode-main`，
`ui = packages/ui/src`）逐棵看过一遍，结论分三层，都要写下来，因为第二层和第三层是"不做"的理由。

**一、参照实现真的有、我们缺的（本 ADR 要做）**

| 上游 | 我们 |
| --- | --- |
| 文件树每行右键 7 项，含 Reveal in file manager（`ui/workspace-file-tree/WorkspaceFileTreeRowView.tsx:352-395`，`:378`） | 行菜单只有打开／复制相对路径／复制绝对路径／以此为根开树 tab（`lib/ui/workbench/tabs/file_tree_tab.dart:367-397`），**没有露出到文件管理器** |
| Git 变更行右键：Reveal in file manager · Copy absolute · Copy relative · **Reveal in file tree**（`ui/GitPaneChangeCard.tsx:127-151`） | 变更行菜单：打开编辑器／stage／discard／两种复制（`lib/ui/workbench/tabs/git_tab.dart:439-489`），**两格 reveal 都没有** |
| 跨面板协调：Git 行 → `revealPath`，展开祖先并滚到那一行（`ui/AnimatedSidePanePanel.tsx:1182,1224` → `ui/WorkspaceShellLayout.tsx:1371-1391` → `ui/workspace-file-tree/WorkspaceFileTree.tsx:285-342`） | Reducer **已经在，而且是量过的**：`lib/model/sidebar_state.dart:677-692` 的 `reveal(root, paths)` 展开祖先、并在工作区外止步，两条单测钉着（`test/sidebar_state_test.dart:623,635`）。但包装它的那枚 `WorkbenchController.reveal`（`lib/state/workbench_controller.dart:355-359`）**在生产里一个调用点都没有**——一条有人测、没人走的缝。顺带一处：`file_tree_tab.dart:120-124` 的注释写着"(`reveal`, from a tool call)"，这句话不成立，工具调用走的是 `openFile`，注释要一起改 |
| 查看器 ⋯ 菜单里的 Wrap long lines（`ui/PreviewPane.tsx:1657`） | 编辑器正文写死 `wordWrap: false`（`lib/ui/workbench/tabs/editor_tab.dart:439`）；右侧列窄，长行只能横向滚 |

**二、看起来有、其实上游没有消费者（不抄，抄了就是抄一份死代码）**

- 文件树的**重命名／新建文件／新建文件夹**：`grep -rn "rename|newFile|createFolder|mkdir" ui/workspace-file-tree/` 命中 0，上游树里根本没有这三格。
- Git 面板的 **stage／unstage／discard 行内动作**：`ui/i18n/locales/en-US.ts:1171-1174` 有词条，`unstagePaths`／`discardPaths` 无 UI 消费者，`stagePaths` 只被提交流程 `GitActionMenu.tsx:1173` 用。
  **这一格我们反而是活的**（`git_tab.dart:393-399` 的逐文件 stage/unstage 与 `:466-476` 的 discard）。
- 上游的 `PreviewPane` 是**只读查看器**：`grep "writeFile|save|editable|Monaco|CodeMirror|contentEditable"` 命中 0。我们的 `editor_tab` 能改能存（`:280-303`，`Cmd/Ctrl+S` `:428-429`，脏标记 `:372-376`，2 MiB 之上转只读并说明理由 `:85`）。
- Diff 视图的 `selectedLines`（`ui/components/ui/diff-viewer.tsx:43,46-50`）**无消费者**，也没有 open-at-line／revert-hunk 的处理器；`DIFF_VIEWER_UNSAFE_CSS` 是喂给自己的一条死旋钮（`:20,:88`）。
- Git 面板的 "last-turn" 差异源在上游自己是 `readonly: true`（`hooks/useGitRepository.ts:326`），且它读的是产品自己持久化的轮次快照，不是 git。
- 标签页 pin、面板内再分屏、工具调用完成时自动 reveal：上游都没有。我们的 tab 条反而更宽（拖拽跨面板、右键关闭族、中键关闭、浮动层：`lib/ui/workbench/workbench_tab_bar.dart:6-18`）。

**三、我们已经有等价答案，不要因为上游有同名文件就重做一遍**

- 树头搜索：`file_tree_tab.dart:316-363`（匹配模式带祖先、忽略展开集），加上 composer 的 `@` 提及走同一份工作区索引（`lib/main.dart` 接线，`lib/genkit/file_search.dart`）。
- 目录监听：上游每个展开目录一条 watch 流（`ui/terminal/../workspace-file-tree/useWorkspaceFileTreeWatchers.ts:66-85`）；这里用 agent 写入自己报的 `fsRevision` 计数刷新（`file_tree_tab.dart:97-115`，`lib/genkit/tools.dart` 写入时 bump），取舍理由就写在文件头 `:12-17`。
- 终端复制粘贴：`xterm` 4.0.0 自带键位（`~/.pub-cache/hosted/pub.dev/xterm-4.0.0/lib/src/ui/shortcut/shortcuts.dart:19-30`：`Ctrl+Shift+C`/`Cmd+C` 复制、`Ctrl+V`/`Cmd+V` 粘贴），再挂一棵右键菜单就是同一件事第二种说法。

## 决策

1. **「露出到文件管理器」的说法只有一枚键，且平台中立。** 现在它叫 `revealInFinder`（`lib/l10n/locales.dart:139,886`），
   而 `lib/host/reveal.dart` 在三个平台上分别 `open`／`explorer`／`xdg-open`。改成 `revealInFiles` =
   en "Reveal in file manager" / zh 「在文件管理器中显示」——与 ADR-0033 同一条律的反面：**文案不许对运行时做不到的事许诺**，
   在 Windows 上写 Finder 就是错的一边。五处调用点（历史组头、会话行、文件树行、git 变更行——以及它们共用的那枚键）
   共用这一枚键。不加 `Platform.isMacOS` 分支换词：三桌面目标 × 两语言的措辞矩阵不是这一轮要付的代价，中立项在三个平台上都不是错的。
2. **「露出，失败就说」只有一枚函数。** 侧栏已经把它写了两遍（`sidebar.dart:848-856` 与 `:901-909`，各五行逐字相同），
   本 ADR 再加两棵菜单就是第四、第五遍。所以先收成 `lib/ui/primitives/reveal.dart` 的
   `revealInFilesOrReport(context, path)`：它调 `lib/host/reveal.dart` 那一枚（架构规则 5 要求 `lib/ui` 不直接 `dart:io`），
   不成则 `showFeedback(…, destructive: true)` 说一声。调用点各自只剩一行。
3. **文件树行菜单加一格露出**，紧跟已有的两格复制之后。这一格会先逼出 `lib/host/reveal.dart` 的一个空白：
   它现在只认目录（`:16` 的 `Directory(path).exists()`），而树里的**文件行**和 git 变更行给的都是文件路径。
   所以同一枚函数按路径是文件还是目录分两条 argv：macOS `open -R <file>`（在 Finder 里选中它）、
   Windows `explorer /select,<file>`、Linux 退回 `xdg-open <所在目录>`——**Linux 上没有"选中"这回事**，
   这条退化写在代码注释里而不是藏在函数名下（与 ADR-0004 那条"能明说就不许暗示"同律）。
   目录一行的三条平台路径都不变。
4. **Git 变更行菜单加两格**：露出到文件管理器、**在文件树里展开**。后者不能只调 `reveal`：树 tab 没开着的时候，
   展开祖先这件事在屏幕上根本不存在，于是一格按下去什么都不发生的菜单项就是 ADR-0022 那类假开关。
   所以它是两枚现成动词的两行组合：`openFolder(workspaceRoot)`（`workbench_controller.dart:197-202`，
   以 `explorer:<abs>` 为 id，已经开着就只是把它调到前面）＋ `reveal([absolute])`。不新写第二套"展开祖先"的逻辑。
   条件是路径在工作区内（与已有的 `openEditor` 同一道 `tryResolve` 门，`git_tab.dart:449`）——工作区外的文件树上没有那行。
5. **编辑器条加一格折行开关**，状态住在 tab 自己的 State 里（和 `_preview` 同类，`editor_tab.dart:140`），
   默认不折。理由与 ADR-0022 相对：**这是一枚当场生效的开关，不落盘**——落盘就要进 `WorkbenchPrefs` 并多一条"有没有读者"要守。
6. **树里的 git 徽标不在本 ADR**：见"明确不做"。

## 后果

- 从 git 面板到一个具体文件的路线短了两格：以前"这文件改了什么"要点开 diff，"这文件在哪"只能复制路径去别处贴。
  顺带把一条**测过却没人走的缝**接上了：`SidebarState.reveal` 有两条单测，`WorkbenchController.reveal` 在生产里
  从来没有调用点（本 ADR 之前它是一枚死动词），git 行那格是它的第一个入口。
  展开祖先不等于高亮——`sidebar_state.dart:27-29` 明确没有把上游那套 transient highlight 搬过来，
  所以菜单里的说法是"展开"，不是"选中"。
- `revealInFinder` → `revealInFiles` 改掉一枚键、两处侧栏文案、一处测试字符串，并把侧栏那两遍逐字相同的
  "露出＋失败就说"收成一行调用。这是一次合并而不是新增，所以不存在第二份真值。
- 折行开关动了 `CodeEditor(wordWrap:)` 这一枚参数，不动 `DswType`／`DswShape` 任何一档，因此与放大文本那把尺子无关；
  `editor_tab_test.dart` 守的是"开关两档可分辨并且默认不折"。
- 守卫落点（都先红再绿）：
  - `test/workbench_ui_test.dart` — 树行菜单点开之后有那格露出，且它调的是 `revealInFileManager(绝对路径)`。
  - `test/git_tab_test.dart` — 用 `FakeGit.stubRepo` 那棵（真仓库会挂 30s 进程超时），变更行两格 reveal 各自到位；
    工作区外的路径不画"在文件树里展开"。
  - `test/editor_tab_test.dart` — 折行两档。
  - `test/workspace_history_test.dart` — 改名的那格文案。
  - `test/l10n_parity_test.dart` — 键两侧同时出现。

## 明确不做

- **文件树的 git 徽标与"只看变更"过滤**（上游 `WorkspaceFileTreeRowView.tsx:288,307`）。缺的不是那格像素，是**谁持有 status**：
  树 tab 现在不认识 git，git tab 每 2s 自己轮一次（`git_tab.dart:200`）。让树也去要一份，就是同一个问题两条轮询——
  ADR-0023「一处时序只有一处真值」在 git 侧的同型病。要做的前提是先把 status 变成一个被两处读的持有者
  （`lib/host/git.dart` 目前没有共享的 status 缓存），那是一件独立的事，先落观察表。
- **给文件树加 `Directory.watch`**：取舍已经写在 `file_tree_tab.dart:12-17`，本 ADR 不重开。
- **终端右键复制粘贴菜单**：见"背景三"，库已给键位。
- **上游没有消费者的那些格子**（树内重命名/新建、diff 选行、per-file history、last-turn 源）：
  不是"移植漏了"，是参照实现自己没接。要做的按新功能立 ADR，别挂在本 ADR 名下。
- **push／pull**：`lib/host/git.dart` 里没有这两条命令，而它们要凭证与远端语义，是一次独立的能力决策。
