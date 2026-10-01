// Document blocks (ADR-0037 §3). The tree mirrors Anytype's
// `Block.Content` sealed hierarchy (`core-models/.../Block.kt:78-426`) down to
// the code values, and — this is the part that matters — records WHICH of
// those the client can actually reach. Upstream declares 14 text styles but
// `QUOTE` has no insert path; it names 24 embed processors but renders none of
// them inline; it stores `JUSTIFY` but maps it back to start. Copying the
// vocabulary and silently "improving" the reachability would produce a
// document model that disagrees with the inventory it came from.

import 'plan_widget.dart';

/// The 14 text styles (`Block.Content.Text.Style`, `Block.kt:169`).
enum PlanTextStyle {
  paragraph('P'),
  h1('H1'),
  h2('H2'),
  h3('H3'),
  h4('H4'),
  title('TITLE'),
  quote('QUOTE'),
  codeSnippet('CODE_SNIPPET'),
  bullet('BULLET'),
  numbered('NUMBERED'),
  toggle('TOGGLE'),
  checkbox('CHECKBOX'),
  description('DESCRIPTION'),
  callout('CALLOUT');

  const PlanTextStyle(this.code);

  final String code;

  /// Reachable from the slash menu's Style section. `QUOTE` and `DESCRIPTION`
  /// are deliberately absent: upstream has no insert path for either
  /// (`SlashExtensions.kt:61-72`, and `DESCRIPTION` is a system row).
  static const insertable = <PlanTextStyle>[
    paragraph,
    title,
    h2,
    h3,
    callout,
    checkbox,
    bullet,
    numbered,
    toggle,
    codeSnippet,
  ];

  bool get isHeading => this == h1 || this == h2 || this == h3 || this == h4;

  bool get isList => this == bullet || this == numbered;

  /// Alignment is not offered for list, checkbox, toggle or callout rows
  /// (`SlashExtensions.kt:116-131`).
  bool get supportsAlignment =>
      !isList && this != checkbox && this != toggle && this != callout;

  static PlanTextStyle fromCode(String code) =>
      values.firstWhere((value) => value.code == code, orElse: () => paragraph);
}

/// The 11 mark types (`Block.Content.Text.Mark.Type`, `Block.kt:148-160`).
enum PlanMarkType {
  strikethrough,
  keyboard,
  italic,
  bold,
  underline,
  link,
  textColor,
  backgroundColor,
  mention,
  emoji,
  object;

  /// Marks the selection toolbar exposes — eight, matching
  /// `widget_markup_toolbar_main.xml:10-123`. `mention`, `emoji` and `object`
  /// are written by the @ panel and the renderer, not by the toolbar.
  static const toolbarReachable = <PlanMarkType>[
    bold,
    italic,
    strikethrough,
    underline,
    keyboard,
    link,
    textColor,
    backgroundColor,
  ];

  /// A clickable mark: the renderer makes these tappable
  /// (`Block.kt:163 isClickableMark`).
  bool get isClickable => this == link || this == mention || this == object;
}

/// Alignment. `justify` exists upstream and is NOT honoured by the client
/// (`MapperExtension.kt:280-286` maps it back to start), so the value is kept
/// and the renderer answers with start.
enum PlanAlign {
  start,
  center,
  end,
  justify;

  bool get isInsertable => this != justify;
}

/// The 11-stop colour ladder both text colour and background colour draw from
/// (`core-models/.../ThemeColor.kt:10-42`).
abstract final class PlanThemeColors {
  static const names = <String>[
    'default',
    'grey',
    'yellow',
    'orange',
    'red',
    'pink',
    'purple',
    'blue',
    'ice',
    'teal',
    'lime',
  ];

  static int indexOf(String name) => names.indexOf(name);
}

/// `Block.Content.Layout.Type` (`Block.kt:175`).
enum PlanLayoutType {
  row,
  column,
  div,
  header,
  tableRow,
  tableColumn;

  /// The mobile renderer flattens row/column containers to the same indent
  /// (`DefaultBlockViewRenderer.kt:660-684`); only the table pair is structural.
  bool get isStructural => this == tableRow || this == tableColumn;
}

/// `Block.Content.File.Type` (`Block.kt:232`) and its state machine (`:233`).
enum PlanFileKind {
  none,
  file,
  image,
  video,
  audio,
  pdf;

