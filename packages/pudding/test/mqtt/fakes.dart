// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:pudding/mqtt/mqtt.dart';

/// In-memory [MqttTransport] for tests — the seam a fake pushes on instead of a
/// live broker. Records every call and lets the test inject inbound traffic.
class FakeTransport implements MqttTransport {
  final StreamController<MqttIncomingMessage> _messages =
      StreamController<MqttIncomingMessage>.broadcast();
  final StreamController<MqttTransportState> _states =
      StreamController<MqttTransportState>.broadcast();

  final List<MqttConnectRequest> connects = <MqttConnectRequest>[];
  final List<String> subscriptions = <String>[];
  final List<Published> publishes = <Published>[];
  final List<String> unsubscriptions = <String>[];

  Object? connectError;
  bool _connected = false;

  @override
  Stream<MqttIncomingMessage> get messages => _messages.stream;

  @override
  Stream<MqttTransportState> get states => _states.stream;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(MqttConnectRequest request) async {
    connects.add(request);
    if (connectError != null) throw connectError!;
    _connected = true;
    _states.add(MqttTransportState.connected);
  }

  @override
  void subscribe(String topic, MqttQosLevel qos) {
    if (!_connected) throw StateError('not connected');
    subscriptions.add(topic);
  }

  @override
  void unsubscribe(String topic) => unsubscriptions.add(topic);

  @override
  void publish(
    String topic,
    MqttQosLevel qos,
    List<int> payload, {
    bool retain = false,
  }) {
    if (!_connected) throw StateError('not connected');
    publishes.add(Published(topic, qos, List<int>.from(payload), retain));
  }

  @override
  void disconnect() {
    _connected = false;
    _states.add(MqttTransportState.disconnected);
  }

  @override
  Future<void> dispose() async {
    _connected = false;
    await _messages.close();
    await _states.close();
  }

  /// Injects an inbound message as if the broker delivered it.
  void emitMessage(MqttIncomingMessage message) => _messages.add(message);
}

/// [MqttClientObserver] that records the lifecycle sequence for assertions.
class RecordingObserver implements MqttClientObserver {
  final List<String> events = <String>[];

  @override
  void onConnectAttempt(MqttConnectRequest request) =>
      events.add('attempt:${request.endpoint}');

  @override
  void onConnectSuccess(MqttConnectRequest request, Duration elapsed) =>
      events.add('success:${request.clientId}');

  @override
  void onConnectFailure(
    MqttConnectRequest request,
    Object error,
    StackTrace stackTrace,
  ) => events.add('failure:$error');

  @override
  void onSubscribed(String topic, MqttQosLevel qos) =>
      events.add('subscribe:$topic');

  @override
  void onPublished(String topic, MqttQosLevel qos, int payloadBytes) =>
      events.add('publish:$topic:$payloadBytes');

  @override
  void onIncomingMessage(MqttIncomingMessage message) =>
      events.add('incoming:${message.topic}');

  @override
  void onStateChange(MqttTransportState state) =>
      events.add('state:${state.name}');
}

/// A ticket equivalent to the `GetMqttTicket` sample, parsed from its camelCase
/// IspResponse body. Expiry defaults to +1h so refresh logic is exercised.
MqttTicket sampleTicket({DateTime? expiresAt}) {
  return MqttTicket.fromJson(<String, dynamic>{
    'data': <String, dynamic>{
      'expireTimeStamp':
          (expiresAt ?? DateTime.now().add(const Duration(hours: 1)))
              .millisecondsSinceEpoch
              .toString(),
      'mqttEndpoint': 'wuying-xianqiu-mqtt.inter.env76.shuguang.com',
      'mqttVPCEndpoint': 'post-cn-7mz2njrln01-internal-vpc.mqtt.aliyuncs.com',
      'mqttUsername': '言善',
      'mqttPassword': '9cd47cc0-c7bc-4972-8ff1-7e0067f4b4ac',
      'mqttGroupId': 'GID_CLIENT',
      'mqttInstanceId': 'post-cn-7mz2njrln01',
      'topicList': <dynamic>[
        <String, dynamic>{
          'topic': 'pub/FE852C9FA8E09440DF6328FCC8B651F2',
          'permission': 'W',
          'type': 'pub',
        },
        <String, dynamic>{
          'topic': 'sub/ten/1870458179609434',
          'permission': 'R',
          'type': 'sub-ten',
        },
        <String, dynamic>{
          'topic': 'sub/uuid/FE852C9FA8E09440DF6328FCC8B651F2',
          'permission': 'R',
          'type': 'sub-uuid',
        },
        <String, dynamic>{
          'topic': 'sub/sys',
          'permission': 'R',
          'type': 'sub-sys',
        },
      ],
    },
    'success': true,
    'requestId': '0C1B69B4-126A-44E7-9404-D2169CF5E8AD',
  });
}

/// A recorded publish call captured by [FakeTransport].
class Published {
  Published(this.topic, this.qos, this.payload, this.retain);
  final String topic;
  final MqttQosLevel qos;
  final List<int> payload;
  final bool retain;
}
