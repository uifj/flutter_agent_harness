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

import '../../l10n/locales.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/capsule_button.dart';

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
class HeroWorkspacePicker extends StatefulWidget {
  const HeroWorkspacePicker({super.key});

  @override
  State<HeroWorkspacePicker> createState() => _HeroWorkspacePickerState();
}

class _HeroWorkspacePickerState extends State<HeroWorkspacePicker> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final scope = HeroWorkspaceScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final color = context.dsw;

    // Nothing adopted and nothing to offer: the call to pick is the whole row.
    if (scope.workspaceRoot == null && scope.recent.isEmpty) {
      return CapsuleButton(
        label: context.tr('chooseWorkspaceFolder'),
        icon: LucideIcons.folder_open,
        onTap: scope.onPick,
      );
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _openMenu(context, scope),
        child: AnimatedContainer(
          duration: DswMotion.respecting(context, DswMotion.fast),
          curve: DswMotion.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? color.interactiveBgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? color.borderL2 : color.borderL1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.folder_open,
                size: 14,
                color: color.labelSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  scope.workspaceRoot == null
                      ? context.tr('chooseWorkspaceFolder')
                      : scope.workspaceRoot!.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DswType.xs13.copyWith(color: color.labelPrimary),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevron_down,
                size: 13,
                color: color.labelTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The recents as a menu: adopt on select, "Choose…" as the footer — the
  /// source's menu-plus-footer shape.
  Future<void> _openMenu(BuildContext context, HeroWorkspaceScope scope) async {
    final color = context.dsw;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final button = context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final choice = await showMenu<String>(
      context: context,
      position: position,
      constraints: const BoxConstraints(minWidth: 260),
      color: color.menu,
      items: [
        for (final path in scope.recent)
          PopupMenuItem(
            value: path,
            child: _row(context, path, selected: path == scope.workspaceRoot),
          ),
        const PopupMenuDivider(),
        // The footer row: the platform picker, in the menu.
        PopupMenuItem(
          value: '\u0000pick',
          child: Row(
            children: [
              Icon(
                LucideIcons.plus,
                size: 13,
                color: color.labelSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                context.tr('chooseAFolder'),
                style: DswType.xs13.copyWith(color: color.labelSecondary),
              ),
            ],
          ),
        ),
      ],
    );
    if (choice == null) return;
    if (choice == '\u0000pick') {
      await scope.onPick();
      return;
    }
    await scope.onAdopt?.call(choice);
  }

  Widget _row(BuildContext context, String path, {bool selected = false}) {
    final color = context.dsw;
    return Row(
      children: [
        Icon(
          LucideIcons.folder,
          size: 13,
          color: selected ? color.labelPrimary : color.labelSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DswType.xs13.copyWith(
              color: selected ? color.labelPrimary : color.labelSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
