// The data view's evaluation engine (ADR-0037 §1): filter, sort, group, order.
//
// Pure Dart and side-effect free on purpose. Anytype computes the same thing
// inside the Go node, so its Kotlin client has no engine to copy — only the
// condition vocabulary (`Block.kt:366-377`) and the two rules that shape the
// loop: subscribe before the query (`domain/.../DataViewSubscriptionContainer
// .kt:59`) and keep records as an ordered id list (`sets/
// ObjectSetDatabase.kt:24`). Those two live in the store; this file owns the
// answers that must be testable: which records match, in what order, in which
// columns.

import 'plan_dataview.dart';
import 'plan_relation.dart';
import 'plan_struct.dart';

/// A record's value for a relation, resolved through the relation's format so
/// `"42"` and `42` are not two different answers.
Object? planRelationValue(
  PlanObject object,
  String key,
  Map<String, PlanRelation> relations,
) {
  final raw = object.relation(key);
  if (raw == null) return null;
  final relation = relations[key];
  if (relation == null) return raw;
  return relation.normalizeValue(raw);
}

/// Whether a single filter row admits [object].
///
/// A row whose `operator` is [PlanFilterOperator.no] is switched off and
/// admits everything — that is what Anytype's third operator means.
bool matchPlanFilter(
  PlanObject object, {
  required PlanFilter filter,
  Map<String, PlanRelation> relations = const {},
  DateTime? now,
}) {
  if (filter.operator == PlanFilterOperator.no) return true;

  final value = planRelationValue(object, filter.relationKey, relations);
  final condition = filter.condition;

  if (condition == PlanFilterCondition.empty) return _isEmptyValue(value);
  if (condition == PlanFilterCondition.notEmpty) return !_isEmptyValue(value);
  if (condition == PlanFilterCondition.exists) {
    return object.hasRelation(filter.relationKey);
  }

  // Date shortcuts resolve against the read time, so "today" stays today.
  if (filter.quickDate != null) {
    final date = _asDate(value);
    if (date == null) return false;
    final window = filter.quickDate!.window(
      now: now ?? DateTime.now(),
      offset: filter.offset,
    );
    switch (condition) {
      case PlanFilterCondition.notEqual:
      case PlanFilterCondition.notIn:
      case PlanFilterCondition.notLike:
      case PlanFilterCondition.notAllIn:
      case PlanFilterCondition.notExactIn:
        return date.isBefore(window.start) || !date.isBefore(window.end);
      default:
        return !date.isBefore(window.start) && date.isBefore(window.end);
    }
  }

  final expected = filter.value;
  final relation = relations[filter.relationKey];
  final isTextLike =
      relation == null ||
      relation.format == PlanRelationFormat.longText ||
      relation.format == PlanRelationFormat.shortText ||
      relation.format == PlanRelationFormat.url ||
      relation.format == PlanRelationFormat.email ||
      relation.format == PlanRelationFormat.phone;

  switch (condition) {
    case PlanFilterCondition.equal:
      return _scalarEquals(value, expected, asText: isTextLike);
    case PlanFilterCondition.notEqual:
      return !_scalarEquals(value, expected, asText: isTextLike);
    case PlanFilterCondition.greater:
    case PlanFilterCondition.less:
    case PlanFilterCondition.greaterOrEqual:
    case PlanFilterCondition.lessOrEqual:
      final comparison = _compare(value, expected);
      if (comparison == null) return false;
      return switch (condition) {
        PlanFilterCondition.greater => comparison > 0,
        PlanFilterCondition.less => comparison < 0,
        PlanFilterCondition.greaterOrEqual => comparison >= 0,
        _ => comparison <= 0,
      };
    case PlanFilterCondition.like:
      return _asText(
        value,
      ).toLowerCase().contains(_asText(expected).toLowerCase());
    case PlanFilterCondition.notLike:
      return !_asText(
        value,
      ).toLowerCase().contains(_asText(expected).toLowerCase());
    case PlanFilterCondition.inSet:
      return _intersects(value, expected);
    case PlanFilterCondition.notIn:
      return !_intersects(value, expected);
    case PlanFilterCondition.allIn:
      final listed = _asStringList(expected);
      final held = _asStringList(value);
      return listed.isNotEmpty && listed.every(held.contains);
    case PlanFilterCondition.notAllIn:
      final listed = _asStringList(expected);
      final held = _asStringList(value);
      return listed.any((id) => !held.contains(id));
    case PlanFilterCondition.none:
      return !_intersects(value, expected);
    case PlanFilterCondition.exactIn:
      return _setEquals(_asStringList(value), _asStringList(expected));
    case PlanFilterCondition.notExactIn:
      return !_setEquals(_asStringList(value), _asStringList(expected));
    case PlanFilterCondition.empty:
    case PlanFilterCondition.notEmpty:
    case PlanFilterCondition.exists:
      return true;
  }
}

