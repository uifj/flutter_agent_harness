import 'dart:async';
import 'dart:convert';

import 'internal_logger.dart';
import 'mqtt_client_observer.dart';
import 'mqtt_client_transport.dart';
import 'mqtt_config.dart';
import 'mqtt_ticket.dart';
import 'mqtt_ticket_source.dart';
import 'mqtt_transport.dart';

/// A ticket-authenticated MQTT client: fetch a [MqttTicket] from an
/// [MqttTicketSource], open a broker connection with its credentials, subscribe
/// the granted `sub-*` topics, publish to the granted `pub` topic, and renew the
/// ticket before it expires.
///
/// It is deliberately transport-agnostic: [MqttTransport] is the seam a test
/// pushes on, and [MqttClientObserver] is the seam Sentry hooks into (see
/// [SentryMqttObserver]). Nothing here imports `mqtt_client` or Sentry.
///
/// ```dart
/// final client = PuddingMqttClient(
///   config: MqttClientConfig(identity: MqttClientIdentity(deviceId: uuid)),
///   ticketSource: CallbackMqttTicketSource(fetch: api.getMqttTicket),
///   observer: SentryMqttObserver(),
/// );
/// await client.connect();
/// client.messages.listen(handle);
/// client.publishString(jsonEncode(command)); // to the ticket's pub topic
/// // Later:
/// await client.dispose();
/// ```
class PuddingMqttClient {
  /// Creates a client.
  ///
  /// [transportFactory] makes a fresh transport per connection attempt; it
  /// defaults to [MqttClientTransport] and is overridden in tests to inject a
  /// fake. A new transport is required on every (re)connect because a
  /// `mqtt_client` instance is single-use once disposed.
  PuddingMqttClient({
    required this.config,
    required this.ticketSource,
    MqttClientObserver? observer,
    MqttTransport Function()? transportFactory,
  }) : _observer = observer ?? const NoOpMqttClientObserver(),
       _transportFactory = transportFactory ?? (() => MqttClientTransport());

  /// How to reach the broker and at what QoS to move topics.
  final MqttClientConfig config;

  /// Supplies connection tickets.
  final MqttTicketSource ticketSource;

  final MqttClientObserver _observer;
  final MqttTransport Function() _transportFactory;

  final StreamController<MqttIncomingMessage> _messages =
      StreamController<MqttIncomingMessage>.broadcast();
  final StreamController<MqttTransportState> _states =
      StreamController<MqttTransportState>.broadcast();

  MqttTransport? _transport;
  MqttTicket? _ticket;
  StreamSubscription<MqttIncomingMessage>? _messagesSub;
  StreamSubscription<MqttTransportState>? _statesSub;
  Timer? _refreshTimer;
  bool _connecting = false;
  bool _disposed = false;

  /// The last ticket this client connected with, if any.
  MqttTicket? get currentTicket => _ticket;

  /// Whether the underlying transport currently reports a live connection.
  bool get isConnected => _transport?.isConnected ?? false;

  /// Inbound messages from subscribed topics (broadcast; safe for many
  /// listeners; survives reconnects).
  Stream<MqttIncomingMessage> get messages => _messages.stream;

  /// Connection lifecycle events (broadcast).
  Stream<MqttTransportState> get states => _states.stream;

  /// Fetches a ticket, connects, and subscribes the ticket's read topics.
  ///
  /// Throws [MqttTicketException] on an unusable ticket, or
  /// [MqttTransportException] if the broker connection fails. Concurrent calls
  /// are collapsed to the first in-flight connect.
  Future<void> connect() async {
    _assertNotDisposed();
    if (_connecting) return;
    _connecting = true;
    MqttTransport? pending;
    try {
      final ticket = await ticketSource.fetchTicket();
      _validateTicket(ticket);
      final request = config.connectRequestFor(ticket);

      pending = _transportFactory();
      final stopwatch = Stopwatch()..start();
      _observer.onConnectAttempt(request);
      try {
        await pending.connect(request);
      } on Object catch (error, stackTrace) {
        _observer.onConnectFailure(request, error, stackTrace);
        await pending.dispose();
        rethrow;
      }

      await _detachCurrent();
      _transport = pending;
      pending = null;
      _ticket = ticket;
      _wireTransport(pending: _transport!);
      stopwatch.stop();
      _observer.onConnectSuccess(request, stopwatch.elapsed);

      _subscribeTopics(ticket);
      _scheduleRefresh(ticket);
    } finally {
      _connecting = false;
      await pending?.dispose();
    }
  }

