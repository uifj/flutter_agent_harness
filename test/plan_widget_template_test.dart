// 本文件守住的那句话：组件（widget）的上游答案是"13 形态 / 5 布局 / 7 内置源 /
// 没有尺寸概念 / 行数是关系"，模板的答案是"null 模板 = 空白页 + 类型决定能不能带模板"。
//
// ADR-0037 §6–§7。两条最容易悄悄漂移的地方：一是有人会给组件加一个 `size` 字段
// （上游没有，`WidgetTypeView.kt:12-16` 只有布局），二是模板选择器会失去"什么都不选"
// 这条路（`ApplyTemplate.kt:26-30` 明确 null ⇒ 空白）。这里的断言就是钉住这两点的。

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_harness/model/plan_block.dart';
import 'package:agent_harness/model/plan_object_type.dart';
import 'package:agent_harness/model/plan_relation.dart';
import 'package:agent_harness/model/plan_struct.dart';
import 'package:agent_harness/model/plan_template.dart';
import 'package:agent_harness/model/plan_widget.dart';

void main() {
  group('widget forms, layouts and sources', () {
    test(
      'thirteen forms, three auxiliary, five layouts, seven bundled ids',
      () {
        expect(PlanWidgetForm.forms.length, 13);
        expect(PlanWidgetForm.auxiliary.length, 3);
        expect(PlanWidgetLayout.values.length, 5);
        expect(PlanBundledWidgetSourceIds.ids.length, 7);
        expect(PlanWidgetSection.values.length, 5);
      },
    );

    test('layout codes are the upstream ones', () {
      expect(PlanWidgetLayout.tree.code, 1);
      expect(PlanWidgetLayout.link.code, 0);
      expect(PlanWidgetLayout.list.code, 2);
      expect(PlanWidgetLayout.compactList.code, 3);
      expect(PlanWidgetLayout.view.code, 4);
      expect(PlanWidgetLayout.fromCode(99), PlanWidgetLayout.list);
    });

    test('a bundled source resolves to its own form, not to a layout', () {
      PlanWidgetForm bundled(String id) => PlanWidgetForm.resolve(
        layout: PlanWidgetLayout.tree,
        isBundledSource: true,
        bundledId: id,
      );
      expect(bundled(PlanBundledWidgetSourceIds.bin), PlanWidgetForm.bin);
      expect(
        bundled(PlanBundledWidgetSourceIds.allObjects),
        PlanWidgetForm.allContent,
      );
      expect(
        bundled(PlanBundledWidgetSourceIds.chat),
        PlanWidgetForm.spaceChat,
      );
      expect(
        bundled(PlanBundledWidgetSourceIds.favorite),
        PlanWidgetForm.listOfObjects,
      );
      expect(
        bundled(PlanBundledWidgetSourceIds.recent),
        PlanWidgetForm.recentlyEdited,
      );
    });

    test('a concrete object uses its layout, and view means gallery', () {
      expect(
        PlanWidgetForm.resolve(
          layout: PlanWidgetLayout.view,
          isBundledSource: false,
          bundledId: null,
        ),
        PlanWidgetForm.gallery,
      );
      expect(
        PlanWidgetForm.resolve(
          layout: PlanWidgetLayout.link,
          isBundledSource: false,
          bundledId: null,
        ),
        PlanWidgetForm.link,
      );
    });

    test('there is no size: only a layout and a relation-backed row limit', () {
      const widget = PlanWidget(id: 'w', source: PlanWidgetDefaultSource('o1'));
      expect(widget.resolvedLimit(), 6);
      expect(widget.copyWith(limit: 3).resolvedLimit(), 3);
      // A stored zero is "no preference", not "show nothing".
      expect(widget.copyWith(limit: 0).resolvedLimit(), 6);
      expect(
        widget.copyWith(source: const PlanWidgetBundledSource('bin')).objectId,
        isNull,
      );
    });

    test('a widget json survives and keeps its section', () {
      final widget = PlanWidget(
        id: 'w',
        source: const PlanWidgetBundledSource(PlanBundledWidgetSourceIds.chat),
        layout: PlanWidgetLayout.compactList,
        limit: 4,
        activeViewId: 'v',
        section: PlanWidgetSection.unread,
      );
      final decoded = PlanWidget.fromJson(widget.toJson());
      expect(decoded.source.isBundled, isTrue);
      expect(decoded.layout, PlanWidgetLayout.compactList);
      expect(decoded.limit, 4);
      expect(decoded.activeViewId, 'v');
      expect(decoded.section, PlanWidgetSection.unread);
      expect(decoded.form, PlanWidgetForm.spaceChat);
    });

    test('dropdown actions are gated on the source, not the layout', () {
      const bin = PlanWidget(
        id: 'w',
        source: PlanWidgetBundledSource(PlanBundledWidgetSourceIds.bin),
      );
      const objectWidget = PlanWidget(
        id: 'w2',
        source: PlanWidgetDefaultSource('o1'),
      );
      expect(PlanWidgetAction.applies(PlanWidgetAction.emptyBin, bin), isTrue);
      expect(
        PlanWidgetAction.applies(PlanWidgetAction.emptyBin, objectWidget),
        isFalse,
      );
      expect(
        PlanWidgetAction.applies(PlanWidgetAction.favoriteObject, objectWidget),
        isTrue,
      );
      expect(
        PlanWidgetAction.applies(PlanWidgetAction.changeType, bin),
        isTrue,
      );
    });

    test('the strip orders by section, keeping stored order inside it', () {
      final ordered = orderPlanWidgets(const [
        PlanWidget(
          id: 'r2',
          source: PlanWidgetDefaultSource('b'),
          section: PlanWidgetSection.recentlyEdited,
        ),
        PlanWidget(
          id: 'p1',
          source: PlanWidgetDefaultSource('a'),
          section: PlanWidgetSection.pinned,
        ),
        PlanWidget(
          id: 't1',
          source: PlanWidgetDefaultSource('c'),
          section: PlanWidgetSection.types,
        ),
      ]);
      expect(ordered.map((widget) => widget.id), ['p1', 't1', 'r2']);
    });
  });

  group('templates answer blank when nothing is picked', () {
    test('a null template means an empty page', () {
      expect(planTemplateContent(null), isEmpty);
      const withContent = PlanTemplate(
        id: 't',
        name: 'Meeting',
        typeKey: PlanObjectTypeIds.page,
        blocks: [
          PlanBlock(
            id: 'b1',
            content: PlanText(text: 'Agenda', style: PlanTextStyle.h2),
          ),
        ],
      );
      expect(planTemplateContent(withContent).length, 1);
    });

    test('types that may not carry templates get an empty picker', () {
      const templates = [
        PlanTemplate(id: 't1', name: 'One', typeKey: 'ot-bookmark'),
        PlanTemplate(id: 't2', name: 'Two', typeKey: 'ot-page'),
      ];
      expect(
        planTemplatesForType(templates, PlanObjectTypeIds.bookmark),
        isEmpty,
      );
      expect(
        planTemplatesForType(templates, PlanObjectTypeIds.page).single.id,
        't2',
      );
      expect(planTemplatesForType(templates, PlanObjectTypeIds.set), isEmpty);
    });

    test('the default template is listed first', () {
      final templates = [
        const PlanTemplate(id: 'a', name: 'A', typeKey: 'ot-task'),
        const PlanTemplate(
          id: 'b',
          name: 'B',
          typeKey: 'ot-task',
          isDefault: true,
        ),
      ];
      final listed = planTemplatesForType(templates, PlanObjectTypeIds.task);
      expect(listed.first.id, 'b');
      expect(listed.last.id, 'a');
    });

    test('a template with blocks round-trips json', () {
      final template = PlanTemplate(
        id: 't',
        name: 'Weekly',
        typeKey: PlanObjectTypeIds.note,
        bundled: true,
        blocks: const [
          PlanBlock(
            id: 'b1',
            content: PlanText(text: 'Focus', style: PlanTextStyle.checkbox),
          ),
          PlanBlock(
            id: 'b2',
            content: PlanDivider(PlanDividerStyle.dots),
            children: [],
          ),
        ],
      );
      final decoded = PlanTemplate.fromJson(template.toJson());
      expect(decoded.bundled, isTrue);
      expect(decoded.blocks.length, 2);
      expect(
        (decoded.blocks.first.content as PlanText).style,
        PlanTextStyle.checkbox,
      );
      expect(
        (decoded.blocks.last.content as PlanDivider).style,
        PlanDividerStyle.dots,
      );
    });

    test('a gallery package counts what it installs', () {
      const pack = PlanGalleryPackage(
        id: 'g',
        name: 'Research',
        types: [
          PlanObjectType(id: 'x', uniqueKey: 'custom-source', name: 'Source'),
        ],
        templates: [
          PlanTemplate(id: 'y', name: 'Reading note', typeKey: 'ot-note'),
        ],
      );
      expect(pack.contentCount, 2);
    });
  });

  group('the mock vocabulary is the same vocabulary', () {
    test('a record built from recommended fields reads its relations', () {
      const type = PlanObjectType(
        id: 't',
        uniqueKey: 'ot-task',
        name: 'Task',
        layout: PlanTypeLayout.todo,
        recommendedRelationKeys: ['status', 'dueDate', 'done'],
      );
      final record = PlanObject(
        id: 'r',
        struct: {
          PlanRelationKeys.name: 'Write the viewers',
          PlanRelationKeys.type: type.uniqueKey,
          'status': 'doing',
          'dueDate': '2026-10-09',
          'done': false,
        },
      );
      expect(record.name, 'Write the viewers');
      expect(record.typeKey, PlanObjectTypeIds.task);
      expect(record.date('dueDate')?.day, 9);
      expect(record.options('status'), ['doing']);
      expect(type.recommendedRelationKeys, record.presentRelationKeys);
    });

    test('the task record answers a status option through its relation', () {
      const status = PlanRelation(
        id: 'r',
        key: 'status',
        name: 'Status',
        format: PlanRelationFormat.status,
        options: [
          PlanRelationOption(id: 'doing', text: 'Doing', colorIndex: 7),
        ],
      );
      expect(status.optionText('doing'), 'Doing');
      expect(status.optionText('ghost'), 'ghost');
    });
  });
}
