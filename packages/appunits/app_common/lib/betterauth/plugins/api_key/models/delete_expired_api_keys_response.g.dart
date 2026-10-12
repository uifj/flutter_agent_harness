// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_expired_api_keys_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_DeleteExpiredApiKeysResponse _$DeleteExpiredApiKeysResponseFromJson(
  Map<String, dynamic> json,
) => _DeleteExpiredApiKeysResponse(
  success: json['success'] as bool,
  error: json['error'],
);

Map<String, dynamic> _$DeleteExpiredApiKeysResponseToJson(
  _DeleteExpiredApiKeysResponse instance,
) => <String, dynamic>{'success': instance.success, 'error': instance.error};