  /// Only these three open in-app; file and pdf hand off to another app
  /// (`Command.kt:38` — the client has no PDF renderer).
  bool get hasOwnViewer => this == image || this == video || this == audio;
}

enum PlanFileState { empty, uploading, done, error }

/// `Block.Content.Link`'s four enums (`Block.kt:185-196`).
enum PlanLinkType { page, dataView, dashboard, archive }

enum PlanLinkIconSize { none, small, medium }

enum PlanLinkCardStyle { text, card, inline }

enum PlanLinkDescription { none, added, content }

/// `Block.Content.Bookmark.State` (`Block.kt:257`).
enum PlanBookmarkState { empty, fetching, done, error }

/// `Block.Content.DataView.Embed.Processor` — all 24 (`Block.kt:383-407`).
enum PlanEmbedProcessor {
  mermaid(1),
  chart(2),
  youtube(3),
  vimeo(4),
  soundcloud(5),
  googleMaps(6),
  miro(7),
  figma(8),
  twitter(9),
  openStreetMap(10),
  reddit(11),
  facebook(12),
  instagram(13),
  telegram(14),
  githubGist(15),
  codepen(16),
  bilibili(17),
  excalidraw(18),
  kroki(19),
  graphviz(20),
  sketchfab(21),
  image(22),
  drawio(23),
  spotify(24);

  const PlanEmbedProcessor(this.code);

  final int code;

  /// The 15 that need a URL (`EmbedExt.kt:47-67`); the other nine render as
  /// "this content is not available on mobile" with their payload replaced.
  bool get needsUrl => switch (this) {
    mermaid ||
    chart ||
    excalidraw ||
    kroki ||
    graphviz ||
    codepen ||
    githubGist ||
    drawio ||
    image => false,
    _ => true,
  };

  /// Upstream renders NO embed inline — the placeholder card is the answer
  /// (`EmbedPlaceholder.kt:60-91`), and there is no insert path for any of them.
  bool get rendersInline => false;

  static PlanEmbedProcessor fromCode(int code) =>
      values.firstWhere((value) => value.code == code, orElse: () => mermaid);
}

/// A half-open range in [PlanText.text]. Local by necessity: `TextRange` lives
/// in `dart:ui`, and `lib/model` may not import Flutter (invariant 2 — the
/// same reason `lib/model/fs_revision.dart` is a plain listener table).
class PlanMarkRange {
  const PlanMarkRange(this.start, this.end);

  final int start;
  final int end;

  int get length => end - start;

  PlanMarkRange shifted(int delta) => PlanMarkRange(start + delta, end + delta);

  @override
  bool operator ==(Object other) =>
      other is PlanMarkRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'PlanMarkRange($start..$end)';
}

/// A text mark with its range in [text].
class PlanMark {
  const PlanMark({required this.range, required this.type, this.param});

  final PlanMarkRange range;
  final PlanMarkType type;

  /// Link target for [PlanMarkType.link]; unused otherwise.
  final String? param;

  PlanMark shift(int delta) => delta == 0
      ? this
      : PlanMark(range: range.shifted(delta), type: type, param: param);

  Map<String, Object?> toJson() => {
    'start': range.start,
    'end': range.end,
    'type': type.name,
    if (param != null) 'param': param,
  };

  static PlanMark fromJson(Map<String, Object?> json) => PlanMark(
    range: PlanMarkRange(
      (json['start'] as num?)?.toInt() ?? 0,
      (json['end'] as num?)?.toInt() ?? 0,
    ),
    type: PlanMarkType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => PlanMarkType.bold,
    ),
    param: json['param'] as String?,
  );
}

/// The block content vocabulary. One variant per upstream content type, plus
/// [Raw], which is this app's lossless-passthrough answer for anything the
/// Markdown file can hold but the block model cannot express.
sealed class PlanBlockContent {
  const PlanBlockContent();
}

class PlanText extends PlanBlockContent {
  const PlanText({
    required this.text,
    this.style = PlanTextStyle.paragraph,
    this.marks = const [],
    this.color,
    this.background,
    this.align = PlanAlign.start,
    this.checked,
    this.iconEmoji,
    this.iconImageId,
  });

  final String text;
  final PlanTextStyle style;
  final List<PlanMark> marks;
  final String? color;
  final String? background;
  final PlanAlign align;
  final bool? checked;

