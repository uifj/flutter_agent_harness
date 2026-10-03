// 本文件守住的那句话：记录是 `PlanStruct` 的视图，不是字段的类。
//
// ADR-0037 D1 的全部后果都在这：加一条关系不许改类、`unset` 是删键而不是写
// null、比较与 JSON 往返都只有一份表示、限制位的编码与 Anytype 一致（11 档，
// `core-models/.../restrictions/ObjectRestriction.kt:6-40`）。若有人把记录改回
// 固定字段，红的第一条就是这里的动态键断言。

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:planstar/model/plan_dataview.dart';
import 'package:planstar/model/plan_object_type.dart';
import 'package:planstar/model/plan_relation.dart';
import 'package:planstar/model/plan_struct.dart';

void main() {
  group('a record is a map, not a class', () {
    test('a relation nobody declared is still readable', () {
      final object = PlanObject(id: 'a', struct: {'weather': 'sunny'});
      expect(object.text('weather'), 'sunny');
      expect(object.name, '');
      // Anytype falls back to Page, not to "untyped" (ObjectTypeIds.kt:33).
      expect(object.typeKey, PlanObjectTypeIds.page);
    });

    test('values are read through their format, not through a field', () {
      final object = PlanObject(
        id: 'a',
        struct: {
          'effort': '42',
          'done': 'true',
          'dueDate': '2026-10-01T00:00:00.000',
          'tags': ['urgent', 'client'],
          'status': 'doing',
        },
      );
      expect(object.number('effort'), 42.0);
      expect(object.checkbox('done'), true);
      expect(object.date('dueDate')?.day, 1);
      expect(object.options('tags'), ['urgent', 'client']);
      // A status holds one option; the grouping code still gets a list.
      expect(object.options('status'), ['doing']);
      expect(object.options('missing'), isEmpty);
    });

    test('unset removes the key rather than writing null', () {
      final object = PlanObject(id: 'a', struct: {'name': 'x', 'note': 'y'});
      final unset = object.unset(['note']);
      expect(unset.struct.containsKey('note'), isFalse);
      expect(unset.hasRelation('note'), isFalse);
      // `amend` with a null value is the same door from the other side.
      expect(object.amend({'note': null}).hasRelation('note'), isFalse);
    });

    test('amend returns a new record and leaves the old one alone', () {
      final object = PlanObject(id: 'a', struct: {'name': 'before'});
      final next = object.amend({'name': 'after'});
      expect(object.name, 'before');
      expect(next.name, 'after');
      expect(next.id, 'a');
    });

    test('the present-relation list skips identity keys and nulls', () {
      final object = PlanObject(
        id: 'a',
        struct: {
          'name': 'x',
          'type': PlanObjectTypeIds.task,
          'note': null,
          'status': 'doing',
        },
      );
      expect(object.presentRelationKeys, ['status']);
    });

    test('json round-trips through one representation', () {
      final object = PlanObject(
        id: 'a',
        struct: {
          'name': 'x',
          'type': PlanObjectTypeIds.note,
          'tags': ['one', 'two'],
        },
      );
      final decoded = PlanObject.fromJson(
        jsonDecode(jsonEncode(object.toJson())) as Map<String, Object?>,
      );
      expect(decoded, object);
      expect(decoded.struct['tags'], ['one', 'two']);
    });
  });

  group('restriction bits are the same eleven Anytype ships', () {
    test('codes match upstream and survive a round-trip', () {
      expect(PlanObjectRestriction.values.length, 11);
      expect(PlanObjectRestriction.delete.code, 1);
      expect(PlanObjectRestriction.publish.code, 10);
      const set = {
        PlanObjectRestriction.delete,
        PlanObjectRestriction.typeChange,
      };
      expect(
        PlanObjectRestriction.codesToSet(PlanObjectRestriction.setToCodes(set)),
        set,
      );
      expect(PlanObjectRestriction.fromCode(99), PlanObjectRestriction.none);
    });

    test('the data view has its three restrictions', () {
      expect(PlanDataViewRestriction.values, [
        PlanDataViewRestriction.views,
        PlanDataViewRestriction.relation,
        PlanDataViewRestriction.createObject,
      ]);
    });

    test('origin codes are upstream nine', () {
      expect(PlanRelationKeys.originValues.length, 9);
      expect(PlanRelationKeys.originValues['sharingExtension'], 5);
      expect(PlanRelationKeys.originValues['bookmark'], 8);
    });
  });

  group('relations answer with their format', () {
    test('sixteen formats, eleven creatable', () {
      expect(PlanRelationFormat.values.length, 16);
      expect(PlanRelationFormat.creatable.length, 11);
      // The five the "new relation" sheet never offers.
      for (final hidden in [
        PlanRelationFormat.shortText,
        PlanRelationFormat.emoji,
        PlanRelationFormat.map,
        PlanRelationFormat.relations,
        PlanRelationFormat.undefined,
      ]) {
        expect(PlanRelationFormat.creatable, isNot(contains(hidden)));
      }
      expect(PlanRelationFormat.status.code, 3);
      expect(PlanRelationFormat.tag.code, 11);
      expect(PlanRelationFormat.object.code, 100);
    });

    test('normalising kills the "42" versus 42 fork', () {
      final number = const PlanRelation(
        id: 'r',
        key: 'n',
        name: 'N',
        format: PlanRelationFormat.number,
      );
      expect(number.normalizeValue('42'), 42.0);
      expect(number.normalizeValue(7), 7.0);
      expect(number.normalizeValue('nope'), isNull);

      final checkbox = const PlanRelation(
        id: 'r',
        key: 'c',
        name: 'C',
        format: PlanRelationFormat.checkbox,
      );
      expect(checkbox.normalizeValue('true'), isTrue);
      expect(checkbox.normalizeValue('0'), isFalse);

      final tag = const PlanRelation(
        id: 'r',
        key: 't',
        name: 'T',
        format: PlanRelationFormat.tag,
      );
      expect(tag.normalizeValue('one'), ['one']);
      expect(tag.normalizeValue(['a', 1]), ['a', '1']);

      final text = const PlanRelation(
        id: 'r',
        key: 'x',
        name: 'X',
        format: PlanRelationFormat.longText,
      );
      expect(text.normalizeValue('  '), isNotNull);
      expect(text.normalizeValue(''), isNull);
    });

    test('only status and tag carry options', () {
      expect(PlanRelationFormat.status.hasOptions, isTrue);
      expect(PlanRelationFormat.tag.hasOptions, isTrue);
      expect(PlanRelationFormat.checkbox.hasOptions, isFalse);
      expect(PlanRelationFormat.tag.isMultiValue, isTrue);
      expect(PlanRelationFormat.status.isMultiValue, isFalse);
    });

    test('a relation survives json', () {
      final relation = PlanRelation(
        id: 'r',
        key: 'status',
        name: 'Status',
        format: PlanRelationFormat.status,
        options: const [
          PlanRelationOption(id: 'todo', text: 'Todo', colorIndex: 1),
          PlanRelationOption(id: 'doing', text: 'Doing', colorIndex: 7),
        ],
        featured: true,
      );
      final decoded = PlanRelation.fromJson(
        jsonDecode(jsonEncode(relation.toJson())) as Map<String, Object?>,
      );
      expect(decoded.format, PlanRelationFormat.status);
      expect(decoded.optionText('doing'), 'Doing');
      expect(decoded.optionOrderIds, ['todo', 'doing']);
      expect(decoded.featured, isTrue);
      expect(decoded.hidden, isFalse);
    });

    test('derived and account relations are not editable', () {
      expect(PlanRelationSource.local.isEditable, isTrue);
      expect(PlanRelationSource.derived.isEditable, isFalse);
      expect(PlanRelationSource.account.isEditable, isFalse);
    });
  });

  group('object types keep the bundled list honest', () {
    test('twenty-one keys and the four groupings', () {
      expect(PlanObjectTypeIds.all.length, 23);
      expect(PlanObjectTypeIds.fileTypes, [
        PlanObjectTypeIds.file,
        PlanObjectTypeIds.image,
        PlanObjectTypeIds.audio,
        PlanObjectTypeIds.video,
      ]);
      expect(PlanObjectTypeIds.setTypes.length, 2);
      expect(
        PlanObjectTypeIds.typesWithoutTemplates,
        containsAll(PlanObjectTypeIds.setTypes),
      );
      expect(
        PlanObjectTypeIds.typesWithoutTemplates,
        contains(PlanObjectTypeIds.bookmark),
      );
    });

    test('no goal, no habit — that client has neither', () {
      expect(
        PlanObjectTypeIds.all,
        isNot(anyElement(contains('goal'))),
        reason: 'ADR-0037 §4: 0.50.4 defines no ot-goal',
      );
      expect(PlanObjectTypeIds.all, isNot(anyElement(contains('habit'))));
    });

    test('task and project are not special-cased screens', () {
      expect(PlanObjectTypeIds.specialCased, contains(PlanObjectTypeIds.task));
      expect(
        PlanObjectTypeIds.specialCased,
        isNot(contains(PlanObjectTypeIds.project)),
      );
    });

    test('templates are gated, and the collection types skip the picker', () {
      expect(PlanObjectTypeIds.allowsTemplates(PlanObjectTypeIds.page), isTrue);
      expect(PlanObjectTypeIds.allowsTemplates(PlanObjectTypeIds.set), isFalse);
      // A type's uniqueKey is its identity: `copyWith` deliberately does not
      // take it, so the two shapes are constructed, not mutated.
      const collectionType = PlanObjectType(
        id: 't2',
        uniqueKey: 'ot-collection',
        name: 'Collection',
      );
      const pageType = PlanObjectType(
        id: 't1',
        uniqueKey: 'ot-page',
        name: 'Page',
      );
      expect(collectionType.isDataSet, isTrue);
      expect(collectionType.skipsTemplatePicker, isTrue);
      expect(pageType.skipsTemplatePicker, isFalse);
      expect(pageType.allowsTemplates, isTrue);
    });

    test('marketplace ids are the _ot mirror, not a rename', () {
      expect(
        PlanMarketplaceIds.marketplaceKey(PlanObjectTypeIds.task),
        '_ottask',
      );
      expect(PlanMarketplaceIds.marketplaceSpaceId, '_anytype_marketplace');
    });

    test('a type survives json and keeps its recommended fields', () {
      final type = PlanObjectType(
        id: 'o',
        uniqueKey: 'ot-task',
        name: 'Task',
        layout: PlanTypeLayout.todo,
        recommendedRelationKeys: const ['status', 'dueDate'],
        defaultTemplateId: 'tpl',
        pinned: true,
      );
      final decoded = PlanObjectType.fromJson(
        jsonDecode(jsonEncode(type.toJson())) as Map<String, Object?>,
      );
      expect(decoded.layout, PlanTypeLayout.todo);
      expect(decoded.recommendedRelationKeys, ['status', 'dueDate']);
      expect(decoded.defaultTemplateId, 'tpl');
      expect(decoded.pinned, isTrue);
      // Task takes templates; only bookmarks, files, the two collection types
      // and the system types do not.
      expect(decoded.allowsTemplates, isTrue);
      expect(decoded.isBuiltIn, isTrue);
    });
  });

  group('viewers answer with data, not with absence', () {
    test('six kinds, five rendered locally — graph alone says no', () {
      expect(PlanViewerKind.values.length, 6);
      expect(
        PlanViewerKind.values.where((kind) => kind.renderedByClient).length,
        5,
        reason:
            'calendar renders locally since 2026-10-01 (the retired plan '
            'calendar panel moved into the collection view) — a registered '
            'extension over the mobile client, which renders four',
      );
      expect(
        PlanViewerKind.graph.unsupportedL10nKey,
        'planViewGraphUnsupported',
      );
      expect(
        PlanViewerKind.graph.unsupportedL10nKey,
        'planViewGraphUnsupported',
      );
      expect(PlanViewerKind.board.unsupportedL10nKey, isNull);
      expect(PlanViewerKind.grid.formattedName, 'Grid');
      expect(PlanViewerKind.board.formattedName, 'Board');
    });

    test('the kanban gate reuses the same card with its own reason', () {
      expect(
        PlanViewerDisabledReason.kanbanDisabled.l10nKey(PlanViewerKind.board),
        'planViewKanbanDisabled',
      );
      expect(
        PlanViewerDisabledReason.none.l10nKey(PlanViewerKind.calendar),
        'planViewCalendarUnsupported',
      );
    });

    test('column widths and date formats are tokens, not literals', () {
      expect(PlanViewerSize.small.columnWidth, 120);
      expect(PlanViewerSize.large.columnWidth, 260);
      final date = DateTime(2026, 10, 1, 15, 30);
      expect(PlanDateFormat.iso.format(date), '2026-10-01');
      expect(PlanDateFormat.short.format(date), '10/01/2026');
      expect(PlanDateFormat.monthAbbrBeforeDay.format(date), 'Oct 1, 2026');
      expect(PlanDateFormat.medium.format(date), 'Oct 1, 26');
      expect(PlanTimeFormat.h24.format(date), '15:30');
      expect(PlanTimeFormat.h12.format(date), '3:30 PM');
    });

    test('custom sort is never offered in the sheet', () {
      expect(PlanSortType.custom.isOfferedInSheet, isFalse);
      expect(PlanSortType.asc.isOfferedInSheet, isTrue);
      expect(PlanSortType.asc.formattedName, 'ascending');
      expect(PlanSortEmptyPlacement.notSpecific.formattedName, 'None');
    });

    test('a viewer survives json with columns, sorts and filters', () {
      final viewer = PlanViewer(
        id: 'v',
        name: 'By status',
        kind: PlanViewerKind.board,
        relations: const [
          PlanViewerRelation(key: 'name'),
          PlanViewerRelation(
            key: 'dueDate',
            width: PlanViewerSize.small,
            includeTime: true,
          ),
        ],
        sorts: const [PlanSort(relationKey: 'name')],
        filters: const [
          PlanFilter(
            relationKey: 'done',
            condition: PlanFilterCondition.equal,
            value: false,
          ),
        ],
        groupRelationKey: 'status',
        groupBackgroundColors: true,
        defaultObjectTypeId: PlanObjectTypeIds.task,
      );
      final dataView = PlanDataView(
        viewers: [viewer],
        activeViewerId: 'v',
        objectOrders: const {
          'v': ['a', 'b'],
        },
        groupOrders: const {
          'v': ['todo', 'doing'],
        },
      );
      final decoded = PlanDataView.fromJson(
        jsonDecode(jsonEncode(dataView.toJson())) as Map<String, Object?>,
      );
      expect(decoded.activeViewer?.kind, PlanViewerKind.board);
      expect(decoded.activeViewer?.visibleRelationKeys, ['name', 'dueDate']);
      expect(decoded.activeViewer?.relations.last.includeTime, isTrue);
      expect(decoded.activeViewer?.relations.last.width, PlanViewerSize.small);
      expect(decoded.activeViewer?.groupBackgroundColors, isTrue);
      expect(decoded.objectOrders['v'], ['a', 'b']);
      expect(decoded.groupOrders['v'], ['todo', 'doing']);
      expect(decoded.viewerById('nope'), isNull);
    });

    test('collections are an explicit membership; sets skip templates', () {
      expect(PlanCollectionKind.collection.skipsTemplatePicker, isFalse);
      expect(PlanCollectionKind.set.skipsTemplatePicker, isTrue);
      expect(PlanCollectionKind.typeSet.skipsTemplatePicker, isTrue);
      expect(PlanViewerEditAction.values.length, 7);
    });
  });
}
