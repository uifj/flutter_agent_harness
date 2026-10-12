import '../../core/api/better_auth_client.dart';
import '../../core/flutter_better_auth.dart';
import 'one_time_token_better_auth.dart';

extension OneTimeTokenBetterAuthExtension on BetterAuthClient {
  OneTimeTokenBetterAuth get oneTimeToken => OneTimeTokenBetterAuth(
    FlutterBetterAuth.dioClient,
    baseUrl: FlutterBetterAuth.baseUrl,
  );
}
