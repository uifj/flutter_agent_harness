import '../../core/api/better_auth_client.dart';
import '../../core/flutter_better_auth.dart';
import 'api_key_better_auth.dart';

extension ApiKeyBetterAuthExtension on BetterAuthClient {
  ApiKeyBetterAuth get apiKey => ApiKeyBetterAuth(
        FlutterBetterAuth.dioClient,
        baseUrl: FlutterBetterAuth.baseUrl,
      );
}
