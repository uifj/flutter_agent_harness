// The glob and grep tools' engine: what matches, in what order, and where it
// stops.
//
// A port of `tool-fs-search/src/glob.ts` and `grep.ts`, minus their transport.
// dsh spawns the ripgrep binary its npm dependency ships; there is no such
// binary to lean on here, and adding a native one to a Flutter app to walk a
// directory would be a large dependency for a small job — so the walk, the
// pattern translation and the caps are Dart, and only these three divergences
// follow from it:
//
//  * regexes are Dart's, not ripgrep's. Both are Perl-ish; the differences show
//    up only in exotic constructs, and a pattern Dart cannot parse comes back as
//    a tool failure the model can correct rather than a crash.
//  * ignore files are not consulted. dsh does not consult them either for glob
//    (it documents "including hidden and ignored files"), so only grep differs,
//    and it differs by searching more rather than less.
//  * there is no spill file. dsh saves the complete list beside a capped result
//    and reports the path; here a capped result says how many it dropped and the
//    model narrows the pattern instead.
//
// Nothing here touches Genkit, so `test/file_search_test.dart` drives it against
// a temp directory directly.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'read_window.dart' show decodeLines;

/// `GLOB_MAX_RESULTS`: paths one glob call returns.
const globMaxResults = 100;

/// `GREP_MAX_MATCHES`: matched lines one grep call returns.
const grepMaxMatches = 250;

/// `GREP_MAX_LINE_BYTES`: how much of one matched line comes back. A match in a
/// minified file should cost a preview, not a screenful.
const grepMaxLineBytes = 2000;

/// `SEARCH_TIMEOUT_MS`: the budget for one search. Reached, the walk stops and
/// says so rather than returning nothing — a partial answer about a large tree is
/// still an answer.
const searchTimeout = Duration(seconds: 30);

/// `GLOB_VCS_EXCLUDES`: never walked, by either tool.
///
/// Not a general ignore list: these hold thousands of content-addressed files
/// that no one means to match, and a pattern like `**/*` would otherwise return
/// mostly git objects.
const vcsExcludes = {'.git', '.hg', '.svn'};

/// Translates a glob to the regex the walk matches paths against.
///
/// The one rule worth stating: a pattern with no separator matches the basename
/// at any depth, so `*.dart` searches the whole tree and `src/*.dart` does not.
/// dsh's schema documents exactly this, because it is the difference between the
/// tool being useful on the first call and needing a second one.
RegExp globToRegExp(String glob) {
  final anchored = glob.contains('/') ? glob : '**/$glob';
  final out = StringBuffer('^');
  for (var i = 0; i < anchored.length; i++) {
    final ch = anchored[i];
    switch (ch) {
      case '*':
        final doubled = i + 1 < anchored.length && anchored[i + 1] == '*';
        if (!doubled) {
          // One star stays inside a segment, which is what makes `src/*.dart`
          // mean the directory itself rather than the tree under it.
          out.write('[^/]*');
          break;
        }
        i++;
        if (i + 1 < anchored.length && anchored[i + 1] == '/') {
          i++;
          // `**/` has to be able to match nothing at all, or `**/*.dart` would
          // miss a file at the root.
          out.write('(?:[^/]+/)*');
        } else {
          out.write('.*');
        }
      case '?':
        out.write('[^/]');
      case '{':
        out.write('(?:');
      case '}':
        out.write(')');
      case ',':
        // Only meaningful inside a brace group; outside one a comma is a comma,
        // but a literal comma in a path is rare enough that translating it to an
        // alternation bar unconditionally would be the more surprising bug. The
        // depth check keeps both honest.
        out.write(_inBrace(anchored, i) ? '|' : ',');
      default:
        out.write(RegExp.escape(ch));
    }
  }
  out.write(r'$');
  return RegExp(out.toString());
}

bool _inBrace(String glob, int upTo) {
  var depth = 0;
  for (var i = 0; i < upTo; i++) {
    if (glob[i] == '{') depth++;
    if (glob[i] == '}') depth--;
  }
  return depth > 0;
}

/// One matched path, with the timestamp that ordered it.
class GlobHit {
  const GlobHit(this.path, this.modified);

  /// Relative to the directory searched, which is what the model passes back to
  /// `read` — the two tools share a root by construction here, since both
  /// resolve through the same workspace.
  final String path;
  final DateTime modified;
}

/// A finished glob: the page, and what it does not contain.
class GlobOutcome {
  const GlobOutcome({
    required this.hits,
    required this.total,
    required this.timedOut,
  });

  final List<GlobHit> hits;

  /// Matches found, which exceeds `hits.length` on a capped search.
  final int total;

  final bool timedOut;

  bool get capped => total > hits.length;
}

/// Finds files under [root] whose relative path matches [pattern].
///
/// Newest first, because a coding agent's next question is almost always about
/// what changed recently, and a capped page taken off the head is then the useful
/// half rather than an arbitrary one.
Future<GlobOutcome> globFiles({
  required Directory root,
  required String pattern,
  int maxResults = globMaxResults,
  Duration timeout = searchTimeout,
}) async {
  final matcher = globToRegExp(pattern);
  final hits = <GlobHit>[];
  final walk = await _walk(
    root: root,
    timeout: timeout,
    onFile: (relative, file) async {
      if (!matcher.hasMatch(relative)) return;
      hits.add(GlobHit(relative, await _modified(file)));
    },
  );

  hits.sort((a, b) => b.modified.compareTo(a.modified));
  return GlobOutcome(
    hits: hits.take(maxResults).toList(),
    total: hits.length,
    timedOut: walk,
  );
}

