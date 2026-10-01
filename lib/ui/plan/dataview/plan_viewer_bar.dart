// The viewer tab bar (ADR-0037 §1: view management). Upstream's strip gives
// seven actions on a view — rename, layout, relations, filters, sorts,
// duplicate, delete — plus reorder by drag and a "+" that offers every kind
// (`ViewersWidgetUi.kt:30-45`, `ViewerEditWidgetUi.kt:30-40`).
//
// The two kinds the client does not draw stay in the "+" menu. Hiding them
// would quietly make the "not available on mobile yet" card unreachable, and
// that card is the honest answer, not a bug.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/locales.dart';
import '../../../model/plan_dataview.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/icon_button.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';
import 'plan_viewers.dart';

/// The per-view menu's items, named after upstream's `ViewEditAction`.
enum PlanViewerMenuAction { rename, duplicate, delete, moveLeft, moveRight }

IconData planViewerIcon(PlanViewerKind kind) => switch (kind) {
  PlanViewerKind.grid => LucideIcons.table,
  PlanViewerKind.list => LucideIcons.list,
  PlanViewerKind.gallery => LucideIcons.image,
  PlanViewerKind.board => LucideIcons.kanban,
  PlanViewerKind.calendar => LucideIcons.calendar_x,
  PlanViewerKind.graph => LucideIcons.network,
};

class PlanViewerBar extends StatelessWidget {
  const PlanViewerBar({
    super.key,
    required this.viewers,
    required this.activeId,
    required this.canManage,
    required this.onSelect,
    required this.onAdd,
    required this.onMenu,
    required this.onOpenSettings,
    required this.onToggleHeader,
  });

  final List<PlanViewer> viewers;
  final String? activeId;

  /// `DataViewRestriction.views` — a read-only space cannot manage views, so
  /// the strip loses the "+", the menus and the settings row.
  final bool canManage;
  final void Function(String viewerId) onSelect;
  final void Function(PlanViewerKind kind) onAdd;
  final void Function(PlanViewerMenuAction action, String viewerId) onMenu;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleHeader;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final seat = planRowSeat(context);

    List<DswMenuEntry> menuFor(String viewerId) => [
      DswMenuEntry(
        label: context.tr('planViewRename'),
        icon: LucideIcons.pencil,
        onTap: () => onMenu(PlanViewerMenuAction.rename, viewerId),
      ),
      DswMenuEntry(
        label: context.tr('planViewDuplicate'),
        icon: LucideIcons.copy,
        onTap: () => onMenu(PlanViewerMenuAction.duplicate, viewerId),
      ),
      DswMenuEntry(
        label: context.tr('planViewMoveLeft'),
        icon: LucideIcons.chevron_left,
        onTap: () => onMenu(PlanViewerMenuAction.moveLeft, viewerId),
      ),
      DswMenuEntry(
        label: context.tr('planViewMoveRight'),
        icon: LucideIcons.chevron_right,
        onTap: () => onMenu(PlanViewerMenuAction.moveRight, viewerId),
      ),
      const DswMenuEntry.divider(),
      DswMenuEntry(
        label: context.tr('planViewDelete'),
        icon: LucideIcons.x,
        destructive: true,
        onTap: () => onMenu(PlanViewerMenuAction.delete, viewerId),
      ),
    ];

    Widget tab(PlanViewer viewer) {
      final active = viewer.id == activeId;
      final label = Text(
        viewer.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DswType.xs13.copyWith(
          color: active ? color.labelPrimary : color.labelSecondary,
          fontWeight: active ? FontWeight.w500 : FontWeight.w400,
        ),
      );
      return Padding(
        padding: const EdgeInsets.only(right: DswShape.xs),
        child: DswContextMenu(
          items: canManage
              ? (context) => menuFor(viewer.id)
              : (context) => const [],
          child: DswHoverTap(
            onTap: () => onSelect(viewer.id),
            toggled: active,
            semanticLabel: viewer.name,
            builder: (context, hovered, focused) => Container(
              height: seat,
              padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
              decoration: BoxDecoration(
                color: active
                    ? color.interactiveSelected
                    : hovered
                    ? color.interactiveBgHover
                    : null,
                borderRadius: BorderRadius.circular(DswShape.inner),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    planViewerIcon(viewer.kind),
                    size: DswShape.iconTiny,
                    color: active ? color.labelPrimary : color.labelTertiary,
                  ),
                  const SizedBox(width: DswShape.xs),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 160),
                    child: label,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color.borderL2, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: DswShape.sm,
                vertical: DswShape.xs,
              ),
              child: Row(children: [for (final viewer in viewers) tab(viewer)]),
            ),
          ),
          DswMenu(
            label: context.tr('planAllViews'),
            trigger: (context) => Icon(
              LucideIcons.chevrons_up_down,
              size: DswShape.iconSm,
              color: color.labelTertiary,
            ),
            items: (context) => [
              for (final viewer in viewers)
                DswMenuEntry(
                  label: viewer.name,
                  icon: planViewerIcon(viewer.kind),
                  trailing: viewer.id == activeId
                      ? Icon(
                          LucideIcons.check,
                          size: DswShape.iconTiny,
                          color: color.labelPrimary,
                        )
                      : null,
                  onTap: () => onSelect(viewer.id),
                ),
            ],
          ),
          if (canManage)
            DswMenu(
              label: context.tr('planAddView'),
              trigger: (context) => Icon(
                LucideIcons.plus,
                size: DswShape.iconSm,
                color: color.labelTertiary,
              ),
              items: (context) => [
                for (final kind in PlanViewerKind.values)
                  DswMenuEntry(
                    label: kind.formattedName,
                    icon: planViewerIcon(kind),
                    trailing: kind.renderedByClient
                        ? null
                        : Text(
                            context.tr('planViewSoonTag'),
                            style: DswType.xxxs11.copyWith(
                              color: color.labelTertiary,
                            ),
                          ),
                    onTap: () => onAdd(kind),
                  ),
              ],
            ),
          const SizedBox(width: DswShape.xs),
          DswIconButton(
            icon: LucideIcons.sliders_horizontal,
            tooltip: context.tr('planViewSettings'),
            onTap: onOpenSettings,
            size: DswShape.controlMd,
          ),
          const SizedBox(width: DswShape.xs),
          DswIconButton(
            icon: LucideIcons.panel_top,
            tooltip: context.tr('planToggleHeader'),
            onTap: onToggleHeader,
            size: DswShape.controlMd,
          ),
          const SizedBox(width: DswShape.sm),
        ],
      ),
    );
  }
}
