import 'package:freezed_annotation/freezed_annotation.dart';

part 'organization_role_record.freezed.dart';
part 'organization_role_record.g.dart';

/// Dynamic access-control role stored for an organization (`organizationRole`).
@freezed
abstract class OrganizationRoleRecord with _$OrganizationRoleRecord {
  const factory OrganizationRoleRecord({
    required String id,
    required String organizationId,
    required String role,
    required Map<String, dynamic> permission,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _OrganizationRoleRecord;

  factory OrganizationRoleRecord.fromJson(Map<String, dynamic> json) =>
      _$OrganizationRoleRecordFromJson(json);
}
