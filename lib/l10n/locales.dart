// The app's two dictionaries and the seam they are read through.
//
// A port of `DSH-better-sidebar/src/client/locales.ts` narrowed to the two
// locales dsh itself ships (zh/en — the reference's other 20 come from an
// ecosystem plugin this app has no counterpart of). Same contract as the
// source's `t()`: zh is the source of truth, en is checked against it at
// test time, a missing key renders as the key itself so a gap is visible
// rather than blank, and `{name}` placeholders interpolate from params.
//
// The seam is an [AppLocaleScope] the app mounts above the frame, plus a
// `context.tr(key)` extension. A missing scope means English — the language
// every string in this app was written in first — which is what keeps widget
// tests deterministic: they pump without a scope and assert English copy
// without knowing i18n exists. The system-follow resolution
// (`Platform.localeName`) happens ONCE in main when the scope is built, never
// in the fallback.
//
// What deliberately does NOT go through here:
//
//   * The genkit tool descriptions and the errors those tools return — the
//     model reads those, and a model prompt is not UI copy.
//   * Persisted tab titles minted into the layout ('Terminal 3', file
//     basenames). Data must not flip with the language; the single-instance
//     tabs (git, sub-agents) get their display label derived from the type at
//     render time instead, and a terminal's number comes from its id.

import 'package:flutter/widgets.dart';

/// The two locales this app ships — dsh's own pair.
enum AppLocaleId { en, zh }

