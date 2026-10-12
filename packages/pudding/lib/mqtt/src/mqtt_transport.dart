import 'dart:convert';

/// Delivery guarantee for an MQTT message, decoupled from `mqtt_client`'s own
/// enum so callers and tests never import the transport library.
enum MqttQosLevel {
  /// Fire-and-forget (QoS 0).
  atMostOnce,

  /// Delivered at least once (QoS 1).
  atLeastOnce,

  /// Delivered exactly once (QoS 2).
  exactlyOnce,
}

/// Lifecycle of the underlying transport, normalized across `mqtt_client`'s
/// connect/auto-reconnect callbacks into a single stream.
enum MqttTransportState {
  /// Not connected yet and never started.
  idle,

  /// A connect attempt is in flight.
  connecting,

  /// Connected to the broker.
  connected,

  /// Cleanly disconnected (user-initiated or ticket-expiry reconnect).
  disconnected,

  /// `mqtt_client` is auto-reconnecting with the same ticket.
  reconnecting,

  /// A connect/reconnect attempt failed hard.
  failed,
}

/// A message received from the broker on a subscribed topic.
class MqttIncomingMessage {
  /// Creates an incoming message.
  const MqttIncomingMessage({
    required this.topic,
    required this.payload,
    required this.qos,
  });

  /// The topic the message arrived on.
  final String topic;

  /// Raw payload bytes.
  final List<int> payload;

  /// The delivery guarantee the message arrived with.
  final MqttQosLevel qos;

  /// The payload decoded as UTF-8 (best-effort; malformed bytes are replaced).
  String get payloadAsString => utf8.decode(payload, allowMalformed: true);

  @override
  String toString() =>
      'MqttIncomingMessage(topic: $topic, qos: ${qos.name}, bytes: ${payload.length})';
}

/// Everything needed to open one broker connection from a ticket + client id.
///
/// [username] and [password] are secrets sourced from an [MqttTicket]; they are
/// passed straight to the broker and are never emitted to logs/Sentry by this
/// module.
class MqttConnectRequest {
  /// Creates a connect request.
  const MqttConnectRequest({
    required this.endpoint,
    required this.port,
    required this.clientId,
    required this.username,
    required this.password,
    this.keepAlive = const Duration(seconds: 30),
    this.useWebSocket = false,
    this.useTls = false,
    this.cleanSession = true,
    this.autoReconnect = true,
    this.protocolV311 = true,
  });

  /// Broker host (from the ticket `MqttEndpoint` / `MqttVPCEndpoint`).
  final String endpoint;

  /// Broker port (1883 / 8883 TCP, 80 / 443 or broker-specific WebSocket).
  final int port;

  /// Composed MQTT client identifier (Aliyun form: `<groupId>@@@<deviceId>`).
  final String clientId;

  /// Ticket username (secret + often PII).
  final String username;

  /// Ticket password (secret).
  final String password;

  /// Keep-alive interval.
  final Duration keepAlive;

  /// Connect over WebSocket instead of raw TCP.
  final bool useWebSocket;

  /// Use TLS. For TCP this sets the secure socket; ignored for WebSocket, which
  /// derives wss from [port]/broker configuration.
  final bool useTls;

  /// Start a clean session (drop prior subscriptions server-side).
  final bool cleanSession;

  /// Let the transport auto-reconnect on transient drops.
  final bool autoReconnect;

  /// Speak MQTT 3.1.1 rather than 3.1.
  final bool protocolV311;

  @override
  String toString() =>
      'MqttConnectRequest(endpoint: $endpoint:$port, clientId: $clientId, '
      'ws: $useWebSocket, tls: $useTls, clean: $cleanSession)';
}

/// Raised when the transport cannot establish or maintain a connection.
class MqttTransportException implements Exception {
  /// Creates a transport exception. [message] must not contain credentials.
  const MqttTransportException(this.message, {this.returnCode});

  /// Why the transport failed.
  final String message;

  /// The broker's connect return code, when available (as its enum name).
  final String? returnCode;

  @override
  String toString() =>
      'MqttTransportException: $message'
      '${returnCode == null ? '' : ' (returnCode: $returnCode)'}';
}

/// The transport seam: the only place `mqtt_client` is touched, and the seam a
/// test pushes on instead of a live broker (see `test/mqtt/fake_transport.dart`).
///
/// Implementations must be single-use per connect; [dispose] releases resources.
abstract class MqttTransport {
  /// Messages arriving on subscribed topics.
  Stream<MqttIncomingMessage> get messages;

  /// Normalized connection lifecycle events.
  Stream<MqttTransportState> get states;

  /// Whether a connection is currently up.
  bool get isConnected;

  /// Opens the connection described by [request], completing once the broker
  /// acknowledges, or throwing [MqttTransportException] on failure.
  Future<void> connect(MqttConnectRequest request);

  /// Subscribes to [topic] at [qos]. No-op if not connected.
  void subscribe(String topic, MqttQosLevel qos);

  /// Unsubscribes from [topic].
  void unsubscribe(String topic);

  /// Publishes [payload] to [topic]. No-op if not connected.
  void publish(
    String topic,
    MqttQosLevel qos,
    List<int> payload, {
    bool retain,
  });

  /// Disconnects from the broker.
  void disconnect();

  /// Releases the transport and closes its streams. Idempotent.
  Future<void> dispose();
}
