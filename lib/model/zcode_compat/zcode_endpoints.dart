// ZCode-compatible frontend parameters (ADR-0045): the endpoint paths, request
// headers and protocol shapes the production client speaks, kept byte-identical
// to the ZCode desktop client (`packages/shared/src/zcodeEndpoint.ts:262-270`,
// `zcode-source-headers.ts:51-57`, `manifestUpdateProvider.ts:37-93`) so the
// self-built backend can implement the same contract. Pure Dart; no IO here.

/// The endpoint paths under a configured backend origin — the shapes, not a
/// default server: `origin` is empty until the user (or packaging) sets one.
abstract final class ZcodeEndpoints {
  static const String apiBasePath = '/api/v1';
  static const String planOpenAiBasePath = '/api/v1/zcode-plan';
  static const String planAnthropicBasePath = '/api/v1/zcode-plan/anthropic';
  static const String planBillingCurrentPath =
      '/api/v1/zcode-plan/billing/current';
  static const String planBillingBalancePath =
      '/api/v1/zcode-plan/billing/balance';
  static const String releaseManifestPath =
      '/api/v1/releases/electron/manifest';
  static const String clientConfigsPath = '/api/v1/client/configs';

  static String apiBaseUrl(String origin) =>
      '${_normalize(origin)}$apiBasePath';

  static String planOpenAiBaseUrl(String origin) =>
      '${_normalize(origin)}$planOpenAiBasePath';

  static String planAnthropicBaseUrl(String origin) =>
      '${_normalize(origin)}$planAnthropicBasePath';

  static String planBillingCurrentUrl(String origin) =>
      '${_normalize(origin)}$planBillingCurrentPath';

  static String planBillingBalanceUrl(String origin) =>
      '${_normalize(origin)}$planBillingBalancePath';

  /// `{origin}/api/v1/releases/electron/manifest?platform=…&device_mid=…&channel=…`
  /// (`manifestUpdateProvider.ts:40-42`).
  static String releaseManifestUrl({
    required String origin,
    required String platform,
    required String arch,
    required String channel,
    String? deviceMid,
  }) {
    final query = [
      'platform=$platform-$arch',
      if (deviceMid != null && deviceMid.isNotEmpty) 'device_mid=$deviceMid',
      'channel=${releaseChannelApiValue(channel)}',
    ].join('&');
    return '${_normalize(origin)}$releaseManifestPath?$query';
  }

  /// `{origin}/api/v1/client/configs?app_version=…&platform=…`
  /// (`forceUpdateGuard.ts:150-182`).
  static String clientConfigsUrl({
    required String origin,
    required String appVersion,
    required String platform,
  }) =>
      '${_normalize(origin)}$clientConfigsPath'
      '?app_version=$appVersion&platform=$platform';

  /// `stable → "1"`, anything else → `"3"` (`manifestUpdateProvider.ts:37-41`).
  static String releaseChannelApiValue(String channel) =>
      channel == 'preview' ? '3' : '1';

  static String _normalize(String origin) =>
      origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin;
}

/// The shared request headers (`zcode-source-headers.ts:51-57`): every value
/// optional, present keys exactly as ZCode sends them.
Map<String, String> zcodeSourceHeaders({
  String? platform,
  String? arch,
  String? releaseChannel,
  String? deviceMid,
}) {
  final headers = <String, String>{
    if (platform != null &&
        platform.isNotEmpty &&
        arch != null &&
        arch.isNotEmpty)
      'X-Platform': '$platform-$arch',
    if (releaseChannel != null && releaseChannel.isNotEmpty)
      'X-Release-Channel': ZcodeEndpoints.releaseChannelApiValue(
        releaseChannel,
      ),
    if (deviceMid != null && deviceMid.isNotEmpty) 'X-Device-Mid': deviceMid,
  };
  return headers;
}
