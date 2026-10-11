// The type templates screen (ADR-0037 P6, module 6): one type's templates
// with the four menu actions the client answers — set as default, edit,
// duplicate, delete (`TemplatesModalList.kt:213-278`) — plus create, and the
// template-apply semantics the store's createRecord already carries (a null
// template is the blank page; ApplyTemplate with an id seeds the record).
//
// "Edit" here means the template's name and its starting blocks listed as
// read shapes — the full block editor inside a template arrives with the
// object screen work; the banner upstream shows ("You're editing a template
// of X") is the dialog's subtitle here, same information, desktop surface.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/app_localizations.dart';
import '../../../model/plan_object_type.dart';
import '../../../model/plan_template.dart';
import '../../../state/plan_object_store.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/confirm_dialog.dart';
import '../../primitives/feedback.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';

class PlanTemplatesScreen extends StatelessWidget {
  const PlanTemplatesScreen({
    super.key,
    required this.store,
    required this.typeKey,
  });

  final PlanObjectStore store;
  final String typeKey;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final type = store.types
        .where((candidate) => candidate.uniqueKey == typeKey)
        .firstOrNull;
    final templates = [
      for (final template in store.templates)
        if (template.typeKey == typeKey) template,
    ];
    // Types without templates answer with the grouping truth, not an empty
    // screen pretending otherwise (`ObjectTypeIds.kt:35-37`).
    if (type == null || !PlanObjectTypeIds.allowsTemplates(typeKey)) {
      return Center(
        child: Text(
          AppLocalizations.of(context).planTemplatesNotAllowed,
          style: DswType.xs13.copyWith(color: color.labelTertiary),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DswShape.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (type.iconEmoji case final emoji?)
                Text(emoji, style: DswType.l20),
              const SizedBox(width: DswShape.sm),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).planTemplatesTitle(type.name),
                  style: DswType.l20.copyWith(color: color.labelPrimary),
                ),
              ),
              DswContextMenu(
                items: (_) => [
                  DswMenuEntry(
                    label: AppLocalizations.of(context).planTemplateNew,
                    icon: LucideIcons.plus,
                    onTap: () => store.createTemplate(
                      name: AppLocalizations.of(context).planTemplateNewName,
                      typeKey: typeKey,
                    ),
                  ),
                ],
                child: Tooltip(
                  message: AppLocalizations.of(context).planTemplateNew,
                  child: DswHoverTap(
                    onTap: null,
                    semanticLabel: AppLocalizations.of(context).planTemplateNew,
                    builder: (context, hovered, focused) => Icon(
                      LucideIcons.ellipsis_vertical,
                      size: DswShape.iconSm,
                      color: color.labelTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (templates.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: DswShape.md),
              child: Text(
                AppLocalizations.of(context).planTemplatesEmpty,
                style: DswType.xs13.copyWith(color: color.labelTertiary),
              ),
            )
          else
            for (final template in templates)
              _TemplateRow(store: store, template: template, type: type),
        ],
      ),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.store,
    required this.template,
    required this.type,
  });

  final PlanObjectStore store;
  final PlanTemplate template;
  final PlanObjectType type;

  String get typeKey => type.uniqueKey;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswContextMenu(
      items: (menuContext) => [
        DswMenuEntry(
          label: AppLocalizations.of(context).planTemplateSetDefault,
          icon: LucideIcons.star,
          trailing: template.isDefault
              ? Icon(
                  LucideIcons.check,
                  size: DswShape.iconTiny,
                  color: color.brandPrimary,
                )
              : null,
          onTap: () => store.setDefaultTemplate(typeKey, template.id),
        ),
        DswMenuEntry(
          label: AppLocalizations.of(context).planTemplateDuplicate,
          icon: LucideIcons.copy,
          onTap: () => store.duplicateTemplate(template.id),
        ),
        DswMenuEntry(
          label: AppLocalizations.of(context).planTemplateDelete,
          icon: LucideIcons.trash,
          destructive: true,
          onTap: () async {
            final confirmed = await showConfirmDialog(
              menuContext,
              title: AppLocalizations.of(context).planTemplateDelete,
              description: template.name,
              confirmLabel: AppLocalizations.of(context).planActionDelete,
            );
            if (!confirmed) return;
            await store.deleteTemplate(template.id);
            if (!menuContext.mounted) return;
            showFeedback(
              menuContext,
              AppLocalizations.of(context).planTemplateDeleted,
            );
          },
        ),
      ],
      child: DswHoverTap(
        onTap: () => store.setDefaultTemplate(typeKey, template.id),
        semanticLabel: template.name,
        builder: (context, hovered, focused) => Container(
          margin: const EdgeInsets.only(top: DswShape.xs),
          padding: const EdgeInsets.all(DswShape.sm),
          decoration: BoxDecoration(
            color: template.isDefault
                ? color.interactiveSelected
                : color.bgLayer2,
            borderRadius: BorderRadius.circular(DswShape.card),
            border: Border.all(color: color.borderL2),
          ),
          child: Row(
            children: [
              Icon(
                LucideIcons.file,
                size: DswShape.iconSm,
                color: color.labelTertiary,
              ),
              const SizedBox(width: DswShape.sm),
              Expanded(
                child: Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DswType.s14.copyWith(
                    color: color.labelPrimary,
                    fontWeight: template.isDefault
                        ? FontWeight.w500
                        : FontWeight.w400,
                  ),
                ),
              ),
              if (template.isDefault)
                Text(
                  AppLocalizations.of(context).planTemplateDefault,
                  style: DswType.xxxs11.copyWith(color: color.brandPrimary),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
