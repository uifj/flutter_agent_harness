import 'package:freezed_annotation/freezed_annotation.dart';

import 'organization_invitation.dart';
import 'organization_member.dart';
import 'organization_team.dart';

part 'organization_payload.freezed.dart';
part 'organization_payload.g.dart';

/// Organization row plus optional related data (create, get-full, set-active, etc.).
@freezed
abstract class OrganizationPayload with _$OrganizationPayload {
  const factory OrganizationPayload({
    required String id,
    required String name,
    required String slug,
    String? logo,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
    List<OrganizationMember>? members,
    List<OrganizationInvitation>? invitations,
    List<OrganizationTeam>? teams,
  }) = _OrganizationPayload;

  factory OrganizationPayload.fromJson(Map<String, dynamic> json) =>
      _$OrganizationPayloadFromJson(json);
}
