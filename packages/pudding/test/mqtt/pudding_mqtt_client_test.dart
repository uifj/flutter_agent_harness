// Guard: PuddingMqttClient turns a ticket into a connect + subscribe of the
// read topics and a publish to the write topic; a connect failure is reported
// to the observer and rethrown; an unusable ticket never reaches the transport.
// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pudding/mqtt/mqtt.dart';

import 'fakes.dart';

void main() {
  MqttClientConfig config({bool preferVpc = false}) => MqttClientConfig(
    identity: const MqttClientIdentity(deviceId: 'dev-1'),
    preferVpcEndpoint: preferVpc,
  );

  PuddingMqttClient buildClient({
    required FakeTransport transport,
    required MqttTicket ticket,
    MqttClientConfig? clientConfig,
    RecordingObserver? observer,
  }) {
    return PuddingMqttClient(
      config: clientConfig ?? config(),
      ticketSource: CallbackMqttTicketSource(fetch: () async => ticket),
      observer: observer ?? RecordingObserver(),
      transportFactory: () => transport,
    );
  }

  group('connect flow', () {
    test(
      'connects with a composed clientId and subscribes read topics',
      () async {
        final transport = FakeTransport();
        final observer = RecordingObserver();
        final client = buildClient(
          transport: transport,
          ticket: sampleTicket(),
          observer: observer,
        );

        await client.connect();

        expect(transport.connects, hasLength(1));
        final request = transport.connects.single;
        expect(
          request.endpoint,
          'wuying-xianqiu-mqtt.inter.env76.shuguang.com',
        );
        expect(request.clientId, 'GID_CLIENT@@@dev-1');
        expect(request.username, '言善');
        expect(request.password, isNotEmpty);
        expect(transport.subscriptions, hasLength(3));
        expect(transport.subscriptions, isNot(contains(startsWith('pub/'))));
        expect(
          observer.events,
          containsAllInOrder(<String>[
            'attempt:wuying-xianqiu-mqtt.inter.env76.shuguang.com',
            'success:GID_CLIENT@@@dev-1',
            'subscribe:sub/ten/1870458179609434',
          ]),
        );
        await client.dispose();
      },
    );

    test('prefers the VPC endpoint when configured', () async {
      final transport = FakeTransport();
      final client = buildClient(
        transport: transport,
        ticket: sampleTicket(),
        clientConfig: config(preferVpc: true),
      );

      await client.connect();

      expect(
        transport.connects.single.endpoint,
        'post-cn-7mz2njrln01-internal-vpc.mqtt.aliyuncs.com',
      );
      await client.dispose();
    });

    test('publishString targets the ticket pub topic', () async {
      final transport = FakeTransport();
      final observer = RecordingObserver();
      final client = buildClient(
        transport: transport,
        ticket: sampleTicket(),
        observer: observer,
      );
      await client.connect();

      client.publishString('hello');

      final published = transport.publishes.single;
      expect(published.topic, 'pub/FE852C9FA8E09440DF6328FCC8B651F2');
      expect(published.qos, MqttQosLevel.atLeastOnce);
      expect(latin1.decode(published.payload), 'hello');
      expect(
        observer.events,
        contains('publish:pub/FE852C9FA8E09440DF6328FCC8B651F2:5'),
      );
      await client.dispose();
    });

    test(
      'forwards inbound messages to client.messages and the observer',
      () async {
        final transport = FakeTransport();
        final observer = RecordingObserver();
        final client = buildClient(
          transport: transport,
          ticket: sampleTicket(),
          observer: observer,
        );
        await client.connect();

        final received = client.messages.first;
        transport.emitMessage(
          const MqttIncomingMessage(
            topic: 'sub/sys',
            payload: [1, 2, 3],
            qos: MqttQosLevel.atMostOnce,
          ),
        );
        final message = await received.timeout(const Duration(seconds: 1));

        expect(message.topic, 'sub/sys');
        expect(message.payload, <int>[1, 2, 3]);
        await Future<void>(() {}); // let the observer callback run
        expect(observer.events, contains('incoming:sub/sys'));
        await client.dispose();
      },
    );
  });

  group('failure guards', () {
    test(
      'a connect failure is reported to the observer and rethrown',
      () async {
        final transport = FakeTransport()
          ..connectError = const MqttTransportException('broker down');
        final observer = RecordingObserver();
        final client = buildClient(
          transport: transport,
          ticket: sampleTicket(),
          observer: observer,
        );

        await expectLater(
          client.connect(),
          throwsA(isA<MqttTransportException>()),
        );

        expect(client.isConnected, isFalse);
        expect(transport.subscriptions, isEmpty);
        expect(observer.events.any((e) => e.startsWith('failure:')), isTrue);
        await client.dispose();
      },
    );

    test('an expired ticket never reaches the transport', () async {
      final transport = FakeTransport();
      final client = buildClient(
        transport: transport,
        ticket: sampleTicket(
          expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
      );

      await expectLater(client.connect(), throwsA(isA<MqttTicketException>()));
      expect(transport.connects, isEmpty);
      await client.dispose();
    });

    test('a credential-less ticket is rejected', () async {
      final transport = FakeTransport();
      final bad = MqttTicket.fromJson(<String, dynamic>{
        'mqttEndpoint': 'host',
        'mqttGroupId': 'GID_CLIENT',
        'mqttUsername': '',
        'mqttPassword': '',
        'topicList': <dynamic>[],
      });
      final client = buildClient(transport: transport, ticket: bad);

      await expectLater(client.connect(), throwsA(isA<MqttTicketException>()));
      expect(transport.connects, isEmpty);
      await client.dispose();
    });

    test('publish before connect throws StateError', () async {
      final client = buildClient(
        transport: FakeTransport(),
        ticket: sampleTicket(),
      );

      expect(() => client.publishString('x'), throwsStateError);
      await client.dispose();
    });
  });
}
