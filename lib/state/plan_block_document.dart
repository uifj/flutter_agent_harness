// The plan note's in-memory document (ADR-0037 P5). Markdown stays the only
// on-disk format (`plan_markdown_codec.dart` owns the round trip); this class
// owns the block tree the editor draws and edits, plus the two things the
// client gets from Anytype's server history by other means:
//
// - undo/redo is a local snapshot stack (upstream replays the server's
//   command history — `domain/page/Undo.kt`; this workspace has no core, so
//   the ledger lives here, registered as the brief's extension);
// - a text edit adjusts mark ranges itself, because a mark is a range over
//   the block's text and any caret edit shifts it.

import 'package:flutter/foundation.dart';

import '../model/plan_block.dart';
import '../model/plan_markdown_codec.dart';

/// Hands out successive `b<n>` ids above everything the tree already carries,
/// so a document and its duplicates mint without a global counter.
class _Minter {
  _Minter(List<PlanBlock> blocks) {
    for (final id in [for (final block in blocks) ...block.flattenedIds]) {
      final match = RegExp(r'^b(\d+)$').firstMatch(id);
      if (match != null) {
        final value = int.parse(match.group(1)!);
        if (value > _highest) _highest = value;
      }
    }
  }

  int _highest = 0;

  String next() => 'b${++_highest}';
}

class PlanBlockDocument extends ChangeNotifier {
  PlanBlockDocument.fromMarkdown(String source, {int undoDepth = 50})
    : _undoDepth = undoDepth,
      _blocks = decodePlanMarkdown(source);

  final int _undoDepth;
  int revision = 0;

  List<PlanBlock> _blocks;
  List<PlanBlock> get blocks => _blocks;

  final List<List<PlanBlock>> _undoStack = [];
  final List<List<PlanBlock>> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// The on-disk answer: re-encodes the tree the way the codec guarantees —
  /// what cannot be expressed comes back as the raw lines it was read from.
  String encode() => encodePlanMarkdown(_blocks);

  // ---- tree helpers -------------------------------------------------------

  ({List<PlanBlock> siblings, int index, PlanBlock block})? _locate(
    List<PlanBlock> tree,
    String blockId,
  ) {
    for (var i = 0; i < tree.length; i++) {
      if (tree[i].id == blockId) {
        return (siblings: tree, index: i, block: tree[i]);
      }
      final found = _locate(tree[i].children, blockId);
      if (found != null) return found;
    }
    return null;
  }

  PlanBlock? block(String blockId) => _locate(_blocks, blockId)?.block;

  /// Rewrites one block in place inside the working tree — the shared shape of
  /// every op that changes a single block.
  void _edit(String blockId, PlanBlock Function(PlanBlock block) change) =>
      _mutate((working, mint) {
        final found = _locate(working, blockId);
        if (found == null) return;
        found.siblings[found.index] = change(found.block);
      });

  /// Rewrites one text block's content.
  void _editText(String blockId, PlanText Function(PlanText content) change) =>
      _edit(blockId, (block) {
        final content = block.content;
        if (content is! PlanText) return block;
        return block.copyWith(content: change(content));
      });

  static PlanText _textContent(
    PlanText content, {
    String? text,
    PlanTextStyle? style,
    List<PlanMark>? marks,
    String? color,
    String? background,
    PlanAlign? align,
    bool? checked,
  }) => PlanText(
    text: text ?? content.text,
    style: style ?? content.style,
    marks: marks ?? content.marks,
    color: color,
    background: background,
    align: align ?? content.align,
    checked: checked ?? content.checked,
    iconEmoji: content.iconEmoji,
  );

  // ---- ledger -------------------------------------------------------------

  void _commit() {
    revision++;
    notifyListeners();
  }

  void _mutate(void Function(List<PlanBlock> working, _Minter mint) edit) {
    final snapshot = _clone(_blocks);
    final working = _clone(_blocks);
    edit(working, _Minter(working));
    _undoStack.add(snapshot);
    if (_undoStack.length > _undoDepth) _undoStack.removeAt(0);
    _redoStack.clear();
    _blocks = working;
    _commit();
  }

  static List<PlanBlock> _clone(List<PlanBlock> blocks) => [
    for (final block in blocks)
      PlanBlock(
        id: block.id,
        content: block.content,
        children: _clone(block.children),
      ),
  ];

