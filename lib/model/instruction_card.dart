// Instruction cards (ADR-0067): user-authored prompt cards injected with the
// workspace instructions. Pure Dart.

/// One card. [text] is model-facing prose — not an i18n string, the same
/// rule the workspace instruction block follows.
class InstructionCard {
  const InstructionCard({
    required this.id,
    required this.title,
    required this.text,
  });

  final String id;
  final String title;
  final String text;

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'text': text};

  static InstructionCard fromJson(Map<String, dynamic> json) => InstructionCard(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    text: json['text'] as String? ?? '',
  );
}

/// The store's cap; the injection budget is bounded on top of it.
const instructionCardCap = 10;

/// One card's text is clipped to this many characters before joining —
/// 10 full cards stay inside ~5KB, the same budget consciousness the
/// per-file instruction cap runs on.
const instructionCardTextCap = 500;

/// Joins the enabled cards' texts into the tail of the instruction block,
/// or null when none are enabled (the block stays byte-identical to before).
String? instructionCardsBlock(List<String> texts) {
  final bodies = <String>[];
  for (final text in texts) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) continue;
    bodies.add(
      trimmed.length <= instructionCardTextCap
          ? trimmed
          : '${trimmed.substring(0, instructionCardTextCap)}…(truncated)',
    );
  }
  if (bodies.isEmpty) return null;
  return bodies.join('\n\n');
}
