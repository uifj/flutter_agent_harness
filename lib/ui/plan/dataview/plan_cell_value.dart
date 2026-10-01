// The one place a plan record's value becomes pixels (ADR-0037 §5).
//
// Every viewer — grid, list, gallery, board — asks this widget, so a status
// reads the same in a table cell and on a card. Two rules it exists to hold:
// the 11-stop colour ladder is the MODEL's vocabulary (`PlanThemeColors`,
// `core-models/.../ThemeColor.kt:10-42`) and `DswAlias` is the app's; the
// mapping happens here, once, onto tokens that already exist. No new colour
// token is introduced, because ADR-0025 requires every token to have a reader
// and this function is the reader.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../l10n/locales.dart';
import '../../../model/plan_block.dart';
import '../../../model/plan_dataview.dart';
import '../../../model/plan_relation.dart';
import '../../../model/plan_struct.dart';
import '../../../theme/dsw_alias.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/pill.dart';
import '../../primitives/tappable.dart';

/// A relation value's display form, resolved from the model vocabulary.
///
/// [linkedName] turns an `object`-format id into the record's title; a cell
/// that cannot resolve it shows the id, which is what makes a dangling link
/// visible instead of invisible.
class PlanCellValue extends StatelessWidget {
  const PlanCellValue({
    super.key,
    required this.object,
    required this.relation,
    this.viewerRelation,
    this.linkedName,
    this.onToggleCheckbox,
    this.align = TextAlign.start,
  });

  final PlanObject object;
  final PlanRelation? relation;

  /// The column's own settings — date format, include-time — live on the
  /// viewer, not on the relation (`Block.kt:306-313`).
  final PlanViewerRelation? viewerRelation;
  final String? Function(String id)? linkedName;
  final VoidCallback? onToggleCheckbox;
  final TextAlign align;

  PlanRelationFormat get _format =>
      relation?.format ?? PlanRelationFormat.shortText;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final value = object.relation(relation?.key ?? '');
    if (value == null || value == '') {
      return Text(
        context.tr('planCellEmpty'),
        style: DswType.xs13.copyWith(color: color.labelTertiary),
      );
    }

    switch (_format) {
      case PlanRelationFormat.checkbox:
        return _Checkbox(checked: value == true, onTap: onToggleCheckbox);
      case PlanRelationFormat.status:
        // Inside the Wrap the badge takes its label's width: a cell that
        // hands down a tight width (the list's secondary slot) would otherwise
        // stretch the pill across the whole cell and clip its own label.
        return Wrap(
          children: [
            _Badge(
              label: relation?.optionText('$value') ?? '$value',
              colorIndex: relation?.option(value.toString())?.colorIndex,
            ),
          ],
        );
      case PlanRelationFormat.tag:
        final ids = object.options(relation?.key ?? '');
        if (ids.isEmpty) {
          return Text(
            context.tr('planCellEmpty'),
            style: DswType.xs13.copyWith(color: color.labelTertiary),
          );
        }
        return Wrap(
          spacing: DswShape.xs,
          runSpacing: DswShape.xs,
          children: [
            for (final id in ids)
              _Badge(
                label: relation?.optionText(id) ?? id,
                colorIndex: relation?.option(id)?.colorIndex,
              ),
          ],
        );
      case PlanRelationFormat.date:
        return _DateValue(
          date: object.date(relation?.key ?? ''),
          viewerRelation: viewerRelation,
        );
      case PlanRelationFormat.number:
        final number = object.number(relation?.key ?? '');
        return Text(
          number == null ? '$value' : _trim(number),
          style: DswType.xs13.copyWith(color: color.labelPrimary),
        );
      case PlanRelationFormat.object:
        final ids = object.options(relation?.key ?? '');
        return Text(
          ids.isEmpty
              ? '$value'
              : [for (final id in ids) linkedName?.call(id) ?? id].join(', '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DswType.xs13.copyWith(color: color.brandText),
        );
      case PlanRelationFormat.url:
      case PlanRelationFormat.email:
      case PlanRelationFormat.phone:
        return Text(
          '$value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DswType.xs13.copyWith(color: color.labelPrimaryBluish),
        );
      case PlanRelationFormat.file:
        return _FileValue(value: '$value');
      case PlanRelationFormat.emoji:
        return Text('$value', style: DswType.base16);
      case PlanRelationFormat.longText:
        return Text(
          '$value',
          textAlign: align,
          style: DswType.xs13.copyWith(color: color.labelPrimary),
        );
      case PlanRelationFormat.shortText:
        return Text(
          '$value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: align,
          style: DswType.xs13.copyWith(color: color.labelPrimary),
        );
      case PlanRelationFormat.relations:
      case PlanRelationFormat.map:
      case PlanRelationFormat.undefined:
        // Present in the wire vocabulary and not creatable in this client
        // (inventory §5), so reaching one means data from elsewhere: show the
        // scalar rather than pretending the cell is empty.
        return Text(
          '$value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DswType.xs13.copyWith(color: color.labelSecondary),
        );
    }
  }

