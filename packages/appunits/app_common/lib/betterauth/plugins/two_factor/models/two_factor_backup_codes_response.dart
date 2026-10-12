import 'package:freezed_annotation/freezed_annotation.dart';

part 'two_factor_backup_codes_response.freezed.dart';
part 'two_factor_backup_codes_response.g.dart';

@freezed
abstract class TwoFactorBackupCodesResponse with _$TwoFactorBackupCodesResponse {
  const factory TwoFactorBackupCodesResponse({
    required bool status,
    List<String>? backupCodes,
  }) = _TwoFactorBackupCodesResponse;

  factory TwoFactorBackupCodesResponse.fromJson(Map<String, dynamic> json) =>
      _$TwoFactorBackupCodesResponseFromJson(json);
}
