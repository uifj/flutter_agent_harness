// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'verify_api_key_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApiKeyVerifyError _$ApiKeyVerifyErrorFromJson(Map<String, dynamic> json) =>
    _ApiKeyVerifyError(
      message: json['message'] as String,
      code: json['code'] as String,
    );

Map<String, dynamic> _$ApiKeyVerifyErrorToJson(_ApiKeyVerifyError instance) =>
    <String, dynamic>{'message': instance.message, 'code': instance.code};

_VerifyApiKeyResponse _$VerifyApiKeyResponseFromJson(
  Map<String, dynamic> json,
) => _VerifyApiKeyResponse(
  valid: json['valid'] as bool,
  error: json['error'] == null
      ? null
      : ApiKeyVerifyError.fromJson(json['error'] as Map<String, dynamic>),
  key: json['key'] == null
      ? null
      : ApiKeyModel.fromJson(json['key'] as Map<String, dynamic>),
);

Map<String, dynamic> _$VerifyApiKeyResponseToJson(
  _VerifyApiKeyResponse instance,
) => <String, dynamic>{
  'valid': instance.valid,
  'error': instance.error?.toJson(),
  'key': instance.key?.toJson(),
};
