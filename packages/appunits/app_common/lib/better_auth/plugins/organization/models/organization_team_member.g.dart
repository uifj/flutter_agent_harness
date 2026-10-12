// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_team_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OrganizationTeamMember _$OrganizationTeamMemberFromJson(
  Map<String, dynamic> json,
) => _OrganizationTeamMember(
  id: json['id'] as String,
  teamId: json['teamId'] as String,
  userId: json['userId'] as String,
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
);

Map<String, dynamic> _$OrganizationTeamMemberToJson(
  _OrganizationTeamMember instance,
) => <String, dynamic>{
  'id': instance.id,
  'teamId': instance.teamId,
  'userId': instance.userId,
  'createdAt': instance.createdAt?.toIso8601String(),
};
