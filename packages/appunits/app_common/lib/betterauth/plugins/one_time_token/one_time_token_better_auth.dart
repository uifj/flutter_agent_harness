import 'package:dio/dio.dart';
import 'package:flutter_better_auth/core/api/models/session/session_response.dart';
import 'package:retrofit/retrofit.dart';

import '../../core/api/adapter.dart';
import '../../core/api/models/result/result.dart';
import 'models/one_time_token_generate_response.dart';

part 'one_time_token_better_auth.g.dart';

@RestApi(callAdapter: BetterAuthCallAdapter)
abstract class OneTimeTokenBetterAuth {
  factory OneTimeTokenBetterAuth(
    Dio dio, {
    String? baseUrl,
    ParseErrorLogger? errorLogger,
  }) = _OneTimeTokenBetterAuth;

  /// Requires an authenticated session (cookies).
  @GET('/one-time-token/generate')
  Future<Result<OneTimeTokenGenerateResponse>> generate();

  /// Exchanges a one-time token for the linked session (sets session cookie unless the server disables it).
  @POST('/one-time-token/verify')
  Future<Result<SessionResponse>> verify({
    @BodyExtra('token') required String token,
  });
}
