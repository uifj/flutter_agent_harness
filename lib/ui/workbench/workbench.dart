// The workbench: what fills the app frame's details column.
//
// Everything below it is driven by one [WorkbenchController]. This widget's whole
// job is to listen to it, hand the tree to [SplitView], and put a header above.
//
// The listen is an [AnimatedBuilder] on the controller rather than an
// `InheritedNotifier`, and that is the reason tab bodies take the controller as a
// constructor argument: rebuilding on notification is right for the *layout*
// (which is what changed) and wrong for the bodies, where a notification about
// some other pane must not reload a file or re-run a highlight pass. The bodies
// are reached through [SplitView], whose children are keyed by tab id, so an
// unchanged tab keeps its element and its state.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../host/git.dart';
import '../../host/terminal_manager.dart';
import '../../state/conversation_controller.dart';
import '../../state/side_chat_controller.dart';
import '../../theme/dsw_theme.dart';
import '../../model/sidebar_tab.dart';
import '../../state/workbench_controller.dart';
import 'split_view.dart';
import 'tab_registry.dart';
import 'tabs/browser_tab.dart';
import 'tabs/diff_tab.dart';
import 'tabs/editor_tab.dart';
import 'tabs/file_tree_tab.dart';
import 'tabs/git_tab.dart';
import 'tabs/sidechat_tab.dart';
import 'tabs/subagent_tab.dart';
import 'tabs/terminal_tab.dart';

/// Installs the tab types this build ships.
///
/// Called from [Workbench]'s constructor path rather than from `main`, so a test
/// that pumps a workbench gets the same registry the app has without having to
/// know that registration is a thing.
void _registerBuiltinTabs() {
  if (tabRegistry.isNotEmpty) return;
  registerTab(
    TabDescriptor(
      type: BuiltinTabType.explorer,
      icon: LucideIcons.folder_open,
      order: 10,
      build: (context, workbench, tab) =>
          FileTreeTab(workbench: workbench, tab: tab),
    ),
  );
  registerTab(
    TabDescriptor(
      type: BuiltinTabType.editor,
      icon: LucideIcons.file_text,
      order: 20,
      build: (context, workbench, tab) =>
          EditorTab(workbench: workbench, tab: tab),
    ),
  );
  registerTab(
    TabDescriptor(
      type: BuiltinTabType.terminal,
      icon: LucideIcons.terminal,
      order: 30,
      build: (context, workbench, tab) =>
          TerminalTab(workbench: workbench, tab: tab),
    ),
  );
  registerTab(
    TabDescriptor(
      type: BuiltinTabType.git,
      icon: LucideIcons.git_branch,
      order: 40,
      build: (context, workbench, tab) => GitTab(workbench: workbench, tab: tab),
    ),
  );
  registerTab(
    TabDescriptor(
      type: BuiltinTabType.diff,
      icon: LucideIcons.file_diff,
      order: 50,
      build: (context, workbench, tab) => DiffTab(workbench: workbench, tab: tab),
    ),
  );
  registerTab(
    TabDescriptor(
      type: BuiltinTabType.subagent,
      icon: LucideIcons.network,
      order: 60,
      build: (context, workbench, tab) =>
          SubagentTab(workbench: workbench, tab: tab),
    ),
  );
  registerTab(
    TabDescriptor(
      type: BuiltinTabType.browser,
      icon: LucideIcons.globe,
      order: 70,
      build: (context, workbench, tab) =>
          BrowserTab(workbench: workbench, tab: tab),
    ),
  );
  registerTab(
    TabDescriptor(
      type: BuiltinTabType.sidechat,
      icon: LucideIcons.message_square_plus,
      order: 80,
      build: (context, workbench, tab) =>
          SideChatTab(workbench: workbench, tab: tab),
    ),
  );
}

/// Which of the two panels a [Workbench] renders. Both panels share one
/// [WorkbenchController] and its one [SidebarState] — the trees are two halves
/// of a single layout, and tabs cross between them — so the panel says which
/// tree to show, not which state to read.
enum WorkbenchPanel { right, bottom }

/// What the open right panel's strips reserve at their right end for the
/// viewport-corner toggle cluster — `sidebar.module.css:83-85` reserves 72px
/// the same way, so the tabs genuinely yield space to the cluster.
const _clusterReserve = 72.0;

/// The side-chat controller a workbench with no app behind it falls back to —
/// a test pumping a [Workbench] without passing one still gets a host, and a
/// host-less side-chat tab would be a crash instead of an empty page.
final _fallbackSideChat = SideChatController();

class Workbench extends StatelessWidget {
  Workbench({
    super.key,
    required this.workbench,
    required this.conversation,
    required this.onClose,
    this.panel = WorkbenchPanel.right,
    this.sideChat,
    TerminalManager? terminals,
    GitRunner? git,
  }) : terminals = terminals ?? TerminalManager(),
       git = git ?? runGit {
    _registerBuiltinTabs();
  }

  final WorkbenchController workbench;

  /// The transcript the sub-agent tab projects its topology from. On the scope
  /// rather than captured by the tab builder for the reason [SubagentHost]
  /// spells out.
  final ConversationController conversation;

  /// The side chat's controller, on the scope for the same reason. Null falls
  /// back to a shared controller with no runner, whose tab says so.
  final SideChatController? sideChat;

  /// Closes the whole column, the way the details panel's own header does.
  final VoidCallback onClose;

  /// Which panel this instance renders — the right column's tree or the bottom
  /// panel's. The right panel's strips reserve their right end for the toggle
  /// cluster; the bottom panel sits below it and needs no reserve.
  final WorkbenchPanel panel;

  /// The pty pool the terminal tabs draw from. The app passes its own so the
  /// shells die with the app rather than with this column; a default one is
  /// created otherwise because nothing else in the workbench's own tree is
  /// positioned to own host processes — and since sessions are only spawned
  /// when a terminal body is actually built, an unused default pool never
  /// spawns anything.
  final TerminalManager terminals;

  /// How the git tab talks to git. The default runs the real binary; a test
  /// passes a fake so the whole panel runs without a repository.
  final GitRunner git;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(left: BorderSide(color: color.borderL2)),
      ),
      child: GitHost(
        runner: git,
        child: TerminalHost(
          manager: terminals,
          child: SubagentHost(
            conversation: conversation,
            child: SideChatHost(
              chat: sideChat ?? _fallbackSideChat,
              child: AnimatedBuilder(
                animation: workbench,
                builder: (context, _) {
                  final state = workbench.state;
                  final (node, alone) = switch (panel) {
                    WorkbenchPanel.right => (
                      state.tree,
                      state.panes.length == 1,
                    ),
                    WorkbenchPanel.bottom => (
                      state.bottomTree,
                      state.bottomPanes.length == 1,
                    ),
                  };
                  // The panel's top chrome is its first tab strip — there is no
                  // header row above it, so the strip's `+` menu is the only
                  // opener surface (`.panel` = resize strip + panelBody in the
                  // source).
                  return SplitView(
                    workbench: workbench,
                    node: node,
                    alone: alone,
                    reserveTrailing: panel == WorkbenchPanel.right
                        ? _clusterReserve
                        : 0,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
