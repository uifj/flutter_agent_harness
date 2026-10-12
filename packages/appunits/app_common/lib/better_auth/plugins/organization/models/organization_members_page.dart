import 'package:freezed_annotation/freezed_annotation.dart';

import 'organization_member.dart';

part 'organization_members_page.freezed.dart';
part 'organization_members_page.g.dart';

@freezed
abstract class OrganizationMembersPage with _$OrganizationMembersPage {
  const factory OrganizationMembersPage({
    required List<OrganizationMember> members,
    required int total,
  }) = _OrganizationMembersPage;

  factory OrganizationMembersPage.fromJson(Map<String, dynamic> json) =>
      _$OrganizationMembersPageFromJson(json);
}
