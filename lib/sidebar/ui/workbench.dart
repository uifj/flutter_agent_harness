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
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../model/sidebar_tab.dart';
import '../state/workbench_controller.dart';
import 'split_view.dart';
import 'tab_registry.dart';
import 'tabs/diff_tab.dart';
import 'tabs/editor_tab.dart';
import 'tabs/file_tree_tab.dart';
import 'tabs/git_tab.dart';
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
}

class Workbench extends StatelessWidget {
  Workbench({
    super.key,
    required this.workbench,
    required this.conversation,
    required this.onClose,
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

  /// Closes the whole column, the way the details panel's own header does.
  final VoidCallback onClose;

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
        border: Border(left: BorderSide(color: color.borderL1)),
      ),
      child: GitHost(
        runner: git,
        child: TerminalHost(
          manager: terminals,
          child: SubagentHost(
            conversation: conversation,
            child: AnimatedBuilder(
              animation: workbench,
              builder: (context, _) {
                final state = workbench.state;
                return Column(
                  children: [
                    _Header(workbench: workbench, onClose: onClose),
                    Expanded(
                      child: SplitView(
                        workbench: workbench,
                        node: state.tree,
                        alone: state.panes.length == 1,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The column's own title row, above the panes. Holds the openers that are not
/// tied to a pane; a pane's own controls live in its tab strip.
///
/// No title text: the switcher above it already names this panel, and a second
/// "Workbench" would be the same word twice in 60 vertical pixels. What the row
/// says instead is which folder the panes are looking at.
class _Header extends StatelessWidget {
  const _Header({required this.workbench, required this.onClose});

  final WorkbenchController workbench;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final root = workbench.workspaceRoot;
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(bottom: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              root == null ? 'No folder' : root.split('/').last,
              style: DswType.xxsStrong12.copyWith(color: color.labelSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          _HeaderButton(
            icon: LucideIcons.folder_open,
            tooltip: root == null
                ? 'Set a workspace folder in settings first'
                : 'Show files',
            onTap: root == null ? null : () => workbench.openFolder(root),
          ),
          _HeaderButton(
            icon: LucideIcons.terminal,
            tooltip: 'New terminal',
            onTap: workbench.openTerminal,
          ),
          _HeaderButton(
            icon: LucideIcons.git_branch,
            tooltip: 'Source control',
            onTap: workbench.openGit,
          ),
          _HeaderButton(
            icon: LucideIcons.network,
            tooltip: 'Sub-agents',
            onTap: workbench.openSubagents,
          ),
          _HeaderButton(
            icon: LucideIcons.x,
            tooltip: 'Close panel',
            onTap: onClose,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatefulWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// Null disables it — the tooltip then says why, which a hidden button cannot.
  final VoidCallback? onTap;

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final enabled = widget.onTap != null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _hovered && enabled
                  ? color.interactiveBgHover
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: 13,
                color: _tint(color, enabled),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _tint(DswAlias color, bool enabled) {
    if (!enabled) return color.labelCaption;
    return _hovered ? color.labelPrimary : color.labelTertiary;
  }
}
