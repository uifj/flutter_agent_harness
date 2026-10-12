/// Business-ecosystem Sentry integrations for the PlanStar package layer.
///
/// Faithful vendored copies of upstream `sentry-dart` 9.30.1 integrations,
/// plus a first-party module, each importable on its own:
/// - `grpc/grpc.dart` — `SentryGrpcInterceptor` (gRPC client tracing).
/// - `link/link.dart` — `SentryLink` & friends (GraphQL / gql errors + tracing).
/// - `remote_config/remote_config.dart` — Firebase Remote Config feature flags.
/// - `mqtt/mqtt.dart` — first-party MQTT client wrapper over a ticket-auth
///   (`GetMqttTicket`) connect flow, with `SentryMqttIntegration` observability.
///
/// Dependency route (ADR-0083):
/// `sentry → stone_core → pudding → appunits → lib` (never reversed).
library;

export 'grpc/grpc.dart';
export 'link/link.dart';
export 'mqtt/mqtt.dart';
export 'remote_config/remote_config.dart';
