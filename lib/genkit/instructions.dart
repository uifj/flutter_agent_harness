// The workspace's own instruction files, found and merged.
//
// Deliberately free of `package:genkit` — same arrangement as `read_window.dart`
// and `file_search.dart`: the behaviour is plain Dart, so it is unit-testable
// against a real temp tree, and `agent_runtime.dart` keeps being the only place
// Genkit shapes are made.
//
// Why it exists: the harness shipped a compile-time system prompt only, so a
// workspace's `AGENTS.md` — the file this repo's own AI agents read — reached
// the model as nothing at all (ADR-0009). ZCode's runtime injects instructions
// as a user-side context message rather than rewriting the system prompt (see
// `docs/zcode-vs-agent-harness-2026-09.md` §4), and that is the shape copied
// here: the agent is built once and the workspace is a live setter
// (`AppScope.save` → `runtime.workspaceRoot`), so per-workspace instructions
// cannot be baked into a static prompt.
//
// The rules:
//   * Order is user-level first, then from the filesystem root down to the
//     workspace, so the closest `AGENTS.md` is the last thing the model reads.
//   * `AGENTS.md` and `.agents/AGENTS.md` are recognised at every level.
//   * Paths are canonicalised and deduplicated, and an instruction file inside
//     the workspace whose resolved target escapes it is skipped: a symlink
//     planted in a cloned repo must not pull an unrelated file into the model's
//     context. Files in the workspace's ancestor directories are the user's own
//     and are read as found.
//   * Size is capped per file and in total, because one oversized README would
//     otherwise eat the context window. A truncation is announced, not hidden.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/mention_expansion.dart' show workspaceReferenceTag;

/// Where an instruction file came from.
enum InstructionOrigin { user, project }

/// One instruction file, already read and capped.
class InstructionFile {
  const InstructionFile({
    required this.path,
    required this.origin,
    required this.text,
    required this.truncated,
  });

  /// Canonical path, shown to the model so it can cite where a rule came from.
  final String path;
  final InstructionOrigin origin;

  /// The body, already cut to the cap.
  final String text;

  /// Whether [text] is shorter than the file it came from.
  final bool truncated;
}

/// Per-file and total instruction budgets, in UTF-8 bytes.
const int perFileByteCap = 8 * 1024;
const int totalByteCap = 24 * 1024;

/// The file names recognised at every level of the chain.
const List<String> instructionFileNames = ['AGENTS.md', '.agents/AGENTS.md'];

/// The directory holding the user-level instructions, under the home folder.
String userInstructionRoot(String homeRoot) => p.join(homeRoot, '.planstar');

/// The home folder from the environment, or null when it does not say.
///
/// `HOME` on POSIX, `USERPROFILE` on Windows. `path_provider` answers the same
/// question, but asynchronously, and this runs on the synchronous path that
/// queues the next message's context.
String? detectHomeRoot() {
  final env = Platform.environment;
  final home = env['HOME'] ?? env['USERPROFILE'];
  return (home == null || home.isEmpty) ? null : home;
}

/// Finds and reads the instruction files for [workspaceRoot].
///
/// [homeRoot] and [workspaceRoot] are parameters rather than `Directory` /
/// environment lookups, so the precedence and the escape rule can be tested
/// against a real temp tree instead of the machine's own `~`.
List<InstructionFile> discoverInstructions({
  required String? workspaceRoot,
  required String? homeRoot,
}) {
  final found = <InstructionFile>[];
  final seen = <String>{};
  var budget = totalByteCap;

  void add(String candidate, InstructionOrigin origin, {String? withinRoot}) {
    if (budget <= 0) return;
    final file = File(candidate);
    if (!file.existsSync()) return;
    final canonical = _canonical(file);
    if (canonical == null || !seen.add(canonical)) return;
    if (withinRoot != null && !_isWithin(withinRoot, canonical)) return;
    final text = file.readAsStringSync();
    final allowance = budget < perFileByteCap ? budget : perFileByteCap;
    final clipped = _clipToBytes(text, allowance);
    final consumed = _utf8Length(clipped.text);
    budget -= consumed;
    if (consumed == 0 && clipped.cut) return;
    found.add(
      InstructionFile(
        path: canonical,
        origin: origin,
        text: clipped.text,
        truncated: clipped.cut,
      ),
    );
  }

  if (homeRoot != null) {
    add(
      p.join(userInstructionRoot(homeRoot), 'AGENTS.md'),
      InstructionOrigin.user,
    );
  }

  final root = workspaceRoot == null ? null : _canonicalDir(workspaceRoot);
  if (root == null) return found;

  // Walk to the filesystem root, then read the chain top-down: the workspace's
  // own file lands last, which is where a model weighs it heaviest.
  final chain = <String>[];
  var dir = root;
  while (true) {
    chain.add(dir);
    final parent = p.dirname(dir);
    if (parent == dir) break;
    dir = parent;
  }
  for (final level in chain.reversed) {
    // Only a directory inside the workspace can belong to a possibly-untrusted
    // clone, so only there is a symlinked instruction file rejected. An
    // ancestor's own `AGENTS.md` is a file the user placed above the project;
    // it is read as found.
    final ancestorsOnly = !_isWithin(root, level);
    for (final name in instructionFileNames) {
      add(
        p.join(level, name),
        InstructionOrigin.project,
        withinRoot: ancestorsOnly ? null : root,
      );
    }
  }
  return found;
}

