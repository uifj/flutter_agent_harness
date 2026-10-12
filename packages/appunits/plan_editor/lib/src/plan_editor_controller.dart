// The plan editor's field controller (ADR-0044 E1/E2/E3).
//
// A TextEditingController whose value carries inline marks: every text
// change is diffed into an insert/remove and the span bank shifts with it
// (attributed_text's copy-based `insertString`/`removeRegion` — typing
// inside a styled run keeps the style, deleting through it contracts it),
// and `buildTextSpan` renders the marks LIVE while the caret is in the
// field. That last part rides the SDK seam at `editable_text.dart:5956`:
// EditableText itself asks the controller for its span, so the host field
// (ShadInput → TextField → EditableText) needs no changes.
//
// Truth channels (ADR-0044 decision 3): while typing, THIS controller is
// the only shift engine — the host mirrors the result into its document
// wholesale. When the document changes (toolbar, undo), the host pushes
// back through [sync]; a marks-only push never touches the
// TextEditingValue, so the caret stays where it was.

import 'dart:async';

import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';

import 'editor_mark.dart';
import 'editor_spans.dart';

/// A mark over a half-open range of the controller's text.
class EditorMarkRange {
  const EditorMarkRange(this.mark, this.start, this.end);

  final EditorMark mark;
  final int start;
  final int end;

  @override
  String toString() => '[$start, $end) ${mark.id}:${mark.param}';
}

class PlanEditorController extends TextEditingController {
  PlanEditorController({String? text, List<EditorMarkRange> marks = const []})
      : super(text: text ?? '') {
    _attributed = AttributedText(this.text);
    _syncedText = this.text;
    for (final range in marks) {
      _attributed.addAttribution(
        range.mark,
        SpanRange(range.start, range.end - 1),
        overwriteConflictingSpans: true,
      );
    }
  }

  AttributedText _attributed = AttributedText('');
  String _syncedText = '';
  bool _syncing = false;

  /// The host's style answer; null renders the base style everywhere.
  EditorStyleResolver? styleResolver;

  AttributedText get attributedText => _attributed;

  /// The current marks as ranges — the host maps these back onto its
  /// document vocabulary after a typing change. Adjacent same-mark runs are
  /// coalesced here: `insertString` keeps the *content* of a styled run
  /// intact when the caret types into it, but leaves the span bank
  /// fragmented (`he|X|llo` as three bold pieces); the host should never
  /// see that.
  List<EditorMarkRange> get marks => [
        for (final run in _coalesced(_runsOf(_attributed)))
          for (final mark in run.attributions)
            if (mark is EditorMark)
              EditorMarkRange(mark, run.start, run.end + 1),
      ];

  /// Marked runs, inclusive on both ends (the engine's own convention).
  static List<MultiAttributionSpan> _runsOf(AttributedText attributed) =>
      attributed
          .computeAttributionSpans()
          .where((span) => span.attributions.isNotEmpty)
          .toList();

  /// Joins adjacent runs carrying the same attribution set.
  static List<MultiAttributionSpan> _coalesced(
      List<MultiAttributionSpan> runs) {
    final merged = <MultiAttributionSpan>[];
    for (final run in runs) {
      final last = merged.isEmpty ? null : merged.last;
      if (last != null &&
          last.end + 1 == run.start &&
          const SetEquality<Attribution>()
              .equals(last.attributions, run.attributions)) {
        merged[merged.length - 1] = last.copyWith(end: run.end);
      } else {
        merged.add(run);
      }
    }
    return merged;
  }

  /// Text and *coalesced* marks agree — the honest comparison between the
  /// document's answer and the (possibly fragmented) engine state.
  bool _sameContent(AttributedText a, AttributedText b) {
    if (a.toPlainText() != b.toPlainText()) return false;
    final runsA = _coalesced(_runsOf(a));
    final runsB = _coalesced(_runsOf(b));
    if (runsA.length != runsB.length) return false;
    for (var i = 0; i < runsA.length; i++) {
      if (runsA[i].start != runsB[i].start || runsA[i].end != runsB[i].end) {
        return false;
      }
      if (!const SetEquality<Attribution>()
          .equals(runsA[i].attributions, runsB[i].attributions)) {
        return false;
      }
    }
    return true;
  }

