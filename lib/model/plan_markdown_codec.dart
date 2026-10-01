// Markdown ⇄ blocks (ADR-0037 D3): the plan workspace's notes stay `.md` files
// on disk, and the block tree is what the editor holds in memory. One disk
// format, one in-memory shape — a second persisted representation would be the
// "two values that must be equal" failure ADR-0014 already names.
//
// The codec's contract is therefore round-trip stability, not coverage:
// anything it cannot express survives as [PlanRawLine] and is re-emitted
// byte-for-byte. That is also why `toggle`, `callout` colour and the 24 embeds
// are not invented here — upstream has no Markdown form for them either, and a
// fake one would silently rewrite the user's file.
//
// The editor, however, can CREATE blocks markdown has no form for, and the
// first audit (2026-10-01) caught those vanishing on save (`default: return
// ''`) or writing literal `![null]()`. For blocks the editor produces but the
// markdown vocabulary cannot carry, the codec writes a one-line envelope —
// `<!-- plan:{json} -->`, the whole block as JSON — and reads it back on the
// next decode. The file stays legal Markdown (an HTML comment renders as
// nothing), the user's content survives, and hand-written files without the
// envelope decode exactly as before.

import 'dart:convert';

import 'plan_block.dart';

/// Parse a Markdown document into top-level blocks.
List<PlanBlock> decodePlanMarkdown(String source, {String Function()? newId}) {
  final nextId = newId ?? _counter();
  final lines = source.split('\n');
  final blocks = <PlanBlock>[];

  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final trimmed = line.trimRight();

    // The editor's envelope: a block markdown cannot express, saved as JSON.
    if (trimmed.startsWith('<!-- plan:') && trimmed.endsWith('-->')) {
      try {
        final json = jsonDecode(
          trimmed.substring('<!-- plan:'.length, trimmed.length - 3),
        );
        if (json is Map<String, Object?>) {
          blocks.add(PlanBlock.fromJson(json));
          continue;
        }
      } on FormatException {
        // Not ours, or corrupt: fall through and keep the line as literal
        // text — a comment the user wrote must not become a crash.
      }
    }

    // Fenced code: everything up to the closing fence is one text block.
    if (trimmed.startsWith('```')) {
      final body = <String>[];
      i++;
      while (i < lines.length && !lines[i].trimRight().startsWith('```')) {
        body.add(lines[i]);
        i++;
      }
      blocks.add(
        PlanBlock(
          id: nextId(),
          content: PlanText(
            text: body.join('\n'),
            style: PlanTextStyle.codeSnippet,
          ),
        ),
      );
      continue;
    }

    // Math fence: `$$ … $$` on its own lines is a LaTeX block.
    if (trimmed == r'$$') {
      final body = <String>[];
      i++;
      while (i < lines.length && lines[i].trimRight() != r'$$') {
        body.add(lines[i]);
        i++;
      }
      blocks.add(PlanBlock(id: nextId(), content: PlanLatex(body.join('\n'))));
      continue;
    }

    if (trimmed.isEmpty) {
      blocks.add(
        PlanBlock(
          id: nextId(),
          content: const PlanText(text: ''),
        ),
      );
      continue;
    }

    // Table row, with the header separator consumed by the row above it.
    if (trimmed.startsWith('|')) {
      if (_isTableSeparator(trimmed)) {
        if (blocks.isNotEmpty) {
          final last = blocks.last;
          blocks.last = last.copyWith(
            content: last.content is PlanTableBlock
                ? PlanTableBlock(isHeader: true)
                : last.content,
          );
        }
        continue;
      }
      final cells = _splitTableRow(trimmed);
      blocks.add(
        PlanBlock(
          id: nextId(),
          content: const PlanTableBlock(),
          children: [
            for (final cell in cells)
              PlanBlock(
                id: nextId(),
                content: _textFor(cell, PlanTextStyle.paragraph),
              ),
          ],
        ),
      );
      continue;
    }

    if (_dividerFor(trimmed) case final PlanDividerStyle style) {
      blocks.add(PlanBlock(id: nextId(), content: PlanDivider(style)));
      continue;
    }

    if (trimmed.startsWith('> ')) {
      blocks.add(
        PlanBlock(
          id: nextId(),
          content: _textFor(trimmed.substring(2), PlanTextStyle.quote),
        ),
      );
      continue;
    }

    // Checkbox first: `- [x]` would otherwise be read as a bullet.
    // The payload after the box may be empty — an unchecked row the user
    // just created is `- [ ] ` with nothing after it, and it used to fall
    // through to the bullet branch.
    final checkbox = RegExp(r'^[-*]\s+\[( |x|X)\]\s*(.*)$').firstMatch(trimmed);
    if (checkbox != null) {
      final checked = checkbox.group(1)!.toLowerCase() == 'x';
      blocks.add(
        PlanBlock(
          id: nextId(),
          content: _textFor(
            checkbox.group(2)!,
            PlanTextStyle.checkbox,
            checked: checked,
          ),
        ),
      );
      continue;
    }

    final bullet = RegExp(r'^[-*]\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      blocks.add(
        PlanBlock(
          id: nextId(),
          content: _textFor(bullet.group(1)!, PlanTextStyle.bullet),
        ),
      );
      continue;
    }

    final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
    if (numbered != null) {
      blocks.add(
        PlanBlock(
          id: nextId(),
          content: _textFor(numbered.group(2)!, PlanTextStyle.numbered),
        ),
      );
      continue;
    }

    final heading = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      final style = switch (heading.group(1)!.length) {
        1 => PlanTextStyle.h1,
        2 => PlanTextStyle.h2,
        3 => PlanTextStyle.h3,
        _ => PlanTextStyle.h4,
      };
      blocks.add(
        PlanBlock(id: nextId(), content: _textFor(heading.group(2)!, style)),
      );
      continue;
    }

    // A lone image line is a file block; anything else stays a paragraph and
    // an image inside a sentence keeps its Markdown form as raw text.
    final image = RegExp(r'^!\[([^\]]*)\]\(([^)]*)\)$').firstMatch(trimmed);
    if (image != null) {
      blocks.add(
        PlanBlock(
          id: nextId(),
          content: PlanFile(
            kind: PlanFileKind.image,
            target: image.group(2),
            name: image.group(1),
            state: PlanFileState.done,
          ),
        ),
      );
      continue;
    }

    blocks.add(
      PlanBlock(
        id: nextId(),
        content: _textFor(trimmed, PlanTextStyle.paragraph),
      ),
    );
  }

  return blocks;
}

