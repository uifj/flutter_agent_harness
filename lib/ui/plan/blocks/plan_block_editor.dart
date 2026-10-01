// The block editor scaffold (ADR-0037 P5): the toolbar, the slash menu — the
// only insertion path — and in-document search. The search enters read mode
// first, exactly as upstream does (`EVM:2896-2902`), and its six events are
// Query / Search / Next / Previous / Clear / Cancel (`SearchInDocEvent.kt`).
//
// Two honest scope lines for this increment, both registered in the parity
// ledger: the slash menu carries the Style / Media / Other sections — the
// Objects and Properties sections need the plan object library (P6), and the
// Alignment / Colour / Background sections are answered by the toolbar's
// selects; the Actions section is the per-block menu. The toolbar acts on the
// focused block.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadButton, ShadDialog, ShadInput, showShadDialog;

import '../../../l10n/locales.dart';
import '../../../model/plan_block.dart';
import '../../../state/plan_block_document.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_shad_bridge.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../primitives/icon_button.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';
import 'plan_block_view.dart';

class PlanBlockEditor extends StatefulWidget {
  const PlanBlockEditor({
    super.key,
    required this.document,
    required this.onSave,
    this.readOnly = false,
  });

  final PlanBlockDocument document;
  final VoidCallback onSave;
  final bool readOnly;

  @override
  State<PlanBlockEditor> createState() => _PlanBlockEditorState();
}

class _PlanBlockEditorState extends State<PlanBlockEditor> {
  String? _activeBlockId;

  /// The focused field's non-empty selection — the stretch the toolbar's
  /// mark buttons act on; null once the caret collapses.
  PlanMarkRange? _activeSelection;

  /// Applies a mark to the active selection, or reports there was none.
  void _applyMark(PlanMarkType type, {String? param}) {
    final blockId = _activeBlockId;
    final selection = _activeSelection;
    if (blockId == null || selection == null) return;
    widget.document.applyMark(blockId, type, selection, param: param);
  }

  /// Whether the selection already carries the mark, so a toolbar button can
  /// show the applied state (`outlined`).
  bool _hasMark(PlanMarkType type) {
    final blockId = _activeBlockId;
    final selection = _activeSelection;
    if (blockId == null || selection == null) return false;
    final content = widget.document.block(blockId)?.content;
    return content is PlanText &&
        content.marks.any(
          (mark) =>
              mark.type == type &&
              mark.range.start < selection.end &&
              selection.start < mark.range.end,
        );
  }

