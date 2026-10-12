import 'package:dio/dio.dart';
import 'package:flutter_better_auth/core/api/models/session/session_response.dart';
import 'package:retrofit/retrofit.dart';

import '../../core/api/adapter.dart';
import '../../core/api/models/result/result.dart';
import '../../core/api/models/result/status_response.dart';

part 'multi_session_better_auth.g.dart';

/// Better Auth [`multi-session`](https://www.better-auth.com/docs/plugins/multi-session)
/// plugin — manage several signed-in accounts on one device.
@RestApi(callAdapter: BetterAuthCallAdapter)
abstract class MultiSessionBetterAuth {
  factory MultiSessionBetterAuth(
    Dio dio, {
    String? baseUrl,
    ParseErrorLogger? errorLogger,
  }) = _MultiSessionBetterAuth;

  /// All sessions stored on this device (each with its user).
  @GET('/multi-session/list-device-sessions')
  Future<Result<List<SessionResponse>>> listDeviceSessions();

  /// Switches the active session to the one identified by [sessionToken].
  @POST('/multi-session/set-active')
  Future<Result<SessionResponse>> setActive({
    @BodyExtra('sessionToken') required String sessionToken,
  });

  /// Revokes the device session identified by [sessionToken].
  @POST('/multi-session/revoke')
  Future<Result<StatusResponse>> revoke({
    @BodyExtra('sessionToken') required String sessionToken,
  });
}
