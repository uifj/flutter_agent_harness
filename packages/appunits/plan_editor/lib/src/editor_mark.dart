// The inline marks the plan editor's field carries while editing (ADR-0044).
//
// The named set mirrors the selection toolbar's eight buttons; the three
// parametered marks (link, text colour, background colour) carry their
// payload on the attribution itself, the way super_editor's
// LinkAttribution/ColorAttribution do. The package never interprets a
// parameter's meaning — the host's style resolver does (ADR-0002: the
// component stays colour-blind).

import 'package:attributed_text/attributed_text.dart';

class EditorMark implements Attribution {
  const EditorMark._(this.id, this.param);

  /// Simple style toggles — same id always merges, so adjacent runs join.
  static const EditorMark bold = EditorMark._('bold', null);
  static const EditorMark italic = EditorMark._('italic', null);
  static const EditorMark underline = EditorMark._('underline', null);
  static const EditorMark strikethrough = EditorMark._('strikethrough', null);

  /// Inline code (`KEYBOARD` upstream).
  static const EditorMark keyboard = EditorMark._(keyboardId, null);
  static const keyboardId = 'keyboard';

  /// A link target — one mark per URL, so a different URL overwrites.
  factory EditorMark.link(String url) => EditorMark._(linkId, url);
  static const linkId = 'link';

  /// Text colour, keyed by the host's colour-ladder name.
  factory EditorMark.textColor(String ladderName) =>
      EditorMark._('textColor', ladderName);

  /// Background colour, keyed by the host's colour-ladder name.
  factory EditorMark.background(String ladderName) =>
      EditorMark._('background', ladderName);

  @override
  final String id;

  /// The mark's payload (URL, ladder name); null for the plain toggles.
  final String? param;

  /// Marks the plan workspace's toolbar writes. The three render-only marks
  /// upstream keeps (mention/emoji/object) are the host's business, not the
  /// field's.
  static final Set<EditorMark> toolbarMarks = {
    bold,
    italic,
    underline,
    strikethrough,
    keyboard
  };

  @override
  bool canMergeWith(Attribution other) =>
      other is EditorMark && other.id == id && other.param == param;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EditorMark && other.id == id && other.param == param;

  @override
  int get hashCode => Object.hash(id, param);

  @override
  String toString() =>
      param == null ? 'EditorMark($id)' : 'EditorMark($id: $param)';
}