/// English — the source language every string was written in first.
const enStrings = <String, String>{
  // Common
  'close': 'Close',
  'cancel': 'Cancel',
  'retry': 'Retry',
  'restart': 'Restart',
  'refresh': 'Refresh',
  'save': 'Save',
  'saving': 'Saving…',
  'saved': 'Saved',
  'preview': 'Preview',
  'reload': 'Reload from disk',
  'reloadDirtyTitle': 'Discard unsaved edits?',
  'reloadDirtyDesc':
      'Reloading "{path}" from disk will discard your unsaved edits.',
  'settings': 'Settings',
  'openSettings': 'Open settings',
  'quickPreferences': 'Quick preferences',
  'untitled': 'Untitled',
  'loading': 'Loading…',
  'confirm': 'Confirm',
  'remove': 'Remove',

  // Tabs
  'explorer': 'Explorer',
  'terminal': 'Terminal',
  'git': 'Source control',
  'subagents': 'Sub-agents',
  'editor': 'Editor',
  'newTab': 'New tab',
  'splitDown': 'Split down',
  'splitRight': 'Split right',
  'closeOthers': 'Close others',
  'closeAll': 'Close all',
  'sendToSidePanel': 'Send to side panel',
  'sendToBottomPanel': 'Send to bottom panel',
  'floatInWindow': 'Float in a window',
  'dockToSidebar': 'Dock to sidebar',
  'unknownTabType': 'This version has nothing to show a "{type}" tab with.',
  'terminalN': 'Terminal {n}',

  // The browser tab
  'browser': 'Browser',
  'browserBack': 'Back',
  'browserForward': 'Forward',
  'browserGo': 'Go',
  'browserPlaceholder': 'Search or enter address',
  'browserOpenExternal': 'Open in default browser',
  'browserInvalid': 'That is not a valid address.',
  'browserBlockedScheme': 'Only http and https addresses can be opened.',
  'browserBlockedLoopback': 'Local addresses are refused.',
  'browserStart': 'Enter an address above to start browsing.',
  'browserUnsupported': 'In-app browsing is not available on this platform.',

  // The side-chat tab
  'sidechat': 'Side chat',
  'sideChatNew': 'New side chat',
  'sideChatEmpty': 'A lighter conversation beside the main one.',
  'sideChatEmptyDesc': 'Quick asides that never touch the main thread.',
  'sideChatNoModel': 'Connect a model in Settings to chat here.',
  'sideChatPlaceholder': 'Ask an aside…',
  'sideChatThinking': 'Thinking…',

  // The empty pane
  'filesOpenHere': 'Files open here.',
  'clickToOpenFiles': 'Click to open files in this pane.',

  // The frame's toggle cluster
  'openWorkbenchPanel': 'Open workbench panel',
  'collapseWorkbenchPanel': 'Collapse workbench panel',
  'openBottomPanel': 'Open bottom panel',
  'collapseBottomPanel': 'Collapse bottom panel',

  // The sidebar
  'openSidebar': 'Open sidebar',
  'collapseSidebar': 'Collapse sidebar',
  'newSession': 'New Session',
  'sessions': 'Sessions',
  // The top-level workspace switch (ADR-0007)
  'planMode': 'Plan',
  'agentMode': 'Agent',
  'noSessionsYet': 'No sessions yet',
  'openDetailsPanel': 'Open details panel',
  'closeDetailsPanel': 'Close details panel',

  // The hero and the composer
  'askAnything': 'Ask anything',
  'askAnythingHint': 'Ask anything, or describe a task',
  'heroSubtitle': 'Ask anything, or open a workspace to begin',

  // Workspace status bar (below composer)
  'workspaceStatusBar': 'Workspace status bar',
  'localRepo': 'Local',

  // The plan workspace (ADR-0007)
  'planNoWorkspace':
      'Choose a workspace folder first — the plan vault is the workspace',
  'planNoNoteSelected': 'Pick a markdown file from the tree',
  'planNotes': 'Notes',
  'planNoNotes': 'No markdown files in this workspace',
  'planPreview': 'Preview',
  'planSource': 'Source',
  'planUnsaved': 'Unsaved changes',
  'planDiscardTitle': 'Discard unsaved edits?',
  'planDiscardDesc':
      'Switching away from "{path}" without saving discards your edits.',
  'planNewNote': 'New Note',
  'planNewFolder': 'New Folder',
  'planNewNoteHint': 'File name (without .md)',
  'planNewFolderHint': 'Folder name',
  'planCreate': 'Create',
  'planCancel': 'Cancel',
  'planFileNameExists': 'A file with this name already exists',
  'planFolderNameExists': 'A folder with this name already exists',
  'planSwitchWorkspace': 'Switch workspace',

  // The plan extensions (ADR-0007 D4)
  'planExtensions': 'Extensions',
  'planBoard': 'Board',
  'planCalendar': 'Calendar',
  'planTable': 'Table',
  'planAddTask': 'Add',
  'planTaskTitleHint': 'New task title',
  'planTaskDateHint': 'yyyy-mm-dd',
  'planGroupTodo': 'To do',
  'planGroupInProgress': 'In progress',
  'planGroupReview': 'Review',
  'planGroupDone': 'Done',
  'planColumnStatus': 'Status',
  'planColumnTask': 'Task',
  'planColumnDue': 'Due',
  'planNoDue': '—',

  'chooseWorkspaceFolder': 'Choose a workspace folder',
  'chooseAFolder': 'Choose a folder…',
  'send': 'Send',
  'stop': 'Stop',
  'deepDiving': 'Deep diving...',

  // The composer's tool row
  'attachImage': 'Attach images',
  'chooseImages': 'Choose image files…',
  'pasteImage': 'Paste image from clipboard',
  'pasteImageFailed': 'The clipboard has no image.',
  'removeAttachment': 'Remove',
  'dropFilesHint': 'Drop images to attach',
  'askEveryTime': 'Ask every time',
  'askEveryTimeDesc':
      'The agent interrupts for approval before it writes or runs anything.',
  'planFirst': 'Plan first',
  'planFirstDesc':
      'Read-only until a plan is approved; the agent may not change anything.',
  'autoRun': 'Auto-run',
  'autoRunDesc': 'Gated tools run without asking. Use when you trust the turn.',
  'approvalMode': 'Approval mode',
  'commandHint': 'Type / for commands',
  'commands': 'Commands',
  'files': 'Files',
  'searchingFiles': 'Searching the workspace…',
  'commandNewSession': 'Start a new session',
  'commandNewSessionDesc':
      'Leave this conversation on disk and start a fresh one.',
  'commandAskMode': 'Switch to ask mode',
  'commandAskModeDesc': 'Every gated call interrupts for approval.',
  'commandPlanMode': 'Switch to plan mode',
  'commandPlanModeDesc':
      'The workspace is read-only until the plan is approved.',
  'commandAutoMode': 'Switch to auto mode',
  'commandAutoModeDesc': 'Gated tools run without prompting.',

  // The approval panel
  'waitingForApproval': 'Waiting for approval',
  'approvalTitle': 'Tool {name} requests privileged execution',
  'reject': 'Reject',
  'allowOnce': 'Allow once',
  'oneReplacement': '1 replacement',
  'nReplacements': '{n} replacements',
  'overwritesExistingFile': 'overwrites an existing file',
  'inWorkdir': 'in {dir}',

  // The plan review panel
  'planReviewHeader': 'Plan review',
  'planDiscuss': 'Discuss',
  'planDecline': 'Decline',
  'planApprove': 'Approve',
  'planApprovedMessage': 'The plan is approved. Proceed with it.',
  'planDeclinedMessage': 'The plan is declined. Revise it.',

  // The details panel
  'details': 'Details',
  'closeDetails': 'Close details',
  'detailsEmpty': 'Click a tool row in the message flow to view its details',
  'detailsNotInWindow': 'This call is outside the current window',
  'input': 'Input',
  'output': 'Output',
  'running': 'Running…',

  // Tool state dots
  'toolRunning': 'Running',
  'toolDone': 'Done',
  'toolFailed': 'Failed',
  'declined': 'Declined',

  // The editor tab
  'tabHasNoFile': 'This tab has no file.',
  'noWorkspaceNoFile': 'No workspace folder is set, so no file can be read.',
  'fileNoLongerExists': 'This file no longer exists.',
  'looksLikeBinary': 'This looks like a binary file. Nothing here can show it.',
  'readOnlyTooLarge': 'Read-only: this file is larger than {mb} MB.',
  'couldNotSave': 'Could not save: {message}',
  'unsaved': 'unsaved',

  // The file tree
  'noWorkspaceNothingToList':
      'No workspace folder is set, so there is nothing to list.',
  'folderEmpty': 'This folder is empty.',
  'searchFiles': 'Search files',
  'open': 'Open',
  'openInTreeTab': 'Open in a file tree tab',
  'noMatches': 'No files match "{query}".',

  // The terminal tab
  'couldNotStartShell': 'Could not start the shell: {message}',
  'shellExited': 'The shell exited.',
  'shellExitedCode': 'The shell exited ({code}).',

  // The git tab
  'gitNotARepo': 'This directory is not a git repository',
  'gitTooManyChanges': 'Too many changes; showing the first 2,000 entries',
  'stagedCount': 'Staged ({n})',
  'unstagedCount': 'Unstaged ({n})',
  'stage': 'Stage',
  'unstage': 'Unstage',
  'stageAll': 'Stage all',
  'unstageAll': 'Unstage all',
  'history': 'History',
  'noChanges': 'No changes',
  'commitPlaceholder': 'Commit message (Ctrl+Enter)',
  'commit': 'Commit',
  'loadMore': 'Load more',
  'historyLoadError': 'Failed to load more history: {message}',
  'branchSwitchFailed': 'Branch switch failed',
  'openEditor': 'Open editor',
  'discardChanges': 'Discard changes',
  'discardDesc':
      'This discards the worktree changes of "{path}" (not recoverable).',
  'copyRelative': 'Copy relative path',
  'copyAbsolute': 'Copy absolute path',
  'viewCommitDiff': 'View commit diff',
  'copyShortHash': 'Copy short hash',
  'copyFullHash': 'Copy full hash',
  'copySubject': 'Copy subject',
  'revertCommit': 'Revert commit',
  'revertDesc':
      'Create a new commit on the current branch that reverts "{subject}".',
  'cherryPickCommit': 'Cherry-pick commit',
  'cherryPickDesc': 'Apply the changes of "{subject}" to the current branch.',

  // The diff tab
  'diffBinary': 'Binary',
  'diffAdded': 'Added',
  'diffDeleted': 'Deleted',
  'diffRenamed': 'Renamed',

  // The sub-agent tab
  'subagentMainAgent': 'Main agent',
  'subagentIdle': 'Idle',
  'thinking': 'Thinking…',
  'noSubagentsYet': 'No sub-agents yet',
  'subagentsEmptyDesc': 'Work the main agent delegates will be tracked here.',
  'noOutput': 'No output',
  'subagentCount': '{count} subagent',
  'subagentsCount': '{count} subagents',

  // The settings panel: navigation and sections
  'settingsGeneral': 'General',
  'settingsAppearance': 'Appearance',
  'settingsModels': 'Models',
  'settingsWorkspace': 'Workspace',
  'settingsWorkbench': 'Workbench',
  'settingsExtensions': 'Extensions',
  'searchSettings': 'Search settings…',
  'settingsGeneralIntro': 'How the app itself looks and behaves.',
  'settingsAppearanceIntro':
      'The face and width of the conversation, and how generated files are '
      'shown.',
  'settingsModelsIntro': 'Which endpoint this build talks to.',
  'settingsWorkspaceIntro':
      'The one folder the file tools may read and write. They refuse every '
      'call while this is empty, and refuse any path that resolves outside it.',
  'settingsTerminalIntro':
      'The face every terminal tab wears. Applied live — no restart, not '
      'even a Save.',
  'settingsTabsIntro':
      'Which tab types the + menu offers and the opens accept. Tabs already '
      'open keep rendering until you close them.',
  'settingsMcpIntro':
      'External tools the agent may call, named <server>/<tool>. A server is '
      'launched over stdio from a command, or reached over HTTP at a URL — '
      'fill in one or the other. Changes take effect after the runtime is '
      'rebuilt (Save), and a server that fails to connect simply '
      'contributes nothing.',
  'settingsSkillsIntro':
      'The folder whose sub-directories each hold a SKILL.md. The agent lists '
      'them in its system prompt and loads one with the use_skill tool. '
      'Empty means <application support>/skills.',
  'settingsMcpServers': 'MCP servers',
  'settingsSkills': 'Skills',
  'tabs': 'Tabs',

  // The settings panel: fields
  'theme': 'Theme',
  'themeDesc': 'Light, dark, or whatever the system is doing.',
  'followSystem': 'Follow system',
  'light': 'Light',
  'dark': 'Dark',
  'language': 'Language',
  'languageDesc': 'English or Chinese, or follow the system.',
  'english': 'English',
  'chinese': '中文',

  // The settings panel: appearance section (ADR-0005)
  'appearanceTextFont': 'Text font',
  'appearanceTextFontDesc': 'The face the conversation is set in.',
  'fontSansSerif': 'Sans serif',
  'fontSerif': 'Serif',
  'appearanceTextSize': 'Text size',
  'appearanceTextSizeDesc': 'How large the conversation text renders.',
  'sizeSmall': 'Small',
  'sizeMedium': 'Medium',
  'sizeLarge': 'Large',
  'conversationWidth': 'Conversation width',
  'conversationWidthDesc': 'How wide the message column stretches.',
  'widthNormal': 'Normal',
  'widthWide': 'Wide',
  'interfaceStyle': 'Interface style',
  'interfaceStyleDesc':
      'The window skin. Only Standard is styled today; the rest are saved '
      'for a future palette.',
  'styleStandard': 'Standard',
  'styleGlass': 'Glass',
  'styleClassic': 'Classic',
  'styleParchment': 'Parchment',
  'previewMode': 'Preview mode',
  'previewModeDesc': 'Where a generated file opens.',
  'previewNewWindow': 'New window',
  'previewSidePanel': 'Side panel',
  'previewInline': 'Inline',
  'expandToolCalls': 'Expand tool calls',
  'expandToolCallsDesc': 'Newly shown tool blocks start open.',
  'promptSuggestions': 'Prompt suggestions',
  'promptSuggestionsDesc': 'The agent offers follow-up prompts.',
  'provider': 'Provider',
  'providerOpenAiCompatible': 'OpenAI-compatible',
  'providerAnthropic': 'Anthropic',
  'providerGoogle': 'Google',
  'apiKey': 'API key',
  'baseUrl': 'Base URL',
  'model': 'Model',
  'providerDefault': 'provider default',
  'keyConfigured': 'Key configured',
  'noKeyComposerDisabled': 'No key — the composer stays disabled',
  'keyMissing': 'Key missing',
  'keyStored': 'A key is stored',
  'edit': 'Edit',
  'customized': 'Customized',
  'testConnection': 'Test connection',
  'connectionOk': '{n} models available',
  'connectionFailed': 'Could not reach the endpoint.',
  'probeTimeout': 'The endpoint did not answer in time.',
  'fetchingModels': 'Fetching models…',
  'chooseModel': 'Choose a model',
  'noModelsFetched': 'Run Test connection to load the list',
  'refreshModels': 'Load the endpoint\'s list',
  'statsCounts': '{turns} turns · {steps} steps',
  'statsLlm': 'LLM {duration}',
  'statsTool': 'Tool call {duration}',
  'statsTtft': 'TTFT avg {duration}',
  'statsTokens': '{tokens} tokens',
  'folder': 'Folder',
  'choose': 'Choose…',
  'recent': 'Recent',
  'missing': 'missing',
  'folderNotOnDisk': 'This folder is not on disk right now.',
  'fontFamily': 'Font family',
  'fontFamilyHint': "'' follows the theme's code font",
  'fontSize': 'Font size',
  'seedBottomPanel': 'Seed the bottom panel',
  'seedBottomPanelDesc':
      'Expanding the bottom panel for the first time in a session opens a '
      'terminal tab there.',
  'explorerDesc': 'The file tree over the workspace folder.',
  'terminalDesc': 'A shell over the workspace folder.',
  'gitDesc': 'The git change list and its diffs.',
  'subagentsDesc': 'The live sub-agent and job view.',
  'browserDesc': 'The built-in web view with its address bar.',
  'sideChatDesc': 'Quick asides beside the main thread.',
  'addServer': 'Add server',
  'serverName': 'Name',
  'arguments': 'Arguments',
  'commandStdio': 'Command (stdio)',
  'urlHttp': 'URL (HTTP)',
  'showKey': 'Show key',
  'hideKey': 'Hide key',
  'closeSettings': 'Close settings',
  'forget': 'Forget',
  'increase': 'Increase',
  'decrease': 'Decrease',
  'removeServer': 'Remove server',
  'restartWarning':
      'Saving reconnects the agent. The open conversation is cleared; it '
      'stays on disk and can be reopened from the sidebar.',
};

