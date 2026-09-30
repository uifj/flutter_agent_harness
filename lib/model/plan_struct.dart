// The plan workspace's record shape (ADR-0037 D1): a record is a VIEW over a
// `PlanStruct`, not a class with fields.
//
// Anytype gets away with one model for 21 object types because relations are
// resolved from a map at read time (`ObjectWrapper` over `Struct`,
// `core-models/.../ObjectWrapper.kt:24`), so adding a relation never touches a
// class. Copying that shape is what lets the plan workspace carry sets,
// collections, boards and galleries over the same records.
//
// Pure Dart: `lib/model` may not import `package:flutter` (invariant 2, gate
// rule 2). Dates are `DateTime`, ids are `String`, and every value in the map
// is a JSON scalar/list/map so the same document round-trips through
// `dart:convert` without a second representation.

/// A record's relations, by key. Missing key = "no value" (Anytype's own
/// semantics: `unset` removes the key rather than writing null).
typedef PlanStruct = Map<String, Object?>;

/// The relation keys every object carries, whatever its type.
abstract final class PlanRelationKeys {
  static const name = 'name';
  static const type = 'type';
  static const done = 'done';
  static const assignee = 'assignee';
  static const dueDate = 'dueDate';
  static const status = 'status';
  static const priority = 'priority';
  static const tags = 'tags';
  static const url = 'url';
  static const email = 'email';
  static const phone = 'phone';
  static const emoji = 'emoji';
  static const note = 'note';
  static const cover = 'cover';
  static const icon = 'icon';
  static const links = 'links';
  static const origin = 'origin';

  /// How a record came to exist (Anytype's `ObjectOrigin`, 9 values,
  /// `core-models/.../ObjectOrigin.kt:4-12`). Codes match upstream so a real
  /// source can be dropped under the mock without rewriting the values.
  static const originValues = <String, int>{
    'none': 0,
    'clipboard': 1,
    'dragAndDrop': 2,
    'import': 3,
    'webClipper': 4,
    'sharingExtension': 5,
    'useCase': 6,
    'builtIn': 7,
    'bookmark': 8,
  };
}

/// What the app may not let the user do to an object. One bit per restriction;
/// the set is Anytype's `ObjectRestriction` (11 values,
/// `core-models/.../restrictions/ObjectRestriction.kt:6-40`) — the codes are
/// kept identical because the UI asks "is DELETE in this set?" and that answer
/// must not depend on which side of the map produced it.
enum PlanObjectRestriction {
  none(0),
  delete(1),
  relations(2),
  blocks(3),
  details(4),
  typeChange(5),
  layoutChange(6),
  template(7),
  duplicate(8),
  createObjectOfType(9),
  publish(10);

  const PlanObjectRestriction(this.code);

  final int code;

  static PlanObjectRestriction fromCode(int code) =>
      values.firstWhere((value) => value.code == code, orElse: () => none);

  static Set<PlanObjectRestriction> codesToSet(Iterable<int> codes) => {
    for (final code in codes) fromCode(code),
  };

  static List<int> setToCodes(Set<PlanObjectRestriction> restrictions) => [
    for (final restriction in restrictions) restriction.code,
  ];
}

/// What the app may not let the user do to a data view. Anytype's three
/// (`DataViewRestrictions.kt:9-14`).
enum PlanDataViewRestriction { views, relation, createObject }

/// A record. [id] is identity; [struct] is content, read lazily.
class PlanObject {
  const PlanObject({required this.id, required this.struct});

  final String id;
  final PlanStruct struct;

  String get name => (struct[PlanRelationKeys.name] as String?) ?? '';

  /// The type key. Anytype falls back to Page rather than leaving a record
  /// untyped (`ObjectTypeIds.kt:33 DEFAULT_OBJECT_TYPE`), so the same default
  /// holds here — a record without a type is still a page.
  String get typeKey =>
      (struct[PlanRelationKeys.type] as String?) ?? PlanTypeKeysFallback.page;

  bool get isDone => struct[PlanRelationKeys.done] == true;

  Object? relation(String key) => struct[key];

  bool hasRelation(String key) => struct.containsKey(key);

  /// Text read. Never a bare cast: a value that arrived as a number or a list
  /// must render, not throw on the way to a row.
  String? text(String key) => switch (struct[key]) {
    final String value => value,
    null => null,
    final List<Object?> value => value.map((e) => '$e').join(', '),
    final Object? value => '$value',
  };

  /// Checkbox read, tolerant of the `"true"` a share payload or an older file
  /// can carry. A cast here crashes the row that displays the record.
  bool? checkbox(String key) => switch (struct[key]) {
    final bool value => value,
    final String value => value == 'true' || value == '1',
    final num value => value != 0,
    null => null,
    _ => null,
  };

  /// Numeric read. A value written through [PlanRelation.normalizeValue] is
  /// already a num; the parse fallback is for records that came off disk or out
  /// of a share payload, where `42` can arrive as `"42"`.
  double? number(String key) => switch (struct[key]) {
    final num value => value.toDouble(),
    final String value => double.tryParse(value),
    _ => null,
  };

  DateTime? date(String key) => switch (struct[key]) {
    final String value => DateTime.tryParse(value),
    final DateTime value => value,
    _ => null,
  };

  /// Option ids for a `status` / `tag` relation. One value for status, a list
  /// for tags; both are read as a list so the grouping code has one shape.
  List<String> options(String key) => switch (struct[key]) {
    final String value => [value],
    final List<Object?> value => [
      for (final entry in value)
        if (entry is String) entry,
    ],
    _ => const <String>[],
  };

  /// Relation keys the object actually carries, minus identity keys. Used by
  /// the object-info panel's Local section.
  List<String> get presentRelationKeys => [
    for (final entry in struct.entries)
      if (entry.key != 'id' &&
          entry.key != PlanRelationKeys.name &&
          entry.key != PlanRelationKeys.type &&
          entry.value != null)
        entry.key,
  ];

  /// Write-side diff: [changes] merges, `null` value removes the key.
  /// Returns a new record — the store holds immutable values so a listener
  /// never sees a half-applied edit.
  PlanObject amend(Map<String, Object?> changes) {
    final next = <String, Object?>{...struct};
    changes.forEach((key, value) {
      if (value == null) {
        next.remove(key);
      } else {
        next[key] = value;
      }
    });
    return PlanObject(id: id, struct: next);
  }

  PlanObject unset(List<String> keys) {
    final next = <String, Object?>{...struct};
    for (final key in keys) {
      next.remove(key);
    }
    return PlanObject(id: id, struct: next);
  }

  Map<String, Object?> toJson() => {'id': id, ...struct};

  static PlanObject fromJson(Map<String, Object?> json) {
    final struct = <String, Object?>{...json}..remove('id');
    return PlanObject(id: json['id'] as String? ?? '', struct: struct);
  }

  @override
  bool operator ==(Object other) =>
      other is PlanObject && other.id == id && _mapEquals(other.struct, struct);

  @override
  int get hashCode => Object.hash(id, struct.length, name, typeKey);
}

/// The fallback type key when a record carries none. Kept as a local constant
/// so `plan_object_type.dart` can own the real list without a cycle.
abstract final class PlanTypeKeysFallback {
  static const page = 'ot-page';
}

bool _mapEquals(Map<String, Object?> a, Map<String, Object?> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    if (!b.containsKey(entry.key)) return false;
    if (!_valueEquals(b[entry.key], entry.value)) return false;
  }
  return true;
}

bool _valueEquals(Object? a, Object? b) {
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_valueEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) return _mapEquals(a.cast(), b.cast());
  return a == b;
}
