// All Content (ADR-0037 P6, module 2): the five tabs the client answers
// (`PAGES / LISTS / MEDIA / BOOKMARKS / FILES`), the two menu modes
// (`AllContent | Unlinked`), the time groups, and the per-space sort that
// restores from the store. The queries are the store's own — this screen adds
// no filtering rule of its own.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadInput;

import '../../../l10n/locales.dart';
import '../../../model/plan_all_content.dart';
import '../../../model/plan_struct.dart';
import '../../../state/plan_object_store.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_shad_bridge.dart'
    show dswEnsureShadTheme, dswInputHint;
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/tappable.dart';

/// The screen's remembered answer: which tab, which mode, which sort and
/// direction — the shape `RestoreAllContentState` carries upstream, kept in
/// the owner's state here (persistence rides with the workspace later).
class PlanAllContentState {
  const PlanAllContentState({
    this.tab = PlanAllContentTab.pages,
    this.unlinked = false,
    this.sort = PlanAllContentSort.modified,
    this.ascending = false,
  });

  final PlanAllContentTab tab;
  final bool unlinked;
  final PlanAllContentSort sort;
  final bool ascending;

  PlanAllContentState copyWith({
    PlanAllContentTab? tab,
    bool? unlinked,
    PlanAllContentSort? sort,
    bool? ascending,
  }) => PlanAllContentState(
    tab: tab ?? this.tab,
    unlinked: unlinked ?? this.unlinked,
    sort: sort ?? this.sort,
    ascending: ascending ?? this.ascending,
  );
}

class PlanAllContentScreen extends StatefulWidget {
  const PlanAllContentScreen({
    super.key,
    required this.store,
    this.initial = const PlanAllContentState(),
    this.onStateChanged,
    this.now,
  });

  final PlanObjectStore store;
  final PlanAllContentState initial;
  final void Function(PlanAllContentState state)? onStateChanged;

  /// The grouping clock, injectable so a test's buckets do not drift with the
  /// machine's date.
  final DateTime? now;

  @override
  State<PlanAllContentScreen> createState() => _PlanAllContentScreenState();
}

class _PlanAllContentScreenState extends State<PlanAllContentScreen> {
  late PlanAllContentState _state = widget.initial;
  String _query = '';

  PlanObjectStore get _store => widget.store;

