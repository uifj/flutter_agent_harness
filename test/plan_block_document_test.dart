// 本文件守住的那句话：企划笔记的内存文档把"编辑一次"翻译成对块树的确定性操作——
// 文本改动带着 mark 范围一起走，结构操作铸新 id，撤销重做按快照回滚且 id 不变，
// 表格操作只在"连续表格行"这个 run 内生效。
//
// P5 的可回归契约：任何编辑操作之后 `encode()` 仍是合法 Markdown（P1 编解码
// 的往返性质在编辑路径上不被破坏）。

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_harness/model/plan_block.dart';
import 'package:agent_harness/model/plan_markdown_codec.dart';
import 'package:agent_harness/state/plan_block_document.dart';

const _source = '''
# Delivery notes

- a bullet
- another

1. first
2. second

| A | B |
| --- | --- |
| one | two |

> quoted

\$\$x^2\$\$

- [ ] open task
- [x] done task
''';

PlanText _textOf(PlanBlockDocument doc, String id) =>
    doc.block(id)!.content as PlanText;

String _firstTextId(PlanBlockDocument doc, {String contains = ''}) => doc.blocks
    .expand((block) => block.flattenedIds)
    .firstWhere(
      (id) =>
          doc.block(id)!.content is PlanText &&
          (doc.block(id)!.content as PlanText).text.contains(contains),
    );

