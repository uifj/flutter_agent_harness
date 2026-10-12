// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_team.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OrganizationTeam _$OrganizationTeamFromJson(Map<String, dynamic> json) =>
    _OrganizationTeam(
      id: json['id'] as String,
      name: json['name'] as String,
      organizationId: json['organizationId'] as String,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$OrganizationTeamToJson(_OrganizationTeam instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'organizationId': instance.organizationId,
      'createdAt': instance.createdAt?.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
