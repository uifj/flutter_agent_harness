import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_key_model.freezed.dart';
part 'api_key_model.g.dart';

/// API key record as returned by Better Auth (hashed `key` is omitted on most
/// endpoints). The plaintext secret is only present on [ApiKeyBetterAuth.create].
@freezed
abstract class ApiKeyModel with _$ApiKeyModel {
  const factory ApiKeyModel({
    required String id,
    @Default('default') String configId,
    String? name,
    String? start,
    String? prefix,
    /// Hashed value in storage; omitted from list/get responses. On create,
    /// the server overwrites this field with the **plaintext** secret once.
    String? key,
    required String referenceId,
    int? refillInterval,
    int? refillAmount,
    DateTime? lastRefillAt,
    @Default(true) bool enabled,
    @Default(true) bool rateLimitEnabled,
    int? rateLimitTimeWindow,
    int? rateLimitMax,
    @Default(0) int requestCount,
    int? remaining,
    DateTime? lastRequest,
    DateTime? expiresAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? permissions,
  }) = _ApiKeyModel;

  factory ApiKeyModel.fromJson(Map<String, dynamic> json) =>
      _$ApiKeyModelFromJson(json);
}
