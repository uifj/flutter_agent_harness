import 'package:freezed_annotation/freezed_annotation.dart';

part 'one_time_token_generate_response.freezed.dart';
part 'one_time_token_generate_response.g.dart';

@freezed
abstract class OneTimeTokenGenerateResponse
    with _$OneTimeTokenGenerateResponse {
  const factory OneTimeTokenGenerateResponse({required String token}) =
      _OneTimeTokenGenerateResponse;

  factory OneTimeTokenGenerateResponse.fromJson(Map<String, dynamic> json) =>
      _$OneTimeTokenGenerateResponseFromJson(json);
}