  /// Callout icon (`Block.kt:105-106`).
  final String? iconEmoji;
  final String? iconImageId;
}

class PlanLayout extends PlanBlockContent {
  const PlanLayout(this.type);

  final PlanLayoutType type;
}

class PlanDivider extends PlanBlockContent {
  const PlanDivider(this.style);

  final PlanDividerStyle style;
}

enum PlanDividerStyle { line, dots }

class PlanFile extends PlanBlockContent {
  const PlanFile({
    required this.kind,
    this.target,
    this.state = PlanFileState.empty,
    this.name,
    this.mime,
    this.addedBy,
  });

  final PlanFileKind kind;
  final String? target;
  final PlanFileState state;
  final String? name;
  final String? mime;
  final String? addedBy;
}

class PlanLink extends PlanBlockContent {
  const PlanLink({
    required this.target,
    this.type = PlanLinkType.page,
    this.iconSize = PlanLinkIconSize.small,
    this.cardStyle = PlanLinkCardStyle.text,
    this.description = PlanLinkDescription.none,
  });

  final String target;
  final PlanLinkType type;
  final PlanLinkIconSize iconSize;
  final PlanLinkCardStyle cardStyle;
  final PlanLinkDescription description;
}

class PlanBookmark extends PlanBlockContent {
  const PlanBookmark({this.url, this.state = PlanBookmarkState.empty});

  final String? url;
  final PlanBookmarkState state;
}

class PlanLatex extends PlanBlockContent {
  const PlanLatex(this.source);

  final String source;
}

class PlanEmbed extends PlanBlockContent {
  const PlanEmbed({required this.processor, this.target});

  final PlanEmbedProcessor processor;
  final String? target;
}

class PlanRelationBlock extends PlanBlockContent {
  const PlanRelationBlock(this.key);

  final String? key;
}

class PlanFeaturedRelations extends PlanBlockContent {
  const PlanFeaturedRelations();
}

class PlanTableOfContents extends PlanBlockContent {
  const PlanTableOfContents();
}

class PlanTableBlock extends PlanBlockContent {
  const PlanTableBlock({this.isHeader = false});

  /// Upstream's `TableRow(isHeader)`; `SetTableRowHeader` is never called by
  /// that client, so no UI writes it (`EditorTableDelegate.kt:93`).
  final bool isHeader;
}

class PlanWidgetBlock extends PlanBlockContent {
  const PlanWidgetBlock({
    required this.layout,
    this.limit = 0,
    this.activeViewId,
  });

  final PlanWidgetLayout layout;
  final int limit;
  final String? activeViewId;
}

class PlanUnsupported extends PlanBlockContent {
  const PlanUnsupported([this.reason = 'unsupported']);

  final String reason;
}

/// Lossless fallback: the source line as it was read, re-emitted verbatim.
class PlanRawLine extends PlanBlockContent {
  const PlanRawLine(this.source);

  final String source;
}

/// One block: identity, content, children (nesting is a tree, not an indent).
class PlanBlock {
  const PlanBlock({
    required this.id,
    required this.content,
    this.children = const [],
  });

  final String id;
  final PlanBlockContent content;
  final List<PlanBlock> children;

  PlanBlock copyWith({PlanBlockContent? content, List<PlanBlock>? children}) =>
      PlanBlock(
        id: id,
        content: content ?? this.content,
        children: children ?? this.children,
      );

  /// Depth-first ids, the order the renderer draws and the store keeps.
  List<String> get flattenedIds => [
    id,
    for (final child in children) ...child.flattenedIds,
  ];

  Map<String, Object?> toJson() => {
    'id': id,
    'content': contentJson(content),
    if (children.isNotEmpty)
      'children': [for (final child in children) child.toJson()],
  };

  static PlanBlock fromJson(Map<String, Object?> json) => PlanBlock(
    id: json['id'] as String? ?? '',
    content: contentFromJson(
      (json['content'] as Map<String, Object?>?) ?? const {},
    ),
    children: [
      for (final child in (json['children'] as List<Object?>? ?? const []))
        if (child is Map<String, Object?>) PlanBlock.fromJson(child),
    ],
  );

