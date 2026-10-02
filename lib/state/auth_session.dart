// The auth session (ADR-0045 PE): the state machine behind the welcome
// screen — restore from cache, browser polling flow, logout. The transport
// and the launcher are injected so tests drive the whole flow without a
// network or a browser.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../model/zcode_compat/zcode_compat.dart';
import 'secret_store.dart';

/// Why the welcome screen is open — ZCode's reason set, minus the provider
/// flavors this client does not have (`Root.tsx:862-872`).
enum WelcomeReason { startupNoProvider, manualLogin, sessionExpired }

enum AuthStatus { signedOut, awaitingBrowser, signedIn }

/// Owns the logged-in state and the polling flow. Tokens live in the secret
/// store under the ZCode-compatible key names; the cached profile rides the
/// same store (`oauthService.ts:379-436` — cached at login, restore reads the
/// cache and validates only the JWT's local expiry).
class AuthSession extends ChangeNotifier {
  AuthSession({
    required SecretStore secrets,
    this.origin = '',
    http.Client? client,
    Future<void> Function(Uri url)? openUrl,
    DateTime Function()? now,
  }) : _secrets = secrets,
       _client = client ?? http.Client(),
       _openUrl =
           openUrl ??
           ((url) async {
             await launchUrl(url, mode: LaunchMode.externalApplication);
           }),
       _now = now ?? DateTime.now;

  final SecretStore _secrets;

  /// The self-built backend origin the flow dials; empty until configured.
  final String origin;
  final http.Client _client;
  final Future<void> Function(Uri url) _openUrl;
  final DateTime Function() _now;

  AuthStatus _status = AuthStatus.signedOut;
  ZcodeUserInfo? _user;
  WelcomeReason? _welcomeReason;
  bool _awaitingAck = false;
  Timer? _pollTimer;

  AuthStatus get status => _status;
  ZcodeUserInfo? get user => _user;
  bool get isSignedIn => _status == AuthStatus.signedIn;
  WelcomeReason? get welcomeReason => _welcomeReason;
  bool get welcomeOpen => _welcomeReason != null && !_awaitingAck;

  /// The backend origin — empty until configured; the flow refuses to start
  /// without one rather than dialing a placeholder.
  bool get hasOrigin => origin.trim().isNotEmpty;

  /// Opens (or re-opens) the welcome screen with [reason].
  void openWelcome(WelcomeReason reason) {
    _welcomeReason = reason;
    notifyListeners();
  }

  /// The skip answer (the API-key form's "skip for now"): closes the gate for
  /// this installation — the welcome screen only re-opens for explicit
  /// reasons (manual login, session expiry), not again at startup.
  void ackWelcome() {
    _awaitingAck = true;
    _welcomeReason = null;
    notifyListeners();
  }

  /// Startup restore: reads the cached profile, validates the JWT's local
  /// expiry (`oauthService.ts:182-269` — cache only, no remote call), and
  /// opens the welcome gate when the app has neither a session nor an API
  /// key. Returns whether the session restored.
  Future<bool> restore({required bool hasApiKey}) async {
    final profileJson = await _secrets.read(
      ZcodeOAuth.keyUserInfo(
        ZcodeOAuth.keyActiveProvider.contains('zai')
            ? ZcodeOAuth.providerZai
            : ZcodeOAuth.providerBigmodel,
      ),
    );
    final activeProvider = await _secrets.read(ZcodeOAuth.keyActiveProvider);
    final cached = activeProvider == null || activeProvider.isEmpty
        ? null
        : await _secrets.read(ZcodeOAuth.keyUserInfo(activeProvider));
    final source = cached ?? profileJson;
    final jwt = await _secrets.read('zcodejwttoken');
    final expired = _jwtExpired(jwt);
    if (source != null && !expired) {
      _user = ZcodeUserInfo.fromJson(
        jsonDecode(source) as Map<String, Object?>,
      );
      _status = AuthStatus.signedIn;
      notifyListeners();
      return true;
    }
    if (expired && source != null) {
      // A cached profile whose JWT expired is `reauthentication-required`:
      // the gate opens with the session-expired reason.
      _status = AuthStatus.signedOut;
      _welcomeReason = WelcomeReason.sessionExpired;
      notifyListeners();
      return false;
    }
    if (!hasApiKey) {
      _welcomeReason = WelcomeReason.startupNoProvider;
      notifyListeners();
    }
    return false;
  }

