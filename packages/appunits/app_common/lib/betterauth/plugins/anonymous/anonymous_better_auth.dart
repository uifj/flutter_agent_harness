import 'package:dio/dio.dart';
import 'package:flutter_better_auth/core/api/adapter.dart';
import 'package:flutter_better_auth/core/api/models/result/result.dart';
import 'package:flutter_better_auth/core/api/models/result/success_response.dart';
import 'package:retrofit/retrofit.dart';

part 'anonymous_better_auth.g.dart';

/// Better Auth [`anonymous`](https://www.better-auth.com/docs/plugins/anonymous)
/// plugin: delete anonymous account.
///
/// Anonymous sign-in uses `client.signIn.anonymous()` ([`POST /sign-in/anonymous`](https://www.better-auth.com/docs/plugins/anonymous)).
@RestApi(callAdapter: BetterAuthCallAdapter)
abstract class AnonymousBetterAuth {
  factory AnonymousBetterAuth(
    Dio dio, {
    String? baseUrl,
    ParseErrorLogger? errorLogger,
  }) = _AnonymousBetterAuth;

  /// Requires session; rejects non-anonymous users. Clears session on success.
  @POST('/delete-anonymous-user')
  Future<Result<SuccessResponse>> deleteAnonymousUser({
    @Body(nullToAbsent: true) Map<String, dynamic> body = const {},
  });
}