/// Write the block tree back to Markdown.
String encodePlanMarkdown(List<PlanBlock> blocks) {
  final out = <String>[];
  for (final block in blocks) {
    out.add(_encodeBlock(block));
  }
  return out.join('\n');
}

String _encodeBlock(PlanBlock block) {
  final content = block.content;
  switch (content) {
    case PlanRawLine(:final source):
      return source;
    case PlanDivider(:final style):
      return style == PlanDividerStyle.dots ? '***' : '---';
    case PlanLatex(:final source):
      return '\$\$\n$source\n\$\$';
    case PlanTableBlock(:final isHeader):
      final cells = [for (final child in block.children) _plainText(child)];
      final row = '| ${cells.join(' | ')} |';
      if (!isHeader) return row;
      final separator = '| ${cells.map((_) => '---').join(' | ')} |';
      return '$row\n$separator';
    case PlanFile(:final kind, :final target, :final name, :final state):
      // A real file line needs both its name and its target; anything else
      // (the empty/uploading/error states the editor mints) used to write
      // literal `![null]()` — the envelope carries the block instead.
      if (state == PlanFileState.done && name != null && name.isNotEmpty) {
        if (kind == PlanFileKind.image) {
          return '![$name](${target ?? name})';
        }
        return '[$name](${target ?? name})';
      }
      return _envelope(block);
    case PlanText():
      // Markdown carries this text block only if every field it styles has a
      // vocabulary form; otherwise the envelope keeps the block whole.
      if (!_markdownCarries(content)) return _envelope(block);
      final prefix = switch (content.style) {
        PlanTextStyle.h1 => '# ',
        PlanTextStyle.h2 => '## ',
        PlanTextStyle.h3 => '### ',
        PlanTextStyle.h4 => '#### ',
        PlanTextStyle.quote => '> ',
        PlanTextStyle.bullet => '- ',
        PlanTextStyle.numbered => '1. ',
        PlanTextStyle.checkbox => content.checked == true ? '- [x] ' : '- [ ] ',
        _ => '',
      };
      if (content.style == PlanTextStyle.codeSnippet) {
        return '```\n${content.text}\n```';
      }
      final text = _applyMarks(content.text, content.marks);
      // An empty list/check row is still a row: dropping the prefix silently
      // deleted a checkbox the user had created.
      return content.text.isEmpty && prefix.isEmpty ? '' : '$prefix$text';
    case PlanBookmark():
    case PlanLink():
    case PlanTableOfContents():
    case PlanEmbed():
    case PlanRelationBlock():
    case PlanFeaturedRelations():
    case PlanWidgetBlock():
      // These have no Markdown form at all; the envelope is the only way the
      // block survives a save (they used to fall into `default: return ''`).
      return _envelope(block);
    case PlanUnsupported(:final reason):
      return '<!-- unsupported: $reason -->';
    case PlanLayout():
      // A container has no line of its own; its children encode separately.
      return '';
  }
}

/// The one-line envelope: the whole block as JSON inside an HTML comment.
/// Legal Markdown, renders as nothing, reads back as the block it was.
String _envelope(PlanBlock block) =>
    '<!-- plan:${jsonEncode(block.toJson())} -->';