  /// Starts the browser polling flow: init → open authorize URL → poll until
  /// ready/expired/failed. Returns when the flow settles; the gate closes on
  /// success.
  Future<bool> startBrowserFlow(String provider) async {
    if (!hasOrigin || _status == AuthStatus.awaitingBrowser) return false;
    _status = AuthStatus.awaitingBrowser;
    notifyListeners();
    try {
      final init = await _postJson(
        ZcodeEndpoints.apiBaseUrl(origin) +
            ZcodeAuthEndpoints.oauthInitPath.substring('/api/v1'.length),
        ZcodeOAuthInitRequest(provider: provider).toJson(),
        bearer: _pollToken(),
      );
      if (init['code'] != 0) return _flowFailed();
      final data = ZcodeOAuthInitData.fromJson(
        init['data'] as Map<String, Object?>? ?? const {},
      );
      if (data.flowId.isEmpty || data.authorizeUrl.isEmpty) {
        return _flowFailed();
      }
      await _openUrl(Uri.parse(data.authorizeUrl));
      final deadline = _now().add(ZcodeAuthEndpoints.flowTimeout);
      final interval = data.pollIntervalSec < 1 ? 1 : data.pollIntervalSec;
      while (_now().isBefore(deadline)) {
        await Future<void>.delayed(Duration(seconds: interval));
        final poll = await _getJson(
          '${ZcodeEndpoints.apiBaseUrl(origin)}'
          '${ZcodeAuthEndpoints.oauthPollPath(data.flowId)}',
          bearer: _pollToken(),
        );
        if (poll['code'] != 0) continue; // network/5xx: keep retrying
        final result = ZcodeOAuthPollData.fromJson(poll);
        switch (result.status) {
          case ZcodeOAuthPollStatus.pending:
            continue;
          case ZcodeOAuthPollStatus.failed:
            return _flowFailed();
          case ZcodeOAuthPollStatus.ready:
            final session = result.session;
            if (session == null || !session.isComplete) return _flowFailed();
            await _persist(session);
            return true;
          case ZcodeOAuthPollStatus.unknown:
            continue;
        }
      }
      return _flowFailed();
    } on Exception {
      return _flowFailed();
    }
  }

  /// The shared JWT ZCode persists under its own key (`zcodejwttoken`).
  Future<String?> jwt() => _secrets.read('zcodejwttoken');

  /// Clears tokens and the cached profile; the provider tokens of the active
  /// provider go with it (`oauthService.ts` logout scope `active`).
  Future<void> logout() async {
    final activeProvider = await _secrets.read(ZcodeOAuth.keyActiveProvider);
    if (activeProvider != null && activeProvider.isNotEmpty) {
      await _secrets.delete(ZcodeOAuth.keyAccessToken(activeProvider));
      await _secrets.delete(ZcodeOAuth.keyRefreshToken(activeProvider));
      await _secrets.delete(ZcodeOAuth.keyUserInfo(activeProvider));
    }
    await _secrets.delete('zcodejwttoken');
    await _secrets.delete(ZcodeOAuth.keyActiveProvider);
    _user = null;
    _status = AuthStatus.signedOut;
    _welcomeReason = WelcomeReason.manualLogin;
    notifyListeners();
  }

  Future<void> _persist(ZcodeOAuthSession session) async {
    // Mutually exclusive identity domains: the inactive provider's tokens
    // are cleared first (`resolveInactiveOAuthProvider`, 102-110).
    final previous = await _secrets.read(ZcodeOAuth.keyActiveProvider);
    if (previous != null &&
        previous.isNotEmpty &&
        previous != session.provider) {
      await _secrets.delete(ZcodeOAuth.keyAccessToken(previous));
      await _secrets.delete(ZcodeOAuth.keyRefreshToken(previous));
      await _secrets.delete(ZcodeOAuth.keyUserInfo(previous));
    }
    await _secrets.write(
      ZcodeOAuth.keyAccessToken(session.provider),
      session.providerAccessToken,
    );
    if (session.providerRefreshToken != null) {
      await _secrets.write(
        ZcodeOAuth.keyRefreshToken(session.provider),
        session.providerRefreshToken!,
      );
    }
    final profile = ZcodeUserInfo(
      id: session.userId,
      username: session.username,
      displayName: session.displayName,
      avatarUrl: session.avatarUrl,
    );
    await _secrets.write(
      ZcodeOAuth.keyUserInfo(session.provider),
      jsonEncode(profile.toJson()),
    );
    await _secrets.write('zcodejwttoken', session.jwt);
    await _secrets.write(ZcodeOAuth.keyActiveProvider, session.provider);
    _user = profile;
    _status = AuthStatus.signedIn;
    _welcomeReason = null;
    notifyListeners();
  }

  bool _flowFailed() {
    _status = AuthStatus.signedOut;
    notifyListeners();
    return false;
  }

  /// The client-generated polling token (`randomBytes(32)` hex upstream,
  /// `oauthService.ts:608-617`) — derived from the current wall clock so
  /// every flow carries a fresh bearer.
  String _pollToken() =>
      _now().microsecondsSinceEpoch.toRadixString(16).padLeft(16, '0') * 4;

  bool _jwtExpired(String? jwt) {
    if (jwt == null || jwt.isEmpty) return true;
    final parts = jwt.split('.');
    if (parts.length < 2) return true;
    final normalized = base64Url.normalize(parts[1]);
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map<String, Object?>) return true;
      final exp = (payload['exp'] as num?)?.toInt();
      if (exp == null) return false; // no expiry claim: accept
      return _now().millisecondsSinceEpoch ~/ 1000 >= exp;
    } on FormatException {
      return true;
    }
  }

  Future<Map<String, Object?>> _postJson(
    String url,
    Map<String, Object?> body, {
    String? bearer,
  }) async {
    final response = await _client.post(
      Uri.parse(url),
      headers: {
        'content-type': 'application/json',
        if (bearer != null) 'Authorization': 'Bearer $bearer',
      },
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, Object?>> _getJson(String url, {String? bearer}) async {
    final response = await _client.get(
      Uri.parse(url),
      headers: {if (bearer != null) 'Authorization': 'Bearer $bearer'},
    );
    return _decode(response);
  }

  Map<String, Object?> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, Object?> ? decoded : const {};
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _client.close();
    super.dispose();
  }
}
