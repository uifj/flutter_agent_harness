import 'mqtt_transport.dart';

/// Lifecycle hooks a [PuddingMqttClient] calls as it moves a ticket-based
/// connection through its phases.
///
/// Kept free of Sentry (and of `mqtt_client`) so the client has one seam for
/// observability: production passes [SentryMqttObserver], tests pass a recorder
/// or [NoOpMqttClientObserver]. Implementations must be cheap and non-blocking;
/// every method is called synchronously on the client's isolate.
abstract class MqttClientObserver {
  /// A connect to the broker described by [request] has started.
  void onConnectAttempt(MqttConnectRequest request);

  /// The connect in flight succeeded after [elapsed].
  void onConnectSuccess(MqttConnectRequest request, Duration elapsed);

  /// The connect in flight failed with [error].
  void onConnectFailure(
    MqttConnectRequest request,
    Object error,
    StackTrace stackTrace,
  );

  /// A subscription to [topic] at [qos] was issued.
  void onSubscribed(String topic, MqttQosLevel qos);

  /// A payload of [payloadBytes] was published to [topic] at [qos].
  void onPublished(String topic, MqttQosLevel qos, int payloadBytes);

  /// A message arrived on a subscribed topic.
  void onIncomingMessage(MqttIncomingMessage message);

  /// The transport moved to [state].
  void onStateChange(MqttTransportState state);
}

/// An [MqttClientObserver] that does nothing — the client default.
class NoOpMqttClientObserver implements MqttClientObserver {
  /// Creates the shared no-op observer.
  const NoOpMqttClientObserver();

  @override
  void onConnectAttempt(MqttConnectRequest request) {}

  @override
  void onConnectSuccess(MqttConnectRequest request, Duration elapsed) {}

  @override
  void onConnectFailure(
    MqttConnectRequest request,
    Object error,
    StackTrace stackTrace,
  ) {}

  @override
  void onSubscribed(String topic, MqttQosLevel qos) {}

  @override
  void onPublished(String topic, MqttQosLevel qos, int payloadBytes) {}

  @override
  void onIncomingMessage(MqttIncomingMessage message) {}

  @override
  void onStateChange(MqttTransportState state) {}
}
