// 本文件守住的那句话：编辑器能造出来的每一块，保存后都还在——Markdown 词汇
// 装不下的块走 `<!-- plan:{json} -->` 信封（合法 Markdown、渲染为空、重开原样
// 还原），而不是消失或写出 `![null]()` 垃圾行。
//
// 2026-10-01 审计发现的第一批数据丢失：Bookmark/TOC/Embed/Link/Widget 保存即
// 消失（default: return ''）、空 File 写 ![null]()、空 checkbox 行被吞、
// 块级颜色/背景/对齐/iconEmoji/Toggle/Callout/Title 样式与
// underline/textColor/backgroundColor mark 保存退化。信封是这批缺口的收口。

import 'package:flutter_test/flutter_test.dart';

import 'package:planstar/model/plan_block.dart';
import 'package:planstar/model/plan_markdown_codec.dart';
import 'package:planstar/model/plan_widget.dart';

void main() {
  /// Round-trip helper: encode, decode, and assert the shape survived.
  void expectSurvives(PlanBlock block, {String? needle}) {
    final md = encodePlanMarkdown([block]);
    if (needle != null) {
      expect(md, contains(needle), reason: '$block must be visible in the md');
    }
    expect(md.contains('null'), isFalse, reason: md);
    final readBack = decodePlanMarkdown(md);
    expect(readBack, hasLength(1), reason: md);
    final restored = readBack.single;
    expect(restored.content.runtimeType, block.content.runtimeType);
    // Re-encoding is stable: envelope → decode → encode is idempotent.
    expect(encodePlanMarkdown(readBack), md);
  }

  group('blocks markdown cannot express ride the envelope', () {
    test('a bookmark survives with its url', () {
      expectSurvives(
        const PlanBlock(
          id: 'b1',
          content: PlanBookmark(url: 'https://anytype.io'),
        ),
      );
    });

    test('an empty bookmark does not fabricate a link line', () {
      expectSurvives(const PlanBlock(id: 'b2', content: PlanBookmark()));
    });

    test('a table of contents survives', () {
      expectSurvives(const PlanBlock(id: 'b3', content: PlanTableOfContents()));
    });

    test('an embed with and without a target survives', () {
      expectSurvives(
        const PlanBlock(
          id: 'b4',
          content: PlanEmbed(
            processor: PlanEmbedProcessor.youtube,
            target: 'https://youtu.be/x',
          ),
        ),
      );
      expectSurvives(
        const PlanBlock(
          id: 'b5',
          content: PlanEmbed(processor: PlanEmbedProcessor.mermaid),
        ),
      );
    });

    test('an object link and a widget block survive', () {
      expectSurvives(
        const PlanBlock(
          id: 'b6',
          content: PlanLink(target: 'r-task-1'),
        ),
      );
      expectSurvives(
        const PlanBlock(
          id: 'b7',
          content: PlanWidgetBlock(layout: PlanWidgetLayout.list, limit: 6),
        ),
      );
    });

    test('a relation block and featured relations survive', () {
      expectSurvives(
        const PlanBlock(id: 'b8', content: PlanRelationBlock('status')),
      );
      expectSurvives(
        const PlanBlock(id: 'b9', content: PlanFeaturedRelations()),
      );
    });

    test('a file in the empty state writes no null garbage', () {
      expectSurvives(
        const PlanBlock(
          id: 'b10',
          content: PlanFile(kind: PlanFileKind.image),
        ),
      );
      expectSurvives(
        const PlanBlock(
          id: 'b11',
          content: PlanFile(kind: PlanFileKind.file, state: PlanFileState.done),
        ),
      );
      // A DONE file with a name still reads as a plain markdown image line.
      final md = encodePlanMarkdown([
        const PlanBlock(
          id: 'b12',
          content: PlanFile(
            kind: PlanFileKind.image,
            state: PlanFileState.done,
            name: 'shot.png',
            target: 'assets/shot.png',
          ),
        ),
      ]);
      expect(md, '![shot.png](assets/shot.png)');
    });
  });

  group('text blocks markdown cannot fully carry', () {
    test('toggle, callout and title keep their style through a save', () {
      expectSurvives(
        const PlanBlock(
          id: 't1',
          content: PlanText(text: 'collapsed', style: PlanTextStyle.toggle),
        ),
      );
      expectSurvives(
        const PlanBlock(
          id: 't2',
          content: PlanText(
            text: 'note',
            style: PlanTextStyle.callout,
            iconEmoji: '💡',
          ),
        ),
      );
      expectSurvives(
        const PlanBlock(
          id: 't3',
          content: PlanText(text: 'big', style: PlanTextStyle.title),
        ),
      );
    });

    test('block colour, background and alignment survive', () {
      expectSurvives(
        const PlanBlock(
          id: 't4',
          content: PlanText(text: 'red', color: 'red'),
        ),
      );
      expectSurvives(
        const PlanBlock(
          id: 't5',
          content: PlanText(text: 'highlighted', background: 'blue'),
        ),
      );
      expectSurvives(
        const PlanBlock(
          id: 't6',
          content: PlanText(text: 'right', align: PlanAlign.end),
        ),
      );
    });

    test('an underline mark survives', () {
      expectSurvives(
        const PlanBlock(
          id: 't7',
          content: PlanText(
            text: 'underlined',
            marks: [
              PlanMark(
                range: PlanMarkRange(0, 10),
                type: PlanMarkType.underline,
              ),
            ],
          ),
        ),
      );
    });

    test('an empty checkbox row is still a checkbox row', () {
      final md = encodePlanMarkdown([
        const PlanBlock(
          id: 't8',
          content: PlanText(
            text: '',
            style: PlanTextStyle.checkbox,
            checked: false,
          ),
        ),
      ]);
      // The row keeps its trailing space — markdown's checkbox syntax.
      expect(md, '- [ ] ');
      final readBack = decodePlanMarkdown(md);
      final content = readBack.single.content as PlanText;
      expect(content.style, PlanTextStyle.checkbox);
      expect(content.checked, isFalse);
    });
  });

  group('hand-written files are unaffected', () {
    test('a document without envelopes decodes exactly as before', () {
      const source = '# Title\n\nplain **bold** text\n';
      final blocks = decodePlanMarkdown(source);
      // No envelope round the plain heading — the ordinary md path.
      expect(encodePlanMarkdown(blocks), source);
      // A stray HTML comment the user wrote stays literal text.
      final withComment = decodePlanMarkdown('<!-- just a note -->\n');
      expect(
        withComment.where(
          (block) =>
              block.content is PlanText &&
              (block.content as PlanText).text.contains('just a note'),
        ),
        isNotEmpty,
      );
    });

    test('a corrupt envelope degrades to literal text, not a crash', () {
      final blocks = decodePlanMarkdown('<!-- plan:{not json -->\n');
      expect(blocks, isNotEmpty);
    });
  });
}
