# ADR-0040: 企划块编辑器补全（P9）——14 样式的"长相"与 Media/Other 段的插入闭环

- 分类: ARC
- 优先级: P1
- 状态: ACCEPTED（2026-10-02，用户指令"在企划模式下将 anytype 里的功能进行实现"；架构仍走 ADR-0037 不变，本 ADR 是其对照表剩余 🔨 项中块编辑器一批的施工授权）

## 背景

ADR-0037 P8 落完后的实现对照表（`docs/plan-mode-parity-table-2026-10-01.md`）里，模块 3（文档块）
还剩一批 🔨：**toggle / numbered / quote / callout 四种样式没有自己的渲染**（`plan_block_view.dart`
的 `_textStyle` 把它们全部落进 default 分支，toggle 无 chevron、numbered 无序号、quote 无高亮条、
callout 的 `iconEmoji` 从未被画出）；**书签插入后是死块**（`contentFor` 造 `PlanBookmark()` 空 url，
没有任何 URL 录入路径，AC3-9 的"URL 可编辑"半悬）；**`table(NxM)` 尺寸输入待接**
（`PlanSlashItem.parseTablePattern` 模型就绪、零调用）；**表格块列级插入/删除在 store 有、UI 无**
（`tableInsertColumn`/`tableDeleteColumn` 除测试外零调用，AC3-7 的 Cell/Row/Column 三 tab 只落了
Row）；**AC3-19 剪贴板整行 🔨**（内部块复制/粘贴没有任何实现）。

同时代码地图（2026-10-02 现场核对）确认了四个死方法：`setViewerLayout`（被 Full 版取代）、
`moveRoot`（拖拽未接）、`clearMarks`、`renameRelation` 等——它们不在本 ADR 范围，各自等对应的
P10+ 阶段。

## 决策

按 ADR-0037 的阶段纪律继续（P9，仍是一段三门禁 + 一次提交），范围**只有块编辑器**：

### P9-a 渲染词汇补全（不动模型，除一枚 setter）

1. **Toggle**：chevron 前缀 + 展开/收起。收起态是**编辑器的会话态**（`Set<String>`），不是模型
   字段——上游同样如此（子块永远在树里，折叠只是 `BlockView` 的本地状态）。收起时 `PlanBlockRow`
   跳过子行；读视图（搜索态）画同款 chevron 但不可点。
2. **Numbered**：序号在渲染层按"同层连续 numbered 块"现算（模型只存 style，盘上 `1. ` 本来就丢号）；
   编辑与读两面前缀一致。
3. **Quote**：读视图 = 左侧品牌色竖条 + `bgLayer2` 底；编辑视图同一条竖条（非所见即所得的边界内，
   给样式一个身体）。
4. **Callout**：容器（`bgLayer2` + `inner` 圆角）+ `iconEmoji` 前缀；编辑态图标可点 → 精选 emoji
   网格对话框 → 新文档方法 `setCalloutIcon`（走 `_mutate`，可撤销）。emoji 用精选集，不搬上游
   全量 emoji.json（规模差异已在对照表登记为 🔁）。
5. **读视图前缀**：checkbox 勾选框、bullet 圆点、numbered 序号在读视图照画——搜索把整篇翻成只读，
   此前那里丢掉了全部行身份。

### P9-b 插入与结构闭环

6. **书签 URL**：slash 插入 bookmark 后立即开 URL 对话框；空书签卡在编辑态可点 → 同一对话框改 URL；
   `setBookmarkUrl(blockId, url)` 落 `state: done`。无网络抓取（上游 fetching 态保留在枚举里，
   本项目无抓取管线，诚实降级）。
7. **table(NxM)**：slash 过滤输入里键入 `table(RxC)` 时浮出对应尺寸 chip，确认走
   `parseTablePattern`（夹 1–25）→ `insertTable`。
8. **表格列级菜单**：表头单元格挂一枚列操作触发器（Insert Left/Right、Delete Column），接
   `tableInsertColumn`/`tableDeleteColumn`；仅剩一列时不给 Delete（不放假条目）。菜单只挂在表头行
   （解码器保证首行带 `isHeader`；表头被删的残表诚实无列菜单）。
9. **内部剪贴板（AC3-19 第一增量）**：`PlanBlockClipboard`（state 层静态，应用内存生命周期）+
   块菜单 Copy / Paste 两项；Copy 序列化整棵子树，Paste 在锚点下方以全新 id 落副本
   （新文档方法 `pasteBlocks`）。系统剪贴板 HTML 互操作不在本增量。

### 明确不做（等后续阶段，登记不装）

- **三段落点拖拽 + 自动滚动**（AC3-18 全量）：需要"落进子级"的文档操作与拖拽 UX，独立一段。
- 文件上传管线 / 图片全屏（AC3-8 余项）、链接块外观面板（AC3-10 余项）、@提及面板、
  对象图标/封面选择器（P6 对象身份面）、WYSIWYG（要富文本依赖，需先立 ADR）。
- `toggle` 收起态不落盘：与上游一致（刷新后全展开），不属于"Markdown 装不下"问题。

## 后果

- 对照表模块 3 的 toggle/numbered/quote/callout、AC3-9、AC3-7（列级）、AC3-19（第一增量）、
  `table(NxM)` 各行从 🔨 改为已落；渲染补全不动盘上格式（quote/numbered 本就有 Markdown 形态，
  callout/toggle 继续走 `<!-- plan:{json} -->` 信封，往返契约不变）。
- **顺带修一枚同文件缺陷**：`_textContent` 对 `color`/`background` 不做保留兜底，导致打字
  （`editText`）、改对齐、设文字色都会把块级颜色/底色一并清空（上游两字段独立）。修复后
  `_textContent` 全字段保留，`setTextColor`/`setTextBackground` 直构内容以保留"传 null = 显式清空"
  的语义；`test/plan_block_document_test.dart` 既有断言（设色/清色）不变，另补"互相不清"一条。
- **放大尺子量出并当场修掉两枚座位**（工具栏 chip 36.0 对 26.0、emoji 格子 43.0 对 42.0）：
  工具栏 `_ToolbarChip` 高度改随字步（`controlMd * step`，ADR-0017 S3 一行 chrome 律）、
  emoji 格子 `44 * step`。对话框里 shad 按钮的 25.0 对 24.0 属**已登记的 ADR-0030 那族**，
  本批不动、新守卫也绕开它量（量它 today 只是重复登记）。
- 新增 i18n 键走双语同键守卫；新交互面（emoji 对话框、列菜单）挂进 `plan_blocks_test` 的两档放大尺子。
- `PlanBlockClipboard` 是进程内静态状态：跨窗口不共享、重启即空——与上游"内部块存储 + 系统剪贴板"
  的差距登记在对照表，系统剪贴板互操作另立阶段。
