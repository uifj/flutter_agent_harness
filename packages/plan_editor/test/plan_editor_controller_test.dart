// The package's contract tests (ADR-0044 P10-a). They pin the three things
// the host editor leans on: (1) typing shifts marks — the style a caret
// types into continues, deletion contracts it; (2) toggle/add/remove keep
// replace-overlap semantics so a second colour or URL overwrites; (3)
// buildTextSpan renders the marks while editing, with the composing range
// underlined, and a marks-only sync never moves the caret.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plan_editor/plan_editor.dart';

EditorMarkRange bold(int start, int end) =>
    EditorMarkRange(EditorMark.bold, start, end);

List<EditorMarkRange> marksOf(
        PlanEditorController controller, EditorMark mark) =>
    controller.marks.where((range) => range.mark == mark).toList();

Future<BuildContext> pumpContext(WidgetTester tester) async {
  BuildContext? captured;
  await tester.pumpWidget(
    Builder(
      builder: (context) {
        captured = context;
        return const SizedBox.shrink();
      },
    ),
  );
  return captured!;
}

void main() {
  group('typing shifts the marks', () {
    test('typing inside a bold run extends it', () {
      final controller = PlanEditorController(
        text: 'hello world',
        marks: [bold(0, 5)],
      );
      controller.value = const TextEditingValue(
        text: 'heXllo world',
        selection: TextSelection.collapsed(offset: 3),
      );
      final bolds = marksOf(controller, EditorMark.bold);
      expect(bolds.single.start, 0);
      expect(bolds.single.end, 6);
    });

    test('typing at the end of a bold run extends it', () {
      final controller = PlanEditorController(
        text: 'hello world',
        marks: [bold(0, 5)],
      );
      controller.value = const TextEditingValue(
        text: 'helloX world',
        selection: TextSelection.collapsed(offset: 6),
      );
      final bolds = marksOf(controller, EditorMark.bold);
      expect(bolds.single.start, 0);
      expect(bolds.single.end, 6);
    });

    test('typing at the end of a code run does not extend it', () {
      final controller = PlanEditorController(
        text: 'hello world',
        marks: [EditorMarkRange(EditorMark.keyboard, 0, 5)],
      );
      controller.value = const TextEditingValue(
        text: 'helloX world',
        selection: TextSelection.collapsed(offset: 6),
      );
      expect(marksOf(controller, EditorMark.keyboard).single.end, 5);
    });

    test('typing before a run inherits nothing', () {
      final controller = PlanEditorController(
        text: 'ab bold',
        marks: [bold(3, 7)],
      );
      controller.value = const TextEditingValue(
        text: 'abX bold',
        selection: TextSelection.collapsed(offset: 3),
      );
      expect(marksOf(controller, EditorMark.bold).single.start, 4);
      expect(
        controller.hasMark(
          EditorMark.bold,
          const TextSelection(baseOffset: 2, extentOffset: 3),
        ),
        isFalse,
      );
    });

    test('deleting through a run contracts it', () {
      final controller = PlanEditorController(
        text: 'hello world',
        marks: [bold(0, 5)],
      );
      // Delete the "o" at index 4.
      controller.value = const TextEditingValue(
        text: 'hell world',
        selection: TextSelection.collapsed(offset: 4),
      );
      final bolds = marksOf(controller, EditorMark.bold);
      expect(bolds.single.start, 0);
      expect(bolds.single.end, 4);
    });

    test('deleting the whole run removes the mark', () {
      final controller = PlanEditorController(
        text: 'hello world',
        marks: [bold(0, 5)],
      );
      controller.value = const TextEditingValue(
        text: ' world',
        selection: TextSelection.collapsed(offset: 0),
      );
      expect(marksOf(controller, EditorMark.bold), isEmpty);
    });

    test('marks after the edit shift forward', () {
      final controller = PlanEditorController(
        text: 'ab cd',
        marks: [bold(3, 5)],
      );
      controller.value = const TextEditingValue(
        text: 'abX cd',
        selection: TextSelection.collapsed(offset: 3),
      );
      final bolds = marksOf(controller, EditorMark.bold);
      expect(bolds.single.start, 4);
      expect(bolds.single.end, 6);
    });
  });

  group('mark ops keep replace-overlap semantics', () {
    test('toggle adds then removes over the selection', () {
      final controller = PlanEditorController(text: 'hello world');
      const selection = TextSelection(baseOffset: 0, extentOffset: 5);
      controller.toggleMark(EditorMark.bold, selection);
      expect(controller.hasMark(EditorMark.bold, selection), isTrue);
      controller.toggleMark(EditorMark.bold, selection);
      expect(controller.hasMark(EditorMark.bold, selection), isFalse);
    });

    test('a different text colour overwrites the overlap', () {
      final controller = PlanEditorController(text: 'hello world');
      controller.addMark(
        EditorMark.textColor('red'),
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      controller.addMark(
        EditorMark.textColor('blue'),
        const TextSelection(baseOffset: 3, extentOffset: 8),
      );
      const overlapped = TextSelection(baseOffset: 3, extentOffset: 5);
      const kept = TextSelection(baseOffset: 0, extentOffset: 3);
      expect(
          controller.hasMark(EditorMark.textColor('blue'), overlapped), isTrue);
      expect(controller.hasMark(EditorMark.textColor('red'), kept), isTrue);
      expect(
          controller.hasMark(EditorMark.textColor('red'), overlapped), isFalse);
    });

    test('a different URL overwrites the overlap', () {
      final controller = PlanEditorController(text: 'hello world');
      controller.addMark(
        EditorMark.link('https://a.dev'),
        const TextSelection(baseOffset: 0, extentOffset: 5),
      );
      controller.addMark(
        EditorMark.link('https://b.dev'),
        const TextSelection(baseOffset: 2, extentOffset: 7),
      );
      final oldLinks = marksOf(controller, EditorMark.link('https://a.dev'));
      final newLinks = marksOf(controller, EditorMark.link('https://b.dev'));
      // The old URL survives only before the overlap; the new one owns it.
      for (final range in oldLinks) {
        expect(range.end <= 2, isTrue);
      }
      expect(newLinks.single.start, 2);
    });

    test('different ids coexist over the same range', () {
      final controller = PlanEditorController(text: 'hello world');
      const selection = TextSelection(baseOffset: 0, extentOffset: 5);
      controller.toggleMark(EditorMark.bold, selection);
      controller.toggleMark(EditorMark.italic, selection);
      expect(controller.hasMark(EditorMark.bold, selection), isTrue);
      expect(controller.hasMark(EditorMark.italic, selection), isTrue);
    });

    test('collapsed selections are a no-op (pending styles are a later stage)',
        () {
      final controller = PlanEditorController(text: 'hello world');
      controller.toggleMark(
        EditorMark.bold,
        const TextSelection.collapsed(offset: 3),
      );
      expect(controller.marks, isEmpty);
    });
  });

  group('sync mirrors the document', () {
    test('a marks-only push keeps the caret and composing where they were', () {
      final controller = PlanEditorController(text: 'hello world');
      controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection(baseOffset: 2, extentOffset: 5),
        composing: TextRange.collapsed(3),
      );
      controller.sync(
        AttributedText('hello world')
          ..addAttribution(EditorMark.bold, const SpanRange(0, 5)),
      );
      expect(controller.selection,
          const TextSelection(baseOffset: 2, extentOffset: 5));
      expect(controller.value.composing, const TextRange.collapsed(3));
      expect(controller.hasMark(EditorMark.bold, controller.selection), isTrue);
    });

    test('a full push resets the text and collapses at the end', () {
      final controller = PlanEditorController(text: 'hello world');
      controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection.collapsed(offset: 2),
      );
      controller.sync(AttributedText('rolled back'));
      expect(controller.text, 'rolled back');
      expect(controller.selection, const TextSelection.collapsed(offset: 11));
    });

    test('sync does not double-shift the spans', () {
      final controller = PlanEditorController(text: 'hello');
      controller.value = const TextEditingValue(
        text: 'helloX',
        selection: TextSelection.collapsed(offset: 6),
      );
      // The host mirrors the controller's own shifted answer back: text and
      // marks agree, so the push must be a no-op, not a second shift.
      controller.sync(controller.attributedText);
      expect(controller.text, 'helloX');
      expect(controller.marks, isEmpty);
    });
  });

  group('buildTextSpan renders while editing', () {
    TextStyle resolver(BuildContext context, Set<Attribution> marks) {
      var style = const TextStyle();
      for (final mark in marks) {
        if (mark == EditorMark.bold) {
          style = style.copyWith(fontWeight: FontWeight.w700);
        }
        if (mark == EditorMark.italic) {
          style = style.copyWith(fontStyle: FontStyle.italic);
        }
      }
      return style;
    }

    testWidgets('marks become styled runs, plain stretches keep the base style',
        (
      tester,
    ) async {
      final context = await pumpContext(tester);
      final controller = PlanEditorController(
        text: 'plain bold tail',
        marks: [bold(6, 10)],
      )..styleResolver = resolver;
      final span = controller.buildTextSpan(
        context: context,
        style: const TextStyle(fontSize: 14),
        withComposing: false,
      );
      final runs = span.children!.cast<TextSpan>().toList();
      expect(runs.map((run) => run.text).toList(), ['plain ', 'bold', ' tail']);
      expect(runs[1].style!.fontWeight, FontWeight.w700);
      expect(runs[0].style!.fontWeight, isNull);
      // The base style rides on every run.
      expect(runs[1].style!.fontSize, 14);
    });

    testWidgets('the composing range underlines its stretch', (tester) async {
      final context = await pumpContext(tester);
      final controller = PlanEditorController(text: 'hello world')
        ..styleResolver = resolver;
      controller.value = const TextEditingValue(
        text: 'hello world',
        selection: TextSelection.collapsed(offset: 8),
        composing: TextRange(start: 6, end: 11),
      );
      final span = controller.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: true,
      );
      final composingRun = span.children!
          .cast<TextSpan>()
          .singleWhere((run) => run.text == 'world');
      expect(composingRun.style!.decoration, TextDecoration.underline);
      final plainRun = span.children!
          .cast<TextSpan>()
          .singleWhere((run) => run.text == 'hello ');
      expect(plainRun.style!.decoration, isNull);
    });

    testWidgets('empty text yields a single empty run', (tester) async {
      final context = await pumpContext(tester);
      final controller = PlanEditorController(text: '')
        ..styleResolver = resolver;
      final span = controller.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      expect(span.children, hasLength(1));
    });
  });
}
