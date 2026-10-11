// The bin, expanded (ADR-0037). Upstream has no bin browsing screen — the Bin
// widget's tap opens a subscription-backed "collection-style" list
// (`launchCollections(Subscription.Bin)`), which is the shape this screen
// takes: every binned record, each row restorable or permanently forgettable,
// plus Empty Bin. The stage pipeline excludes binned records from every view,
// so this screen reads `store.binRecords` directly — the one surface the bin
// answers to.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/plan_object_type.dart';
import '../../../model/plan_struct.dart';
import '../../../state/plan_object_store.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/confirm_dialog.dart';
import '../../primitives/feedback.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';

class PlanBinScreen extends StatelessWidget {
  const PlanBinScreen({super.key, required this.store});

  final PlanObjectStore store;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final records = store.binRecords;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(DswShape.md),
          child: Row(
            children: [
              Icon(
                LucideIcons.trash,
                size: DswShape.iconMd,
                color: color.labelTertiary,
              ),
              const SizedBox(width: DswShape.sm),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).planBinTitle,
                  style: DswType.l20.copyWith(color: color.labelPrimary),
                ),
              ),
              Text(
                AppLocalizations.of(context).planRecordCount,
                style: DswType.xxxs11.copyWith(color: color.labelTertiary),
              ),
              const SizedBox(width: DswShape.xs),
              Text(
                '${records.length}',
                style: DswType.xxxs11.copyWith(color: color.labelTertiary),
              ),
              DswContextMenu(
                items: (menuContext) => [
                  DswMenuEntry(
                    label: AppLocalizations.of(context).planWidgetEmptyBin,
                    icon: LucideIcons.trash,
                    destructive: true,
                    onTap: records.isEmpty
                        ? null
                        : () async {
                            final confirmed = await showConfirmDialog(
                              menuContext,
                              title: AppLocalizations.of(
                                context,
                              ).planWidgetEmptyBin,
                              description: AppLocalizations.of(
                                context,
                              ).planBinEmptyBody,
                              confirmLabel: AppLocalizations.of(
                                context,
                              ).planActionDelete,
                            );
                            if (!confirmed) return;
                            await store.emptyBin();
                            if (!menuContext.mounted) return;
                            showFeedback(
                              menuContext,
                              AppLocalizations.of(context).planWidgetBinEmptied,
                            );
                          },
                  ),
                ],
                child: Tooltip(
                  message: AppLocalizations.of(context).planBinActions,
                  child: DswHoverTap(
                    onTap: null,
                    semanticLabel: AppLocalizations.of(context).planBinActions,
                    builder: (context, hovered, focused) => Padding(
                      padding: const EdgeInsets.only(left: DswShape.sm),
                      child: Icon(
                        LucideIcons.ellipsis_vertical,
                        size: DswShape.iconSm,
                        color: color.labelTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(DswShape.lg),
                  child: Text(
                    AppLocalizations.of(context).planBinEmpty,
                    style: DswType.xs13.copyWith(color: color.labelTertiary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: DswShape.md),
                  children: [
                    for (final record in records)
                      _BinRow(store: store, record: record),
                  ],
                ),
        ),
      ],
    );
  }
}

class _BinRow extends StatelessWidget {
  const _BinRow({required this.store, required this.record});

  final PlanObjectStore store;
  final PlanObject record;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswContextMenu(
      items: (menuContext) => [
        DswMenuEntry(
          label: AppLocalizations.of(context).planRestore,
          icon: LucideIcons.undo_2,
          onTap: () async {
            await store.restoreRecords([record.id]);
            if (!menuContext.mounted) return;
            showFeedback(
              menuContext,
              AppLocalizations.of(context).planRestored,
            );
          },
        ),
      ],
      child: DswHoverTap(
        onTap: null,
        semanticLabel: record.name,
        builder: (context, hovered, focused) => Container(
          height:
              DswShape.rowSession * MediaQuery.textScalerOf(context).scale(1),
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
          decoration: BoxDecoration(
            color: hovered ? color.interactiveBgHover : null,
            borderRadius: BorderRadius.circular(DswShape.inner),
          ),
          child: Row(
            children: [
              Icon(
                record.typeKey == PlanObjectTypeIds.task
                    ? LucideIcons.circle_check
                    : LucideIcons.circle,
                size: DswShape.iconTiny,
                color: color.labelTertiary,
              ),
              const SizedBox(width: DswShape.sm),
              Expanded(
                child: Text(
                  record.name.isEmpty
                      ? AppLocalizations.of(context).planUntitled
                      : record.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DswType.xs13.copyWith(
                    color: color.labelSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              Text(
                AppLocalizations.of(context).planBinned,
                style: DswType.xxxs11.copyWith(color: color.labelTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
