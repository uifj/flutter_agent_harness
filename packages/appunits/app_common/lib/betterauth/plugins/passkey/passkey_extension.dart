import '../../core/api/better_auth_client.dart';
import '../../core/flutter_better_auth.dart';
import 'passkey_better_auth.dart';

extension PasskeyBetterAuthExtension on BetterAuthClient {
  PasskeyBetterAuth get passkey => PasskeyBetterAuth(
    FlutterBetterAuth.dioClient,
    baseUrl: FlutterBetterAuth.baseUrl,
  );
}
