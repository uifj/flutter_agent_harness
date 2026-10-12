import 'package:freezed_annotation/freezed_annotation.dart';

part 'two_factor_totp_uri_response.freezed.dart';
part 'two_factor_totp_uri_response.g.dart';

@freezed
abstract class TwoFactorTotpUriResponse with _$TwoFactorTotpUriResponse {
  const factory TwoFactorTotpUriResponse({
    required String totpURI,
  }) = _TwoFactorTotpUriResponse;

  factory TwoFactorTotpUriResponse.fromJson(Map<String, dynamic> json) =>
      _$TwoFactorTotpUriResponseFromJson(json);
}
