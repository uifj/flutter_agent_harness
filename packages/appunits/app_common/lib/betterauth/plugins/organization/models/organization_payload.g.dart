// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_payload.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OrganizationPayload _$OrganizationPayloadFromJson(Map<String, dynamic> json) =>
    _OrganizationPayload(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      logo: json['logo'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
      members: (json['members'] as List<dynamic>?)
          ?.map((e) => OrganizationMember.fromJson(e as Map<String, dynamic>))
          .toList(),
      invitations: (json['invitations'] as List<dynamic>?)
          ?.map(
            (e) => OrganizationInvitation.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      teams: (json['teams'] as List<dynamic>?)
          ?.map((e) => OrganizationTeam.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OrganizationPayloadToJson(
  _OrganizationPayload instance,
) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'slug': instance.slug,
  'logo': instance.logo,
  'createdAt': instance.createdAt?.toIso8601String(),
  'updatedAt': instance.updatedAt?.toIso8601String(),
  'metadata': instance.metadata,
  'members': instance.members?.map((e) => e.toJson()).toList(),
  'invitations': instance.invitations?.map((e) => e.toJson()).toList(),
  'teams': instance.teams?.map((e) => e.toJson()).toList(),
};