/// Chinese — the source of truth the reference keeps, translated from the
/// English this app was written in. A key missing here falls back to English
/// at lookup, so a half-added string renders in English rather than as its
/// key.
const zhStrings = <String, String>{
  // Common
  'close': '关闭',
  'cancel': '取消',
  'retry': '重试',
  'restart': '重启',
  'refresh': '刷新',
  'save': '保存',
  'saving': '保存中…',
  'saved': '已保存',
  'preview': '预览',
  'reload': '从磁盘重新加载',
  'reloadDirtyTitle': '放弃未保存的编辑？',
  'reloadDirtyDesc': '从磁盘重新加载「{path}」将丢弃未保存的编辑。',
  'settings': '设置',
  'openSettings': '打开设置',
  'quickPreferences': '快捷偏好设置',
  'untitled': '未命名',
  'loading': '加载中…',
  'confirm': '确认',
  'remove': '移除',

  // Tabs
  'explorer': '资源管理器',
  'terminal': '终端',
  'git': '源代码管理',
  'subagents': '子代理',
  'editor': '编辑器',
  'newTab': '新建标签页',
  'splitDown': '向下分栏',
  'splitRight': '向右分栏',
  'closeOthers': '关闭其他',
  'closeAll': '关闭全部',
  'sendToSidePanel': '发送到侧边面板',
  'sendToBottomPanel': '发送到底部面板',
  'floatInWindow': '悬浮为窗口',
  'dockToSidebar': '回到侧边栏',
  'unknownTabType': '此版本无法展示「{type}」标签页。',
  'terminalN': '终端 {n}',

  // The browser tab
  'browser': '浏览器',
  'browserBack': '后退',
  'browserForward': '前进',
  'browserGo': '前往',
  'browserPlaceholder': '搜索或输入地址',
  'browserOpenExternal': '在默认浏览器中打开',
  'browserInvalid': '这不是一个有效的地址。',
  'browserBlockedScheme': '只能打开 http 和 https 地址。',
  'browserBlockedLoopback': '本地地址已被拒绝。',
  'browserStart': '在上方输入地址开始浏览。',
  'browserUnsupported': '当前平台不支持内置浏览器。',

  // The side-chat tab
  'sidechat': '边侧对话',
  'sideChatNew': '新建边侧对话',
  'sideChatEmpty': '主对话旁的轻量对话。',
  'sideChatEmptyDesc': '不打扰主线程的快速提问。',
  'sideChatNoModel': '在设置中连接模型后可在此对话。',
  'sideChatPlaceholder': '问点什么…',
  'sideChatThinking': '思考中…',

  // The empty pane
  'filesOpenHere': '文件在这里打开。',
  'clickToOpenFiles': '点击在此窗格中打开文件。',

  // The frame's toggle cluster
  'openWorkbenchPanel': '打开工作台面板',
  'collapseWorkbenchPanel': '折叠工作台面板',
  'openBottomPanel': '打开底部面板',
  'collapseBottomPanel': '折叠底部面板',

  // The sidebar
  'openSidebar': '展开侧边栏',
  'collapseSidebar': '折叠侧边栏',
  'newSession': '新会话',
  'sessions': '会话',
  // The top-level workspace switch (ADR-0007)
  'planMode': '企划',
  'agentMode': '代理',
  'noSessionsYet': '暂无会话',
  'openDetailsPanel': '打开详情面板',
  'closeDetailsPanel': '关闭详情面板',

  // The hero and the composer
  'askAnything': '随便问点什么',
  'askAnythingHint': '输入问题，或描述一个任务',
  'heroSubtitle': '随时提问，或打开工作区开始探索',

  // Workspace status bar (below composer)
  'workspaceStatusBar': '工作区状态栏',
  'localRepo': '本地',

  // The plan workspace (ADR-0007)
  'planNoWorkspace': '请先选择工作区文件夹——企划库就是工作区',
  'planNoNoteSelected': '从目录树中选择一个 Markdown 文件',
  'planNotes': '笔记',
  'planNoNotes': '此工作区暂无 Markdown 文件',
  'planPreview': '预览',
  'planSource': '源码',
  'planUnsaved': '有未保存的修改',
  'planDiscardTitle': '放弃未保存的编辑？',
  'planDiscardDesc': '不保存就离开「{path}」将丢弃你的编辑。',
  'planNewNote': '新建笔记',
  'planNewFolder': '新建文件夹',
  'planNewNoteHint': '文件名（不含 .md）',
  'planNewFolderHint': '文件夹名',
  'planCreate': '创建',
  'planCancel': '取消',
  'planFileNameExists': '同名文件已存在',
  'planFolderNameExists': '同名文件夹已存在',
  'planSwitchWorkspace': '切换工作区',

  // The plan extensions (ADR-0007 D4)
  'planExtensions': '扩展',
  'planBoard': '看板',
  'planCalendar': '日程',
  'planTable': '表格',
  'planAddTask': '添加',
  'planTaskTitleHint': '新任务标题',
  'planTaskDateHint': 'yyyy-mm-dd',
  'planGroupTodo': '待办',
  'planGroupInProgress': '进行中',
  'planGroupReview': '评审',
  'planGroupDone': '完成',
  'planColumnStatus': '状态',
  'planColumnTask': '任务',
  'planColumnDue': '截止',
  'planNoDue': '—',

  'chooseWorkspaceFolder': '选择工作区文件夹',
  'chooseAFolder': '选择文件夹…',
  'send': '发送',
  'stop': '停止',
  'deepDiving': '深入思考中...',

  // The composer's tool row
  'attachImage': '添加图片',
  'chooseImages': '选择图片文件…',
  'pasteImage': '从剪贴板粘贴图片',
  'pasteImageFailed': '剪贴板中没有图片。',
  'removeAttachment': '移除',
  'dropFilesHint': '拖放图片以添加附件',
  'askEveryTime': '每次询问',
  'askEveryTimeDesc': '代理在写入或执行命令前会中断并请求批准。',
  'planFirst': '先做计划',
  'planFirstDesc': '计划批准前只读；代理不能做任何更改。',
  'autoRun': '自动执行',
  'autoRunDesc': '受限工具直接运行、不再询问。确认可信时使用。',
  'approvalMode': '批准模式',
  'commandHint': '输入 / 唤出命令',
  'commands': '命令',
  'files': '文件',
  'searchingFiles': '正在搜索工作区…',
  'commandNewSession': '开始新会话',
  'commandNewSessionDesc': '当前会话保留在磁盘上，另起一个全新会话。',
  'commandAskMode': '切换到询问模式',
  'commandAskModeDesc': '每个受限调用都会中断等待批准。',
  'commandPlanMode': '切换到计划模式',
  'commandPlanModeDesc': '计划批准之前，工作区只读。',
  'commandAutoMode': '切换到自动模式',
  'commandAutoModeDesc': '受限工具不再询问直接运行。',

  // The approval panel
  'waitingForApproval': '等待批准',
  'approvalTitle': '工具 {name} 请求特权执行',
  'reject': '拒绝',
  'allowOnce': '仅此一次',
  'oneReplacement': '1 处替换',
  'nReplacements': '{n} 处替换',
  'overwritesExistingFile': '将覆盖已有文件',
  'inWorkdir': '在 {dir} 中',

  // The plan review panel
  'planReviewHeader': '计划审批',
  'planDiscuss': '继续讨论',
  'planDecline': '否决',
  'planApprove': '批准',
  'planApprovedMessage': '计划已批准，请按计划执行。',
  'planDeclinedMessage': '计划已被否决，请修改计划。',

  // The details panel
  'details': '详情',
  'closeDetails': '关闭详情',
  'detailsEmpty': '点击消息流中的工具行查看其详情',
  'detailsNotInWindow': '该调用不在当前窗口内',
  'input': '输入',
  'output': '输出',
  'running': '运行中…',

  // Tool state dots
  'toolRunning': '运行中',
  'toolDone': '完成',
  'toolFailed': '失败',
  'declined': '已拒绝',

  // The editor tab
  'tabHasNoFile': '此标签页没有文件。',
  'noWorkspaceNoFile': '未设置工作区文件夹，无法读取文件。',
  'fileNoLongerExists': '此文件已不存在。',
  'looksLikeBinary': '这看起来是二进制文件，无法显示。',
  'readOnlyTooLarge': '只读：文件超过 {mb} MB。',
  'couldNotSave': '保存失败：{message}',
  'unsaved': '未保存',

  // The file tree
  'noWorkspaceNothingToList': '未设置工作区文件夹，没有可列出的内容。',
  'folderEmpty': '此文件夹为空。',
  'searchFiles': '搜索文件',
  'open': '打开',
  'openInTreeTab': '在文件树标签页中打开',
  'noMatches': '没有匹配「{query}」的文件。',

  // The terminal tab
  'couldNotStartShell': '无法启动 shell：{message}',
  'shellExited': 'Shell 已退出。',
  'shellExitedCode': 'Shell 已退出（{code}）。',

  // The git tab
  'gitNotARepo': '当前目录不是 git 仓库',
  'gitTooManyChanges': '变更过多，仅显示前 2,000 条',
  'stagedCount': '已暂存 ({n})',
  'unstagedCount': '未暂存 ({n})',
  'stage': '暂存',
  'unstage': '取消暂存',
  'stageAll': '全部暂存',
  'unstageAll': '全部取消暂存',
  'history': '历史',
  'noChanges': '没有变更',
  'commitPlaceholder': '提交信息 (Ctrl+Enter)',
  'commit': '提交',
  'loadMore': '加载更多',
  'historyLoadError': '加载更多历史失败：{message}',
  'branchSwitchFailed': '切换分支失败',
  'openEditor': '打开编辑器',
  'discardChanges': '放弃更改',
  'discardDesc': '将丢弃「{path}」的工作区修改（不可恢复）。',
  'copyRelative': '复制相对路径',
  'copyAbsolute': '复制绝对路径',
  'viewCommitDiff': '查看提交差异',
  'copyShortHash': '复制短哈希',
  'copyFullHash': '复制完整哈希',
  'copySubject': '复制提交信息',
  'revertCommit': '还原此提交',
  'revertDesc': '将在当前分支创建一个反转「{subject}」的新提交。',
  'cherryPickCommit': '捡取此提交',
  'cherryPickDesc': '将「{subject}」的更改应用到当前分支。',

  // The diff tab
  'diffBinary': '二进制',
  'diffAdded': '新增',
  'diffDeleted': '删除',
  'diffRenamed': '重命名',

  // The sub-agent tab
  'subagentMainAgent': '主代理',
  'subagentIdle': '空闲',
  'thinking': '思考中…',
  'noSubagentsYet': '暂无子代理',
  'subagentsEmptyDesc': '主代理派发的工作将在这里跟踪。',
  'noOutput': '暂无输出',
  'subagentCount': '{count} 个子代理',
  'subagentsCount': '{count} 个子代理',

  // The settings panel: navigation and sections
  'settingsGeneral': '常规',
  'settingsAppearance': '外观',
  'settingsModels': '模型',
  'settingsWorkspace': '工作区',
  'settingsWorkbench': '工作台',
  'settingsExtensions': '扩展',
  'searchSettings': '搜索设置…',
  'settingsGeneralIntro': '应用自身的外观与行为。',
  'settingsAppearanceIntro': '对话的字体与宽度，以及生成文件的呈现方式。',
  'settingsModelsIntro': '此构建连接哪个端点。',
  'settingsWorkspaceIntro': '文件工具唯一可读写的文件夹。为空时拒绝所有调用；解析结果超出该文件夹的路径一律拒绝。',
  'settingsTerminalIntro': '每个终端标签页的外观。即时生效——无需重启，甚至无需保存。',
  'settingsTabsIntro': '+ 菜单提供哪些标签页类型、打开操作接受哪些类型。已打开的标签页会继续显示，直到你关闭它们。',
  'settingsMcpIntro':
      '代理可调用的外部工具，命名 <server>/<tool>。服务器通过命令经 stdio 启动，或通过 HTTP URL 访问——二者填其一。更改在运行时重建（保存）后生效；连接失败的服务器不会贡献任何内容。',
  'settingsSkillsIntro':
      '其子目录各含一个 SKILL.md 的文件夹。代理在系统提示词中列出它们，并通过 use_skill 工具加载。为空表示 <应用程序支持目录>/skills。',
  'settingsMcpServers': 'MCP 服务器',
  'settingsSkills': '技能',
  'tabs': '标签页',

  // The settings panel: fields
  'theme': '主题',
  'themeDesc': '浅色、深色，或跟随系统。',
  'followSystem': '跟随系统',
  'light': '浅色',
  'dark': '深色',
  'language': '语言',
  'languageDesc': '英文或中文，或跟随系统。',
  'english': 'English',
  'chinese': '中文',

  // The settings panel: appearance section (ADR-0005)
  'appearanceTextFont': '正文字体',
  'appearanceTextFontDesc': '对话正文所使用的字体。',
  'fontSansSerif': '无衬线',
  'fontSerif': '衬线',
  'appearanceTextSize': '正文字号',
  'appearanceTextSizeDesc': '对话正文文字的显示大小。',
  'sizeSmall': '小',
  'sizeMedium': '中',
  'sizeLarge': '大',
  'conversationWidth': '对话宽度',
  'conversationWidthDesc': '消息栏可延展到的宽度。',
  'widthNormal': '标准',
  'widthWide': '加宽',
  'interfaceStyle': '界面风格',
  'interfaceStyleDesc': '界面外观。目前仅“标准”有完整配色，其余会保存待未来的配色方案。',
  'styleStandard': '标准',
  'styleGlass': '玻璃',
  'styleClassic': '经典',
  'styleParchment': '羊皮纸',
  'previewMode': '预览方式',
  'previewModeDesc': '生成的文件在何处打开。',
  'previewNewWindow': '新窗口',
  'previewSidePanel': '侧边栏',
  'previewInline': '就地',
  'expandToolCalls': '展开工具调用',
  'expandToolCallsDesc': '新出现的工具区块默认展开。',
  'promptSuggestions': '提示建议',
  'promptSuggestionsDesc': '智能体会提供后续提示。',
  'provider': '提供商',
  'providerOpenAiCompatible': 'OpenAI 兼容',
  'providerAnthropic': 'Anthropic',
  'providerGoogle': 'Google',
  'apiKey': 'API 密钥',
  'baseUrl': 'Base URL',
  'model': '模型',
  'providerDefault': '提供商默认',
  'keyConfigured': '密钥已配置',
  'noKeyComposerDisabled': '缺少密钥——输入框保持禁用',
  'keyMissing': '缺少密钥',
  'keyStored': '已保存密钥',
  'edit': '编辑',
  'customized': '自定义',
  'testConnection': '测试连接',
  'connectionOk': '{n} 个可用模型',
  'connectionFailed': '无法连接到服务地址。',
  'probeTimeout': '服务地址未及时响应。',
  'fetchingModels': '正在获取模型…',
  'chooseModel': '选择模型',
  'noModelsFetched': '先运行测试连接以载入列表',
  'refreshModels': '载入服务端的模型列表',
  'statsCounts': '{turns} 轮 · {steps} 步',
  'statsLlm': 'LLM {duration}',
  'statsTool': '工具调用 {duration}',
  'statsTtft': '首 token 平均 {duration}',
  'statsTokens': '{tokens} tokens',
  'folder': '文件夹',
  'choose': '选择…',
  'recent': '最近使用',
  'missing': '已失效',
  'folderNotOnDisk': '此文件夹当前不在磁盘上。',
  'fontFamily': '字体族',
  'fontFamilyHint': "'' 跟随主题的代码字体",
  'fontSize': '字号',
  'seedBottomPanel': '底部面板自动开终端',
  'seedBottomPanelDesc': '每次会话中首次展开底部面板时，在那里打开一个终端标签页。',
  'explorerDesc': '工作区文件夹的文件树。',
  'terminalDesc': '工作区文件夹上的 shell。',
  'gitDesc': 'git 变更列表及其差异。',
  'subagentsDesc': '实时子代理与任务视图。',
  'browserDesc': '带地址栏的内置网页视图。',
  'sideChatDesc': '主线程旁的快速提问。',
  'addServer': '添加服务器',
  'serverName': '名称',
  'arguments': '参数',
  'commandStdio': '命令 (stdio)',
  'urlHttp': 'URL (HTTP)',
  'showKey': '显示密钥',
  'hideKey': '隐藏密钥',
  'closeSettings': '关闭设置',
  'forget': '移除',
  'increase': '增大',
  'decrease': '减小',
  'removeServer': '移除服务器',
  'restartWarning': '保存将重连代理。当前会话会被清空；它仍保留在磁盘上，可从侧边栏重新打开。',
};

