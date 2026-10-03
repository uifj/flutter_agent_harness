// ADR-0045 PG: AppMeta.version is a synchronous second copy of the pubspec
// version for the About dialog; this test is what keeps the two honest.

import 'dart:io';

import 'package:planstar/model/app_meta.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppMeta.version matches pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull);
    expect(AppMeta.version, match!.group(1));
  });

  test('help links are absolute https URLs', () {
    for (final url in [
      AppMeta.docsUrl,
      AppMeta.communityUrl,
      AppMeta.issuesUrl,
      AppMeta.featureRequestUrl,
      AppMeta.releasesUrl,
    ]) {
      expect(Uri.tryParse(url)!.isAbsolute, isTrue, reason: url);
      expect(url.startsWith('https://'), isTrue, reason: url);
    }
  });
}