  /// Mirrors the document's answer into the field. Same text = a marks-only
  /// push (the caret and any IME composition stay exactly where they are);
  /// different text = the field resets, selection collapsed at the end, the
  /// answer the plain TextEditingController gave the host before.
  void sync(AttributedText next) {
    if (_sameContent(next, _attributed) && next.toPlainText() == text) return;
    // The push almost always arrives inside the host's build
    // (didUpdateWidget); touching the value or notifying listeners there
    // marks the field dirty mid-build and the framework throws. One
    // microtask lands the push after the frame. The `_syncing` guard wraps
    // the microtask, so the pushed value never re-enters the shift engine.
    _syncing = true;
    scheduleMicrotask(() {
      try {
        final nextText = next.toPlainText();
        if (nextText != text) {
          _attributed = next;
          super.value = TextEditingValue(
            text: nextText,
            selection: TextSelection.collapsed(offset: nextText.length),
          );
          _syncedText = nextText;
        } else {
          _attributed = next;
          notifyListeners();
        }
      } finally {
        _syncing = false;
      }
    });
  }

  @override
  set value(TextEditingValue newValue) {
    if (!_syncing && newValue.text != _syncedText) {
      _shiftTo(newValue.text);
    }
    super.value = newValue;
  }

  /// Diffs the two texts into one remove + one insert and applies them to
  /// the span bank. Longest common prefix/suffix — the same rule the host's
  /// document used for plain-text edits, now living only here (ADR-0044
  /// decision 3: one shift engine per channel).
  ///
  /// Inheritance is the host's job because the engine does not do it: typed
  /// text takes the marks of the character *before* the insertion point —
  /// except code and link, which only continue when the caret is strictly
  /// inside the run (appflowy's `partialSliced` rule: typing after a linked
  /// word must not drag the link along).
  void _shiftTo(String newText) {
    final oldText = _syncedText;
    var prefix = 0;
    while (prefix < oldText.length &&
        prefix < newText.length &&
        oldText.codeUnitAt(prefix) == newText.codeUnitAt(prefix)) {
      prefix++;
    }
    var oldSuffix = oldText.length;
    var newSuffix = newText.length;
    while (oldSuffix > prefix &&
        newSuffix > prefix &&
        oldText.codeUnitAt(oldSuffix - 1) ==
            newText.codeUnitAt(newSuffix - 1)) {
      oldSuffix--;
      newSuffix--;
    }
    final inherited = prefix == 0 || prefix > _attributed.length
        ? const <Attribution>{}
        : _inheritedAt(prefix);
    if (oldSuffix > prefix) {
      _attributed = _attributed.removeRegion(
        startOffset: prefix,
        endOffset: oldSuffix,
      );
    }
    if (newSuffix > prefix) {
      _attributed = _attributed.insertString(
        textToInsert: newText.substring(prefix, newSuffix),
        startOffset: prefix,
        applyAttributions: inherited,
      );
    }
    _syncedText = newText;
  }

  /// The marks the character before [index] carries — minus the boundary-shy
  /// marks (code, link) that only continue inside their run.
  Set<Attribution> _inheritedAt(int index) {
    final before = _attributed.getAllAttributionsAt(index - 1);
    if (before.isEmpty) return const {};
    final after = index < _attributed.length
        ? _attributed.getAllAttributionsAt(index)
        : const <Attribution>{};
    return {
      for (final mark in before)
        if (mark is! EditorMark ||
            !(mark.id == EditorMark.keyboardId ||
                mark.id == EditorMark.linkId) ||
            after.contains(mark))
          mark,
    };
  }

  // ---- marks ---------------------------------------------------------------

  /// Flips a mark over the selection (no-op collapsed — pending styles for
  /// the next typed character are a later stage). A different param of the
  /// same id (another colour, another URL) overwrites the overlap.
  void toggleMark(EditorMark mark, TextSelection selection) {
    if (selection.isCollapsed) return;
    _attributed.toggleAttribution(
        mark, SpanRange(selection.start, selection.end - 1));
    notifyListeners();
  }

  /// Adds a mark over the selection, overwriting a conflicting same-id span.
  void addMark(EditorMark mark, TextSelection selection) {
    if (selection.isCollapsed) return;
    _attributed.addAttribution(
      mark,
      SpanRange(selection.start, selection.end - 1),
      overwriteConflictingSpans: true,
    );
    notifyListeners();
  }

  void removeMark(EditorMark mark, TextSelection selection) {
    _attributed.removeAttribution(
        mark, SpanRange(selection.start, selection.end - 1));
    notifyListeners();
  }

  /// Whether the whole selection carries [mark] — the toolbar's applied
  /// (ghost) state.
  bool hasMark(EditorMark mark, TextSelection selection) {
    if (selection.isCollapsed) return false;
    return _attributed.hasAttributionsThroughout(
      attributions: {mark},
      range: SpanRange(selection.start, selection.end - 1),
    );
  }

  // ---- rendering -----------------------------------------------------------

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    return TextSpan(
      style: base,
      children: buildEditorRuns(
        _attributed,
        base,
        styleResolver,
        context: context,
        composing: withComposing ? value.composing : TextRange.empty,
      ),
    );
  }
}
