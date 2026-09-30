// 本文件守住的那句话：数据视图的筛选、排序、分组只有一个答案，且那个答案是
// Anytype 的词汇表（18 个条件 / 3 个运算符 / 15 个日期快捷 / 3 种排序 + 空值位置）。
//
// ADR-0037 里最容易悄悄跑偏的就是这一层：条件枚举抄全了但求值只写了一半，
// 于是抽屉能选、结果不变——用户看到的是"筛选失效"，测试看到的是"全绿"。
// 所以每条条件都有正反两例，日期快捷全部按窗口断言（`now` 注入，不靠时钟），
// 空值位置三档各自钉住，手工序只在 `custom` 生效时被读。

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_harness/model/plan_dataview.dart';
import 'package:agent_harness/model/plan_filter_engine.dart';
import 'package:agent_harness/model/plan_relation.dart';
import 'package:agent_harness/model/plan_struct.dart';

/// 一个足够分辨所有条件的记录集：文本、数字、日期、勾选、状态、标签各不同。
final _objects = <String, PlanObject>{
  'a': PlanObject(
    id: 'a',
    struct: {
      'name': 'Alpha',
      'effort': 5,
      'done': true,
      'dueDate': '2026-10-01T09:00:00.000',
      'status': 'doing',
      'tags': ['urgent', 'client'],
      'url': 'https://anytype.io/docs',
    },
  ),
  'b': PlanObject(
    id: 'b',
    struct: {
      'name': 'beta',
      'effort': 12,
      'done': false,
      'dueDate': '2026-10-08T09:00:00.000',
      'status': 'todo',
      'tags': ['client'],
      'note': 'has a note',
    },
  ),
  'c': PlanObject(
    id: 'c',
    struct: {
      'name': 'Gamma',
      'done': false,
      'dueDate': '2026-11-20T09:00:00.000',
      'status': 'done',
      'tags': <String>[],
    },
  ),
};

final _relations = <String, PlanRelation>{
  'effort': const PlanRelation(
    id: 'r1',
    key: 'effort',
    name: 'Effort',
    format: PlanRelationFormat.number,
  ),
  'dueDate': const PlanRelation(
    id: 'r2',
    key: 'dueDate',
    name: 'Due',
    format: PlanRelationFormat.date,
  ),
  'done': const PlanRelation(
    id: 'r3',
    key: 'done',
    name: 'Done',
    format: PlanRelationFormat.checkbox,
  ),
  'status': const PlanRelation(
    id: 'r4',
    key: 'status',
    name: 'Status',
    format: PlanRelationFormat.status,
    options: [
      PlanRelationOption(id: 'todo', text: 'Todo'),
      PlanRelationOption(id: 'doing', text: 'Doing'),
      PlanRelationOption(id: 'done', text: 'Done'),
    ],
  ),
  'tags': const PlanRelation(
    id: 'r5',
    key: 'tags',
    name: 'Tags',
    format: PlanRelationFormat.tag,
    options: [
      PlanRelationOption(id: 'urgent', text: 'Urgent'),
      PlanRelationOption(id: 'client', text: 'Client'),
    ],
  ),
  'name': const PlanRelation(
    id: 'r6',
    key: 'name',
    name: 'Name',
    format: PlanRelationFormat.shortText,
  ),
};

const _all = ['a', 'b', 'c'];

/// 只跑一条条件的便捷写法。
List<String> _select(PlanFilter filter, {DateTime? now}) => selectPlanRecordIds(
  candidateIds: _all,
  objects: _objects,
  relations: _relations,
  filters: [filter],
  now: now,
);

