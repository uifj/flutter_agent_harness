import 'package:dio/dio.dart';
import 'package:flutter_better_auth/core/api/default/sign_up/models/sign_up_response/sign_up_response.dart';
import 'package:flutter_better_auth/core/api/models/result/result.dart';
import 'package:flutter_better_auth/core/api/models/result/status_response.dart';
import 'package:retrofit/retrofit.dart';

import '../../core/api/adapter.dart';
import 'models/two_factor_backup_codes_response.dart';
import 'models/two_factor_enable_response.dart';
import 'models/two_factor_totp_uri_response.dart';

part 'two_factor_better_auth.g.dart';

@RestApi(callAdapter: BetterAuthCallAdapter)
abstract class TwoFactorBetterAuth {
  factory TwoFactorBetterAuth(
    Dio dio, {
    String? baseUrl,
    ParseErrorLogger? errorLogger,
  }) = _TwoFactorBetterAuth;

  @POST('/two-factor/enable')
  Future<Result<TwoFactorEnableResponse>> enable({
    @BodyExtra('password') String? password,
    @BodyExtra('issuer') String? issuer,
  });

  @POST('/two-factor/disable')
  Future<Result<StatusResponse>> disable({
    @BodyExtra('password') String? password,
  });

  @POST('/two-factor/get-totp-uri')
  Future<Result<TwoFactorTotpUriResponse>> getTotpUri({
    @BodyExtra('password') String? password,
  });

  @POST('/two-factor/verify-totp')
  Future<Result<SignUpResponse>> verifyTotp({
    @BodyExtra('code') required String code,
    @BodyExtra('trustDevice') bool? trustDevice,
  });

  @POST('/two-factor/send-otp')
  Future<Result<StatusResponse>> sendOtp({
    @BodyExtra('trustDevice') bool? trustDevice,
  });

  @POST('/two-factor/verify-otp')
  Future<Result<SignUpResponse>> verifyOtp({
    @BodyExtra('code') required String code,
    @BodyExtra('trustDevice') bool? trustDevice,
  });

  @POST('/two-factor/verify-backup-code')
  Future<Result<SignUpResponse>> verifyBackupCode({
    @BodyExtra('code') required String code,
    @BodyExtra('disableSession') bool? disableSession,
    @BodyExtra('trustDevice') bool? trustDevice,
  });

  @POST('/two-factor/generate-backup-codes')
  Future<Result<TwoFactorBackupCodesResponse>> generateBackupCodes({
    @BodyExtra('password') String? password,
  });

  @POST('/two-factor/view-backup-codes')
  Future<Result<TwoFactorBackupCodesResponse>> viewBackupCodes({
    @BodyExtra('userId') required String userId,
  });
}
