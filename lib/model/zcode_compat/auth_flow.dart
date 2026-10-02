// ZCode-compatible auth flow shapes (ADR-0045 PE): the server-initiated
// polling OAuth that ZCode's desktop client runs (`oauthService.ts:594-699`)
// — init, browser authorize, poll until ready — plus the self-built backend's
// web registration URL. Field names verbatim; parsing tolerates the two
// provider token spellings upstream serves (`zai.access_token`,
// `bigmodel.access_token|accessToken`). Pure Dart: the transport and the
// polling loop live in the state layer.

/// The poll statuses the backend's flow bucket answers with
/// (`oauthService.ts:725-761`).
enum ZcodeOAuthPollStatus { pending, ready, failed, unknown }

class ZcodeOAuthInitRequest {
  const ZcodeOAuthInitRequest({required this.provider});

  final String provider;

  Map<String, Object?> toJson() => {'provider': provider};
}

/// `POST /api/v1/oauth/cli/init` → `{code, msg, data:{flow_id, authorize_url,
/// expires_at, poll_interval_sec}}` (`oauthService.ts:622-665`).
class ZcodeOAuthInitData {
  const ZcodeOAuthInitData({
    required this.flowId,
    required this.authorizeUrl,
    this.expiresAt,
    this.pollIntervalSec = 1,
  });

  factory ZcodeOAuthInitData.fromJson(Map<String, Object?> json) =>
      ZcodeOAuthInitData(
        flowId: json['flow_id'] as String? ?? '',
        authorizeUrl: json['authorize_url'] as String? ?? '',
        expiresAt: (json['expires_at'] as num?)?.toInt(),
        pollIntervalSec: (json['poll_interval_sec'] as num?)?.toInt() ?? 1,
      );

  final String flowId;

  /// The provider authorize URL the desktop opens in the system browser. The
  /// backend is expected to have rewritten the redirect to its web transfer
  /// page (`oauthService.ts:644-653`).
  final String authorizeUrl;
  final int? expiresAt;
  final int pollIntervalSec;

  static bool looksEnveloped(Map<String, Object?> json) =>
      json['code'] != null && json['data'] is Map;
}

/// `GET /api/v1/oauth/cli/poll/{flowId}` → `{code, data:{status, user,
/// zai|bigmodel tokens, token}}`. `ready` carries all three required pieces
/// (`oauthService.ts:776-788`).
class ZcodeOAuthPollData {
  const ZcodeOAuthPollData({required this.status, this.session});

  factory ZcodeOAuthPollData.fromJson(Map<String, Object?> json) {
    final data = json['data'];
    final status = data is Map<String, Object?>
        ? data['status'] as String?
        : null;
    return ZcodeOAuthPollData(
      status: switch (status) {
        'pending' => ZcodeOAuthPollStatus.pending,
        'ready' => ZcodeOAuthPollStatus.ready,
        'failed' => ZcodeOAuthPollStatus.failed,
        _ => ZcodeOAuthPollStatus.unknown,
      },
      session: data is Map<String, Object?> && status == 'ready'
          ? ZcodeOAuthSession.fromPollData(data)
          : null,
    );
  }

  final ZcodeOAuthPollStatus status;
  final ZcodeOAuthSession? session;
}

/// The session a completed flow yields: user identity + provider tokens + the
/// shared zcode JWT. Both providers' token spellings are accepted because the
/// upstream payload is per-provider (`oauthService.ts:776-788`).
class ZcodeOAuthSession {
  const ZcodeOAuthSession({
    required this.provider,
    required this.userId,
    required this.username,
    required this.displayName,
    this.email,
    this.avatarUrl,
    required this.providerAccessToken,
    this.providerRefreshToken,
    required this.jwt,
  });

  /// Reads the `data` map of a `ready` poll response.
  factory ZcodeOAuthSession.fromPollData(Map<String, Object?> data) {
    final user = data['user'];
    final userMap = user is Map<String, Object?> ? user : const {};
    final providerTokens = _tokensOf(data);
    return ZcodeOAuthSession(
      provider: providerTokens.provider,
      userId: userMap['user_id'] as String? ?? '',
      username: userMap['name'] as String? ?? '',
      displayName: userMap['name'] as String? ?? '',
      email: userMap['email'] as String?,
      avatarUrl: userMap['avatar'] as String?,
      providerAccessToken: providerTokens.accessToken,
      providerRefreshToken: providerTokens.refreshToken,
      jwt: data['token'] as String? ?? '',
    );
  }

  static ({String provider, String accessToken, String? refreshToken})
  _tokensOf(Map<String, Object?> data) {
    final zai = data['zai'];
    if (zai is Map<String, Object?>) {
      return (
        provider: 'zai',
        accessToken: zai['access_token'] as String? ?? '',
        refreshToken: (zai['refresh_token'] ?? zai['refreshToken']) as String?,
      );
    }
    final bigmodel = data['bigmodel'];
    if (bigmodel is Map<String, Object?>) {
      return (
        provider: 'bigmodel',
        accessToken:
            (bigmodel['access_token'] ?? bigmodel['accessToken']) as String? ??
            '',
        refreshToken:
            (bigmodel['refresh_token'] ?? bigmodel['refreshToken']) as String?,
      );
    }
    return (provider: '', accessToken: '', refreshToken: null);
  }

  final String provider;
  final String userId;
  final String username;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String providerAccessToken;
  final String? providerRefreshToken;
  final String jwt;

  bool get isComplete =>
      provider.isNotEmpty &&
      userId.isNotEmpty &&
      providerAccessToken.isNotEmpty &&
      jwt.isNotEmpty;
}

abstract final class ZcodeAuthEndpoints {
  static const String oauthInitPath = '/api/v1/oauth/cli/init';
  static String oauthPollPath(String flowId) =>
      '/api/v1/oauth/cli/poll/$flowId';

  /// The self-built backend's web registration page — the form itself lives
  /// server-side (ZCode has no in-app registration either; the client opens
  /// the web page). Documented as this project's one auth extension beyond
  /// the ZCode OAuth surface.
  static String registerUrl(String origin) => '${_normalize(origin)}/register';

  /// The local expiry ZCode enforces (`OAUTH_TIMEOUT_MS`, line 38).
  static const Duration flowTimeout = Duration(minutes: 5);

  static String _normalize(String origin) =>
      origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin;
}
