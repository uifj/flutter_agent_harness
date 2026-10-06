// The mock plan space (ADR-0037 §"mock 是数据源，不是降级层").
//
// This seed exists so every capability in the inventory §1–§7 is reachable in
// the UI without a backend: four rendered viewers plus two that answer
// "not supported", a status relation with a colour per option, a board that
// groups by it, records with and without values (so empty placement and the
// empty column are visible), a type with recommended fields and a default
// template, an archived record the bin widget must show, and widgets across
// every section.
//
// It lives in `lib/model` and is pure Dart: swapping in a real source means
// overriding one provider with a different seed, never editing a widget.

import 'plan_block.dart';
import 'plan_dataview.dart';
import 'plan_object_type.dart';
import 'plan_relation.dart';
import 'plan_space.dart';
import 'plan_struct.dart';
import 'plan_template.dart';
import 'plan_widget.dart';

/// Keys the mock uses, so the seed and the UI agree on one spelling.
abstract final class PlanMockKeys {
  static const status = 'status';
  static const tags = 'tags';
  static const effort = 'effort';
  static const dueDate = 'dueDate';
  static const assignee = 'assignee';
  static const contact = 'contact';
  static const doc = 'doc';
  static const notes = 'ot-note';
  static const taskSet = 'set-tasks';
  static const inbox = 'col-inbox';
  static const typeProject = 'custom-project';
}

/// The demo seed's localized furniture names (ADR-0074). The model cannot
/// import the dictionaries, so `main` builds this from
/// `PlanSeedText.of(locale)` and hands it in. Fields default to the original
/// English literals so existing callers and tests stay valid.
class PlanSeedNames {
  const PlanSeedNames({
    this.deliveryBoard = 'Delivery board',
    this.readingInbox = 'Reading inbox',
    this.viewBoard = 'Board',
    this.viewAllTasks = 'All tasks',
    this.viewOpenOnly = 'Open only',
    this.viewCards = 'Cards',
    this.viewCalendar = 'Calendar',
    this.viewGraph = 'Graph',
    this.viewList = 'List',
    this.viewTable = 'Table',
    this.relStatus = 'Status',
    this.relTags = 'Tags',
    this.relEffort = 'Effort',
    this.relDue = 'Due',
    this.optTodo = 'Todo',
    this.optDoing = 'Doing',
    this.optBlocked = 'Blocked',
    this.optShipped = 'Shipped',
    this.optUrgent = 'Urgent',
    this.optClient = 'Client',
    this.optInternal = 'Internal',
  });

  final String deliveryBoard;
  final String readingInbox;
  final String viewBoard;
  final String viewAllTasks;
  final String viewOpenOnly;
  final String viewCards;
  final String viewCalendar;
  final String viewGraph;
  final String viewList;
  final String viewTable;
  final String relStatus;
  final String relTags;
  final String relEffort;
  final String relDue;
  final String optTodo;
  final String optDoing;
  final String optBlocked;
  final String optShipped;
  final String optUrgent;
  final String optClient;
  final String optInternal;

  /// The generation this seed shape writes — bumped when the seed's shape
  /// or language changes and a one-time re-seed should refresh demo spaces
  /// that still carry the previous generation untouched.
  static const int currentVersion = 2;
}

PlanSpaceSeed planMockSeed({PlanSeedNames names = const PlanSeedNames()}) =>
    PlanSpaceSeed(
      objects: _records(),
      collections: _collections(names),
      types: _types(),
      relations: _relations(names),
      templates: _templates(),
      widgets: _widgets(),
      bin: const {'r-archive'},
    );

List<PlanRelation> _relations(PlanSeedNames names) => [
  PlanRelation(
    id: 'rel-status',
    key: PlanMockKeys.status,
    name: names.relStatus,
    format: PlanRelationFormat.status,
    featured: true,
    options: [
      PlanRelationOption(id: 'todo', text: names.optTodo, colorIndex: 1),
      PlanRelationOption(id: 'doing', text: names.optDoing, colorIndex: 7),
      PlanRelationOption(id: 'blocked', text: names.optBlocked, colorIndex: 5),
      PlanRelationOption(id: 'shipped', text: names.optShipped, colorIndex: 9),
    ],
  ),
  PlanRelation(
    id: 'rel-tags',
    key: PlanMockKeys.tags,
    name: names.relTags,
    format: PlanRelationFormat.tag,
    options: [
      PlanRelationOption(id: 'urgent', text: names.optUrgent, colorIndex: 4),
      PlanRelationOption(id: 'client', text: names.optClient, colorIndex: 8),
      PlanRelationOption(
        id: 'internal',
        text: names.optInternal,
        colorIndex: 2,
      ),
    ],
  ),
  PlanRelation(
    id: 'rel-effort',
    key: PlanMockKeys.effort,
    name: names.relEffort,
    format: PlanRelationFormat.number,
  ),
  PlanRelation(
    id: 'rel-due',
    key: PlanMockKeys.dueDate,
    name: names.relDue,
    format: PlanRelationFormat.date,
  ),
  PlanRelation(
    id: 'rel-done',
    key: PlanRelationKeys.done,
    name: 'Done',
    format: PlanRelationFormat.checkbox,
  ),
  PlanRelation(
    id: 'rel-assignee',
    key: PlanMockKeys.assignee,
    name: 'Assignee',
    format: PlanRelationFormat.object,
  ),
  PlanRelation(
    id: 'rel-contact',
    key: PlanMockKeys.contact,
    name: 'Contact',
    format: PlanRelationFormat.email,
    hidden: true,
  ),
  PlanRelation(
    id: 'rel-doc',
    key: PlanMockKeys.doc,
    name: 'Document',
    format: PlanRelationFormat.file,
  ),
];

