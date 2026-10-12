import 'package:freezed_annotation/freezed_annotation.dart';

import 'organization_invitation.dart';
import 'organization_member.dart';

part 'invitation_with_member_response.freezed.dart';
part 'invitation_with_member_response.g.dart';

@freezed
abstract class InvitationWithMemberResponse
    with _$InvitationWithMemberResponse {
  const factory InvitationWithMemberResponse({
    required OrganizationInvitation invitation,
    OrganizationMember? member,
  }) = _InvitationWithMemberResponse;

  factory InvitationWithMemberResponse.fromJson(Map<String, dynamic> json) =>
      _$InvitationWithMemberResponseFromJson(json);
}
