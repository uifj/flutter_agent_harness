import 'package:freezed_annotation/freezed_annotation.dart';

part 'two_factor_enable_response.freezed.dart';
part 'two_factor_enable_response.g.dart';

@freezed
abstract class TwoFactorEnableResponse with _$TwoFactorEnableResponse {
  const factory TwoFactorEnableResponse({
    required String totpURI,
    required List<String> backupCodes,
  }) = _TwoFactorEnableResponse;

  factory TwoFactorEnableResponse.fromJson(Map<String, dynamic> json) =>
      _$TwoFactorEnableResponseFromJson(json);
}