/// Whether every field of this text block has a Markdown form: a style with a
/// prefix (or the code fence), marks that fold to markdown tokens, and no
/// colour/alignment/emoji payload.
bool _markdownCarries(PlanText content) {
  final styled = switch (content.style) {
    PlanTextStyle.h1 ||
    PlanTextStyle.h2 ||
    PlanTextStyle.h3 ||
    PlanTextStyle.h4 ||
    PlanTextStyle.quote ||
    PlanTextStyle.bullet ||
    PlanTextStyle.numbered ||
    PlanTextStyle.checkbox ||
    PlanTextStyle.codeSnippet ||
    PlanTextStyle.paragraph => true,
    _ => false,
  };
  if (!styled) return false;
  if (content.color != null ||
      content.background != null ||
      content.iconEmoji != null ||
      content.align != PlanAlign.start) {
    return false;
  }
  return content.marks.every(
    (mark) => switch (mark.type) {
      PlanMarkType.bold ||
      PlanMarkType.italic ||
      PlanMarkType.strikethrough ||
      PlanMarkType.keyboard ||
      PlanMarkType.link => true,
      _ => false,
    },
  );
}

String _plainText(PlanBlock block) =>
    block.content is PlanText ? (block.content as PlanText).text : '';

bool _isTableSeparator(String line) =>
    RegExp(r'^\|(\s*:?-{2,}:?\s*\|)+$').hasMatch(line.trim());

List<String> _splitTableRow(String line) {
  var body = line.trim();
  if (body.startsWith('|')) body = body.substring(1);
  if (body.endsWith('|')) body = body.substring(0, body.length - 1);
  return [for (final cell in body.split('|')) cell.trim()];
}

PlanDividerStyle? _dividerFor(String line) {
  if (line == '---' || line == '___') return PlanDividerStyle.line;
  if (line == '***' || line == '···') return PlanDividerStyle.dots;
  return null;
}

String _applyMarks(String text, List<PlanMark> marks) {
  if (marks.isEmpty) return text;
  final sorted = [...marks]
    ..sort((a, b) => b.range.start.compareTo(a.range.start));
  var out = text;
  for (final mark in sorted) {
    final start = mark.range.start.clamp(0, out.length);
    final end = mark.range.end.clamp(start, out.length);
    final inner = out.substring(start, end);
    final wrapped = switch (mark.type) {
      PlanMarkType.bold => '**$inner**',
      PlanMarkType.italic => '*$inner*',
      PlanMarkType.strikethrough => '~~$inner~~',
      PlanMarkType.keyboard => '`$inner`',
      PlanMarkType.link => '[$inner](${mark.param ?? ''})',
      _ => inner,
    };
    if (wrapped == inner) continue;
    out = out.replaceRange(start, end, wrapped);
  }
  return out;
}

/// Inline mark parser: bold, italic, strikethrough, code and links, non-
/// nested. Anything it cannot fold stays literal text.
PlanText _textFor(String raw, PlanTextStyle style, {bool? checked}) {
  final marks = <PlanMark>[];
  final buffer = StringBuffer();
  var index = 0;

  void consume(String token, PlanMarkType type, {String? param}) {
    marks.add(
      PlanMark(
        range: PlanMarkRange(buffer.length, buffer.length + token.length),
        type: type,
        param: param,
      ),
    );
    buffer.write(token);
  }

  while (index < raw.length) {
    final rest = raw.substring(index);
    if (rest.startsWith('**')) {
      final close = rest.indexOf('**', 2);
      if (close > 2) {
        consume(rest.substring(2, close), PlanMarkType.bold);
        index += close + 2;
        continue;
      }
    }
    if (rest.startsWith('~~')) {
      final close = rest.indexOf('~~', 2);
      if (close > 2) {
        consume(rest.substring(2, close), PlanMarkType.strikethrough);
        index += close + 2;
        continue;
      }
    }
    if (rest.startsWith('`')) {
      final close = rest.indexOf('`', 1);
      if (close > 1) {
        consume(rest.substring(1, close), PlanMarkType.keyboard);
        index += close + 1;
        continue;
      }
    }
    final link = RegExp(r'^\[([^\]]+)\]\(([^)]+)\)').firstMatch(rest);
    if (link != null) {
      consume(link.group(1)!, PlanMarkType.link, param: link.group(2));
      index += link.group(0)!.length;
      continue;
    }
    if (rest.startsWith('*') && !rest.startsWith('**')) {
      final close = rest.indexOf('*', 1);
      if (close > 1) {
        consume(rest.substring(1, close), PlanMarkType.italic);
        index += close + 1;
        continue;
      }
    }
    buffer.write(raw[index]);
    index++;
  }

  return PlanText(
    text: buffer.toString(),
    style: style,
    marks: marks,
    checked: checked,
  );
}

String Function() _counter() {
  var n = 0;
  return () => 'b${++n}';
}
