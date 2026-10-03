// ADR-0045 PA: the ZCode-compatible parameter layer is pinned against the
// archived client's values — an endpoint path that drifts is a backend
// contract break, so the expectations here are verbatim strings, not shapes.

import 'package:planstar/model/zcode_compat/zcode_compat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('endpoints (zcodeEndpoint.ts:262-270)', () {
    test('the five plan paths build verbatim under an origin', () {
      expect(
        ZcodeEndpoints.apiBaseUrl('https://api.example.com'),
        'https://api.example.com/api/v1',
      );
      expect(
        ZcodeEndpoints.planOpenAiBaseUrl('https://api.example.com'),
        'https://api.example.com/api/v1/zcode-plan',
      );
      expect(
        ZcodeEndpoints.planAnthropicBaseUrl('https://api.example.com'),
        'https://api.example.com/api/v1/zcode-plan/anthropic',
      );
      expect(
        ZcodeEndpoints.planBillingCurrentUrl('https://api.example.com'),
        'https://api.example.com/api/v1/zcode-plan/billing/current',
      );
      expect(
        ZcodeEndpoints.planBillingBalanceUrl('https://api.example.com'),
        'https://api.example.com/api/v1/zcode-plan/billing/balance',
      );
    });

    test('a trailing slash on the origin does not double', () {
      expect(
        ZcodeEndpoints.apiBaseUrl('https://api.example.com/'),
        'https://api.example.com/api/v1',
      );
    });

    test('the manifest URL carries platform/device_mid/channel', () {
      expect(
        ZcodeEndpoints.releaseManifestUrl(
          origin: 'https://api.example.com',
          platform: 'darwin',
          arch: 'arm64',
          channel: 'stable',
          deviceMid: 'abc-123',
        ),
        'https://api.example.com/api/v1/releases/electron/manifest'
        '?platform=darwin-arm64&device_mid=abc-123&channel=1',
      );
    });

    test(
      'release channel maps stable→1, preview→3 (manifestUpdateProvider.ts:37-41)',
      () {
        expect(ZcodeEndpoints.releaseChannelApiValue('stable'), '1');
        expect(ZcodeEndpoints.releaseChannelApiValue('preview'), '3');
        expect(ZcodeEndpoints.releaseChannelApiValue('anything'), '1');
      },
    );

    test('the client configs URL carries app_version and platform', () {
      expect(
        ZcodeEndpoints.clientConfigsUrl(
          origin: 'https://api.example.com',
          appVersion: '0.1.0',
          platform: 'macos',
        ),
        'https://api.example.com/api/v1/client/configs'
        '?app_version=0.1.0&platform=macos',
      );
    });
  });

  group('source headers (zcode-source-headers.ts:51-57)', () {
    test('all three present with values', () {
      expect(
        zcodeSourceHeaders(
          platform: 'darwin',
          arch: 'arm64',
          releaseChannel: 'preview',
          deviceMid: 'mid-1',
        ),
        {
          'X-Platform': 'darwin-arm64',
          'X-Release-Channel': '3',
          'X-Device-Mid': 'mid-1',
        },
      );
    });

    test('absent values drop their header, never send empty strings', () {
      expect(zcodeSourceHeaders(), isEmpty);
      expect(
        zcodeSourceHeaders(
          platform: '',
          arch: 'arm64',
        ).containsKey('X-Platform'),
        isFalse,
      );
    });
  });

  group('account shapes', () {
    test('UserInfo round-trips the upstream field names', () {
      const user = ZcodeUserInfo(
        id: 'u1',
        username: 'demo',
        displayName: 'Demo',
        avatarUrl: 'https://a/p.png',
        subscription: 'Pro',
      );
      final json = user.toJson();
      expect(
        json.keys,
        containsAll(['id', 'username', 'displayName', 'avatarUrl']),
      );
      expect(ZcodeUserInfo.fromJson(json), user);
    });

    test('oauth provider ids and storage keys keep the upstream names', () {
      expect(ZcodeOAuth.providerZai, 'zai');
      expect(ZcodeOAuth.providerBigmodel, 'bigmodel');
      expect(ZcodeOAuth.keyActiveProvider, 'oauth:active_provider');
      expect(ZcodeOAuth.keyAccessToken('zai'), 'oauth:zai:access_token');
      expect(
        ZcodeOAuth.keyRefreshToken('bigmodel'),
        'oauth:bigmodel:refresh_token',
      );
      expect(ZcodeOAuth.keyUserInfo('zai'), 'oauth:zai:user_info');
    });

    test('quota snapshot round-trips nullable fields by name', () {
      const limit = ZcodeUsageQuotaLimit(
        type: 'TOKENS_LIMIT',
        bucketId: 'b1',
        periodStart: 100,
        periodEnd: 200,
        meter: 'tokens',
        usage: 12.5,
        remaining: 87.5,
        percentage: 12.5,
        nextResetTime: 300,
        usageDetails: [
          ZcodeUsageQuotaUsageDetail(modelCode: 'glm-5', usage: 10),
        ],
      );
      final json = limit.toJson();
      // The wire names the backend will serve — verbatim upstream camelCase.
      expect(
        json.keys,
        containsAll(['type', 'bucketId', 'periodStart', 'nextResetTime']),
      );
      final round = ZcodeUsageQuotaSnapshot.fromJson({
        'level': 'PRO',
        'limits': [json],
      });
      expect(round.level, 'PRO');
      expect(round.limits.single.usage, 12.5);
      expect(round.limits.single.usageDetails.single.modelCode, 'glm-5');
      expect(round.limits.single.percentage, 12.5);
      // Absent nullable fields stay absent on the way back out.
      final sparse = ZcodeUsageQuotaLimit(type: 'MCP_USAGE_LIMIT').toJson();
      expect(sparse.containsKey('bucketId'), isFalse);
      expect(sparse['usageDetails'], isEmpty);
    });
  });

  group('deviceMid (deviceMid.ts:21-28)', () {
    test('generates valid v4-shaped uuids', () {
      for (var i = 0; i < 20; i++) {
        expect(isValidDeviceMid(generateDeviceMid()), isTrue, reason: 'run $i');
      }
    });

    test('the loader rejects junk and regenerates', () {
      expect(isValidDeviceMid(null), isFalse);
      expect(isValidDeviceMid(''), isFalse);
      expect(isValidDeviceMid('not-a-uuid'), isFalse);
      // v1-style or wrong variant are refused: only what the generator emits
      // round-trips through persistence.
      expect(isValidDeviceMid('5f2a8c1e-9b3d-4e7f-8a2b-1c9d4e7f2a8b'), isTrue);
      expect(isValidDeviceMid('5f2a8c1e-9b3d-1e7f-8a2b-1c9d4e7f2a8b'), isFalse);
    });
  });
}
