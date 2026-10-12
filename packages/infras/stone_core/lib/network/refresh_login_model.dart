/// Model for refreshing login tokens when they expire.
///
/// Holds the parameters needed to automatically refresh
/// authentication tokens via the KeepAlive mechanism.
class RefreshLoginModel {
  /// KeepAlive token for auto-refresh authentication.
  String? keepAliveToken;

  /// Office site / company ID.
  String? officeSiteId;

  /// Identity provider ID.
  String? idpId;

  /// Whether this is an ApsaraStack (proprietary cloud) deployment.
  bool apsara;

  /// Base parameters from the endpoint configuration.
  Map<String, dynamic> baseParams;

  /// Mobile-specific brand field.
  String? brand;

  /// Mobile-specific model field.
  String? model;

  /// Tracing span ID for distributed tracing.
  String? traceId;

  /// Tracing ID for distributed tracing.
  String? spanId;

  RefreshLoginModel({
    this.keepAliveToken,
    this.officeSiteId,
    this.idpId,
    this.apsara = false,
    this.baseParams = const {},
    this.brand,
    this.model,
    this.traceId,
    this.spanId,
  });
}
