// 本文件守住的那句话：企划的 store 是唯一真值，盘上只有 `plan_space.json` 一份，
// 而"某个视图现在显示什么"永远是 (collection, viewer) 的纯函数结果。
//
// ADR-0037 P2 的四条后果都在这里验：原子写与损坏文件读空回落种子（沿
// `plan_task_store` 的先例）、每次变更一步单调 revision（Anytype 用它防渲染被去重吞掉）、
// 订阅按集合计数（`ObjectStore.kt:50-60`）、以及上游那三处"最后一个不能删"的门
// （最后一个视图、不可创建的格式、不给模板的类型）。

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:planstar/model/plan_dataview.dart';
import 'package:planstar/state/app_database.dart';
import 'package:planstar/model/plan_mock_content.dart';
import 'package:planstar/model/plan_object_type.dart';
import 'package:planstar/model/plan_relation.dart';
import 'package:planstar/model/plan_space.dart';
import 'package:planstar/model/plan_struct.dart';
import 'package:planstar/model/plan_widget.dart';
import 'package:planstar/state/plan_object_store.dart';

void main() {
  _legacyGroup();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plan_space');
  });

  AppDatabase? db;

  tearDown(() async {
    await db?.close();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<PlanObjectStore> open({PlanSpaceSeed? seed}) async {
    db = AppDatabase.open(File('${root.path}/planstar.db'));
    return PlanObjectStore.open(db!, root: root, seed: seed ?? planMockSeed());
  }

  group('the file is the only truth', () {
    test(
      'a fresh space comes from the seed and persists on first write',
      () async {
        final store = await open();
        expect(store.collections.length, 2);
        expect(store.objects.length, 11);
        final file = File('${root.path}/plan_space.json');
        expect(file.existsSync(), isFalse);
        await store.toggleRecord('r-task-1');
        expect(store.byId('r-task-1')!.isDone, isTrue);
        // The rows are in the database now (ADR-0071): a fresh connection
        // reads the persisted state back.
        final freshDb = AppDatabase.open(File('${root.path}/planstar.db'));
        final rows = await freshDb.select(freshDb.planRecordRows).get();
        await freshDb.close();
        expect(rows.where((row) => row.kind == 'object'), hasLength(11));
      },
    );

    test(
      'reopening reads back the same state and keeps the revision',
      () async {
        final store = await open();
        await store.amendRecord('r-task-3', {'status': 'doing'});
        final revision = store.revision;
        final reopened = await open(seed: null);
        expect(reopened.revision, revision);
        expect(reopened.byId('r-task-3')!.text('status'), 'doing');
        expect(reopened.binIds, {'r-archive'});
      },
    );

    test('a corrupt file falls back to the seed instead of throwing', () async {
      File('${root.path}/plan_space.json').writeAsStringSync('{not json');
      final store = await open();
      expect(store.collections, isNotEmpty);
    });

    test('an empty file with no seed opens empty', () async {
      File('${root.path}/plan_space.json').writeAsStringSync(
        jsonEncode({'objects': [], 'collections': [], 'revision': 0}),
      );
      final store = await open(seed: const PlanSpaceSeed());
      expect(store.objects, isEmpty);
      expect(store.collections, isEmpty);
    });
  });

  group('revision is a render guarantee', () {
    test('one step per mutation, and the stage carries it', () async {
      final store = await open();
      expect(store.revision, 0);
      final before = store.stageFor(PlanMockKeys.taskSet).revision;
      await store.toggleRecord('r-task-1');
      expect(store.revision, 1);
      expect(store.stageFor(PlanMockKeys.taskSet).revision, 1);
      expect(store.stageFor(PlanMockKeys.taskSet).revision, isNot(before));
    });

    test('listeners fire exactly once per mutation', () async {
      final store = await open();
      var notifications = 0;
      store.addListener(() => notifications++);
      await store.toggleRecord('r-task-1');
      await store.amendRecord('r-task-2', {'effort': 9});
      expect(notifications, 2);
    });
  });

  group('stageFor answers per viewer kind', () {
    test('grid sorts by date with the valueless record last', () async {
      final store = await open();
      final stage = store.stageFor(PlanMockKeys.taskSet, viewerId: 'v-table');
      expect(stage.ids.first, 'r-task-4'); // 2026-09-25, the earliest
      expect(stage.ids.last, isNot('r-task-3')); // no due date ⇒ empty last
      expect(stage.records.length, stage.ids.length);
      expect(stage.viewer?.kind, PlanViewerKind.grid);
    });

    test('a filter row removes what it should and keeps the rest', () async {
      final store = await open();
      final all = store.stageFor(PlanMockKeys.taskSet, viewerId: 'v-table').ids;
      final openOnly = store.stageFor(PlanMockKeys.taskSet, viewerId: 'v-open');
      expect(openOnly.ids, hasLength(all.length - 1));
      expect(
        openOnly.ids,
        isNot(contains('r-task-5')),
      ); // the shipped, done one
    });

    test(
      'board groups by status with groupOrders and an empty column',
      () async {
        final store = await open();
        final stage = store.stageFor(PlanMockKeys.taskSet, viewerId: 'v-board');
        expect(
          stage.groups.keys,
          containsAll(['todo', 'doing', 'blocked', 'shipped']),
        );
        expect(stage.groups['doing'], ['r-task-1']);
        expect(stage.groups[''], contains('r-task-3'));
        // groupOrders lists the four known options; the empty bucket stays last.
        expect(stage.groups.keys.toList().sublist(0, 4), [
          'todo',
          'doing',
          'blocked',
          'shipped',
        ]);
      },
    );

    test('graph alone is a reachable state that answers unsupported', () async {
      final store = await open();
      final graph = store.stageFor(PlanMockKeys.taskSet, viewerId: 'v-graph');
      expect(graph.isUnsupported, isTrue);
      expect(graph.unsupportedReasonKey, 'planViewGraphUnsupported');
      expect(graph.ids, isEmpty);
      // Calendar renders locally since 2026-10-01 (the retired plan
      // calendar panel moved into the collection view): the stage answers
      // records, not an excuse.
      final calendar = store.stageFor(
        PlanMockKeys.taskSet,
        viewerId: 'v-calendar',
      );
      expect(calendar.isUnsupported, isFalse);
      expect(calendar.ids, isNotEmpty);
    });

    test(
      'a collection stage uses its membership list, not a type query',
      () async {
        final store = await open();
        final stage = store.stageFor(PlanMockKeys.inbox);
        expect(stage.ids, [
          'r-note-1',
          'r-note-2',
          'r-bookmark-1',
          'r-image-1',
        ]);
        expect(stage.collection.kind, PlanCollectionKind.collection);
      },
    );

    test('an unknown collection or viewer is still a legal stage', () async {
      final store = await open();
      expect(store.stageFor('ghost').ids, isEmpty);
      expect(
        store.stageFor(PlanMockKeys.taskSet, viewerId: 'ghost').viewer,
        isNull,
      );
    });
  });

  group('view management is data', () {
    test(
      'adding a viewer appends and activates it, columns from relations',
      () async {
        final store = await open();
        await store.addViewer(PlanMockKeys.taskSet, PlanViewerKind.gallery);
        final view = store.collectionById(PlanMockKeys.taskSet)!.dataView;
        expect(view.viewers.length, 7);
        expect(view.activeViewer?.kind, PlanViewerKind.gallery);
        expect(
          view.activeViewer!.relations.map((r) => r.key),
          contains('status'),
        );
        expect(
          view.activeViewer!.relations
              .firstWhere((r) => r.key == 'status')
              .isVisible,
          isTrue,
        );
      },
    );

    test(
      'rename, duplicate after the source, and the last-view guard',
      () async {
        final store = await open();
        await store.renameViewer(PlanMockKeys.taskSet, 'v-board', 'Sprint 12');
        expect(
          store
              .collectionById(PlanMockKeys.taskSet)!
              .dataView
              .viewerById('v-board')!
              .name,
          'Sprint 12',
        );
        await store.duplicateViewer(PlanMockKeys.taskSet, 'v-board');
        final viewers = store
            .collectionById(PlanMockKeys.taskSet)!
            .dataView
            .viewers;
        expect(viewers[1].name, 'Sprint 12 (1)');
        expect(viewers[1].kind, PlanViewerKind.board);

        // Down to one, then the delete is refused.
        for (final viewer in viewers.map((v) => v.id).toList()) {
          if (viewer != 'v-board') {
            await store.removeViewer(PlanMockKeys.taskSet, viewer);
          }
        }
        await store.removeViewer(PlanMockKeys.taskSet, 'v-board');
        expect(
          store.collectionById(PlanMockKeys.taskSet)!.dataView.viewers.length,
          1,
        );
      },
    );

    test(
      'removing the active viewer falls back to the first remaining one',
      () async {
        final store = await open();
        await store.setActiveViewer(PlanMockKeys.taskSet, 'v-gallery');
        await store.removeViewer(PlanMockKeys.taskSet, 'v-gallery');
        expect(
          store.collectionById(PlanMockKeys.taskSet)!.activeViewer!.id,
          'v-board',
        );
      },
    );

    test(
      'reordering the tab strip is stored, and orders are cleaned up',
      () async {
        final store = await open();
        await store.setManualOrder(PlanMockKeys.taskSet, 'v-table', [
          'r-task-1',
          'r-task-2',
        ]);
        await store.removeViewer(PlanMockKeys.taskSet, 'v-table');
        final view = store.collectionById(PlanMockKeys.taskSet)!.dataView;
        expect(view.objectOrders.containsKey('v-table'), isFalse);
        // Remaining order was [board, open, gallery, calendar, graph]; moving
        // index 0 to index 2 lands the board third.
        await store.moveViewer(PlanMockKeys.taskSet, 0, 2);
        expect(
          store
              .collectionById(PlanMockKeys.taskSet)!
              .dataView
              .viewers
              .map((viewer) => viewer.id),
          ['v-open', 'v-gallery', 'v-board', 'v-calendar', 'v-graph'],
        );
      },
    );
  });

  group('manual order is the custom sort', () {
    test(
      'a custom sort reads the stored order and keeps unlisted records',
      () async {
        final store = await open();
        await store.setManualOrder(PlanMockKeys.taskSet, 'v-open', [
          'r-task-4',
          'r-task-1',
        ]);
        await store.setViewerSorts(PlanMockKeys.taskSet, 'v-open', const [
          PlanSort(relationKey: 'name', type: PlanSortType.custom),
        ]);
        final ids = store
            .stageFor(PlanMockKeys.taskSet, viewerId: 'v-open')
            .ids;
        expect(ids.first, 'r-task-4');
        expect(ids[1], 'r-task-1');
        expect(ids, hasLength(4));
      },
    );

    test('a board drag writes the relation and the column order', () async {
      final store = await open();
      await store.moveWithinBoard(
        collectionId: PlanMockKeys.taskSet,
        viewerId: 'v-board',
        recordId: 'r-task-1',
        toOptionId: 'blocked',
        toIndex: 0,
      );
      expect(store.byId('r-task-1')!.text('status'), 'blocked');
      final stage = store.stageFor(PlanMockKeys.taskSet, viewerId: 'v-board');
      expect(stage.groups['blocked']!.first, 'r-task-1');
      expect(stage.groups['doing'], isNot(contains('r-task-1')));
    });

    test('dragging into the empty column clears the relation', () async {
      final store = await open();
      await store.moveWithinBoard(
        collectionId: PlanMockKeys.taskSet,
        viewerId: 'v-board',
        recordId: 'r-task-2',
        toOptionId: '',
        toIndex: 0,
      );
      expect(store.byId('r-task-2')!.hasRelation('status'), isFalse);
      expect(
        store.stageFor(PlanMockKeys.taskSet, viewerId: 'v-board').groups[''],
        contains('r-task-2'),
      );
    });
  });

  group('the store enforces the same gates as the client', () {
    test(
      'only the eleven creatable formats can be created, and keys are unique',
      () async {
        final store = await open();
        expect(
          await store.createRelation(
            key: 'mood',
            name: 'Mood',
            format: PlanRelationFormat.emoji,
          ),
          isNull,
        );
        expect(
          (await store.createRelation(
            key: 'phase',
            name: 'Phase',
            format: PlanRelationFormat.status,
          ))!.format,
          PlanRelationFormat.status,
        );
        expect(
          await store.createRelation(
            key: 'phase',
            name: 'Phase',
            format: PlanRelationFormat.status,
          ),
          isNull,
        );
        expect(store.relations.length, 9);
      },
    );

    test('deleting an option also clears it from every record', () async {
      final store = await open();
      await store.deleteRelationOptions('tags', ['client']);
      expect(store.byId('r-note-2')!.options('tags'), ['urgent']);
      expect(store.byId('r-task-1')!.options('tags'), ['urgent', 'internal']);
      expect(store.byId('r-image-1')!.hasRelation('tags'), isFalse);
      expect(store.relationByKey('tags')!.options.map((o) => o.id), [
        'urgent',
        'internal',
      ]);
    });

    test(
      'option order, featured and hidden flags are stored, not inferred',
      () async {
        final store = await open();
        await store.setRelationOptionOrder('status', [
          'shipped',
          'todo',
          'doing',
          'blocked',
        ]);
        expect(store.relationByKey('status')!.optionOrderIds.first, 'shipped');
        await store.setRelationFeatured('effort', featured: true);
        expect(store.relationByKey('effort')!.featured, isTrue);
        await store.setRelationHidden('contact', hidden: false);
        expect(store.relationByKey('contact')!.hidden, isFalse);
      },
    );

    test('bookmark and set types get no template', () async {
      final store = await open();
      expect(
        await store.createTemplate(
          name: 'Nope',
          typeKey: PlanObjectTypeIds.bookmark,
        ),
        isNull,
      );
      final template = await store.createTemplate(
        name: 'Checklist',
        typeKey: PlanObjectTypeIds.task,
      );
      expect(template, isNotNull);
      await store.setDefaultTemplate(PlanObjectTypeIds.task, template!.id);
      expect(
        store.typeByKey(PlanObjectTypeIds.task)!.defaultTemplateId,
        template.id,
      );
      expect(
        store.templates
            .where((t) => t.isDefault && t.typeKey == 'ot-task')
            .single
            .id,
        template.id,
      );
      await store.deleteTemplate(template.id);
      expect(store.templates.where((t) => t.id == template.id), isEmpty);
    });

    test('one default type at a time, and archiving keeps the key', () async {
      final store = await open();
      await store.setDefaultType('type-note');
      expect(
        store.types.where((t) => t.defaultType).single.uniqueKey,
        PlanMockKeys.notes,
      );
      await store.archiveType('type-project', archived: true);
      expect(store.typeByKey(PlanMockKeys.typeProject)!.isArchived, isTrue);
      await store.pinType('type-project', pinned: true);
      expect(store.typeByKey(PlanMockKeys.typeProject)!.pinned, isTrue);
      final created = await store.createType(
        name: 'Reading list',
        iconEmoji: '📚',
      );
      expect(created.isBuiltIn, isFalse);
      expect(created.iconEmoji, '📚');
    });
  });

  group('records, bin and read seams', () {
    test('values are normalized on write', () async {
      final store = await open();
      await store.amendRecord('r-task-1', {'effort': '7'});
      expect(store.byId('r-task-1')!.number('effort'), 7.0);
      await store.amendRecord('r-task-1', {'dueDate': DateTime(2026, 10, 3)});
      expect(store.byId('r-task-1')!.date('dueDate')!.day, 3);
      await store.unsetRecord('r-task-1', ['dueDate']);
      expect(store.byId('r-task-1')!.date('dueDate'), isNull);
    });

    test(
      'a new record gets the type, the collection and the recommended keys',
      () async {
        final store = await open();
        final record = await store.createRecord(
          collectionId: PlanMockKeys.inbox,
          typeKey: PlanObjectTypeIds.task,
          values: {PlanRelationKeys.name: 'Fresh'},
        );
        expect(record.typeKey, PlanObjectTypeIds.task);
        expect(record.name, 'Fresh');
        expect(
          store.collectionById(PlanMockKeys.inbox)!.members,
          contains(record.id),
        );
        expect(store.stageFor(PlanMockKeys.inbox).ids, contains(record.id));
        // A set does not store membership: its candidate list is the type query.
        expect(store.collectionById(PlanMockKeys.taskSet)!.members, isEmpty);
        expect(
          store.stageFor(PlanMockKeys.taskSet, viewerId: 'v-table').ids,
          contains(record.id),
        );
      },
    );

    test('bin: archive, restore, empty', () async {
      final store = await open();
      expect(store.binRecords.map((r) => r.id), ['r-archive']);
      await store.archiveRecords(['r-note-2']);
      expect(store.binRecords.length, 2);
      await store.restoreRecords(['r-note-2']);
      expect(store.binRecords.length, 1);
      expect(store.byId('r-note-2')!.hasRelation('isArchived'), isFalse);
      await store.emptyBin();
      expect(store.binRecords, isEmpty);
      expect(store.byId('r-archive'), isNull);
    });

    test('favorites, recents, type queries and unlinked', () async {
      final store = await open();
      expect(store.favorites.map((r) => r.id), ['r-task-2']);
      await store.setFavorite('r-note-1', favorite: true);
      expect(store.favorites.length, 2);
      expect(store.recentlyEdited.first.id, 'r-task-1');
      expect(store.recordsOfType(PlanMockKeys.notes).length, 2);
      expect(store.unlinkedRecords, isNotEmpty);
      await store.amendRecord('r-task-1', {
        'links': ['r-note-1'],
      });
      expect(store.unlinkedRecords.any((r) => r.id == 'r-task-1'), isFalse);
    });

    test('restrictions come off the record, not off a guess', () async {
      final store = await open();
      expect(store.restrictionsFor(store.byId('r-task-1')!), isEmpty);
      await store.amendRecord('r-task-1', {
        planRestrictionsKey: [1, 5, 10],
      });
      expect(store.restrictionsFor(store.byId('r-task-1')!), {
        PlanObjectRestriction.delete,
        PlanObjectRestriction.typeChange,
        PlanObjectRestriction.publish,
      });
    });
  });

  group('widgets and subscriptions', () {
    test('the widget list is section-ordered and editable', () async {
      final store = await open();
      expect(store.widgets.first.section, PlanWidgetSection.pinned);
      await store.changeWidgetLayout(
        'w-pinned-note',
        PlanWidgetLayout.compactList,
      );
      expect(
        store.widgets.firstWhere((w) => w.id == 'w-pinned-note').form,
        PlanWidgetForm.listOfObjects,
      );
      await store.setWidgetLimit('w-pinned-note', 2);
      expect(store.widgets.firstWhere((w) => w.id == 'w-pinned-note').limit, 2);
      await store.setWidgetActiveView('w-pinned-set', 'v-board');
      expect(
        store.widgets.firstWhere((w) => w.id == 'w-pinned-set').activeViewId,
        'v-board',
      );
      await store.addWidget(source: const PlanWidgetDefaultSource('r-note-1'));
      expect(store.widgets.length, 9);
      await store.removeWidget('w-pinned-note');
      expect(store.widgets.length, 8);
      await store.reorderWidgets(0, 2);
      expect(store.widgets.first.id, isNot('w-pinned-set'));
    });

    test('subscriptions count per collection and release at zero', () async {
      final store = await open();
      store.subscribe(PlanMockKeys.taskSet);
      store.subscribe(PlanMockKeys.taskSet);
      expect(store.subscriptionsFor(PlanMockKeys.taskSet), 2);
      store.unsubscribe(PlanMockKeys.taskSet);
      expect(store.subscriptionsFor(PlanMockKeys.taskSet), 1);
      store.unsubscribe(PlanMockKeys.taskSet);
      expect(store.subscriptionsFor(PlanMockKeys.taskSet), 0);
      store.unsubscribe('never-subscribed');
      expect(store.subscriptionsFor('never-subscribed'), 0);
    });
  });

  // The groupOrders write-back is a registered extension over the mobile
  // client (its columns are read-only there); the board's column drag lands
  // here, so the store path needs its own pin.
  group('group order write-back', () {
    test('a viewer order survives a save and feeds the grouping', () async {
      final store = await open();
      addTearDown(store.dispose);
      await store.setGroupOrder(PlanMockKeys.taskSet, 'v-board', [
        'doing',
        'todo',
        'shipped',
        'blocked',
        '',
      ]);
      final readBack = store
          .collectionById(PlanMockKeys.taskSet)!
          .dataView
          .groupOrders['v-board'];
      expect(readBack, ['doing', 'todo', 'shipped', 'blocked', '']);

      // The grouping engine answers columns in that order.
      final groups = store
          .stageFor(PlanMockKeys.taskSet, viewerId: 'v-board')
          .groups;
      expect(groups.keys.toList(), ['doing', 'todo', 'shipped', 'blocked', '']);
    });
  });
}

// ADR-0071: the one-time import from the legacy plan_space.json carrier.
void _legacyGroup() {
  group('legacy plan_space.json import', () {
    late Directory root;
    AppDatabase? db;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('plan_space_legacy');
    });

    tearDown(() async {
      await db?.close();
      if (root.existsSync()) await root.delete(recursive: true);
    });

    test('imports once, keeps records, deletes the file', () async {
      File('${root.path}/plan_space.json').writeAsStringSync(
        jsonEncode({
          'revision': 4,
          'objects': [
            {
              'id': 'r-1',
              'type': 'task',
              'struct': {'status': 'todo'},
            },
          ],
          'collections': [],
          'types': [],
          'relations': [],
          'templates': [],
          'widgets': [],
          'bin': ['r-2'],
        }),
      );

      db = AppDatabase.open(File('${root.path}/planstar.db'));
      final store = await PlanObjectStore.open(db!, root: root, seed: null);
      expect(store.objects, hasLength(1));
      expect(store.revision, 4);
      expect(store.binIds, {'r-2'});
      expect(File('${root.path}/plan_space.json').existsSync(), isFalse);

      // The database is now the only carrier: reopening reads the rows.
      final reopened = await PlanObjectStore.open(db!, root: root, seed: null);
      expect(reopened.objects, hasLength(1));
    });

    test('a corrupt legacy file is deleted unread', () async {
      File('${root.path}/plan_space.json').writeAsStringSync('{"torn');
      db = AppDatabase.open(File('${root.path}/planstar.db'));
      final store = await PlanObjectStore.open(db!, root: root, seed: null);
      expect(store.objects, isEmpty);
      expect(File('${root.path}/plan_space.json').existsSync(), isFalse);
    });
  });
}