/// Translates [key] in [locale], interpolating `{name}` placeholders from
/// [params].
///
/// zh falls back to en per-key (en is where strings are written first), and a
/// key missing from both renders as itself — visible in the UI, greppable,
/// and never a blank.
String translate(
  AppLocaleId locale,
  String key, [
  Map<String, Object>? params,
]) {
  var text =
      (locale == AppLocaleId.zh ? zhStrings[key] : null) ??
      enStrings[key] ??
      key;
  if (params != null) {
    for (final entry in params.entries) {
      text = text.replaceAll('{${entry.key}}', '${entry.value}');
    }
  }
  return text;
}

/// The locale seat: mounted by the app above the frame, read by every
/// `context.tr` below it.
class AppLocaleScope extends InheritedWidget {
  const AppLocaleScope({super.key, required this.locale, required super.child});

  final AppLocaleId locale;

  /// The locale below [context], or English when no scope is mounted — the
  /// deterministic default widget tests rely on.
  static AppLocaleId of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppLocaleScope>()?.locale ??
      AppLocaleId.en;

  @override
  bool updateShouldNotify(AppLocaleScope oldWidget) =>
      locale != oldWidget.locale;
}

extension AppLocaleTrX on BuildContext {
  /// Translates [key] in the locale this context sits under.
  String tr(String key, [Map<String, Object>? params]) =>
      translate(AppLocaleScope.of(this), key, params);
}