  /// Content is serialised as a tagged map: the record model (D1) keeps one
  /// representation, and a block tree written to disk must not need a class
  /// per variant on the read side.
  static Map<String, Object?> contentJson(PlanBlockContent content) =>
      switch (content) {
        final PlanText text => {
          'kind': 'text',
          'text': text.text,
          'style': text.style.code,
          'align': text.align.name,
          if (text.marks.isNotEmpty)
            'marks': [for (final m in text.marks) m.toJson()],
          if (text.color != null) 'color': text.color,
          if (text.background != null) 'background': text.background,
          if (text.checked != null) 'checked': text.checked,
          if (text.iconEmoji != null) 'iconEmoji': text.iconEmoji,
          if (text.iconImageId != null) 'iconImageId': text.iconImageId,
        },
        final PlanLayout layout => {'kind': 'layout', 'type': layout.type.name},
        final PlanDivider divider => {
          'kind': 'divider',
          'style': divider.style.name,
        },
        final PlanFile file => {
          'kind': 'file',
          'fileType': file.kind.name,
          'state': file.state.name,
          if (file.target != null) 'target': file.target,
          if (file.name != null) 'name': file.name,
          if (file.mime != null) 'mime': file.mime,
        },
        final PlanLink link => {
          'kind': 'link',
          'target': link.target,
          'type': link.type.name,
          'iconSize': link.iconSize.name,
          'cardStyle': link.cardStyle.name,
          'description': link.description.name,
        },
        final PlanBookmark bookmark => {
          'kind': 'bookmark',
          'state': bookmark.state.name,
          if (bookmark.url != null) 'url': bookmark.url,
        },
        final PlanLatex latex => {'kind': 'latex', 'source': latex.source},
        final PlanEmbed embed => {
          'kind': 'embed',
          'processor': embed.processor.code,
          if (embed.target != null) 'target': embed.target,
        },
        final PlanRelationBlock relation => {
          'kind': 'relation',
          if (relation.key != null) 'key': relation.key,
        },
        PlanFeaturedRelations() => {'kind': 'featuredRelations'},
        PlanTableOfContents() => {'kind': 'toc'},
        final PlanTableBlock table => {
          'kind': 'table',
          'isHeader': table.isHeader,
        },
        final PlanWidgetBlock widget => {
          'kind': 'widget',
          'layout': widget.layout.code,
          'limit': widget.limit,
          if (widget.activeViewId != null) 'activeView': widget.activeViewId,
        },
        final PlanRawLine raw => {'kind': 'raw', 'source': raw.source},
        final PlanUnsupported unsupported => {
          'kind': 'unsupported',
          'reason': unsupported.reason,
        },
      };

  static PlanBlockContent contentFromJson(Map<String, Object?> json) {
    final marks = [
      for (final entry in (json['marks'] as List<Object?>? ?? const []))
        if (entry is Map<String, Object?>) PlanMark.fromJson(entry),
    ];
    return switch (json['kind']) {
      'text' => PlanText(
        text: json['text'] as String? ?? '',
        style: PlanTextStyle.fromCode(json['style'] as String? ?? 'P'),
        marks: marks,
        color: json['color'] as String?,
        background: json['background'] as String?,
        align: PlanAlign.values.firstWhere(
          (value) => value.name == json['align'],
          orElse: () => PlanAlign.start,
        ),
        checked: json['checked'] as bool?,
        iconEmoji: json['iconEmoji'] as String?,
        iconImageId: json['iconImageId'] as String?,
      ),
      'layout' => PlanLayout(
        PlanLayoutType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => PlanLayoutType.div,
        ),
      ),
      'divider' => PlanDivider(
        json['style'] == 'dots' ? PlanDividerStyle.dots : PlanDividerStyle.line,
      ),
      'file' => PlanFile(
        kind: PlanFileKind.values.firstWhere(
          (value) => value.name == json['fileType'],
          orElse: () => PlanFileKind.none,
        ),
        state: PlanFileState.values.firstWhere(
          (value) => value.name == json['state'],
          orElse: () => PlanFileState.empty,
        ),
        target: json['target'] as String?,
        name: json['name'] as String?,
        mime: json['mime'] as String?,
      ),
      'link' => PlanLink(
        target: json['target'] as String? ?? '',
        type: PlanLinkType.values.firstWhere(
          (value) => value.name == json['type'],
          orElse: () => PlanLinkType.page,
        ),
        iconSize: PlanLinkIconSize.values.firstWhere(
          (value) => value.name == json['iconSize'],
          orElse: () => PlanLinkIconSize.small,
        ),
        cardStyle: PlanLinkCardStyle.values.firstWhere(
          (value) => value.name == json['cardStyle'],
          orElse: () => PlanLinkCardStyle.text,
        ),
        description: PlanLinkDescription.values.firstWhere(
          (value) => value.name == json['description'],
          orElse: () => PlanLinkDescription.none,
        ),
      ),
      'bookmark' => PlanBookmark(
        url: json['url'] as String?,
        state: PlanBookmarkState.values.firstWhere(
          (value) => value.name == json['state'],
          orElse: () => PlanBookmarkState.empty,
        ),
      ),
      'latex' => PlanLatex(json['source'] as String? ?? ''),
      'embed' => PlanEmbed(
        processor: PlanEmbedProcessor.fromCode(
          (json['processor'] as num?)?.toInt() ?? 1,
        ),
        target: json['target'] as String?,
      ),
      'relation' => PlanRelationBlock(json['key'] as String?),
      'featuredRelations' => const PlanFeaturedRelations(),
      'toc' => const PlanTableOfContents(),
      'table' => PlanTableBlock(isHeader: json['isHeader'] == true),
      'widget' => PlanWidgetBlock(
        layout: PlanWidgetLayout.fromCode(
          (json['layout'] as num?)?.toInt() ?? 2,
        ),
        limit: (json['limit'] as num?)?.toInt() ?? 0,
        activeViewId: json['activeView'] as String?,
      ),
      'raw' => PlanRawLine(json['source'] as String? ?? ''),
      _ => const PlanUnsupported(),
    };
  }
}