  /// The link mark needs a URL: one small dialog, then the mark.
  Future<void> _applyLink() async {
    final blockId = _activeBlockId;
    final selection = _activeSelection;
    if (blockId == null || selection == null || !mounted) return;
    final url = await showShadDialog<String>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        title: Text(context.tr('planLinkPrompt'), style: DswType.sStrong14),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('planCancel')),
          ),
        ],
        child: _LinkInput(
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
      ),
    );
    if (url == null || url.trim().isEmpty) return;
    _applyMark(PlanMarkType.link, param: url.trim());
  }

  bool _searching = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final Map<String, GlobalKey> _rowKeys = {};
  int _matchIndex = -1;
  List<String> _matches = const [];

  @override
  void initState() {
    super.initState();
    widget.document.addListener(_onDocumentChanged);
    _rebuildKeys();
  }

  @override
  void didUpdateWidget(PlanBlockEditor old) {
    super.didUpdateWidget(old);
    if (widget.document != old.document) {
      old.document.removeListener(_onDocumentChanged);
      widget.document.addListener(_onDocumentChanged);
      _rebuildKeys();
    }
  }

  @override
  void dispose() {
    widget.document.removeListener(_onDocumentChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onDocumentChanged() {
    if (mounted) setState(() {});
  }

  void _rebuildKeys() {
    _rowKeys
      ..clear()
      ..addEntries([
        for (final id in _flattenedIds())
          MapEntry(id, GlobalKey(debugLabel: 'plan-row-$id')),
      ]);
  }

  List<String> _flattenedIds() => [
    for (final block in widget.document.blocks) ...block.flattenedIds,
  ];

  // ---- search (the six events) --------------------------------------------

  void _searchQuery(String text) {
    _query = text.trim().toLowerCase();
    _matches = _query.isEmpty
        ? const []
        : [
            for (final id in _flattenedIds())
              if (_blockText(id).toLowerCase().contains(_query)) id,
          ];
    _matchIndex = _matches.isEmpty ? -1 : 0;
    setState(() {});
  }

  void _searchNext() => _cycle(1);

  void _searchPrevious() => _cycle(-1);

  void _cycle(int delta) {
    if (_matches.isEmpty) return;
    _matchIndex = (_matchIndex + delta) % _matches.length;
    final key = _rowKeys[_matches[_matchIndex]];
    final target = key?.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 120),
        alignment: 0.2,
      );
    }
    setState(() {});
  }

  void _searchCancel() {
    _searching = false;
    _searchClear();
  }

  void _searchClear() {
    _query = '';
    _searchController.clear();
    _matches = const [];
    _matchIndex = -1;
    setState(() {});
  }

  String _blockText(String id) {
    final content = widget.document.block(id)?.content;
    return content is PlanText ? content.text : '';
  }

  // ---- insertion (the slash menu) -----------------------------------------

  Future<void> _openSlash(String? afterBlockId) async {
    // The slash panel floats near the caret upstream; a centred dialog is the
    // same command-palette shape on a desktop pointer surface, and it rides
    // the dialog skin the app already themes.
    final name = await showShadDialog<String>(
      context: context,
      builder: (dialogContext) => ShadDialog(
        radius: BorderRadius.circular(DswShape.float),
        title: Text(context.tr('planAddBlock'), style: DswType.sStrong14),
        child: SizedBox(width: 520, child: _SlashSheet()),
      ),
    );
    if (name == null || !mounted) return;
    final item = PlanSlashItem.values
        .where((entry) => entry.name == name)
        .first;
    // The Simple table item lands a real table run — the default 3×3
    // (CreateTable's DEFAULT_ROW/COLUMN_COUNT upstream); `table(NxM)` sizes
    // it once the filter input is on hand to carry the pattern.
    if (item == PlanSlashItem.table) {
      final id = widget.document.insertTable(rows: 3, columns: 3);
      setState(() => _activeBlockId = id);
      return;
    }
    final id = widget.document.insertBelow(
      afterBlockId,
      _SlashSheetState.contentFor(item),
    );
    setState(() => _activeBlockId = id);
  }

  // ---- build ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Toolbar(
          document: doc,
          canUndo: doc.canUndo,
          canRedo: doc.canRedo,
          activeBlockId: _activeBlockId,
          selection: _activeSelection,
          hasMark: _hasMark,
          onApplyMark: _applyMark,
          onApplyLink: _applyLink,
          searching: _searching,
          matchCount: _matches.length,
          matchIndex: _matchIndex,
          searchController: _searchController,
          onUndo: doc.undo,
          onRedo: doc.redo,
          onSearchToggle: () => _searching
              ? _searchCancel()
              : setState(() {
                  _searching = true;
                }),
          onQuery: _searchQuery,
          onNext: _searchNext,
          onPrevious: _searchPrevious,
          onCancel: _searchCancel,
          onTurnInto: (style) {
            if (_activeBlockId != null) doc.turnInto(_activeBlockId!, style);
          },
          onTextColor: (name) {
            final selection = _activeSelection;
            if (_activeBlockId != null && selection != null) {
              doc.applyMark(
                _activeBlockId!,
                PlanMarkType.textColor,
                selection,
                param: name,
              );
            } else if (_activeBlockId != null) {
              doc.setTextColor(_activeBlockId!, name);
            }
          },
          onBackground: (name) {
            final selection = _activeSelection;
            if (_activeBlockId != null && selection != null) {
              doc.applyMark(
                _activeBlockId!,
                PlanMarkType.backgroundColor,
                selection,
                param: name,
              );
            } else if (_activeBlockId != null) {
              doc.setTextBackground(_activeBlockId!, name);
            }
          },
          onAlign: (align) {
            if (_activeBlockId != null) doc.setAlign(_activeBlockId!, align);
          },
          onInsert: _openSlash,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(DswShape.md),
            child: PlanBlockView(
              document: doc,
              readOnly: widget.readOnly || _searching,
              onInsertSlash: _openSlash,
              onFocusedBlock: (id) => setState(() => _activeBlockId = id),
              onSelectionChanged: (id, selection) {
                if (_activeBlockId == id || selection != null) {
                  setState(() {
                    _activeBlockId = id;
                    _activeSelection = selection;
                  });
                }
              },
              keyFor: (id) => _rowKeys[id],
              searchQuery: _query,
            ),
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.document,
    required this.canUndo,
    required this.canRedo,
    required this.activeBlockId,
    required this.selection,
    required this.hasMark,
    required this.onApplyMark,
    required this.onApplyLink,
    required this.searching,
    required this.matchCount,
    required this.matchIndex,
    required this.searchController,
    required this.onUndo,
    required this.onRedo,
    required this.onSearchToggle,
    required this.onQuery,
    required this.onNext,
    required this.onPrevious,
    required this.onCancel,
    required this.onTurnInto,
    required this.onTextColor,
    required this.onBackground,
    required this.onAlign,
    required this.onInsert,
  });

  final PlanBlockDocument document;
  final bool canUndo;
  final bool canRedo;
  final String? activeBlockId;
  final PlanMarkRange? selection;
  final bool Function(PlanMarkType type) hasMark;
  final void Function(PlanMarkType type, {String? param}) onApplyMark;
  final Future<void> Function() onApplyLink;
  final bool searching;
  final int matchCount;
  final int matchIndex;
  final TextEditingController searchController;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSearchToggle;
  final void Function(String) onQuery;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onCancel;
  final void Function(PlanTextStyle) onTurnInto;
  final void Function(String?) onTextColor;
  final void Function(String?) onBackground;
  final void Function(PlanAlign) onAlign;
  final void Function(String? afterBlockId) onInsert;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DswShape.md,
        vertical: DswShape.xs,
      ),
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(bottom: BorderSide(color: color.borderL2)),
      ),
      child: Wrap(
        spacing: DswShape.sm,
        runSpacing: DswShape.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DswIconButton(
            icon: LucideIcons.undo_2,
            tooltip: context.tr('planEditorUndo'),
            onTap: canUndo ? onUndo : null,
          ),
          DswIconButton(
            icon: LucideIcons.redo_2,
            tooltip: context.tr('planEditorRedo'),
            onTap: canRedo ? onRedo : null,
          ),
          DswIconButton(
            icon: LucideIcons.plus,
            tooltip: context.tr('planAddBlock'),
            onTap: () => onInsert(activeBlockId),
          ),
          if (searching) ...[
            SizedBox(
              width: 220,
              child: dswEnsureShadTheme(
                context,
                ShadInput(
                  controller: searchController,
                  autofocus: true,
                  placeholder: Text(
                    context.tr('planSearchInDoc'),
                    style: DswType.xs13.copyWith(color: color.labelTertiary),
                  ),
                  style: DswType.xs13,
                  onChanged: onQuery,
                ),
              ),
            ),
            Text(
              matchCount == 0 ? '0' : '${matchIndex + 1} / $matchCount',
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
            DswIconButton(
              icon: LucideIcons.chevron_up,
              tooltip: context.tr('planSearchPrevious'),
              onTap: matchCount > 0 ? onPrevious : null,
            ),
            DswIconButton(
              icon: LucideIcons.chevron_down,
              tooltip: context.tr('planSearchNext'),
              onTap: matchCount > 0 ? onNext : null,
            ),
            DswIconButton(
              icon: LucideIcons.x,
              tooltip: context.tr('planSearchCancel'),
              onTap: onCancel,
            ),
          ] else
            DswIconButton(
              icon: LucideIcons.search,
              tooltip: context.tr('planSearchInDoc'),
              onTap: onSearchToggle,
            ),
          if (!searching && activeBlockId != null && selection != null) ...[
            for (final (type, icon, tip, _) in const [
              (PlanMarkType.bold, LucideIcons.bold, 'planMarkBold', false),
              (
                PlanMarkType.italic,
                LucideIcons.italic,
                'planMarkItalic',
                false,
              ),
              (
                PlanMarkType.strikethrough,
                LucideIcons.strikethrough,
                'planMarkStrike',
                false,
              ),
              (
                PlanMarkType.underline,
                LucideIcons.underline,
                'planMarkUnderline',
                false,
              ),
              (PlanMarkType.keyboard, LucideIcons.code, 'planMarkCode', false),
              (PlanMarkType.link, LucideIcons.link, 'planMarkLink', false),
            ])
              // Applied marks read as ghost buttons; the outlined frame is
              // the "not yet on this stretch" state.
              hasMark(type)
                  ? DswIconButton(
                      icon: icon,
                      tooltip: context.tr(tip),
                      onTap: type == PlanMarkType.link
                          ? onApplyLink
                          : () => onApplyMark(type),
                    )
                  : DswIconButton.outlined(
                      icon: icon,
                      tooltip: context.tr(tip),
                      onTap: type == PlanMarkType.link
                          ? onApplyLink
                          : () => onApplyMark(type),
                    ),
          ],
          if (!searching && activeBlockId != null) ...[
            SizedBox(
              width: 132,
              child: dswEnsureShadTheme(
                context,
                _StyleSelect(
                  document: document,
                  blockId: activeBlockId!,
                  onTurnInto: onTurnInto,
                ),
              ),
            ),
            SizedBox(
              width: 116,
              child: dswEnsureShadTheme(
                context,
                _ColorSelect(
                  label: context.tr('planColourLabel'),
                  onPick: onTextColor,
                ),
              ),
            ),
            SizedBox(
              width: 116,
              child: dswEnsureShadTheme(
                context,
                _ColorSelect(
                  label: context.tr('planColourBackground'),
                  onPick: onBackground,
                ),
              ),
            ),
            for (final (align, icon, label) in const [
              (
                PlanAlign.start,
                LucideIcons.align_start_horizontal,
                'planAlignLeft',
              ),
              (
                PlanAlign.center,
                LucideIcons.align_center_horizontal,
                'planAlignCenter',
              ),
              (
                PlanAlign.end,
                LucideIcons.align_end_horizontal,
                'planAlignRight',
              ),
            ])
              DswIconButton(
                icon: icon,
                tooltip: context.tr(label),
                onTap: () => onAlign(align),
              ),
          ],
        ],
      ),
    );
  }
}

