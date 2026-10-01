// The library screens' shared creation flow (ADR-0037 P6, module 2): one
// dialog answers "new set / new collection / a set of this type", and the
// store's createCollection seeds the starter grid. Set and Collection skip
// the template selector upstream (`ObjectTypeExtensions.kt:107-130`), which
// is why this dialog asks for a name and nothing else.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadButton, ShadDialog, ShadInput, showShadDialog;

import '../../../l10n/locales.dart';
import '../../../model/plan_dataview.dart';
import '../../../model/plan_object_type.dart';
import '../../../state/plan_object_store.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_shad_bridge.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/feedback.dart';
import '../../primitives/tappable.dart';

/// Opens the new-set/collection dialog. Returns the created collection's id,
/// or null when the user dismissed.
Future<String?> showPlanCreateCollectionDialog(
  BuildContext context,
  PlanObjectStore store, {

  /// Pre-selected kind — the "create set of this type" entry locks it.
  PlanCollectionKind? kind,
  PlanObjectType? sourceType,
}) async {
  return showShadDialog<String>(
    context: context,
    builder: (dialogContext) => _CreateCollectionDialog(
      store: store,
      kind: kind,
      sourceType: sourceType,
    ),
  );
}

class _CreateCollectionDialog extends StatefulWidget {
  const _CreateCollectionDialog({
    required this.store,
    this.kind,
    this.sourceType,
  });

  final PlanObjectStore store;
  final PlanCollectionKind? kind;
  final PlanObjectType? sourceType;

  @override
  State<_CreateCollectionDialog> createState() =>
      _CreateCollectionDialogState();
}

class _CreateCollectionDialogState extends State<_CreateCollectionDialog> {
  late PlanCollectionKind _kind = widget.kind ?? PlanCollectionKind.collection;
  PlanObjectType? _sourceType;
  final _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sourceType = widget.sourceType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final collection = await widget.store.createCollection(
      kind: _kind,
      name: name,
      sourceTypeKey: _kind == PlanCollectionKind.set
          ? _sourceType?.uniqueKey
          : null,
      iconEmoji: _sourceType?.iconEmoji,
      seedRelations: _kind == PlanCollectionKind.set
          ? [
              for (final key
                  in _sourceType?.recommendedRelationKeys ?? const [])
                if (widget.store.relationByKey(key) != null)
                  widget.store.relationByKey(key)!,
            ]
          : const [],
    );
    if (!mounted) return;
    Navigator.of(context).pop(collection.id);
    showFeedback(context, context.tr('planCollectionCreated'));
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final types = [
      for (final type in widget.store.types)
        if (!type.isArchived && !type.isDataSet) type,
    ];
    return ShadDialog(
      radius: BorderRadius.circular(DswShape.float),
      title: Text(context.tr('planNewCollection'), style: DswType.sStrong14),
      actions: [
        ShadButton.outline(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('planCancel')),
        ),
        ShadButton(
          onPressed: _nameController.text.trim().isEmpty ? null : _create,
          child: Text(context.tr('planSave')),
        ),
      ],
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: DswShape.xs,
              children: [
                for (final (candidate, label) in [
                  (PlanCollectionKind.collection, 'planKindCollection'),
                  (PlanCollectionKind.set, 'planKindSet'),
                ])
                  Tooltip(
                    message: context.tr(label),
                    child: DswHoverTap(
                      onTap: widget.kind == null
                          ? () => setState(() => _kind = candidate)
                          : null,
                      semanticLabel: context.tr(label),
                      builder: (context, hovered, focused) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DswShape.sm,
                          vertical: DswShape.xs,
                        ),
                        decoration: BoxDecoration(
                          color: _kind == candidate
                              ? color.interactiveSelected
                              : hovered
                              ? color.interactiveBgHover
                              : color.bgLayer2,
                          borderRadius: BorderRadius.circular(DswShape.inner),
                          border: Border.all(color: color.borderL2),
                        ),
                        child: Text(
                          context.tr(label),
                          style: DswType.xs13.copyWith(
                            color: color.labelPrimary,
                            fontWeight: _kind == candidate
                                ? FontWeight.w500
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: DswShape.sm),
            dswEnsureShadTheme(
              context,
              ShadInput(
                controller: _nameController,
                autofocus: true,
                placeholder: dswInputHint(
                  context.tr('planUntitled'),
                  style: DswType.xs13.copyWith(color: color.labelTertiary),
                ),
                style: DswType.s14,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _create(),
              ),
            ),
            if (_kind == PlanCollectionKind.set) ...[
              const SizedBox(height: DswShape.sm),
              Text(
                context.tr('planKindSetSource'),
                style: DswType.xxsStrong12.copyWith(color: color.labelTertiary),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final type in types)
                        DswHoverTap(
                          onTap: () => setState(() => _sourceType = type),
                          semanticLabel: type.name,
                          builder: (context, hovered, focused) => Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: DswShape.xs,
                              vertical: DswShape.xs,
                            ),
                            child: Row(
                              children: [
                                if (type.iconEmoji case final emoji?)
                                  Text(emoji, style: DswType.xs13)
                                else
                                  Icon(
                                    LucideIcons.circle,
                                    size: DswShape.iconTiny,
                                    color: color.labelTertiary,
                                  ),
                                const SizedBox(width: DswShape.xs),
                                Expanded(
                                  child: Text(
                                    type.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DswType.xs13.copyWith(
                                      color: color.labelPrimary,
                                      fontWeight: _sourceType?.id == type.id
                                          ? FontWeight.w500
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (_sourceType?.id == type.id)
                                  Icon(
                                    LucideIcons.check,
                                    size: DswShape.iconTiny,
                                    color: color.brandPrimary,
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
