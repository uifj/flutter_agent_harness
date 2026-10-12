// AttributedText → InlineSpan runs (ADR-0044 E2). The single glue between
// the span engine and Flutter's text painting: segments are cut at every
// attribution boundary (and at the IME composing range), and each segment's
// style is the host resolver's answer merged over the field's base style.
// The package never decides what bold looks like.

import 'package:attributed_text/attributed_text.dart';
import 'package:flutter/widgets.dart';

/// Turns a set of marks into the style delta for that run, with the field's
/// own context (theme lookups are the host's business). Merged over the base
/// style; an empty style leaves the base untouched.
typedef EditorStyleResolver = TextStyle Function(
  BuildContext context,
  Set<Attribution> marks,
);

/// Builds the [TextSpan] children for [attributed]: one child per
/// style-constant run, plus the composing region underlined the way the
/// SDK's own field does (EditableText hands us `withComposing`).
List<InlineSpan> buildEditorRuns(
  AttributedText attributed,
  TextStyle base,
  EditorStyleResolver? resolver, {
  required BuildContext context,
  TextRange composing = TextRange.empty,
}) {
  final text = attributed.toPlainText();
  if (text.isEmpty) {
    return const [TextSpan(text: '')];
  }

  final hasComposing = composing.isValid &&
      !composing.isCollapsed &&
      composing.start <= text.length;

  // Cut points: every attribution boundary plus the composing range's.
  final cuts = <int>{0, text.length};
  for (final span in attributed.computeAttributionSpans()) {
    cuts.add(span.start.clamp(0, text.length));
    cuts.add((span.end + 1).clamp(0, text.length));
  }
  if (hasComposing) {
    cuts.add(composing.start);
    cuts.add(composing.end);
  }
  final ordered = cuts.toList()..sort();

  final children = <InlineSpan>[];
  for (var i = 0; i < ordered.length - 1; i++) {
    final start = ordered[i];
    final end = ordered[i + 1];
    if (end <= start) continue;
    final marks = attributed.getAllAttributionsAt(start);
    var style = base;
    if (resolver != null && marks.isNotEmpty) {
      style = style.merge(resolver(context, marks));
    }
    if (hasComposing && start >= composing.start && end <= composing.end) {
      // The composing underline rides on top of the run's own style, the
      // same convention EditableText's default buildTextSpan uses.
      style = style.copyWith(decoration: TextDecoration.underline);
    }
    children.add(TextSpan(text: text.substring(start, end), style: style));
  }
  return children;
}
