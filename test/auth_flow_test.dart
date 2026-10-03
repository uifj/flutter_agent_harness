// ADR-0045 PE guards: the auth flow DTOs parse ZCode's verbatim response
// shapes, and the session state machine drives the polling flow against a
// fake transport — init, poll pending/failed/ready, persistence into the
// secret store, restore from cache with the JWT's local expiry, logout, and
// the welcome gate's reasons.

import 'dart:convert';

import 'package:planstar/model/zcode_compat/zcode_compat.dart';
import 'package:planstar/state/auth_session.dart';
import 'package:planstar/state/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('auth flow DTOs (oauthService.ts:608-788)', () {
    test('init data parses the verbatim envelope', () {
      final data = ZcodeOAuthInitData.fromJson({
        'flow_id': 'flow-1',
        'authorize_url': 'https://chat.z.ai/api/oauth/authorize?state=abc',
        'expires_at': 1790000000,
        'poll_interval_sec': 2,
      });
      expect(data.flowId, 'flow-1');
      expect(data.authorizeUrl, contains('oauth/authorize'));
      expect(data.pollIntervalSec, 2);
      expect(ZcodeOAuthInitData.fromJson(const {}).pollIntervalSec, 1);
    });

    test('poll ready parses the zai token spelling and user', () {
      final poll = ZcodeOAuthPollData.fromJson({
        'code': 0,
        'data': {
          'status': 'ready',
          'user': {
            'user_id': 'u-1',
            'name': 'Demo',
            'email': 'd@x.io',
            'avatar': 'https://a/p.png',
          },
          'zai': {'access_token': 'zat', 'refresh_token': 'zrt'},
          'token': 'jwt-value',
        },
      });
      expect(poll.status, ZcodeOAuthPollStatus.ready);
      final session = poll.session!;
      expect(session.isComplete, isTrue);
      expect(session.provider, 'zai');
      expect(session.username, 'Demo');
      expect(session.providerAccessToken, 'zat');
      expect(session.providerRefreshToken, 'zrt');
      expect(session.jwt, 'jwt-value');
    });

    test('poll ready parses the bigmodel camelCase token spelling', () {
      final poll = ZcodeOAuthPollData.fromJson({
        'code': 0,
        'data': {
          'status': 'ready',
          'user': {'user_id': 'u-2', 'name': 'Bm'},
          'bigmodel': {'accessToken': 'bmt', 'refreshToken': 'brt'},
          'token': 'jwt-2',
        },
      });
      expect(poll.session!.provider, 'bigmodel');
      expect(poll.session!.providerAccessToken, 'bmt');
    });

    test('pending and failed map without a session', () {
      expect(
        ZcodeOAuthPollData.fromJson({
          'code': 0,
          'data': {'status': 'pending'},
        }).status,
        ZcodeOAuthPollStatus.pending,
      );
      final failed = ZcodeOAuthPollData.fromJson({
        'code': 0,
        'data': {'status': 'failed'},
      });
      expect(failed.status, ZcodeOAuthPollStatus.failed);
      expect(failed.session, isNull);
    });

    test('the endpoints keep the upstream paths', () {
      expect(ZcodeAuthEndpoints.oauthInitPath, '/api/v1/oauth/cli/init');
      expect(
        ZcodeAuthEndpoints.oauthPollPath('f1'),
        '/api/v1/oauth/cli/poll/f1',
      );
      expect(
        ZcodeAuthEndpoints.registerUrl('https://api.example.com/'),
        'https://api.example.com/register',
      );
      expect(ZcodeAuthEndpoints.flowTimeout, const Duration(minutes: 5));
    });
  });

  group('AuthSession', () {
    late InMemorySecretStore secrets;
    late List<String> openedUrls;

    AuthSession sessionWith(List<Map<String, Object?>> responses) {
      var call = 0;
      return AuthSession(
        secrets: secrets,
        origin: 'https://api.example.com',
        client: MockClient((request) async {
          if (call < responses.length) {
            final body = jsonEncode(responses[call++]);
            return http.Response(body, 200);
          }
          return http.Response(jsonEncode({'code': 1}), 200);
        }),
        openUrl: (url) async {
          openedUrls.add(url.toString());
        },
        now: () => DateTime.utc(2026, 10, 2),
      );
    }

    setUp(() {
      secrets = InMemorySecretStore();
      openedUrls = [];
    });

    test('a ready flow persists the session under the upstream keys', () async {
      final session = sessionWith([
        {
          'code': 0,
          'data': {
            'flow_id': 'f1',
            'authorize_url': 'https://chat.z.ai/authorize?state=s1',
            'poll_interval_sec': 0,
          },
        },
        {
          'code': 0,
          'data': {
            'status': 'ready',
            'user': {'user_id': 'u-1', 'name': 'Demo'},
            'zai': {'access_token': 'zat'},
            'token': 'jwt-1',
          },
        },
      ]);
      final ok = await session.startBrowserFlow('zai');
      expect(ok, isTrue);
      expect(session.isSignedIn, isTrue);
      expect(session.user!.displayName, 'Demo');
      expect(openedUrls.single, 'https://chat.z.ai/authorize?state=s1');
      expect(await secrets.read(ZcodeOAuth.keyAccessToken('zai')), 'zat');
      expect(await secrets.read('zcodejwttoken'), 'jwt-1');
      expect(await secrets.read(ZcodeOAuth.keyActiveProvider), 'zai');
      expect(session.welcomeOpen, isFalse);
    });

    test('a failed flow signs out and the gate shows the error path', () async {
      final session = sessionWith([
        {
          'code': 0,
          'data': {
            'flow_id': 'f1',
            'authorize_url': 'https://x/authorize',
            'poll_interval_sec': 0,
          },
        },
        {
          'code': 0,
          'data': {'status': 'failed'},
        },
      ]);
      session.openWelcome(WelcomeReason.manualLogin);
      expect(await session.startBrowserFlow('zai'), isFalse);
      expect(session.isSignedIn, isFalse);
    });

    test('restore reads the cached profile while the JWT is fresh', () async {
      const profile = ZcodeUserInfo(
        id: 'u-1',
        username: 'demo',
        displayName: 'Demo',
      );
      final jwtPayload = base64Url.encode(
        utf8.encode(jsonEncode({'exp': 4102444800})),
      );
      await secrets.write(ZcodeOAuth.keyActiveProvider, 'zai');
      await secrets.write(ZcodeOAuth.keyAccessToken('zai'), 'zat');
      await secrets.write(
        ZcodeOAuth.keyUserInfo('zai'),
        jsonEncode(profile.toJson()),
      );
      await secrets.write('zcodejwttoken', 'header.$jwtPayload.sig');
      final session = AuthSession(
        secrets: secrets,
        origin: 'https://api.example.com',
        client: MockClient((request) async => http.Response('{}', 200)),
        openUrl: (_) async {},
        now: () => DateTime.utc(2026, 10, 2),
      );
      expect(await session.restore(hasApiKey: true), isTrue);
      expect(session.isSignedIn, isTrue);
      expect(session.welcomeOpen, isFalse);
    });

    test('an expired JWT flips restore to reauthentication', () async {
      const profile = ZcodeUserInfo(
        id: 'u-1',
        username: 'demo',
        displayName: 'Demo',
      );
      final jwtPayload = base64Url.encode(utf8.encode(jsonEncode({'exp': 1})));
      await secrets.write(ZcodeOAuth.keyActiveProvider, 'zai');
      await secrets.write(
        ZcodeOAuth.keyUserInfo('zai'),
        jsonEncode(profile.toJson()),
      );
      await secrets.write('zcodejwttoken', 'header.$jwtPayload.sig');
      final session = AuthSession(
        secrets: secrets,
        origin: 'https://api.example.com',
        client: MockClient((request) async => http.Response('{}', 200)),
        openUrl: (_) async {},
        now: () => DateTime.utc(2026, 10, 2),
      );
      expect(await session.restore(hasApiKey: true), isFalse);
      expect(session.welcomeReason, WelcomeReason.sessionExpired);
    });

    test('logout clears every key of the active provider', () async {
      final session = sessionWith([
        {
          'code': 0,
          'data': {
            'flow_id': 'f1',
            'authorize_url': 'https://x/a',
            'poll_interval_sec': 0,
          },
        },
        {
          'code': 0,
          'data': {
            'status': 'ready',
            'user': {'user_id': 'u-1', 'name': 'Demo'},
            'zai': {'access_token': 'zat'},
            'token': 'jwt-1',
          },
        },
      ]);
      await session.startBrowserFlow('zai');
      await session.logout();
      expect(session.isSignedIn, isFalse);
      expect(await secrets.read(ZcodeOAuth.keyAccessToken('zai')), isNull);
      expect(await secrets.read('zcodejwttoken'), isNull);
      // A manual logout re-opens the gate, ZCode's manual-login semantics.
      expect(session.welcomeReason, WelcomeReason.manualLogin);
    });
  });
}
