// A conversation's verbs, answered once.
//
// Two surfaces open this menu now: the sidebar's session row and the centre
// column's header strip. Rows spelled twice are two rows that rot separately —
// the reason this repo already keeps one `revealInFilesOrReport`, one
// `showFeedback` and one `SessionIndex` (ADR-0041, ADR-0020, ADR-0039).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadButton, ShadDialog, ShadInput, showShadDialog;

import '../l10n/app_localizations.dart';
import '../model/conversation.dart';
import '../state/session_index.dart';
import '../theme/dsw_shape.dart';
import '../theme/dsw_typography.dart';
import 'primitives/confirm_dialog.dart';
import 'primitives/feedback.dart';
import 'primitives/menu.dart';
import 'primitives/reveal.dart';

/// The rows of one session's menu.
///
/// [withDelete] is the list's door: the header sits above the transcript you are
/// reading, and a menu that destroys it from up there is a foot-gun the sidebar
/// does not have. [onOpenSettings] is the header's door, optional because a host
/// without a settings surface gets no row rather than a dead one.
List<DswMenuEntry> sessionMenuEntries(
  BuildContext context, {
  required SessionSummary session,
  required SessionIndex sessions,
  bool withDelete = false,
  VoidCallback? onOpenSettings,
}) => [
  DswMenuEntry(
    label: session.pinnedAt == null
        ? AppLocalizations.of(context).pinSession
        : AppLocalizations.of(context).unpinSession,
    icon: LucideIcons.pin,
    onTap: () {
      sessions.setPinned(session.id, session.pinnedAt == null);
      warnIfHistoryNotSaved(context, sessions);
    },
  ),
  DswMenuEntry(
    label: AppLocalizations.of(context).renameSession,
    icon: LucideIcons.pencil,
    onTap: () => renameSession(context, sessions, session),
  ),
  const DswMenuEntry.divider(),
  DswMenuEntry(
    label: AppLocalizations.of(context).copySessionId,
    icon: LucideIcons.copy,
    onTap: () => Clipboard.setData(ClipboardData(text: session.id)),
  ),
  if (session.workspaceRoot != null) ...[
    DswMenuEntry(
      label: AppLocalizations.of(context).copyWorkspacePath,
      icon: LucideIcons.copy,
      onTap: () =>
          Clipboard.setData(ClipboardData(text: session.workspaceRoot!)),
    ),
    // Upstream puts reveal on the task row as well as the project row
    // (`useTaskListItemContextActions.ts:168-175`): the question being asked
    // is usually "where did this conversation's files go", which is about the
    // conversation, not about a folder header.
    DswMenuEntry(
      label: AppLocalizations.of(context).revealInFiles,
      icon: LucideIcons.external_link,
      onTap: () => revealInFilesOrReport(context, session.workspaceRoot!),
    ),
  ],
  if (onOpenSettings != null)
    DswMenuEntry(
      label: AppLocalizations.of(context).settings,
      icon: LucideIcons.settings,
      onTap: onOpenSettings,
    ),
  if (withDelete)
    DswMenuEntry(
      label: AppLocalizations.of(context).deleteSession,
      icon: LucideIcons.trash,
      destructive: true,
      onTap: () => deleteSession(context, sessions, session),
    ),
];

/// Renaming is an override on the sidecar, not a rewrite of the genkit session:
/// the title the list shows is `override ?? derived`, resolved in `SessionIndex`.
Future<void> renameSession(
  BuildContext context,
  SessionIndex sessions,
  SessionSummary session,
) async {
  final next = await _promptForText(
    context,
    title: AppLocalizations.of(context).renameSessionTitle,
    initial: session.title ?? '',
  );
  if (next == null || next.isEmpty) return;
  sessions.rename(session.id, next);
  if (!context.mounted) return;
  warnIfHistoryNotSaved(context, sessions);
}

/// Deletion is a tombstone, never an `rm`: the session file outlives the row so
/// that a restore of a backup brings it back (ADR-0039).
Future<void> deleteSession(
  BuildContext context,
  SessionIndex sessions,
  SessionSummary session,
) async {
  final confirmed = await showConfirmDialog(
    context,
    title: AppLocalizations.of(context).deleteSessionTitle,
    description: AppLocalizations.of(context).deleteSessionBody,
    confirmLabel: AppLocalizations.of(context).deleteSession,
  );
  if (!confirmed || !context.mounted) return;
  sessions.remove(session.id);
  if (warnIfHistoryNotSaved(context, sessions)) return;
  if (!context.mounted) return;
  showFeedback(context, AppLocalizations.of(context).sessionDeleted);
}

/// The sidecar write is the one thing these rows can lose without the screen
/// showing it: the list answers from memory either way, so the only honest
/// surface is the action that just failed. Returns whether it failed.
bool warnIfHistoryNotSaved(BuildContext context, SessionIndex sessions) {
  if (sessions.metadataError == null) return false;
  showFeedback(
    context,
    AppLocalizations.of(context).historyNotSaved,
    destructive: true,
  );
  return true;
}

Future<String?> _promptForText(
  BuildContext context, {
  required String title,
  required String initial,
}) async {
  final controller = TextEditingController(text: initial);
  final step = MediaQuery.textScalerOf(context).scale(1);
  final result = await showShadDialog<String>(
    context: context,
    builder: (context) => ShadDialog(
      radius: BorderRadius.circular(DswShape.float),
      title: Text(title, style: DswType.sStrong14),
      actions: [
        ShadButton.outline(
          height: 24 * step,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).planCancel),
        ),
        ShadButton(
          height: 24 * step,
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(AppLocalizations.of(context).renameSession),
        ),
      ],
      child: ShadInput(
        controller: controller,
        style: DswType.s14,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
    ),
  );
  controller.dispose();
  return result;
}
