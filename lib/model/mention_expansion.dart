// The `@path` mention expansion — a port of dsh-at-file's `mention.ts`
// (FSMargoo/dsh-at-file), at the one boundary this app has: the send.
//
// The plugin validates mentions as a HOST pre-step and injects reference
// messages between the user's send and the model's turn. This app has no
// host, so the same expansion happens inside `AgentRuntime.send`: the
// user's text is scanned for `@path` tokens, each token is resolved through
// the same [Workspace] guard the file tools use, and every VALIDATED
// reference rides the outgoing message as an extra text part ahead of the
// body. Invalid paths stay plain prose — the model sees the user's words,
// not an error.
//
// Existence-only, like the plugin: the reference carries the path and its
// kind and nothing else. The agent chooses whether to read it with its own
// tools; a mention is a pointer, not a payload.

import 'dart:io';

import 'workspace.dart';

/// The literal mention token: `@` then a path with no whitespace or `@` —
/// the plugin's `MENTION_PATTERN`.
final _mentionPattern = RegExp(r'@([^\s@]+)');

/// One recognized mention: its workspace-relative token and resolved kind.
class Mention {
  const Mention({required this.relative, required this.isDirectory});

  final String relative;
  final bool isDirectory;

  @override
  bool operator ==(Object other) =>
      other is Mention &&
      other.relative == relative &&
      other.isDirectory == isDirectory;

  @override
  int get hashCode => Object.hash(relative, isDirectory);
}

/// Scans [text] for `@path` tokens, deduplicated in first-seen order. A
/// trailing slash (the directory-pick form) is stripped from the path.
List<String> scanMentions(String text) {
  final seen = <String>{};
  final out = <String>[];
  for (final match in _mentionPattern.allMatches(text)) {
    final raw = match.group(1)!;
    final relative =
        raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
    if (relative.isEmpty || seen.contains(relative)) continue;
    seen.add(relative);
    out.add(relative);
  }
  return out;
}

/// Resolves every mention token in [text] against [workspace], keeping only
/// the ones that exist inside it. A token that names nothing, or something
/// outside the workspace, stays plain prose — the plugin's "unknown paths
/// stay plain prose" rule, which keeps a false mention from becoming an
/// error the user has to fix before their question goes out.
List<Mention> resolveMentions(String text, Workspace workspace) {
  final out = <Mention>[];
  for (final token in scanMentions(text)) {
    // The guard is the plugin's confinement check: an absolute path or a
    // `..` escape is refused here rather than resolved. `tryResolve` returns
    // null for a nonexistent path too, which is the same "plain prose"
    // outcome as a refusal — the probe below tells them apart only to skip.
    final absolute = workspace.tryResolve(token);
    if (absolute == null) continue;
    final type = FileSystemEntity.typeSync(absolute, followLinks: true);
    if (type == FileSystemEntityType.directory) {
      out.add(Mention(relative: token, isDirectory: true));
    } else if (type == FileSystemEntityType.file) {
      out.add(Mention(relative: token, isDirectory: false));
    }
    // Anything else (a dangling link, a socket): not a reference.
  }
  return out;
}

/// The existence-only reference form the model receives — the plugin's
/// `referenceForm`, XML-escaped so a path with `&`/`<` cannot break out of
/// the attribute.
String referenceForm(Mention mention) {
  final kind = mention.isDirectory ? 'directory' : 'file';
  return '<workspace-reference path="${_escapeAttribute(mention.relative)}"'
      ' kind="$kind" />';
}

String _escapeAttribute(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('"', '&quot;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
