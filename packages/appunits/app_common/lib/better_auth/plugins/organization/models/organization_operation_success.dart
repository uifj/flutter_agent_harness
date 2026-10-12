import 'package:freezed_annotation/freezed_annotation.dart';

part 'organization_operation_success.freezed.dart';
part 'organization_operation_success.g.dart';

@freezed
abstract class OrganizationOperationSuccess
    with _$OrganizationOperationSuccess {
  const factory OrganizationOperationSuccess({required bool success}) =
      _OrganizationOperationSuccess;

  factory OrganizationOperationSuccess.fromJson(Map<String, dynamic> json) =>
      _$OrganizationOperationSuccessFromJson(json);
}
