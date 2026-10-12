/// The SDK version reported to Sentry.io in the submitted events.
///
/// Mirrors the vendored `sentry` baseline this package is pinned against
/// (ADR-0083), so MQTT events carry the same version string as the other
/// integrations in `pudding`.
const String sdkVersion = '9.30.1';

/// The package name reported to Sentry.io in the submitted events.
const String packageName = 'pub:pudding_mqtt';
