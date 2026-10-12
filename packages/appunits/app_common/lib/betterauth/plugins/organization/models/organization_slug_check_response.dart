import 'package:freezed_annotation/freezed_annotation.dart';

part 'organization_slug_check_response.freezed.dart';
part 'organization_slug_check_response.g.dart';

@freezed
abstract class OrganizationSlugCheckResponse
    with _$OrganizationSlugCheckResponse {
  const factory OrganizationSlugCheckResponse({required bool status}) =
      _OrganizationSlugCheckResponse;

  factory OrganizationSlugCheckResponse.fromJson(Map<String, dynamic> json) =>
      _$OrganizationSlugCheckResponseFromJson(json);
}
