// Guard: a GetMqttTicket response parses into a usable ticket from EITHER the
// PascalCase POP `Response` shape OR the camelCase `IspResponse.data` shape, and
// round-trips; publish vs subscribe topics split by permission; expiry parses.
// ignore_for_file: public_member_api_docs

import 'package:flutter_test/flutter_test.dart';
import 'package:pudding/mqtt/mqtt.dart';

import 'fakes.dart';

void main() {
  const pascalBody = <String, dynamic>{
    'MqttPassword': '9cd47cc0-c7bc-4972-8ff1-7e0067f4b4ac',
    'MqttGroupId': 'GID_CLIENT',
    'RequestId': '0C1B69B4-126A-44E7-9404-D2169CF5E8AD',
    'ExpireTimeStamp': '1777431679767',
    'MqttUsername': '言善',
    'MqttEndpoint': 'wuying-xianqiu-mqtt.inter.env76.shuguang.com',
    'MqttInstanceId': 'post-cn-7mz2njrln01',
    'TopicList': <dynamic>[
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
    'MqttVPCEndpoint': 'post-cn-7mz2njrln01-internal-vpc.mqtt.aliyuncs.com',
    'Success': true,
  };

  group('MqttTicket parsing', () {
    test('parses the PascalCase POP Response shape', () {
      final ticket = MqttTicket.fromJson(pascalBody);

      expect(ticket.endpoint, 'wuying-xianqiu-mqtt.inter.env76.shuguang.com');
      expect(ticket.vpcEndpoint, endsWith('.mqtt.aliyuncs.com'));
      expect(ticket.instanceId, 'post-cn-7mz2njrln01');
      expect(ticket.groupId, 'GID_CLIENT');
      expect(ticket.username, '言善');
      expect(ticket.password, '9cd47cc0-c7bc-4972-8ff1-7e0067f4b4ac');
      expect(ticket.requestId, '0C1B69B4-126A-44E7-9404-D2169CF5E8AD');
      expect(
        ticket.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1777431679767, isUtc: true),
      );
      expect(ticket.topics, hasLength(4));
    });

    test('accepts the Response envelope and yields the same fields', () {
      final wrapped = MqttTicket.fromJson(<String, dynamic>{
        'Response': pascalBody,
      });
      expect(wrapped.groupId, 'GID_CLIENT');
      expect(wrapped.topics, hasLength(4));
    });

    test('parses the camelCase IspResponse.data shape', () {
      final ticket = sampleTicket();
      expect(ticket.groupId, 'GID_CLIENT');
      expect(ticket.topics, hasLength(4));
      expect(ticket.publishTopic?.topic, startsWith('pub/'));
    });

    test('splits publish vs subscribe topics by permission', () {
      final ticket = MqttTicket.fromJson(pascalBody);

      expect(
        ticket.publishTopic?.topic,
        'pub/FE852C9FA8E09440DF6328FCC8B651F2',
      );
      expect(ticket.publishTopic?.role, MqttTopicRole.publish);
      expect(ticket.subscribeTopics, hasLength(3));
      expect(ticket.subscribeTopics.map((t) => t.role).toSet(), {
        MqttTopicRole.tenant,
        MqttTopicRole.device,
        MqttTopicRole.system,
      });
    });

    test('round-trips through toJson (camelCase) without losing topics', () {
      final ticket = MqttTicket.fromJson(pascalBody);
      final reparsed = MqttTicket.fromJson(ticket.toJson());

      expect(reparsed.endpoint, ticket.endpoint);
      expect(reparsed.password, ticket.password);
      expect(reparsed.expiresAt, ticket.expiresAt);
      expect(reparsed.topics.length, ticket.topics.length);
      expect(
        reparsed.subscribeTopics.map((t) => t.topic),
        ticket.subscribeTopics.map((t) => t.topic),
      );
    });

    test('never leaks credentials through toString', () {
      final ticket = MqttTicket.fromJson(pascalBody);
      expect(ticket.toString(), isNot(contains(ticket.password)));
      expect(ticket.toString(), isNot(contains(ticket.username)));
    });
  });

  group('MqttTicket expiry', () {
    test('isExpired honors the skew window', () {
      final soon = DateTime.now().add(const Duration(seconds: 10));
      final ticket = sampleTicket(expiresAt: soon);
      expect(ticket.isExpired(now: DateTime.now()), isTrue);
    });

    test('a far-future ticket is not expired', () {
      final ticket = sampleTicket(
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );
      expect(ticket.isExpired(now: DateTime.now()), isFalse);
    });
  });

  group('MqttClientIdentity', () {
    test('composes the Aliyun GID@@@device client id', () {
      final ticket = sampleTicket();
      const identity = MqttClientIdentity(deviceId: 'dev-1');
      expect(identity.resolve(ticket), 'GID_CLIENT@@@dev-1');
    });

    test('rawClientId bypasses composition', () {
      final ticket = sampleTicket();
      const identity = MqttClientIdentity(rawClientId: 'fixed-id');
      expect(identity.resolve(ticket), 'fixed-id');
    });
  });
}
