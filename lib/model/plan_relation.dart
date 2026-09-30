// Relations and their formats (ADR-0037 §5). The 16 formats, their codes and
// the 4 sources are Anytype's `Relation.Format` / `Relation.Source`
// (`core-models/.../Relation.kt:33-54`); codes are kept identical so a value
// written by this app means the same thing to any future real source.
//
// The gate that matters is [creatable]: Anytype offers 11 formats in its
// "new relation" sheet and NOT the other five (`SHORT_TEXT`, `EMOJI`, `MAP`,
// `RELATIONS`, `UNDEFINED` are system-derived). Reproducing that list is the
// difference between "an Anytype-shaped relation library" and "everything the
// wire model can hold". Evidence: `feature-properties/.../add/
// UiEditTypePropertiesState.kt:20-32`.

/// How a relation's value is stored and edited.
enum PlanRelationFormat {
  longText(0),
  shortText(1),
  number(2),
  status(3),
  date(4),
  file(5),
  checkbox(6),
  url(7),
  email(8),
  phone(9),
  emoji(10),
  tag(11),
  object(100),
  relations(101),
  map(102),
  undefined(-1);

  const PlanRelationFormat(this.code);

  final int code;

  /// The formats the "new relation" sheet offers — Anytype's eleven.
  static const creatable = <PlanRelationFormat>[
    longText,
    tag,
    status,
    number,
    date,
    file,
    object,
    checkbox,
    url,
    email,
    phone,
  ];

  /// Formats whose value is one or more option ids.
  bool get hasOptions => this == status || this == tag;

  bool get isMultiValue => this == tag || this == file || this == object;

  static PlanRelationFormat fromCode(int code) =>
      values.firstWhere((value) => value.code == code, orElse: () => undefined);
}

/// Where a relation came from (`Relation.Source`, `Relation.kt:51-54`).
enum PlanRelationSource {
  details,
  derived,
  account,
  local;

  /// Anytype splits the object-info list on this: `local` relations are the
  /// user's own and editable, the rest are read-only rows.
  bool get isEditable => this == local || this == details;
}

/// One selectable value of a `status` / `tag` relation.
class PlanRelationOption {
  const PlanRelationOption({
    required this.id,
    required this.text,
    this.colorIndex,
  });

  final String id;
  final String text;

  /// Index into the 11-stop `ThemeColor` ladder the surface paints with. Kept
  /// as an index (not a color) so the theme stays the only source of hue.
  final int? colorIndex;

  Map<String, Object?> toJson() => {
    'id': id,
    'text': text,
    if (colorIndex != null) 'colorIndex': colorIndex,
  };

  static PlanRelationOption fromJson(Map<String, Object?> json) =>
      PlanRelationOption(
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        colorIndex: (json['colorIndex'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is PlanRelationOption &&
      other.id == id &&
      other.text == text &&
      other.colorIndex == colorIndex;

  @override
  int get hashCode => Object.hash(id, text, colorIndex);
}

/// A relation definition. Like every other object in this model, a relation
/// IS an object — its own struct plus the format/option payload.
class PlanRelation {
  const PlanRelation({
    required this.id,
    required this.key,
    required this.name,
    required this.format,
    this.source = PlanRelationSource.local,
    this.options = const [],
    this.hidden = false,
    this.featured = false,
  });

  final String id;
  final String key;
  final String name;
  final PlanRelationFormat format;
  final PlanRelationSource source;
  final List<PlanRelationOption> options;

  /// Hidden relations exist on the record but are not listed by default —
  /// Anytype shows them in a separate section of the info panel.
  final bool hidden;

  /// Featured relations render in the object header row
  /// (`Block.Content.FeaturedRelations`, `Block.kt:264`).
  final bool featured;

  PlanRelationOption? option(String optionId) {
    for (final option in options) {
      if (option.id == optionId) return option;
    }
    return null;
  }

  String optionText(String optionId) => option(optionId)?.text ?? optionId;

  /// The order the options are listed in. `SetRelationOptionOrder` is one of
  /// Anytype's eight relation operations, so the order is data, not a sort.
  List<String> get optionOrderIds => [for (final o in options) o.id];

  PlanRelation copyWith({
    String? name,
    PlanRelationFormat? format,
    PlanRelationSource? source,
    List<PlanRelationOption>? options,
    bool? hidden,
    bool? featured,
  }) => PlanRelation(
    id: id,
    key: key,
    name: name ?? this.name,
    format: format ?? this.format,
    source: source ?? this.source,
    options: options ?? this.options,
    hidden: hidden ?? this.hidden,
    featured: featured ?? this.featured,
  );

  /// Normalises a value being written, per format. Without this the same
  /// relation can hold `"42"` and `42` and every comparison would need a
  /// second rule; Anytype's equivalent lives in its payload mappers.
  Object? normalizeValue(Object? raw) {
    if (raw == null) return null;
    switch (format) {
      case PlanRelationFormat.number:
        if (raw is num) return raw.toDouble();
        return double.tryParse(raw.toString());
      case PlanRelationFormat.checkbox:
        if (raw is bool) return raw;
        final text = raw.toString();
        return text == 'true' || text == '1';
      case PlanRelationFormat.date:
        if (raw is DateTime) {
          // Day-resolution: Anytype's `includeTime` is a viewer option, the
          // stored value stays a parseable ISO stamp.
          return raw.toIso8601String();
        }
        final parsed = DateTime.tryParse(raw.toString());
        return parsed?.toIso8601String();
      case PlanRelationFormat.status:
      case PlanRelationFormat.emoji:
      case PlanRelationFormat.url:
      case PlanRelationFormat.email:
      case PlanRelationFormat.phone:
      case PlanRelationFormat.shortText:
      case PlanRelationFormat.longText:
        final text = raw.toString();
        return text.isEmpty ? null : text;
      case PlanRelationFormat.tag:
      case PlanRelationFormat.file:
      case PlanRelationFormat.object:
      case PlanRelationFormat.relations:
        return switch (raw) {
          final List<Object?> value => [
            for (final entry in value)
              if (entry != null) entry.toString(),
          ],
          final String value => [value],
          _ => const <String>[],
        };
      case PlanRelationFormat.map:
        return raw is Map ? Map<String, Object?>.from(raw.cast()) : null;
      case PlanRelationFormat.undefined:
        return raw;
    }
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'key': key,
    'name': name,
    'format': format.code,
    'source': source.name,
    'options': [for (final option in options) option.toJson()],
    if (hidden) 'hidden': true,
    if (featured) 'featured': true,
  };

  static PlanRelation fromJson(Map<String, Object?> json) => PlanRelation(
    id: json['id'] as String? ?? '',
    key: json['key'] as String? ?? '',
    name: json['name'] as String? ?? '',
    format: PlanRelationFormat.fromCode(
      (json['format'] as num?)?.toInt() ?? -1,
    ),
    source: PlanRelationSource.values.firstWhere(
      (value) => value.name == json['source'],
      orElse: () => PlanRelationSource.local,
    ),
    options: [
      for (final entry in (json['options'] as List<Object?>? ?? const []))
        if (entry is Map<String, Object?>) PlanRelationOption.fromJson(entry),
    ],
    hidden: json['hidden'] == true,
    featured: json['featured'] == true,
  );
}

/// The eight relation operations Anytype's domain layer exposes
/// (`domain/.../relations/`), kept as data so the store and the UI agree on
/// what "editing relations" means.
enum PlanRelationAction {
  create,
  addToObject,
  deleteFromObject,
  setKey,
  addToFeatured,
  removeFromFeatured,
  createOption,
  deleteOptions,
  setOptionOrder,
}
