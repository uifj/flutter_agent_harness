import '../../core/api/better_auth_client.dart';
import '../../core/flutter_better_auth.dart';
import 'two_factor_better_auth.dart';

extension TwoFactorBetterAuthExtension on BetterAuthClient {
  TwoFactorBetterAuth get twoFactor => TwoFactorBetterAuth(
        FlutterBetterAuth.dioClient,
        baseUrl: FlutterBetterAuth.baseUrl,
      );
}
