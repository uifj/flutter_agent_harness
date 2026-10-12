// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_role_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OrganizationRoleRecord _$OrganizationRoleRecordFromJson(
  Map<String, dynamic> json,
) => _OrganizationRoleRecord(
  id: json['id'] as String,
  organizationId: json['organizationId'] as String,
  role: json['role'] as String,
  permission: json['permission'] as Map<String, dynamic>,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  updatedAt: json['updatedAt'] == null
      ? null
      : DateTime.parse(json['updatedAt'] as String),
);

Map<String, dynamic> _$OrganizationRoleRecordToJson(
  _OrganizationRoleRecord instance,
) => <String, dynamic>{
  'id': instance.id,
  'organizationId': instance.organizationId,
  'role': instance.role,
  'permission': instance.permission,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
};
