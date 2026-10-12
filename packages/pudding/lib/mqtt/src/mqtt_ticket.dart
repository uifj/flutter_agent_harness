/// Data model for the MQTT connection ticket returned by the
/// `GetMqttTicket` gateway API (Alibaba-Cloud style, e.g. the Wuying /
/// appstreaming `gws-*` products).
///
/// The gateway logs this payload twice, in two shapes:
/// - the POP `Response` field uses **PascalCase** keys
///   (`MqttEndpoint`, `MqttUsername`, `TopicList`, ...);
/// - the backend `IspResponse` field wraps a **camelCase** body under `data`
///   (`mqttEndpoint`, `mqttUsername`, `topicList`, ...).
///
/// [MqttTicket.fromJson] accepts either shape without the caller having to
/// pick, so a single parser keeps "one answer" for both readers (the
/// ADR-0035 rule about a value that has more than one reader).
library;

/// Whether a ticket topic may be published to or subscribed from.
///
/// Derived from the topic's `permission` field: `W` → [MqttTopicAccess.publish],
/// `R` → [MqttTopicAccess.subscribe].
enum MqttTopicAccess {
  /// The client may publish to this topic (permission `W`).
  publish,

  /// The client may subscribe to this topic (permission `R`).
  subscribe;

  /// Parses the gateway's single-letter [permission] (`W` / `R`).
  ///
  /// Returns `null` for an unrecognized value rather than throwing, so a
  /// future permission letter from the server degrades to "ignored" instead
  /// of breaking the whole ticket.
  static MqttTopicAccess? tryParse(String? permission) {
    switch (permission?.toUpperCase()) {
      case 'W':
        return MqttTopicAccess.publish;
      case 'R':
        return MqttTopicAccess.subscribe;
      default:
        return null;
    }
  }
}

/// The role a topic plays in the ticket, from its `type` field.
///
/// The gateway scopes subscriptions per tenant / user / device and adds a
/// system channel; the single `pub` topic is the client's publish target.
enum MqttTopicRole {
  /// The client's own publish target (`type: pub`).
  publish,

  /// Tenant-wide broadcast channel (`type: sub-ten`).
  tenant,

  /// Per-user channel (`type: sub-usr`).
  user,

  /// Per-device channel, keyed by the client `Uuid` (`type: sub-uuid`).
  device,

  /// System/control channel (`type: sub-sys`).
  system,

  /// Any role the SDK does not yet recognize (forward-compatibility bucket).
  unknown;

  /// Parses the gateway's `type` string into a [MqttTopicRole].
  static MqttTopicRole parse(String? type) {
    switch (type?.toLowerCase()) {
      case 'pub':
        return MqttTopicRole.publish;
      case 'sub-ten':
        return MqttTopicRole.tenant;
      case 'sub-usr':
        return MqttTopicRole.user;
      case 'sub-uuid':
        return MqttTopicRole.device;
      case 'sub-sys':
        return MqttTopicRole.system;
      default:
        return MqttTopicRole.unknown;
    }
  }

  /// The gateway `type` string this role round-trips to.
  String get wireValue => switch (this) {
    MqttTopicRole.publish => 'pub',
    MqttTopicRole.tenant => 'sub-ten',
    MqttTopicRole.user => 'sub-usr',
    MqttTopicRole.device => 'sub-uuid',
    MqttTopicRole.system => 'sub-sys',
    MqttTopicRole.unknown => 'unknown',
  };
}

/// A single topic entry inside an [MqttTicket].
class MqttTicketTopic {
  /// Creates a topic entry.
  ///
  /// [access] and [role] are parsed from the raw [permission] / [type]
  /// strings; callers that already hold the raw gateway map should prefer
  /// [MqttTicketTopic.fromJson].
  const MqttTicketTopic({
    required this.topic,
    required this.access,
    required this.role,
  });

  /// Parses a gateway topic entry (`{topic, permission, type}`).
  factory MqttTicketTopic.fromJson(Map<String, dynamic> json) {
    return MqttTicketTopic(
      topic: _firstString(json, const ['topic', 'Topic']) ?? '',
      access: MqttTopicAccess.tryParse(
        _firstString(json, const ['permission', 'Permission']),
      ),
      role: MqttTopicRole.parse(_firstString(json, const ['type', 'Type'])),
    );
  }

  /// The MQTT topic name, e.g. `sub/uuid/FE852C9FA8E09440DF6328FCC8B651F2`.
  final String topic;

  /// Publish/subscribe direction, or `null` if the server sent an unknown
  /// permission letter.
  final MqttTopicAccess? access;

  /// The topic's role in the ticket.
  final MqttTopicRole role;

  /// Whether this topic should be subscribed on connect.
  bool get isSubscribable =>
      access == MqttTopicAccess.subscribe ||
      (access == null && role != MqttTopicRole.publish);

  /// Whether this topic is the client's publish target.
  bool get isPublishable => access == MqttTopicAccess.publish;

  /// Serializes back to the camelCase gateway shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'topic': topic,
    if (access != null)
      'permission': access == MqttTopicAccess.publish ? 'W' : 'R',
    'type': role.wireValue,
  };

  @override
  String toString() => 'MqttTicketTopic($topic, ${role.name}, ${access?.name})';
}

