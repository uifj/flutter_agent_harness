// The four sheets a viewer is configured with, plus the cell editor
// (ADR-0037 §1, §5). All of them are `DswSheetPopover` content, so the popover
// skin is said once.
//
// The vocabularies are the model's, not invented here: 18 filter conditions
// with the 15 date shortcuts (`Block.kt:366-377`), three sort directions plus
// the empty-value placement (`:335-345`), three column widths (`:303`), five
// date formats (`:239`). Two upstream gates are reproduced rather than
// smoothed over: nested/advanced filter rows are desktop-only, so the sheet
// says the row exists and is not applied instead of hiding it; and `CUSTOM`
// order is never offered in the sort list, only stored.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadButton, ShadInput;

import '../../../l10n/locales.dart';
import '../../../model/plan_dataview.dart';
import '../../../model/plan_filter_engine.dart';
import '../../../model/plan_object_type.dart';
import '../../../model/plan_relation.dart';
import '../../../model/plan_struct.dart';
import '../../../model/plan_template.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_shad_bridge.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/icon_button.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';
import 'plan_cell_value.dart';

/// The trigger row every sheet shares: an icon, a label, a count of what is
/// configured, so a closed sheet still says whether anything is set.
class PlanSheetTrigger extends StatelessWidget {
  const PlanSheetTrigger({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DswShape.sm,
        vertical: DswShape.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DswShape.iconTiny, color: color.labelTertiary),
          const SizedBox(width: DswShape.xs),
          Text(
            count == 0 ? label : '$label · $count',
            style: DswType.xs13.copyWith(color: color.labelSecondary),
          ),
        ],
      ),
    );
  }
}

/// A sheet section title, and the dashed "add" row every list ends with.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(
      top: DswShape.xs,
      bottom: DswShape.xs,
      left: DswShape.xs,
    ),
    child: Text(
      text,
      style: DswType.xxxsStrong11.copyWith(color: context.dsw.labelTertiary),
    ),
  );
}

class _Row {
  const _Row({
    required this.label,
    this.trailing,
    this.onTap,
    this.selected,
    this.key,
  });

  /// Lets a test (and a keyboard) name one option row instead of "the last
  /// widget that happens to read `Shipped`".
  final Key? key;

  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool? selected;
}