  /// The snapshot keeps the same ids, so a scroll position survives undo.
  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_blocks);
    _blocks = _undoStack.removeLast();
    _commit();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_blocks);
    _blocks = _redoStack.removeLast();
    _commit();
  }

  // ---- text ---------------------------------------------------------------

  /// Replaces a text block's content, shifting and clipping its marks the way
  /// the range arithmetic demands: a mark never outlives the text it styled.
  void editText(String blockId, String text) => _editText(blockId, (content) {
    if (content.text == text) return content;
    final oldText = content.text;
    var prefix = 0;
    while (prefix < oldText.length &&
        prefix < text.length &&
        oldText[prefix] == text[prefix]) {
      prefix++;
    }
    var oldSuffix = oldText.length;
    var newSuffix = text.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText[oldSuffix - 1] == text[newSuffix - 1]) {
      oldSuffix--;
      newSuffix--;
    }
    final delta = newSuffix - oldSuffix;
    PlanMarkRange shifted(PlanMarkRange range) {
      final start = range.start >= oldSuffix
          ? range.start + delta
          : (range.start <= prefix ? range.start : prefix);
      final end = range.end <= prefix
          ? range.end
          : (range.end >= oldSuffix ? range.end + delta : newSuffix);
      return PlanMarkRange(start, end > start ? end : start);
    }

    return _textContent(
      content,
      text: text,
      marks: [
        for (final mark in content.marks)
          PlanMark(
            range: shifted(mark.range),
            type: mark.type,
            param: mark.param,
          ),
      ].where((mark) => mark.range.end > mark.range.start).toList(),
    );
  });

  void toggleCheckbox(String blockId) => _editText(
    blockId,
    (content) => _textContent(content, checked: !(content.checked ?? false)),
  );

  void turnInto(String blockId, PlanTextStyle style) =>
      _editText(blockId, (content) {
        if (content.style == style) return content;
        // The checkbox state belongs to the checkbox row: another style drops
        // it (explicitly — this op must be able to clear), checkbox takes it.
        return PlanText(
          text: content.text,
          style: style,
          marks: content.marks,
          color: content.color,
          background: content.background,
          align: content.align,
          checked: style == PlanTextStyle.checkbox
              ? (content.checked ?? false)
              : null,
          iconEmoji: content.iconEmoji,
        );
      });

  void setAlign(String blockId, PlanAlign align) =>
      _editText(blockId, (content) => _textContent(content, align: align));

  /// Text colour and background take a `ThemeColor` name; null clears.
  void setTextColor(String blockId, String? name) =>
      _editText(blockId, (content) => _textContent(content, color: name));

  void setTextBackground(String blockId, String? name) =>
      _editText(blockId, (content) => _textContent(content, background: name));

  // ---- marks --------------------------------------------------------------

  /// Applies a mark over the range, replacing the same type where it overlaps
  /// — one mark type, one span per stretch, the shape `filterByRange` upstream
  /// leaves the model in (`MapperExtension.kt:392-415`).
  void applyMark(
    String blockId,
    PlanMarkType type,
    PlanMarkRange range, {
    String? param,
  }) => _editText(blockId, (content) {
    final kept = [
      for (final mark in content.marks)
        if (!_sameTypeOverlapping(mark, type, range)) mark,
      PlanMark(range: range, type: type, param: param),
    ];
    kept.sort((a, b) => a.range.start.compareTo(b.range.start));
    return _textContent(content, marks: kept);
  });

  void clearMarks(String blockId, PlanMarkType type, PlanMarkRange range) =>
      _editText(
        blockId,
        (content) => _textContent(
          content,
          marks: [
            for (final mark in content.marks)
              if (!_sameTypeOverlapping(mark, type, range)) mark,
          ],
        ),
      );

  static bool _sameTypeOverlapping(
    PlanMark mark,
    PlanMarkType type,
    PlanMarkRange range,
  ) =>
      mark.type == type &&
      mark.range.start < range.end &&
      range.start < mark.range.end;

  // ---- structure ----------------------------------------------------------

  /// Inserts below [afterId] (or at the end when null) and returns the new id.
  /// The anchor is searched across every sibling list, so the block lands in
  /// the same nesting level as the anchor.
  String insertBelow(String? afterId, PlanBlockContent content) {
    var newId = '';
    _mutate((working, mint) {
      newId = mint.next();
      final block = PlanBlock(id: newId, content: content);
      if (afterId != null) {
        for (final siblings in _siblingLists(working)) {
          final index = siblings.indexWhere((entry) => entry.id == afterId);
          if (index >= 0) {
            siblings.insert(index + 1, block);
            return;
          }
        }
      }
      working.add(block);
    });
    return newId;
  }

  static List<List<PlanBlock>> _siblingLists(List<PlanBlock> blocks) => [
    blocks,
    for (final block in blocks) ..._siblingLists(block.children),
  ];

  void delete(String blockId) => _mutate((working, mint) {
    void remove(List<PlanBlock> list) {
      list.removeWhere((entry) => entry.id == blockId);
      for (final child in list) {
        remove(child.children);
      }
    }

    remove(working);
  });

  /// A duplicate is a fresh subtree: same content, all-new ids, minted
  /// depth-first, inserted right below the original.
  void duplicate(String blockId) => _mutate((working, mint) {
    final found = _locate(working, blockId);
    if (found == null) return;
    PlanBlock copy(PlanBlock source) => PlanBlock(
      id: mint.next(),
      content: source.content,
      children: [for (final child in source.children) copy(child)],
    );
    found.siblings.insert(found.index + 1, copy(found.block));
  });

  /// Moves a root-level block one slot up or down — the drag's cheap answer
  /// for the first increment (full three-zone dragging rides on top of this).
  void moveRoot(String blockId, {required bool up}) => _mutate((working, mint) {
    final index = working.indexWhere((entry) => entry.id == blockId);
    if (index < 0) return;
    final target = up ? index - 1 : index + 1;
    if (target < 0 || target >= working.length) return;
    final moved = working.removeAt(index);
    working.insert(target, moved);
  });

  // ---- table --------------------------------------------------------------

  /// The table run a row belongs to: consecutive root-level table rows
  /// (`plan_markdown_codec.dart` decodes a markdown table into exactly this
  /// shape, the first row carrying `isHeader`).
  List<PlanBlock> _tableRun(List<PlanBlock> working, String rowId) {
    final run = <PlanBlock>[];
    for (final block in working) {
      if (block.content is PlanTableBlock) {
        run.add(block);
      } else if (run.isNotEmpty) {
        break;
      }
    }
    return run.any((block) => block.id == rowId) ? run : const [];
  }

  void tableInsertRow(String rowId, {required bool below}) =>
      _mutate((working, mint) {
        final run = _tableRun(working, rowId);
        if (run.isEmpty) return;
        final columns = run.first.children.length;
        final anchor = working.indexWhere((entry) => entry.id == rowId);
        if (anchor < 0) return;
        working.insert(
          below ? anchor + 1 : anchor,
          PlanBlock(
            id: mint.next(),
            content: const PlanTableBlock(),
            children: [
              for (var i = 0; i < columns; i++)
                PlanBlock(
                  id: mint.next(),
                  content: const PlanText(text: ''),
                ),
            ],
          ),
        );
      });

  void tableDeleteRow(String rowId) => _mutate((working, mint) {
    if (_tableRun(working, rowId).length <= 1) return;
    working.removeWhere((entry) => entry.id == rowId);
  });

  void tableMoveRow(String rowId, {required bool up}) =>
      _mutate((working, mint) {
        final run = _tableRun(working, rowId);
        final index = run.indexWhere((entry) => entry.id == rowId);
        final target = up ? index - 1 : index + 1;
        if (index < 0 || target < 0 || target >= run.length) return;
        final from = working.indexWhere((entry) => entry.id == rowId);
        final moved = working.removeAt(from);
        final to = working.indexWhere((entry) => entry.id == run[target].id);
        working.insert(to + (up ? 0 : 1), moved);
      });

  void tableClearRow(String rowId) => _mutate((working, mint) {
    final index = working.indexWhere((entry) => entry.id == rowId);
    if (index < 0) return;
    working[index] = working[index].copyWith(
      children: [
        for (final cell in working[index].children)
          PlanBlock(
            id: cell.id,
            content: cell.content is PlanText
                ? const PlanText(text: '')
                : cell.content,
          ),
      ],
    );
  });

  void tableInsertColumn(String rowId, {required bool left}) =>
      _mutate((working, mint) {
        final run = _tableRun(working, rowId);
        if (run.isEmpty) return;
        final cellIndex = left ? 0 : run.first.children.length;
        for (final row in run) {
          final i = working.indexWhere((entry) => entry.id == row.id);
          working[i] = row.copyWith(
            children: [
              ...row.children.take(cellIndex),
              PlanBlock(
                id: mint.next(),
                content: const PlanText(text: ''),
              ),
              ...row.children.skip(cellIndex),
            ],
          );
        }
      });

  void tableDeleteColumn(String rowId, int cellIndex) =>
      _mutate((working, mint) {
        final run = _tableRun(working, rowId);
        if (run.isEmpty || run.first.children.length <= 1) return;
        for (final row in run) {
          final i = working.indexWhere((entry) => entry.id == row.id);
          working[i] = row.copyWith(
            children: [
              for (var c = 0; c < row.children.length; c++)
                if (c != cellIndex) row.children[c],
            ],
          );
        }
      });
}
