// The ask_user vocabulary (ADR-0059): what the tool's interrupt carries and
// what the user's answer looks like when it rides back as the tool result.
// Pure Dart — the panel parses the interrupt payload through here, the
// controller ships [AskUserAnswer]s through here, and neither learns the
// other's shape.

/// One question the model asked, parsed from the interrupt payload
/// (`details['questions']`). Malformed entries drop rather than throw — a
/// model that sends junk gets a refusal it can read, not a crashed UI.
class AskUserQuestion {
  const AskUserQuestion({
    required this.question,
    required this.options,
    required this.multi,
  });

  /// Bounds the tool schema also declares; the parse enforces them so a
  /// hand-edited or hallucinated payload cannot stretch the panel.
  static const maxQuestions = 4;
  static const maxOptions = 4;

  factory AskUserQuestion.fromJson(Object? json) {
    if (json is! Map) return const AskUserQuestion.hollow();
    final question = json['question'];
    final rawOptions = json['options'];
    return AskUserQuestion(
      question: question is String && question.trim().isNotEmpty
          ? question.trim()
          : '',
      options: [
        if (rawOptions is List)
          for (final option in rawOptions)
            if (option is String && option.trim().isNotEmpty) option.trim(),
      ].take(maxOptions).toList(),
      multi: json['multi'] == true,
    );
  }

  /// A question with nothing left after a malformed parse; callers treat it
  /// as "render nothing, refuse the call".
  const AskUserQuestion.hollow()
    : question = '',
      options = const [],
      multi = false;

  final String question;

  /// Empty means an open question: the answer is free text only.
  final List<String> options;
  final bool multi;

  bool get isValid => question.isNotEmpty;
}

/// One answered (or skipped) question, as the resume payload carries it.
class AskUserAnswer {
  const AskUserAnswer({
    required this.question,
    required this.values,
    this.custom,
    this.skipped = false,
  });

  final String question;

  /// The chosen option labels; empty when the answer is [custom]-only or
  /// the question was skipped.
  final List<String> values;

  /// Free text, alone for an open question or beside chosen options.
  final String? custom;
  final bool skipped;

  Map<String, Object?> toJson() => {
    'question': question,
    'values': values,
    if (custom != null && custom!.isNotEmpty) 'custom': custom,
    if (skipped) 'skipped': true,
  };

  /// The tool result the model reads back: one ok envelope around every
  /// answer, the same shape every workspace tool returns.
  static Map<String, Object?> payload(List<AskUserAnswer> answers) => {
    'ok': true,
    'answers': [for (final answer in answers) answer.toJson()],
  };
}