  /// Publishes raw [bytes]. Targets the ticket's `pub` topic unless [topic] is
  /// given. Throws [StateError] if not connected or no publish topic resolves.
  void publishBytes(List<int> bytes, {String? topic, bool retain = false}) {
    final transport = _transport;
    if (transport == null || !transport.isConnected) {
      throw StateError('PuddingMqttClient is not connected.');
    }
    final target = topic ?? _ticket?.publishTopic?.topic;
    if (target == null) {
      throw StateError(
        'No publish topic: the ticket grants none and none was '
        'passed explicitly.',
      );
    }
    transport.publish(target, config.publishQos, bytes, retain: retain);
    _observer.onPublished(target, config.publishQos, bytes.length);
  }

  /// Publishes [text] UTF-8 encoded, to the same target as [publishBytes].
  void publishString(String text, {String? topic, bool retain = false}) =>
      publishBytes(utf8.encode(text), topic: topic, retain: retain);

  /// Unsubscribes from [topic] on the live connection.
  void unsubscribe(String topic) => _transport?.unsubscribe(topic);

  /// Gracefully disconnects, cancelling the ticket-refresh timer.
  Future<void> disconnect() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    await _detachCurrent();
    _emitState(MqttTransportState.disconnected);
  }

  /// Disconnects and releases all resources. Idempotent.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await _messages.close();
    await _states.close();
  }

  void _wireTransport({required MqttTransport pending}) {
    _messagesSub = pending.messages.listen((message) {
      _observer.onIncomingMessage(message);
      _emitMessage(message);
    });
    _statesSub = pending.states.listen(_onTransportState);
  }

  void _onTransportState(MqttTransportState state) {
    _observer.onStateChange(state);
    _emitState(state);
  }

  void _subscribeTopics(MqttTicket ticket) {
    final transport = _transport;
    if (transport == null) return;
    for (final topic in ticket.subscribeTopics) {
      final qos = config.qosForTopic(topic);
      transport.subscribe(topic.topic, qos);
      _observer.onSubscribed(topic.topic, qos);
    }
  }

  void _scheduleRefresh(MqttTicket ticket) {
    _refreshTimer?.cancel();
    final expiry = ticket.expiresAt;
    if (expiry == null) return;
    var delay = expiry.difference(DateTime.now()) - _refreshSkew;
    if (delay.isNegative) delay = Duration.zero;
    internalLogger.debug('Scheduling MQTT ticket refresh in $delay.');
    _refreshTimer = Timer(delay, () => unawaited(_renewTicket()));
  }

  Future<void> _renewTicket() async {
    if (_disposed) return;
    // Reconnect with a fresh ticket; the broker drops the old short-lived
    // credentials at expiry, so a renewal failure must surface to the observer.
    try {
      await connect();
    } on Object catch (error, stackTrace) {
      internalLogger.warning(
        'MQTT ticket renewal failed; connection left for caller to retry.',
        error: error,
        stackTrace: stackTrace,
      );
      _emitState(MqttTransportState.failed);
    }
  }

  void _validateTicket(MqttTicket ticket) {
    if (ticket.endpoint.isEmpty) {
      throw MqttTicketException(
        'Ticket has no MQTT endpoint.',
        requestId: ticket.requestId,
      );
    }
    if (ticket.username.isEmpty || ticket.password.isEmpty) {
      throw MqttTicketException(
        'Ticket is missing the MQTT username/password credentials.',
        requestId: ticket.requestId,
      );
    }
    if (ticket.isExpired(now: DateTime.now(), skew: Duration.zero)) {
      throw MqttTicketException(
        'Ticket is already expired.',
        requestId: ticket.requestId,
      );
    }
  }

  Future<void> _detachCurrent() async {
    await _messagesSub?.cancel();
    _messagesSub = null;
    await _statesSub?.cancel();
    _statesSub = null;
    final transport = _transport;
    _transport = null;
    await transport?.dispose();
  }

  void _emitMessage(MqttIncomingMessage message) {
    if (!_messages.isClosed) _messages.add(message);
  }

  void _emitState(MqttTransportState state) {
    if (!_states.isClosed) _states.add(state);
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('PuddingMqttClient has been disposed.');
    }
  }

  // Renew 30s ahead of expiry so an in-flight connect is not cut off.
  static const Duration _refreshSkew = Duration(seconds: 30);
}