void main() {
  group('all eighteen conditions answer', () {
    test(
      'equal / notEqual on text ignore case, unlike upstream\'s LIKE gap',
      () {
        expect(
          _select(
            const PlanFilter(
              relationKey: 'name',
              condition: PlanFilterCondition.equal,
              value: 'alpha',
            ),
          ),
          ['a'],
        );
        expect(
          _select(
            const PlanFilter(
              relationKey: 'name',
              condition: PlanFilterCondition.notEqual,
              value: 'alpha',
            ),
          ),
          ['b', 'c'],
        );
      },
    );

    test('equal on a number does not need the string form to match', () {
      expect(
        _select(
          const PlanFilter(
            relationKey: 'effort',
            condition: PlanFilterCondition.equal,
            value: '12',
          ),
        ),
        ['b'],
        reason: '"12" and 12 are one value after normalizeValue',
      );
    });

    test('the four comparison conditions order numbers and dates', () {
      PlanFilter compare(PlanFilterCondition condition, Object value) =>
          PlanFilter(relationKey: 'effort', condition: condition, value: value);
      expect(_select(compare(PlanFilterCondition.greater, 5)), ['b']);
      // Nothing has an effort below 5; `c` has no effort at all, and a
      // comparison against nothing is never true.
      expect(_select(compare(PlanFilterCondition.less, 5)), isEmpty);
      // c has no effort: a comparison against nothing is never true.
      expect(_select(compare(PlanFilterCondition.greaterOrEqual, 5)), [
        'a',
        'b',
      ]);
      expect(_select(compare(PlanFilterCondition.lessOrEqual, 5)), ['a']);

      final dateCompare = PlanFilter(
        relationKey: 'dueDate',
        condition: PlanFilterCondition.greater,
        value: '2026-10-05T00:00:00.000',
      );
      expect(_select(dateCompare), ['b', 'c']);
    });

    test('like / notLike are substring and case-insensitive', () {
      expect(
        _select(
          const PlanFilter(
            relationKey: 'name',
            condition: PlanFilterCondition.like,
            value: 'amm',
          ),
        ),
        ['c'],
      );
      expect(
        _select(
          const PlanFilter(
            relationKey: 'url',
            condition: PlanFilterCondition.like,
            value: 'ANYTYPE',
          ),
        ),
        ['a'],
      );
      expect(
        _select(
          const PlanFilter(
            relationKey: 'name',
            condition: PlanFilterCondition.notLike,
            value: 'a',
          ),
        ),
        isEmpty,
      );
    });

    test('inSet / notIn intersect option ids', () {
      expect(
        _select(
          const PlanFilter(
            relationKey: 'status',
            condition: PlanFilterCondition.inSet,
            value: ['todo', 'doing'],
          ),
        ),
        ['a', 'b'],
      );
      expect(
        _select(
          const PlanFilter(
            relationKey: 'status',
            condition: PlanFilterCondition.notIn,
            value: ['todo', 'doing'],
          ),
        ),
        ['c'],
      );
    });

    test('allIn needs every listed option; notAllIn needs one missing', () {
      expect(
        _select(
          const PlanFilter(
            relationKey: 'tags',
            condition: PlanFilterCondition.allIn,
            value: ['urgent', 'client'],
          ),
        ),
        ['a'],
      );
      expect(
        _select(
          const PlanFilter(
            relationKey: 'tags',
            condition: PlanFilterCondition.notAllIn,
            value: ['urgent', 'client'],
          ),
        ),
        ['b', 'c'],
      );
    });

    test('none is "holds none of the listed options"', () {
      expect(
        _select(
          const PlanFilter(
            relationKey: 'tags',
            condition: PlanFilterCondition.none,
            value: ['urgent'],
          ),
        ),
        ['b', 'c'],
      );
    });

    test('exactIn compares whole sets and notExactIn is its mirror', () {
      expect(
        _select(
          const PlanFilter(
            relationKey: 'tags',
            condition: PlanFilterCondition.exactIn,
            value: ['client', 'urgent'],
          ),
        ),
        ['a'],
      );
      expect(
        _select(
          const PlanFilter(
            relationKey: 'tags',
            condition: PlanFilterCondition.notExactIn,
            value: ['client', 'urgent'],
          ),
        ),
        ['b', 'c'],
      );
    });

    test('empty / notEmpty / exists read presence, not truthiness', () {
      expect(
        _select(
          const PlanFilter(
            relationKey: 'effort',
            condition: PlanFilterCondition.empty,
          ),
        ),
        ['c'],
      );
      expect(
        _select(
          const PlanFilter(
            relationKey: 'tags',
            condition: PlanFilterCondition.empty,
          ),
        ),
        ['c'],
        reason: 'an empty list is empty',
      );
      expect(
        _select(
          const PlanFilter(
            relationKey: 'note',
            condition: PlanFilterCondition.notEmpty,
          ),
        ),
        ['b'],
      );
      expect(
        _select(
          const PlanFilter(
            relationKey: 'note',
            condition: PlanFilterCondition.exists,
          ),
        ),
        ['b'],
      );
    });

    test('operator NO switches a row off', () {
      expect(
        _select(
          const PlanFilter(
            relationKey: 'effort',
            operator: PlanFilterOperator.no,
            condition: PlanFilterCondition.greater,
            value: 999,
          ),
        ),
        _all,
      );
    });

    test('the fifteen quick-date windows are the documented ranges', () {
      // A Tuesday. Monday-based weeks, day-resolution, half-open [start, end).
      final now = DateTime(2026, 10, 6, 13);
      DateTime day(int month, int dome) => DateTime(2026, month, dome);
      ({DateTime start, DateTime end}) window(
        PlanFilterQuickDate quick, [
        int offset = 0,
      ]) => quick.window(now: now, offset: offset);

      expect(PlanFilterQuickDate.values.length, 15);

      final exact = window(PlanFilterQuickDate.exactDate, 3);
      expect(exact.start, day(10, 9));
      expect(exact.end, day(10, 10));

      expect(window(PlanFilterQuickDate.yesterday).start, day(10, 5));
      expect(window(PlanFilterQuickDate.today).start, day(10, 6));
      expect(window(PlanFilterQuickDate.today).end, day(10, 7));
      expect(window(PlanFilterQuickDate.tomorrow).start, day(10, 7));

      // Oct 6 is a Tuesday, so this week began Monday Oct 5.
      expect(window(PlanFilterQuickDate.currentWeek).start, day(10, 5));
      expect(window(PlanFilterQuickDate.currentWeek).end, day(10, 12));
      expect(window(PlanFilterQuickDate.lastWeek).start, day(9, 28));
      expect(window(PlanFilterQuickDate.nextWeek).start, day(10, 12));

      expect(window(PlanFilterQuickDate.currentMonth).start, day(10, 1));
      expect(window(PlanFilterQuickDate.currentMonth).end, day(11, 1));
      expect(window(PlanFilterQuickDate.lastMonth).start, DateTime(2026, 9, 1));
      expect(window(PlanFilterQuickDate.lastMonth).end, day(10, 1));
      expect(window(PlanFilterQuickDate.nextMonth).start, day(11, 1));
      expect(window(PlanFilterQuickDate.nextMonth).end, DateTime(2026, 12, 1));

      // "N days ago" runs back to today; "N days ahead" runs forward from it.
      expect(window(PlanFilterQuickDate.daysAgo, 6).start, day(9, 30));
      expect(window(PlanFilterQuickDate.daysAgo, 6).end, day(10, 7));
      expect(window(PlanFilterQuickDate.daysAhead, 2).start, day(10, 6));
      expect(window(PlanFilterQuickDate.daysAhead, 2).end, day(10, 9));

      expect(
        window(PlanFilterQuickDate.currentYear).start,
        DateTime(2026, 1, 1),
      );
      expect(window(PlanFilterQuickDate.currentYear).end, DateTime(2027, 1, 1));
      expect(window(PlanFilterQuickDate.lastYear).start, DateTime(2025, 1, 1));
      expect(window(PlanFilterQuickDate.nextYear).start, DateTime(2027, 1, 1));
    });

    test('quick dates select by window and are resolved at read time', () {
      PlanFilter row(PlanFilterQuickDate quick) => PlanFilter(
        relationKey: 'dueDate',
        condition: PlanFilterCondition.equal,
        quickDate: quick,
      );
      // a = Oct 1, b = Oct 8, c = Nov 20. On Tue Oct 6 the week is Oct 5–11,
      // so b is this week and a is last week.
      expect(_select(row(PlanFilterQuickDate.currentMonth)), ['a', 'b']);
      expect(_select(row(PlanFilterQuickDate.nextMonth)), ['c']);
      expect(
        _select(
          row(PlanFilterQuickDate.currentWeek),
          now: DateTime(2026, 10, 6),
        ),
        ['b'],
      );
      expect(
        _select(row(PlanFilterQuickDate.lastWeek), now: DateTime(2026, 10, 6)),
        ['a'],
      );
      // "today" means today, not the day the filter row was created.
      expect(
        _select(row(PlanFilterQuickDate.today), now: DateTime(2026, 10, 1)),
        ['a'],
      );
    });

    test('a negated quick-date condition is the complement', () {
      expect(
        _select(
          PlanFilter(
            relationKey: 'dueDate',
            condition: PlanFilterCondition.notEqual,
            quickDate: PlanFilterQuickDate.currentMonth,
          ),
          now: DateTime(2026, 10, 6),
        ),
        ['c'],
      );
    });
  });

  group('AND and OR combine the way the sheet labels them', () {
    test('AND rows all have to hold', () {
      expect(
        selectPlanRecordIds(
          candidateIds: _all,
          objects: _objects,
          relations: _relations,
          filters: const [
            PlanFilter(
              relationKey: 'done',
              condition: PlanFilterCondition.equal,
              value: false,
            ),
            PlanFilter(
              relationKey: 'effort',
              condition: PlanFilterCondition.notEmpty,
            ),
          ],
        ),
        ['b'],
      );
    });

    test('one OR row admitting is enough', () {
      expect(
        selectPlanRecordIds(
          candidateIds: _all,
          objects: _objects,
          relations: _relations,
          filters: const [
            PlanFilter(
              relationKey: 'name',
              operator: PlanFilterOperator.or,
              condition: PlanFilterCondition.equal,
              value: 'Gamma',
            ),
            PlanFilter(
              relationKey: 'name',
              operator: PlanFilterOperator.or,
              condition: PlanFilterCondition.equal,
              value: 'Alpha',
            ),
          ],
        ),
        ['a', 'c'],
      );
    });

    test(
      'advanced rows are not evaluated here and are reported, not ignored',
      () {
        const advanced = PlanFilter(
          relationKey: 'name',
          condition: PlanFilterCondition.equal,
          nested: [
            PlanFilter(
              relationKey: 'done',
              condition: PlanFilterCondition.equal,
            ),
          ],
        );
        expect(advanced.isAdvanced, isTrue);
        expect(splitAdvanced([advanced]), [advanced]);
        // A lone advanced rule filters nothing — which is why the sheet must say so.
        expect(_select(advanced), _all);
      },
    );
  });

  group('sorting answers with direction, placement and manual order', () {
    test('asc and desc are mirrors on numbers', () {
      List<String> sortedBy(PlanSortType type) => selectPlanRecordIds(
        candidateIds: ['c', 'a', 'b'],
        objects: _objects,
        relations: _relations,
        sorts: [PlanSort(relationKey: 'effort', type: type)],
      );
      expect(sortedBy(PlanSortType.asc), ['a', 'b', 'c']);
      expect(sortedBy(PlanSortType.desc), ['b', 'a', 'c']);
    });

    test('empty placement decides where the valueless record lands', () {
      List<String> withPlacement(PlanSortEmptyPlacement placement) =>
          selectPlanRecordIds(
            candidateIds: ['c', 'a', 'b'],
            objects: _objects,
            relations: _relations,
            sorts: [PlanSort(relationKey: 'effort', emptyPlacement: placement)],
          );
      expect(withPlacement(PlanSortEmptyPlacement.start), ['c', 'a', 'b']);
      expect(withPlacement(PlanSortEmptyPlacement.end), ['a', 'b', 'c']);
      expect(withPlacement(PlanSortEmptyPlacement.notSpecific), [
        'a',
        'b',
        'c',
      ]);
    });

    test('empties are not moved by direction', () {
      expect(
        selectPlanRecordIds(
          candidateIds: ['c', 'a', 'b'],
          objects: _objects,
          relations: _relations,
          sorts: [
            const PlanSort(relationKey: 'effort', type: PlanSortType.desc),
          ],
        ),
        ['b', 'a', 'c'],
        reason: 'desc flips the values, not the empty row',
      );
    });

    test(
      'custom reads the stored order and keeps unlisted records reachable',
      () {
        final ids = selectPlanRecordIds(
          candidateIds: ['a', 'b', 'c'],
          objects: _objects,
          relations: _relations,
          sorts: const [
            PlanSort(relationKey: 'name', type: PlanSortType.custom),
          ],
          manualOrder: const ['c', 'a'],
        );
        expect(ids, ['c', 'a', 'b']);
      },
    );

    test('sorts cascade: status then name', () {
      final objects = <String, PlanObject>{
        'x': PlanObject(id: 'x', struct: {'status': 'doing', 'name': 'Z'}),
        'y': PlanObject(id: 'y', struct: {'status': 'doing', 'name': 'A'}),
        'z': PlanObject(id: 'z', struct: {'status': 'todo', 'name': 'M'}),
      };
      expect(
        selectPlanRecordIds(
          candidateIds: ['x', 'y', 'z'],
          objects: objects,
          sorts: const [
            PlanSort(relationKey: 'status'),
            PlanSort(relationKey: 'name'),
          ],
        ),
        ['y', 'x', 'z'],
      );
    });
  });

  group('grouping builds board columns', () {
    test('columns follow groupOrders, unknown options append, empty last', () {
      final groups = groupPlanRecordIds(
        ids: ['a', 'b', 'c'],
        objects: _objects,
        groupRelationKey: 'status',
        relation: _relations['status'],
        optionOrder: ['doing', 'todo'],
      );
      expect(groups.keys, ['doing', 'todo', 'done']);
      expect(groups['doing'], ['a']);
      expect(groups['todo'], ['b']);
      // 'done' was not in groupOrders and still shows up — a column nobody
      // ordered must not swallow its records.
      expect(groups['done'], ['c']);
    });

    test('a record with no status still gets a column (the empty one)', () {
      final objects = <String, PlanObject>{
        'a': PlanObject(id: 'a', struct: {'status': 'todo'}),
        'b': PlanObject(id: 'b', struct: <String, Object?>{}),
      };
      final groups = groupPlanRecordIds(
        ids: ['a', 'b'],
        objects: objects,
        groupRelationKey: 'status',
      );
      expect(groups.keys, ['todo', '']);
      expect(groups[''], ['b']);
    });

    test('a multi-valued tag appears in each of its columns', () {
      final groups = groupPlanRecordIds(
        ids: ['a', 'b', 'c'],
        objects: _objects,
        groupRelationKey: 'tags',
        relation: _relations['tags'],
      );
      expect(groups['client'], ['a', 'b']);
      expect(groups['urgent'], ['a']);
      expect(groups[''], ['c']);
    });
  });

  group('a collection is a membership list', () {
    test('membership filters before sorts and manual order', () {
      expect(
        selectPlanRecordIds(
          candidateIds: _all,
          objects: _objects,
          relations: _relations,
          membership: const ['b', 'c'],
          sorts: const [PlanSort(relationKey: 'name')],
        ),
        ['b', 'c'],
      );
    });

    test('a candidate id the store does not have cannot survive a filter', () {
      expect(
        selectPlanRecordIds(
          candidateIds: ['ghost', 'a'],
          objects: _objects,
          relations: _relations,
          filters: const [
            PlanFilter(
              relationKey: 'done',
              condition: PlanFilterCondition.notEmpty,
            ),
          ],
        ),
        ['a'],
      );
    });
  });

  group('value helpers are the single answer', () {
    test('normalizeValue keeps comparison honest for stored strings', () {
      final object = PlanObject(id: 'a', struct: {'effort': '7'});
      expect(planRelationValue(object, 'effort', _relations), 7.0);
      expect(planRelationValue(object, 'unknown', _relations), isNull);
    });

    test('empty text counts as no value, whitespace does not', () {
      final objects = <String, PlanObject>{
        'blank': PlanObject(id: 'blank', struct: {'name': ''}),
        'space': PlanObject(id: 'space', struct: {'name': ' '}),
      };
      final ids = selectPlanRecordIds(
        candidateIds: ['blank', 'space'],
        objects: objects,
        relations: _relations,
        filters: const [
          PlanFilter(relationKey: 'name', condition: PlanFilterCondition.empty),
        ],
      );
      expect(ids, ['blank']);
    });
  });
}
