// 本文件守住的那句话：企划笔记的盘上格式只有 Markdown 一种，块树只是它的内存形状，
// 而块树照抄的是 Anytype **能到达** 的那部分。
//
// ADR-0037 D3 有两半：round-trip 稳定（编辑一次块再存盘，文件不能长出自造语法），
// 以及可达性诚实（14 种样式里用户能插 11 种——"Title" 是 H1、"Highlighted" 是
// QUOTE（SlashExtensions.kt:22-33 → MapperExtension.kt:417-438，2026-10-01 回档
// 更正了早批审计对 QUOTE 的 ⛔ 误记）、TITLE/H4/DESCRIPTION 无插入路径、
// 24 种 embed 存在但一种都不内嵌渲染、`JUSTIFY` 存在但被映射回起点）。
// 这一棵树同时钉住两半：往返用固定文档断言，可达性用枚举断言。
// 若有人为了让测试通过而给不可达档位加插入路径，第二条 group 会当场指出他与上游不一致。

import 'package:flutter_test/flutter_test.dart';

import 'package:planstar/model/plan_block.dart';
import 'package:planstar/model/plan_markdown_codec.dart';

const _document = '''
# Title

A paragraph with **bold** and *italic* and `code` and [a link](https://anytype.io).

- bullet one
1. numbered one
- [x] done thing
- [ ] open thing

> quoted line

---

***

```
code body
```

## Table

| Name | Status |
| --- | --- |
| Alpha | doing |

![photo](file:///a.png)

<details>html passthrough</details>
''';