/// Rows the client does not evaluate: nested/advanced rules, whose editor is
/// desktop-only upstream (`Block.kt:360-365 isAdvanced()`). The sheet must say
/// these are not applied rather than pretending they matched everything.
List<PlanFilter> splitAdvanced(List<PlanFilter> filters) => [
  for (final filter in filters)
    if (filter.isAdvanced) filter,
];

/// The ordered record ids a viewer shows.
///
/// [manualOrder] is the viewer's `objectOrders` entry; it only wins when a
/// sort of type [PlanSortType.custom] is present — Anytype's own rule, since
/// `custom` is never offered in the sort sheet and only means "the stored
/// order".
List<String> selectPlanRecordIds({
  required List<String> candidateIds,
  required Map<String, PlanObject> objects,
  Map<String, PlanRelation> relations = const {},
  List<PlanFilter> filters = const [],
  List<PlanSort> sorts = const [],
  List<String> manualOrder = const [],
  List<String> membership = const [],
  DateTime? now,
}) {
  var ids = [...candidateIds];

  // A collection is an explicit list, so membership filters before anything.
  if (membership.isNotEmpty) {
    final allowed = membership.toSet();
    ids = [
      for (final id in ids)
        if (allowed.contains(id)) id,
    ];
  }

  final effective = [
    for (final f in filters)
      if (!f.isAdvanced) f,
  ];
  if (effective.isNotEmpty) {
    ids = [
      for (final id in ids)
        if (_matchesAll(objects[id], effective, relations, now)) id,
    ];
  }

  final activeSorts = [
    for (final sort in sorts)
      if (sort.type != PlanSortType.custom) sort,
  ];
  if (sorts.any((sort) => sort.type == PlanSortType.custom)) {
    ids = _applyManualOrder(ids, manualOrder);
  }

  if (activeSorts.isEmpty) return ids;
  ids.sort((a, b) {
    for (final sort in activeSorts) {
      final result = _compareBySort(a, b, sort, objects, relations);
      if (result != 0) return result;
    }
    return a.compareTo(b);
  });
  return ids;
}

bool _matchesAll(
  PlanObject? object,
  List<PlanFilter> filters,
  Map<String, PlanRelation> relations,
  DateTime? now,
) {
  if (object == null) return false;
  for (final filter in filters) {
    final matched = matchPlanFilter(
      object,
      filter: filter,
      relations: relations,
      now: now,
    );
    // OR rows admit on their own; AND rows all have to hold.
    if (filter.operator == PlanFilterOperator.or) {
      if (matched) return true;
      continue;
    }
    if (!matched) return false;
  }
  return !filters.any((filter) => filter.operator == PlanFilterOperator.or);
}

List<String> _applyManualOrder(List<String> ids, List<String> manualOrder) {
  if (manualOrder.isEmpty) return ids;
  final known = ids.toSet();
  final ordered = [
    for (final id in manualOrder)
      if (known.contains(id)) id,
  ];
  // Anything without a stored position keeps its place at the end rather
  // than disappearing — a new record must still be reachable.
  ordered.addAll([
    for (final id in ids)
      if (!manualOrder.contains(id)) id,
  ]);
  return ordered;
}

int _compareBySort(
  String a,
  String b,
  PlanSort sort,
  Map<String, PlanObject> objects,
  Map<String, PlanRelation> relations,
) {
  final left = objects[a];
  final right = objects[b];
  final leftValue = left == null
      ? null
      : planRelationValue(left, sort.relationKey, relations);
  final rightValue = right == null
      ? null
      : planRelationValue(right, sort.relationKey, relations);

  final leftEmpty = _isEmptyValue(leftValue);
  final rightEmpty = _isEmptyValue(rightValue);
  if (leftEmpty || rightEmpty) {
    if (leftEmpty && rightEmpty) return 0;
    // Placement is placement: the direction must not move the empty side.
    // `notSpecific` puts empties last, which is what the Android client
    // renders when nothing is chosen (the sheet only offers top / bottom,
    // `ModifyViewerSortViewModel.kt:86,96`).
    final emptiesFirst = sort.emptyPlacement == PlanSortEmptyPlacement.start;
    return leftEmpty == emptiesFirst ? -1 : 1;
  }

  final comparison =
      _compareValues(leftValue, rightValue) ??
      _compareText(_asText(leftValue), _asText(rightValue));
  if (comparison != 0) {
    return sort.type == PlanSortType.desc ? -comparison : comparison;
  }
  // Equal on this key: the caller's next sort decides, and only the last key
  // falls back to id. Returning an id tie-break here would stop the cascade
  // after the first key — which is exactly what "status then name" means.
  return 0;
}

