import 'package:flutter_better_auth/core/models/user/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'organization_member.freezed.dart';
part 'organization_member.g.dart';

@freezed
abstract class OrganizationMember with _$OrganizationMember {
  const factory OrganizationMember({
    required String id,
    required String organizationId,
    required String userId,
    required String role,
    DateTime? createdAt,
    User? user,
  }) = _OrganizationMember;

  factory OrganizationMember.fromJson(Map<String, dynamic> json) =>
      _$OrganizationMemberFromJson(json);
}
