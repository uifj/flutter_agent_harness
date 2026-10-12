import 'package:freezed_annotation/freezed_annotation.dart';

part 'organization_team_member.freezed.dart';
part 'organization_team_member.g.dart';

@freezed
abstract class OrganizationTeamMember with _$OrganizationTeamMember {
  const factory OrganizationTeamMember({
    required String id,
    required String teamId,
    required String userId,
    DateTime? createdAt,
  }) = _OrganizationTeamMember;

  factory OrganizationTeamMember.fromJson(Map<String, dynamic> json) =>
      _$OrganizationTeamMemberFromJson(json);
}