/// A resolved MQTT connection ticket: broker endpoints, one-shot credentials,
/// an expiry, and the topics the client is allowed to use.
///
/// The credentials ([username] / [password]) are **secrets** and the
/// [username] is frequently PII (a person's display name in the sample
/// payload). They are deliberately excluded from [toString]; pass them to the
/// broker but never to logs or Sentry unless `sendDefaultPii` is on.
class MqttTicket {
  /// Creates a ticket.
  const MqttTicket({
    required this.endpoint,
    required this.instanceId,
    required this.groupId,
    required this.username,
    required this.password,
    required this.topics,
    this.vpcEndpoint,
    this.expiresAt,
    this.requestId,
  });

  /// Parses either the PascalCase POP `Response` body or the camelCase
  /// `IspResponse` body (with or without the surrounding `data` / `Response`
  /// envelope) into an [MqttTicket].
  factory MqttTicket.fromJson(Map<String, dynamic> json) {
    final body = _unwrap(json);
    return MqttTicket(
      endpoint:
          _firstString(body, const ['MqttEndpoint', 'mqttEndpoint']) ?? '',
      vpcEndpoint: _firstString(body, const [
        'MqttVPCEndpoint',
        'mqttVPCEndpoint',
      ]),
      instanceId:
          _firstString(body, const ['MqttInstanceId', 'mqttInstanceId']) ?? '',
      groupId: _firstString(body, const ['MqttGroupId', 'mqttGroupId']) ?? '',
      username:
          _firstString(body, const ['MqttUsername', 'mqttUsername']) ?? '',
      password:
          _firstString(body, const ['MqttPassword', 'mqttPassword']) ?? '',
      expiresAt: _parseEpochMillis(
        _firstString(body, const ['ExpireTimeStamp', 'expireTimeStamp']) ??
            _firstAny(body, const ['ExpireTimeStamp', 'expireTimeStamp']),
      ),
      requestId: _firstString(body, const ['RequestId', 'requestId']),
      topics: _parseTopics(_firstAny(body, const ['TopicList', 'topicList'])),
    );
  }

  /// Public broker host, e.g.
  /// `wuying-xianqiu-mqtt.inter.env76.shuguang.com`.
  final String endpoint;

  /// Internal VPC broker host, when the client runs inside the cloud VPC.
  final String? vpcEndpoint;

  /// The MQTT instance id (`MqttInstanceId`), e.g. `post-cn-7mz2njrln01`.
  final String instanceId;

  /// The consumer group id (`MqttGroupId`), e.g. `GID_CLIENT`. Composed into
  /// the Aliyun client id as `<groupId>@@@<deviceId>`.
  final String groupId;

  /// MQTT username. Treated as secret + PII — never logged by this SDK.
  final String username;

  /// MQTT password. Secret — never logged by this SDK.
  final String password;

  /// The topics granted to this ticket, in gateway order.
  final List<MqttTicketTopic> topics;

  /// When the ticket (and thus these credentials) stop working, if the
  /// server sent an expiry.
  final DateTime? expiresAt;

  /// The gateway `RequestId`, handy for correlating a connect with a server log.
  final String? requestId;

  /// The single publish target, or `null` if the ticket grants none.
  MqttTicketTopic? get publishTopic {
    for (final topic in topics) {
      if (topic.isPublishable) return topic;
    }
    return null;
  }

  /// All topics the client should subscribe to on connect.
  List<MqttTicketTopic> get subscribeTopics =>
      topics.where((topic) => topic.isSubscribable).toList(growable: false);

  /// Whether the ticket is known to be expired against [now].
  ///
  /// A ticket with no expiry is never considered expired. [skew] renews a
  /// little early so an in-flight connect is not cut off mid-handshake.
  bool isExpired({DateTime? now, Duration skew = const Duration(seconds: 30)}) {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return !(now ?? DateTime.now()).isBefore(expiry.subtract(skew));
  }

  /// Serializes to the camelCase gateway shape (used for caching/telemetry).
  ///
  /// [username] / [password] are included because a cached ticket must be
  /// re-usable; keep the output of this method off logs and off Sentry.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'mqttEndpoint': endpoint,
    if (vpcEndpoint != null) 'mqttVPCEndpoint': vpcEndpoint,
    'mqttInstanceId': instanceId,
    'mqttGroupId': groupId,
    'mqttUsername': username,
    'mqttPassword': password,
    if (expiresAt != null)
      'expireTimeStamp': expiresAt!.millisecondsSinceEpoch.toString(),
    if (requestId != null) 'requestId': requestId,
    'topicList': topics.map((topic) => topic.toJson()).toList(growable: false),
  };

  @override
  String toString() =>
      'MqttTicket(endpoint: $endpoint, instance: $instanceId, group: $groupId, '
      'topics: ${topics.length}, expiresAt: $expiresAt, requestId: $requestId)';
}

// ---- parsing helpers (private; no second source of truth) ----

/// Drops envelopes the gateway sometimes wraps the body in: `Response`
/// (the POP string is already an object here) or `data` (the IspResponse).
Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
  final response = json['Response'];
  if (response is Map<String, dynamic>) return response;
  final data = json['data'];
  if (data is Map<String, dynamic>) return data;
  return json;
}

String? _firstString(Map<String, dynamic> map, List<String> keys) {
  final value = _firstAny(map, keys);
  if (value == null) return null;
  return value is String ? value : value.toString();
}

dynamic _firstAny(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (map.containsKey(key)) return map[key];
  }
  return null;
}

List<MqttTicketTopic> _parseTopics(Object? raw) {
  if (raw is! List) return const <MqttTicketTopic>[];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(MqttTicketTopic.fromJson)
      .toList(growable: false);
}

DateTime? _parseEpochMillis(Object? raw) {
  if (raw == null) return null;
  final millis = raw is int ? raw : int.tryParse(raw.toString());
  if (millis == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
}