/// The insert menu's sections, as data — the same seven Anytype's slash menu
/// has, with the same two commented-out entries recorded as absent rather than
/// quietly added.
enum PlanSlashItem {
  styleText,
  styleTitle,
  styleHeading,
  styleSubheading,
  styleHighlighted,
  styleCallout,
  styleCheckbox,
  styleBulleted,
  styleNumbered,
  styleToggle,
  file,
  picture,
  video,
  bookmark,
  code,
  line,
  dots,
  tableOfContents,
  table,
  linkTo,
  selectDate,
  property,
  delete,
  duplicate,
  copy,
  paste,
  move,
  moveTo;

  /// Every one of these is reachable in Anytype's slash menu; the two entries
  /// the upstream file has commented out (`PropertyNew`, `CleanStyle`) are not
  /// in this list at all — see the inventory §3.1.
  static const insertableActions = <PlanSlashItem>[
    delete,
    duplicate,
    copy,
    paste,
    move,
    moveTo,
  ];

  static const styleSection = <PlanSlashItem>[
    styleText,
    styleTitle,
    styleHeading,
    styleSubheading,
    styleHighlighted,
    styleCallout,
    styleCheckbox,
    styleBulleted,
    styleNumbered,
    styleToggle,
  ];

  static const mediaSection = <PlanSlashItem>[
    file,
    picture,
    video,
    bookmark,
    code,
  ];

  static const otherSection = <PlanSlashItem>[
    line,
    dots,
    tableOfContents,
    table,
  ];

  static PlanTextStyle textStyleFor(PlanSlashItem item) => switch (item) {
    styleText => PlanTextStyle.paragraph,
    styleTitle => PlanTextStyle.title,
    styleHeading => PlanTextStyle.h2,
    styleSubheading => PlanTextStyle.h3,
    styleHighlighted => PlanTextStyle.callout,
    styleCallout => PlanTextStyle.callout,
    styleCheckbox => PlanTextStyle.checkbox,
    styleBulleted => PlanTextStyle.bullet,
    styleNumbered => PlanTextStyle.numbered,
    styleToggle => PlanTextStyle.toggle,
    _ => PlanTextStyle.paragraph,
  };

  /// `table(NxM)`, clamped to 1–25 rows and columns
  /// (`SlashExtensions.kt:308-325`, `CreateTable.kt:33-37`).
  static ({int rows, int columns}) parseTablePattern(String query) {
    final match = RegExp(r'^table\((\d+)x(\d+)\)$').firstMatch(query.trim());
    if (match == null) return (rows: 1, columns: 1);
    int clamp(String value) => ((int.tryParse(value) ?? 1)).clamp(1, 25);
    return (rows: clamp(match.group(1)!), columns: clamp(match.group(2)!));
  }
}
