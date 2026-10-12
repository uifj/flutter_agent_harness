import 'package:freezed_annotation/freezed_annotation.dart';

part 'organization_member_role_response.freezed.dart';
part 'organization_member_role_response.g.dart';

@freezed
abstract class OrganizationMemberRoleResponse
    with _$OrganizationMemberRoleResponse {
  const factory OrganizationMemberRoleResponse({required String role}) =
      _OrganizationMemberRoleResponse;

  factory OrganizationMemberRoleResponse.fromJson(Map<String, dynamic> json) =>
      _$OrganizationMemberRoleResponseFromJson(json);
}
