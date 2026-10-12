import '../../core/api/better_auth_client.dart';
import '../../core/flutter_better_auth.dart';
import 'magic_link_better_auth.dart';

extension MagicLinkBetterAuthExtension on BetterAuthClient {
  MagicLinkBetterAuth get magicLink => MagicLinkBetterAuth(
    FlutterBetterAuth.dioClient,
    baseUrl: FlutterBetterAuth.baseUrl,
  );
}
