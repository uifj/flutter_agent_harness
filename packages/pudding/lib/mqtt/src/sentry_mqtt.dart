// ignore_for_file: invalid_use_of_internal_member, implementation_imports

import 'dart:async';

import 'package:sentry/sentry.dart';
import 'package:sentry/src/tracing/instrumentation/instrumentation.dart';

import 'internal_logger.dart';
import 'mqtt_client_observer.dart';
import 'mqtt_transport.dart';
import 'version.dart';

/// Sentry integration that tags events as produced by the MQTT module.
///
/// Add it to `SentryOptions.integrations` so the SDK reports the integration
/// and package, then construct the client with a [SentryMqttObserver] to emit
/// connect/publish spans and breadcrumbs:
///
/// ```dart
/// await Sentry.init((options) {
///   options.addIntegration(SentryMqttIntegration());
/// });
/// final client = PuddingMqttClient(
///   config: config,
///   ticketSource: source,
///   observer: SentryMqttObserver(),
/// );
/// ```
class SentryMqttIntegration extends Integration<SentryOptions> {
  /// Integration name registered with the Sentry SDK.
  static const String integrationName = 'MqttClient';

  @override
  FutureOr<void> call(Hub hub, SentryOptions options) {
    options.sdk
      ..addIntegration(integrationName)
      ..addPackage(packageName, sdkVersion);
    internalLogger.debug('Registered $integrationName with Sentry.');
  }
}

/// [MqttClientObserver] that turns the client's lifecycle into Sentry telemetry.
///
/// - One child span per connect (`mqtt.connect`), tagged ok/error; failures are
///   additionally captured as exceptions when [captureConnectErrors] is on.
/// - Breadcrumbs for connect, subscribe, publish, disconnect, and state moves.
/// - [reportMessageTraffic] opts in to a lightweight breadcrumb per inbound
///   message (off by default — control channels can be chatty).
///
/// Credentials ([MqttConnectRequest.username] / [MqttConnectRequest.password])
/// are **never** attached. The ticket username is commonly PII and the password
/// is a secret; only endpoint, port, clientId, topic and QoS are reported.
class SentryMqttObserver implements MqttClientObserver {
  /// Creates an observer bound to [hub] (defaults to the global [HubAdapter]).
  SentryMqttObserver({
    Hub? hub,
    this.captureConnectErrors = true,
    this.reportMessageTraffic = false,
  }) : _hub = hub ?? HubAdapter() {
    _spanFactory = _hub.options.spanFactory;
  }

  /// Trace origin stamped on the connect span.
  static const String _connectOrigin = 'auto.mqtt.client';

  final Hub _hub;
  late final InstrumentationSpanFactory _spanFactory;

  /// Whether a failed connect is also captured as a Sentry exception.
  final bool captureConnectErrors;

  /// Whether each inbound message emits a breadcrumb.
  final bool reportMessageTraffic;

  InstrumentationSpan? _connectSpan;

  @override
  void onConnectAttempt(MqttConnectRequest request) {
    final parent = _spanFactory.getSpan(_hub);
    final span = parent == null
        ? null
        : _spanFactory.createSpan(
            parentSpan: parent,
            operation: 'mqtt.connect',
            description: '${request.endpoint}:${request.port}',
          );
    if (span != null) {
      span
        ..origin = _connectOrigin
        ..setData('server.address', request.endpoint)
        ..setData('server.port', request.port)
        ..setData('mqtt.client_id', request.clientId);
    }
    _connectSpan = span;
    unawaited(
      _hub.addBreadcrumb(
        Breadcrumb(
          type: 'mqtt',
          category: 'mqtt.connect',
          level: SentryLevel.info,
          data: <String, Object>{
            'endpoint': request.endpoint,
            'port': request.port,
            'client_id': request.clientId,
            'websocket': request.useWebSocket,
            'tls': request.useTls,
          },
        ),
      ),
    );
  }

  @override
  void onConnectSuccess(MqttConnectRequest request, Duration elapsed) {
    final span = _connectSpan;
    _connectSpan = null;
    if (span == null) return;
    span
      ..setData('mqtt.connect.duration_ms', elapsed.inMilliseconds)
      ..status = const SpanStatus.ok();
    unawaited(span.finish());
  }

  @override
  void onConnectFailure(
    MqttConnectRequest request,
    Object error,
    StackTrace stackTrace,
  ) {
    final span = _connectSpan;
    _connectSpan = null;
    if (span != null) {
      span
        ..throwable = error
        ..status = const SpanStatus.internalError();
      unawaited(span.finish());
    }
    if (!captureConnectErrors) return;
    unawaited(
      _hub.captureException(
        error,
        stackTrace: stackTrace,
        withScope: (scope) {
          scope.setContexts('mqtt', <String, Object>{
            'endpoint': request.endpoint,
            'port': request.port,
            'client_id': request.clientId,
            'phase': 'connect',
          });
        },
      ),
    );
  }

  @override
  void onSubscribed(String topic, MqttQosLevel qos) {
    unawaited(
      _breadcrumb('mqtt.subscribe', SentryLevel.info, <String, Object>{
        'topic': topic,
        'qos': qos.name,
      }),
    );
  }

  @override
  void onPublished(String topic, MqttQosLevel qos, int payloadBytes) {
    unawaited(
      _breadcrumb('mqtt.publish', SentryLevel.info, <String, Object>{
        'topic': topic,
        'qos': qos.name,
        'payload_bytes': payloadBytes,
      }),
    );
  }

  @override
  void onIncomingMessage(MqttIncomingMessage message) {
    if (!reportMessageTraffic) return;
    unawaited(
      _breadcrumb('mqtt.message', SentryLevel.debug, <String, Object>{
        'topic': message.topic,
        'payload_bytes': message.payload.length,
      }),
    );
  }

  @override
  void onStateChange(MqttTransportState state) {
    if (state != MqttTransportState.disconnected &&
        state != MqttTransportState.failed &&
        state != MqttTransportState.reconnecting) {
      return;
    }
    final level = state == MqttTransportState.failed
        ? SentryLevel.error
        : SentryLevel.info;
    unawaited(
      _breadcrumb('mqtt.state', level, <String, Object>{'state': state.name}),
    );
  }

  Future<void> _breadcrumb(
    String category,
    SentryLevel level,
    Map<String, Object> data,
  ) => _hub.addBreadcrumb(
    Breadcrumb(type: 'mqtt', category: category, level: level, data: data),
  );
}
