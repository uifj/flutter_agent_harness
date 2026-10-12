import 'package:freezed_annotation/freezed_annotation.dart';

import 'organization_role_record.dart';

part 'organization_update_role_response.freezed.dart';
part 'organization_update_role_response.g.dart';

@freezed
abstract class OrganizationUpdateRoleResponse
    with _$OrganizationUpdateRoleResponse {
  const factory OrganizationUpdateRoleResponse({
    required bool success,
    required OrganizationRoleRecord roleData,
  }) = _OrganizationUpdateRoleResponse;

  factory OrganizationUpdateRoleResponse.fromJson(Map<String, dynamic> json) =>
      _$OrganizationUpdateRoleResponseFromJson(json);
}
