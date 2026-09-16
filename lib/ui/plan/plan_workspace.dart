// The 企划 (plan) workspace — the center pane's plan-mode face (ADR-0007).
//
// An Obsidian-style vault over the CURRENT workspace root: a tree of every
// `*.md` file on the left, and a markdown editor/preview for the selected note
// on the right. The tree lives HERE, in the center pane, rather than in the
// sidebar as starkins does it — the selection has to be shared between the tree
// and the editor, and keeping both under one widget makes that state local
// instead of threading it through the sidebar's collapse machinery.
//
// The vault is whatever folder the agent workspace already uses (the same
// `workspaceRoot` the file tools are confined to) — there is no separate vault
// picker, no second permission, and no way for the two to disagree.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../l10n/locales.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';

/// The plan workspace center pane. [workspaceRoot] is the current agent
/// workspace; null means there is no vault to read yet (the hero picker's
/// empty state is the agent-mode answer, here the guidance points back to it).
class PlanWorkspace extends StatelessWidget {
  const PlanWorkspace({super.key, this.workspaceRoot});

  final String? workspaceRoot;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return ColoredBox(
      color: color.bgBase,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.book_open, size: 34, color: color.labelTertiary),
            const SizedBox(height: 10),
            Text(
              workspaceRoot == null
                  ? context.tr('planNoWorkspace')
                  : context.tr('planNoNoteSelected'),
              style: DswType.base16.copyWith(color: color.labelSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
