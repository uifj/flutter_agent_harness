import 'package:app_common/better_auth/flutter_better_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:stone_core/logger/logger_core.dart';

/// Wraps google_sign_in v7 to obtain a Google ID token and hand it to Better
/// Auth's native (idToken) social sign-in.
///
/// Setup required (see example/README.md):
///  - GOOGLE_SERVER_CLIENT_ID = the Google OAuth **Web** client id configured
///    on the Better Auth server's `socialProviders.google.clientId`.
///  - iOS: GOOGLE_IOS_CLIENT_ID + reversed-client-id URL scheme in Info.plist.
///  - Android: app SHA-1 registered with an Android OAuth client.
///
/// TODO(social): this file is ready; the blocker is external setup, not code —
///  - Backend `trustedOrigins` (`agent_harness_server/src/lib/auth.ts`) and the
///    macOS `myapp://` scheme (Info.plist) are configured. This native Google
///    path additionally needs its own reversed-client-id URL scheme on iOS/macOS.
///  - The client ids above come from root `.env`; keep `BETTER_AUTH_SECRET`
///    (and any OAuth *secret*) on the server only — never in `.env`.
class GoogleAuthService {
  static bool _initialized = false;

  static Future<void> init({String? serverClientId, String? clientId}) async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId,
      clientId: clientId,
    );
    _initialized = true;
  }

  /// Triggers the native Google account picker, then exchanges the resulting
  /// ID token with Better Auth via `signIn.social(idToken:)`.
  static Future<Result<SignInSocialResponse>> signIn() async {
    StoneLogger.info('SIGNING ...', 'better_auth');
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw StateError('Google authenticate() is unsupported on this platform');
    }
    final account = await GoogleSignIn.instance.authenticate();

    final idToken = account.authentication.idToken;
    StoneLogger.info('ID TOKEN acquired: ${idToken != null}', 'better_auth');
    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Google returned no ID token — check GOOGLE_SERVER_CLIENT_ID',
      );
    }
    return FlutterBetterAuth.client.signIn.social(
      provider: 'google',
      idToken: SocialIdTokenBody(token: idToken),
    );
  }

  static Future<void> signOut() => GoogleSignIn.instance.signOut();
}
