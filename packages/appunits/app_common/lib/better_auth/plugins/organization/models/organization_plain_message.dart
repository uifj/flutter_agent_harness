import 'package:freezed_annotation/freezed_annotation.dart';

part 'organization_plain_message.freezed.dart';
part 'organization_plain_message.g.dart';

@freezed
abstract class OrganizationPlainMessage with _$OrganizationPlainMessage {
  const factory OrganizationPlainMessage({required String message}) =
      _OrganizationPlainMessage;

  factory OrganizationPlainMessage.fromJson(Map<String, dynamic> json) =>
      _$OrganizationPlainMessageFromJson(json);
}
