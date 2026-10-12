// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invitation_with_member_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_InvitationWithMemberResponse _$InvitationWithMemberResponseFromJson(
  Map<String, dynamic> json,
) => _InvitationWithMemberResponse(
  invitation: OrganizationInvitation.fromJson(
    json['invitation'] as Map<String, dynamic>,
  ),
  member: json['member'] == null
      ? null
      : OrganizationMember.fromJson(json['member'] as Map<String, dynamic>),
);

Map<String, dynamic> _$InvitationWithMemberResponseToJson(
  _InvitationWithMemberResponse instance,
) => <String, dynamic>{
  'invitation': instance.invitation.toJson(),
  'member': instance.member?.toJson(),
};
