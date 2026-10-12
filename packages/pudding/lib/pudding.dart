/// Business-ecosystem Sentry integrations for the PlanStar package layer.
///
/// Three faithful vendored copies of upstream `sentry-dart` 9.30.1 integrations,
/// one per ecosystem, each importable on its own:
/// - `grpc/grpc.dart` — `SentryGrpcInterceptor` (gRPC client tracing).
/// - `link/link.dart` — `SentryLink` & friends (GraphQL / gql errors + tracing).
/// - `remote_config/remote_config.dart` — Firebase Remote Config feature flags.
///
/// Dependency route (ADR-0083):
/// `sentry → stone_core → pudding → appunits → lib` (never reversed).
library;

export 'grpc/grpc.dart';
export 'link/link.dart';
export 'remote_config/remote_config.dart';
