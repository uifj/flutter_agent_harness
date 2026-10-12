// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_create_role_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OrganizationCreateRoleResponse _$OrganizationCreateRoleResponseFromJson(
  Map<String, dynamic> json,
) => _OrganizationCreateRoleResponse(
  success: json['success'] as bool,
  roleData: OrganizationRoleRecord.fromJson(
    json['roleData'] as Map<String, dynamic>,
  ),
  statements: json['statements'],
);

Map<String, dynamic> _$OrganizationCreateRoleResponseToJson(
  _OrganizationCreateRoleResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'roleData': instance.roleData.toJson(),
  'statements': instance.statements,
};