class _StyleSelect extends StatelessWidget {
  const _StyleSelect({
    required this.document,
    required this.blockId,
    required this.onTurnInto,
  });

  final PlanBlockDocument document;
  final String blockId;
  final void Function(PlanTextStyle) onTurnInto;

  @override
  Widget build(BuildContext context) {
    return DswContextMenu(
      items: (_) => [
        for (final style in PlanTextStyle.insertable)
          DswMenuEntry(label: style.code, onTap: () => onTurnInto(style)),
      ],
      child: _ToolbarChip(label: context.tr('planStyleLabel')),
    );
  }
}

class _ColorSelect extends StatelessWidget {
  const _ColorSelect({required this.label, required this.onPick});

  final String label;
  final void Function(String?) onPick;

  @override
  Widget build(BuildContext context) {
    return DswContextMenu(
      items: (_) => [
        DswMenuEntry(
          label: context.tr('planLayoutNone'),
          onTap: () => onPick(null),
        ),
        for (final name in PlanThemeColors.names)
          DswMenuEntry(label: name, onTap: () => onPick(name)),
      ],
      child: _ToolbarChip(label: label),
    );
  }
}

/// A small toolbar chip that opens a context menu; icon-free on purpose, so
/// the label is its own accessible name.
class _ToolbarChip extends StatelessWidget {
  const _ToolbarChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      height: DswShape.controlMd,
      padding: const EdgeInsets.symmetric(horizontal: DswShape.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.bgLayer2,
        borderRadius: BorderRadius.circular(DswShape.inner),
        border: Border.all(color: color.borderL2),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: DswType.xs13.copyWith(color: color.labelSecondary),
      ),
    );
  }
}

