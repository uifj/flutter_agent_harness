import '../../core/api/better_auth_client.dart';
import '../../core/flutter_better_auth.dart';
import 'anonymous_better_auth.dart';

extension AnonymousBetterAuthExtension on BetterAuthClient {
  AnonymousBetterAuth get anonymous => AnonymousBetterAuth(
    FlutterBetterAuth.dioClient,
    baseUrl: FlutterBetterAuth.baseUrl,
  );
}
