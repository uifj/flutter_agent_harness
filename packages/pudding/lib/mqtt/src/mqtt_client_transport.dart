// Bridges the pure [MqttTransport] seam to `package:mqtt_client`.
//
// This is the only file in the module that imports `mqtt_client`; everything
// above it talks to [MqttTransport], so tests never need a live broker.
// ignore_for_file: implementation_imports

import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:mqtt_client/mqtt_server_client.dart' as mqtt;
import 'package:typed_data/typed_data.dart' as typed;

import 'internal_logger.dart';
import 'mqtt_transport.dart';

/// [MqttTransport] backed by `mqtt_client`'s [mqtt.MqttServerClient].
///
/// Supports ticket-sourced credentials ([MqttConnectRequest.username] /
/// [MqttConnectRequest.password]) over TCP or WebSocket, plain or TLS, and
/// normalizes `mqtt_client`'s callbacks into [states].
class MqttClientTransport implements MqttTransport {
  /// Creates a transport with an optional [maxConnectionAttempts] guard for the
  /// initial connect (the client's own auto-reconnect is governed by the
  /// [MqttConnectRequest.autoReconnect] flag, not this).
  MqttClientTransport({this.maxConnectionAttempts = 3});

  /// Max attempts the underlying client makes before failing the first connect.
  final int maxConnectionAttempts;

  mqtt.MqttServerClient? _client;
  final StreamController<MqttIncomingMessage> _messages =
      StreamController<MqttIncomingMessage>.broadcast();
  final StreamController<MqttTransportState> _states =
      StreamController<MqttTransportState>.broadcast();
  StreamSubscription<List<mqtt.MqttReceivedMessage<mqtt.MqttMessage>>>?
  _updatesSub;
  bool _disposed = false;

  @override
  Stream<MqttIncomingMessage> get messages => _messages.stream;

  @override
  Stream<MqttTransportState> get states => _states.stream;

  @override
  bool get isConnected =>
      _client?.connectionStatus?.state == mqtt.MqttConnectionState.connected;

  @override
  Future<void> connect(MqttConnectRequest request) async {
    _assertNotDisposed();
    _emit(MqttTransportState.connecting);

    final client = mqtt.MqttServerClient.withPort(
      request.endpoint,
      request.clientId,
      request.port,
      maxConnectionAttempts: maxConnectionAttempts,
    );
    _client = client;

    client
      ..logging(on: false)
      ..keepAlivePeriod = request.keepAlive.inSeconds
      ..autoReconnect = request.autoReconnect
      ..resubscribeOnAutoReconnect = true;
    if (request.protocolV311) client.setProtocolV311();
    if (request.useWebSocket) client.useWebSocket = true;
    if (request.useTls) client.secure = true;

    _wireCallbacks(client);

    final connectMessage = mqtt.MqttConnectMessage()
        .withClientIdentifier(request.clientId)
        .authenticateAs(request.username, request.password);
    if (request.cleanSession) connectMessage.startClean();
    client.connectionMessage = connectMessage;

    final status = await client.connect();
    if (client.connectionStatus?.state != mqtt.MqttConnectionState.connected) {
      final code = status?.returnCode?.toString().split('.').last;
      internalLogger.warning(
        'MQTT connect to ${request.endpoint}:${request.port} did not reach '
        'connected state (returnCode: $code).',
      );
      throw MqttTransportException(
        'Connect to ${request.endpoint}:${request.port} did not succeed.',
        returnCode: code,
      );
    }

    _updatesSub = client.updates?.listen(_onUpdates);
    _emit(MqttTransportState.connected);
    internalLogger.debug(
      'MQTT connected to ${request.endpoint}:${request.port}.',
    );
  }

  @override
  void subscribe(String topic, MqttQosLevel qos) {
    final client = _client;
    if (client == null || !isConnected) {
      internalLogger.debug('subscribe($topic) skipped: not connected.');
      return;
    }
    client.subscribe(topic, _mapQos(qos));
  }

  @override
  void unsubscribe(String topic) {
    _client?.unsubscribe(topic);
  }

  @override
  void publish(
    String topic,
    MqttQosLevel qos,
    List<int> payload, {
    bool retain = false,
  }) {
    final client = _client;
    if (client == null || !isConnected) {
      internalLogger.debug('publish($topic) skipped: not connected.');
      return;
    }
    final buffer = typed.Uint8Buffer();
    buffer.addAll(payload);
    client.publishMessage(topic, _mapQos(qos), buffer, retain: retain);
  }

  @override
  void disconnect() {
    _client?.disconnect();
    _emit(MqttTransportState.disconnected);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _client?.disconnect();
    _client = null;
    await _updatesSub?.cancel();
    _updatesSub = null;
    await _messages.close();
    await _states.close();
  }

  void _wireCallbacks(mqtt.MqttServerClient client) {
    client.onConnected = () => _emit(MqttTransportState.connected);
    client.onDisconnected = () => _emit(MqttTransportState.disconnected);
    client.onAutoReconnect = () => _emit(MqttTransportState.reconnecting);
    client.onAutoReconnected = () => _emit(MqttTransportState.connected);
    client.onFailedConnectionAttempt = (int attemptNumber) {
      _emit(MqttTransportState.failed);
      internalLogger.warning('MQTT connection attempt #$attemptNumber failed.');
    };
  }

  void _onUpdates(List<mqtt.MqttReceivedMessage<mqtt.MqttMessage>> received) {
    for (final record in received) {
      final payload = record.payload;
      if (payload is! mqtt.MqttPublishMessage) continue;
      _messages.add(
        MqttIncomingMessage(
          topic: record.topic,
          payload: List<int>.from(payload.payload.message),
          qos: _mapQosFromWire(payload.header?.qos),
        ),
      );
    }
  }

  mqtt.MqttQos _mapQos(MqttQosLevel qos) => switch (qos) {
    MqttQosLevel.atMostOnce => mqtt.MqttQos.atMostOnce,
    MqttQosLevel.atLeastOnce => mqtt.MqttQos.atLeastOnce,
    MqttQosLevel.exactlyOnce => mqtt.MqttQos.exactlyOnce,
  };

  MqttQosLevel _mapQosFromWire(mqtt.MqttQos? qos) => switch (qos) {
    mqtt.MqttQos.atLeastOnce => MqttQosLevel.atLeastOnce,
    mqtt.MqttQos.exactlyOnce => MqttQosLevel.exactlyOnce,
    _ => MqttQosLevel.atMostOnce,
  };

  void _emit(MqttTransportState state) {
    if (!_states.isClosed) _states.add(state);
  }

  void _assertNotDisposed() {
    if (_disposed) {
      throw StateError('MqttClientTransport has been disposed.');
    }
  }
}
