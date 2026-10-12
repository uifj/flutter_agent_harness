// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'api_key_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ApiKeyModel _$ApiKeyModelFromJson(Map<String, dynamic> json) => _ApiKeyModel(
  id: json['id'] as String,
  configId: json['configId'] as String? ?? 'default',
  name: json['name'] as String?,
  start: json['start'] as String?,
  prefix: json['prefix'] as String?,
  key: json['key'] as String?,
  referenceId: json['referenceId'] as String,
  refillInterval: (json['refillInterval'] as num?)?.toInt(),
  refillAmount: (json['refillAmount'] as num?)?.toInt(),
  lastRefillAt: json['lastRefillAt'] == null
      ? null
      : DateTime.parse(json['lastRefillAt'] as String),
  enabled: json['enabled'] as bool? ?? true,
  rateLimitEnabled: json['rateLimitEnabled'] as bool? ?? true,
  rateLimitTimeWindow: (json['rateLimitTimeWindow'] as num?)?.toInt(),
  rateLimitMax: (json['rateLimitMax'] as num?)?.toInt(),
  requestCount: (json['requestCount'] as num?)?.toInt() ?? 0,
  remaining: (json['remaining'] as num?)?.toInt(),
  lastRequest: json['lastRequest'] == null
      ? null
      : DateTime.parse(json['lastRequest'] as String),
  expiresAt: json['expiresAt'] == null
      ? null
      : DateTime.parse(json['expiresAt'] as String),
  createdAt: DateTime.parse(json['createdAt'] as String),
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  metadata: json['metadata'] as Map<String, dynamic>?,
  permissions: json['permissions'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$ApiKeyModelToJson(_ApiKeyModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'configId': instance.configId,
      'name': instance.name,
      'start': instance.start,
      'prefix': instance.prefix,
      'key': instance.key,
      'referenceId': instance.referenceId,
      'refillInterval': instance.refillInterval,
      'refillAmount': instance.refillAmount,
      'lastRefillAt': instance.lastRefillAt?.toIso8601String(),
      'enabled': instance.enabled,
      'rateLimitEnabled': instance.rateLimitEnabled,
      'rateLimitTimeWindow': instance.rateLimitTimeWindow,
      'rateLimitMax': instance.rateLimitMax,
      'requestCount': instance.requestCount,
      'remaining': instance.remaining,
      'lastRequest': instance.lastRequest?.toIso8601String(),
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'metadata': instance.metadata,
      'permissions': instance.permissions,
    };
