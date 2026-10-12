import 'package:freezed_annotation/freezed_annotation.dart';

import 'organization_member.dart';

part 'wrapped_organization_member_response.freezed.dart';
part 'wrapped_organization_member_response.g.dart';

@freezed
abstract class WrappedOrganizationMemberResponse
    with _$WrappedOrganizationMemberResponse {
  const factory WrappedOrganizationMemberResponse({
    required OrganizationMember member,
  }) = _WrappedOrganizationMemberResponse;

  factory WrappedOrganizationMemberResponse.fromJson(
    Map<String, dynamic> json,
  ) => _$WrappedOrganizationMemberResponseFromJson(json);
}