  /// The tab's records after the mode and the type filter — upstream runs the
  /// same two filters in `filtersForSubscribe` (`:72-102`), minus the deleted
  /// filter our stage boundary already answers.
  List<PlanObject> _recordsFor(PlanAllContentTab tab) {
    final bin = _store.binIds;
    final pool = _state.unlinked
        ? _store.unlinkedRecords
        : [
            for (final record in _store.objects)
              if (!bin.contains(record.id)) record,
          ];
    return [
      for (final record in pool)
        if (tab.typeKeys.contains(record.typeKey) &&
            (_query.isEmpty ||
                (record.text(PlanRelationKeys.name) ?? '')
                    .toLowerCase()
                    .contains(_query)))
          record,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final records = sortPlanAllContent(
      _recordsFor(_state.tab),
      _state.sort,
      ascending: _state.ascending,
    );
    final groups = groupPlanAllContent(records, widget.now ?? DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DswShape.md,
            DswShape.md,
            DswShape.md,
            DswShape.xs,
          ),
          child: Wrap(
            spacing: DswShape.sm,
            runSpacing: DswShape.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                context.tr('planAllContentTitle'),
                style: DswType.l20.copyWith(color: color.labelPrimary),
              ),
              SizedBox(
                width: 200,
                child: dswEnsureShadTheme(
                  context,
                  ShadInput(
                    placeholder: dswInputHint(
                      context.tr('planSearchInDoc'),
                      style: DswType.xs13.copyWith(color: color.labelTertiary),
                    ),
                    style: DswType.xs13,
                    onChanged: (text) =>
                        setState(() => _query = text.toLowerCase()),
                  ),
                ),
              ),
              _ModeChip(
                label: context.tr(
                  _state.unlinked ? 'planModeUnlinked' : 'planModeAllContent',
                ),
                onTap: () {
                  setState(() {
                    _state = _state.copyWith(unlinked: !_state.unlinked);
                  });
                  widget.onStateChanged?.call(_state);
                },
              ),
              _ModeChip(
                label: context.tr(
                  _state.ascending ? 'planSortAsc' : 'planSortDesc',
                ),
                onTap: () {
                  setState(() {
                    _state = _state.copyWith(ascending: !_state.ascending);
                  });
                  widget.onStateChanged?.call(_state);
                },
              ),
              for (final (sort, label) in [
                (PlanAllContentSort.modified, 'planSortModified'),
                (PlanAllContentSort.created, 'planSortCreated'),
                (PlanAllContentSort.name, 'planSortName'),
                (PlanAllContentSort.lastUsed, 'planSortLastUsed'),
              ])
                _ModeChip(
                  label: context.tr(label),
                  selected: _state.sort == sort,
                  onTap: () {
                    setState(() => _state = _state.copyWith(sort: sort));
                    widget.onStateChanged?.call(_state);
                  },
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DswShape.md),
          child: Wrap(
            spacing: DswShape.xs,
            runSpacing: DswShape.xs,
            children: [
              for (final tab in PlanAllContentTab.values)
                _ModeChip(
                  label: switch (tab) {
                    PlanAllContentTab.pages => context.tr('planTabPages'),
                    PlanAllContentTab.lists => context.tr('planTabLists'),
                    PlanAllContentTab.media => context.tr('planTabMedia'),
                    PlanAllContentTab.bookmarks => context.tr(
                      'planTabBookmarks',
                    ),
                    PlanAllContentTab.files => context.tr('planTabFiles'),
                  },
                  selected: _state.tab == tab,
                  onTap: () {
                    setState(() => _state = _state.copyWith(tab: tab));
                    widget.onStateChanged?.call(_state);
                  },
                ),
            ],
          ),
        ),
        Expanded(
          child: records.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(DswShape.lg),
                  child: Text(
                    context.tr('planAllContentEmpty'),
                    style: DswType.xs13.copyWith(color: color.labelTertiary),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(DswShape.md),
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                          top: DswShape.sm,
                          bottom: DswShape.xs,
                        ),
                        child: Text(
                          context.tr(planAllContentGroupLabelCode(entry.key)),
                          style: DswType.xxsStrong12.copyWith(
                            color: color.labelTertiary,
                          ),
                        ),
                      ),
                      for (final record in entry.value)
                        _RecordRow(
                          name:
                              record.text(PlanRelationKeys.name) ??
                              context.tr('planUntitled'),
                          typeKey: record.typeKey,
                          onTap: () {},
                        ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: onTap,
      semanticLabel: label,
      builder: (context, hovered, focused) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DswShape.sm,
          vertical: DswShape.xs,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.interactiveSelected
              : hovered
              ? color.interactiveBgHover
              : color.bgLayer2,
          borderRadius: BorderRadius.circular(DswShape.inner),
          border: Border.all(color: color.borderL2),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DswType.xs13.copyWith(
            color: color.labelPrimary,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  const _RecordRow({
    required this.name,
    required this.typeKey,
    required this.onTap,
  });

  final String name;
  final String typeKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: onTap,
      semanticLabel: name,
      builder: (context, hovered, focused) => Container(
        height: DswShape.rowSession * MediaQuery.textScalerOf(context).scale(1),
        padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
        decoration: BoxDecoration(
          color: hovered ? color.interactiveBgHover : null,
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.circle,
              size: DswShape.iconTiny,
              color: color.labelTertiary,
            ),
            const SizedBox(width: DswShape.sm),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.xs13.copyWith(color: color.labelPrimary),
              ),
            ),
            Text(
              typeKey,
              style: DswType.xxxs11.copyWith(color: color.labelTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