/// One matched line.
class GrepHit {
  const GrepHit(this.path, this.line, this.text);

  final String path;

  /// 1-based, as displayed.
  final int line;

  /// The line, cut to [grepMaxLineBytes] with a marker when it was long.
  final String text;
}

/// A finished grep: the page, how much it left behind, and across how many files.
class GrepOutcome {
  const GrepOutcome({
    required this.hits,
    required this.total,
    required this.files,
    required this.timedOut,
  });

  final List<GrepHit> hits;
  final int total;

  /// Files with at least one match — the number the summary line quotes, and it
  /// counts every matching file, not only the ones the page reached.
  final int files;

  final bool timedOut;

  bool get capped => total > hits.length;
}

/// Searches file contents under [target] for [pattern].
///
/// [target] may be a single file, which is the shape the model reaches for after
/// a glob narrowed things down to one.
Future<GrepOutcome> grepFiles({
  required FileSystemEntity target,
  required RegExp pattern,
  String? include,
  int maxMatches = grepMaxMatches,
  int maxLineBytes = grepMaxLineBytes,
  Duration timeout = searchTimeout,
}) async {
  final filter = include == null || include.isEmpty
      ? null
      : globToRegExp(include);
  final hits = <GrepHit>[];
  var total = 0;
  var files = 0;

  Future<void> search(String display, File file) async {
    final found = await _grepOne(
      file: file,
      display: display,
      pattern: pattern,
      maxLineBytes: maxLineBytes,
    );
    if (found.isEmpty) return;
    files++;
    total += found.length;
    // Retained up to the cap, but counted past it: the model needs to know the
    // page is a page, and the count is what tells it the pattern was too wide.
    for (final hit in found) {
      if (hits.length >= maxMatches) break;
      hits.add(hit);
    }
  }

  var timedOut = false;
  if (target is File) {
    if (filter == null || filter.hasMatch(p.basename(target.path))) {
      await search(p.basename(target.path), target);
    }
  } else if (target is Directory) {
    timedOut = await _walk(
      root: target,
      timeout: timeout,
      onFile: (relative, file) async {
        if (filter != null && !filter.hasMatch(relative)) return;
        if (hits.length >= maxMatches && total >= maxMatches * 4) {
          // Past the cap the walk is only counting, and a count is not worth an
          // unbounded scan of a huge tree. Four pages is enough for the model to
          // see the pattern is too wide.
          return;
        }
        await search(relative, file);
      },
    );
  }

  return GrepOutcome(
    hits: hits,
    total: total,
    files: files,
    timedOut: timedOut,
  );
}

/// Matches in one file, or nothing for a binary one.
Future<List<GrepHit>> _grepOne({
  required File file,
  required String display,
  required RegExp pattern,
  required int maxLineBytes,
}) async {
  final hits = <GrepHit>[];
  var number = 0;
  try {
    await for (final line in decodeLines(file.openRead())) {
      number++;
      // A NUL byte is how every grep decides a file is binary. Bailing on the
      // whole file rather than the line matters: a binary file's "lines" are
      // arbitrary, so its matches would be noise even where the regex hits.
      if (line.contains('\u0000')) return const [];
      if (!pattern.hasMatch(line)) continue;
      hits.add(GrepHit(display, number, _preview(line, maxLineBytes)));
    }
  } on FileSystemException {
    // An unreadable file costs its own matches, not the search.
    return hits;
  }
  return hits;
}

/// `previewLine`: cut on a UTF-8 boundary, and say that it was cut.
String _preview(String line, int maxBytes) {
  if (line.length <= maxBytes) return line;
  return '${line.substring(0, maxBytes)}… (line truncated)';
}

/// Walks [root] depth-first, skipping [vcsExcludes], and returns whether it ran
/// out of time.
///
/// `followLinks: false` on every listing: a symlink loop inside the tree would
/// otherwise walk forever, and the workspace guard would refuse anything a link
/// out of the tree found anyway.
Future<bool> _walk({
  required Directory root,
  required Duration timeout,
  required Future<void> Function(String relative, File file) onFile,
}) async {
  final deadline = DateTime.now().add(timeout);
  final queue = <Directory>[root];
  var seen = 0;

  while (queue.isNotEmpty) {
    final dir = queue.removeLast();
    final List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } on FileSystemException {
      // An unreadable directory costs its subtree, not the walk.
      continue;
    }
    for (final entry in entries) {
      // The clock is read every 200 entries rather than every one: a directory
      // walk of a large tree is dominated by syscalls, and `DateTime.now()` per
      // entry is a measurable share of them.
      if (++seen % 200 == 0 && DateTime.now().isAfter(deadline)) return true;
      final name = p.basename(entry.path);
      if (entry is Directory) {
        if (vcsExcludes.contains(name)) continue;
        queue.add(entry);
      } else if (entry is File) {
        await onFile(p.relative(entry.path, from: root.path), entry);
      }
    }
  }
  return false;
}

/// A file's mtime, or the epoch for one that vanished mid-walk — a race with the
/// user's editor should sort the file last, not fail the search.
Future<DateTime> _modified(File file) async {
  try {
    return (await file.stat()).modified;
  } on FileSystemException {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
