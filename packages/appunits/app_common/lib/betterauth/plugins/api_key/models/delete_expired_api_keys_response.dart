import 'package:freezed_annotation/freezed_annotation.dart';

part 'delete_expired_api_keys_response.freezed.dart';
part 'delete_expired_api_keys_response.g.dart';

@freezed
abstract class DeleteExpiredApiKeysResponse with _$DeleteExpiredApiKeysResponse {
  const factory DeleteExpiredApiKeysResponse({
    required bool success,
    Object? error,
  }) = _DeleteExpiredApiKeysResponse;

  factory DeleteExpiredApiKeysResponse.fromJson(Map<String, dynamic> json) =>
      _$DeleteExpiredApiKeysResponseFromJson(json);
}
