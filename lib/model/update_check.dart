// The update check's pure vocabulary (ADR-0079).
//
// Split from the service so the comparators and payload parsing stay
// Flutter-free and testable without a client: the service owns the network
// call and the on-disk prefs, this file owns the answers.
//
// The release channel is this repo's GitHub Releases; the payload shape is
// its `releases/latest` response. There is deliberately no `mandatory` field
// — the GitHub API has no such bit, and a dead switch in the schema would be
// a fake door (hunnu's mandatory lives in a self-managed version.json; if
// this ever migrates to one, the field comes back with it).

import 'app_meta.dart';

/// One released version worth comparing against.
class ReleaseEntry {
  const ReleaseEntry({required this.version, required this.url});

  /// The bare version ('v0.2.0' → '0.2.0') — always comparable.
  final String version;

  /// Where the release lives (the release's html_url; falls back to the
  /// releases landing page when the payload omits it).
  final String url;
}

/// The check's answer. [error] is deliberately separate from [hasUpdate]:
/// a manual check that failed must SAY so instead of pretending
/// "already latest" — the one piece of hunnu's conflation not copied
/// (ADR-0079 ①).
class UpdateCheckResult {
  const UpdateCheckResult({
    required this.hasUpdate,
    required this.current,
    this.remote,
    this.error,
  });

  final bool hasUpdate;
  final String current;
  final ReleaseEntry? remote;
  final Object? error;
}

/// Compares dotted versions segment by segment; the shorter side pads with 0
/// and non-numeric segments count as 0. Returns <0, 0, >0 like Comparable.
int compareVersions(String a, String b) {
  List<int> segments(String s) =>
      s.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final left = segments(a);
  final right = segments(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}

/// Strips a release tag down to its bare version: 'v0.2.0' → '0.2.0',
/// '0.2.0' unchanged.
String versionFromTag(String tag) =>
    tag.startsWith('v') ? tag.substring(1) : tag;

/// Parses a GitHub `releases/latest` payload into the entry the check needs.
/// Answers null for a payload without a usable tag (the caller treats that
/// as "nothing to compare" — not an error).
ReleaseEntry? parseGitHubRelease(Map<String, dynamic> payload) {
  final tag = payload['tag_name'];
  if (tag is! String || tag.isEmpty) return null;
  final url = payload['html_url'];
  return ReleaseEntry(
    version: versionFromTag(tag),
    url: url is String && url.isNotEmpty ? url : AppMeta.releasesUrl,
  );
}