/// The opening tag of the injected block. A constant because a surface that
/// shows what the user typed has to recognise and skip it — see
/// [isInjectedPart].
const instructionsOpenTag = '<project-instructions>';

/// True for text the runtime put into the user's message on the user's behalf:
/// the workspace instruction block (ADR-0009), the `@` file references, and
/// the compression summary (ADR-0061).
///
/// All of them ride the first user message as their own text parts, so
/// anything that reads that message to describe the conversation to a human —
/// a session title, primarily — must drop them. They are model-facing prose,
/// and they spend the whole title budget before the user's own sentence
/// begins.
bool isInjectedPart(String text) {
  final head = text.trimLeft();
  return head.startsWith(instructionsOpenTag) ||
      head.startsWith(workspaceReferenceTag) ||
      head.startsWith(conversationSummaryOpenTag);
}

/// The opening tag of the compression summary block (ADR-0061). The summary
/// rides the same channel as the workspace instructions — context the model
/// must know, not words the user typed — so it earns the same exclusion.
const conversationSummaryOpenTag = '<conversation-summary>';

/// Wraps a compression summary into the injected block the next send carries.
String conversationSummaryBlock(String summary) {
  final buffer = StringBuffer()
    ..writeln(conversationSummaryOpenTag)
    ..writeln(
      'A summary of the conversation this one continues, written when the '
      'previous transcript was compressed. Treat it as established context: '
      'the user\'s standing requests and decisions below still hold. Details '
      'may be missing — ask when something matters and is not here.',
    )
    ..writeln()
    ..writeln(summary.trim())
    ..write('</conversation-summary>');
  return buffer.toString();
}

/// The block injected ahead of the user's own words, or null when there is
/// nothing to inject.
///
/// Model-facing text, so it is not an i18n string — a tool description and this
/// block are read by the model, not by the user (`workflow.md` §3).
String? renderInstructions(List<InstructionFile> files) {
  if (files.isEmpty) return null;
  final buffer = StringBuffer()
    ..writeln(instructionsOpenTag)
    ..writeln(
      'Instruction files the user maintains for these directories. Follow '
      'them. Something the user says in this conversation outranks a file; '
      'when two files disagree, the later one wins.',
    );
  for (final file in files) {
    final scope = file.origin == InstructionOrigin.user
        ? 'user-level'
        : 'directory';
    buffer
      ..writeln()
      ..writeln('### ${file.path} ($scope)')
      ..writeln(file.text.trimRight());
    if (file.truncated) {
      buffer.writeln();
      buffer.writeln(
        '… truncated: the file is longer than the $perFileByteCap-byte '
        'instruction budget.',
      );
    }
  }
  buffer.write('</project-instructions>');
  return buffer.toString();
}

/// The one call the runtime makes: the block for one workspace, or null.
String? instructionsForWorkspace({
  required String? workspaceRoot,
  required String? homeRoot,
}) => renderInstructions(
  discoverInstructions(workspaceRoot: workspaceRoot, homeRoot: homeRoot),
);

class _Clip {
  const _Clip(this.text, this.cut);
  final String text;
  final bool cut;
}

/// Cuts [text] to at most [maxBytes] UTF-8 bytes on a code-point boundary, so a
/// clipped instruction file cannot arrive at the provider as a broken sequence.
_Clip _clipToBytes(String text, int maxBytes) {
  if (_utf8Length(text) <= maxBytes) return _Clip(text, false);
  final out = StringBuffer();
  var used = 0;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final size = _utf8Length(char);
    if (used + size > maxBytes) break;
    out.write(char);
    used += size;
  }
  return _Clip(out.toString(), true);
}

int _utf8Length(String text) => utf8.encode(text).length;

String? _canonical(File file) {
  try {
    return p.canonicalize(file.resolveSymbolicLinksSync());
  } on FileSystemException {
    return null;
  }
}

String? _canonicalDir(String path) {
  try {
    return p.canonicalize(Directory(path).resolveSymbolicLinksSync());
  } on FileSystemException {
    return null;
  }
}

bool _isWithin(String root, String candidate) {
  final relative = p.relative(candidate, from: root);
  return !relative.startsWith('..') && !p.isAbsolute(relative);
}
