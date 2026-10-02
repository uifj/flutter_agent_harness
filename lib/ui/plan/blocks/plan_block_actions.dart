// Block actions and the table row menu (ADR-0037 P5). The assembly follows
// upstream's conditional rules (`EditorViewModel.kt:2510-2624`): entries drop
// out per block shape, and the three dead-code actions the inventory recorded
// (Column.Sort, Column.Copy, Row.Copy — defined upstream, never wired into the
// UI) are not offered here either.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/services.dart';

import '../../../l10n/locales.dart';
import '../../../model/plan_block.dart';
import '../../../model/plan_markdown_codec.dart';
import '../../../state/plan_block_document.dart';
import '../../primitives/menu.dart';
import '../../primitives/tappable.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';

/// The block menu a block's gutter offers. Turn-into and styling ride the
/// slash menu / markup toolbar — this menu is the structural answer. Copy /
/// Paste are the internal block clipboard (AC3-19's first increment); the
/// system-clipboard interop upstream layers on top does not exist here yet.
/// The system clipboard carries the block as Markdown text (upstream layers
/// a system clipboard beside the internal block store — `AnytypeClipboard.kt:17-41`),
/// so a copy lands in another app and a paste can come from one. The internal
/// clipboard still wins when it holds blocks: that keeps the lossless envelope
/// round trip for what Markdown cannot carry.
Future<void> pasteFromClipboards(
  PlanBlockDocument document,
  String afterId,
) async {
  if (PlanBlockClipboard.hasContent) {
    document.pasteBlocks(afterId, PlanBlockClipboard.take());
    return;
  }
  final data = await Clipboard.getData('text/plain');
  final source = data?.text;
  if (source == null || source.trim().isEmpty) return;
  pasteFromText(document, afterId, source);
}

/// The testable seam under the clipboard read: external Markdown/ text
/// decodes through the codec and lands as fresh-id blocks. The channel glue
/// above is the only untested line (the test binding keeps no clipboard
/// data to read back).
void pasteFromText(PlanBlockDocument document, String afterId, String source) {
  final blocks = decodePlanMarkdown(source);
  if (blocks.isEmpty) return;
  // A trailing blank line decodes as a paragraph block; pasting "a\n" would
  // land two blocks. Trim the purely-empty tail so the paste carries what
  // the user selected, not the newline that came with it.
  while (blocks.isNotEmpty &&
      blocks.last.content is PlanText &&
      (blocks.last.content as PlanText).text.isEmpty) {
    blocks.removeLast();
  }
  if (blocks.isEmpty) return;
  document.pasteBlocks(afterId, blocks);
}

List<DswMenuEntry> planBlockActions(
  BuildContext context,
  PlanBlockDocument document,
  PlanBlock block,
) => [
  DswMenuEntry(
    label: context.tr('planActionCopy'),
    icon: LucideIcons.copy,
    onTap: () {
      PlanBlockClipboard.copy(block);
      Clipboard.setData(ClipboardData(text: encodePlanMarkdown([block])));
    },
  ),
  DswMenuEntry(
    label: context.tr('planActionPaste'),
    icon: LucideIcons.clipboard_paste,
    onTap: () => pasteFromClipboards(document, block.id),
  ),
  DswMenuEntry(
    label: context.tr('planActionDuplicate'),
    icon: LucideIcons.copy_plus,
    onTap: () => document.duplicate(block.id),
  ),
  DswMenuEntry(
    label: context.tr('planActionDelete'),
    icon: LucideIcons.trash,
    destructive: true,
    onTap: () => document.delete(block.id),
  ),
];

/// The table row menu — Cell/Row/Column tabs upstream collapse here into the
/// row-shaped answer a markdown table can take. Sort and copy are the two
/// upstream dead-code actions and are deliberately absent.
List<DswMenuEntry> planTableRowActions(
  BuildContext context,
  PlanBlockDocument doc,
  String rowId,
) => [
  DswMenuEntry(
    label: context.tr('planTableInsertAbove'),
    icon: LucideIcons.arrow_up,
    onTap: () => doc.tableInsertRow(rowId, below: false),
  ),
  DswMenuEntry(
    label: context.tr('planTableInsertBelow'),
    icon: LucideIcons.arrow_down,
    onTap: () => doc.tableInsertRow(rowId, below: true),
  ),
  DswMenuEntry(
    label: context.tr('planTableMoveUp'),
    icon: LucideIcons.chevron_up,
    onTap: () => doc.tableMoveRow(rowId, up: true),
  ),
  DswMenuEntry(
    label: context.tr('planTableMoveDown'),
    icon: LucideIcons.chevron_down,
    onTap: () => doc.tableMoveRow(rowId, up: false),
  ),
  DswMenuEntry(
    label: context.tr('planTableDuplicate'),
    icon: LucideIcons.copy,
    onTap: () => doc.duplicate(rowId),
  ),
  DswMenuEntry(
    label: context.tr('planTableClear'),
    icon: LucideIcons.eraser,
    onTap: () => doc.tableClearRow(rowId),
  ),
  DswMenuEntry(
    label: context.tr('planTableDelete'),
    icon: LucideIcons.trash,
    destructive: true,
    onTap: () => doc.tableDeleteRow(rowId),
  ),
];

/// The column menu a header cell offers — the Cell/Row/Column tab trio
/// collapses into row-shaped (above) and column-shaped (here) answers, since
/// a markdown table can only carry those two dimensions. Delete drops out at
/// one column rather than shipping a no-op entry.
List<DswMenuEntry> planTableColumnActions(
  BuildContext context,
  PlanBlockDocument doc,
  String rowId,
  int cellIndex,
) => [
  DswMenuEntry(
    label: context.tr('planTableInsertLeft'),
    icon: LucideIcons.arrow_left,
    onTap: () => doc.tableInsertColumn(rowId, left: true),
  ),
  DswMenuEntry(
    label: context.tr('planTableInsertRight'),
    icon: LucideIcons.arrow_right,
    onTap: () => doc.tableInsertColumn(rowId, left: false),
  ),
  if (doc.tableColumnCount(rowId) > 1)
    DswMenuEntry(
      label: context.tr('planTableDeleteColumn'),
      icon: LucideIcons.trash,
      destructive: true,
      onTap: () => doc.tableDeleteColumn(rowId, cellIndex),
    ),
];

/// The icon-only trigger that opens a context menu on tap — every icon-only
/// control names itself (`app_frame_test`'s rule).
class PlanMenuTrigger extends StatelessWidget {
  const PlanMenuTrigger({
    super.key,
    required this.semanticLabel,
    required this.items,
    this.icon,
  });

  final String semanticLabel;
  final List<DswMenuEntry> items;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswContextMenu(
      items: (_) => items,
      child: DswHoverTap(
        onTap: null,
        semanticLabel: semanticLabel,
        builder: (context, hovered, focused) => Padding(
          padding: const EdgeInsets.only(left: DswShape.xs, top: DswShape.xs),
          child: Icon(
            icon ?? LucideIcons.ellipsis_vertical,
            size: DswShape.iconTiny,
            color: color.labelTertiary,
          ),
        ),
      ),
    );
  }
}
