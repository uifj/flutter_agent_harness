// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_update_role_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OrganizationUpdateRoleResponse _$OrganizationUpdateRoleResponseFromJson(
  Map<String, dynamic> json,
) => _OrganizationUpdateRoleResponse(
  success: json['success'] as bool,
  roleData: OrganizationRoleRecord.fromJson(
    json['roleData'] as Map<String, dynamic>,
  ),
);

Map<String, dynamic> _$OrganizationUpdateRoleResponseToJson(
  _OrganizationUpdateRoleResponse instance,
) => <String, dynamic>{
  'success': instance.success,
  'roleData': instance.roleData.toJson(),
};
