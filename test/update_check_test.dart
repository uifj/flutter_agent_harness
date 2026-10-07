// The update check's pure vocabulary (ADR-0079) — comparators and payload
// parsing, no network, no Flutter.

import 'package:flutter_test/flutter_test.dart';

import 'package:planstar/model/update_check.dart';

void main() {
  group('compareVersions', () {
    test('equal versions compare zero', () {
      expect(compareVersions('0.1.0', '0.1.0'), 0);
      expect(compareVersions('0.1.0', '0.1.0.0'), 0);
    });

    test('patch, minor and major bumps order correctly', () {
      expect(compareVersions('0.1.1', '0.1.0'), greaterThan(0));
      expect(compareVersions('0.2.0', '0.1.9'), greaterThan(0));
      expect(compareVersions('1.0.0', '0.9.9'), greaterThan(0));
      expect(compareVersions('0.0.9', '0.1.0'), lessThan(0));
    });

    test('a shorter version pads with zero', () {
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('1.0.1', '1.0'), greaterThan(0));
    });

    test('non-numeric segments count as zero', () {
      expect(compareVersions('0.1.x', '0.1.0'), 0);
    });
  });

  group('versionFromTag', () {
    test('strips a leading v and keeps bare versions', () {
      expect(versionFromTag('v0.2.0'), '0.2.0');
      expect(versionFromTag('0.2.0'), '0.2.0');
    });
  });

  group('parseGitHubRelease', () {
    test('reads the tag and the html_url', () {
      final entry = parseGitHubRelease({
        'tag_name': 'v0.2.0',
        'html_url':
            'https://github.com/uifj/flutter_agent_harness/releases/tag/v0.2.0',
      });
      expect(entry, isNotNull);
      expect(entry!.version, '0.2.0');
      expect(entry.url, contains('/tag/v0.2.0'));
    });

    test('a payload without a usable tag answers null', () {
      expect(parseGitHubRelease({'tag_name': ''}), isNull);
      expect(parseGitHubRelease({'html_url': 'x'}), isNull);
      expect(parseGitHubRelease({}), isNull);
    });

    test('a missing html_url falls back to the releases page', () {
      final entry = parseGitHubRelease({'tag_name': 'v0.2.0'});
      expect(entry!.url, endsWith('/releases'));
    });
  });
}
