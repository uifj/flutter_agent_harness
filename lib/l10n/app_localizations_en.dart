// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'PlanStar';

  @override
  String get close => 'Close';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get restart => 'Restart';

  @override
  String get refresh => 'Refresh';

  @override
  String get save => 'Save';

  @override
  String get saving => 'Saving…';

  @override
  String get saved => 'Saved';

  @override
  String get preview => 'Preview';

  @override
  String get reload => 'Reload from disk';

  @override
  String get reloadDirtyTitle => 'Discard unsaved edits?';

  @override
  String reloadDirtyDesc(String path) {
    return 'Reloading \"$path\" from disk will discard your unsaved edits.';
  }

  @override
  String get settings => 'Settings';

  @override
  String get openSettings => 'Open settings';

  @override
  String get quickPreferences => 'Quick preferences';

  @override
  String get untitled => 'Untitled';

  @override
  String get loading => 'Loading…';

  @override
  String get confirm => 'Confirm';

  @override
  String get remove => 'Remove';

  @override
  String get explorer => 'Explorer';

  @override
  String get terminal => 'Terminal';

  @override
  String get git => 'Source control';

  @override
  String get subagents => 'Sub-agents';

  @override
  String get editor => 'Editor';

  @override
  String get newTab => 'New tab';

  @override
  String get splitDown => 'Split down';

  @override
  String get splitRight => 'Split right';

  @override
  String get closeOthers => 'Close others';

  @override
  String get closeAll => 'Close all';

  @override
  String get sendToSidePanel => 'Send to side panel';

  @override
  String get sendToBottomPanel => 'Send to bottom panel';

  @override
  String get floatInWindow => 'Float in a window';

  @override
  String get dockToSidebar => 'Dock to sidebar';

  @override
  String unknownTabType(String type) {
    return 'This version has nothing to show a \"$type\" tab with.';
  }

  @override
  String terminalN(String n) {
    return 'Terminal $n';
  }

  @override
  String get browser => 'Browser';

  @override
  String get browserBack => 'Back';

  @override
  String get browserForward => 'Forward';

  @override
  String get browserGo => 'Go';

  @override
  String get browserPlaceholder => 'Search or enter address';

  @override
  String get browserOpenExternal => 'Open in default browser';

  @override
  String get browserInvalid => 'That is not a valid address.';

  @override
  String get browserBlockedScheme =>
      'Only http and https addresses can be opened.';

  @override
  String get browserBlockedLoopback => 'Local addresses are refused.';

  @override
  String get browserStart => 'Enter an address above to start browsing.';

  @override
  String get browserUnsupported =>
      'In-app browsing is not available on this platform.';

  @override
  String get sidechat => 'Side chat';

  @override
  String get sideChatNew => 'New side chat';

  @override
  String get sideChatEmpty => 'A lighter conversation beside the main one.';

  @override
  String get sideChatEmptyDesc =>
      'Quick asides that never touch the main thread.';

  @override
  String get sideChatNoModel => 'Connect a model in Settings to chat here.';

  @override
  String get sideChatPlaceholder => 'Ask an aside…';

  @override
  String get sideChatThinking => 'Thinking…';

  @override
  String get filesOpenHere => 'Files open here.';

  @override
  String get clickToOpenFiles => 'Click to open files in this pane.';

  @override
  String get openWorkbenchPanel => 'Open workbench panel';

  @override
  String get collapseWorkbenchPanel => 'Collapse workbench panel';

  @override
  String get openBottomPanel => 'Open bottom panel';

  @override
  String get collapseBottomPanel => 'Collapse bottom panel';

  @override
  String openSidebar(String accel) {
    return 'Open sidebar ($accel)';
  }

  @override
  String collapseSidebar(String accel) {
    return 'Collapse sidebar ($accel)';
  }

  @override
  String get newSession => 'New Session';

  @override
  String get sessions => 'Sessions';

  @override
  String get planMode => 'Plan';

  @override
  String get agentMode => 'Agent';

  @override
  String get noSessionsYet => 'No sessions yet';

  @override
  String get workspaces => 'Workspaces';

  @override
  String get unassignedWorkspace => 'Unassigned';

  @override
  String get historyView => 'History view';

  @override
  String get groupByWorkspace => 'Group by workspace';

  @override
  String get flatList => 'Flat list';

  @override
  String get workspaceActions => 'Workspace actions';

  @override
  String get conversationActions => 'Conversation actions';

  @override
  String get newSessionHere => 'New session';

  @override
  String get showFileTree => 'Show file tree';

  @override
  String get removeWorkspace => 'Remove from list';

  @override
  String get removeWorkspaceHint => 'Keeps its conversations';

  @override
  String get renameSession => 'Rename';

  @override
  String get pinSession => 'Pin to top';

  @override
  String get unpinSession => 'Unpin';

  @override
  String get deleteSession => 'Delete';

  @override
  String get copySessionId => 'Copy session id';

  @override
  String get copyWorkspacePath => 'Copy workspace path';

  @override
  String get revealInFiles => 'Reveal in file manager';

  @override
  String get revealInTree => 'Expand in file tree';

  @override
  String get pinned => 'Pinned';

  @override
  String get renameSessionTitle => 'Rename session';

  @override
  String get deleteSessionTitle => 'Delete this session?';

  @override
  String get deleteSessionBody =>
      'The conversation stays on disk; it only leaves this list.';

  @override
  String get sessionDeleted => 'Session removed from the list';

  @override
  String get revealFailed => 'Could not open that location';

  @override
  String get historyNotSaved => 'The list changed, but that could not be saved';

  @override
  String get addWorkspace => 'Add a folder';

  @override
  String get expandAll => 'Expand all';

  @override
  String get collapseAll => 'Collapse all';

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(String n) {
    return '${n}m';
  }

  @override
  String hoursAgo(String n) {
    return '${n}h';
  }

  @override
  String daysAgo(String n) {
    return '${n}d';
  }

  @override
  String get openDetailsPanel => 'Open details panel';

  @override
  String get closeDetailsPanel => 'Close details panel';

  @override
  String get askAnything => 'Ask anything';

  @override
  String get askAnythingHint => 'Ask anything, or describe a task';

  @override
  String get queueDraftHint =>
      'Keep typing — this queues behind the current turn';

  @override
  String get heroSubtitle => 'Ask anything, or open a workspace to begin';

  @override
  String get workspaceStatusBar => 'Workspace status bar';

  @override
  String get localRepo => 'Local';

  @override
  String get planNoWorkspace =>
      'Choose a workspace folder first — the plan vault is the workspace';

  @override
  String get planNoNoteSelected => 'Pick a markdown file from the tree';

  @override
  String get planNotes => 'Notes';

  @override
  String get seedDeliveryBoard => 'Delivery board';

  @override
  String get seedReadingInbox => 'Reading inbox';

  @override
  String get seedViewBoard => 'Board';

  @override
  String get seedViewAllTasks => 'All tasks';

  @override
  String get seedViewOpenOnly => 'Open only';

  @override
  String get seedViewCards => 'Cards';

  @override
  String get seedViewCalendar => 'Calendar';

  @override
  String get seedViewGraph => 'Graph';

  @override
  String get seedViewList => 'List';

  @override
  String get seedViewTable => 'Table';

  @override
  String get seedRelStatus => 'Status';

  @override
  String get seedRelTags => 'Tags';

  @override
  String get seedRelEffort => 'Effort';

  @override
  String get seedRelDue => 'Due';

  @override
  String get seedOptTodo => 'Todo';

  @override
  String get seedOptDoing => 'Doing';

  @override
  String get seedOptBlocked => 'Blocked';

  @override
  String get seedOptShipped => 'Shipped';

  @override
  String get seedOptUrgent => 'Urgent';

  @override
  String get seedOptClient => 'Client';

  @override
  String get seedOptInternal => 'Internal';

  @override
  String get planNoNotes => 'No markdown files in this workspace';

  @override
  String get planPreview => 'Preview';

  @override
  String get planSource => 'Source';

  @override
  String get planStuckChip => 'Changes not written';

  @override
  String get planStuckTitle => 'Unwritten changes';

  @override
  String get planStuckDesc =>
      'The file on disk did not receive these edits (it may have been changed externally). Leaving now discards them.';

  @override
  String get planStuckConfirm => 'Discard & leave';

  @override
  String get planExternalChanged =>
      'The note changed on disk — autosave paused.';

  @override
  String get planNoteVanished => 'The note was removed on disk — closed.';

  @override
  String get planSaveFailed => 'Saving the note failed.';

  @override
  String get planNewNote => 'New Note';

  @override
  String get planNewFolder => 'New Folder';

  @override
  String get planNewNoteHint => 'File name (without .md)';

  @override
  String get planNewFolderHint => 'Folder name';

  @override
  String get planCreate => 'Create';

  @override
  String get planCancel => 'Cancel';

  @override
  String get planEditorEdit => 'Edit';

  @override
  String get planEditorSource => 'Source';

  @override
  String get planEditorPreview => 'Preview';

  @override
  String get planAddBlock => 'Add block';

  @override
  String get planBlockMenu => 'Block actions';

  @override
  String get planBlockToc => 'Table of contents';

  @override
  String get planBlockRelation => 'Relation';

  @override
  String get planBlockFeatured => 'Featured relations';

  @override
  String get planBlockWidget => 'Widget';

  @override
  String get planBlockUnsupported => 'Unsupported block';

  @override
  String get planFileUploading => 'Uploading…';

  @override
  String get planFileError => 'File failed to load';

  @override
  String get planFileEmpty => 'Empty file';

  @override
  String get planBookmarkEmpty => 'Empty bookmark';

  @override
  String get planBookmarkFetching => 'Fetching…';

  @override
  String get planBookmarkError => 'Bookmark failed to load';

  @override
  String get planBookmarkPrompt => 'Bookmark URL';

  @override
  String get planBlockToggle => 'Toggle section';

  @override
  String get planCalloutIcon => 'Callout icon';

  @override
  String get planEmbedOpen => 'opens externally';

  @override
  String get planEmbedUnavailable => 'not available here';

  @override
  String get planTableActions => 'Row actions';

  @override
  String get planColumnMenu => 'Column actions';

  @override
  String get planTableInsertAbove => 'Insert row above';

  @override
  String get planTableInsertBelow => 'Insert row below';

  @override
  String get planTableMoveUp => 'Move row up';

  @override
  String get planTableMoveDown => 'Move row down';

  @override
  String get planTableDuplicate => 'Duplicate row';

  @override
  String get planTableClear => 'Clear row';

  @override
  String get planTableDelete => 'Delete row';

  @override
  String get planTableInsertLeft => 'Insert column left';

  @override
  String get planTableInsertRight => 'Insert column right';

  @override
  String get planTableDeleteColumn => 'Delete column';

  @override
  String get planActionCopy => 'Copy';

  @override
  String get planActionPaste => 'Paste';

  @override
  String get planActionDrag => 'Drag to move';

  @override
  String get planLinkOpen => 'Open link';

  @override
  String get planLinkPrompt => 'Link URL';

  @override
  String get planLinkRemoveHint => 'Leave empty to remove the link';

  @override
  String get planLinkFailed => 'Could not open that link';

  @override
  String get planActionDuplicate => 'Duplicate';

  @override
  String get planActionDelete => 'Delete';

  @override
  String get planSearchInDoc => 'Search in document';

  @override
  String get planSearchNext => 'Next match';

  @override
  String get planSearchPrevious => 'Previous match';

  @override
  String get planSearchCancel => 'Stop searching';

  @override
  String get planStyleLabel => 'Style';

  @override
  String get planColourLabel => 'Text colour';

  @override
  String get planColourBackground => 'Background';

  @override
  String get planAlignLabel => 'Alignment';

  @override
  String get planSlashPlaceholder => 'Type to filter…';

  @override
  String get planEditorUndo => 'Undo';

  @override
  String get planEditorRedo => 'Redo';

  @override
  String get planAlignLeft => 'Align left';

  @override
  String get planAlignCenter => 'Align centre';

  @override
  String get planAlignRight => 'Align right';

  @override
  String get planSlashText => 'Text';

  @override
  String get planSlashTitle => 'Title';

  @override
  String get planSlashHeading => 'Heading';

  @override
  String get planSlashSubheading => 'Subheading';

  @override
  String get planSlashHighlighted => 'Highlighted';

  @override
  String get planSlashCallout => 'Callout';

  @override
  String get planSlashCheckbox => 'Checkbox';

  @override
  String get planSlashBulleted => 'Bulleted';

  @override
  String get planSlashNumbered => 'Numbered';

  @override
  String get planSlashToggle => 'Toggle';

  @override
  String get planSlashFile => 'File';

  @override
  String get planSlashPicture => 'Picture';

  @override
  String get planSlashVideo => 'Video';

  @override
  String get planSlashBookmark => 'Bookmark';

  @override
  String get planSlashCode => 'Code';

  @override
  String get planSlashLine => 'Divider line';

  @override
  String get planSlashDots => 'Three dots';

  @override
  String get planSlashToc => 'Table of contents';

  @override
  String get planSlashTable => 'Simple table';

  @override
  String get planAllContentTitle => 'All content';

  @override
  String get planTabPages => 'Pages';

  @override
  String get planTabLists => 'Lists';

  @override
  String get planTabMedia => 'Media';

  @override
  String get planTabBookmarks => 'Bookmarks';

  @override
  String get planTabFiles => 'Files';

  @override
  String get planModeAllContent => 'All content';

  @override
  String get planModeUnlinked => 'Unlinked';

  @override
  String get planGroupToday => 'Today';

  @override
  String get planGroupYesterday => 'Yesterday';

  @override
  String get planGroupPrevious7Days => 'Previous 7 days';

  @override
  String get planGroupPrevious14Days => 'Previous 14 days';

  @override
  String get planGroupMonth => 'This month';

  @override
  String get planGroupMonthAndYear => 'Earlier this year';

  @override
  String get planGroupOlder => 'Older';

  @override
  String get planSortCreated => 'Date created';

  @override
  String get planSortModified => 'Date modified';

  @override
  String get planSortName => 'Name';

  @override
  String get planSortLastUsed => 'Last used';

  @override
  String get planAllContentEmpty => 'Nothing here yet';

  @override
  String get planSegmentFeatured => 'Featured';

  @override
  String get planSegmentLocal => 'Local';

  @override
  String get planSegmentHidden => 'Hidden';

  @override
  String get planFeature => 'Add to featured';

  @override
  String get planUnfeature => 'Remove from featured';

  @override
  String get planHide => 'Hide relation';

  @override
  String get planUnhide => 'Unhide relation';

  @override
  String get planRemoveRelation => 'Remove from object';

  @override
  String get planRelationRemoved => 'Relation removed';

  @override
  String get planRelationActions => 'Relation actions';

  @override
  String get planAddRelation => 'Add a relation';

  @override
  String get planNewCollection => 'New set or collection';

  @override
  String get planKindCollection => 'Collection';

  @override
  String get planKindSet => 'Set';

  @override
  String get planKindSetSource =>
      'Source type (records arrive as you create them)';

  @override
  String get planCollectionCreated => 'Created';

  @override
  String planTemplatesTitle(String name) {
    return 'Templates · $name';
  }

  @override
  String get planTemplatesNotAllowed => 'This type does not take templates';

  @override
  String get planTemplatesEmpty => 'No templates yet — new records start blank';

  @override
  String get planTemplateNew => 'New template';

  @override
  String get planTemplateNewName => 'Untitled template';

  @override
  String get planTemplateSetDefault => 'Set as default';

  @override
  String get planTemplateDuplicate => 'Duplicate';

  @override
  String get planTemplateDelete => 'Delete';

  @override
  String get planTemplateDeleted => 'Template deleted';

  @override
  String get planTemplateDefault => 'Default';

  @override
  String get planDateToday => 'Today';

  @override
  String get planDateYesterday => 'Yesterday';

  @override
  String get planDateTomorrow => 'Tomorrow';

  @override
  String get planDateNoObjects => 'No objects on this day';

  @override
  String get planGalleryTitle => 'Gallery';

  @override
  String get planGalleryInstall => 'Install';

  @override
  String get planGalleryInstalling => 'Installing…';

  @override
  String planGalleryDone(String name) {
    return 'Installed as $name';
  }

  @override
  String get planGalleryInstalled => 'Installed';

  @override
  String get planGalleryUnsupported =>
      'Nothing in this pack fits this workspace';

  @override
  String get planSectionPinned => 'Pinned';

  @override
  String get planSectionFavorites => 'My favourites';

  @override
  String get planSectionRecent => 'Recently edited';

  @override
  String get planSectionTypes => 'Object types';

  @override
  String get planWidgetMenu => 'Widget actions';

  @override
  String get planWidgetEmpty => 'Nothing here yet';

  @override
  String get planWidgetFavorites => 'Favourites';

  @override
  String get planWidgetRecent => 'Recently edited';

  @override
  String get planWidgetBin => 'Bin';

  @override
  String get planWidgetAllObjects => 'All objects';

  @override
  String get planWidgetTypes => 'Object types';

  @override
  String get planWidgetChangeType => 'Change widget type';

  @override
  String get planWidgetRemove => 'Remove widget';

  @override
  String get planWidgetRemoved => 'Widget removed';

  @override
  String get planWidgetEmptyBin => 'Empty bin';

  @override
  String get planWidgetBinEmptied => 'Bin emptied';

  @override
  String get planWidgetChangeHome => 'Change home';

  @override
  String get planWidgetCreateObject => 'Create object of type';

  @override
  String get planSlashStyle => 'Style';

  @override
  String get planSlashMedia => 'Media';

  @override
  String get planSlashOther => 'Other';

  @override
  String get planSlashObjects => 'Objects';

  @override
  String get planSlashObjectsEmpty =>
      'Objects arrive with the object library (P6)';

  @override
  String get planSlashProperties => 'Properties';

  @override
  String get planSlashPropertiesEmpty =>
      'Properties arrive with the object library (P6)';

  @override
  String get planSlashActions => 'Actions';

  @override
  String get planSlashInsertBelow => 'Insert below';

  @override
  String get planOpenCollection => 'Open a collection';

  @override
  String get planFileNameExists => 'A file with this name already exists';

  @override
  String get planFolderNameExists => 'A folder with this name already exists';

  @override
  String get planSwitchWorkspace => 'Switch workspace';

  @override
  String get planExtensions => 'Extensions';

  @override
  String get planBoard => 'Board';

  @override
  String get planCalendar => 'Calendar';

  @override
  String get planTable => 'Table';

  @override
  String get planAddTask => 'Add';

  @override
  String get planTaskTitleHint => 'New task title';

  @override
  String get planTaskDateHint => 'yyyy-mm-dd';

  @override
  String get planGroupTodo => 'To do';

  @override
  String get planGroupInProgress => 'In progress';

  @override
  String get planGroupReview => 'Review';

  @override
  String get planGroupDone => 'Done';

  @override
  String get planColumnStatus => 'Status';

  @override
  String get planColumnTask => 'Task';

  @override
  String get planColumnDue => 'Due';

  @override
  String get planNoDue => '—';

  @override
  String get chooseWorkspaceFolder => 'Choose a workspace folder';

  @override
  String get chooseAFolder => 'Choose a folder…';

  @override
  String get send => 'Send';

  @override
  String get stop => 'Stop';

  @override
  String get deepDiving => 'Deep diving...';

  @override
  String get inputQueue => 'Waiting to send';

  @override
  String get queueInput => 'Queue';

  @override
  String get guideNow => 'Steer';

  @override
  String get deliveryQueue => 'After this turn';

  @override
  String get deliveryGuide => 'Steer this turn';

  @override
  String get dragToReorder => 'Drag to reorder';

  @override
  String get rewindPill => 'Undo this write';

  @override
  String get rewindTitle => 'Go back to before this write?';

  @override
  String get rewindConfirm => 'Go back';

  @override
  String get rewindNothing => 'Nothing left to undo.';

  @override
  String get rewindRestores => 'Restores';

  @override
  String get rewindDeletes => 'Deletes';

  @override
  String get rewindSkips => 'Leaves alone';

  @override
  String get rewindWhyChanged => 'edited outside the agent';

  @override
  String get rewindWhyNoImage => 'no before-image was stored';

  @override
  String get attachImage => 'Attach images';

  @override
  String get attach => 'Attach';

  @override
  String get chooseImages => 'Choose image files…';

  @override
  String get chooseDocuments => 'Attach documents (PDF, text)…';

  @override
  String get pasteImage => 'Paste image from clipboard';

  @override
  String get pasteImageFailed => 'The clipboard has no image.';

  @override
  String imagesUnsupportedByModel(String model) {
    return '\"$model\" does not accept images. Attach it as a document instead, or pick a vision model in the model menu.';
  }

  @override
  String get removeAttachment => 'Remove';

  @override
  String get dropFilesHint => 'Drop images to attach';

  @override
  String get askEveryTime => 'Ask every time';

  @override
  String get askEveryTimeDesc =>
      'The agent interrupts for approval before it writes or runs anything.';

  @override
  String get planFirst => 'Plan first';

  @override
  String get planFirstDesc =>
      'Read-only until a plan is approved; the agent may not change anything.';

  @override
  String get autoRun => 'Auto-run';

  @override
  String get autoRunDesc =>
      'Gated tools run without asking. Use when you trust the turn.';

  @override
  String get approvalMode => 'Approval mode';

  @override
  String get commandHint => 'Type / for commands';

  @override
  String get commands => 'Commands';

  @override
  String get files => 'Files';

  @override
  String get searchingFiles => 'Searching the workspace…';

  @override
  String get commandNewSession => 'Start a new session';

  @override
  String get quickPhrases => 'Quick phrases';

  @override
  String get messageCopyText => 'Copy text';

  @override
  String get messageExportMd => 'Export as Markdown';

  @override
  String get messageExportTxt => 'Export as plain text';

  @override
  String get commandCopyTranscript => 'Copy the whole conversation';

  @override
  String get commandCopyTranscriptDesc =>
      'Every user and assistant message, in order, onto the clipboard';

  @override
  String get preRestoreTitle => 'Pre-restore snapshots';

  @override
  String get preRestoreDesc =>
      'Each restore first copies the files it will overwrite here. The newest 3 are kept.';

  @override
  String get settingsCards => 'Instruction cards';

  @override
  String get settingsCardsIntro =>
      'Prompt cards you write once and enable per preference; enabled cards are injected with the workspace instructions.';

  @override
  String get cardAdd => 'Add card';

  @override
  String get cardDelete => 'Delete card';

  @override
  String get cardTitleHint => 'Card title';

  @override
  String get cardTextHint => 'The prompt text to inject';

  @override
  String get cardsEmpty => 'No cards yet.';

  @override
  String get settingsTasks => 'Scheduled tasks';

  @override
  String get settingsTasksIntro =>
      'Prompts that run on a schedule while the app is open. A task that needs an answer fails and waits for its next minute.';

  @override
  String get taskAdd => 'Add task';

  @override
  String get taskDelete => 'Delete task';

  @override
  String get taskNameHint => 'Task name';

  @override
  String get taskPromptHint => 'The prompt to run';

  @override
  String get taskHourHint => 'Hour';

  @override
  String get taskMinuteHint => 'Min';

  @override
  String taskWeekday(String n) {
    return 'Day $n';
  }

  @override
  String get tasksEmpty => 'No tasks yet.';

  @override
  String get settingsEnvironment => 'Environment variables';

  @override
  String get settingsEnvironmentIntro =>
      'Injected into shell commands; reference them as \$NAME. Values live in the keychain and are redacted from command output shown to the model.';

  @override
  String get envAdd => 'Add variable';

  @override
  String get envDelete => 'Delete variable';

  @override
  String get envNameHint => 'NAME (letters, digits, underscore)';

  @override
  String get envValueHint => 'Value — stored in the keychain';

  @override
  String get settingsPhrases => 'Quick phrases';

  @override
  String get settingsPhrasesIntro =>
      'Reusable snippets the composer inserts at the cursor. Up to 20.';

  @override
  String get quickPhraseAdd => 'Add phrase';

  @override
  String get quickPhraseDelete => 'Delete phrase';

  @override
  String get quickPhraseFull => 'The list is full — remove one to add another.';

  @override
  String get quickPhraseTitleHint => 'Menu title';

  @override
  String get quickPhraseTextHint => 'The text to insert';

  @override
  String get commandCompress => 'Compress this conversation';

  @override
  String get commandCompressDesc =>
      'Summarize it and continue in a fresh session that remembers the summary';

  @override
  String get compressStarted => 'Compressing…';

  @override
  String get compressDone => 'Compressed. The summary rides your next message.';

  @override
  String get compressFailed =>
      'Compression failed. The conversation is unchanged.';

  @override
  String get commandNewSessionDesc =>
      'Leave this conversation on disk and start a fresh one.';

  @override
  String get commandAskMode => 'Switch to ask mode';

  @override
  String get commandAskModeDesc => 'Every gated call interrupts for approval.';

  @override
  String get commandPlanMode => 'Switch to plan mode';

  @override
  String get commandPlanModeDesc =>
      'The workspace is read-only until the plan is approved.';

  @override
  String get commandAutoMode => 'Switch to auto mode';

  @override
  String get commandAutoModeDesc => 'Gated tools run without prompting.';

  @override
  String get waitingForApproval => 'Waiting for approval';

  @override
  String approvalTitle(String name) {
    return 'Tool $name requests privileged execution';
  }

  @override
  String get askUserStrip => 'The agent needs your input';

  @override
  String get askUserOther => 'Other — type it instead';

  @override
  String get askUserSkip => 'Skip';

  @override
  String get askUserSkipped => 'Skipped';

  @override
  String get askUserOpenHint => 'Type your answer';

  @override
  String get askUserSubmit => 'Submit answer';

  @override
  String get reject => 'Reject';

  @override
  String get allowOnce => 'Allow once';

  @override
  String get alwaysAllow => 'Always allow';

  @override
  String get approvalsTitle => 'Approval rules';

  @override
  String get approvalsNote =>
      'Commands and paths you allowed once, so the agent stops asking about them. They apply to this folder only.';

  @override
  String get approvalsEmpty => 'No saved approvals for this folder.';

  @override
  String get approvalAllowed => 'The agent may do this without asking';

  @override
  String get approvalDenied => 'Never ask — and never let it through';

  @override
  String get forgetWorkspaceApprovals => 'Remove all for this folder';

  @override
  String get oneReplacement => '1 replacement';

  @override
  String nReplacements(String n) {
    return '$n replacements';
  }

  @override
  String get overwritesExistingFile => 'overwrites an existing file';

  @override
  String inWorkdir(String dir) {
    return 'in $dir';
  }

  @override
  String get planReviewHeader => 'Plan review';

  @override
  String get planDiscuss => 'Discuss';

  @override
  String get planDecline => 'Decline';

  @override
  String get planApprove => 'Approve';

  @override
  String get planApprovedMessage => 'The plan is approved. Proceed with it.';

  @override
  String get planDeclinedMessage => 'The plan is declined. Revise it.';

  @override
  String get details => 'Details';

  @override
  String get closeDetails => 'Close details';

  @override
  String get detailsEmpty =>
      'Click a tool row in the message flow to view its details';

  @override
  String get detailsNotInWindow => 'This call is outside the current window';

  @override
  String get input => 'Input';

  @override
  String get output => 'Output';

  @override
  String get running => 'Running…';

  @override
  String get toolRunning => 'Running';

  @override
  String get toolDone => 'Done';

  @override
  String get toolFailed => 'Failed';

  @override
  String get declined => 'Declined';

  @override
  String get tabHasNoFile => 'This tab has no file.';

  @override
  String get noWorkspaceNoFile =>
      'No workspace folder is set, so no file can be read.';

  @override
  String get fileNoLongerExists => 'This file no longer exists.';

  @override
  String get looksLikeBinary =>
      'This looks like a binary file. Nothing here can show it.';

  @override
  String readOnlyTooLarge(String mb) {
    return 'Read-only: this file is larger than $mb MB.';
  }

  @override
  String couldNotSave(String message) {
    return 'Could not save: $message';
  }

  @override
  String get unsaved => 'unsaved';

  @override
  String get noWorkspaceNothingToList =>
      'No workspace folder is set, so there is nothing to list.';

  @override
  String get folderEmpty => 'This folder is empty.';

  @override
  String get searchFiles => 'Search files';

  @override
  String get open => 'Open';

  @override
  String get openInTreeTab => 'Open in a file tree tab';

  @override
  String noMatches(String query) {
    return 'No files match \"$query\".';
  }

  @override
  String couldNotStartShell(String message) {
    return 'Could not start the shell: $message';
  }

  @override
  String get shellExited => 'The shell exited.';

  @override
  String shellExitedCode(String code) {
    return 'The shell exited ($code).';
  }

  @override
  String get gitNotARepo => 'This directory is not a git repository';

  @override
  String get gitTooManyChanges =>
      'Too many changes; showing the first 2,000 entries';

  @override
  String stagedCount(String n) {
    return 'Staged ($n)';
  }

  @override
  String unstagedCount(String n) {
    return 'Unstaged ($n)';
  }

  @override
  String get stage => 'Stage';

  @override
  String get unstage => 'Unstage';

  @override
  String get stageAll => 'Stage all';

  @override
  String get unstageAll => 'Unstage all';

  @override
  String get history => 'History';

  @override
  String get noChanges => 'No changes';

  @override
  String get commitPlaceholder => 'Commit message (Ctrl+Enter)';

  @override
  String get commit => 'Commit';

  @override
  String get loadMore => 'Load more';

  @override
  String historyLoadError(String message) {
    return 'Failed to load more history: $message';
  }

  @override
  String get branchSwitchFailed => 'Branch switch failed';

  @override
  String get openEditor => 'Open editor';

  @override
  String get discardChanges => 'Discard changes';

  @override
  String discardDesc(String path) {
    return 'This discards the worktree changes of \"$path\" (not recoverable).';
  }

  @override
  String get copyRelative => 'Copy relative path';

  @override
  String get copyAbsolute => 'Copy absolute path';

  @override
  String get wrapLines => 'Wrap long lines';

  @override
  String get showOnlyChanged => 'Changed files only';

  @override
  String get nothingChanged => 'Nothing is changed in this folder';

  @override
  String get viewCommitDiff => 'View commit diff';

  @override
  String get copyShortHash => 'Copy short hash';

  @override
  String get copyFullHash => 'Copy full hash';

  @override
  String get copySubject => 'Copy subject';

  @override
  String get revertCommit => 'Revert commit';

  @override
  String revertDesc(String subject) {
    return 'Create a new commit on the current branch that reverts \"$subject\".';
  }

  @override
  String get cherryPickCommit => 'Cherry-pick commit';

  @override
  String cherryPickDesc(String subject) {
    return 'Apply the changes of \"$subject\" to the current branch.';
  }

  @override
  String get diffBinary => 'Binary';

  @override
  String get diffAdded => 'Added';

  @override
  String get diffDeleted => 'Deleted';

  @override
  String get diffRenamed => 'Renamed';

  @override
  String get subagentMainAgent => 'Main agent';

  @override
  String get subagentIdle => 'Idle';

  @override
  String get thinking => 'Thinking…';

  @override
  String get noSubagentsYet => 'No sub-agents yet';

  @override
  String get subagentsEmptyDesc =>
      'Work the main agent delegates will be tracked here.';

  @override
  String get noOutput => 'No output';

  @override
  String subagentCount(String count) {
    return '$count subagent';
  }

  @override
  String subagentsCount(String count) {
    return '$count subagents';
  }

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsModels => 'Models';

  @override
  String get settingsWorkspace => 'Workspace';

  @override
  String get settingsWorkbench => 'Workbench';

  @override
  String get settingsExtensions => 'Extensions';

  @override
  String get settingsBackup => 'Backup & Restore';

  @override
  String get settingsBackupIntro =>
      'Export all your data to a file, or restore from a previous backup.';

  @override
  String get backupCreate => 'Create backup';

  @override
  String get backupCreateDesc =>
      'Export settings, sessions, and tasks to a zip file.';

  @override
  String get providersSaveCurrent => 'Save connection';

  @override
  String get providersSaveCurrentDesc =>
      'Keep the connection you just tested in the book, so you can switch between providers without re-entering keys. Keys stay in the system keychain.';

  @override
  String get providersBookEmpty =>
      'No saved connections yet. Configure one above, then save it here.';

  @override
  String get providersActivate => 'Use';

  @override
  String get providersDelete => 'Delete';

  @override
  String get modelsListLabel => 'Model list';

  @override
  String get modelsActiveTag => 'active';

  @override
  String get modelsRemove => 'Remove from list';

  @override
  String get modelsAddHint => 'Add a model id, press Enter';

  @override
  String get notificationsOn => 'Raise the window when a run finishes';

  @override
  String get notificationsOnDesc =>
      'When the window is hidden in the tray, finishing a run brings it back to the front.';

  @override
  String get helpDocs => 'Product docs';

  @override
  String get helpCommunity => 'User community';

  @override
  String get helpReportIssue => 'Report an issue';

  @override
  String get helpFeatureRequest => 'Request a feature';

  @override
  String get helpReleases => 'Check for updates';

  @override
  String updateAvailableTitle(String version) {
    return 'New version $version available';
  }

  @override
  String updateBody(String current, String new_) {
    return 'Current $current, latest $new_.';
  }

  @override
  String get updateSkip => 'Skip this version';

  @override
  String get updateDownload => 'Download';

  @override
  String get updateUpToDate => 'You\'re on the latest version.';

  @override
  String get updateCheckFailed => 'Update check failed — try again later.';

  @override
  String get helpAbout => 'About PlanStar';

  @override
  String get helpAboutTitle => 'PlanStar';

  @override
  String helpAboutBody(String version) {
    return 'A desktop AI agent workbench: agent conversations over Genkit and a plan workspace with Anytype-style data views. Version $version.';
  }

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authSignOut => 'Sign out';

  @override
  String get welcomeTitle => 'Welcome to PlanStar';

  @override
  String get welcomeIntro =>
      'Connect your account to start using the workbench.';

  @override
  String get welcomeApiKeyIntro =>
      'Enter an API key from your provider to start.';

  @override
  String get welcomeProviderZai => 'Continue with Z.ai';

  @override
  String get welcomeProviderBigmodel => 'Continue with BigModel';

  @override
  String get welcomeRegionGlobal => 'Global';

  @override
  String get welcomeRegionCn => 'CN';

  @override
  String get welcomeUseApiKey => 'Use API key';

  @override
  String get welcomeApiKeyHint => 'API key';

  @override
  String get welcomeApiKeySave => 'Save and start';

  @override
  String get welcomeSkip => 'Skip for now';

  @override
  String get welcomeBackToProviders => 'Back to sign-in options';

  @override
  String get welcomeWaiting => 'Waiting for authentication in your browser…';

  @override
  String get welcomeCancelWait => 'Cancel';

  @override
  String get welcomeFlowFailed => 'The sign-in flow failed. Try again.';

  @override
  String get welcomeFlowUnavailable =>
      'No backend endpoint is configured, so browser sign-in is unavailable. Use an API key instead.';

  @override
  String get welcomeRegister => 'Create an account';

  @override
  String get welcomeLater => 'Maybe later';

  @override
  String get settingsShortcuts => 'Shortcuts';

  @override
  String get settingsShortcutsIntro =>
      'Every keyboard command in one place. Editing bindings arrives in a later update.';

  @override
  String get shortcutToggleWindow => 'Show or hide the window';

  @override
  String get shortcutNewSession => 'New session';

  @override
  String get shortcutOpenSettings => 'Open settings';

  @override
  String get shortcutToggleSidebar => 'Toggle the sidebar';

  @override
  String get settingsUsage => 'Usage';

  @override
  String get settingsUsageIntro =>
      'Local model usage, kept for 30 days on this machine only. Nothing leaves the device.';

  @override
  String get usageTurns => 'Model turns recorded';

  @override
  String get usageTotalTokens => 'Tokens used';

  @override
  String get usageErrorRate => 'Turn error rate';

  @override
  String get usageCrashLogTitle => 'Crash & error archive';

  @override
  String get usageCrashLogDesc =>
      'Local reports for the last crashes, kept for the newest 5 files. Nothing is uploaded.';

  @override
  String get usageCrashLogOpen => 'Open folder';

  @override
  String get settingsDiagnostics => 'Diagnostics';

  @override
  String get settingsDiagnosticsIntro =>
      'Local logs for debugging the agent: one line per model call, and — if you turn it on — the full messages sent to the model. Kept for 30 days on this machine only.';

  @override
  String get diagnosticRequestLog => 'Request log';

  @override
  String get diagnosticRequestLogDesc =>
      'Record every model call: duration, outcome and token usage.';

  @override
  String get diagnosticContextLog => 'Context snapshot';

  @override
  String get diagnosticContextLogDesc =>
      'Also record the full messages each call sends to the model. Large; off by default.';

  @override
  String get diagnosticFolderTitle => 'Diagnostics folder';

  @override
  String get diagnosticFolderDesc =>
      'requests-*.jsonl and contexts-*.jsonl, one file per month.';

  @override
  String get settingsFeedback => 'Send feedback';

  @override
  String get settingsFeedbackDesc =>
      'Report a problem or suggest an idea. Opens a pre-filled draft on the GitHub issue tracker that you review and submit.';

  @override
  String get settingsFeedbackOpen => 'Open form';

  @override
  String get feedbackIssueOpened => 'Opened a feedback draft in your browser';

  @override
  String get settingsReset => 'Reset';

  @override
  String get settingsResetDesc =>
      'Quarantine settings and preferences and start from defaults. The API key is removed from the keychain. Sessions and plan data are kept.';

  @override
  String get settingsResetConfirmTitle => 'Reset settings and preferences?';

  @override
  String get settingsResetConfirmBody =>
      'Your current settings file is kept as a .corrupt- copy next to the new one, so this is recoverable by hand. Sessions and plan data are untouched.';

  @override
  String get settingsResetDone => 'Settings and preferences were reset';

  @override
  String get backupExport => 'Export';

  @override
  String get backupRestore => 'Restore from backup';

  @override
  String get backupRestoreDesc =>
      'Import data from a backup file, overwriting current data.';

  @override
  String get backupImport => 'Import';

  @override
  String backupCreated(String count) {
    return 'Backup created with $count files.';
  }

  @override
  String backupRestored(String count) {
    return 'Restored $count files. Restart to apply.';
  }

  @override
  String get backupFailed => 'Backup failed';

  @override
  String get searchSettings => 'Search settings…';

  @override
  String get settingsGeneralIntro => 'How the app itself looks and behaves.';

  @override
  String get settingsAppearanceIntro =>
      'The face and width of the conversation, and how generated files are shown.';

  @override
  String get settingsModelsIntro => 'Which endpoint this build talks to.';

  @override
  String get settingsWorkspaceIntro =>
      'The one folder the file tools may read and write. They refuse every call while this is empty, and refuse any path that resolves outside it.';

  @override
  String get settingsTerminalIntro =>
      'The face every terminal tab wears. Applied live — no restart, not even a Save.';

  @override
  String get settingsTabsIntro =>
      'Which tab types the + menu offers and the opens accept. Tabs already open keep rendering until you close them.';

  @override
  String get settingsMcpIntro =>
      'External tools the agent may call, named <server>/<tool>. A server is launched over stdio from a command, or reached over HTTP at a URL — fill in one or the other. Changes take effect after the runtime is rebuilt (Save), and a server that fails to connect simply contributes nothing.';

  @override
  String get settingsSkillsIntro =>
      'The folder whose sub-directories each hold a SKILL.md. The agent lists them in its system prompt and loads one with the use_skill tool. Empty means <application support>/skills.';

  @override
  String get settingsMcpServers => 'MCP servers';

  @override
  String get settingsSkills => 'Skills';

  @override
  String get tabs => 'Tabs';

  @override
  String get theme => 'Theme';

  @override
  String get themeDesc => 'Light, dark, or whatever the system is doing.';

  @override
  String get followSystem => 'Follow system';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageDesc => 'English or Chinese, or follow the system.';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';

  @override
  String get appearanceTextSize => 'Text size';

  @override
  String get appearanceTextSizeDesc =>
      'How large the conversation text renders.';

  @override
  String get sizeSmall => 'Small';

  @override
  String get sizeMedium => 'Medium';

  @override
  String get sizeLarge => 'Large';

  @override
  String get conversationWidth => 'Conversation width';

  @override
  String get conversationWidthDesc => 'How wide the message column stretches.';

  @override
  String get widthNormal => 'Normal';

  @override
  String get widthWide => 'Wide';

  @override
  String get expandToolCalls => 'Expand tool calls';

  @override
  String get expandToolCallsDesc => 'Newly shown tool blocks start open.';

  @override
  String get provider => 'Provider';

  @override
  String get providerOpenAiCompatible => 'OpenAI-compatible';

  @override
  String get providerAnthropic => 'Anthropic';

  @override
  String get providerGoogle => 'Google';

  @override
  String get apiKey => 'API key';

  @override
  String get baseUrl => 'Base URL';

  @override
  String get model => 'Model';

  @override
  String get providerDefault => 'provider default';

  @override
  String get keyConfigured => 'Key configured';

  @override
  String get noKeyComposerDisabled => 'No key — the composer stays disabled';

  @override
  String get keyMissing => 'Key missing';

  @override
  String get keyStored => 'A key is stored';

  @override
  String get edit => 'Edit';

  @override
  String get customized => 'Customized';

  @override
  String get testConnection => 'Test connection';

  @override
  String connectionOk(String n) {
    return '$n models available';
  }

  @override
  String get connectionFailed => 'Could not reach the endpoint.';

  @override
  String get probeTimeout => 'The endpoint did not answer in time.';

  @override
  String get fetchingModels => 'Fetching models…';

  @override
  String get chooseModel => 'Choose a model';

  @override
  String get noModelsFetched => 'Run Test connection to load the list';

  @override
  String get refreshModels => 'Load the endpoint\'s list';

  @override
  String get modelManagement => 'Model management';

  @override
  String statsCounts(String turns, String steps) {
    return '$turns turns · $steps steps';
  }

  @override
  String statsLlm(String duration) {
    return 'LLM $duration';
  }

  @override
  String statsTool(String duration) {
    return 'Tool call $duration';
  }

  @override
  String statsTtft(String duration) {
    return 'TTFT avg $duration';
  }

  @override
  String statsTokens(String tokens) {
    return '$tokens tokens';
  }

  @override
  String get folder => 'Folder';

  @override
  String get choose => 'Choose…';

  @override
  String get recent => 'Recent';

  @override
  String get missing => 'missing';

  @override
  String get folderNotOnDisk => 'This folder is not on disk right now.';

  @override
  String get fontFamily => 'Font family';

  @override
  String get fontFamilyHint => '\'\' follows the theme\'s code font';

  @override
  String get fontSize => 'Font size';

  @override
  String get seedBottomPanel => 'Seed the bottom panel';

  @override
  String get seedBottomPanelDesc =>
      'Expanding the bottom panel for the first time in a session opens a terminal tab there.';

  @override
  String get explorerDesc => 'The file tree over the workspace folder.';

  @override
  String get terminalDesc => 'A shell over the workspace folder.';

  @override
  String get gitDesc => 'The git change list and its diffs.';

  @override
  String get subagentsDesc => 'The live sub-agent and job view.';

  @override
  String get browserDesc => 'The built-in web view with its address bar.';

  @override
  String get sideChatDesc => 'Quick asides beside the main thread.';

  @override
  String get addServer => 'Add server';

  @override
  String get serverName => 'Name';

  @override
  String get arguments => 'Arguments';

  @override
  String get commandStdio => 'Command (stdio)';

  @override
  String get urlHttp => 'URL (HTTP)';

  @override
  String get showKey => 'Show key';

  @override
  String get hideKey => 'Hide key';

  @override
  String get closeSettings => 'Close settings';

  @override
  String get forget => 'Forget';

  @override
  String get increase => 'Increase';

  @override
  String get decrease => 'Decrease';

  @override
  String get removeServer => 'Remove server';

  @override
  String get restartWarning =>
      'Saving reconnects the agent. The open conversation is cleared; it stays on disk and can be reopened from the sidebar.';

  @override
  String get planCellEmpty => 'No value';

  @override
  String get planCellChecked => 'Marked done';

  @override
  String get planCellUnchecked => 'Mark not done';

  @override
  String get planFieldName => 'Name';

  @override
  String get planUntitled => 'Untitled';

  @override
  String get planNewRow => 'New row';

  @override
  String get planNoRecords => 'Nothing here yet';

  @override
  String get planRecordCount => 'records';

  @override
  String get planColumnNoStatus => 'No status';

  @override
  String get planColumnChecked => 'Checked';

  @override
  String get planCollections => 'Collections';

  @override
  String get planLibrary => 'Library';

  @override
  String get planWidgetStrip => 'Home widgets';

  @override
  String get planBinTitle => 'Bin';

  @override
  String get planBinEmpty => 'The bin is empty';

  @override
  String get planBinEmptyBody => 'Every binned record will be gone for good.';

  @override
  String get planBinActions => 'Bin actions';

  @override
  String get planBinned => 'binned';

  @override
  String get planRestored => 'Restored';

  @override
  String get planObjectInfoTitle => 'Object info';

  @override
  String get planTemplatesTitleShort => 'Templates';

  @override
  String get planCollectionMenu => 'Collection actions';

  @override
  String get planMarkBold => 'Bold';

  @override
  String get planMarkItalic => 'Italic';

  @override
  String get planMarkStrike => 'Strikethrough';

  @override
  String get planMarkUnderline => 'Underline';

  @override
  String get planMarkCode => 'Code';

  @override
  String get planMarkLink => 'Link';

  @override
  String planCalendarUndated(String count) {
    return '$count record(s) without a date';
  }

  @override
  String get planColumnUnchecked => 'Unchecked';

  @override
  String get planSortBy => 'Sort';

  @override
  String get planSortAdd => 'Add sort';

  @override
  String get planSortDirection => 'Sort direction';

  @override
  String get planSortEmpty => 'Where empty values go';

  @override
  String get planSortAsc => 'Ascending';

  @override
  String get planSortDesc => 'Descending';

  @override
  String get planSortClear => 'Clear this sort';

  @override
  String get planHideField => 'Hide field';

  @override
  String get planFilterTitle => 'Filter';

  @override
  String get planFilterAdd => 'Add filter';

  @override
  String get planFilterCondition => 'Condition';

  @override
  String get planFilterValue => 'Value';

  @override
  String get planFilterPickValue => 'Set value';

  @override
  String get planFilterOperator => 'Operator';

  @override
  String get planFilterNestedUnsupported =>
      'Nested rules are desktop-only and are not applied here';

  @override
  String get planNewOption => 'New option';

  @override
  String get planDateLiteral => 'Exact date';

  @override
  String get planRemove => 'Remove';

  @override
  String get planDelete => 'Delete';

  @override
  String get planSave => 'Save';

  @override
  String get planLayoutTitle => 'Layout';

  @override
  String get planLayoutHideIcon => 'Hide icons';

  @override
  String get planLayoutCardSize => 'Card size';

  @override
  String get planLayoutCover => 'Cover';

  @override
  String get planLayoutNone => 'None';

  @override
  String get planLayoutCoverFit => 'Cover fits the card';

  @override
  String get planLayoutGroupBy => 'Group by';

  @override
  String get planLayoutColorColumns => 'Colour columns';

  @override
  String get planLayoutDefaultType => 'Default type for new records';

  @override
  String get planLayoutDefaultTemplate => 'Template for new records';

  @override
  String get planFieldsTitle => 'Fields';

  @override
  String get planFieldDateFormat => 'Date format';

  @override
  String get planFieldWidth => 'Width';

  @override
  String get planAllViews => 'All views';

  @override
  String get planAddView => 'New view';

  @override
  String get planViewSettings => 'View settings';

  @override
  String get planToggleHeader => 'Hide header';

  @override
  String get planViewSoonTag => 'not on desktop-size yet';

  @override
  String get planViewRename => 'Rename view';

  @override
  String get planViewDuplicate => 'Duplicate view';

  @override
  String get planViewMoveLeft => 'Move left';

  @override
  String get planViewMoveRight => 'Move right';

  @override
  String get planViewDelete => 'Delete view';

  @override
  String get planViewDeleteBody =>
      'This view and its filters are removed. The records stay.';

  @override
  String get planViewDeleted => 'View deleted';

  @override
  String get planViewCalendarUnsupported =>
      'Calendar view is not available in this workspace yet. Change the view type, or create a new view to reach your data.';

  @override
  String get planViewGraphUnsupported =>
      'Graph view is not available in this workspace yet. Change the view type, or create a new view to reach your data.';

  @override
  String get planCollectionMissing => 'This collection is no longer here';

  @override
  String get planRenameCollection => 'Rename collection';

  @override
  String get planRecordTitle => 'Record';

  @override
  String get planRecordNoFields => 'No fields in this view';

  @override
  String get planFavorite => 'Add to favorites';

  @override
  String get planUnfavorite => 'Remove from favorites';

  @override
  String get planRestore => 'Restore';

  @override
  String get planMoveToBin => 'Move to bin';

  @override
  String get planDuplicate => 'Duplicate';

  @override
  String get planCondEqual => 'is';

  @override
  String get planCondNotEqual => 'is not';

  @override
  String get planCondGreater => 'greater than';

  @override
  String get planCondGreaterOrEqual => 'greater than or equal';

  @override
  String get planCondLess => 'less than';

  @override
  String get planCondLessOrEqual => 'less than or equal';

  @override
  String get planCondLike => 'contains';

  @override
  String get planCondNotLike => 'does not contain';

  @override
  String get planCondIn => 'is any of';

  @override
  String get planCondNotIn => 'is not any of';

  @override
  String get planCondEmpty => 'is empty';

  @override
  String get planCondNotEmpty => 'is not empty';

  @override
  String get planCondAllIn => 'has all of';

  @override
  String get planCondNotAllIn => 'does not have all of';

  @override
  String get planCondNone => 'has none of';

  @override
  String get planCondExactIn => 'is exactly';

  @override
  String get planCondNotExactIn => 'is not exactly';

  @override
  String get planCondExists => 'exists';
}