  static String _trim(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';
}

/// A status or tag value as a pill. The colour comes from the option's index
/// into the 11-stop ladder, mapped onto existing aliases.
class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.colorIndex});

  final String label;
  final int? colorIndex;

  @override
  Widget build(BuildContext context) {
    return Pill(
      label: label,
      height: DswShape.controlMd * MediaQuery.textScalerOf(context).scale(1),
      color: planLadderColor(context.dsw, colorIndex),
    );
  }
}

/// Maps the model's 11-stop ladder onto `DswAlias` tokens. One function, so a
/// status colour is the same answer everywhere and there is no second table.
Color planLadderColor(DswAlias color, int? index) => switch (index) {
  null => color.bgLayer2,
  0 => color.bgLayer2,
  1 => color.labelTertiary,
  2 => color.stateWarnTertiary,
  3 => color.stateWarnPrimary,
  4 => color.stateErrorPrimary,
  5 => color.stateErrorSecondary,
  6 => color.stateBusinessTertiary,
  7 => color.brandPrimary,
  8 => color.stateBusinessPrimary,
  9 => color.stateSuccessPrimary,
  _ => color.stateSuccessTertiary,
};

/// `PlanThemeColors.names` → the ladder index a relation option stores.
int? planLadderIndexOf(String name) {
  final index = PlanThemeColors.names.indexOf(name);
  return index < 0 ? null : index;
}

class _DateValue extends StatelessWidget {
  const _DateValue({required this.date, this.viewerRelation});

  final DateTime? date;
  final PlanViewerRelation? viewerRelation;

  @override
  Widget build(BuildContext context) {
    final value = date;
    if (value == null) {
      return Text(
        context.tr('planCellEmpty'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DswType.xs13.copyWith(color: context.dsw.labelTertiary),
      );
    }
    final format = viewerRelation?.dateFormat ?? PlanDateFormat.medium;
    final includeTime = viewerRelation?.includeTime ?? false;
    final time = viewerRelation?.timeFormat ?? PlanTimeFormat.h12;
    final text = includeTime
        ? '${format.format(value)} ${time.format(value)}'
        : format.format(value);
    // A date reads as one line at every step — it shortens, the seat doesn't
    // grow (two-line dates get clipped at 1.8x in the grid's narrow columns).
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
      style: DswType.xs13.copyWith(color: context.dsw.labelSecondary),
    );
  }
}

class _FileValue extends StatelessWidget {
  const _FileValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final name = value.split('/').last;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LucideIcons.file,
          size: DswShape.iconTiny,
          color: color.labelTertiary,
        ),
        const SizedBox(width: DswShape.xs),
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DswType.xs13.copyWith(color: color.labelPrimary),
          ),
        ),
      ],
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked, this.onTap});

  final bool checked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // `DswHoverTap`, not a hand-rolled MouseRegion + GestureDetector: the
    // checkbox needs keyboard and semantics too (ADR-0021), and
    // `test/tap_affordance_test.dart` counts the handwritten form per file.
    return DswHoverTap(
      onTap: onTap,
      toggled: checked,
      semanticLabel: context.tr(
        checked ? 'planCellChecked' : 'planCellUnchecked',
      ),
      builder: (context, hovered, focused) => checked
          ? Container(
              // `check_square` is not in the pinned lucide set; a filled box
              // with a check reads the same and only uses names that exist.
              width: DswShape.iconSm,
              height: DswShape.iconSm,
              decoration: BoxDecoration(
                color: color.brandPrimary,
                borderRadius: BorderRadius.circular(DswShape.inset),
              ),
              child: Icon(
                LucideIcons.check,
                size: DswShape.iconCaption + 2,
                color: color.labelPrimaryForeground,
              ),
            )
          : Icon(
              LucideIcons.square,
              size: DswShape.iconSm,
              color: hovered || focused
                  ? color.labelSecondary
                  : color.labelTertiary,
            ),
    );
  }
}
