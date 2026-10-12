import 'package:dio/dio.dart';
import 'package:flutter_better_auth/core/api/models/result/result.dart';
import 'package:flutter_better_auth/core/api/models/result/success_response.dart';
import 'package:retrofit/retrofit.dart';

import '../../core/api/adapter.dart';
import 'models/api_key_model.dart';
import 'models/api_keys_list_response.dart';
import 'models/delete_expired_api_keys_response.dart';
import 'models/verify_api_key_response.dart';

part 'api_key_better_auth.g.dart';

@RestApi(callAdapter: BetterAuthCallAdapter)
abstract class ApiKeyBetterAuth {
  factory ApiKeyBetterAuth(
    Dio dio, {
    String? baseUrl,
    ParseErrorLogger? errorLogger,
  }) = _ApiKeyBetterAuth;

  @POST('/api-key/create')
  Future<Result<ApiKeyModel>> create({
    @BodyExtra('configId') String? configId,
    @BodyExtra('name') String? name,
    @BodyExtra('expiresIn') int? expiresIn,
    @BodyExtra('userId') String? userId,
    @BodyExtra('organizationId') String? organizationId,
    @BodyExtra('prefix') String? prefix,
    @BodyExtra('remaining') int? remaining,
    @BodyExtra('metadata') Map<String, dynamic>? metadata,
    @BodyExtra('permissions') Map<String, dynamic>? permissions,
  });

  @POST('/api-key/verify')
  Future<Result<VerifyApiKeyResponse>> verify({
    @BodyExtra('configId') String? configId,
    @BodyExtra('key') required String key,
    @BodyExtra('permissions') Map<String, dynamic>? permissions,
  });

  /// Same as Better Auth client `authClient.apiKey.get` (GET `/api-key/get`).
  @GET('/api-key/get')
  Future<Result<ApiKeyModel>> fetch({
    @Query('configId') String? configId,
    @Query('id') required String id,
  });

  @POST('/api-key/update')
  Future<Result<ApiKeyModel>> update({
    @BodyExtra('configId') String? configId,
    @BodyExtra('keyId') required String keyId,
    @BodyExtra('userId') String? userId,
    @BodyExtra('name') String? name,
    @BodyExtra('enabled') bool? enabled,
    @BodyExtra('remaining') int? remaining,
    @BodyExtra('refillAmount') int? refillAmount,
    @BodyExtra('refillInterval') int? refillInterval,
    @BodyExtra('metadata') Map<String, dynamic>? metadata,
  });

  @POST('/api-key/delete')
  Future<Result<SuccessResponse>> delete({
    @BodyExtra('configId') String? configId,
    @BodyExtra('keyId') required String keyId,
  });

  @GET('/api-key/list')
  Future<Result<ApiKeysListResponse>> list({
    @Query('configId') String? configId,
    @Query('organizationId') String? organizationId,
    @Query('limit') int? limit,
    @Query('offset') int? offset,
    @Query('sortBy') String? sortBy,
    @Query('sortDirection') String? sortDirection,
  });

  @POST('/api-key/delete-all-expired-api-keys')
  Future<Result<DeleteExpiredApiKeysResponse>> deleteAllExpired({
    @Body(nullToAbsent: true) Map<String, dynamic> body = const {},
  });
}
