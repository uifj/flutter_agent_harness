// A quick phrase (ADR-0063): a reusable snippet the composer inserts at the
// cursor. User content, not a preference — it lives in its own store, rides
// the backup, and knows nothing about who consumes it.


class QuickPhrase {
  const QuickPhrase({
    required this.id,
    required this.title,
    required this.text,
  });

  final String id;
  final String title;
  final String text;

  QuickPhrase copyWith({String? title, String? text}) =>
      QuickPhrase(id: id, title: title ?? this.title, text: text ?? this.text);

  Map<String, Object?> toJson() => {'id': id, 'title': title, 'text': text};

  static QuickPhrase fromJson(Map<String, dynamic> json) => QuickPhrase(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    text: json['text'] as String? ?? '',
  );
}

/// The menu's cap (ADR-0063): past this the new-entry action stops, because a
/// phrase list the menu cannot render is a list nobody edits either.
const quickPhraseCap = 20;
