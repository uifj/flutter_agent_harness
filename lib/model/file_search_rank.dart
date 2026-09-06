// Pure ranking for the `@` mention menu — a direct port of dsh-at-file's
// `search.ts`, which is the part of the plugin that makes the picker feel
// right: a plain query matches basenames only (letters spread across a long
// generated path cannot create false positives), a query containing `/`
// matches path segments in order, and the empty query is a shallow-first
// browse view with directories ahead of files at the same depth.
//
// Everything here is a pure function over lists, so the ranking contract is
// pinned by tests with no filesystem and no UI.

import 'workspace_index.dart';

/// Ranked top-[limit] entries matching [query]. Ties break by kind (files
/// first), then path length, then path order.
List<FileEntry> rankFiles(List<FileEntry> files, String query, int limit) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) {
    final browsed = [...files]..sort(byBrowse);
    return browsed.take(limit).toList();
  }
  final scored = <(FileEntry, int)>[];
  for (final file in files) {
    final score = _scorePath(file.relative, q);
    if (score >= 0) scored.add((file, score));
  }
  scored.sort((a, b) {
    final byScore = b.$2.compareTo(a.$2);
    if (byScore != 0) return byScore;
    final aDir = a.$1.kind == 'dir' ? 1 : 0;
    final bDir = b.$1.kind == 'dir' ? 1 : 0;
    if (aDir != bDir) return aDir - bDir;
    final byLength = a.$1.relative.length.compareTo(b.$1.relative.length);
    if (byLength != 0) return byLength;
    return a.$1.relative.compareTo(b.$1.relative);
  });
  return [
    for (final (file, _) in scored.take(limit)) file,
  ];
}

/// Browse order: shallow paths first, then directories before files, then
/// alphabetical. The picker presents this for an empty query so root-level
/// files are not displaced by deeply nested directories.
int byBrowse(FileEntry a, FileEntry b) {
  final depth = _depth(a.relative) - _depth(b.relative);
  if (depth != 0) return depth;
  if (a.kind != b.kind) return a.kind == 'dir' ? -1 : 1;
  return a.relative.compareTo(b.relative);
}

int _depth(String relative) => '/'.allMatches(relative).length;

/// Match one normalized query against a basename or an ordered path-segment
/// list — the plugin's `scorePath`.
int _scorePath(String path, String q) {
  final lowerPath = path.toLowerCase();
  final pathSegments = lowerPath.split('/');
  final normalizedQuery = q.replaceAll('\\', '/');
  final querySegments = normalizedQuery.split('/').where((s) => s.isNotEmpty).toList();
  if (!normalizedQuery.contains('/')) {
    return _scoreName(pathSegments.last, querySegments.first);
  }
  if (querySegments.isEmpty) return -1;
  if (normalizedQuery.endsWith('/')) {
    final prefix = normalizedQuery.substring(0, normalizedQuery.length - 1);
    if (!lowerPath.startsWith('$prefix/')) return -1;
    final depth = '/'.allMatches(lowerPath.substring(prefix.length + 1)).length;
    return 6000 - depth * 100 - path.length;
  }

  var cursor = 0;
  var total = 0;
  var lastMatch = -1;
  for (final querySegment in querySegments) {
    var matchedIndex = -1;
    var matchedScore = -1;
    for (var index = cursor; index < pathSegments.length; index++) {
      final score = _scoreName(pathSegments[index], querySegment);
      if (score < 0) continue;
      matchedScore = score;
      matchedIndex = index;
      break;
    }
    if (matchedIndex < 0) return -1;
    total += matchedScore;
    lastMatch = matchedIndex;
    cursor = matchedIndex + 1;
  }
  final basenameBonus = lastMatch == pathSegments.length - 1 ? 1000 : 0;
  return total + basenameBonus - path.length;
}

/// Exact, prefix, substring, then compact-subsequence scoring for one name —
/// the plugin's `scoreName`.
int _scoreName(String name, String query) {
  if (name == query) return 5000;
  if (name.startsWith(query)) return 4500 - name.length;
  final contained = name.indexOf(query);
  if (contained >= 0) return 4000 - contained * 10 - name.length;
  var first = -1;
  var previous = -1;
  var gaps = 0;
  var at = 0;
  for (final ch in query.runes) {
    final found = name.indexOf(String.fromCharCode(ch), at);
    if (found < 0) return -1;
    if (first < 0) first = found;
    if (previous >= 0) gaps += found - previous - 1;
    previous = found;
    at = found + 1;
  }
  return 3000 - first * 10 - gaps * 5 - name.length;
}

/// The directory prefix of a forward-slash relative path ('' for root-level
/// files) — the picker row's second line.
String dirnameOf(String relative) {
  final at = relative.lastIndexOf('/');
  return at < 0 ? '' : relative.substring(0, at);
}

/// The basename of a forward-slash relative path — the picker row's label.
String basenameOf(String relative) {
  final at = relative.lastIndexOf('/');
  return at < 0 ? relative : relative.substring(at + 1);
}
