// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'two_factor_enable_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TwoFactorEnableResponse _$TwoFactorEnableResponseFromJson(
  Map<String, dynamic> json,
) => _TwoFactorEnableResponse(
  totpURI: json['totpURI'] as String,
  backupCodes: (json['backupCodes'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$TwoFactorEnableResponseToJson(
  _TwoFactorEnableResponse instance,
) => <String, dynamic>{
  'totpURI': instance.totpURI,
  'backupCodes': instance.backupCodes,
};