void main() {
  group('the file is the only disk format', () {
    test('a note survives decode → encode unchanged', () {
      final blocks = decodePlanMarkdown(_document);
      // Byte-for-byte, trailing newline included: a save must not reformat.
      expect(encodePlanMarkdown(blocks), _document);
    });

    test('encoding is idempotent, so a save never grows the file', () {
      final once = encodePlanMarkdown(decodePlanMarkdown(_document));
      final twice = encodePlanMarkdown(decodePlanMarkdown(once));
      expect(twice, once);
    });

    test('styles, marks and lists come back as the same block kinds', () {
      final blocks = decodePlanMarkdown(_document);
      // Blank lines are paragraph blocks too; the assertion wants the one
      // with content in it.
      PlanText? firstOf(PlanTextStyle style) {
        for (final block in blocks) {
          final content = block.content;
          if (content is PlanText &&
              content.style == style &&
              content.text.isNotEmpty) {
            return content;
          }
        }
        return null;
      }

      expect(firstOf(PlanTextStyle.h1)?.text, 'Title');
      expect(firstOf(PlanTextStyle.h2)?.text, 'Table');
      expect(firstOf(PlanTextStyle.bullet)?.text, 'bullet one');
      expect(firstOf(PlanTextStyle.numbered)?.text, 'numbered one');
      expect(firstOf(PlanTextStyle.checkbox)?.checked, isTrue);
      expect(firstOf(PlanTextStyle.quote)?.text, 'quoted line');
      expect(firstOf(PlanTextStyle.codeSnippet)?.text, 'code body');

      final paragraph = firstOf(PlanTextStyle.paragraph)!;
      final kinds = {for (final mark in paragraph.marks) mark.type};
      expect(kinds, {
        PlanMarkType.bold,
        PlanMarkType.italic,
        PlanMarkType.keyboard,
        PlanMarkType.link,
      });
      final link = paragraph.marks.firstWhere(
        (m) => m.type == PlanMarkType.link,
      );
      expect(link.param, 'https://anytype.io');
      // The marker characters are not part of the text the editor shows.
      expect(paragraph.text, contains('a link'));
      expect(paragraph.text, isNot(contains('**')));
    });

    test(
      'a table row keeps its cells and the header separator is consumed',
      () {
        final blocks = decodePlanMarkdown(_document);
        final rows = blocks
            .where((block) => block.content is PlanTableBlock)
            .toList();
        expect(rows.length, 2);
        expect((rows.first.content as PlanTableBlock).isHeader, isTrue);
        expect((rows.last.content as PlanTableBlock).isHeader, isFalse);
        expect(
          [
            for (final cell in rows.first.children)
              (cell.content as PlanText).text,
          ],
          ['Name', 'Status'],
        );
        expect(encodePlanMarkdown(rows), contains('| --- | --- |'));
      },
    );

    test('an image line is a file block and the rest stays literal', () {
      final blocks = decodePlanMarkdown(_document);
      final files = blocks.where((block) => block.content is PlanFile).toList();
      expect(files.length, 1);
      final file = files.first.content as PlanFile;
      expect(file.kind, PlanFileKind.image);
      expect(file.target, 'file:///a.png');
      expect(file.state, PlanFileState.done);

      final encoded = encodePlanMarkdown(blocks);
      expect(encoded, contains('<details>html passthrough</details>'));
    });

    test('dividers keep their two styles', () {
      final blocks = decodePlanMarkdown(_document);
      final dividers = [
        for (final block in blocks)
          if (block.content is PlanDivider)
            (block.content as PlanDivider).style,
      ];
      expect(dividers, [PlanDividerStyle.line, PlanDividerStyle.dots]);
    });

    test('a math fence is a latex block', () {
      const source = '\$\$\nE = mc^2\n\$\$';
      final blocks = decodePlanMarkdown(source);
      expect(blocks.single.content, isA<PlanLatex>());
      expect((blocks.single.content as PlanLatex).source, 'E = mc^2');
      expect(encodePlanMarkdown(blocks), source);
    });

    test('json round-trips the block tree, marks included', () {
      final blocks = decodePlanMarkdown(_document);
      final decoded = [
        for (final entry in blocks.map((b) => b.toJson()))
          PlanBlock.fromJson(entry.cast<String, Object?>()),
      ];
      expect(encodePlanMarkdown(decoded), encodePlanMarkdown(blocks));
      expect(
        decoded.map((block) => block.flattenedIds.length),
        blocks.map((block) => block.flattenedIds.length),
      );
    });
  });

  group('reachability is the upstream answer, not an improvement', () {
    test('fourteen styles exist, eleven are insertable via the slash menu, '
        'title/h4/description are not', () {
      expect(PlanTextStyle.values.length, 14);
      expect(PlanTextStyle.insertable.length, 11);
      expect(PlanTextStyle.insertable, contains(PlanTextStyle.quote));
      expect(PlanTextStyle.insertable, contains(PlanTextStyle.h1));
      expect(PlanTextStyle.insertable, isNot(contains(PlanTextStyle.title)));
      expect(PlanTextStyle.insertable, isNot(contains(PlanTextStyle.h4)));
      expect(
        PlanTextStyle.insertable,
        isNot(contains(PlanTextStyle.description)),
      );
      expect(PlanTextStyle.h4.isHeading, isTrue);
      expect(PlanTextStyle.bullet.supportsAlignment, isFalse);
      expect(PlanTextStyle.paragraph.supportsAlignment, isTrue);
      // HIGHLIGHT only gets left/right — no centre (SlashExtensions.kt:122).
      expect(PlanTextStyle.quote.supportsAlignment, isTrue);
      expect(PlanTextStyle.quote.supportsCenterAlignment, isFalse);
      expect(PlanTextStyle.callout.supportsAlignment, isTrue);
      expect(PlanTextStyle.callout.supportsCenterAlignment, isTrue);
    });

    test('eleven marks exist and the toolbar exposes eight', () {
      expect(PlanMarkType.values.length, 11);
      expect(PlanMarkType.toolbarReachable.length, 8);
      expect(PlanMarkType.mention.isClickable, isTrue);
      expect(PlanMarkType.bold.isClickable, isFalse);
      expect(
        PlanMarkType.toolbarReachable,
        isNot(contains(PlanMarkType.mention)),
      );
    });

    test('justify is stored but never offered, matching the client', () {
      expect(PlanAlign.values.length, 4);
      expect(PlanAlign.justify.isInsertable, isFalse);
    });

    test('the colour ladder is the eleven-stop one', () {
      expect(PlanThemeColors.names.length, 11);
      expect(PlanThemeColors.indexOf('blue'), 7);
      expect(PlanThemeColors.indexOf('nope'), -1);
    });

    test('twenty-four embeds, none rendered inline, fifteen needing a url', () {
      expect(PlanEmbedProcessor.values.length, 24);
      expect(PlanEmbedProcessor.values.where((p) => p.rendersInline), isEmpty);
      expect(PlanEmbedProcessor.values.where((p) => p.needsUrl).length, 15);
      expect(PlanEmbedProcessor.mermaid.needsUrl, isFalse);
      expect(PlanEmbedProcessor.spotify.code, 24);
    });

    test(
      'only image, video and audio open in app — there is no pdf viewer',
      () {
        expect(PlanFileKind.values.length, 6);
        expect(
          PlanFileKind.values.where((kind) => kind.hasOwnViewer).length,
          3,
        );
        expect(PlanFileKind.pdf.hasOwnViewer, isFalse);
      },
    );

    test('layout containers are flattened except the table pair', () {
      expect(PlanLayoutType.values.length, 6);
      expect(PlanLayoutType.row.isStructural, isFalse);
      expect(PlanLayoutType.tableRow.isStructural, isTrue);
    });

    test(
      'the slash vocabulary has the two upstream-commented entries absent',
      () {
        final names = {for (final item in PlanSlashItem.values) item.name};
        expect(names, isNot(contains('propertyNew')));
        expect(names, isNot(contains('cleanStyle')));
        expect(PlanSlashItem.insertableActions.length, 6);
        expect(PlanSlashItem.styleSection.length, 10);
        expect(PlanSlashItem.mediaSection.length, 5);
        expect(PlanSlashItem.otherSection.length, 4);
        expect(
          PlanSlashItem.textStyleFor(PlanSlashItem.styleTitle),
          PlanTextStyle.h1,
        );
        expect(
          PlanSlashItem.textStyleFor(PlanSlashItem.styleHeading),
          PlanTextStyle.h2,
        );
        // The slash item named "Highlighted" is how users reach QUOTE
        // (SlashExtensions.kt:27 → MapperExtension.kt:422).
        expect(
          PlanSlashItem.textStyleFor(PlanSlashItem.styleHighlighted),
          PlanTextStyle.quote,
        );
      },
    );

    test('table(NxM) parses and clamps to 1..25 like the sheet does', () {
      expect(PlanSlashItem.parseTablePattern('table(3x4)'), (
        rows: 3,
        columns: 4,
      ));
      expect(PlanSlashItem.parseTablePattern('table(99x0)'), (
        rows: 25,
        columns: 1,
      ));
      expect(PlanSlashItem.parseTablePattern('table'), (rows: 1, columns: 1));
    });

    test('a mark shifts with inserted text and json survives', () {
      const mark = PlanMark(
        range: PlanMarkRange(2, 6),
        type: PlanMarkType.bold,
      );
      expect(mark.shift(3).range, const PlanMarkRange(5, 9));
      expect(PlanMark.fromJson(mark.toJson()).range, mark.range);
    });
  });
}
