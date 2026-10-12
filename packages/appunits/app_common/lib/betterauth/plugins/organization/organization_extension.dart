import '../../core/api/better_auth_client.dart';
import '../../core/flutter_better_auth.dart';
import 'organization_better_auth.dart';

extension OrganizationBetterAuthExtension on BetterAuthClient {
  OrganizationBetterAuth get organization => OrganizationBetterAuth(
    FlutterBetterAuth.dioClient,
    baseUrl: FlutterBetterAuth.baseUrl,
  );
}
