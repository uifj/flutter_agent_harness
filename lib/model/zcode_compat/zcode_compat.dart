/// ZCode-compatible frontend parameters (ADR-0045): endpoints, headers,
/// account/quota shapes and the device identity, byte-aligned with the ZCode
/// desktop client so the self-built backend implements one contract. Pure
/// Dart; no IO, no network — the transport is a later batch.
library;

export 'device_mid.dart' show generateDeviceMid, isValidDeviceMid;
export 'zcode_account.dart';
export 'auth_flow.dart';
export 'zcode_endpoints.dart' show ZcodeEndpoints, zcodeSourceHeaders;
