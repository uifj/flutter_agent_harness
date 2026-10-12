import 'package:dio/dio.dart';
import 'package:flutter_better_auth/core/api/models/session/session_response.dart';
import 'package:retrofit/retrofit.dart';

import '../../core/api/adapter.dart';
import '../../core/api/models/result/result.dart';
import '../../core/api/models/result/status_response.dart';

part 'magic_link_better_auth.g.dart';

/// Better Auth [`magic-link`](https://www.better-auth.com/docs/plugins/magic-link) plugin.
@RestApi(callAdapter: BetterAuthCallAdapter)
abstract class MagicLinkBetterAuth {
  factory MagicLinkBetterAuth(
    Dio dio, {
    String? baseUrl,
    ParseErrorLogger? errorLogger,
  }) = _MagicLinkBetterAuth;

  /// Sends a magic link to [email]. The server delivers the link (email/SMS);
  /// the user opens it and the app handles the resulting deep link, then calls
  /// [verify] with the `token` query parameter.
  @POST('/sign-in/magic-link')
  Future<Result<StatusResponse>> signIn({
    @BodyExtra('email') required String email,
    @BodyExtra('name') String? name,
    @BodyExtra('callbackURL') String? callbackURL,
    @BodyExtra('newUserCallbackURL') String? newUserCallbackURL,
    @BodyExtra('errorCallbackURL') String? errorCallbackURL,
  });

  /// Exchanges the magic-link [token] for a session (sets the session cookie).
  @GET('/magic-link/verify')
  Future<Result<SessionResponse>> verify({
    @Query('token') required String token,
    @Query('callbackURL') String? callbackURL,
  });
}
