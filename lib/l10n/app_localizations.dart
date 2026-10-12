import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'PlanStar'**
  String get appName;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @restart.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get restart;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload from disk'**
  String get reload;

  /// No description provided for @reloadDirtyTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard unsaved edits?'**
  String get reloadDirtyTitle;

  /// No description provided for @reloadDirtyDesc.
  ///
  /// In en, this message translates to:
  /// **'Reloading \"{path}\" from disk will discard your unsaved edits.'**
  String reloadDirtyDesc(String path);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @quickPreferences.
  ///
  /// In en, this message translates to:
  /// **'Quick preferences'**
  String get quickPreferences;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @explorer.
  ///
  /// In en, this message translates to:
  /// **'Explorer'**
  String get explorer;

  /// No description provided for @terminal.
  ///
  /// In en, this message translates to:
  /// **'Terminal'**
  String get terminal;

  /// No description provided for @git.
  ///
  /// In en, this message translates to:
  /// **'Source control'**
  String get git;

  /// No description provided for @subagents.
  ///
  /// In en, this message translates to:
  /// **'Sub-agents'**
  String get subagents;

  /// No description provided for @editor.
  ///
  /// In en, this message translates to:
  /// **'Editor'**
  String get editor;

  /// No description provided for @newTab.
  ///
  /// In en, this message translates to:
  /// **'New tab'**
  String get newTab;

  /// No description provided for @splitDown.
  ///
  /// In en, this message translates to:
  /// **'Split down'**
  String get splitDown;

  /// No description provided for @splitRight.
  ///
  /// In en, this message translates to:
  /// **'Split right'**
  String get splitRight;

  /// No description provided for @closeOthers.
  ///
  /// In en, this message translates to:
  /// **'Close others'**
  String get closeOthers;

  /// No description provided for @closeAll.
  ///
  /// In en, this message translates to:
  /// **'Close all'**
  String get closeAll;

  /// No description provided for @sendToSidePanel.
  ///
  /// In en, this message translates to:
  /// **'Send to side panel'**
  String get sendToSidePanel;

  /// No description provided for @sendToBottomPanel.
  ///
  /// In en, this message translates to:
  /// **'Send to bottom panel'**
  String get sendToBottomPanel;

  /// No description provided for @floatInWindow.
  ///
  /// In en, this message translates to:
  /// **'Float in a window'**
  String get floatInWindow;

  /// No description provided for @dockToSidebar.
  ///
  /// In en, this message translates to:
  /// **'Dock to sidebar'**
  String get dockToSidebar;

  /// No description provided for @unknownTabType.
  ///
  /// In en, this message translates to:
  /// **'This version has nothing to show a \"{type}\" tab with.'**
  String unknownTabType(String type);

  /// No description provided for @terminalN.
  ///
  /// In en, this message translates to:
  /// **'Terminal {n}'**
  String terminalN(String n);

  /// No description provided for @browser.
  ///
  /// In en, this message translates to:
  /// **'Browser'**
  String get browser;

  /// No description provided for @browserBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get browserBack;

  /// No description provided for @browserForward.
  ///
  /// In en, this message translates to:
  /// **'Forward'**
  String get browserForward;

  /// No description provided for @browserGo.
  ///
  /// In en, this message translates to:
  /// **'Go'**
  String get browserGo;

  /// No description provided for @browserPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search or enter address'**
  String get browserPlaceholder;

  /// No description provided for @browserOpenExternal.
  ///
  /// In en, this message translates to:
  /// **'Open in default browser'**
  String get browserOpenExternal;

  /// No description provided for @browserInvalid.
  ///
  /// In en, this message translates to:
  /// **'That is not a valid address.'**
  String get browserInvalid;

  /// No description provided for @browserBlockedScheme.
  ///
  /// In en, this message translates to:
  /// **'Only http and https addresses can be opened.'**
  String get browserBlockedScheme;

  /// No description provided for @browserBlockedLoopback.
  ///
  /// In en, this message translates to:
  /// **'Local addresses are refused.'**
  String get browserBlockedLoopback;

  /// No description provided for @browserStart.
  ///
  /// In en, this message translates to:
  /// **'Enter an address above to start browsing.'**
  String get browserStart;

  /// No description provided for @browserUnsupported.
  ///
  /// In en, this message translates to:
  /// **'In-app browsing is not available on this platform.'**
  String get browserUnsupported;

  /// No description provided for @sidechat.
  ///
  /// In en, this message translates to:
  /// **'Side chat'**
  String get sidechat;

  /// No description provided for @sideChatNew.
  ///
  /// In en, this message translates to:
  /// **'New side chat'**
  String get sideChatNew;

  /// No description provided for @sideChatEmpty.
  ///
  /// In en, this message translates to:
  /// **'A lighter conversation beside the main one.'**
  String get sideChatEmpty;

  /// No description provided for @sideChatEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Quick asides that never touch the main thread.'**
  String get sideChatEmptyDesc;

  /// No description provided for @sideChatNoModel.
  ///
  /// In en, this message translates to:
  /// **'Connect a model in Settings to chat here.'**
  String get sideChatNoModel;

  /// No description provided for @sideChatPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Ask an aside…'**
  String get sideChatPlaceholder;

  /// No description provided for @sideChatThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get sideChatThinking;

  /// No description provided for @filesOpenHere.
  ///
  /// In en, this message translates to:
  /// **'Files open here.'**
  String get filesOpenHere;

  /// No description provided for @clickToOpenFiles.
  ///
  /// In en, this message translates to:
  /// **'Click to open files in this pane.'**
  String get clickToOpenFiles;

  /// No description provided for @openWorkbenchPanel.
  ///
  /// In en, this message translates to:
  /// **'Open workbench panel'**
  String get openWorkbenchPanel;

  /// No description provided for @collapseWorkbenchPanel.
  ///
  /// In en, this message translates to:
  /// **'Collapse workbench panel'**
  String get collapseWorkbenchPanel;

  /// No description provided for @openBottomPanel.
  ///
  /// In en, this message translates to:
  /// **'Open bottom panel'**
  String get openBottomPanel;

  /// No description provided for @collapseBottomPanel.
  ///
  /// In en, this message translates to:
  /// **'Collapse bottom panel'**
  String get collapseBottomPanel;

  /// No description provided for @openSidebar.
  ///
  /// In en, this message translates to:
  /// **'Open sidebar ({accel})'**
  String openSidebar(String accel);

  /// No description provided for @collapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar ({accel})'**
  String collapseSidebar(String accel);

  /// No description provided for @newSession.
  ///
  /// In en, this message translates to:
  /// **'New Session'**
  String get newSession;

  /// No description provided for @sessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get sessions;

  /// No description provided for @planMode.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get planMode;

  /// No description provided for @agentMode.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agentMode;

  /// No description provided for @noSessionsYet.
  ///
  /// In en, this message translates to:
  /// **'No sessions yet'**
  String get noSessionsYet;

  /// No description provided for @workspaces.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get workspaces;

  /// No description provided for @unassignedWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get unassignedWorkspace;

  /// No description provided for @historyView.
  ///
  /// In en, this message translates to:
  /// **'History view'**
  String get historyView;

  /// No description provided for @groupByWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Group by workspace'**
  String get groupByWorkspace;

  /// No description provided for @flatList.
  ///
  /// In en, this message translates to:
  /// **'Flat list'**
  String get flatList;

  /// No description provided for @workspaceActions.
  ///
  /// In en, this message translates to:
  /// **'Workspace actions'**
  String get workspaceActions;

  /// No description provided for @conversationActions.
  ///
  /// In en, this message translates to:
  /// **'Conversation actions'**
  String get conversationActions;

  /// No description provided for @newSessionHere.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get newSessionHere;

  /// No description provided for @showFileTree.
  ///
  /// In en, this message translates to:
  /// **'Show file tree'**
  String get showFileTree;

  /// No description provided for @removeWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get removeWorkspace;

  /// No description provided for @removeWorkspaceHint.
  ///
  /// In en, this message translates to:
  /// **'Keeps its conversations'**
  String get removeWorkspaceHint;

  /// No description provided for @renameSession.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameSession;

  /// No description provided for @pinSession.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get pinSession;

  /// No description provided for @unpinSession.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpinSession;

  /// No description provided for @deleteSession.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteSession;

  /// No description provided for @copySessionId.
  ///
  /// In en, this message translates to:
  /// **'Copy session id'**
  String get copySessionId;

  /// No description provided for @copyWorkspacePath.
  ///
  /// In en, this message translates to:
  /// **'Copy workspace path'**
  String get copyWorkspacePath;

  /// No description provided for @revealInFiles.
  ///
  /// In en, this message translates to:
  /// **'Reveal in file manager'**
  String get revealInFiles;

  /// No description provided for @revealInTree.
  ///
  /// In en, this message translates to:
  /// **'Expand in file tree'**
  String get revealInTree;

  /// No description provided for @pinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinned;

  /// No description provided for @renameSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename session'**
  String get renameSessionTitle;

  /// No description provided for @deleteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this session?'**
  String get deleteSessionTitle;

  /// No description provided for @deleteSessionBody.
  ///
  /// In en, this message translates to:
  /// **'The conversation stays on disk; it only leaves this list.'**
  String get deleteSessionBody;

  /// No description provided for @sessionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Session removed from the list'**
  String get sessionDeleted;

  /// No description provided for @revealFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open that location'**
  String get revealFailed;

  /// No description provided for @historyNotSaved.
  ///
  /// In en, this message translates to:
  /// **'The list changed, but that could not be saved'**
  String get historyNotSaved;

  /// No description provided for @addWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Add a folder'**
  String get addWorkspace;

  /// No description provided for @expandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand all'**
  String get expandAll;

  /// No description provided for @collapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse all'**
  String get collapseAll;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}m'**
  String minutesAgo(String n);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h'**
  String hoursAgo(String n);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d'**
  String daysAgo(String n);

  /// No description provided for @openDetailsPanel.
  ///
  /// In en, this message translates to:
  /// **'Open details panel'**
  String get openDetailsPanel;

  /// No description provided for @closeDetailsPanel.
  ///
  /// In en, this message translates to:
  /// **'Close details panel'**
  String get closeDetailsPanel;

  /// No description provided for @askAnything.
  ///
  /// In en, this message translates to:
  /// **'Ask anything'**
  String get askAnything;

  /// No description provided for @askAnythingHint.
  ///
  /// In en, this message translates to:
  /// **'Ask anything, or describe a task'**
  String get askAnythingHint;

  /// No description provided for @queueDraftHint.
  ///
  /// In en, this message translates to:
  /// **'Keep typing — this queues behind the current turn'**
  String get queueDraftHint;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask anything, or open a workspace to begin'**
  String get heroSubtitle;

  /// No description provided for @workspaceStatusBar.
  ///
  /// In en, this message translates to:
  /// **'Workspace status bar'**
  String get workspaceStatusBar;

  /// No description provided for @localRepo.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get localRepo;

  /// No description provided for @planNoWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Choose a workspace folder first — the plan vault is the workspace'**
  String get planNoWorkspace;

  /// No description provided for @planNoNoteSelected.
  ///
  /// In en, this message translates to:
  /// **'Pick a markdown file from the tree'**
  String get planNoNoteSelected;

  /// No description provided for @planNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get planNotes;

  /// No description provided for @seedDeliveryBoard.
  ///
  /// In en, this message translates to:
  /// **'Delivery board'**
  String get seedDeliveryBoard;

  /// No description provided for @seedReadingInbox.
  ///
  /// In en, this message translates to:
  /// **'Reading inbox'**
  String get seedReadingInbox;

  /// No description provided for @seedViewBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get seedViewBoard;

  /// No description provided for @seedViewAllTasks.
  ///
  /// In en, this message translates to:
  /// **'All tasks'**
  String get seedViewAllTasks;

  /// No description provided for @seedViewOpenOnly.
  ///
  /// In en, this message translates to:
  /// **'Open only'**
  String get seedViewOpenOnly;

  /// No description provided for @seedViewCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get seedViewCards;

  /// No description provided for @seedViewCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get seedViewCalendar;

  /// No description provided for @seedViewGraph.
  ///
  /// In en, this message translates to:
  /// **'Graph'**
  String get seedViewGraph;

  /// No description provided for @seedViewList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get seedViewList;

  /// No description provided for @seedViewTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get seedViewTable;

  /// No description provided for @seedRelStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get seedRelStatus;

  /// No description provided for @seedRelTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get seedRelTags;

  /// No description provided for @seedRelEffort.
  ///
  /// In en, this message translates to:
  /// **'Effort'**
  String get seedRelEffort;

  /// No description provided for @seedRelDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get seedRelDue;

  /// No description provided for @seedOptTodo.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get seedOptTodo;

  /// No description provided for @seedOptDoing.
  ///
  /// In en, this message translates to:
  /// **'Doing'**
  String get seedOptDoing;

  /// No description provided for @seedOptBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get seedOptBlocked;

  /// No description provided for @seedOptShipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get seedOptShipped;

  /// No description provided for @seedOptUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get seedOptUrgent;

  /// No description provided for @seedOptClient.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get seedOptClient;

  /// No description provided for @seedOptInternal.
  ///
  /// In en, this message translates to:
  /// **'Internal'**
  String get seedOptInternal;

  /// No description provided for @planNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No markdown files in this workspace'**
  String get planNoNotes;

  /// No description provided for @planPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get planPreview;

  /// No description provided for @planSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get planSource;

  /// No description provided for @planStuckChip.
  ///
  /// In en, this message translates to:
  /// **'Changes not written'**
  String get planStuckChip;

  /// No description provided for @planStuckTitle.
  ///
  /// In en, this message translates to:
  /// **'Unwritten changes'**
  String get planStuckTitle;

  /// No description provided for @planStuckDesc.
  ///
  /// In en, this message translates to:
  /// **'The file on disk did not receive these edits (it may have been changed externally). Leaving now discards them.'**
  String get planStuckDesc;

  /// No description provided for @planStuckConfirm.
  ///
  /// In en, this message translates to:
  /// **'Discard & leave'**
  String get planStuckConfirm;

  /// No description provided for @planExternalChanged.
  ///
  /// In en, this message translates to:
  /// **'The note changed on disk — autosave paused.'**
  String get planExternalChanged;

  /// No description provided for @planNoteVanished.
  ///
  /// In en, this message translates to:
  /// **'The note was removed on disk — closed.'**
  String get planNoteVanished;

  /// No description provided for @planSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Saving the note failed.'**
  String get planSaveFailed;

  /// No description provided for @planNewNote.
  ///
  /// In en, this message translates to:
  /// **'New Note'**
  String get planNewNote;

  /// No description provided for @planNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New Folder'**
  String get planNewFolder;

  /// No description provided for @planNewNoteHint.
  ///
  /// In en, this message translates to:
  /// **'File name (without .md)'**
  String get planNewNoteHint;

  /// No description provided for @planNewFolderHint.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get planNewFolderHint;

  /// No description provided for @planCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get planCreate;

  /// No description provided for @planCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get planCancel;

  /// No description provided for @planEditorEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get planEditorEdit;

  /// No description provided for @planEditorSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get planEditorSource;

  /// No description provided for @planEditorPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get planEditorPreview;

  /// No description provided for @planAddBlock.
  ///
  /// In en, this message translates to:
  /// **'Add block'**
  String get planAddBlock;

  /// No description provided for @planBlockMenu.
  ///
  /// In en, this message translates to:
  /// **'Block actions'**
  String get planBlockMenu;

  /// No description provided for @planBlockToc.
  ///
  /// In en, this message translates to:
  /// **'Table of contents'**
  String get planBlockToc;

  /// No description provided for @planBlockRelation.
  ///
  /// In en, this message translates to:
  /// **'Relation'**
  String get planBlockRelation;

  /// No description provided for @planBlockFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured relations'**
  String get planBlockFeatured;

  /// No description provided for @planBlockWidget.
  ///
  /// In en, this message translates to:
  /// **'Widget'**
  String get planBlockWidget;

  /// No description provided for @planBlockUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Unsupported block'**
  String get planBlockUnsupported;

  /// No description provided for @planFileUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get planFileUploading;

  /// No description provided for @planFileError.
  ///
  /// In en, this message translates to:
  /// **'File failed to load'**
  String get planFileError;

  /// No description provided for @planFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty file'**
  String get planFileEmpty;

  /// No description provided for @planBookmarkEmpty.
  ///
  /// In en, this message translates to:
  /// **'Empty bookmark'**
  String get planBookmarkEmpty;

  /// No description provided for @planBookmarkFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching…'**
  String get planBookmarkFetching;

  /// No description provided for @planBookmarkError.
  ///
  /// In en, this message translates to:
  /// **'Bookmark failed to load'**
  String get planBookmarkError;

  /// No description provided for @planBookmarkPrompt.
  ///
  /// In en, this message translates to:
  /// **'Bookmark URL'**
  String get planBookmarkPrompt;

  /// No description provided for @planBlockToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle section'**
  String get planBlockToggle;

  /// No description provided for @planCalloutIcon.
  ///
  /// In en, this message translates to:
  /// **'Callout icon'**
  String get planCalloutIcon;

  /// No description provided for @planEmbedOpen.
  ///
  /// In en, this message translates to:
  /// **'opens externally'**
  String get planEmbedOpen;

  /// No description provided for @planEmbedUnavailable.
  ///
  /// In en, this message translates to:
  /// **'not available here'**
  String get planEmbedUnavailable;

  /// No description provided for @planTableActions.
  ///
  /// In en, this message translates to:
  /// **'Row actions'**
  String get planTableActions;

  /// No description provided for @planColumnMenu.
  ///
  /// In en, this message translates to:
  /// **'Column actions'**
  String get planColumnMenu;

  /// No description provided for @planTableInsertAbove.
  ///
  /// In en, this message translates to:
  /// **'Insert row above'**
  String get planTableInsertAbove;

  /// No description provided for @planTableInsertBelow.
  ///
  /// In en, this message translates to:
  /// **'Insert row below'**
  String get planTableInsertBelow;

  /// No description provided for @planTableMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move row up'**
  String get planTableMoveUp;

  /// No description provided for @planTableMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move row down'**
  String get planTableMoveDown;

  /// No description provided for @planTableDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate row'**
  String get planTableDuplicate;

  /// No description provided for @planTableClear.
  ///
  /// In en, this message translates to:
  /// **'Clear row'**
  String get planTableClear;

  /// No description provided for @planTableDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete row'**
  String get planTableDelete;

  /// No description provided for @planTableInsertLeft.
  ///
  /// In en, this message translates to:
  /// **'Insert column left'**
  String get planTableInsertLeft;

  /// No description provided for @planTableInsertRight.
  ///
  /// In en, this message translates to:
  /// **'Insert column right'**
  String get planTableInsertRight;

  /// No description provided for @planTableDeleteColumn.
  ///
  /// In en, this message translates to:
  /// **'Delete column'**
  String get planTableDeleteColumn;

  /// No description provided for @planActionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get planActionCopy;

  /// No description provided for @planActionPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get planActionPaste;

  /// No description provided for @planActionDrag.
  ///
  /// In en, this message translates to:
  /// **'Drag to move'**
  String get planActionDrag;

  /// No description provided for @planLinkOpen.
  ///
  /// In en, this message translates to:
  /// **'Open link'**
  String get planLinkOpen;

  /// No description provided for @planLinkPrompt.
  ///
  /// In en, this message translates to:
  /// **'Link URL'**
  String get planLinkPrompt;

  /// No description provided for @planLinkRemoveHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to remove the link'**
  String get planLinkRemoveHint;

  /// No description provided for @planLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open that link'**
  String get planLinkFailed;

  /// No description provided for @planActionDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get planActionDuplicate;

  /// No description provided for @planActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get planActionDelete;

  /// No description provided for @planSearchInDoc.
  ///
  /// In en, this message translates to:
  /// **'Search in document'**
  String get planSearchInDoc;

  /// No description provided for @planSearchNext.
  ///
  /// In en, this message translates to:
  /// **'Next match'**
  String get planSearchNext;

  /// No description provided for @planSearchPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous match'**
  String get planSearchPrevious;

  /// No description provided for @planSearchCancel.
  ///
  /// In en, this message translates to:
  /// **'Stop searching'**
  String get planSearchCancel;

  /// No description provided for @planStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get planStyleLabel;

  /// No description provided for @planColourLabel.
  ///
  /// In en, this message translates to:
  /// **'Text colour'**
  String get planColourLabel;

  /// No description provided for @planColourBackground.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get planColourBackground;

  /// No description provided for @planAlignLabel.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get planAlignLabel;

  /// No description provided for @planSlashPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type to filter…'**
  String get planSlashPlaceholder;

  /// No description provided for @planEditorUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get planEditorUndo;

  /// No description provided for @planEditorRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get planEditorRedo;

  /// No description provided for @planAlignLeft.
  ///
  /// In en, this message translates to:
  /// **'Align left'**
  String get planAlignLeft;

  /// No description provided for @planAlignCenter.
  ///
  /// In en, this message translates to:
  /// **'Align centre'**
  String get planAlignCenter;

  /// No description provided for @planAlignRight.
  ///
  /// In en, this message translates to:
  /// **'Align right'**
  String get planAlignRight;

  /// No description provided for @planSlashText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get planSlashText;

  /// No description provided for @planSlashTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get planSlashTitle;

  /// No description provided for @planSlashHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get planSlashHeading;

  /// No description provided for @planSlashSubheading.
  ///
  /// In en, this message translates to:
  /// **'Subheading'**
  String get planSlashSubheading;

  /// No description provided for @planSlashHighlighted.
  ///
  /// In en, this message translates to:
  /// **'Highlighted'**
  String get planSlashHighlighted;

  /// No description provided for @planSlashCallout.
  ///
  /// In en, this message translates to:
  /// **'Callout'**
  String get planSlashCallout;

  /// No description provided for @planSlashCheckbox.
  ///
  /// In en, this message translates to:
  /// **'Checkbox'**
  String get planSlashCheckbox;

  /// No description provided for @planSlashBulleted.
  ///
  /// In en, this message translates to:
  /// **'Bulleted'**
  String get planSlashBulleted;

  /// No description provided for @planSlashNumbered.
  ///
  /// In en, this message translates to:
  /// **'Numbered'**
  String get planSlashNumbered;

  /// No description provided for @planSlashToggle.
  ///
  /// In en, this message translates to:
  /// **'Toggle'**
  String get planSlashToggle;

  /// No description provided for @planSlashFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get planSlashFile;

  /// No description provided for @planSlashPicture.
  ///
  /// In en, this message translates to:
  /// **'Picture'**
  String get planSlashPicture;

  /// No description provided for @planSlashVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get planSlashVideo;

  /// No description provided for @planSlashBookmark.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get planSlashBookmark;

  /// No description provided for @planSlashCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get planSlashCode;

  /// No description provided for @planSlashLine.
  ///
  /// In en, this message translates to:
  /// **'Divider line'**
  String get planSlashLine;

  /// No description provided for @planSlashDots.
  ///
  /// In en, this message translates to:
  /// **'Three dots'**
  String get planSlashDots;

  /// No description provided for @planSlashToc.
  ///
  /// In en, this message translates to:
  /// **'Table of contents'**
  String get planSlashToc;

  /// No description provided for @planSlashTable.
  ///
  /// In en, this message translates to:
  /// **'Simple table'**
  String get planSlashTable;

  /// No description provided for @planAllContentTitle.
  ///
  /// In en, this message translates to:
  /// **'All content'**
  String get planAllContentTitle;

  /// No description provided for @planTabPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get planTabPages;

  /// No description provided for @planTabLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get planTabLists;

  /// No description provided for @planTabMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get planTabMedia;

  /// No description provided for @planTabBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get planTabBookmarks;

  /// No description provided for @planTabFiles.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get planTabFiles;

  /// No description provided for @planModeAllContent.
  ///
  /// In en, this message translates to:
  /// **'All content'**
  String get planModeAllContent;

  /// No description provided for @planModeUnlinked.
  ///
  /// In en, this message translates to:
  /// **'Unlinked'**
  String get planModeUnlinked;

  /// No description provided for @planGroupToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get planGroupToday;

  /// No description provided for @planGroupYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get planGroupYesterday;

  /// No description provided for @planGroupPrevious7Days.
  ///
  /// In en, this message translates to:
  /// **'Previous 7 days'**
  String get planGroupPrevious7Days;

  /// No description provided for @planGroupPrevious14Days.
  ///
  /// In en, this message translates to:
  /// **'Previous 14 days'**
  String get planGroupPrevious14Days;

  /// No description provided for @planGroupMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get planGroupMonth;

  /// No description provided for @planGroupMonthAndYear.
  ///
  /// In en, this message translates to:
  /// **'Earlier this year'**
  String get planGroupMonthAndYear;

  /// No description provided for @planGroupOlder.
  ///
  /// In en, this message translates to:
  /// **'Older'**
  String get planGroupOlder;

  /// No description provided for @planSortCreated.
  ///
  /// In en, this message translates to:
  /// **'Date created'**
  String get planSortCreated;

  /// No description provided for @planSortModified.
  ///
  /// In en, this message translates to:
  /// **'Date modified'**
  String get planSortModified;

  /// No description provided for @planSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get planSortName;

  /// No description provided for @planSortLastUsed.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get planSortLastUsed;

  /// No description provided for @planAllContentEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get planAllContentEmpty;

  /// No description provided for @planSegmentFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get planSegmentFeatured;

  /// No description provided for @planSegmentLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get planSegmentLocal;

  /// No description provided for @planSegmentHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden'**
  String get planSegmentHidden;

  /// No description provided for @planFeature.
  ///
  /// In en, this message translates to:
  /// **'Add to featured'**
  String get planFeature;

  /// No description provided for @planUnfeature.
  ///
  /// In en, this message translates to:
  /// **'Remove from featured'**
  String get planUnfeature;

  /// No description provided for @planHide.
  ///
  /// In en, this message translates to:
  /// **'Hide relation'**
  String get planHide;

  /// No description provided for @planUnhide.
  ///
  /// In en, this message translates to:
  /// **'Unhide relation'**
  String get planUnhide;

  /// No description provided for @planRemoveRelation.
  ///
  /// In en, this message translates to:
  /// **'Remove from object'**
  String get planRemoveRelation;

  /// No description provided for @planRelationRemoved.
  ///
  /// In en, this message translates to:
  /// **'Relation removed'**
  String get planRelationRemoved;

  /// No description provided for @planRelationActions.
  ///
  /// In en, this message translates to:
  /// **'Relation actions'**
  String get planRelationActions;

  /// No description provided for @planAddRelation.
  ///
  /// In en, this message translates to:
  /// **'Add a relation'**
  String get planAddRelation;

  /// No description provided for @planNewCollection.
  ///
  /// In en, this message translates to:
  /// **'New set or collection'**
  String get planNewCollection;

  /// No description provided for @planKindCollection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get planKindCollection;

  /// No description provided for @planKindSet.
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get planKindSet;

  /// No description provided for @planKindSetSource.
  ///
  /// In en, this message translates to:
  /// **'Source type (records arrive as you create them)'**
  String get planKindSetSource;

  /// No description provided for @planCollectionCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get planCollectionCreated;

  /// No description provided for @planTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Templates · {name}'**
  String planTemplatesTitle(String name);

  /// No description provided for @planTemplatesNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'This type does not take templates'**
  String get planTemplatesNotAllowed;

  /// No description provided for @planTemplatesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No templates yet — new records start blank'**
  String get planTemplatesEmpty;

  /// No description provided for @planTemplateNew.
  ///
  /// In en, this message translates to:
  /// **'New template'**
  String get planTemplateNew;

  /// No description provided for @planTemplateNewName.
  ///
  /// In en, this message translates to:
  /// **'Untitled template'**
  String get planTemplateNewName;

  /// No description provided for @planTemplateSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get planTemplateSetDefault;

  /// No description provided for @planTemplateDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get planTemplateDuplicate;

  /// No description provided for @planTemplateDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get planTemplateDelete;

  /// No description provided for @planTemplateDeleted.
  ///
  /// In en, this message translates to:
  /// **'Template deleted'**
  String get planTemplateDeleted;

  /// No description provided for @planTemplateDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get planTemplateDefault;

  /// No description provided for @planDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get planDateToday;

  /// No description provided for @planDateYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get planDateYesterday;

  /// No description provided for @planDateTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get planDateTomorrow;

  /// No description provided for @planDateNoObjects.
  ///
  /// In en, this message translates to:
  /// **'No objects on this day'**
  String get planDateNoObjects;

  /// No description provided for @planGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get planGalleryTitle;

  /// No description provided for @planGalleryInstall.
  ///
  /// In en, this message translates to:
  /// **'Install'**
  String get planGalleryInstall;

  /// No description provided for @planGalleryInstalling.
  ///
  /// In en, this message translates to:
  /// **'Installing…'**
  String get planGalleryInstalling;

  /// No description provided for @planGalleryDone.
  ///
  /// In en, this message translates to:
  /// **'Installed as {name}'**
  String planGalleryDone(String name);

  /// No description provided for @planGalleryInstalled.
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get planGalleryInstalled;

  /// No description provided for @planGalleryUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this pack fits this workspace'**
  String get planGalleryUnsupported;

  /// No description provided for @planSectionPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get planSectionPinned;

  /// No description provided for @planSectionFavorites.
  ///
  /// In en, this message translates to:
  /// **'My favourites'**
  String get planSectionFavorites;

  /// No description provided for @planSectionRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently edited'**
  String get planSectionRecent;

  /// No description provided for @planSectionTypes.
  ///
  /// In en, this message translates to:
  /// **'Object types'**
  String get planSectionTypes;

  /// No description provided for @planWidgetMenu.
  ///
  /// In en, this message translates to:
  /// **'Widget actions'**
  String get planWidgetMenu;

  /// No description provided for @planWidgetEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get planWidgetEmpty;

  /// No description provided for @planWidgetFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get planWidgetFavorites;

  /// No description provided for @planWidgetRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently edited'**
  String get planWidgetRecent;

  /// No description provided for @planWidgetBin.
  ///
  /// In en, this message translates to:
  /// **'Bin'**
  String get planWidgetBin;

  /// No description provided for @planWidgetAllObjects.
  ///
  /// In en, this message translates to:
  /// **'All objects'**
  String get planWidgetAllObjects;

  /// No description provided for @planWidgetTypes.
  ///
  /// In en, this message translates to:
  /// **'Object types'**
  String get planWidgetTypes;

  /// No description provided for @planWidgetChangeType.
  ///
  /// In en, this message translates to:
  /// **'Change widget type'**
  String get planWidgetChangeType;

  /// No description provided for @planWidgetRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove widget'**
  String get planWidgetRemove;

  /// No description provided for @planWidgetRemoved.
  ///
  /// In en, this message translates to:
  /// **'Widget removed'**
  String get planWidgetRemoved;

  /// No description provided for @planWidgetEmptyBin.
  ///
  /// In en, this message translates to:
  /// **'Empty bin'**
  String get planWidgetEmptyBin;

  /// No description provided for @planWidgetBinEmptied.
  ///
  /// In en, this message translates to:
  /// **'Bin emptied'**
  String get planWidgetBinEmptied;

  /// No description provided for @planWidgetChangeHome.
  ///
  /// In en, this message translates to:
  /// **'Change home'**
  String get planWidgetChangeHome;

  /// No description provided for @planWidgetCreateObject.
  ///
  /// In en, this message translates to:
  /// **'Create object of type'**
  String get planWidgetCreateObject;

  /// No description provided for @planSlashStyle.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get planSlashStyle;

  /// No description provided for @planSlashMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get planSlashMedia;

  /// No description provided for @planSlashOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get planSlashOther;

  /// No description provided for @planSlashObjects.
  ///
  /// In en, this message translates to:
  /// **'Objects'**
  String get planSlashObjects;

  /// No description provided for @planSlashObjectsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Objects arrive with the object library (P6)'**
  String get planSlashObjectsEmpty;

  /// No description provided for @planSlashProperties.
  ///
  /// In en, this message translates to:
  /// **'Properties'**
  String get planSlashProperties;

  /// No description provided for @planSlashPropertiesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Properties arrive with the object library (P6)'**
  String get planSlashPropertiesEmpty;

  /// No description provided for @planSlashActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get planSlashActions;

  /// No description provided for @planSlashInsertBelow.
  ///
  /// In en, this message translates to:
  /// **'Insert below'**
  String get planSlashInsertBelow;

  /// No description provided for @planOpenCollection.
  ///
  /// In en, this message translates to:
  /// **'Open a collection'**
  String get planOpenCollection;

  /// No description provided for @planFileNameExists.
  ///
  /// In en, this message translates to:
  /// **'A file with this name already exists'**
  String get planFileNameExists;

  /// No description provided for @planFolderNameExists.
  ///
  /// In en, this message translates to:
  /// **'A folder with this name already exists'**
  String get planFolderNameExists;

  /// No description provided for @planSwitchWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Switch workspace'**
  String get planSwitchWorkspace;

  /// No description provided for @planExtensions.
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get planExtensions;

  /// No description provided for @planBoard.
  ///
  /// In en, this message translates to:
  /// **'Board'**
  String get planBoard;

  /// No description provided for @planCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get planCalendar;

  /// No description provided for @planTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get planTable;

  /// No description provided for @planAddTask.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get planAddTask;

  /// No description provided for @planTaskTitleHint.
  ///
  /// In en, this message translates to:
  /// **'New task title'**
  String get planTaskTitleHint;

  /// No description provided for @planTaskDateHint.
  ///
  /// In en, this message translates to:
  /// **'yyyy-mm-dd'**
  String get planTaskDateHint;

  /// No description provided for @planGroupTodo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get planGroupTodo;

  /// No description provided for @planGroupInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get planGroupInProgress;

  /// No description provided for @planGroupReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get planGroupReview;

  /// No description provided for @planGroupDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get planGroupDone;

  /// No description provided for @planColumnStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get planColumnStatus;

  /// No description provided for @planColumnTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get planColumnTask;

  /// No description provided for @planColumnDue.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get planColumnDue;

  /// No description provided for @planNoDue.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get planNoDue;

  /// No description provided for @chooseWorkspaceFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a workspace folder'**
  String get chooseWorkspaceFolder;

  /// No description provided for @chooseAFolder.
  ///
  /// In en, this message translates to:
  /// **'Choose a folder…'**
  String get chooseAFolder;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @deepDiving.
  ///
  /// In en, this message translates to:
  /// **'Deep diving...'**
  String get deepDiving;

  /// No description provided for @inputQueue.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get inputQueue;

  /// No description provided for @queueInput.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queueInput;

  /// No description provided for @guideNow.
  ///
  /// In en, this message translates to:
  /// **'Steer'**
  String get guideNow;

  /// No description provided for @deliveryQueue.
  ///
  /// In en, this message translates to:
  /// **'After this turn'**
  String get deliveryQueue;

  /// No description provided for @deliveryGuide.
  ///
  /// In en, this message translates to:
  /// **'Steer this turn'**
  String get deliveryGuide;

  /// No description provided for @dragToReorder.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder'**
  String get dragToReorder;

  /// No description provided for @rewindPill.
  ///
  /// In en, this message translates to:
  /// **'Undo this write'**
  String get rewindPill;

  /// No description provided for @rewindTitle.
  ///
  /// In en, this message translates to:
  /// **'Go back to before this write?'**
  String get rewindTitle;

  /// No description provided for @rewindConfirm.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get rewindConfirm;

  /// No description provided for @rewindNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing left to undo.'**
  String get rewindNothing;

  /// No description provided for @rewindRestores.
  ///
  /// In en, this message translates to:
  /// **'Restores'**
  String get rewindRestores;

  /// No description provided for @rewindDeletes.
  ///
  /// In en, this message translates to:
  /// **'Deletes'**
  String get rewindDeletes;

  /// No description provided for @rewindSkips.
  ///
  /// In en, this message translates to:
  /// **'Leaves alone'**
  String get rewindSkips;

  /// No description provided for @rewindWhyChanged.
  ///
  /// In en, this message translates to:
  /// **'edited outside the agent'**
  String get rewindWhyChanged;

  /// No description provided for @rewindWhyNoImage.
  ///
  /// In en, this message translates to:
  /// **'no before-image was stored'**
  String get rewindWhyNoImage;

  /// No description provided for @attachImage.
  ///
  /// In en, this message translates to:
  /// **'Attach images'**
  String get attachImage;

  /// No description provided for @attach.
  ///
  /// In en, this message translates to:
  /// **'Attach'**
  String get attach;

  /// No description provided for @chooseImages.
  ///
  /// In en, this message translates to:
  /// **'Choose image files…'**
  String get chooseImages;

  /// No description provided for @chooseDocuments.
  ///
  /// In en, this message translates to:
  /// **'Attach documents (PDF, text)…'**
  String get chooseDocuments;

  /// No description provided for @pasteImage.
  ///
  /// In en, this message translates to:
  /// **'Paste image from clipboard'**
  String get pasteImage;

  /// No description provided for @pasteImageFailed.
  ///
  /// In en, this message translates to:
  /// **'The clipboard has no image.'**
  String get pasteImageFailed;

  /// No description provided for @imagesUnsupportedByModel.
  ///
  /// In en, this message translates to:
  /// **'\"{model}\" does not accept images. Attach it as a document instead, or pick a vision model in the model menu.'**
  String imagesUnsupportedByModel(String model);

  /// No description provided for @removeAttachment.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeAttachment;

  /// No description provided for @dropFilesHint.
  ///
  /// In en, this message translates to:
  /// **'Drop images to attach'**
  String get dropFilesHint;

  /// No description provided for @askEveryTime.
  ///
  /// In en, this message translates to:
  /// **'Ask every time'**
  String get askEveryTime;

  /// No description provided for @askEveryTimeDesc.
  ///
  /// In en, this message translates to:
  /// **'The agent interrupts for approval before it writes or runs anything.'**
  String get askEveryTimeDesc;

  /// No description provided for @planFirst.
  ///
  /// In en, this message translates to:
  /// **'Plan first'**
  String get planFirst;

  /// No description provided for @planFirstDesc.
  ///
  /// In en, this message translates to:
  /// **'Read-only until a plan is approved; the agent may not change anything.'**
  String get planFirstDesc;

  /// No description provided for @autoRun.
  ///
  /// In en, this message translates to:
  /// **'Auto-run'**
  String get autoRun;

  /// No description provided for @autoRunDesc.
  ///
  /// In en, this message translates to:
  /// **'Gated tools run without asking. Use when you trust the turn.'**
  String get autoRunDesc;

  /// No description provided for @approvalMode.
  ///
  /// In en, this message translates to:
  /// **'Approval mode'**
  String get approvalMode;

  /// No description provided for @commandHint.
  ///
  /// In en, this message translates to:
  /// **'Type / for commands'**
  String get commandHint;

  /// No description provided for @commands.
  ///
  /// In en, this message translates to:
  /// **'Commands'**
  String get commands;

  /// No description provided for @files.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get files;

  /// No description provided for @searchingFiles.
  ///
  /// In en, this message translates to:
  /// **'Searching the workspace…'**
  String get searchingFiles;

  /// No description provided for @commandNewSession.
  ///
  /// In en, this message translates to:
  /// **'Start a new session'**
  String get commandNewSession;

  /// No description provided for @quickPhrases.
  ///
  /// In en, this message translates to:
  /// **'Quick phrases'**
  String get quickPhrases;

  /// No description provided for @messageCopyText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get messageCopyText;

  /// No description provided for @messageExportMd.
  ///
  /// In en, this message translates to:
  /// **'Export as Markdown'**
  String get messageExportMd;

  /// No description provided for @messageExportTxt.
  ///
  /// In en, this message translates to:
  /// **'Export as plain text'**
  String get messageExportTxt;

  /// No description provided for @commandCopyTranscript.
  ///
  /// In en, this message translates to:
  /// **'Copy the whole conversation'**
  String get commandCopyTranscript;

  /// No description provided for @commandCopyTranscriptDesc.
  ///
  /// In en, this message translates to:
  /// **'Every user and assistant message, in order, onto the clipboard'**
  String get commandCopyTranscriptDesc;

  /// No description provided for @preRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-restore snapshots'**
  String get preRestoreTitle;

  /// No description provided for @preRestoreDesc.
  ///
  /// In en, this message translates to:
  /// **'Each restore first copies the files it will overwrite here. The newest 3 are kept.'**
  String get preRestoreDesc;

  /// No description provided for @settingsCards.
  ///
  /// In en, this message translates to:
  /// **'Instruction cards'**
  String get settingsCards;

  /// No description provided for @settingsCardsIntro.
  ///
  /// In en, this message translates to:
  /// **'Prompt cards you write once and enable per preference; enabled cards are injected with the workspace instructions.'**
  String get settingsCardsIntro;

  /// No description provided for @cardAdd.
  ///
  /// In en, this message translates to:
  /// **'Add card'**
  String get cardAdd;

  /// No description provided for @cardDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete card'**
  String get cardDelete;

  /// No description provided for @cardTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Card title'**
  String get cardTitleHint;

  /// No description provided for @cardTextHint.
  ///
  /// In en, this message translates to:
  /// **'The prompt text to inject'**
  String get cardTextHint;

  /// No description provided for @cardsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No cards yet.'**
  String get cardsEmpty;

  /// No description provided for @settingsTasks.
  ///
  /// In en, this message translates to:
  /// **'Scheduled tasks'**
  String get settingsTasks;

  /// No description provided for @settingsTasksIntro.
  ///
  /// In en, this message translates to:
  /// **'Prompts that run on a schedule while the app is open. A task that needs an answer fails and waits for its next minute.'**
  String get settingsTasksIntro;

  /// No description provided for @taskAdd.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get taskAdd;

  /// No description provided for @taskDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete task'**
  String get taskDelete;

  /// No description provided for @taskNameHint.
  ///
  /// In en, this message translates to:
  /// **'Task name'**
  String get taskNameHint;

  /// No description provided for @taskPromptHint.
  ///
  /// In en, this message translates to:
  /// **'The prompt to run'**
  String get taskPromptHint;

  /// No description provided for @taskHourHint.
  ///
  /// In en, this message translates to:
  /// **'Hour'**
  String get taskHourHint;

  /// No description provided for @taskMinuteHint.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get taskMinuteHint;

  /// No description provided for @taskWeekday.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String taskWeekday(String n);

  /// No description provided for @tasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet.'**
  String get tasksEmpty;

  /// No description provided for @settingsEnvironment.
  ///
  /// In en, this message translates to:
  /// **'Environment variables'**
  String get settingsEnvironment;

  /// No description provided for @settingsEnvironmentIntro.
  ///
  /// In en, this message translates to:
  /// **'Injected into shell commands; reference them as \$NAME. Values live in the keychain and are redacted from command output shown to the model.'**
  String get settingsEnvironmentIntro;

  /// No description provided for @envAdd.
  ///
  /// In en, this message translates to:
  /// **'Add variable'**
  String get envAdd;

  /// No description provided for @envDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete variable'**
  String get envDelete;

  /// No description provided for @envNameHint.
  ///
  /// In en, this message translates to:
  /// **'NAME (letters, digits, underscore)'**
  String get envNameHint;

  /// No description provided for @envValueHint.
  ///
  /// In en, this message translates to:
  /// **'Value — stored in the keychain'**
  String get envValueHint;

  /// No description provided for @settingsPhrases.
  ///
  /// In en, this message translates to:
  /// **'Quick phrases'**
  String get settingsPhrases;

  /// No description provided for @settingsPhrasesIntro.
  ///
  /// In en, this message translates to:
  /// **'Reusable snippets the composer inserts at the cursor. Up to 20.'**
  String get settingsPhrasesIntro;

  /// No description provided for @quickPhraseAdd.
  ///
  /// In en, this message translates to:
  /// **'Add phrase'**
  String get quickPhraseAdd;

  /// No description provided for @quickPhraseDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete phrase'**
  String get quickPhraseDelete;

  /// No description provided for @quickPhraseFull.
  ///
  /// In en, this message translates to:
  /// **'The list is full — remove one to add another.'**
  String get quickPhraseFull;

  /// No description provided for @quickPhraseTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Menu title'**
  String get quickPhraseTitleHint;

  /// No description provided for @quickPhraseTextHint.
  ///
  /// In en, this message translates to:
  /// **'The text to insert'**
  String get quickPhraseTextHint;

  /// No description provided for @commandCompress.
  ///
  /// In en, this message translates to:
  /// **'Compress this conversation'**
  String get commandCompress;

  /// No description provided for @commandCompressDesc.
  ///
  /// In en, this message translates to:
  /// **'Summarize it and continue in a fresh session that remembers the summary'**
  String get commandCompressDesc;

  /// No description provided for @compressStarted.
  ///
  /// In en, this message translates to:
  /// **'Compressing…'**
  String get compressStarted;

  /// No description provided for @compressDone.
  ///
  /// In en, this message translates to:
  /// **'Compressed. The summary rides your next message.'**
  String get compressDone;

  /// No description provided for @compressFailed.
  ///
  /// In en, this message translates to:
  /// **'Compression failed. The conversation is unchanged.'**
  String get compressFailed;

  /// No description provided for @commandNewSessionDesc.
  ///
  /// In en, this message translates to:
  /// **'Leave this conversation on disk and start a fresh one.'**
  String get commandNewSessionDesc;

  /// No description provided for @commandAskMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to ask mode'**
  String get commandAskMode;

  /// No description provided for @commandAskModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Every gated call interrupts for approval.'**
  String get commandAskModeDesc;

  /// No description provided for @commandPlanMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to plan mode'**
  String get commandPlanMode;

  /// No description provided for @commandPlanModeDesc.
  ///
  /// In en, this message translates to:
  /// **'The workspace is read-only until the plan is approved.'**
  String get commandPlanModeDesc;

  /// No description provided for @commandAutoMode.
  ///
  /// In en, this message translates to:
  /// **'Switch to auto mode'**
  String get commandAutoMode;

  /// No description provided for @commandAutoModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Gated tools run without prompting.'**
  String get commandAutoModeDesc;

  /// No description provided for @waitingForApproval.
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval'**
  String get waitingForApproval;

  /// No description provided for @approvalTitle.
  ///
  /// In en, this message translates to:
  /// **'Tool {name} requests privileged execution'**
  String approvalTitle(String name);

  /// No description provided for @askUserStrip.
  ///
  /// In en, this message translates to:
  /// **'The agent needs your input'**
  String get askUserStrip;

  /// No description provided for @askUserOther.
  ///
  /// In en, this message translates to:
  /// **'Other — type it instead'**
  String get askUserOther;

  /// No description provided for @askUserSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get askUserSkip;

  /// No description provided for @askUserSkipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get askUserSkipped;

  /// No description provided for @askUserOpenHint.
  ///
  /// In en, this message translates to:
  /// **'Type your answer'**
  String get askUserOpenHint;

  /// No description provided for @askUserSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit answer'**
  String get askUserSubmit;

  /// No description provided for @reject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reject;

  /// No description provided for @allowOnce.
  ///
  /// In en, this message translates to:
  /// **'Allow once'**
  String get allowOnce;

  /// No description provided for @alwaysAllow.
  ///
  /// In en, this message translates to:
  /// **'Always allow'**
  String get alwaysAllow;

  /// No description provided for @approvalsTitle.
  ///
  /// In en, this message translates to:
  /// **'Approval rules'**
  String get approvalsTitle;

  /// No description provided for @approvalsNote.
  ///
  /// In en, this message translates to:
  /// **'Commands and paths you allowed once, so the agent stops asking about them. They apply to this folder only.'**
  String get approvalsNote;

  /// No description provided for @approvalsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved approvals for this folder.'**
  String get approvalsEmpty;

  /// No description provided for @approvalAllowed.
  ///
  /// In en, this message translates to:
  /// **'The agent may do this without asking'**
  String get approvalAllowed;

  /// No description provided for @approvalDenied.
  ///
  /// In en, this message translates to:
  /// **'Never ask — and never let it through'**
  String get approvalDenied;

  /// No description provided for @forgetWorkspaceApprovals.
  ///
  /// In en, this message translates to:
  /// **'Remove all for this folder'**
  String get forgetWorkspaceApprovals;

  /// No description provided for @oneReplacement.
  ///
  /// In en, this message translates to:
  /// **'1 replacement'**
  String get oneReplacement;

  /// No description provided for @nReplacements.
  ///
  /// In en, this message translates to:
  /// **'{n} replacements'**
  String nReplacements(String n);

  /// No description provided for @overwritesExistingFile.
  ///
  /// In en, this message translates to:
  /// **'overwrites an existing file'**
  String get overwritesExistingFile;

  /// No description provided for @inWorkdir.
  ///
  /// In en, this message translates to:
  /// **'in {dir}'**
  String inWorkdir(String dir);

  /// No description provided for @planReviewHeader.
  ///
  /// In en, this message translates to:
  /// **'Plan review'**
  String get planReviewHeader;

  /// No description provided for @planDiscuss.
  ///
  /// In en, this message translates to:
  /// **'Discuss'**
  String get planDiscuss;

  /// No description provided for @planDecline.
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get planDecline;

  /// No description provided for @planApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get planApprove;

  /// No description provided for @planApprovedMessage.
  ///
  /// In en, this message translates to:
  /// **'The plan is approved. Proceed with it.'**
  String get planApprovedMessage;

  /// No description provided for @planDeclinedMessage.
  ///
  /// In en, this message translates to:
  /// **'The plan is declined. Revise it.'**
  String get planDeclinedMessage;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @closeDetails.
  ///
  /// In en, this message translates to:
  /// **'Close details'**
  String get closeDetails;

  /// No description provided for @detailsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Click a tool row in the message flow to view its details'**
  String get detailsEmpty;

  /// No description provided for @detailsNotInWindow.
  ///
  /// In en, this message translates to:
  /// **'This call is outside the current window'**
  String get detailsNotInWindow;

  /// No description provided for @input.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get input;

  /// No description provided for @output.
  ///
  /// In en, this message translates to:
  /// **'Output'**
  String get output;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get running;

  /// No description provided for @toolRunning.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get toolRunning;

  /// No description provided for @toolDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get toolDone;

  /// No description provided for @toolFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get toolFailed;

  /// No description provided for @declined.
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get declined;

  /// No description provided for @tabHasNoFile.
  ///
  /// In en, this message translates to:
  /// **'This tab has no file.'**
  String get tabHasNoFile;

  /// No description provided for @noWorkspaceNoFile.
  ///
  /// In en, this message translates to:
  /// **'No workspace folder is set, so no file can be read.'**
  String get noWorkspaceNoFile;

  /// No description provided for @fileNoLongerExists.
  ///
  /// In en, this message translates to:
  /// **'This file no longer exists.'**
  String get fileNoLongerExists;

  /// No description provided for @looksLikeBinary.
  ///
  /// In en, this message translates to:
  /// **'This looks like a binary file. Nothing here can show it.'**
  String get looksLikeBinary;

  /// No description provided for @readOnlyTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Read-only: this file is larger than {mb} MB.'**
  String readOnlyTooLarge(String mb);

  /// No description provided for @couldNotSave.
  ///
  /// In en, this message translates to:
  /// **'Could not save: {message}'**
  String couldNotSave(String message);

  /// No description provided for @unsaved.
  ///
  /// In en, this message translates to:
  /// **'unsaved'**
  String get unsaved;

  /// No description provided for @noWorkspaceNothingToList.
  ///
  /// In en, this message translates to:
  /// **'No workspace folder is set, so there is nothing to list.'**
  String get noWorkspaceNothingToList;

  /// No description provided for @folderEmpty.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty.'**
  String get folderEmpty;

  /// No description provided for @searchFiles.
  ///
  /// In en, this message translates to:
  /// **'Search files'**
  String get searchFiles;

  /// No description provided for @open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// No description provided for @openInTreeTab.
  ///
  /// In en, this message translates to:
  /// **'Open in a file tree tab'**
  String get openInTreeTab;

  /// No description provided for @noMatches.
  ///
  /// In en, this message translates to:
  /// **'No files match \"{query}\".'**
  String noMatches(String query);

  /// No description provided for @couldNotStartShell.
  ///
  /// In en, this message translates to:
  /// **'Could not start the shell: {message}'**
  String couldNotStartShell(String message);

  /// No description provided for @shellExited.
  ///
  /// In en, this message translates to:
  /// **'The shell exited.'**
  String get shellExited;

  /// No description provided for @shellExitedCode.
  ///
  /// In en, this message translates to:
  /// **'The shell exited ({code}).'**
  String shellExitedCode(String code);

  /// No description provided for @gitNotARepo.
  ///
  /// In en, this message translates to:
  /// **'This directory is not a git repository'**
  String get gitNotARepo;

  /// No description provided for @gitTooManyChanges.
  ///
  /// In en, this message translates to:
  /// **'Too many changes; showing the first 2,000 entries'**
  String get gitTooManyChanges;

  /// No description provided for @stagedCount.
  ///
  /// In en, this message translates to:
  /// **'Staged ({n})'**
  String stagedCount(String n);

  /// No description provided for @unstagedCount.
  ///
  /// In en, this message translates to:
  /// **'Unstaged ({n})'**
  String unstagedCount(String n);

  /// No description provided for @stage.
  ///
  /// In en, this message translates to:
  /// **'Stage'**
  String get stage;

  /// No description provided for @unstage.
  ///
  /// In en, this message translates to:
  /// **'Unstage'**
  String get unstage;

  /// No description provided for @stageAll.
  ///
  /// In en, this message translates to:
  /// **'Stage all'**
  String get stageAll;

  /// No description provided for @unstageAll.
  ///
  /// In en, this message translates to:
  /// **'Unstage all'**
  String get unstageAll;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @noChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes'**
  String get noChanges;

  /// No description provided for @commitPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Commit message (Ctrl+Enter)'**
  String get commitPlaceholder;

  /// No description provided for @commit.
  ///
  /// In en, this message translates to:
  /// **'Commit'**
  String get commit;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @historyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load more history: {message}'**
  String historyLoadError(String message);

  /// No description provided for @branchSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Branch switch failed'**
  String get branchSwitchFailed;

  /// No description provided for @openEditor.
  ///
  /// In en, this message translates to:
  /// **'Open editor'**
  String get openEditor;

  /// No description provided for @discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard changes'**
  String get discardChanges;

  /// No description provided for @discardDesc.
  ///
  /// In en, this message translates to:
  /// **'This discards the worktree changes of \"{path}\" (not recoverable).'**
  String discardDesc(String path);

  /// No description provided for @copyRelative.
  ///
  /// In en, this message translates to:
  /// **'Copy relative path'**
  String get copyRelative;

  /// No description provided for @copyAbsolute.
  ///
  /// In en, this message translates to:
  /// **'Copy absolute path'**
  String get copyAbsolute;

  /// No description provided for @wrapLines.
  ///
  /// In en, this message translates to:
  /// **'Wrap long lines'**
  String get wrapLines;

  /// No description provided for @showOnlyChanged.
  ///
  /// In en, this message translates to:
  /// **'Changed files only'**
  String get showOnlyChanged;

  /// No description provided for @nothingChanged.
  ///
  /// In en, this message translates to:
  /// **'Nothing is changed in this folder'**
  String get nothingChanged;

  /// No description provided for @viewCommitDiff.
  ///
  /// In en, this message translates to:
  /// **'View commit diff'**
  String get viewCommitDiff;

  /// No description provided for @copyShortHash.
  ///
  /// In en, this message translates to:
  /// **'Copy short hash'**
  String get copyShortHash;

  /// No description provided for @copyFullHash.
  ///
  /// In en, this message translates to:
  /// **'Copy full hash'**
  String get copyFullHash;

  /// No description provided for @copySubject.
  ///
  /// In en, this message translates to:
  /// **'Copy subject'**
  String get copySubject;

  /// No description provided for @revertCommit.
  ///
  /// In en, this message translates to:
  /// **'Revert commit'**
  String get revertCommit;

  /// No description provided for @revertDesc.
  ///
  /// In en, this message translates to:
  /// **'Create a new commit on the current branch that reverts \"{subject}\".'**
  String revertDesc(String subject);

  /// No description provided for @cherryPickCommit.
  ///
  /// In en, this message translates to:
  /// **'Cherry-pick commit'**
  String get cherryPickCommit;

  /// No description provided for @cherryPickDesc.
  ///
  /// In en, this message translates to:
  /// **'Apply the changes of \"{subject}\" to the current branch.'**
  String cherryPickDesc(String subject);

  /// No description provided for @diffBinary.
  ///
  /// In en, this message translates to:
  /// **'Binary'**
  String get diffBinary;

  /// No description provided for @diffAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get diffAdded;

  /// No description provided for @diffDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get diffDeleted;

  /// No description provided for @diffRenamed.
  ///
  /// In en, this message translates to:
  /// **'Renamed'**
  String get diffRenamed;

  /// No description provided for @subagentMainAgent.
  ///
  /// In en, this message translates to:
  /// **'Main agent'**
  String get subagentMainAgent;

  /// No description provided for @subagentIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get subagentIdle;

  /// No description provided for @thinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get thinking;

  /// No description provided for @noSubagentsYet.
  ///
  /// In en, this message translates to:
  /// **'No sub-agents yet'**
  String get noSubagentsYet;

  /// No description provided for @subagentsEmptyDesc.
  ///
  /// In en, this message translates to:
  /// **'Work the main agent delegates will be tracked here.'**
  String get subagentsEmptyDesc;

  /// No description provided for @noOutput.
  ///
  /// In en, this message translates to:
  /// **'No output'**
  String get noOutput;

  /// No description provided for @subagentCount.
  ///
  /// In en, this message translates to:
  /// **'{count} subagent'**
  String subagentCount(String count);

  /// No description provided for @subagentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} subagents'**
  String subagentsCount(String count);

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get settingsModels;

  /// No description provided for @settingsWorkspace.
  ///
  /// In en, this message translates to:
  /// **'Workspace'**
  String get settingsWorkspace;

  /// No description provided for @settingsWorkbench.
  ///
  /// In en, this message translates to:
  /// **'Workbench'**
  String get settingsWorkbench;

  /// No description provided for @settingsExtensions.
  ///
  /// In en, this message translates to:
  /// **'Extensions'**
  String get settingsExtensions;

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackup;

  /// No description provided for @settingsBackupIntro.
  ///
  /// In en, this message translates to:
  /// **'Export all your data to a file, or restore from a previous backup.'**
  String get settingsBackupIntro;

  /// No description provided for @backupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get backupCreate;

  /// No description provided for @backupCreateDesc.
  ///
  /// In en, this message translates to:
  /// **'Export settings, sessions, and tasks to a zip file.'**
  String get backupCreateDesc;

  /// No description provided for @providersSaveCurrent.
  ///
  /// In en, this message translates to:
  /// **'Save connection'**
  String get providersSaveCurrent;

  /// No description provided for @providersSaveCurrentDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep the connection you just tested in the book, so you can switch between providers without re-entering keys. Keys stay in the system keychain.'**
  String get providersSaveCurrentDesc;

  /// No description provided for @providersBookEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved connections yet. Configure one above, then save it here.'**
  String get providersBookEmpty;

  /// No description provided for @providersActivate.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get providersActivate;

  /// No description provided for @providersDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get providersDelete;

  /// No description provided for @modelsListLabel.
  ///
  /// In en, this message translates to:
  /// **'Model list'**
  String get modelsListLabel;

  /// No description provided for @modelsActiveTag.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get modelsActiveTag;

  /// No description provided for @modelsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get modelsRemove;

  /// No description provided for @modelsAddHint.
  ///
  /// In en, this message translates to:
  /// **'Add a model id, press Enter'**
  String get modelsAddHint;

  /// No description provided for @notificationsOn.
  ///
  /// In en, this message translates to:
  /// **'Raise the window when a run finishes'**
  String get notificationsOn;

  /// No description provided for @notificationsOnDesc.
  ///
  /// In en, this message translates to:
  /// **'When the window is hidden in the tray, finishing a run brings it back to the front.'**
  String get notificationsOnDesc;

  /// No description provided for @helpDocs.
  ///
  /// In en, this message translates to:
  /// **'Product docs'**
  String get helpDocs;

  /// No description provided for @helpCommunity.
  ///
  /// In en, this message translates to:
  /// **'User community'**
  String get helpCommunity;

  /// No description provided for @helpReportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report an issue'**
  String get helpReportIssue;

  /// No description provided for @helpFeatureRequest.
  ///
  /// In en, this message translates to:
  /// **'Request a feature'**
  String get helpFeatureRequest;

  /// No description provided for @helpReleases.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get helpReleases;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'New version {version} available'**
  String updateAvailableTitle(String version);

  /// No description provided for @updateBody.
  ///
  /// In en, this message translates to:
  /// **'Current {current}, latest {new_}.'**
  String updateBody(String current, String new_);

  /// No description provided for @updateSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this version'**
  String get updateSkip;

  /// No description provided for @updateDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get updateDownload;

  /// No description provided for @updateUpToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re on the latest version.'**
  String get updateUpToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Update check failed — try again later.'**
  String get updateCheckFailed;

  /// No description provided for @helpAbout.
  ///
  /// In en, this message translates to:
  /// **'About PlanStar'**
  String get helpAbout;

  /// No description provided for @helpAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'PlanStar'**
  String get helpAboutTitle;

  /// No description provided for @helpAboutBody.
  ///
  /// In en, this message translates to:
  /// **'A desktop AI agent workbench: agent conversations over Genkit and a plan workspace with Anytype-style data views. Version {version}.'**
  String helpAboutBody(String version);

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get authSignOut;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to PlanStar'**
  String get welcomeTitle;

  /// No description provided for @welcomeIntro.
  ///
  /// In en, this message translates to:
  /// **'Connect your account to start using the workbench.'**
  String get welcomeIntro;

  /// No description provided for @welcomeApiKeyIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter an API key from your provider to start.'**
  String get welcomeApiKeyIntro;

  /// No description provided for @welcomeProviderZai.
  ///
  /// In en, this message translates to:
  /// **'Continue with Z.ai'**
  String get welcomeProviderZai;

  /// No description provided for @welcomeProviderBigmodel.
  ///
  /// In en, this message translates to:
  /// **'Continue with BigModel'**
  String get welcomeProviderBigmodel;

  /// No description provided for @welcomeRegionGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get welcomeRegionGlobal;

  /// No description provided for @welcomeRegionCn.
  ///
  /// In en, this message translates to:
  /// **'CN'**
  String get welcomeRegionCn;

  /// No description provided for @welcomeUseApiKey.
  ///
  /// In en, this message translates to:
  /// **'Use API key'**
  String get welcomeUseApiKey;

  /// No description provided for @welcomeApiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get welcomeApiKeyHint;

  /// No description provided for @welcomeApiKeySave.
  ///
  /// In en, this message translates to:
  /// **'Save and start'**
  String get welcomeApiKeySave;

  /// No description provided for @welcomeSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get welcomeSkip;

  /// No description provided for @welcomeBackToProviders.
  ///
  /// In en, this message translates to:
  /// **'Back to sign-in options'**
  String get welcomeBackToProviders;

  /// No description provided for @welcomeWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for authentication in your browser…'**
  String get welcomeWaiting;

  /// No description provided for @welcomeCancelWait.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get welcomeCancelWait;

  /// No description provided for @welcomeFlowFailed.
  ///
  /// In en, this message translates to:
  /// **'The sign-in flow failed. Try again.'**
  String get welcomeFlowFailed;

  /// No description provided for @welcomeFlowUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No backend endpoint is configured, so browser sign-in is unavailable. Use an API key instead.'**
  String get welcomeFlowUnavailable;

  /// No description provided for @welcomeRegister.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get welcomeRegister;

  /// No description provided for @welcomeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get welcomeLater;

  /// No description provided for @settingsShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get settingsShortcuts;

  /// No description provided for @settingsShortcutsIntro.
  ///
  /// In en, this message translates to:
  /// **'Every keyboard command in one place. Editing bindings arrives in a later update.'**
  String get settingsShortcutsIntro;

  /// No description provided for @shortcutToggleWindow.
  ///
  /// In en, this message translates to:
  /// **'Show or hide the window'**
  String get shortcutToggleWindow;

  /// No description provided for @shortcutNewSession.
  ///
  /// In en, this message translates to:
  /// **'New session'**
  String get shortcutNewSession;

  /// No description provided for @shortcutOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get shortcutOpenSettings;

  /// No description provided for @shortcutToggleSidebar.
  ///
  /// In en, this message translates to:
  /// **'Toggle the sidebar'**
  String get shortcutToggleSidebar;

  /// No description provided for @settingsUsage.
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get settingsUsage;

  /// No description provided for @settingsUsageIntro.
  ///
  /// In en, this message translates to:
  /// **'Local model usage, kept for 30 days on this machine only. Nothing leaves the device.'**
  String get settingsUsageIntro;

  /// No description provided for @usageTurns.
  ///
  /// In en, this message translates to:
  /// **'Model turns recorded'**
  String get usageTurns;

  /// No description provided for @usageTotalTokens.
  ///
  /// In en, this message translates to:
  /// **'Tokens used'**
  String get usageTotalTokens;

  /// No description provided for @usageErrorRate.
  ///
  /// In en, this message translates to:
  /// **'Turn error rate'**
  String get usageErrorRate;

  /// No description provided for @usageCrashLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Crash & error archive'**
  String get usageCrashLogTitle;

  /// No description provided for @usageCrashLogDesc.
  ///
  /// In en, this message translates to:
  /// **'Local reports for the last crashes, kept for the newest 5 files. Nothing is uploaded.'**
  String get usageCrashLogDesc;

  /// No description provided for @usageCrashLogOpen.
  ///
  /// In en, this message translates to:
  /// **'Open folder'**
  String get usageCrashLogOpen;

  /// No description provided for @settingsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get settingsDiagnostics;

  /// No description provided for @settingsDiagnosticsIntro.
  ///
  /// In en, this message translates to:
  /// **'Local logs for debugging the agent: one line per model call, and — if you turn it on — the full messages sent to the model. Kept for 30 days on this machine only.'**
  String get settingsDiagnosticsIntro;

  /// No description provided for @diagnosticRequestLog.
  ///
  /// In en, this message translates to:
  /// **'Request log'**
  String get diagnosticRequestLog;

  /// No description provided for @diagnosticRequestLogDesc.
  ///
  /// In en, this message translates to:
  /// **'Record every model call: duration, outcome and token usage.'**
  String get diagnosticRequestLogDesc;

  /// No description provided for @diagnosticContextLog.
  ///
  /// In en, this message translates to:
  /// **'Context snapshot'**
  String get diagnosticContextLog;

  /// No description provided for @diagnosticContextLogDesc.
  ///
  /// In en, this message translates to:
  /// **'Also record the full messages each call sends to the model. Large; off by default.'**
  String get diagnosticContextLogDesc;

  /// No description provided for @diagnosticFolderTitle.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics folder'**
  String get diagnosticFolderTitle;

  /// No description provided for @diagnosticFolderDesc.
  ///
  /// In en, this message translates to:
  /// **'requests-*.jsonl and contexts-*.jsonl, one file per month.'**
  String get diagnosticFolderDesc;

  /// No description provided for @settingsFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get settingsFeedback;

  /// No description provided for @settingsFeedbackDesc.
  ///
  /// In en, this message translates to:
  /// **'Report a problem or suggest an idea. Opens a pre-filled draft on the GitHub issue tracker that you review and submit.'**
  String get settingsFeedbackDesc;

  /// No description provided for @settingsFeedbackOpen.
  ///
  /// In en, this message translates to:
  /// **'Open form'**
  String get settingsFeedbackOpen;

  /// No description provided for @feedbackIssueOpened.
  ///
  /// In en, this message translates to:
  /// **'Opened a feedback draft in your browser'**
  String get feedbackIssueOpened;

  /// No description provided for @settingsReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get settingsReset;

  /// No description provided for @settingsResetDesc.
  ///
  /// In en, this message translates to:
  /// **'Quarantine settings and preferences and start from defaults. The API key is removed from the keychain. Sessions and plan data are kept.'**
  String get settingsResetDesc;

  /// No description provided for @settingsResetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset settings and preferences?'**
  String get settingsResetConfirmTitle;

  /// No description provided for @settingsResetConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your current settings file is kept as a .corrupt- copy next to the new one, so this is recoverable by hand. Sessions and plan data are untouched.'**
  String get settingsResetConfirmBody;

  /// No description provided for @settingsResetDone.
  ///
  /// In en, this message translates to:
  /// **'Settings and preferences were reset'**
  String get settingsResetDone;

  /// No description provided for @backupExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get backupExport;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get backupRestore;

  /// No description provided for @backupRestoreDesc.
  ///
  /// In en, this message translates to:
  /// **'Import data from a backup file, overwriting current data.'**
  String get backupRestoreDesc;

  /// No description provided for @backupImport.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get backupImport;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created with {count} files.'**
  String backupCreated(String count);

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored {count} files. Restart to apply.'**
  String backupRestored(String count);

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup failed'**
  String get backupFailed;

  /// No description provided for @searchSettings.
  ///
  /// In en, this message translates to:
  /// **'Search settings…'**
  String get searchSettings;

  /// No description provided for @settingsGeneralIntro.
  ///
  /// In en, this message translates to:
  /// **'How the app itself looks and behaves.'**
  String get settingsGeneralIntro;

  /// No description provided for @settingsAppearanceIntro.
  ///
  /// In en, this message translates to:
  /// **'The face and width of the conversation, and how generated files are shown.'**
  String get settingsAppearanceIntro;

  /// No description provided for @settingsModelsIntro.
  ///
  /// In en, this message translates to:
  /// **'Which endpoint this build talks to.'**
  String get settingsModelsIntro;

  /// No description provided for @settingsWorkspaceIntro.
  ///
  /// In en, this message translates to:
  /// **'The one folder the file tools may read and write. They refuse every call while this is empty, and refuse any path that resolves outside it.'**
  String get settingsWorkspaceIntro;

  /// No description provided for @settingsTerminalIntro.
  ///
  /// In en, this message translates to:
  /// **'The face every terminal tab wears. Applied live — no restart, not even a Save.'**
  String get settingsTerminalIntro;

  /// No description provided for @settingsTabsIntro.
  ///
  /// In en, this message translates to:
  /// **'Which tab types the + menu offers and the opens accept. Tabs already open keep rendering until you close them.'**
  String get settingsTabsIntro;

  /// No description provided for @settingsMcpIntro.
  ///
  /// In en, this message translates to:
  /// **'External tools the agent may call, named <server>/<tool>. A server is launched over stdio from a command, or reached over HTTP at a URL — fill in one or the other. Changes take effect after the runtime is rebuilt (Save), and a server that fails to connect simply contributes nothing.'**
  String get settingsMcpIntro;

  /// No description provided for @settingsSkillsIntro.
  ///
  /// In en, this message translates to:
  /// **'The folder whose sub-directories each hold a SKILL.md. The agent lists them in its system prompt and loads one with the use_skill tool. Empty means <application support>/skills.'**
  String get settingsSkillsIntro;

  /// No description provided for @settingsMcpServers.
  ///
  /// In en, this message translates to:
  /// **'MCP servers'**
  String get settingsMcpServers;

  /// No description provided for @settingsSkills.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get settingsSkills;

  /// No description provided for @tabs.
  ///
  /// In en, this message translates to:
  /// **'Tabs'**
  String get tabs;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeDesc.
  ///
  /// In en, this message translates to:
  /// **'Light, dark, or whatever the system is doing.'**
  String get themeDesc;

  /// No description provided for @followSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get followSystem;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDesc.
  ///
  /// In en, this message translates to:
  /// **'English or Chinese, or follow the system.'**
  String get languageDesc;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get chinese;

  /// No description provided for @appearanceTextSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get appearanceTextSize;

  /// No description provided for @appearanceTextSizeDesc.
  ///
  /// In en, this message translates to:
  /// **'How large the conversation text renders.'**
  String get appearanceTextSizeDesc;

  /// No description provided for @sizeSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get sizeSmall;

  /// No description provided for @sizeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get sizeMedium;

  /// No description provided for @sizeLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get sizeLarge;

  /// No description provided for @conversationWidth.
  ///
  /// In en, this message translates to:
  /// **'Conversation width'**
  String get conversationWidth;

  /// No description provided for @conversationWidthDesc.
  ///
  /// In en, this message translates to:
  /// **'How wide the message column stretches.'**
  String get conversationWidthDesc;

  /// No description provided for @widthNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get widthNormal;

  /// No description provided for @widthWide.
  ///
  /// In en, this message translates to:
  /// **'Wide'**
  String get widthWide;

  /// No description provided for @expandToolCalls.
  ///
  /// In en, this message translates to:
  /// **'Expand tool calls'**
  String get expandToolCalls;

  /// No description provided for @expandToolCallsDesc.
  ///
  /// In en, this message translates to:
  /// **'Newly shown tool blocks start open.'**
  String get expandToolCallsDesc;

  /// No description provided for @provider.
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get provider;

  /// No description provided for @providerOpenAiCompatible.
  ///
  /// In en, this message translates to:
  /// **'OpenAI-compatible'**
  String get providerOpenAiCompatible;

  /// No description provided for @providerAnthropic.
  ///
  /// In en, this message translates to:
  /// **'Anthropic'**
  String get providerAnthropic;

  /// No description provided for @providerGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get providerGoogle;

  /// No description provided for @apiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get apiKey;

  /// No description provided for @baseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get baseUrl;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @providerDefault.
  ///
  /// In en, this message translates to:
  /// **'provider default'**
  String get providerDefault;

  /// No description provided for @keyConfigured.
  ///
  /// In en, this message translates to:
  /// **'Key configured'**
  String get keyConfigured;

  /// No description provided for @noKeyComposerDisabled.
  ///
  /// In en, this message translates to:
  /// **'No key — the composer stays disabled'**
  String get noKeyComposerDisabled;

  /// No description provided for @keyMissing.
  ///
  /// In en, this message translates to:
  /// **'Key missing'**
  String get keyMissing;

  /// No description provided for @keyStored.
  ///
  /// In en, this message translates to:
  /// **'A key is stored'**
  String get keyStored;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @customized.
  ///
  /// In en, this message translates to:
  /// **'Customized'**
  String get customized;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get testConnection;

  /// No description provided for @connectionOk.
  ///
  /// In en, this message translates to:
  /// **'{n} models available'**
  String connectionOk(String n);

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach the endpoint.'**
  String get connectionFailed;

  /// No description provided for @probeTimeout.
  ///
  /// In en, this message translates to:
  /// **'The endpoint did not answer in time.'**
  String get probeTimeout;

  /// No description provided for @fetchingModels.
  ///
  /// In en, this message translates to:
  /// **'Fetching models…'**
  String get fetchingModels;

  /// No description provided for @chooseModel.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get chooseModel;

  /// No description provided for @noModelsFetched.
  ///
  /// In en, this message translates to:
  /// **'Run Test connection to load the list'**
  String get noModelsFetched;

  /// No description provided for @refreshModels.
  ///
  /// In en, this message translates to:
  /// **'Load the endpoint\'s list'**
  String get refreshModels;

  /// No description provided for @modelManagement.
  ///
  /// In en, this message translates to:
  /// **'Model management'**
  String get modelManagement;

  /// No description provided for @statsCounts.
  ///
  /// In en, this message translates to:
  /// **'{turns} turns · {steps} steps'**
  String statsCounts(String turns, String steps);

  /// No description provided for @statsLlm.
  ///
  /// In en, this message translates to:
  /// **'LLM {duration}'**
  String statsLlm(String duration);

  /// No description provided for @statsTool.
  ///
  /// In en, this message translates to:
  /// **'Tool call {duration}'**
  String statsTool(String duration);

  /// No description provided for @statsTtft.
  ///
  /// In en, this message translates to:
  /// **'TTFT avg {duration}'**
  String statsTtft(String duration);

  /// No description provided for @statsTokens.
  ///
  /// In en, this message translates to:
  /// **'{tokens} tokens'**
  String statsTokens(String tokens);

  /// No description provided for @folder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get folder;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose…'**
  String get choose;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @missing.
  ///
  /// In en, this message translates to:
  /// **'missing'**
  String get missing;

  /// No description provided for @folderNotOnDisk.
  ///
  /// In en, this message translates to:
  /// **'This folder is not on disk right now.'**
  String get folderNotOnDisk;

  /// No description provided for @fontFamily.
  ///
  /// In en, this message translates to:
  /// **'Font family'**
  String get fontFamily;

  /// No description provided for @fontFamilyHint.
  ///
  /// In en, this message translates to:
  /// **'\'\' follows the theme\'s code font'**
  String get fontFamilyHint;

  /// No description provided for @fontSize.
  ///
  /// In en, this message translates to:
  /// **'Font size'**
  String get fontSize;

  /// No description provided for @seedBottomPanel.
  ///
  /// In en, this message translates to:
  /// **'Seed the bottom panel'**
  String get seedBottomPanel;

  /// No description provided for @seedBottomPanelDesc.
  ///
  /// In en, this message translates to:
  /// **'Expanding the bottom panel for the first time in a session opens a terminal tab there.'**
  String get seedBottomPanelDesc;

  /// No description provided for @explorerDesc.
  ///
  /// In en, this message translates to:
  /// **'The file tree over the workspace folder.'**
  String get explorerDesc;

  /// No description provided for @terminalDesc.
  ///
  /// In en, this message translates to:
  /// **'A shell over the workspace folder.'**
  String get terminalDesc;

  /// No description provided for @gitDesc.
  ///
  /// In en, this message translates to:
  /// **'The git change list and its diffs.'**
  String get gitDesc;

  /// No description provided for @subagentsDesc.
  ///
  /// In en, this message translates to:
  /// **'The live sub-agent and job view.'**
  String get subagentsDesc;

  /// No description provided for @browserDesc.
  ///
  /// In en, this message translates to:
  /// **'The built-in web view with its address bar.'**
  String get browserDesc;

  /// No description provided for @sideChatDesc.
  ///
  /// In en, this message translates to:
  /// **'Quick asides beside the main thread.'**
  String get sideChatDesc;

  /// No description provided for @addServer.
  ///
  /// In en, this message translates to:
  /// **'Add server'**
  String get addServer;

  /// No description provided for @serverName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get serverName;

  /// No description provided for @arguments.
  ///
  /// In en, this message translates to:
  /// **'Arguments'**
  String get arguments;

  /// No description provided for @commandStdio.
  ///
  /// In en, this message translates to:
  /// **'Command (stdio)'**
  String get commandStdio;

  /// No description provided for @urlHttp.
  ///
  /// In en, this message translates to:
  /// **'URL (HTTP)'**
  String get urlHttp;

  /// No description provided for @showKey.
  ///
  /// In en, this message translates to:
  /// **'Show key'**
  String get showKey;

  /// No description provided for @hideKey.
  ///
  /// In en, this message translates to:
  /// **'Hide key'**
  String get hideKey;

  /// No description provided for @closeSettings.
  ///
  /// In en, this message translates to:
  /// **'Close settings'**
  String get closeSettings;

  /// No description provided for @forget.
  ///
  /// In en, this message translates to:
  /// **'Forget'**
  String get forget;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// No description provided for @removeServer.
  ///
  /// In en, this message translates to:
  /// **'Remove server'**
  String get removeServer;

  /// No description provided for @restartWarning.
  ///
  /// In en, this message translates to:
  /// **'Saving reconnects the agent. The open conversation is cleared; it stays on disk and can be reopened from the sidebar.'**
  String get restartWarning;

  /// No description provided for @planCellEmpty.
  ///
  /// In en, this message translates to:
  /// **'No value'**
  String get planCellEmpty;

  /// No description provided for @planCellChecked.
  ///
  /// In en, this message translates to:
  /// **'Marked done'**
  String get planCellChecked;

  /// No description provided for @planCellUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Mark not done'**
  String get planCellUnchecked;

  /// No description provided for @planFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get planFieldName;

  /// No description provided for @planUntitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get planUntitled;

  /// No description provided for @planNewRow.
  ///
  /// In en, this message translates to:
  /// **'New row'**
  String get planNewRow;

  /// No description provided for @planNoRecords.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get planNoRecords;

  /// No description provided for @planRecordCount.
  ///
  /// In en, this message translates to:
  /// **'records'**
  String get planRecordCount;

  /// No description provided for @planColumnNoStatus.
  ///
  /// In en, this message translates to:
  /// **'No status'**
  String get planColumnNoStatus;

  /// No description provided for @planColumnChecked.
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get planColumnChecked;

  /// No description provided for @planCollections.
  ///
  /// In en, this message translates to:
  /// **'Collections'**
  String get planCollections;

  /// No description provided for @planLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get planLibrary;

  /// No description provided for @planWidgetStrip.
  ///
  /// In en, this message translates to:
  /// **'Home widgets'**
  String get planWidgetStrip;

  /// No description provided for @planBinTitle.
  ///
  /// In en, this message translates to:
  /// **'Bin'**
  String get planBinTitle;

  /// No description provided for @planBinEmpty.
  ///
  /// In en, this message translates to:
  /// **'The bin is empty'**
  String get planBinEmpty;

  /// No description provided for @planBinEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Every binned record will be gone for good.'**
  String get planBinEmptyBody;

  /// No description provided for @planBinActions.
  ///
  /// In en, this message translates to:
  /// **'Bin actions'**
  String get planBinActions;

  /// No description provided for @planBinned.
  ///
  /// In en, this message translates to:
  /// **'binned'**
  String get planBinned;

  /// No description provided for @planRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored'**
  String get planRestored;

  /// No description provided for @planObjectInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Object info'**
  String get planObjectInfoTitle;

  /// No description provided for @planTemplatesTitleShort.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get planTemplatesTitleShort;

  /// No description provided for @planCollectionMenu.
  ///
  /// In en, this message translates to:
  /// **'Collection actions'**
  String get planCollectionMenu;

  /// No description provided for @planMarkBold.
  ///
  /// In en, this message translates to:
  /// **'Bold'**
  String get planMarkBold;

  /// No description provided for @planMarkItalic.
  ///
  /// In en, this message translates to:
  /// **'Italic'**
  String get planMarkItalic;

  /// No description provided for @planMarkStrike.
  ///
  /// In en, this message translates to:
  /// **'Strikethrough'**
  String get planMarkStrike;

  /// No description provided for @planMarkUnderline.
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get planMarkUnderline;

  /// No description provided for @planMarkCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get planMarkCode;

  /// No description provided for @planMarkLink.
  ///
  /// In en, this message translates to:
  /// **'Link'**
  String get planMarkLink;

  /// No description provided for @planCalendarUndated.
  ///
  /// In en, this message translates to:
  /// **'{count} record(s) without a date'**
  String planCalendarUndated(String count);

  /// No description provided for @planColumnUnchecked.
  ///
  /// In en, this message translates to:
  /// **'Unchecked'**
  String get planColumnUnchecked;

  /// No description provided for @planSortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get planSortBy;

  /// No description provided for @planSortAdd.
  ///
  /// In en, this message translates to:
  /// **'Add sort'**
  String get planSortAdd;

  /// No description provided for @planSortDirection.
  ///
  /// In en, this message translates to:
  /// **'Sort direction'**
  String get planSortDirection;

  /// No description provided for @planSortEmpty.
  ///
  /// In en, this message translates to:
  /// **'Where empty values go'**
  String get planSortEmpty;

  /// No description provided for @planSortAsc.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get planSortAsc;

  /// No description provided for @planSortDesc.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get planSortDesc;

  /// No description provided for @planSortClear.
  ///
  /// In en, this message translates to:
  /// **'Clear this sort'**
  String get planSortClear;

  /// No description provided for @planHideField.
  ///
  /// In en, this message translates to:
  /// **'Hide field'**
  String get planHideField;

  /// No description provided for @planFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get planFilterTitle;

  /// No description provided for @planFilterAdd.
  ///
  /// In en, this message translates to:
  /// **'Add filter'**
  String get planFilterAdd;

  /// No description provided for @planFilterCondition.
  ///
  /// In en, this message translates to:
  /// **'Condition'**
  String get planFilterCondition;

  /// No description provided for @planFilterValue.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get planFilterValue;

  /// No description provided for @planFilterPickValue.
  ///
  /// In en, this message translates to:
  /// **'Set value'**
  String get planFilterPickValue;

  /// No description provided for @planFilterOperator.
  ///
  /// In en, this message translates to:
  /// **'Operator'**
  String get planFilterOperator;

  /// No description provided for @planFilterNestedUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Nested rules are desktop-only and are not applied here'**
  String get planFilterNestedUnsupported;

  /// No description provided for @planNewOption.
  ///
  /// In en, this message translates to:
  /// **'New option'**
  String get planNewOption;

  /// No description provided for @planDateLiteral.
  ///
  /// In en, this message translates to:
  /// **'Exact date'**
  String get planDateLiteral;

  /// No description provided for @planRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get planRemove;

  /// No description provided for @planDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get planDelete;

  /// No description provided for @planSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get planSave;

  /// No description provided for @planLayoutTitle.
  ///
  /// In en, this message translates to:
  /// **'Layout'**
  String get planLayoutTitle;

  /// No description provided for @planLayoutHideIcon.
  ///
  /// In en, this message translates to:
  /// **'Hide icons'**
  String get planLayoutHideIcon;

  /// No description provided for @planLayoutCardSize.
  ///
  /// In en, this message translates to:
  /// **'Card size'**
  String get planLayoutCardSize;

  /// No description provided for @planLayoutCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get planLayoutCover;

  /// No description provided for @planLayoutNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get planLayoutNone;

  /// No description provided for @planLayoutCoverFit.
  ///
  /// In en, this message translates to:
  /// **'Cover fits the card'**
  String get planLayoutCoverFit;

  /// No description provided for @planLayoutGroupBy.
  ///
  /// In en, this message translates to:
  /// **'Group by'**
  String get planLayoutGroupBy;

  /// No description provided for @planLayoutColorColumns.
  ///
  /// In en, this message translates to:
  /// **'Colour columns'**
  String get planLayoutColorColumns;

  /// No description provided for @planLayoutDefaultType.
  ///
  /// In en, this message translates to:
  /// **'Default type for new records'**
  String get planLayoutDefaultType;

  /// No description provided for @planLayoutDefaultTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template for new records'**
  String get planLayoutDefaultTemplate;

  /// No description provided for @planFieldsTitle.
  ///
  /// In en, this message translates to:
  /// **'Fields'**
  String get planFieldsTitle;

  /// No description provided for @planFieldDateFormat.
  ///
  /// In en, this message translates to:
  /// **'Date format'**
  String get planFieldDateFormat;

  /// No description provided for @planFieldWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get planFieldWidth;

  /// No description provided for @planAllViews.
  ///
  /// In en, this message translates to:
  /// **'All views'**
  String get planAllViews;

  /// No description provided for @planAddView.
  ///
  /// In en, this message translates to:
  /// **'New view'**
  String get planAddView;

  /// No description provided for @planViewSettings.
  ///
  /// In en, this message translates to:
  /// **'View settings'**
  String get planViewSettings;

  /// No description provided for @planToggleHeader.
  ///
  /// In en, this message translates to:
  /// **'Hide header'**
  String get planToggleHeader;

  /// No description provided for @planViewSoonTag.
  ///
  /// In en, this message translates to:
  /// **'not on desktop-size yet'**
  String get planViewSoonTag;

  /// No description provided for @planViewRename.
  ///
  /// In en, this message translates to:
  /// **'Rename view'**
  String get planViewRename;

  /// No description provided for @planViewDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate view'**
  String get planViewDuplicate;

  /// No description provided for @planViewMoveLeft.
  ///
  /// In en, this message translates to:
  /// **'Move left'**
  String get planViewMoveLeft;

  /// No description provided for @planViewMoveRight.
  ///
  /// In en, this message translates to:
  /// **'Move right'**
  String get planViewMoveRight;

  /// No description provided for @planViewDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete view'**
  String get planViewDelete;

  /// No description provided for @planViewDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This view and its filters are removed. The records stay.'**
  String get planViewDeleteBody;

  /// No description provided for @planViewDeleted.
  ///
  /// In en, this message translates to:
  /// **'View deleted'**
  String get planViewDeleted;

  /// No description provided for @planViewCalendarUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Calendar view is not available in this workspace yet. Change the view type, or create a new view to reach your data.'**
  String get planViewCalendarUnsupported;

  /// No description provided for @planViewGraphUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Graph view is not available in this workspace yet. Change the view type, or create a new view to reach your data.'**
  String get planViewGraphUnsupported;

  /// No description provided for @planCollectionMissing.
  ///
  /// In en, this message translates to:
  /// **'This collection is no longer here'**
  String get planCollectionMissing;

  /// No description provided for @planRenameCollection.
  ///
  /// In en, this message translates to:
  /// **'Rename collection'**
  String get planRenameCollection;

  /// No description provided for @planRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get planRecordTitle;

  /// No description provided for @planRecordNoFields.
  ///
  /// In en, this message translates to:
  /// **'No fields in this view'**
  String get planRecordNoFields;

  /// No description provided for @planFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get planFavorite;

  /// No description provided for @planUnfavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get planUnfavorite;

  /// No description provided for @planRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get planRestore;

  /// No description provided for @planMoveToBin.
  ///
  /// In en, this message translates to:
  /// **'Move to bin'**
  String get planMoveToBin;

  /// No description provided for @planDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get planDuplicate;

  /// No description provided for @planCondEqual.
  ///
  /// In en, this message translates to:
  /// **'is'**
  String get planCondEqual;

  /// No description provided for @planCondNotEqual.
  ///
  /// In en, this message translates to:
  /// **'is not'**
  String get planCondNotEqual;

  /// No description provided for @planCondGreater.
  ///
  /// In en, this message translates to:
  /// **'greater than'**
  String get planCondGreater;

  /// No description provided for @planCondGreaterOrEqual.
  ///
  /// In en, this message translates to:
  /// **'greater than or equal'**
  String get planCondGreaterOrEqual;

  /// No description provided for @planCondLess.
  ///
  /// In en, this message translates to:
  /// **'less than'**
  String get planCondLess;

  /// No description provided for @planCondLessOrEqual.
  ///
  /// In en, this message translates to:
  /// **'less than or equal'**
  String get planCondLessOrEqual;

  /// No description provided for @planCondLike.
  ///
  /// In en, this message translates to:
  /// **'contains'**
  String get planCondLike;

  /// No description provided for @planCondNotLike.
  ///
  /// In en, this message translates to:
  /// **'does not contain'**
  String get planCondNotLike;

  /// No description provided for @planCondIn.
  ///
  /// In en, this message translates to:
  /// **'is any of'**
  String get planCondIn;

  /// No description provided for @planCondNotIn.
  ///
  /// In en, this message translates to:
  /// **'is not any of'**
  String get planCondNotIn;

  /// No description provided for @planCondEmpty.
  ///
  /// In en, this message translates to:
  /// **'is empty'**
  String get planCondEmpty;

  /// No description provided for @planCondNotEmpty.
  ///
  /// In en, this message translates to:
  /// **'is not empty'**
  String get planCondNotEmpty;

  /// No description provided for @planCondAllIn.
  ///
  /// In en, this message translates to:
  /// **'has all of'**
  String get planCondAllIn;

  /// No description provided for @planCondNotAllIn.
  ///
  /// In en, this message translates to:
  /// **'does not have all of'**
  String get planCondNotAllIn;

  /// No description provided for @planCondNone.
  ///
  /// In en, this message translates to:
  /// **'has none of'**
  String get planCondNone;

  /// No description provided for @planCondExactIn.
  ///
  /// In en, this message translates to:
  /// **'is exactly'**
  String get planCondExactIn;

  /// No description provided for @planCondNotExactIn.
  ///
  /// In en, this message translates to:
  /// **'is not exactly'**
  String get planCondNotExactIn;

  /// No description provided for @planCondExists.
  ///
  /// In en, this message translates to:
  /// **'exists'**
  String get planCondExists;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
