// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wrapped_organization_member_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_WrappedOrganizationMemberResponse _$WrappedOrganizationMemberResponseFromJson(
  Map<String, dynamic> json,
) => _WrappedOrganizationMemberResponse(
  member: OrganizationMember.fromJson(json['member'] as Map<String, dynamic>),
);

Map<String, dynamic> _$WrappedOrganizationMemberResponseToJson(
  _WrappedOrganizationMemberResponse instance,
) => <String, dynamic>{'member': instance.member.toJson()};
