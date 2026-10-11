// The hero's workspace picker — dsh's `conversation.hero.workspace` seat.
//
// `ui-workspace/index.ts:107-131` mounts a WorkspacePicker on the empty
// conversation: the workspace list as a menu, "Add workspace" as the footer,
// and a directory flow behind both. This port takes the same seat with the
// pieces this app has — the recent list and the platform picker — through a
// scope rather than a global service, the same seam SubagentHost uses.
//
// What the source has and this does not:
//
//   * Per-workspace sessions. A dsh workspace owns its conversations; here a
//     session is a transcript with no folder of its own, so the picker adopts
//     a folder for the whole app and nothing is keyed by it.
//   * Create/rename/archive. The picker adopts existing folders; a folder
//     that wants creating gets created in the platform dialog.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadOption;

import '../../l10n/app_localizations.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/capsule_button.dart';
import '../primitives/menu.dart';

/// The seam the hero picker reads: the settings document, the recents it
/// offers, and the way out to the platform's directory dialog.
///
/// Same reason as [SubagentHost] in subagent_tab.dart: the hero is built deep
/// under the frame and cannot capture app-scoped objects without pinning
/// whichever instance built first.
class HeroWorkspaceScope extends InheritedWidget {
  const HeroWorkspaceScope({
    super.key,
    required this.workspaceRoot,
    required this.recent,
    required this.onPick,
    this.onAdopt,
    required super.child,
  });

  /// The adopted folder, or null when no workspace is set.
  final String? workspaceRoot;

  /// The recent folders to offer, most recent first.
  final List<String> recent;

  /// Opens the platform picker and persists the adoption — a picked folder is
  /// applied immediately here, unlike in the settings panel where the whole
  /// document waits for Save: the hero has no form to commit.
  final Future<void> Function() onPick;

  /// Adopts [path] from the recent list — same immediacy as [onPick].
  final Future<void> Function(String path)? onAdopt;

  static HeroWorkspaceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HeroWorkspaceScope>();

  @override
  bool updateShouldNotify(HeroWorkspaceScope oldWidget) =>
      workspaceRoot != oldWidget.workspaceRoot ||
      recent.length != oldWidget.recent.length;
}

/// The hero's one control: the workspace as a capsule button, or the call to
/// pick one when there is nothing yet.
///
/// Hidden once a workspace exists only in the menu sense — the capsule stays,
/// showing the folder name, because the hero is also where a user switches
/// projects between sessions. A scope that is absent hides the picker
/// entirely: the host is the app's to mount, and a missing one means the app
/// chose not to offer the seat.
class HeroWorkspacePicker extends StatelessWidget {
  const HeroWorkspacePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = HeroWorkspaceScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final color = context.dsw;

    // Nothing adopted and nothing to offer: the call to pick is the whole row.
    if (scope.workspaceRoot == null && scope.recent.isEmpty) {
      return CapsuleButton(
        label: AppLocalizations.of(context).chooseWorkspaceFolder,
        icon: LucideIcons.folder_open,
        onTap: scope.onPick,
      );
    }

    // The chip is a picker, so shad owns the popup, the keyboard (Enter/Space
    // opens, Escape closes) and the selected row's trailing check. What it does
    // not own is the hover wash — `ShadSelect`'s trigger has none — so
    // [DswSelect] reports the pointer and the chip paints as before.
    return DswSelect<String>(
      value: scope.workspaceRoot,
      onChanged: (path) {
        if (path != null) scope.onAdopt?.call(path);
      },
      popupMinWidth: 260,
      trigger: (context, value, hovered) => AnimatedContainer(
        duration: DswMotion.respecting(context, DswMotion.fast),
        curve: DswMotion.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hovered ? color.interactiveBgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(DswShape.control),
          border: Border.all(color: hovered ? color.borderL2 : color.borderL1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.folder_open,
              size: DswShape.iconSm,
              color: color.labelSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                value == null
                    ? AppLocalizations.of(context).chooseWorkspaceFolder
                    : value.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.xs13.copyWith(color: color.labelPrimary),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.chevron_down,
              size: DswShape.iconSm,
              color: color.labelTertiary,
            ),
          ],
        ),
      ),
      // The recents as options, "Choose…" as the footer — the source's
      // menu-plus-footer shape.
      options: (context, close) => [
        for (final path in scope.recent)
          ShadOption<String>(value: path, child: _row(context, path)),
        const DswMenuDivider(),
        // A free row rather than an option: it picks nothing, so it has to close
        // the popup itself.
        DswMenuRow(
          entry: DswMenuEntry(
            icon: LucideIcons.plus,
            label: AppLocalizations.of(context).chooseAFolder,
            onTap: () {
              close();
              scope.onPick();
            },
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String path) {
    final color = context.dsw;
    return Row(
      children: [
        Icon(
          LucideIcons.folder,
          size: DswShape.iconSm,
          color: color.labelSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DswType.xs13.copyWith(color: color.labelSecondary),
          ),
        ),
      ],
    );
  }
}
