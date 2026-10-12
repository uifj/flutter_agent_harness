import 'package:freezed_annotation/freezed_annotation.dart';

part 'organization_team.freezed.dart';
part 'organization_team.g.dart';

@freezed
abstract class OrganizationTeam with _$OrganizationTeam {
  const factory OrganizationTeam({
    required String id,
    required String name,
    required String organizationId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _OrganizationTeam;

  factory OrganizationTeam.fromJson(Map<String, dynamic> json) =>
      _$OrganizationTeamFromJson(json);
}
