import 'package:freezed_annotation/freezed_annotation.dart';

import 'api_key_model.dart';

part 'verify_api_key_response.freezed.dart';
part 'verify_api_key_response.g.dart';

@freezed
abstract class ApiKeyVerifyError with _$ApiKeyVerifyError {
  const factory ApiKeyVerifyError({
    required String message,
    required String code,
  }) = _ApiKeyVerifyError;

  factory ApiKeyVerifyError.fromJson(Map<String, dynamic> json) =>
      _$ApiKeyVerifyErrorFromJson(json);
}

@freezed
abstract class VerifyApiKeyResponse with _$VerifyApiKeyResponse {
  const factory VerifyApiKeyResponse({
    required bool valid,
    ApiKeyVerifyError? error,
    ApiKeyModel? key,
  }) = _VerifyApiKeyResponse;

  factory VerifyApiKeyResponse.fromJson(Map<String, dynamic> json) =>
      _$VerifyApiKeyResponseFromJson(json);
}
