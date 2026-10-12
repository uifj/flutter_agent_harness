import 'package:freezed_annotation/freezed_annotation.dart';

import 'organization_role_record.dart';

part 'organization_create_role_response.freezed.dart';
part 'organization_create_role_response.g.dart';

@freezed
abstract class OrganizationCreateRoleResponse
    with _$OrganizationCreateRoleResponse {
  const factory OrganizationCreateRoleResponse({
    required bool success,
    required OrganizationRoleRecord roleData,
    Object? statements,
  }) = _OrganizationCreateRoleResponse;

  factory OrganizationCreateRoleResponse.fromJson(Map<String, dynamic> json) =>
      _$OrganizationCreateRoleResponseFromJson(json);
}
