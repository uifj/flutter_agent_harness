import 'mqtt_ticket.dart';
import 'mqtt_transport.dart';

/// Builds the MQTT client identifier from a ticket's group id and a stable
/// device id.
///
/// Alibaba-Cloud MQTT requires the connect `clientId` to be
/// `<MqttGroupId>@@<deviceId>` (two-`@`) for ordinary clients, and
/// `<MqttGroupId>@@@<deviceId>` (three-`@`) to enable shared/queue semantics.
/// This uses the three-`@` form, matching the Wuying/appstreaming clients that
/// consume `GetMqttTicket`. Supply [rawClientId] to bypass composition entirely.
class MqttClientIdentity {
  /// Creates an identity from a [deviceId], or a [rawClientId] used verbatim.
  const MqttClientIdentity({this.deviceId, this.rawClientId})
    : assert(
        deviceId != null || rawClientId != null,
        'Provide a deviceId or a rawClientId.',
      );

  /// Stable per-installation device id (the ticket's `Uuid` is a good source).
  final String? deviceId;

  /// A fully-formed clientId that skips group composition when non-null.
  final String? rawClientId;

  /// Resolves the clientId for [ticket].
  ///
  /// Throws [StateError] if neither [rawClientId] nor [deviceId] is available.
  String resolve(MqttTicket ticket) {
    final raw = rawClientId;
    if (raw != null) return raw;
    final device = deviceId;
    if (device == null) {
      throw StateError(
        'MqttClientIdentity needs a rawClientId or a deviceId to build the '
        'Aliyun <groupId>@@@<deviceId> client id.',
      );
    }
    return '${ticket.groupId}@@@$device';
  }
}

/// Static configuration for a [PuddingMqttClient]: how to reach the broker and
/// at what QoS to move the ticket's topics.
class MqttClientConfig {
  /// Creates a config.
  const MqttClientConfig({
    required this.identity,
    this.port = 1883,
    this.vpcPort,
    this.keepAlive = const Duration(seconds: 30),
    this.useWebSocket = false,
    this.useTls = false,
    this.preferVpcEndpoint = false,
    this.cleanSession = true,
    this.autoReconnect = true,
    this.protocolV311 = true,
    this.publishQos = MqttQosLevel.atLeastOnce,
    this.subscribeQos = MqttQosLevel.atLeastOnce,
    this.topicOverrides = const <String, MqttQosLevel>{},
  });

  /// How the connect `clientId` is composed.
  final MqttClientIdentity identity;

  /// Broker port for the public endpoint.
  final int port;

  /// Broker port when [preferVpcEndpoint] selects the VPC endpoint; defaults to
  /// [port] when unset.
  final int? vpcPort;

  /// Keep-alive interval handed to the transport.
  final Duration keepAlive;

  /// Connect over WebSocket.
  final bool useWebSocket;

  /// Use TLS.
  final bool useTls;

  /// Prefer the ticket's VPC endpoint when present (in-cloud deployments).
  final bool preferVpcEndpoint;

  /// Start a clean session.
  final bool cleanSession;

  /// Let the transport auto-reconnect on transient drops.
  final bool autoReconnect;

  /// Speak MQTT 3.1.1.
  final bool protocolV311;

  /// QoS for publishing to the ticket's `pub` topic.
  final MqttQosLevel publishQos;

  /// Default QoS for subscribing the ticket's `sub-*` topics.
  final MqttQosLevel subscribeQos;

  /// Per-topic QoS overrides, keyed by exact topic name.
  final Map<String, MqttQosLevel> topicOverrides;

  /// Builds the transport connect request from a [ticket].
  MqttConnectRequest connectRequestFor(MqttTicket ticket) {
    final useVpc =
        preferVpcEndpoint && (ticket.vpcEndpoint?.isNotEmpty ?? false);
    final endpoint = useVpc ? ticket.vpcEndpoint! : ticket.endpoint;
    return MqttConnectRequest(
      endpoint: endpoint,
      port: useVpc ? (vpcPort ?? port) : port,
      clientId: identity.resolve(ticket),
      username: ticket.username,
      password: ticket.password,
      keepAlive: keepAlive,
      useWebSocket: useWebSocket,
      useTls: useTls,
      cleanSession: cleanSession,
      autoReconnect: autoReconnect,
      protocolV311: protocolV311,
    );
  }

  /// The QoS to subscribe [topic] at, honoring [topicOverrides].
  MqttQosLevel qosForTopic(MqttTicketTopic topic) =>
      topicOverrides[topic.topic] ?? subscribeQos;
}
