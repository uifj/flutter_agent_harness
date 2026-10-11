// A YAML-frontmatter mini-parser for `SKILL.md`, shared by the two places that
// read one: the runtime's workspace-skill manifest (`instructions.dart`) and the
// offline importer (`tool/import_agent_skill.dart`).
//
// It exists as a library so a skill's `name` and `description` resolve
// identically in both. They cannot diverge: the importer flattens a folded
// description onto one line to survive genkit_middleware's single-line regex,
// and the manifest reads the same raw third-party files — if each had its own
// parser, a skill could import one way and list another.
//
// Pure Dart, no imports: string in, string out, unit-testable directly.

/// Frontmatter block: `---\n ... \n---` at the very start of the file.
final RegExp _frontmatter = RegExp(
  r'^---\r?\n([\s\S]*?)\r?\n---[^\S\r\n]*\r?\n?',
);

/// A YAML block-scalar indicator on a `key:` line (`>-`, `|`, `|+`, …).
final RegExp _blockIndicator = RegExp(r'^[>|][+-]?\d*$');

/// Splits [skillMd] into its frontmatter block and body. Returns null when the
/// file does not open with a `---` frontmatter fence.
(String frontmatter, String body)? splitFrontmatter(String skillMd) {
  final match = _frontmatter.firstMatch(skillMd);
  if (match == null) return null;
  return (match.group(1) ?? '', skillMd.substring(match.end));
}

/// Collapses any run of whitespace (including newlines) to single spaces.
String _oneLine(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// Reads the value of [key] from a frontmatter block, flattening a YAML
/// folded/literal block scalar onto one line. Returns '' when absent.
///
/// genkit_middleware only ever reads the first physical line after `key:`, so a
/// multi-line description must become one line here or it is lost.
String flattenScalar(String frontmatter, String key) {
  final lines = frontmatter.split('\n');
  final keyPattern = RegExp('^$key:[ \t]*(.*)\$');
  for (var i = 0; i < lines.length; i++) {
    final match = keyPattern.firstMatch(lines[i]);
    if (match == null) continue;
    final rest = match.group(1)!.trim();
    // Inline scalar on the same line.
    if (rest.isNotEmpty && !_blockIndicator.hasMatch(rest)) {
      return _oneLine(_unquote(rest));
    }
    // Block scalar: gather the more-indented lines that follow.
    final collected = <String>[];
    for (var j = i + 1; j < lines.length; j++) {
      final line = lines[j];
      if (line.trim().isEmpty) {
        collected.add('');
        continue;
      }
      if (!RegExp(r'^[ \t]').hasMatch(line)) break; // dedented → block ended.
      collected.add(line.trim());
    }
    return _oneLine(collected.join(' '));
  }
  return '';
}

String _unquote(String value) {
  if (value.length >= 2 &&
      ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'")))) {
    return value.substring(1, value.length - 1);
  }
  return value;
}