class _Rows extends StatelessWidget {
  const _Rows({required this.rows});

  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows)
          DswHoverTap(
            key: row.key,
            onTap: row.onTap,
            toggled: row.selected ?? false,
            semanticLabel: row.label,
            builder: (context, hovered, focused) => Container(
              height:
                  DswShape.rowMenu * MediaQuery.textScalerOf(context).scale(1),
              padding: const EdgeInsets.symmetric(horizontal: DswShape.xs),
              decoration: BoxDecoration(
                color: hovered
                    ? color.interactiveBgHover
                    : (row.selected == true ? color.interactiveSelected : null),
                borderRadius: BorderRadius.circular(DswShape.inner),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DswType.xs13.copyWith(
                        color: color.labelPrimary,
                        fontWeight: row.selected == true
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (row.trailing != null) row.trailing!,
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Sorts: direction and the empty-value placement, in the order they apply.
class PlanSortSheet extends StatelessWidget {
  const PlanSortSheet({
    super.key,
    required this.viewer,
    required this.relations,
    required this.onChanged,
  });

  final PlanViewer viewer;
  final List<PlanRelation> relations;
  final void Function(List<PlanSort> sorts) onChanged;

  static const _label = 'planSortBy';

  void _replace(PlanSort? before, PlanSort after) {
    final next = [
      for (final sort in viewer.sorts)
        if (before != null && sort.relationKey == before.relationKey)
          after
        else
          sort,
    ];
    if (before == null) next.add(after);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionTitle(text: context.tr(_label)),
        for (final sort in viewer.sorts)
          _SortRow(
            key: ValueKey('sort-${sort.relationKey}'),
            sort: sort,
            relation: relations
                .where((relation) => relation.key == sort.relationKey)
                .firstOrNull,
            onDirection: (type) => _replace(
              sort,
              PlanSort(
                relationKey: sort.relationKey,
                type: type,
                emptyPlacement: sort.emptyPlacement,
              ),
            ),
            onPlacement: (placement) => _replace(
              sort,
              PlanSort(
                relationKey: sort.relationKey,
                type: sort.type,
                emptyPlacement: placement,
              ),
            ),
            onRemove: () => onChanged([
              for (final other in viewer.sorts)
                if (other.relationKey != sort.relationKey) other,
            ]),
          ),
        _SectionTitle(text: context.tr('planSortAdd')),
        _Rows(
          rows: [
            for (final relation in relations)
              if (!viewer.sorts.any((sort) => sort.relationKey == relation.key))
                _Row(
                  label: relation.name,
                  onTap: () =>
                      _replace(null, PlanSort(relationKey: relation.key)),
                ),
          ],
        ),
      ],
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({
    super.key,
    required this.sort,
    required this.relation,
    required this.onDirection,
    required this.onPlacement,
    required this.onRemove,
  });

  final PlanSort sort;
  final PlanRelation? relation;
  final void Function(PlanSortType type) onDirection;
  final void Function(PlanSortEmptyPlacement placement) onPlacement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Row(
      children: [
        Expanded(
          child: DswSheetPopover(
            label: context.tr('planSortDirection'),
            minWidth: 180,
            trigger: (context) => SizedBox(
              height:
                  DswShape.rowMenu * MediaQuery.textScalerOf(context).scale(1),
              child: Row(
                children: [
                  Icon(
                    sort.type == PlanSortType.desc
                        ? LucideIcons.arrow_down
                        : LucideIcons.arrow_up,
                    size: DswShape.iconTiny,
                    color: color.labelTertiary,
                  ),
                  const SizedBox(width: DswShape.sm),
                  Expanded(
                    child: Text(
                      relation?.name ?? sort.relationKey,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DswType.xs13.copyWith(color: color.labelPrimary),
                    ),
                  ),
                ],
              ),
            ),
            // CUSTOM is deliberately absent: the sheet offers two directions,
            // the third exists only as the stored manual order.
            content: (context, close) => _Rows(
              rows: [
                _Row(
                  label: PlanSortType.asc.formattedName,
                  selected: sort.type == PlanSortType.asc,
                  onTap: () {
                    close();
                    onDirection(PlanSortType.asc);
                  },
                ),
                _Row(
                  label: PlanSortType.desc.formattedName,
                  selected: sort.type == PlanSortType.desc,
                  onTap: () {
                    close();
                    onDirection(PlanSortType.desc);
                  },
                ),
              ],
            ),
          ),
        ),
        DswSheetPopover(
          label: context.tr('planSortEmpty'),
          minWidth: 160,
          trigger: (context) => Icon(
            LucideIcons.sliders_horizontal,
            size: DswShape.iconTiny,
            color: color.labelTertiary,
          ),
          content: (context, close) => _Rows(
            rows: [
              for (final placement in PlanSortEmptyPlacement.values)
                _Row(
                  label: placement.formattedName,
                  selected: sort.emptyPlacement == placement,
                  onTap: () {
                    close();
                    onPlacement(placement);
                  },
                ),
            ],
          ),
        ),
        DswIconButton(
          icon: LucideIcons.x,
          tooltip: context.tr('planRemove'),
          onTap: onRemove,
          size: DswShape.controlMd,
          iconSize: DswShape.iconTiny,
        ),
      ],
    );
  }
}

/// Filters: condition, operator and value. The 15 date shortcuts are the
/// model's, resolved at read time so "today" stays today.
class PlanFilterSheet extends StatelessWidget {
  const PlanFilterSheet({
    super.key,
    required this.viewer,
    required this.relations,
    required this.onChanged,
  });

  final PlanViewer viewer;
  final List<PlanRelation> relations;
  final void Function(List<PlanFilter> filters) onChanged;

  static String _conditionLabel(
    BuildContext context,
    PlanFilterCondition condition,
  ) => switch (condition) {
    PlanFilterCondition.equal => context.tr('planCondEqual'),
    PlanFilterCondition.notEqual => context.tr('planCondNotEqual'),
    PlanFilterCondition.greater => context.tr('planCondGreater'),
    PlanFilterCondition.greaterOrEqual => context.tr('planCondGreaterOrEqual'),
    PlanFilterCondition.less => context.tr('planCondLess'),
    PlanFilterCondition.lessOrEqual => context.tr('planCondLessOrEqual'),
    PlanFilterCondition.like => context.tr('planCondLike'),
    PlanFilterCondition.notLike => context.tr('planCondNotLike'),
    PlanFilterCondition.inSet => context.tr('planCondIn'),
    PlanFilterCondition.notIn => context.tr('planCondNotIn'),
    PlanFilterCondition.empty => context.tr('planCondEmpty'),
    PlanFilterCondition.notEmpty => context.tr('planCondNotEmpty'),
    PlanFilterCondition.allIn => context.tr('planCondAllIn'),
    PlanFilterCondition.notAllIn => context.tr('planCondNotAllIn'),
    PlanFilterCondition.none => context.tr('planCondNone'),
    PlanFilterCondition.exactIn => context.tr('planCondExactIn'),
    PlanFilterCondition.notExactIn => context.tr('planCondNotExactIn'),
    PlanFilterCondition.exists => context.tr('planCondExists'),
  };

  @override
  Widget build(BuildContext context) {
    final advanced = splitAdvanced(viewer.filters);
    void replace(int index, PlanFilter filter) {
      final next = [...viewer.filters];
      next[index] = filter;
      onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionTitle(text: context.tr('planFilterTitle')),
        for (var index = 0; index < viewer.filters.length; index++)
          _FilterRow(
            key: ValueKey('filter-$index'),
            filter: viewer.filters[index],
            relations: relations,
            conditionLabel: (condition) => _conditionLabel(context, condition),
            onChange: (filter) => replace(index, filter),
            onRemove: () => onChanged([
              for (var other = 0; other < viewer.filters.length; other++)
                if (other != index) viewer.filters[other],
            ]),
          ),
        if (advanced.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: DswShape.xs),
            child: Text(
              context.tr('planFilterNestedUnsupported'),
              style: DswType.xxxs11.copyWith(color: context.dsw.labelTertiary),
            ),
          ),
        _SectionTitle(text: context.tr('planFilterAdd')),
        _Rows(
          rows: [
            for (final relation in relations)
              _Row(
                label: relation.name,
                onTap: () => onChanged([
                  ...viewer.filters,
                  PlanFilter(
                    relationKey: relation.key,
                    condition: PlanFilterCondition.offeredInSheet.first,
                  ),
                ]),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    super.key,
    required this.filter,
    required this.relations,
    required this.conditionLabel,
    required this.onChange,
    required this.onRemove,
  });

  final PlanFilter filter;
  final List<PlanRelation> relations;
  final String Function(PlanFilterCondition condition) conditionLabel;
  final void Function(PlanFilter filter) onChange;
  final VoidCallback onRemove;

  PlanRelation? get relation {
    for (final entry in relations) {
      if (entry.key == filter.relationKey) return entry;
    }
    return null;
  }

  String get valueLabel {
    if (filter.quickDate != null) return filter.quickDate!.name;
    final value = filter.value;
    if (value == null) return '';
    final matched = relation;
    if (matched != null && matched.format.hasOptions) {
      return [
        for (final id
            in value is List ? value.cast<String>() : <String>['$value'])
          matched.optionText(id),
      ].join(', ');
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                relation?.name ?? filter.relationKey,
                style: DswType.xxxsStrong11.copyWith(
                  color: color.labelTertiary,
                ),
              ),
              Row(
                children: [
                  DswSheetPopover(
                    label: context.tr('planFilterCondition'),
                    minWidth: 200,
                    trigger: (context) => Text(
                      conditionLabel(filter.condition),
                      style: DswType.xs13.copyWith(color: color.labelPrimary),
                    ),
                    content: (context, close) => SingleChildScrollView(
                      child: _Rows(
                        rows: [
                          for (final condition
                              in PlanFilterCondition.offeredInSheet)
                            _Row(
                              label: conditionLabel(condition),
                              selected: filter.condition == condition,
                              onTap: () {
                                close();
                                onChange(
                                  PlanFilter(
                                    relationKey: filter.relationKey,
                                    operator: filter.operator,
                                    condition: condition,
                                    value: filter.value,
                                    offset: filter.offset,
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: DswShape.sm),
                  Expanded(
                    child: filter.condition.isValueless
                        ? const SizedBox.shrink()
                        : DswSheetPopover(
                            label: context.tr('planFilterValue'),
                            minWidth: 220,
                            trigger: (context) => Text(
                              valueLabel.isEmpty
                                  ? context.tr('planFilterPickValue')
                                  : valueLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DswType.xs13.copyWith(
                                color: valueLabel.isEmpty
                                    ? color.labelTertiary
                                    : color.labelPrimary,
                              ),
                            ),
                            content: (context, close) => _ValuePicker(
                              relation: relation,
                              multi: filter.condition.isMultiValue,
                              selected: {
                                if (filter.value is List)
                                  for (final id
                                      in (filter.value as List).cast<String>())
                                    id
                                else if (filter.value != null)
                                  '${filter.value}',
                              },
                              quickDates:
                                  relation?.format == PlanRelationFormat.date,
                              onPick: (value) {
                                close();
                                onChange(
                                  PlanFilter(
                                    relationKey: filter.relationKey,
                                    operator: filter.operator,
                                    condition: filter.condition,
                                    value: value,
                                    offset: filter.offset,
                                  ),
                                );
                              },
                              onQuickDate: (quick) {
                                close();
                                onChange(
                                  PlanFilter(
                                    relationKey: filter.relationKey,
                                    operator: filter.operator,
                                    condition: filter.condition,
                                    quickDate: quick,
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
        DswSheetPopover(
          label: context.tr('planFilterOperator'),
          minWidth: 140,
          trigger: (context) => Text(
            filter.operator.name,
            style: DswType.xxxs11.copyWith(color: color.labelTertiary),
          ),
          content: (context, close) => _Rows(
            rows: [
              for (final operator in PlanFilterOperator.values)
                _Row(
                  label: operator.name,
                  selected: filter.operator == operator,
                  onTap: () {
                    close();
                    onChange(
                      PlanFilter(
                        relationKey: filter.relationKey,
                        operator: operator,
                        condition: filter.condition,
                        value: filter.value,
                        quickDate: filter.quickDate,
                        offset: filter.offset,
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        DswIconButton(
          icon: LucideIcons.x,
          tooltip: context.tr('planRemove'),
          onTap: onRemove,
          size: DswShape.controlMd,
          iconSize: DswShape.iconTiny,
        ),
      ],
    );
  }
}

/// One value picker for every format: option lists for status/tag, the fifteen
/// date shortcuts plus a literal entry for dates, and text/number input for
/// the rest. This is also what the cell editor uses.
class _ValuePicker extends StatefulWidget {
  const _ValuePicker({
    required this.multi,
    required this.selected,
    required this.onPick,
    this.relation,
    this.quickDates = false,
    this.onQuickDate,
    this.onAddOption,
  });

  final PlanRelation? relation;
  final bool multi;
  final Set<String> selected;
  final void Function(Object? value) onPick;
  final bool quickDates;
  final void Function(PlanFilterQuickDate quick)? onQuickDate;
  final void Function(String text)? onAddOption;

  @override
  State<_ValuePicker> createState() => _ValuePickerState();
}

class _ValuePickerState extends State<_ValuePicker> {
  final _text = TextEditingController();
  final List<String> _picked = [];

  @override
  void initState() {
    super.initState();
    _picked.addAll(widget.selected);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final relation = widget.relation;
    // The popover caps its own height, so the picker scrolls: `Expanded` is not
    // an option inside a column that sizes itself to its children.
    final rows = <Widget>[];
    if (widget.quickDates) {
      rows.add(
        _Rows(
          rows: [
            for (final quick in PlanFilterQuickDate.values)
              _Row(
                label: quick.name,
                onTap: () => widget.onQuickDate?.call(quick),
              ),
          ],
        ),
      );
    } else if (relation != null && relation.format.hasOptions) {
      rows.add(
        _Rows(
          rows: [
            for (final option in relation.options)
              _Row(
                key: ValueKey('plan-option-${option.id}'),
                label: option.text,
                selected: widget.selected.contains(option.id),
                trailing: Padding(
                  padding: const EdgeInsets.only(left: DswShape.xs),
                  child: Icon(
                    LucideIcons.circle,
                    size: DswShape.iconCaption,
                    color: planLadderColor(context.dsw, option.colorIndex),
                  ),
                ),
                onTap: () {
                  if (!widget.multi) {
                    widget.onPick(option.id);
                    return;
                  }
                  setState(() {
                    if (!_picked.remove(option.id)) {
                      _picked.add(option.id);
                    }
                  });
                  widget.onPick(_picked);
                },
              ),
          ],
        ),
      );
    }
    if (widget.onAddOption != null ||
        (relation != null &&
            !relation.format.hasOptions &&
            !widget.quickDates)) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(top: DswShape.xs),
          child: _textRow(
            context,
            label: context.tr(
              widget.onAddOption != null ? 'planNewOption' : 'planFilterValue',
            ),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }

  Widget _textRow(BuildContext context, {required String label}) {
    final color = context.dsw;
    return Row(
      children: [
        Expanded(
          child: dswEnsureShadTheme(
            context,
            ShadInput(
              controller: _text,
              placeholder: Text(
                label,
                style: DswType.xs13.copyWith(color: color.labelTertiary),
              ),
              style: DswType.s14,
            ),
          ),
        ),
        const SizedBox(width: DswShape.xs),
        ShadButton.outline(
          height:
              DswShape.controlMd * MediaQuery.textScalerOf(context).scale(1),
          onPressed: () {
            final value = _text.text.trim();
            if (value.isEmpty) return;
            if (widget.onAddOption != null) {
              widget.onAddOption!(value);
            } else {
              widget.onPick(value);
            }
            setState(_text.clear);
          },
          leading: const Icon(LucideIcons.plus, size: DswShape.iconTiny),
          child: Text(label, style: DswType.xs13),
        ),
      ],
    );
  }
}

/// The viewer's layout options. Every field here is a model field
/// (`Block.kt:284-291`); the sheet does not invent a preference the data view
/// cannot store.
class PlanLayoutSheet extends StatelessWidget {
  const PlanLayoutSheet({
    super.key,
    required this.viewer,
    required this.relations,
    required this.types,
    required this.templates,
    required this.onChange,
  });

  final PlanViewer viewer;
  final List<PlanRelation> relations;
  final List<PlanObjectType> types;
  final List<PlanTemplate> templates;
  final void Function(PlanViewer viewer) onChange;

  @override
  Widget build(BuildContext context) {
    final kind = viewer.kind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionTitle(text: context.tr('planLayoutTitle')),
        _Rows(
          rows: [
            _Row(
              label: context.tr('planLayoutHideIcon'),
              selected: viewer.hideIcon,
              onTap: () =>
                  onChange(viewer.copyWith(hideIcon: !viewer.hideIcon)),
            ),
          ],
        ),
        if (kind == PlanViewerKind.gallery) ...[
          _SectionTitle(text: context.tr('planLayoutCardSize')),
          _Rows(
            rows: [
              for (final size in PlanViewerSize.values)
                _Row(
                  label: size.name,
                  selected: viewer.cardSize == size,
                  onTap: () => onChange(viewer.copyWith(cardSize: size)),
                ),
            ],
          ),
          _SectionTitle(text: context.tr('planLayoutCover')),
          _Rows(
            rows: [
              _Row(
                label: context.tr('planLayoutNone'),
                selected: viewer.coverRelationKey == null,
                onTap: () => onChange(viewer.copyWith(coverRelationKey: null)),
              ),
              for (final relation in relations.where(
                (r) => r.format == PlanRelationFormat.file,
              ))
                _Row(
                  label: relation.name,
                  selected: viewer.coverRelationKey == relation.key,
                  onTap: () =>
                      onChange(viewer.copyWith(coverRelationKey: relation.key)),
                ),
            ],
          ),
          _Rows(
            rows: [
              _Row(
                label: context.tr('planLayoutCoverFit'),
                selected: viewer.coverFit,
                onTap: () =>
                    onChange(viewer.copyWith(coverFit: !viewer.coverFit)),
              ),
            ],
          ),
        ],
        if (kind == PlanViewerKind.board) ...[
          _SectionTitle(text: context.tr('planLayoutGroupBy')),
          _Rows(
            rows: [
              // The upstream grouping whitelist is {STATUS, TAG, CHECKBOX}
              // (`BoardColumnQuery.kt:18-22`) — checkbox reads as the two
              // checked-state columns.
              for (final relation in relations.where(
                (r) =>
                    r.format.hasOptions ||
                    r.format == PlanRelationFormat.checkbox,
              ))
                _Row(
                  label: relation.name,
                  selected: viewer.groupRelationKey == relation.key,
                  onTap: () =>
                      onChange(viewer.copyWith(groupRelationKey: relation.key)),
                ),
            ],
          ),
          _Rows(
            rows: [
              _Row(
                label: context.tr('planLayoutColorColumns'),
                selected: viewer.groupBackgroundColors,
                onTap: () => onChange(
                  viewer.copyWith(
                    groupBackgroundColors: !viewer.groupBackgroundColors,
                  ),
                ),
              ),
            ],
          ),
        ],
        _SectionTitle(text: context.tr('planLayoutDefaultType')),
        _Rows(
          rows: [
            for (final type in types)
              _Row(
                label: type.name,
                selected: viewer.defaultObjectTypeId == type.uniqueKey,
                onTap: () => onChange(
                  viewer.copyWith(defaultObjectTypeId: type.uniqueKey),
                ),
              ),
          ],
        ),
        _SectionTitle(text: context.tr('planLayoutDefaultTemplate')),
        _Rows(
          rows: [
            _Row(
              label: context.tr('planLayoutNone'),
              selected: viewer.defaultTemplateId == null,
              onTap: () => onChange(viewer.copyWith(defaultTemplateId: null)),
            ),
            for (final template in templates)
              _Row(
                label: template.name,
                selected: viewer.defaultTemplateId == template.id,
                onTap: () =>
                    onChange(viewer.copyWith(defaultTemplateId: template.id)),
              ),
          ],
        ),
      ],
    );
  }
}

/// The fields sheet: which relations are columns, how wide, and how a date
/// column renders.
class PlanFieldsSheet extends StatelessWidget {
  const PlanFieldsSheet({
    super.key,
    required this.viewer,
    required this.relations,
    required this.onChange,
  });

  final PlanViewer viewer;
  final List<PlanRelation> relations;
  final void Function(List<PlanViewerRelation> columns) onChange;

  @override
  Widget build(BuildContext context) {
    PlanViewerRelation columnFor(PlanRelation relation) {
      for (final column in viewer.relations) {
        if (column.key == relation.key) return column;
      }
      return PlanViewerRelation(key: relation.key, isVisible: false);
    }

    void update(PlanRelation relation, PlanViewerRelation next) {
      final columns = [...viewer.relations];
      final index = columns.indexWhere((column) => column.key == relation.key);
      if (index < 0) {
        columns.add(next);
      } else {
        columns[index] = next;
      }
      onChange(columns);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SectionTitle(text: context.tr('planFieldsTitle')),
        for (final relation in relations)
          Builder(
            builder: (context) {
              final column = columnFor(relation);
              return Row(
                children: [
                  SizedBox(
                    width: DswShape.controlMd,
                    child: DswHoverTap(
                      onTap: () => update(
                        relation,
                        column.copyWith(isVisible: !column.isVisible),
                      ),
                      semanticLabel: relation.name,
                      toggled: column.isVisible,
                      builder: (context, hovered, focused) => Icon(
                        column.isVisible
                            ? LucideIcons.eye
                            : LucideIcons.eye_off,
                        size: DswShape.iconTiny,
                        color: hovered
                            ? context.dsw.labelSecondary
                            : context.dsw.labelTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(width: DswShape.sm),
                  Expanded(
                    child: Text(
                      relation.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DswType.xs13.copyWith(
                        color: context.dsw.labelPrimary,
                      ),
                    ),
                  ),
                  if (relation.format == PlanRelationFormat.date)
                    DswSheetPopover(
                      label: context.tr('planFieldDateFormat'),
                      minWidth: 160,
                      trigger: (context) => Text(
                        column.dateFormat.name,
                        style: DswType.xxxs11.copyWith(
                          color: context.dsw.labelTertiary,
                        ),
                      ),
                      content: (context, close) => _Rows(
                        rows: [
                          for (final format in PlanDateFormat.values)
                            _Row(
                              label: format.format(DateTime(2026, 10, 1)),
                              selected: column.dateFormat == format,
                              onTap: () {
                                close();
                                update(
                                  relation,
                                  column.copyWith(dateFormat: format),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  DswSheetPopover(
                    label: context.tr('planFieldWidth'),
                    minWidth: 140,
                    trigger: (context) => Text(
                      column.width.name,
                      style: DswType.xxxs11.copyWith(
                        color: context.dsw.labelTertiary,
                      ),
                    ),
                    content: (context, close) => _Rows(
                      rows: [
                        for (final size in PlanViewerSize.values)
                          _Row(
                            label: '${size.name} · ${size.columnWidth.round()}',
                            selected: column.width == size,
                            onTap: () {
                              close();
                              update(relation, column.copyWith(width: size));
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

/// The cell editor: one popover, chosen by the relation's format. The value
/// writes through the same normaliser the store uses, so a cell cannot store
/// `"42"` where the engine expects `42`.
class PlanCellEditor extends StatelessWidget {
  const PlanCellEditor({
    super.key,
    required this.record,
    required this.relation,
    required this.onWrite,
    required this.onClear,
    this.onAddOption,
    required this.child,
  });

  final PlanObject record;
  final PlanRelation relation;
  final void Function(Object? value) onWrite;
  final VoidCallback onClear;
  final void Function(String text)? onAddOption;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (relation.format == PlanRelationFormat.checkbox) {
      // A checkbox toggles in place; no popover to dismiss.
      return DswHoverTap(
        onTap: () => onWrite(!(record.relation(relation.key) == true)),
        semanticLabel: relation.name,
        builder: (context, hovered, focused) => child,
      );
    }
    final selected = <String>{
      if (record.relation(relation.key) case final value)
        ...value is List ? [for (final entry in value) '$entry'] : ['$value'],
    };
    return DswSheetPopover(
      label: relation.name,
      minWidth: 240,
      trigger: (context) => child,
      content: (context, close) => _ValuePicker(
        relation: relation,
        multi: relation.format.isMultiValue,
        selected: selected,
        onAddOption: onAddOption,
        quickDates: relation.format == PlanRelationFormat.date,
        onQuickDate: null,
        onPick: (value) {
          if (value == null || (value is String && value.isEmpty)) {
            onClear();
          } else {
            onWrite(value);
          }
          close();
        },
      ),
    );
  }
}
