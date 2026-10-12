// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organization_members_page.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_OrganizationMembersPage _$OrganizationMembersPageFromJson(
  Map<String, dynamic> json,
) => _OrganizationMembersPage(
  members: (json['members'] as List<dynamic>)
      .map((e) => OrganizationMember.fromJson(e as Map<String, dynamic>))
      .toList(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$OrganizationMembersPageToJson(
  _OrganizationMembersPage instance,
) => <String, dynamic>{
  'members': instance.members.map((e) => e.toJson()).toList(),
  'total': instance.total,
};