List<PlanObjectType> _types() => const [
  PlanObjectType(
    id: 'type-page',
    uniqueKey: PlanObjectTypeIds.page,
    name: 'Page',
    defaultType: true,
    pinned: true,
  ),
  PlanObjectType(
    id: 'type-note',
    uniqueKey: PlanObjectTypeIds.note,
    name: 'Note',
    iconEmoji: '📝',
    pinned: true,
    recommendedRelationKeys: [PlanMockKeys.tags],
  ),
  PlanObjectType(
    id: 'type-task',
    uniqueKey: PlanObjectTypeIds.task,
    name: 'Task',
    iconEmoji: '✅',
    layout: PlanTypeLayout.todo,
    pinned: true,
    recommendedRelationKeys: [
      PlanMockKeys.status,
      PlanMockKeys.dueDate,
      PlanRelationKeys.done,
      PlanMockKeys.effort,
    ],
    defaultTemplateId: 'tpl-task',
  ),
  PlanObjectType(
    id: 'type-bookmark',
    uniqueKey: PlanObjectTypeIds.bookmark,
    name: 'Bookmark',
    iconEmoji: '🔗',
    recommendedRelationKeys: [PlanRelationKeys.url],
  ),
  PlanObjectType(
    id: 'type-project',
    uniqueKey: PlanMockKeys.typeProject,
    name: 'Project',
    iconEmoji: '📁',
    recommendedRelationKeys: [
      PlanMockKeys.status,
      PlanMockKeys.assignee,
      PlanMockKeys.tags,
    ],
  ),
  PlanObjectType(
    id: 'type-archived',
    uniqueKey: 'custom-legacy',
    name: 'Legacy log',
    isArchived: true,
  ),
];

List<PlanCollection> _collections(PlanSeedNames names) => [
  PlanCollection(
    id: PlanMockKeys.taskSet,
    name: names.deliveryBoard,
    kind: PlanCollectionKind.set,
    sourceTypeKey: PlanObjectTypeIds.task,
    iconEmoji: '🚧',
    dataView: PlanDataView(
      viewers: [
        PlanViewer(
          id: 'v-board',
          name: 'Board',
          kind: PlanViewerKind.board,
          groupRelationKey: PlanMockKeys.status,
          groupBackgroundColors: true,
          relations: [
            PlanViewerRelation(key: PlanRelationKeys.name),
            PlanViewerRelation(key: PlanMockKeys.dueDate),
          ],
        ),
        PlanViewer(
          id: 'v-table',
          name: 'All tasks',
          kind: PlanViewerKind.grid,
          relations: [
            PlanViewerRelation(key: PlanRelationKeys.name),
            PlanViewerRelation(key: PlanMockKeys.status),
            PlanViewerRelation(
              key: PlanMockKeys.effort,
              width: PlanViewerSize.small,
            ),
            PlanViewerRelation(
              key: PlanMockKeys.dueDate,
              width: PlanViewerSize.small,
            ),
            PlanViewerRelation(key: PlanMockKeys.tags),
          ],
          sorts: [
            PlanSort(
              relationKey: PlanMockKeys.dueDate,
              emptyPlacement: PlanSortEmptyPlacement.end,
            ),
          ],
        ),
        PlanViewer(
          id: 'v-open',
          name: 'Open only',
          kind: PlanViewerKind.list,
          relations: [
            PlanViewerRelation(key: PlanRelationKeys.name),
            PlanViewerRelation(key: PlanMockKeys.status),
          ],
          filters: [
            PlanFilter(
              relationKey: PlanRelationKeys.done,
              condition: PlanFilterCondition.notEqual,
              value: true,
            ),
          ],
        ),
        PlanViewer(
          id: 'v-gallery',
          name: 'Cards',
          kind: PlanViewerKind.gallery,
          cardSize: PlanViewerSize.large,
          coverRelationKey: PlanMockKeys.doc,
          coverFit: true,
          relations: [
            PlanViewerRelation(key: PlanRelationKeys.name),
            PlanViewerRelation(key: PlanMockKeys.status),
          ],
        ),
        // Two kinds the upstream client does not draw. They are here so the
        // "not available yet" answer is a state the UI can actually reach.
        PlanViewer(
          id: 'v-calendar',
          name: 'Calendar',
          kind: PlanViewerKind.calendar,
        ),
        PlanViewer(
          id: 'v-graph',
          name: names.viewGraph,
          kind: PlanViewerKind.graph,
        ),
      ],
      activeViewerId: 'v-board',
      groupOrders: {
        'v-board': ['todo', 'doing', 'blocked', 'shipped'],
      },
    ),
  ),
  PlanCollection(
    id: PlanMockKeys.inbox,
    name: names.readingInbox,
    kind: PlanCollectionKind.collection,
    members: ['r-note-1', 'r-note-2', 'r-bookmark-1', 'r-image-1'],
    dataView: PlanDataView(
      viewers: [
        PlanViewer(
          id: 'v-inbox-list',
          name: 'List',
          kind: PlanViewerKind.list,
          relations: [
            PlanViewerRelation(key: PlanRelationKeys.name),
            PlanViewerRelation(key: PlanRelationKeys.url),
          ],
        ),
        PlanViewer(
          id: 'v-inbox-grid',
          name: 'Table',
          kind: PlanViewerKind.grid,
          relations: [
            PlanViewerRelation(key: PlanRelationKeys.name),
            PlanViewerRelation(key: PlanMockKeys.tags),
          ],
        ),
      ],
      activeViewerId: 'v-inbox-list',
    ),
  ),
];

