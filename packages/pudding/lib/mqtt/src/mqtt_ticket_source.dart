import 'mqtt_ticket.dart';

/// Raised when a fetched ticket is unusable — missing endpoint/credentials, or
/// already expired on arrival.
class MqttTicketException implements Exception {
  /// Creates an exception with a human-readable [message].
  const MqttTicketException(this.message, {this.requestId});

  /// Why the ticket could not be used. Never includes credentials.
  final String message;

  /// The gateway `RequestId`, when known, for correlating with a server log.
  final String? requestId;

  @override
  String toString() =>
      'MqttTicketException: $message${requestId == null ? '' : ' (requestId: $requestId)'}';
}

/// Supplies MQTT connection tickets to [PuddingMqttClient].
///
/// This is the seam between the transport wrapper and the actual
/// `GetMqttTicket` call. Fetching a ticket requires the product's POP gateway
/// signing (AK/SK, `Action=GetMqttTicket`, `Version=2022-02-10`, ...) which is
/// owned by the app layer, not by `pudding`. Implement [fetchTicket] with the
/// app's HTTP client and hand the parsed [MqttTicket] back here.
///
/// Keeping it an interface also means "testing the connect flow" does not
/// require network — see `test/mqtt/` fakes.
abstract class MqttTicketSource {
  /// Fetches a fresh ticket.
  ///
  /// Must throw [MqttTicketException] (or any exception) on failure; the client
  /// surfaces it and reports to Sentry. Implementations should return a ticket
  /// that is not already expired.
  Future<MqttTicket> fetchTicket();
}

/// An [MqttTicketSource] backed by a plain async callback.
///
/// Useful for app wiring (`CallbackMqttTicketSource(fetch: myApi.getMqttTicket)`)
/// and for tests (`CallbackMqttTicketSource(fetch: () async => fakeTicket)`).
class CallbackMqttTicketSource implements MqttTicketSource {
  /// Creates a source that delegates to [fetch].
  const CallbackMqttTicketSource({required this.fetch});

  /// The ticket producer.
  final Future<MqttTicket> Function() fetch;

  @override
  Future<MqttTicket> fetchTicket() => fetch();
}