/// The upstream label for each item (`SlashConst.kt`), through the
/// dictionaries like every other user-facing string.
String slashLabel(BuildContext context, PlanSlashItem item) => switch (item) {
  PlanSlashItem.styleText => context.tr('planSlashText'),
  PlanSlashItem.styleTitle => context.tr('planSlashTitle'),
  PlanSlashItem.styleHeading => context.tr('planSlashHeading'),
  PlanSlashItem.styleSubheading => context.tr('planSlashSubheading'),
  PlanSlashItem.styleHighlighted => context.tr('planSlashHighlighted'),
  PlanSlashItem.styleCallout => context.tr('planSlashCallout'),
  PlanSlashItem.styleCheckbox => context.tr('planSlashCheckbox'),
  PlanSlashItem.styleBulleted => context.tr('planSlashBulleted'),
  PlanSlashItem.styleNumbered => context.tr('planSlashNumbered'),
  PlanSlashItem.styleToggle => context.tr('planSlashToggle'),
  PlanSlashItem.file => context.tr('planSlashFile'),
  PlanSlashItem.picture => context.tr('planSlashPicture'),
  PlanSlashItem.video => context.tr('planSlashVideo'),
  PlanSlashItem.bookmark => context.tr('planSlashBookmark'),
  PlanSlashItem.code => context.tr('planSlashCode'),
  PlanSlashItem.line => context.tr('planSlashLine'),
  PlanSlashItem.dots => context.tr('planSlashDots'),
  PlanSlashItem.tableOfContents => context.tr('planSlashToc'),
  PlanSlashItem.table => context.tr('planSlashTable'),
  _ => item.name,
};

/// The slash sheet: the sections the client actually answers in this
/// increment, each item mapped onto the block it inserts.
class _SlashSheet extends StatefulWidget {
  const _SlashSheet();

  @override
  State<_SlashSheet> createState() => _SlashSheetState();
}

