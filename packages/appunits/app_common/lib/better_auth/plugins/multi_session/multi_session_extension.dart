import '../../core/api/better_auth_client.dart';
import '../../core/flutter_better_auth.dart';
import 'multi_session_better_auth.dart';

extension MultiSessionBetterAuthExtension on BetterAuthClient {
  MultiSessionBetterAuth get multiSession => MultiSessionBetterAuth(
    FlutterBetterAuth.dioClient,
    baseUrl: FlutterBetterAuth.baseUrl,
  );
}