List<PlanObject> _records() => const [
  PlanObject(
    id: 'r-task-1',
    struct: {
      PlanRelationKeys.name: 'Ship the viewer bar',
      PlanRelationKeys.type: PlanObjectTypeIds.task,
      PlanMockKeys.status: 'doing',
      PlanMockKeys.effort: 3,
      PlanMockKeys.dueDate: '2026-10-02',
      PlanMockKeys.tags: ['urgent', 'internal'],
      PlanRelationKeys.done: false,
      'editedAt': '2026-10-01T09:00:00.000',
    },
  ),
  PlanObject(
    id: 'r-task-2',
    struct: {
      PlanRelationKeys.name: 'Relation value editors for all eleven formats',
      PlanRelationKeys.type: PlanObjectTypeIds.task,
      PlanMockKeys.status: 'todo',
      PlanMockKeys.effort: 8,
      PlanMockKeys.dueDate: '2026-10-06',
      PlanMockKeys.tags: ['client'],
      'isFavorite': true,
      'editedAt': '2026-10-01T08:00:00.000',
    },
  ),
  PlanObject(
    id: 'r-task-3',
    struct: {
      PlanRelationKeys.name: 'Empty column check',
      PlanRelationKeys.type: PlanObjectTypeIds.task,
      PlanRelationKeys.done: false,
      'editedAt': '2026-09-30T18:00:00.000',
    },
  ),
  PlanObject(
    id: 'r-task-4',
    struct: {
      PlanRelationKeys.name: 'Blocked on the design token audit',
      PlanRelationKeys.type: PlanObjectTypeIds.task,
      PlanMockKeys.status: 'blocked',
      PlanMockKeys.effort: 2,
      PlanMockKeys.dueDate: '2026-09-25',
      PlanRelationKeys.done: false,
      'editedAt': '2026-09-29T11:00:00.000',
    },
  ),
  PlanObject(
    id: 'r-task-5',
    struct: {
      PlanRelationKeys.name: 'Kanban gate shipped',
      PlanRelationKeys.type: PlanObjectTypeIds.task,
      PlanMockKeys.status: 'shipped',
      PlanMockKeys.effort: 5,
      PlanRelationKeys.done: true,
      'editedAt': '2026-09-28T11:00:00.000',
    },
  ),
  PlanObject(
    id: 'r-note-1',
    struct: {
      PlanRelationKeys.name: 'Meeting notes 2026-10',
      PlanRelationKeys.type: PlanMockKeys.notes,
      PlanMockKeys.tags: ['internal'],
      'editedAt': '2026-10-01T07:30:00.000',
    },
  ),
  PlanObject(
    id: 'r-note-2',
    struct: {
      PlanRelationKeys.name: '一个很长的中文标题用来验证窄面板里的省略号行为是否还成立',
      PlanRelationKeys.type: PlanMockKeys.notes,
      PlanMockKeys.tags: ['client', 'urgent'],
      'editedAt': '2026-09-30T07:30:00.000',
    },
  ),
  PlanObject(
    id: 'r-bookmark-1',
    struct: {
      PlanRelationKeys.name: 'Anytype Android reference',
      PlanRelationKeys.type: PlanObjectTypeIds.bookmark,
      PlanRelationKeys.url: 'https://github.com/anyproto/anytype-kotlin',
      'editedAt': '2026-09-27T07:30:00.000',
    },
  ),
  PlanObject(
    id: 'r-image-1',
    struct: {
      PlanRelationKeys.name: 'Whiteboard photo',
      PlanRelationKeys.type: PlanObjectTypeIds.image,
      PlanMockKeys.doc: 'file:///whiteboard.png',
      PlanMockKeys.tags: ['client'],
      'editedAt': '2026-09-26T07:30:00.000',
    },
  ),
  PlanObject(
    id: 'r-archive',
    struct: {
      PlanRelationKeys.name: 'Retired checklist',
      PlanRelationKeys.type: PlanMockKeys.notes,
      'isArchived': true,
      'editedAt': '2026-09-01T07:30:00.000',
    },
  ),
  PlanObject(
    id: 'r-assignee',
    struct: {
      PlanRelationKeys.name: 'In Sail',
      PlanRelationKeys.type: PlanObjectTypeIds.profile,
      PlanMockKeys.contact: 'sail@example.com',
    },
  ),
];

