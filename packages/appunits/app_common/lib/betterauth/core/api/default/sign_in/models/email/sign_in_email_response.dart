import 'package:flutter_better_auth/core/models/user/user.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sign_in_email_response.freezed.dart';
part 'sign_in_email_response.g.dart';

@freezed
abstract class SignInEmailResponse with _$SignInEmailResponse {
  /// Email or username/password sign-in. When the user must complete second
  /// factor, [twoFactorRedirect] is true and [token]/[user] are absent until
  /// verification succeeds (use the Two-Factor plugin on the API client).
  const factory SignInEmailResponse({
    @Default(false) bool redirect,
    String? token,
    String? url,
    User? user,
    @Default(false) bool twoFactorRedirect,
    List<String>? twoFactorMethods,
  }) = _SignInEmailResponse;

  factory SignInEmailResponse.fromJson(Map<String, dynamic> json) =>
      _$SignInEmailResponseFromJson(json);
}
