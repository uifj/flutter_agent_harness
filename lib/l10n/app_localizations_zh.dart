// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '企划星';

  @override
  String get close => '关闭';

  @override
  String get cancel => '取消';

  @override
  String get retry => '重试';

  @override
  String get restart => '重启';

  @override
  String get refresh => '刷新';

  @override
  String get save => '保存';

  @override
  String get saving => '保存中…';

  @override
  String get saved => '已保存';

  @override
  String get preview => '预览';

  @override
  String get reload => '从磁盘重新加载';

  @override
  String get reloadDirtyTitle => '放弃未保存的编辑？';

  @override
  String reloadDirtyDesc(String path) {
    return '从磁盘重新加载「$path」将丢弃未保存的编辑。';
  }

  @override
  String get settings => '设置';

  @override
  String get openSettings => '打开设置';

  @override
  String get quickPreferences => '快捷偏好设置';

  @override
  String get untitled => '未命名';

  @override
  String get loading => '加载中…';

  @override
  String get confirm => '确认';

  @override
  String get remove => '移除';

  @override
  String get explorer => '资源管理器';

  @override
  String get terminal => '终端';

  @override
  String get git => '源代码管理';

  @override
  String get subagents => '子代理';

  @override
  String get editor => '编辑器';

  @override
  String get newTab => '新建标签页';

  @override
  String get splitDown => '向下分栏';

  @override
  String get splitRight => '向右分栏';

  @override
  String get closeOthers => '关闭其他';

  @override
  String get closeAll => '关闭全部';

  @override
  String get sendToSidePanel => '发送到侧边面板';

  @override
  String get sendToBottomPanel => '发送到底部面板';

  @override
  String get floatInWindow => '悬浮为窗口';

  @override
  String get dockToSidebar => '回到侧边栏';

  @override
  String unknownTabType(String type) {
    return '此版本无法展示「$type」标签页。';
  }

  @override
  String terminalN(String n) {
    return '终端 $n';
  }

  @override
  String get browser => '浏览器';

  @override
  String get browserBack => '后退';

  @override
  String get browserForward => '前进';

  @override
  String get browserGo => '前往';

  @override
  String get browserPlaceholder => '搜索或输入地址';

  @override
  String get browserOpenExternal => '在默认浏览器中打开';

  @override
  String get browserInvalid => '这不是一个有效的地址。';

  @override
  String get browserBlockedScheme => '只能打开 http 和 https 地址。';

  @override
  String get browserBlockedLoopback => '本地地址已被拒绝。';

  @override
  String get browserStart => '在上方输入地址开始浏览。';

  @override
  String get browserUnsupported => '当前平台不支持内置浏览器。';

  @override
  String get sidechat => '边侧对话';

  @override
  String get sideChatNew => '新建边侧对话';

  @override
  String get sideChatEmpty => '主对话旁的轻量对话。';

  @override
  String get sideChatEmptyDesc => '不打扰主线程的快速提问。';

  @override
  String get sideChatNoModel => '在设置中连接模型后可在此对话。';

  @override
  String get sideChatPlaceholder => '问点什么…';

  @override
  String get sideChatThinking => '思考中…';

  @override
  String get filesOpenHere => '文件在这里打开。';

  @override
  String get clickToOpenFiles => '点击在此窗格中打开文件。';

  @override
  String get openWorkbenchPanel => '打开工作台面板';

  @override
  String get collapseWorkbenchPanel => '折叠工作台面板';

  @override
  String get openBottomPanel => '打开底部面板';

  @override
  String get collapseBottomPanel => '折叠底部面板';

  @override
  String openSidebar(String accel) {
    return '展开侧边栏（$accel）';
  }

  @override
  String collapseSidebar(String accel) {
    return '折叠侧边栏（$accel）';
  }

  @override
  String get newSession => '新会话';

  @override
  String get sessions => '会话';

  @override
  String get planMode => '企划';

  @override
  String get agentMode => '代理';

  @override
  String get noSessionsYet => '暂无会话';

  @override
  String get workspaces => '工作区';

  @override
  String get unassignedWorkspace => '未归属';

  @override
  String get historyView => '历史视图';

  @override
  String get groupByWorkspace => '按工作区分组';

  @override
  String get flatList => '平铺列表';

  @override
  String get workspaceActions => '工作区操作';

  @override
  String get conversationActions => '对话操作';

  @override
  String get newSessionHere => '新建会话';

  @override
  String get showFileTree => '显示文件树';

  @override
  String get removeWorkspace => '从列表中移除';

  @override
  String get removeWorkspaceHint => '不删除它的任何会话';

  @override
  String get renameSession => '重命名';

  @override
  String get pinSession => '置顶';

  @override
  String get unpinSession => '取消置顶';

  @override
  String get deleteSession => '删除';

  @override
  String get copySessionId => '复制会话 id';

  @override
  String get copyWorkspacePath => '复制工作区路径';

  @override
  String get revealInFiles => '在文件管理器中显示';

  @override
  String get revealInTree => '在文件树里展开';

  @override
  String get pinned => '已置顶';

  @override
  String get renameSessionTitle => '重命名会话';

  @override
  String get deleteSessionTitle => '删除这个会话？';

  @override
  String get deleteSessionBody => '会话仍留在磁盘上，只是不再出现在列表里。';

  @override
  String get sessionDeleted => '已从列表移除该会话';

  @override
  String get revealFailed => '打不开那个位置';

  @override
  String get historyNotSaved => '改动已生效，但没能存盘';

  @override
  String get addWorkspace => '添加文件夹';

  @override
  String get expandAll => '全部展开';

  @override
  String get collapseAll => '全部收起';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(String n) {
    return '$n分';
  }

  @override
  String hoursAgo(String n) {
    return '$n小时';
  }

  @override
  String daysAgo(String n) {
    return '$n天';
  }

  @override
  String get openDetailsPanel => '打开详情面板';

  @override
  String get closeDetailsPanel => '关闭详情面板';

  @override
  String get askAnything => '随便问点什么';

  @override
  String get askAnythingHint => '输入问题，或描述一个任务';

  @override
  String get queueDraftHint => '继续输入，会排在当前这轮之后';

  @override
  String get heroSubtitle => '随时提问，或打开工作区开始探索';

  @override
  String get workspaceStatusBar => '工作区状态栏';

  @override
  String get localRepo => '本地';

  @override
  String get planNoWorkspace => '请先选择工作区文件夹——企划库就是工作区';

  @override
  String get planNoNoteSelected => '从目录树中选择一个 Markdown 文件';

  @override
  String get planNotes => '笔记';

  @override
  String get seedDeliveryBoard => '交付看板';

  @override
  String get seedReadingInbox => '阅读收件箱';

  @override
  String get seedViewBoard => '看板';

  @override
  String get seedViewAllTasks => '全部任务';

  @override
  String get seedViewOpenOnly => '仅打开';

  @override
  String get seedViewCards => '卡片';

  @override
  String get seedViewCalendar => '日历';

  @override
  String get seedViewGraph => '图谱';

  @override
  String get seedViewList => '列表';

  @override
  String get seedViewTable => '表格';

  @override
  String get seedRelStatus => '状态';

  @override
  String get seedRelTags => '标签';

  @override
  String get seedRelEffort => '工作量';

  @override
  String get seedRelDue => '截止';

  @override
  String get seedOptTodo => '待办';

  @override
  String get seedOptDoing => '进行中';

  @override
  String get seedOptBlocked => '受阻';

  @override
  String get seedOptShipped => '已发布';

  @override
  String get seedOptUrgent => '紧急';

  @override
  String get seedOptClient => '客户';

  @override
  String get seedOptInternal => '内部';

  @override
  String get planNoNotes => '此工作区暂无 Markdown 文件';

  @override
  String get planPreview => '预览';

  @override
  String get planSource => '源码';

  @override
  String get planStuckChip => '修改未写入盘';

  @override
  String get planStuckTitle => '存在未写入的修改';

  @override
  String get planStuckDesc => '盘上的文件没有收到这些修改（可能已被外部改动）。现在离开将丢弃它们。';

  @override
  String get planStuckConfirm => '丢弃并离开';

  @override
  String get planExternalChanged => '笔记在盘上已被外部修改，自动保存已暂停。';

  @override
  String get planNoteVanished => '笔记已从盘上被移除，已自动关闭。';

  @override
  String get planSaveFailed => '笔记保存失败。';

  @override
  String get planNewNote => '新建笔记';

  @override
  String get planNewFolder => '新建文件夹';

  @override
  String get planNewNoteHint => '文件名（不含 .md）';

  @override
  String get planNewFolderHint => '文件夹名';

  @override
  String get planCreate => '创建';

  @override
  String get planCancel => '取消';

  @override
  String get planEditorEdit => '编辑';

  @override
  String get planEditorSource => '源码';

  @override
  String get planEditorPreview => '预览';

  @override
  String get planAddBlock => '添加块';

  @override
  String get planBlockMenu => '块操作';

  @override
  String get planBlockToc => '目录';

  @override
  String get planBlockRelation => '关系';

  @override
  String get planBlockFeatured => '置顶属性';

  @override
  String get planBlockWidget => '组件';

  @override
  String get planBlockUnsupported => '不支持的块';

  @override
  String get planFileUploading => '上传中…';

  @override
  String get planFileError => '文件加载失败';

  @override
  String get planFileEmpty => '空文件';

  @override
  String get planBookmarkEmpty => '空书签';

  @override
  String get planBookmarkFetching => '获取中…';

  @override
  String get planBookmarkError => '书签加载失败';

  @override
  String get planBookmarkPrompt => '书签 URL';

  @override
  String get planBlockToggle => '展开或折叠';

  @override
  String get planCalloutIcon => '标注图标';

  @override
  String get planEmbedOpen => '可在外部打开';

  @override
  String get planEmbedUnavailable => '此处不可用';

  @override
  String get planTableActions => '行操作';

  @override
  String get planColumnMenu => '列操作';

  @override
  String get planTableInsertAbove => '上方插入行';

  @override
  String get planTableInsertBelow => '下方插入行';

  @override
  String get planTableMoveUp => '上移行';

  @override
  String get planTableMoveDown => '下移行';

  @override
  String get planTableDuplicate => '复制行';

  @override
  String get planTableClear => '清空行';

  @override
  String get planTableDelete => '删除行';

  @override
  String get planTableInsertLeft => '左侧插入列';

  @override
  String get planTableInsertRight => '右侧插入列';

  @override
  String get planTableDeleteColumn => '删除列';

  @override
  String get planActionCopy => '复制';

  @override
  String get planActionPaste => '粘贴';

  @override
  String get planActionDrag => '拖动移动';

  @override
  String get planLinkOpen => '打开链接';

  @override
  String get planLinkPrompt => '链接 URL';

  @override
  String get planLinkRemoveHint => '留空则移除链接';

  @override
  String get planLinkFailed => '打不开那个链接';

  @override
  String get planActionDuplicate => '创建副本';

  @override
  String get planActionDelete => '删除';

  @override
  String get planSearchInDoc => '文内搜索';

  @override
  String get planSearchNext => '下一个匹配';

  @override
  String get planSearchPrevious => '上一个匹配';

  @override
  String get planSearchCancel => '停止搜索';

  @override
  String get planStyleLabel => '样式';

  @override
  String get planColourLabel => '文字颜色';

  @override
  String get planColourBackground => '背景颜色';

  @override
  String get planAlignLabel => '对齐';

  @override
  String get planSlashPlaceholder => '输入以筛选…';

  @override
  String get planEditorUndo => '撤销';

  @override
  String get planEditorRedo => '重做';

  @override
  String get planAlignLeft => '左对齐';

  @override
  String get planAlignCenter => '居中';

  @override
  String get planAlignRight => '右对齐';

  @override
  String get planSlashText => '文本';

  @override
  String get planSlashTitle => '标题';

  @override
  String get planSlashHeading => '一级标题';

  @override
  String get planSlashSubheading => '二级标题';

  @override
  String get planSlashHighlighted => '高亮块';

  @override
  String get planSlashCallout => '标注';

  @override
  String get planSlashCheckbox => '勾选';

  @override
  String get planSlashBulleted => '无序列表';

  @override
  String get planSlashNumbered => '有序列表';

  @override
  String get planSlashToggle => '折叠';

  @override
  String get planSlashFile => '文件';

  @override
  String get planSlashPicture => '图片';

  @override
  String get planSlashVideo => '视频';

  @override
  String get planSlashBookmark => '书签';

  @override
  String get planSlashCode => '代码';

  @override
  String get planSlashLine => '分隔线';

  @override
  String get planSlashDots => '三点分隔';

  @override
  String get planSlashToc => '目录';

  @override
  String get planSlashTable => '简单表格';

  @override
  String get planAllContentTitle => '全部内容';

  @override
  String get planTabPages => '页面';

  @override
  String get planTabLists => '集合';

  @override
  String get planTabMedia => '媒体';

  @override
  String get planTabBookmarks => '书签';

  @override
  String get planTabFiles => '文件';

  @override
  String get planModeAllContent => '全部内容';

  @override
  String get planModeUnlinked => '未链接';

  @override
  String get planGroupToday => '今天';

  @override
  String get planGroupYesterday => '昨天';

  @override
  String get planGroupPrevious7Days => '过去 7 天';

  @override
  String get planGroupPrevious14Days => '过去 14 天';

  @override
  String get planGroupMonth => '本月';

  @override
  String get planGroupMonthAndYear => '今年早些时候';

  @override
  String get planGroupOlder => '更早';

  @override
  String get planSortCreated => '创建日期';

  @override
  String get planSortModified => '修改日期';

  @override
  String get planSortName => '名称';

  @override
  String get planSortLastUsed => '最近使用';

  @override
  String get planAllContentEmpty => '暂无内容';

  @override
  String get planSegmentFeatured => '置顶属性';

  @override
  String get planSegmentLocal => '本地属性';

  @override
  String get planSegmentHidden => '隐藏属性';

  @override
  String get planFeature => '加入置顶';

  @override
  String get planUnfeature => '移出置顶';

  @override
  String get planHide => '隐藏属性';

  @override
  String get planUnhide => '取消隐藏';

  @override
  String get planRemoveRelation => '从对象移除';

  @override
  String get planRelationRemoved => '属性已移除';

  @override
  String get planRelationActions => '属性操作';

  @override
  String get planAddRelation => '添加属性';

  @override
  String get planNewCollection => '新建集合或查询';

  @override
  String get planKindCollection => '集合';

  @override
  String get planKindSet => '查询';

  @override
  String get planKindSetSource => '来源类型（记录随创建进入）';

  @override
  String get planCollectionCreated => '已创建';

  @override
  String planTemplatesTitle(String name) {
    return '模板 · $name';
  }

  @override
  String get planTemplatesNotAllowed => '该类型不使用模板';

  @override
  String get planTemplatesEmpty => '还没有模板——新记录从空白开始';

  @override
  String get planTemplateNew => '新建模板';

  @override
  String get planTemplateNewName => '未命名模板';

  @override
  String get planTemplateSetDefault => '设为默认';

  @override
  String get planTemplateDuplicate => '复制';

  @override
  String get planTemplateDelete => '删除';

  @override
  String get planTemplateDeleted => '模板已删除';

  @override
  String get planTemplateDefault => '默认';

  @override
  String get planDateToday => '今天';

  @override
  String get planDateYesterday => '昨天';

  @override
  String get planDateTomorrow => '明天';

  @override
  String get planDateNoObjects => '这一天没有对象';

  @override
  String get planGalleryTitle => '扩展';

  @override
  String get planGalleryInstall => '安装';

  @override
  String get planGalleryInstalling => '安装中…';

  @override
  String planGalleryDone(String name) {
    return '已安装为 $name';
  }

  @override
  String get planGalleryInstalled => '安装完成';

  @override
  String get planGalleryUnsupported => '此工作区放不下该模板包';

  @override
  String get planSectionPinned => '已固定';

  @override
  String get planSectionFavorites => '我的收藏';

  @override
  String get planSectionRecent => '最近编辑';

  @override
  String get planSectionTypes => '对象类型';

  @override
  String get planWidgetMenu => '组件操作';

  @override
  String get planWidgetEmpty => '暂无内容';

  @override
  String get planWidgetFavorites => '收藏';

  @override
  String get planWidgetRecent => '最近编辑';

  @override
  String get planWidgetBin => '回收站';

  @override
  String get planWidgetAllObjects => '全部对象';

  @override
  String get planWidgetTypes => '对象类型';

  @override
  String get planWidgetChangeType => '更改组件类型';

  @override
  String get planWidgetRemove => '移除组件';

  @override
  String get planWidgetRemoved => '组件已移除';

  @override
  String get planWidgetEmptyBin => '清空回收站';

  @override
  String get planWidgetBinEmptied => '回收站已清空';

  @override
  String get planWidgetChangeHome => '更改主页';

  @override
  String get planWidgetCreateObject => '按类型创建对象';

  @override
  String get planSlashStyle => '样式';

  @override
  String get planSlashMedia => '媒体';

  @override
  String get planSlashOther => '其他';

  @override
  String get planSlashObjects => '对象';

  @override
  String get planSlashObjectsEmpty => '对象段随对象库（P6）到达';

  @override
  String get planSlashProperties => '属性';

  @override
  String get planSlashPropertiesEmpty => '属性段随对象库（P6）到达';

  @override
  String get planSlashActions => '操作';

  @override
  String get planSlashInsertBelow => '在下方插入';

  @override
  String get planOpenCollection => '打开一个集合';

  @override
  String get planFileNameExists => '同名文件已存在';

  @override
  String get planFolderNameExists => '同名文件夹已存在';

  @override
  String get planSwitchWorkspace => '切换工作区';

  @override
  String get planExtensions => '扩展';

  @override
  String get planBoard => '看板';

  @override
  String get planCalendar => '日程';

  @override
  String get planTable => '表格';

  @override
  String get planAddTask => '添加';

  @override
  String get planTaskTitleHint => '新任务标题';

  @override
  String get planTaskDateHint => 'yyyy-mm-dd';

  @override
  String get planGroupTodo => '待办';

  @override
  String get planGroupInProgress => '进行中';

  @override
  String get planGroupReview => '评审';

  @override
  String get planGroupDone => '完成';

  @override
  String get planColumnStatus => '状态';

  @override
  String get planColumnTask => '任务';

  @override
  String get planColumnDue => '截止';

  @override
  String get planNoDue => '—';

  @override
  String get chooseWorkspaceFolder => '选择工作区文件夹';

  @override
  String get chooseAFolder => '选择文件夹…';

  @override
  String get send => '发送';

  @override
  String get stop => '停止';

  @override
  String get deepDiving => '深入思考中...';

  @override
  String get inputQueue => '等待发送';

  @override
  String get queueInput => '排队';

  @override
  String get guideNow => '转向';

  @override
  String get deliveryQueue => '本轮结束后';

  @override
  String get deliveryGuide => '转向本轮';

  @override
  String get dragToReorder => '拖拽改序';

  @override
  String get rewindPill => '撤销这次写入';

  @override
  String get rewindTitle => '回到这次写入之前？';

  @override
  String get rewindConfirm => '回到之前';

  @override
  String get rewindNothing => '没有可以撤销的内容。';

  @override
  String get rewindRestores => '将恢复';

  @override
  String get rewindDeletes => '将删除';

  @override
  String get rewindSkips => '保持不变';

  @override
  String get rewindWhyChanged => '在代理之外被修改';

  @override
  String get rewindWhyNoImage => '未保存改动前的内容';

  @override
  String get attachImage => '添加图片';

  @override
  String get attach => '附件';

  @override
  String get chooseImages => '选择图片文件…';

  @override
  String get chooseDocuments => '附加文档（PDF、文本）…';

  @override
  String get pasteImage => '从剪贴板粘贴图片';

  @override
  String get pasteImageFailed => '剪贴板中没有图片。';

  @override
  String imagesUnsupportedByModel(String model) {
    return '「$model」不支持图片。请改用附加文档，或在模型菜单里选择支持视觉的模型。';
  }

  @override
  String get removeAttachment => '移除';

  @override
  String get dropFilesHint => '拖放图片以添加附件';

  @override
  String get askEveryTime => '每次询问';

  @override
  String get askEveryTimeDesc => '代理在写入或执行命令前会中断并请求批准。';

  @override
  String get planFirst => '先做计划';

  @override
  String get planFirstDesc => '计划批准前只读；代理不能做任何更改。';

  @override
  String get autoRun => '自动执行';

  @override
  String get autoRunDesc => '受限工具直接运行、不再询问。确认可信时使用。';

  @override
  String get approvalMode => '批准模式';

  @override
  String get commandHint => '输入 / 唤出命令';

  @override
  String get commands => '命令';

  @override
  String get files => '文件';

  @override
  String get searchingFiles => '正在搜索工作区…';

  @override
  String get commandNewSession => '开始新会话';

  @override
  String get quickPhrases => '快捷短语';

  @override
  String get messageCopyText => '复制文本';

  @override
  String get messageExportMd => '导出为 Markdown';

  @override
  String get messageExportTxt => '导出为纯文本';

  @override
  String get commandCopyTranscript => '复制整段对话';

  @override
  String get commandCopyTranscriptDesc => '按顺序复制全部用户与助手消息到剪贴板';

  @override
  String get preRestoreTitle => '恢复前快照';

  @override
  String get preRestoreDesc => '每次恢复前，将被覆盖的文件先复制到这里。保留最近 3 份。';

  @override
  String get settingsCards => '指令卡';

  @override
  String get settingsCardsIntro => '写一次、按需启用的提示词卡；启用的卡片会随工作区指令一起注入。';

  @override
  String get cardAdd => '新建卡片';

  @override
  String get cardDelete => '删除卡片';

  @override
  String get cardTitleHint => '卡片标题';

  @override
  String get cardTextHint => '要注入的提示词文本';

  @override
  String get cardsEmpty => '还没有卡片。';

  @override
  String get settingsTasks => '定时任务';

  @override
  String get settingsTasksIntro => '应用开启期间按计划运行的提示词；需要用户应答的任务会判为失败并等下一个计划分钟。';

  @override
  String get taskAdd => '新建任务';

  @override
  String get taskDelete => '删除任务';

  @override
  String get taskNameHint => '任务名称';

  @override
  String get taskPromptHint => '要运行的提示词';

  @override
  String get taskHourHint => '时';

  @override
  String get taskMinuteHint => '分';

  @override
  String taskWeekday(String n) {
    return '周$n';
  }

  @override
  String get tasksEmpty => '还没有任务。';

  @override
  String get settingsEnvironment => '环境变量';

  @override
  String get settingsEnvironmentIntro =>
      '注入 shell 命令，以 \$NAME 引用。值保存在钥匙串，并会从展示给模型的命令输出中脱敏。';

  @override
  String get envAdd => '新建变量';

  @override
  String get envDelete => '删除变量';

  @override
  String get envNameHint => '变量名（字母、数字、下划线）';

  @override
  String get envValueHint => '值——存入钥匙串';

  @override
  String get settingsPhrases => '快捷短语';

  @override
  String get settingsPhrasesIntro => '输入卡光标处一键插入的常用话术。最多 20 条。';

  @override
  String get quickPhraseAdd => '新建短语';

  @override
  String get quickPhraseDelete => '删除短语';

  @override
  String get quickPhraseFull => '列表已满——先删除一条才能再添加。';

  @override
  String get quickPhraseTitleHint => '菜单标题';

  @override
  String get quickPhraseTextHint => '要插入的文本';

  @override
  String get commandCompress => '压缩当前会话';

  @override
  String get commandCompressDesc => '总结后在新会话中继续，新会话记得这份摘要';

  @override
  String get compressStarted => '正在压缩…';

  @override
  String get compressDone => '已压缩。摘要将随你的下一条消息带入。';

  @override
  String get compressFailed => '压缩失败。会话保持不变。';

  @override
  String get commandNewSessionDesc => '当前会话保留在磁盘上，另起一个全新会话。';

  @override
  String get commandAskMode => '切换到询问模式';

  @override
  String get commandAskModeDesc => '每个受限调用都会中断等待批准。';

  @override
  String get commandPlanMode => '切换到计划模式';

  @override
  String get commandPlanModeDesc => '计划批准之前，工作区只读。';

  @override
  String get commandAutoMode => '切换到自动模式';

  @override
  String get commandAutoModeDesc => '受限工具不再询问直接运行。';

  @override
  String get waitingForApproval => '等待批准';

  @override
  String approvalTitle(String name) {
    return '工具 $name 请求特权执行';
  }

  @override
  String get askUserStrip => 'Agent 需要你的输入';

  @override
  String get askUserOther => '其他——直接输入';

  @override
  String get askUserSkip => '跳过';

  @override
  String get askUserSkipped => '已跳过';

  @override
  String get askUserOpenHint => '输入你的回答';

  @override
  String get askUserSubmit => '提交回答';

  @override
  String get reject => '拒绝';

  @override
  String get allowOnce => '仅此一次';

  @override
  String get alwaysAllow => '总是允许';

  @override
  String get approvalsTitle => '批准规则';

  @override
  String get approvalsNote => '你曾放行的命令与路径，agent 之后不再询问。仅对当前文件夹生效。';

  @override
  String get approvalsEmpty => '此文件夹没有已保存的批准。';

  @override
  String get approvalAllowed => 'agent 可以不再询问直接执行';

  @override
  String get approvalDenied => '不再询问，也永不放行';

  @override
  String get forgetWorkspaceApprovals => '移除当前文件夹的全部规则';

  @override
  String get oneReplacement => '1 处替换';

  @override
  String nReplacements(String n) {
    return '$n 处替换';
  }

  @override
  String get overwritesExistingFile => '将覆盖已有文件';

  @override
  String inWorkdir(String dir) {
    return '在 $dir 中';
  }

  @override
  String get planReviewHeader => '计划审批';

  @override
  String get planDiscuss => '继续讨论';

  @override
  String get planDecline => '否决';

  @override
  String get planApprove => '批准';

  @override
  String get planApprovedMessage => '计划已批准，请按计划执行。';

  @override
  String get planDeclinedMessage => '计划已被否决，请修改计划。';

  @override
  String get details => '详情';

  @override
  String get closeDetails => '关闭详情';

  @override
  String get detailsEmpty => '点击消息流中的工具行查看其详情';

  @override
  String get detailsNotInWindow => '该调用不在当前窗口内';

  @override
  String get input => '输入';

  @override
  String get output => '输出';

  @override
  String get running => '运行中…';

  @override
  String get toolRunning => '运行中';

  @override
  String get toolDone => '完成';

  @override
  String get toolFailed => '失败';

  @override
  String get declined => '已拒绝';

  @override
  String get tabHasNoFile => '此标签页没有文件。';

  @override
  String get noWorkspaceNoFile => '未设置工作区文件夹，无法读取文件。';

  @override
  String get fileNoLongerExists => '此文件已不存在。';

  @override
  String get looksLikeBinary => '这看起来是二进制文件，无法显示。';

  @override
  String readOnlyTooLarge(String mb) {
    return '只读：文件超过 $mb MB。';
  }

  @override
  String couldNotSave(String message) {
    return '保存失败：$message';
  }

  @override
  String get unsaved => '未保存';

  @override
  String get noWorkspaceNothingToList => '未设置工作区文件夹，没有可列出的内容。';

  @override
  String get folderEmpty => '此文件夹为空。';

  @override
  String get searchFiles => '搜索文件';

  @override
  String get open => '打开';

  @override
  String get openInTreeTab => '在文件树标签页中打开';

  @override
  String noMatches(String query) {
    return '没有匹配「$query」的文件。';
  }

  @override
  String couldNotStartShell(String message) {
    return '无法启动 shell：$message';
  }

  @override
  String get shellExited => 'Shell 已退出。';

  @override
  String shellExitedCode(String code) {
    return 'Shell 已退出（$code）。';
  }

  @override
  String get gitNotARepo => '当前目录不是 git 仓库';

  @override
  String get gitTooManyChanges => '变更过多，仅显示前 2,000 条';

  @override
  String stagedCount(String n) {
    return '已暂存 ($n)';
  }

  @override
  String unstagedCount(String n) {
    return '未暂存 ($n)';
  }

  @override
  String get stage => '暂存';

  @override
  String get unstage => '取消暂存';

  @override
  String get stageAll => '全部暂存';

  @override
  String get unstageAll => '全部取消暂存';

  @override
  String get history => '历史';

  @override
  String get noChanges => '没有变更';

  @override
  String get commitPlaceholder => '提交信息 (Ctrl+Enter)';

  @override
  String get commit => '提交';

  @override
  String get loadMore => '加载更多';

  @override
  String historyLoadError(String message) {
    return '加载更多历史失败：$message';
  }

  @override
  String get branchSwitchFailed => '切换分支失败';

  @override
  String get openEditor => '打开编辑器';

  @override
  String get discardChanges => '放弃更改';

  @override
  String discardDesc(String path) {
    return '将丢弃「$path」的工作区修改（不可恢复）。';
  }

  @override
  String get copyRelative => '复制相对路径';

  @override
  String get copyAbsolute => '复制绝对路径';

  @override
  String get wrapLines => '长行折行';

  @override
  String get showOnlyChanged => '只看变更';

  @override
  String get nothingChanged => '这个文件夹里没有变更';

  @override
  String get viewCommitDiff => '查看提交差异';

  @override
  String get copyShortHash => '复制短哈希';

  @override
  String get copyFullHash => '复制完整哈希';

  @override
  String get copySubject => '复制提交信息';

  @override
  String get revertCommit => '还原此提交';

  @override
  String revertDesc(String subject) {
    return '将在当前分支创建一个反转「$subject」的新提交。';
  }

  @override
  String get cherryPickCommit => '捡取此提交';

  @override
  String cherryPickDesc(String subject) {
    return '将「$subject」的更改应用到当前分支。';
  }

  @override
  String get diffBinary => '二进制';

  @override
  String get diffAdded => '新增';

  @override
  String get diffDeleted => '删除';

  @override
  String get diffRenamed => '重命名';

  @override
  String get subagentMainAgent => '主代理';

  @override
  String get subagentIdle => '空闲';

  @override
  String get thinking => '思考中…';

  @override
  String get noSubagentsYet => '暂无子代理';

  @override
  String get subagentsEmptyDesc => '主代理派发的工作将在这里跟踪。';

  @override
  String get noOutput => '暂无输出';

  @override
  String subagentCount(String count) {
    return '$count 个子代理';
  }

  @override
  String subagentsCount(String count) {
    return '$count 个子代理';
  }

  @override
  String get settingsGeneral => '常规';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsModels => '模型';

  @override
  String get settingsWorkspace => '工作区';

  @override
  String get settingsWorkbench => '工作台';

  @override
  String get settingsExtensions => '扩展';

  @override
  String get settingsBackup => '备份与恢复';

  @override
  String get settingsBackupIntro => '将所有数据导出到文件，或从备份文件恢复。';

  @override
  String get backupCreate => '创建备份';

  @override
  String get backupCreateDesc => '将设置、会话和任务导出为 zip 文件。';

  @override
  String get providersSaveCurrent => '保存当前连接';

  @override
  String get providersSaveCurrentDesc =>
      '把刚配置好的连接存入清单，之后无需重填密钥即可切换服务商。密钥始终保存在系统钥匙串中。';

  @override
  String get providersBookEmpty => '还没有已保存的连接。在上方配置好后，保存到这里。';

  @override
  String get providersActivate => '使用';

  @override
  String get providersDelete => '删除';

  @override
  String get modelsListLabel => '模型列表';

  @override
  String get modelsActiveTag => '当前';

  @override
  String get modelsRemove => '从列表移除';

  @override
  String get modelsAddHint => '输入模型 id，回车添加';

  @override
  String get notificationsOn => '运行结束后唤起窗口';

  @override
  String get notificationsOnDesc => '窗口隐藏在托盘时，运行结束自动回到前台。';

  @override
  String get helpDocs => '产品文档';

  @override
  String get helpCommunity => '用户社群';

  @override
  String get helpReportIssue => '问题上报';

  @override
  String get helpFeatureRequest => '给产品提需求';

  @override
  String get helpReleases => '发现新版本';

  @override
  String updateAvailableTitle(String version) {
    return '发现新版本 $version';
  }

  @override
  String updateBody(String current, String new_) {
    return '当前版本 $current，最新版本 $new_。';
  }

  @override
  String get updateSkip => '跳过这个版本';

  @override
  String get updateDownload => '前往下载';

  @override
  String get updateUpToDate => '已是最新版本。';

  @override
  String get updateCheckFailed => '检查更新失败，请稍后再试。';

  @override
  String get helpAbout => '关于企划星';

  @override
  String get helpAboutTitle => '企划星';

  @override
  String helpAboutBody(String version) {
    return '桌面端 AI 代理工作台：Genkit 代理会话 + 企划数据视图工作区。当前版本 $version。';
  }

  @override
  String get authSignIn => '登录';

  @override
  String get authSignOut => '退出登录';

  @override
  String get welcomeTitle => '欢迎使用企划星';

  @override
  String get welcomeIntro => '连接你的账号，开始使用工作台。';

  @override
  String get welcomeApiKeyIntro => '输入服务商提供的 API key 即可开始。';

  @override
  String get welcomeProviderZai => '使用 Z.ai 登录';

  @override
  String get welcomeProviderBigmodel => '使用 BigModel 登录';

  @override
  String get welcomeRegionGlobal => '国际';

  @override
  String get welcomeRegionCn => '国内';

  @override
  String get welcomeUseApiKey => '使用 API key';

  @override
  String get welcomeApiKeyHint => 'API key';

  @override
  String get welcomeApiKeySave => '保存并开始';

  @override
  String get welcomeSkip => '暂时跳过';

  @override
  String get welcomeBackToProviders => '返回登录选项';

  @override
  String get welcomeWaiting => '正在等待浏览器中的认证…';

  @override
  String get welcomeCancelWait => '取消';

  @override
  String get welcomeFlowFailed => '登录流程失败，请重试。';

  @override
  String get welcomeFlowUnavailable => '尚未配置后端地址，浏览器登录不可用。请改用 API key。';

  @override
  String get welcomeRegister => '注册账号';

  @override
  String get welcomeLater => '稍后再说';

  @override
  String get settingsShortcuts => '快捷键';

  @override
  String get settingsShortcutsIntro => '所有键盘命令一览。自定义绑定将在后续版本提供。';

  @override
  String get shortcutToggleWindow => '显示或隐藏窗口';

  @override
  String get shortcutNewSession => '新建会话';

  @override
  String get shortcutOpenSettings => '打开设置';

  @override
  String get shortcutToggleSidebar => '收起或展开侧栏';

  @override
  String get settingsUsage => '使用统计';

  @override
  String get settingsUsageIntro => '本机模型使用记录，仅保留 30 天，不会离开这台设备。';

  @override
  String get usageTurns => '已记录模型轮次';

  @override
  String get usageTotalTokens => '已用 Token';

  @override
  String get usageErrorRate => '轮次错误率';

  @override
  String get usageCrashLogTitle => '崩溃与错误归档';

  @override
  String get usageCrashLogDesc => '最近崩溃的本地报告，仅保留最新 5 个文件，不会上传。';

  @override
  String get usageCrashLogOpen => '打开文件夹';

  @override
  String get settingsDiagnostics => '诊断日志';

  @override
  String get settingsDiagnosticsIntro =>
      '用于排查 agent 行为的本地日志：每次模型调用一行；开启后还会记录每次调用发给模型的完整消息。仅保留 30 天，不会离开这台设备。';

  @override
  String get diagnosticRequestLog => '请求日志';

  @override
  String get diagnosticRequestLogDesc => '记录每次模型调用：耗时、成败与 Token 用量。';

  @override
  String get diagnosticContextLog => '上下文快照';

  @override
  String get diagnosticContextLogDesc => '同时记录每次调用实际发给模型的完整消息。体积较大，默认关闭。';

  @override
  String get diagnosticFolderTitle => '诊断文件夹';

  @override
  String get diagnosticFolderDesc =>
      'requests-*.jsonl 与 contexts-*.jsonl，每月一个文件。';

  @override
  String get settingsReset => '重置';

  @override
  String get settingsResetDesc => '隔离设置与偏好文件并恢复默认。API key 将从钥匙串移除。会话与企划数据保留。';

  @override
  String get settingsResetConfirmTitle => '重置设置与偏好？';

  @override
  String get settingsResetConfirmBody =>
      '当前设置文件会以 .corrupt- 副本留在旁边，手动即可找回。会话与企划数据不受影响。';

  @override
  String get settingsResetDone => '设置与偏好已重置';

  @override
  String get backupExport => '导出';

  @override
  String get backupRestore => '从备份恢复';

  @override
  String get backupRestoreDesc => '从备份文件导入数据，将覆盖当前数据。';

  @override
  String get backupImport => '导入';

  @override
  String backupCreated(String count) {
    return '已创建备份，包含 $count 个文件。';
  }

  @override
  String backupRestored(String count) {
    return '已恢复 $count 个文件。重启后生效。';
  }

  @override
  String get backupFailed => '备份失败';

  @override
  String get searchSettings => '搜索设置…';

  @override
  String get settingsGeneralIntro => '应用自身的外观与行为。';

  @override
  String get settingsAppearanceIntro => '对话的字体与宽度，以及生成文件的呈现方式。';

  @override
  String get settingsModelsIntro => '此构建连接哪个端点。';

  @override
  String get settingsWorkspaceIntro =>
      '文件工具唯一可读写的文件夹。为空时拒绝所有调用；解析结果超出该文件夹的路径一律拒绝。';

  @override
  String get settingsTerminalIntro => '每个终端标签页的外观。即时生效——无需重启，甚至无需保存。';

  @override
  String get settingsTabsIntro =>
      '+ 菜单提供哪些标签页类型、打开操作接受哪些类型。已打开的标签页会继续显示，直到你关闭它们。';

  @override
  String get settingsMcpIntro =>
      '代理可调用的外部工具，命名 <server>/<tool>。服务器通过命令经 stdio 启动，或通过 HTTP URL 访问——二者填其一。更改在运行时重建（保存）后生效；连接失败的服务器不会贡献任何内容。';

  @override
  String get settingsSkillsIntro =>
      '其子目录各含一个 SKILL.md 的文件夹。代理在系统提示词中列出它们，并通过 use_skill 工具加载。为空表示 <应用程序支持目录>/skills。';

  @override
  String get settingsMcpServers => 'MCP 服务器';

  @override
  String get settingsSkills => '技能';

  @override
  String get tabs => '标签页';

  @override
  String get theme => '主题';

  @override
  String get themeDesc => '浅色、深色，或跟随系统。';

  @override
  String get followSystem => '跟随系统';

  @override
  String get light => '浅色';

  @override
  String get dark => '深色';

  @override
  String get language => '语言';

  @override
  String get languageDesc => '英文或中文，或跟随系统。';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get appearanceTextSize => '正文字号';

  @override
  String get appearanceTextSizeDesc => '对话正文文字的显示大小。';

  @override
  String get sizeSmall => '小';

  @override
  String get sizeMedium => '中';

  @override
  String get sizeLarge => '大';

  @override
  String get conversationWidth => '对话宽度';

  @override
  String get conversationWidthDesc => '消息栏可延展到的宽度。';

  @override
  String get widthNormal => '标准';

  @override
  String get widthWide => '加宽';

  @override
  String get expandToolCalls => '展开工具调用';

  @override
  String get expandToolCallsDesc => '新出现的工具区块默认展开。';

  @override
  String get provider => '提供商';

  @override
  String get providerOpenAiCompatible => 'OpenAI 兼容';

  @override
  String get providerAnthropic => 'Anthropic';

  @override
  String get providerGoogle => 'Google';

  @override
  String get apiKey => 'API 密钥';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get model => '模型';

  @override
  String get providerDefault => '提供商默认';

  @override
  String get keyConfigured => '密钥已配置';

  @override
  String get noKeyComposerDisabled => '缺少密钥——输入框保持禁用';

  @override
  String get keyMissing => '缺少密钥';

  @override
  String get keyStored => '已保存密钥';

  @override
  String get edit => '编辑';

  @override
  String get customized => '自定义';

  @override
  String get testConnection => '测试连接';

  @override
  String connectionOk(String n) {
    return '$n 个可用模型';
  }

  @override
  String get connectionFailed => '无法连接到服务地址。';

  @override
  String get probeTimeout => '服务地址未及时响应。';

  @override
  String get fetchingModels => '正在获取模型…';

  @override
  String get chooseModel => '选择模型';

  @override
  String get noModelsFetched => '先运行测试连接以载入列表';

  @override
  String get refreshModels => '载入服务端的模型列表';

  @override
  String get modelManagement => '模型管理';

  @override
  String statsCounts(String turns, String steps) {
    return '$turns 轮 · $steps 步';
  }

  @override
  String statsLlm(String duration) {
    return 'LLM $duration';
  }

  @override
  String statsTool(String duration) {
    return '工具调用 $duration';
  }

  @override
  String statsTtft(String duration) {
    return '首 token 平均 $duration';
  }

  @override
  String statsTokens(String tokens) {
    return '$tokens tokens';
  }

  @override
  String get folder => '文件夹';

  @override
  String get choose => '选择…';

  @override
  String get recent => '最近使用';

  @override
  String get missing => '已失效';

  @override
  String get folderNotOnDisk => '此文件夹当前不在磁盘上。';

  @override
  String get fontFamily => '字体族';

  @override
  String get fontFamilyHint => '\'\' 跟随主题的代码字体';

  @override
  String get fontSize => '字号';

  @override
  String get seedBottomPanel => '底部面板自动开终端';

  @override
  String get seedBottomPanelDesc => '每次会话中首次展开底部面板时，在那里打开一个终端标签页。';

  @override
  String get explorerDesc => '工作区文件夹的文件树。';

  @override
  String get terminalDesc => '工作区文件夹上的 shell。';

  @override
  String get gitDesc => 'git 变更列表及其差异。';

  @override
  String get subagentsDesc => '实时子代理与任务视图。';

  @override
  String get browserDesc => '带地址栏的内置网页视图。';

  @override
  String get sideChatDesc => '主线程旁的快速提问。';

  @override
  String get addServer => '添加服务器';

  @override
  String get serverName => '名称';

  @override
  String get arguments => '参数';

  @override
  String get commandStdio => '命令 (stdio)';

  @override
  String get urlHttp => 'URL (HTTP)';

  @override
  String get showKey => '显示密钥';

  @override
  String get hideKey => '隐藏密钥';

  @override
  String get closeSettings => '关闭设置';

  @override
  String get forget => '移除';

  @override
  String get increase => '增大';

  @override
  String get decrease => '减小';

  @override
  String get removeServer => '移除服务器';

  @override
  String get restartWarning => '保存将重连代理。当前会话会被清空；它仍保留在磁盘上，可从侧边栏重新打开。';

  @override
  String get planCellEmpty => '暂无值';

  @override
  String get planCellChecked => '已标记完成';

  @override
  String get planCellUnchecked => '标记未完成';

  @override
  String get planFieldName => '名称';

  @override
  String get planUntitled => '未命名';

  @override
  String get planNewRow => '新建一行';

  @override
  String get planNoRecords => '暂时还没有内容';

  @override
  String get planRecordCount => '条记录';

  @override
  String get planColumnNoStatus => '无状态';

  @override
  String get planColumnChecked => '已勾选';

  @override
  String get planCollections => '集合';

  @override
  String get planLibrary => '库';

  @override
  String get planWidgetStrip => '主屏组件';

  @override
  String get planBinTitle => '回收站';

  @override
  String get planBinEmpty => '回收站是空的';

  @override
  String get planBinEmptyBody => '所有已入回收站的记录将被彻底清除。';

  @override
  String get planBinActions => '回收站操作';

  @override
  String get planBinned => '已入回收站';

  @override
  String get planRestored => '已还原';

  @override
  String get planObjectInfoTitle => '对象信息';

  @override
  String get planTemplatesTitleShort => '模板';

  @override
  String get planCollectionMenu => '集合操作';

  @override
  String get planMarkBold => '加粗';

  @override
  String get planMarkItalic => '斜体';

  @override
  String get planMarkStrike => '删除线';

  @override
  String get planMarkUnderline => '下划线';

  @override
  String get planMarkCode => '代码';

  @override
  String get planMarkLink => '链接';

  @override
  String planCalendarUndated(String count) {
    return '$count 条记录没有日期';
  }

  @override
  String get planColumnUnchecked => '未勾选';

  @override
  String get planSortBy => '排序';

  @override
  String get planSortAdd => '添加排序';

  @override
  String get planSortDirection => '排序方向';

  @override
  String get planSortEmpty => '空值位置';

  @override
  String get planSortAsc => '升序';

  @override
  String get planSortDesc => '降序';

  @override
  String get planSortClear => '清除该排序';

  @override
  String get planHideField => '隐藏字段';

  @override
  String get planFilterTitle => '筛选';

  @override
  String get planFilterAdd => '添加筛选';

  @override
  String get planFilterCondition => '条件';

  @override
  String get planFilterValue => '值';

  @override
  String get planFilterPickValue => '设置值';

  @override
  String get planFilterOperator => '组合方式';

  @override
  String get planFilterNestedUnsupported => '嵌套规则只属于桌面端，这里不会应用';

  @override
  String get planNewOption => '新建选项';

  @override
  String get planDateLiteral => '指定日期';

  @override
  String get planRemove => '移除';

  @override
  String get planDelete => '删除';

  @override
  String get planSave => '保存';

  @override
  String get planLayoutTitle => '布局';

  @override
  String get planLayoutHideIcon => '隐藏图标';

  @override
  String get planLayoutCardSize => '卡片尺寸';

  @override
  String get planLayoutCover => '封面';

  @override
  String get planLayoutNone => '无';

  @override
  String get planLayoutCoverFit => '封面适应卡片';

  @override
  String get planLayoutGroupBy => '分组依据';

  @override
  String get planLayoutColorColumns => '彩色列';

  @override
  String get planLayoutDefaultType => '新建记录的默认类型';

  @override
  String get planLayoutDefaultTemplate => '新建记录的模板';

  @override
  String get planFieldsTitle => '字段';

  @override
  String get planFieldDateFormat => '日期格式';

  @override
  String get planFieldWidth => '宽度';

  @override
  String get planAllViews => '全部视图';

  @override
  String get planAddView => '新建视图';

  @override
  String get planViewSettings => '视图设置';

  @override
  String get planToggleHeader => '隐藏表头';

  @override
  String get planViewSoonTag => '本机暂不支持';

  @override
  String get planViewRename => '重命名视图';

  @override
  String get planViewDuplicate => '复制视图';

  @override
  String get planViewMoveLeft => '左移';

  @override
  String get planViewMoveRight => '右移';

  @override
  String get planViewDelete => '删除视图';

  @override
  String get planViewDeleteBody => '该视图及其筛选条件会被移除，记录本身保留。';

  @override
  String get planViewDeleted => '视图已删除';

  @override
  String get planViewCalendarUnsupported =>
      '此工作台暂不支持日历视图。请更改视图类型，或新建一个视图来查看数据。';

  @override
  String get planViewGraphUnsupported => '此工作台暂不支持图形视图。请更改视图类型，或新建一个视图来查看数据。';

  @override
  String get planCollectionMissing => '该集合已不存在';

  @override
  String get planRenameCollection => '重命名集合';

  @override
  String get planRecordTitle => '记录';

  @override
  String get planRecordNoFields => '此视图没有字段';

  @override
  String get planFavorite => '加入收藏';

  @override
  String get planUnfavorite => '取消收藏';

  @override
  String get planRestore => '恢复';

  @override
  String get planMoveToBin => '移入回收站';

  @override
  String get planDuplicate => '创建副本';

  @override
  String get planCondEqual => '等于';

  @override
  String get planCondNotEqual => '不等于';

  @override
  String get planCondGreater => '大于';

  @override
  String get planCondGreaterOrEqual => '大于等于';

  @override
  String get planCondLess => '小于';

  @override
  String get planCondLessOrEqual => '小于等于';

  @override
  String get planCondLike => '包含';

  @override
  String get planCondNotLike => '不包含';

  @override
  String get planCondIn => '属于其一';

  @override
  String get planCondNotIn => '不属于其一';

  @override
  String get planCondEmpty => '为空';

  @override
  String get planCondNotEmpty => '非空';

  @override
  String get planCondAllIn => '全部包含';

  @override
  String get planCondNotAllIn => '未全部包含';

  @override
  String get planCondNone => '全都不含';

  @override
  String get planCondExactIn => '恰好是';

  @override
  String get planCondNotExactIn => '不恰好是';

  @override
  String get planCondExists => '已设置';
}