class _SlashSheetState extends State<_SlashSheet> {
  final _filterController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  /// The block a chosen slash item inserts. Style items answer through the
  /// model's own mapping — the single source of truth that already records
  /// "Title is H1, Highlighted is QUOTE" (the audit caught this sheet
  /// drifting from it).
  static PlanBlockContent contentFor(PlanSlashItem item) => switch (item) {
    PlanSlashItem.styleText ||
    PlanSlashItem.styleTitle ||
    PlanSlashItem.styleHeading ||
    PlanSlashItem.styleSubheading ||
    PlanSlashItem.styleHighlighted ||
    PlanSlashItem.styleCallout ||
    PlanSlashItem.styleCheckbox ||
    PlanSlashItem.styleBulleted ||
    PlanSlashItem.styleNumbered ||
    PlanSlashItem.styleToggle ||
    PlanSlashItem.code => PlanText(
      text: '',
      style: PlanSlashItem.textStyleFor(item),
      checked: item == PlanSlashItem.styleCheckbox ? false : null,
      iconEmoji: item == PlanSlashItem.styleCallout ? '💡' : null,
    ),
    PlanSlashItem.file => const PlanFile(kind: PlanFileKind.file),
    PlanSlashItem.picture => const PlanFile(kind: PlanFileKind.image),
    PlanSlashItem.video => const PlanFile(kind: PlanFileKind.video),
    PlanSlashItem.bookmark => const PlanBookmark(),
    PlanSlashItem.line => const PlanDivider(PlanDividerStyle.line),
    PlanSlashItem.dots => const PlanDivider(PlanDividerStyle.dots),
    PlanSlashItem.tableOfContents => const PlanTableOfContents(),
    PlanSlashItem.table => const PlanUnsupported('table(NxM) opens the grid'),
    _ => const PlanUnsupported(),
  };

  bool _matches(PlanSlashItem item) =>
      _query.isEmpty ||
      slashLabel(context, item).toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final sections = <(String, List<PlanSlashItem>)>[
      (context.tr('planSlashStyle'), PlanSlashItem.styleSection),
      (context.tr('planSlashMedia'), PlanSlashItem.mediaSection),
      (context.tr('planSlashOther'), PlanSlashItem.otherSection),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dswEnsureShadTheme(
          context,
          ShadInput(
            controller: _filterController,
            autofocus: true,
            placeholder: dswInputHint(
              context.tr('planSlashPlaceholder'),
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
            style: DswType.s14,
            onChanged: (text) => setState(() => _query = text.toLowerCase()),
          ),
        ),
        const SizedBox(height: DswShape.sm),
        for (final (title, items) in sections) ...[
          if (items.any(_matches)) ...[
            Text(
              title,
              style: DswType.xxsStrong12.copyWith(color: color.labelTertiary),
            ),
            const SizedBox(height: DswShape.xs),
            Wrap(
              spacing: DswShape.xs,
              runSpacing: DswShape.xs,
              children: [
                for (final item in items)
                  if (_matches(item))
                    DswHoverTap(
                      onTap: () => Navigator.of(context).pop(item.name),
                      semanticLabel: slashLabel(context, item),
                      builder: (context, hovered, focused) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DswShape.sm,
                          vertical: DswShape.xs,
                        ),
                        decoration: BoxDecoration(
                          color: hovered
                              ? color.interactiveBgHover
                              : color.bgLayer2,
                          borderRadius: BorderRadius.circular(DswShape.inner),
                          border: Border.all(color: color.borderL2),
                        ),
                        child: Text(
                          slashLabel(context, item),
                          style: DswType.xs13.copyWith(
                            color: color.labelPrimary,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: DswShape.md),
          ],
        ],
        if (_query.isEmpty) ...[
          Text(
            context.tr('planSlashObjectsEmpty'),
            style: DswType.xs13.copyWith(color: color.labelTertiary),
          ),
          const SizedBox(height: DswShape.xs),
          Text(
            context.tr('planSlashPropertiesEmpty'),
            style: DswType.xs13.copyWith(color: color.labelTertiary),
          ),
        ],
      ],
    );
  }
}

/// The URL field behind the link mark: one input, submit or button confirms.
class _LinkInput extends StatelessWidget {
  const _LinkInput({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final controller = TextEditingController();
    return dswEnsureShadTheme(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ShadInput(
            controller: controller,
            autofocus: true,
            placeholder: dswInputHint(
              'https://',
              style: DswType.xs13.copyWith(color: color.labelTertiary),
            ),
            style: DswType.s14,
            onSubmitted: onSubmitted,
          ),
          const SizedBox(height: DswShape.sm),
          ShadButton(
            onPressed: () => onSubmitted(controller.text.trim()),
            child: Text(context.tr('planSave')),
          ),
        ],
      ),
    );
  }
}
