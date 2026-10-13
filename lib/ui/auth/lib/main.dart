import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:app_common/better_auth/flutter_better_auth.dart';
// HiveStorage is native-only and not exported from the barrel; import directly.
import 'package:app_common/better_auth/core/storage/hive_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'harness/session_header.dart';
import 'services/google_auth.dart';
import 'tabs/admin_tab.dart';
import 'tabs/api_key_tab.dart';
import 'tabs/auth_tab.dart';
import 'tabs/email_otp_tab.dart';
import 'tabs/jwt_ott_tab.dart';
import 'tabs/magic_link_tab.dart';
import 'tabs/multi_session_tab.dart';
import 'tabs/organization_tab.dart';
import 'tabs/passkey_tab.dart';
import 'tabs/phone_tab.dart';
import 'tabs/sessions_tab.dart';
import 'tabs/social_tab.dart';
import 'tabs/two_factor_tab.dart';

// ── External prerequisites for social / Google sign-in ────────────────────────
// Email + password sign-in works against the running backend as-is. The native
// Google/social flow needs setup OUTSIDE this Dart code before it can succeed:
//
//  1. [DONE] Backend `trustedOrigins` (agent_harness_server `src/lib/auth.ts`):
//     the Flutter client's origin and the `myapp://` callback scheme are listed,
//     so Better Auth no longer replies 403 "origin not trusted".
//  2. [TODO] Google Cloud OAuth clients → put the ids in root `.env`:
//     `GOOGLE_SERVER_CLIENT_ID` (the Web client id, = the server's
//     `socialProviders.google.clientId`) and `GOOGLE_IOS_CLIENT_ID`.
//  3. [DONE] macOS `Runner/Info.plist`: the `myapp://` callback scheme is
//     registered under `CFBundleURLTypes`, matching `scheme: 'myapp'` below;
//     flutter_web_auth_2 receives the redirect through it. Remaining native
//     pieces: iOS reversed-client-id scheme + Android app SHA-1 OAuth client.
//  4. Keep real secrets OUT of `.env`: it ships only the localhost
//     `BETTER_AUTH_URL` and (empty) public client ids; `BETTER_AUTH_SECRET`
//     lives on the server only.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  // Local-run cookie persistence: use HiveStorage (writes a Hive box under the
  // app-support dir) instead of the default SecureStorage. The default backs
  // cookies with the macOS Keychain, but a `flutter run` debug build is ad-hoc
  // signed and has no `keychain-access-groups` entitlement, so Keychain writes
  // fail with errSecMissingEntitlement (-34018) and break signIn.email even
  // though the backend already returned 200.
  //
  // TODO(keychain): switch back to the encrypted SecureStorage for production
  // once the Runner target has the Keychain Sharing capability + a real Apple
  // Development signing team (then simply drop `store:` to fall back to the
  // SecureStorage default, or pass SecureStorage() explicitly).
  await HiveStorage.init();
  await FlutterBetterAuth.initialize(
    url: dotenv.env['BETTER_AUTH_URL']!,
    store: HiveStorage(),
    // Required for native social sign-in: sent as `expo-origin` so the
    // Better Auth Expo server recognizes the native flow and appends the
    // session cookie to the `myapp://` callback deeplink. Must match the
    // scheme registered in AndroidManifest.xml / Info.plist and the
    // server's trustedOrigins.
    // macOS Info.plist `myapp` scheme + backend trustedOrigins are configured;
    // still TODO(social): supply the Google OAuth client ids in root `.env` (and
    // the iOS reversed-client-id scheme / Android SHA-1) — see the block above.
    scheme: 'myapp',
  );
  String? envOrNull(String key) {
    final v = dotenv.env[key];
    return (v == null || v.isEmpty) ? null : v;
  }

  try {
    await GoogleAuthService.init(
      serverClientId: envOrNull('GOOGLE_SERVER_CLIENT_ID'),
      // On web, google_sign_in needs the WEB client id as `clientId`
      // (the web origin must be an "Authorized JavaScript origin" of that
      // client). On native, use the iOS client id (or null).
      clientId: kIsWeb
          ? envOrNull('GOOGLE_SERVER_CLIENT_ID')
          : envOrNull('GOOGLE_IOS_CLIENT_ID'),
    );
  } catch (e) {
    debugPrint('Google sign-in init skipped: $e');
  }
  // Detect an existing session on load (e.g. after returning from a web OAuth
  // redirect).
  unawaited(FlutterBetterAuth.refreshSession());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BetterAuthProvider(
      child: ShadApp(
        title: 'BetterAuth Harness',
        darkTheme: ShadThemeData(
          brightness: Brightness.dark,
          colorScheme: ShadNeutralColorScheme.dark(),
        ),
        theme: ShadThemeData(
          brightness: Brightness.light,
          colorScheme: ShadNeutralColorScheme.light(),
        ),
        themeMode: ThemeMode.dark,
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BetterAuthConsumer(
      builder: (context, client) {
        final tabs = <(String, Widget)>[
          ('Auth', const AuthTab()),
          ('Sessions', const SessionsTab()),
          ('Social', const SocialTab()),
          ('2FA', const TwoFactorTab()),
          ('Admin', const AdminTab()),
          ('Org', const OrganizationTab()),
          ('API Key', const ApiKeyTab()),
          ('Passkey', const PasskeyTab()),
          ('Phone', const PhoneTab()),
          ('Email OTP', const EmailOtpTab()),
          ('Magic Link', const MagicLinkTab()),
          ('Multi-Session', const MultiSessionTab()),
          ('JWT / OTT', const JwtOttTab()),
        ];
        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Better Auth Harness'),
              bottom: TabBar(
                isScrollable: true,
                tabs: [for (final tab in tabs) Tab(text: tab.$1)],
              ),
            ),
            body: Column(
              children: [
                SessionHeader(client: client),
                Expanded(
                  child: TabBarView(children: [for (final tab in tabs) tab.$2]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
