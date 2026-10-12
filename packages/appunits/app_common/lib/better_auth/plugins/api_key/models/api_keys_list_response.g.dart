// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_keys_list_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApiKeysListResponse _$ApiKeysListResponseFromJson(Map<String, dynamic> json) =>
    _ApiKeysListResponse(
      apiKeys: (json['apiKeys'] as List<dynamic>)
          .map((e) => ApiKeyModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (json['total'] as num).toInt(),
      limit: (json['limit'] as num?)?.toInt(),
      offset: (json['offset'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ApiKeysListResponseToJson(
  _ApiKeysListResponse instance,
) => <String, dynamic>{
  'apiKeys': instance.apiKeys.map((e) => e.toJson()).toList(),
  'total': instance.total,
  'limit': instance.limit,
  'offset': instance.offset,
};
