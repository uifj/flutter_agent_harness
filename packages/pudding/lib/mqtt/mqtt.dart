/// First-party MQTT client wrapper for `pudding`.
///
/// Wraps an Alibaba-Cloud-style ticket-auth connect flow (`GetMqttTicket`) on
/// top of `package:mqtt_client`, and exposes a Sentry seam for observability.
///
/// - [PuddingMqttClient] — fetch ticket → connect → subscribe → publish → renew.
/// - [MqttTicket] — parsed ticket (endpoints, credentials, topics, expiry).
/// - [MqttTicketSource] — the seam that supplies tickets from your API layer.
/// - [MqttTransport] — the seam over `mqtt_client` (fake it in tests).
/// - [SentryMqttIntegration] / [SentryMqttObserver] — Sentry telemetry.
library;

export 'src/mqtt_client_observer.dart';
export 'src/mqtt_client_transport.dart';
export 'src/mqtt_config.dart';
export 'src/mqtt_ticket.dart';
export 'src/mqtt_ticket_source.dart';
export 'src/mqtt_transport.dart';
export 'src/pudding_mqtt_client.dart';
export 'src/sentry_mqtt.dart';