List<PlanTemplate> _templates() => const [
  PlanTemplate(
    id: 'tpl-task',
    name: 'Default task',
    typeKey: PlanObjectTypeIds.task,
    isDefault: true,
    bundled: true,
    blocks: [
      PlanBlock(
        id: 'tb1',
        content: PlanText(text: 'Outcome', style: PlanTextStyle.title),
      ),
      PlanBlock(
        id: 'tb2',
        content: PlanText(text: '', style: PlanTextStyle.paragraph),
      ),
      PlanBlock(
        id: 'tb3',
        content: PlanText(
          text: 'Steps',
          style: PlanTextStyle.checkbox,
          checked: false,
        ),
      ),
    ],
  ),
  PlanTemplate(
    id: 'tpl-note',
    name: 'Meeting note',
    typeKey: PlanMockKeys.notes,
    blocks: [
      PlanBlock(
        id: 'nb1',
        content: PlanText(text: 'Attendees', style: PlanTextStyle.h2),
      ),
      PlanBlock(id: 'nb2', content: PlanDivider(PlanDividerStyle.line)),
    ],
  ),
];

List<PlanWidget> _widgets() => const [
  PlanWidget(
    id: 'w-pinned-set',
    source: PlanWidgetDefaultSource(PlanMockKeys.taskSet),
    layout: PlanWidgetLayout.tree,
    section: PlanWidgetSection.pinned,
    limit: 4,
  ),
  PlanWidget(
    id: 'w-pinned-inbox',
    source: PlanWidgetDefaultSource(PlanMockKeys.inbox),
    layout: PlanWidgetLayout.view,
    section: PlanWidgetSection.pinned,
    limit: 3,
  ),
  PlanWidget(
    id: 'w-pinned-note',
    source: PlanWidgetDefaultSource('r-note-1'),
    layout: PlanWidgetLayout.link,
  ),
  PlanWidget(
    id: 'w-favorites',
    source: PlanWidgetBundledSource(
      PlanBundledWidgetSourceIds.personalFavorites,
    ),
    layout: PlanWidgetLayout.compactList,
    section: PlanWidgetSection.myFavorites,
  ),
  PlanWidget(
    id: 'w-types',
    source: PlanWidgetBundledSource(PlanBundledWidgetSourceIds.allObjects),
    layout: PlanWidgetLayout.list,
    section: PlanWidgetSection.types,
  ),
  PlanWidget(
    id: 'w-recent',
    source: PlanWidgetBundledSource(PlanBundledWidgetSourceIds.recent),
    layout: PlanWidgetLayout.compactList,
    section: PlanWidgetSection.recentlyEdited,
    limit: 5,
  ),
  PlanWidget(
    id: 'w-chat',
    source: PlanWidgetBundledSource(PlanBundledWidgetSourceIds.chat),
    layout: PlanWidgetLayout.view,
    section: PlanWidgetSection.unread,
  ),
  PlanWidget(
    id: 'w-bin',
    source: PlanWidgetBundledSource(PlanBundledWidgetSourceIds.bin),
    layout: PlanWidgetLayout.list,
    section: PlanWidgetSection.recentlyEdited,
  ),
];
