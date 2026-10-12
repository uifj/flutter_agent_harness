import 'package:freezed_annotation/freezed_annotation.dart';

import 'api_key_model.dart';

part 'api_keys_list_response.freezed.dart';
part 'api_keys_list_response.g.dart';

@freezed
abstract class ApiKeysListResponse with _$ApiKeysListResponse {
  const factory ApiKeysListResponse({
    required List<ApiKeyModel> apiKeys,
    required int total,
    int? limit,
    int? offset,
  }) = _ApiKeysListResponse;

  factory ApiKeysListResponse.fromJson(Map<String, dynamic> json) =>
      _$ApiKeysListResponseFromJson(json);
}