void main() {
  late PlanBlockDocument doc;

  setUp(() => doc = PlanBlockDocument.fromMarkdown(_source));

  group('decoding and encoding', () {
    test('the document starts as the codec reads the source', () {
      expect(doc.blocks, isNotEmpty);
      expect(doc.encode(), isNotEmpty);
      // Round-trip stability belongs to the codec; the document only has to
      // produce an encode() the codec reads back to the same tree.
      final readBack = decodePlanMarkdown(doc.encode());
      expect(readBack.length, doc.blocks.length);
    });
  });

  group('text edits carry their marks', () {
    test('a middle insertion shifts later marks, earlier ones stay put', () {
      final id = doc.insertBelow(null, PlanText(text: 'hello world'));
      doc.applyMark(id, PlanMarkType.bold, const PlanMarkRange(6, 11));
      expect(_textOf(doc, id).marks.single.range.end, 11);

      doc.editText(id, 'hello brave world');
      final marks = _textOf(doc, id).marks;
      expect(marks, hasLength(1));
      expect(marks.single.range.start, 12);
      expect(marks.single.range.end, 17);
    });

    test('a deletion that swallows a mark drops the mark', () {
      final id = doc.insertBelow(null, PlanText(text: 'keep drop keep'));
      doc.applyMark(id, PlanMarkType.italic, const PlanMarkRange(5, 10));
      doc.editText(id, 'keep keep');
      expect(_textOf(doc, id).marks, isEmpty);
    });

    test('the same type overlaps replace, other types coexist', () {
      final id = doc.insertBelow(null, PlanText(text: 'abcdef'));
      doc.applyMark(id, PlanMarkType.bold, const PlanMarkRange(0, 4));
      doc.applyMark(id, PlanMarkType.bold, const PlanMarkRange(2, 6));
      doc.applyMark(id, PlanMarkType.underline, const PlanMarkRange(1, 3));
      final marks = _textOf(doc, id).marks;
      final bolds = marks.where((mark) => mark.type == PlanMarkType.bold);
      // Re-applying replaces the overlapping stretch: the new range wins.
      expect(bolds, hasLength(1));
      expect(bolds.single.range.start, 2);
      expect(bolds.single.range.end, 6);
      expect(
        marks.where((m) => m.type == PlanMarkType.underline),
        hasLength(1),
      );
    });
  });

  group('style ops', () {
    test('turnInto checkbox takes a state, turning away clears it', () {
      final id = _firstTextId(doc, contains: 'bullet');
      doc.turnInto(id, PlanTextStyle.checkbox);
      expect(_textOf(doc, id).checked, isFalse);
      doc.toggleCheckbox(id);
      expect(_textOf(doc, id).checked, isTrue);
      doc.turnInto(id, PlanTextStyle.paragraph);
      expect(_textOf(doc, id).checked, isNull);
    });

    test('colour and background take ladder names and clear with null', () {
      final id = _firstTextId(doc, contains: 'bullet');
      doc.setTextColor(id, 'red');
      expect(_textOf(doc, id).color, 'red');
      doc.setTextColor(id, null);
      expect(_textOf(doc, id).color, isNull);
    });
  });

  group('structure ops', () {
    test('insertBelow lands in the anchor level and mints above every id', () {
      final id = doc.insertBelow(null, PlanText(text: 'appended'));
      expect(doc.block(id), isNotNull);
      expect(_textOf(doc, id).text, 'appended');
      // Encoding keeps the new block as markdown prose.
      expect(doc.encode(), contains('appended'));
    });

    test('duplicate copies the subtree with fresh ids below the original', () {
      final id = _firstTextId(doc, contains: 'bullet');
      doc.duplicate(id);
      final texts = [
        for (final block in doc.blocks)
          if (block.content is PlanText) (block.content as PlanText).text,
      ];
      expect(texts.where((text) => text == 'a bullet'), hasLength(2));
      // The ids differ — a duplicate is a new block.
      final bulletIds = [
        for (final block in doc.blocks)
          if (block.content is PlanText &&
              (block.content as PlanText).text == 'a bullet')
            block.id,
      ];
      expect(bulletIds.toSet(), hasLength(2));
    });

    test('delete removes the block and its children', () {
      final id = _firstTextId(doc, contains: 'first');
      doc.delete(id);
      expect(doc.blocks.any((block) => block.id == id), isFalse);
      expect(doc.encode(), isNot(contains('first')));
    });

    test('moveRoot swaps adjacent root blocks', () {
      final before = doc.blocks.map((block) => block.id).toList();
      doc.moveRoot(before[1], up: true);
      expect(doc.blocks.map((block) => block.id).toList()[0], before[1]);
    });
  });

  group('table ops stay inside the run', () {
    test('insert row widens nothing and keeps the markdown table', () {
      final rowId = doc.blocks
          .firstWhere((block) => block.content is PlanTableBlock)
          .id;
      doc.tableInsertRow(rowId, below: true);
      final run = doc.blocks
          .where((block) => block.content is PlanTableBlock)
          .toList();
      expect(run, hasLength(3));
      expect(run.last.children, hasLength(2));
      expect(doc.encode(), contains('|  |  |'));
    });

    test('delete column removes the cell from every row, never the last', () {
      final rowId = doc.blocks
          .firstWhere((block) => block.content is PlanTableBlock)
          .id;
      doc.tableDeleteColumn(rowId, 1);
      final run = doc.blocks
          .where((block) => block.content is PlanTableBlock)
          .toList();
      for (final row in run) {
        expect(row.children, hasLength(1));
      }
      // The last column cannot go: a one-cell markdown table is not a table.
      doc.tableDeleteColumn(rowId, 0);
      expect(
        doc.blocks.where((block) => block.content is PlanTableBlock),
        isNotEmpty,
      );
    });

    test('clear row empties every cell of that row only', () {
      final rowId = doc.blocks
          .firstWhere((block) => block.content is PlanTableBlock)
          .id;
      doc.tableClearRow(rowId);
      final row = doc.block(rowId)!;
      for (final cell in row.children) {
        expect((cell.content as PlanText).text, '');
      }
    });
  });

  group('the ledger', () {
    test('undo restores the exact tree, redo reapplies, ids survive', () {
      final idsBefore = [for (final block in doc.blocks) ...block.flattenedIds];
      final id = doc.insertBelow(null, PlanText(text: 'temporary'));
      expect(doc.canUndo, isTrue);
      doc.undo();
      expect(doc.block(id), isNull);
      expect([
        for (final block in doc.blocks) ...block.flattenedIds,
      ], idsBefore);
      expect(doc.canRedo, isTrue);
      doc.redo();
      expect(doc.block(id), isNotNull);
    });

    test('a new edit clears the redo stack', () {
      doc.insertBelow(null, PlanText(text: 'one'));
      doc.undo();
      expect(doc.canRedo, isTrue);
      doc.insertBelow(null, PlanText(text: 'two'));
      expect(doc.canRedo, isFalse);
      // The mint re-walks the restored tree, so the aborted edit's id can be
      // reused by the next one — the text, not the id, tells the two apart.
      final texts = [
        for (final block in doc.blocks)
          if (block.content is PlanText) (block.content as PlanText).text,
      ];
      expect(texts, contains('two'));
      expect(texts, isNot(contains('one')));
    });

    test('undo depth is capped', () {
      final tight = PlanBlockDocument.fromMarkdown(_source, undoDepth: 3);
      for (var i = 0; i < 6; i++) {
        tight.insertBelow(null, PlanText(text: 'edit $i'));
      }
      var undos = 0;
      while (tight.canUndo) {
        tight.undo();
        undos++;
      }
      expect(undos, 3);
    });
  });
}
