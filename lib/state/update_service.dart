// The in-app update check (ADR-0079).
//
// Shape adapted from hunnu_app_osos's UpdateService six-piece (remote source,
// semver compare, skip-this-version, daily throttle, silent failure, single
// dialog — docs/hunnu-app-osos-vs-planstar-2026-10.md §1.1), with two
// deliberate departures: the release channel is this repo's GitHub Releases
// (no hand-maintained version.json), and a failed manual check reports an
// error instead of pretending "already latest".
//
// The pure comparators and payload parsing live in model/update_check.dart;
// this file owns the network call and the on-disk check state.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../model/app_meta.dart';
import '../model/update_check.dart';

/// The per-machine check state: when the automatic check last ran and which
/// version the user chose to skip. Not user settings — no seat in the
/// settings page (ADR-0022's fake-switch law, inverted).
class UpdatePrefs {
  const UpdatePrefs({this.lastCheckDate, this.skippedVersion});

  factory UpdatePrefs.fromJson(Map<String, dynamic> json) => UpdatePrefs(
    lastCheckDate: switch (json['lastCheckDate']) {
      final String s => DateTime.tryParse(s),
      _ => null,
    },
    skippedVersion: switch (json['skippedVersion']) {
      final String s => s,
      _ => null,
    },
  );

  final DateTime? lastCheckDate;
  final String? skippedVersion;

  Map<String, dynamic> toJson() => {
    if (lastCheckDate != null)
      'lastCheckDate': lastCheckDate!.toIso8601String(),
    if (skippedVersion != null) 'skippedVersion': skippedVersion,
  };
}

/// Checks this repo's GitHub Releases for a version newer than
/// [AppMeta.version]. One instance per process — it owns the http client and
/// the check-state file.
class UpdateService {
  UpdateService({required File file, http.Client? client, Uri? apiUri})
    : _file = file,
      _client = client ?? http.Client(),
      _apiUri =
          apiUri ??
          Uri.parse(
            'https://api.github.com/repos/uifj/flutter_agent_harness/releases/latest',
          );

  /// Opens the service under [support]; its check state lives at
  /// `<support>/update.json`.
  static UpdateService open(Directory support, {http.Client? client}) =>
      UpdateService(file: File('${support.path}/update.json'), client: client);

  final File _file;
  final http.Client _client;
  final Uri _apiUri;

  /// The one entry point. [userInitiated] (the app menu) bypasses the daily
  /// throttle and the skipped version — the user asked, the check answers.
  /// The automatic startup check respects both, and its failures are silent.
  Future<UpdateCheckResult> check({required bool userInitiated}) async {
    final prefs = await _loadPrefs();
    if (!userInitiated && prefs.lastCheckDate != null) {
      final last = prefs.lastCheckDate!;
      final now = DateTime.now();
      final checkedToday =
          last.year == now.year &&
          last.month == now.month &&
          last.day == now.day;
      if (checkedToday) {
        return UpdateCheckResult(hasUpdate: false, current: AppMeta.version);
      }
    }

    UpdateCheckResult result;
    try {
      final response = await _client.get(
        _apiUri,
        headers: {
          'User-Agent': '${AppMeta.productName}/${AppMeta.version}',
          'Accept': 'application/vnd.github+json',
        },
      );
      if (response.statusCode != 200) {
        throw HttpException('release channel answered ${response.statusCode}');
      }
      final payload =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final remote = parseGitHubRelease(payload);
      if (remote == null) {
        result = UpdateCheckResult(hasUpdate: false, current: AppMeta.version);
      } else {
        var hasUpdate = compareVersions(remote.version, AppMeta.version) > 0;
        if (hasUpdate &&
            !userInitiated &&
            prefs.skippedVersion == remote.version) {
          // The user already declined this exact version; the automatic
          // check stays quiet about it. The menu's manual check ignores the
          // skip — asking for it must still answer.
          hasUpdate = false;
        }
        result = UpdateCheckResult(
          hasUpdate: hasUpdate,
          current: AppMeta.version,
          remote: remote,
        );
      }
    } catch (error) {
      result = UpdateCheckResult(
        hasUpdate: false,
        current: AppMeta.version,
        error: error,
      );
    }

    // Only a successful check counts toward the daily throttle — a failed
    // one must not silence tomorrow's retry.
    if (result.error == null) {
      await _savePrefs(
        UpdatePrefs(
          lastCheckDate: DateTime.now(),
          skippedVersion: prefs.skippedVersion,
        ),
      );
    }
    return result;
  }

  /// Records the version the user declined (the dialog's skip button).
  Future<void> skipVersion(String version) async {
    final prefs = await _loadPrefs();
    await _savePrefs(
      UpdatePrefs(lastCheckDate: prefs.lastCheckDate, skippedVersion: version),
    );
  }

  Future<UpdatePrefs> _loadPrefs() async {
    try {
      final text = await _file.readAsString();
      return UpdatePrefs.fromJson(jsonDecode(text) as Map<String, dynamic>);
    } on FileSystemException {
      return const UpdatePrefs();
    } on FormatException {
      // A corrupt file reads as absent — a lost skip preference is a prompt
      // the user has to click again, never a crash.
      return const UpdatePrefs();
    }
  }

  Future<void> _savePrefs(UpdatePrefs prefs) async {
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsString(jsonEncode(prefs.toJson()), flush: true);
    await tmp.rename(_file.path);
  }

  void dispose() => _client.close();
}
