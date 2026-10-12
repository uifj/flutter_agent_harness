// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'two_factor_backup_codes_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TwoFactorBackupCodesResponse _$TwoFactorBackupCodesResponseFromJson(
  Map<String, dynamic> json,
) => _TwoFactorBackupCodesResponse(
  status: json['status'] as bool,
  backupCodes: (json['backupCodes'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$TwoFactorBackupCodesResponseToJson(
  _TwoFactorBackupCodesResponse instance,
) => <String, dynamic>{
  'status': instance.status,
  'backupCodes': instance.backupCodes,
};
