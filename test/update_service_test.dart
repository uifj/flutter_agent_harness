// The update service's six pieces (ADR-0079): remote source, compare, skip
// this version, daily throttle, silent failure, atomic prefs. The network is
// a MockClient; the prefs file is real IO in a temp directory — plain
// `test()` bodies, no FakeAsync, so the writes complete.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:planstar/state/update_service.dart';

void main() {
  late Directory root;
  late UpdateService service;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dsh_update_');
  });

  tearDown(() {
    root.deleteSync(recursive: true);
  });

  UpdateService openService({
    required List<int> callCount,
    Future<http.Response> Function(http.Request)? handler,
  }) {
    final client = MockClient((request) async {
      callCount[0]++;
      if (handler != null) return handler(request);
      return http.Response(
        jsonEncode({
          'tag_name': 'v0.2.0',
          'html_url':
              'https://github.com/uifj/flutter_agent_harness/releases/tag/v0.2.0',
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return UpdateService(
      file: File('${root.path}/update.json'),
      client: client,
      apiUri: Uri.parse('https://api.github.com/test/latest'),
    );
  }

  test('a newer release answers hasUpdate with the remote entry', () async {
    final calls = [0];
    service = openService(callCount: calls);
    final result = await service.check(userInitiated: true);
    expect(result.hasUpdate, isTrue);
    expect(result.remote!.version, '0.2.0');
    expect(result.remote!.url, contains('/tag/v0.2.0'));
    expect(result.error, isNull);
  });

  test('an older release answers no update', () async {
    final calls = [0];
    service = openService(
      callCount: calls,
      handler: (_) async {
        return http.Response(
          jsonEncode({'tag_name': 'v0.0.9', 'html_url': 'x'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      },
    );
    final result = await service.check(userInitiated: true);
    expect(result.hasUpdate, isFalse);
    expect(result.remote, isNotNull);
  });

  test('the daily throttle silences a second automatic check', () async {
    final calls = [0];
    service = openService(callCount: calls);
    await service.check(userInitiated: false);
    final second = await service.check(userInitiated: false);
    expect(calls[0], 1, reason: 'the second check must not hit the network');
    expect(second.hasUpdate, isFalse);
  });

  test('the user check bypasses the throttle', () async {
    final calls = [0];
    service = openService(callCount: calls);
    await service.check(userInitiated: false);
    await service.check(userInitiated: true);
    expect(calls[0], 2, reason: 'asking must answer, same day or not');
  });

  test('a skipped version stays quiet for automatic checks', () async {
    final calls = [0];
    File('${root.path}/update.json').writeAsStringSync(
      jsonEncode({
        'lastCheckDate': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'skippedVersion': '0.2.0',
      }),
    );
    service = openService(callCount: calls);
    final result = await service.check(userInitiated: false);
    expect(calls[0], 1, reason: 'yesterday is outside the throttle');
    expect(result.hasUpdate, isFalse, reason: 'the skip holds');
  });

  test('the user check ignores the skip', () async {
    final calls = [0];
    File('${root.path}/update.json').writeAsStringSync(
      jsonEncode({
        'lastCheckDate': DateTime.now()
            .subtract(const Duration(days: 1))
            .toIso8601String(),
        'skippedVersion': '0.2.0',
      }),
    );
    service = openService(callCount: calls);
    final result = await service.check(userInitiated: true);
    expect(result.hasUpdate, isTrue);
  });

  test('a failed check reports an error and does not throttle', () async {
    final calls = [0];
    service = openService(
      callCount: calls,
      handler: (_) async {
        throw http.ClientException('offline');
      },
    );
    final result = await service.check(userInitiated: true);
    expect(result.error, isNotNull);
    expect(
      File('${root.path}/update.json').existsSync(),
      isFalse,
      reason: 'a failed check must not count toward the throttle',
    );
  });

  test('a corrupt prefs file reads as absent', () async {
    final calls = [0];
    File('${root.path}/update.json').writeAsStringSync('not json');
    service = openService(callCount: calls);
    final result = await service.check(userInitiated: true);
    expect(result.hasUpdate, isTrue);
  });

  test('the prefs write is atomic — no tmp residue', () async {
    final calls = [0];
    service = openService(callCount: calls);
    await service.check(userInitiated: true);
    final residue = root
        .listSync()
        .where((e) => e.path.endsWith('.tmp'))
        .toList();
    expect(residue, isEmpty);
    final prefs = jsonDecode(
      File('${root.path}/update.json').readAsStringSync(),
    );
    expect(prefs['lastCheckDate'], isNotNull);
  });
}