/// Case-insensitive alphabetical compare with a deterministic fallback, so
/// `beta` sorts before `Gamma` the way a viewer reads it and equal-folded text
/// still has one stable order. Upstream collation lives in the Go node; this
/// is the closest honest equivalent without a locale table.
int _compareText(String left, String right) {
  final folded = left.toLowerCase().compareTo(right.toLowerCase());
  return folded != 0 ? folded : left.compareTo(right);
}

/// Records grouped by the value of [groupRelationKey] — the board's columns.
/// Columns come back in [optionOrder] (the viewer's `groupOrders`), with
/// unknown option ids appended and an empty bucket last: a record with no
/// status still has to be reachable.
Map<String, List<String>> groupPlanRecordIds({
  required List<String> ids,
  required Map<String, PlanObject> objects,
  required String groupRelationKey,
  List<String> optionOrder = const [],
  PlanRelation? relation,
}) {
  final buckets = <String, List<String>>{};
  for (final id in ids) {
    final object = objects[id];
    if (object == null) continue;
    final value = relation == null
        ? object.relation(groupRelationKey)
        : planRelationValue(object, groupRelationKey, {
            groupRelationKey: relation,
          });
    final keys = _asStringList(value);
    if (keys.isEmpty) {
      (buckets[''] ??= <String>[]).add(id);
    } else {
      for (final key in keys) {
        (buckets[key] ??= <String>[]).add(id);
      }
    }
  }

  final ordered = <String, List<String>>{};
  for (final optionId in optionOrder) {
    if (buckets.containsKey(optionId)) {
      ordered[optionId] = buckets[optionId]!;
    }
  }
  for (final entry in buckets.entries) {
    if (entry.key.isNotEmpty && !ordered.containsKey(entry.key)) {
      ordered[entry.key] = entry.value;
    }
  }
  if (buckets.containsKey('')) ordered[''] = buckets['']!;
  return ordered;
}

// ---- value helpers --------------------------------------------------------

bool _isEmptyValue(Object? value) => switch (value) {
  null => true,
  final String text => text.isEmpty,
  final List<Object?> list => list.isEmpty,
  final Map<Object?, Object?> map => map.isEmpty,
  _ => false,
};

String _asText(Object? value) => switch (value) {
  null => '',
  final List<Object?> list => list.map(_asText).join(', '),
  _ => value.toString(),
};

List<String> _asStringList(Object? value) => switch (value) {
  final String text => [text],
  final List<Object?> list => [
    for (final entry in list)
      if (entry != null) entry.toString(),
  ],
  null => const [],
  _ => [value.toString()],
};

bool _scalarEquals(Object? value, Object? expected, {bool asText = false}) {
  if (value == null || expected == null) return false;
  if (value is bool || expected is bool) return value == expected;
  if (asText) {
    final left = _asText(value);
    final right = _asText(expected);
    if (left.isEmpty || right.isEmpty) return false;
    return left.toLowerCase() == right.toLowerCase();
  }
  if (value is DateTime || expected is DateTime) {
    final left = _asDate(value);
    final right = _asDate(expected);
    if (left == null || right == null) return false;
    return left == right;
  }
  final comparison = _compareValues(value, expected);
  if (comparison != null) return comparison == 0;
  return _asText(value) == _asText(expected);
}

bool _intersects(Object? value, Object? expected) {
  final held = _asStringList(value).toSet();
  final wanted = _asStringList(expected);
  return wanted.any(held.contains);
}

bool _setEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  return a.toSet().containsAll(b) && b.toSet().containsAll(a.toSet());
}

DateTime? _asDate(Object? value) => switch (value) {
  // Only a date-shaped value is a date. A bare number must stay a number:
  // letting `5` become "1970-01-01T00:00:00.005" made an effort filter of
  // `greater 5` compare two epoch milliseconds instead of two quantities.
  final DateTime date => date,
  final String text when DateTime.tryParse(text) != null => DateTime.parse(
    text,
  ),
  _ => null,
};

num? _asNumber(Object? value) => switch (value) {
  final num number => number,
  final String text => num.tryParse(text),
  _ => null,
};

int? _compare(Object? value, Object? expected) =>
    _compareValues(value, expected);

int? _compareValues(Object? left, Object? right) {
  if (left == null || right == null) return null;
  final leftDate = _asDate(left);
  final rightDate = _asDate(right);
  if (leftDate != null && rightDate != null) {
    return leftDate.compareTo(rightDate);
  }
  final leftNumber = _asNumber(left);
  final rightNumber = _asNumber(right);
  if (leftNumber != null && rightNumber != null) {
    return leftNumber.compareTo(rightNumber);
  }
  if (left is bool && right is bool) {
    return (left ? 1 : 0).compareTo(right ? 1 : 0);
  }
  return null;
}
