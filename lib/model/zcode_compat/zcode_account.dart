// ZCode-compatible account and quota shapes (ADR-0045): `UserInfo`
// (`oauth.ts:82-91`), the OAuth storage key names (`oauthService.ts:55`,
// `ModelProviderSection.tsx:488-490`) and `UsageQuotaSnapshot`/
// `UsageQuotaLimit`/`UsageQuotaUsageDetail` (`usage-quota.ts:9-49`) — field
// names kept verbatim (camelCase, nullable positions included) so the
// self-built backend can serve the same contract. Pure Dart.

/// The identity an OAuth session callback carries. `subscription` is ours:
/// ZCode keeps the plan badge in its own session state; we surface the same
/// slot so the sidebar footer reads one shape.
class ZcodeUserInfo {
  const ZcodeUserInfo({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.subscription,
  });

  factory ZcodeUserInfo.fromJson(Map<String, Object?> json) => ZcodeUserInfo(
    id: json['id'] as String? ?? '',
    username: json['username'] as String? ?? '',
    displayName: json['displayName'] as String? ?? '',
    avatarUrl: json['avatarUrl'] as String?,
    subscription: json['subscription'] as String?,
  );

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? subscription;

  Map<String, Object?> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    if (avatarUrl != null) 'avatarUrl': avatarUrl,
    if (subscription != null) 'subscription': subscription,
  };

  @override
  bool operator ==(Object other) =>
      other is ZcodeUserInfo &&
      other.id == id &&
      other.username == username &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.subscription == subscription;

  @override
  int get hashCode =>
      Object.hash(id, username, displayName, avatarUrl, subscription);
}

/// The two built-in OAuth providers (`oauth.ts:8-12`) and the storage key
/// names their tokens live under (`oauthService.ts:55`). The keys are
/// semantic names inside our secure store, not a second truth.
abstract final class ZcodeOAuth {
  static const String providerZai = 'zai';
  static const String providerBigmodel = 'bigmodel';

  static const String keyActiveProvider = 'oauth:active_provider';
  static String keyAccessToken(String provider) =>
      'oauth:$provider:access_token';
  static String keyRefreshToken(String provider) =>
      'oauth:$provider:refresh_token';
  static String keyUserInfo(String provider) => 'oauth:$provider:user_info';
}

/// `UsageQuotaSnapshot` — the level plus the limits list.
class ZcodeUsageQuotaSnapshot {
  const ZcodeUsageQuotaSnapshot({required this.level, required this.limits});

  factory ZcodeUsageQuotaSnapshot.fromJson(Map<String, Object?> json) =>
      ZcodeUsageQuotaSnapshot(
        level: json['level'] as String?,
        limits: [
          for (final entry in (json['limits'] as List<Object?>? ?? const []))
            if (entry is Map<String, Object?>)
              ZcodeUsageQuotaLimit.fromJson(entry),
        ],
      );

  final String? level;
  final List<ZcodeUsageQuotaLimit> limits;

  Map<String, Object?> toJson() => {
    'level': level,
    'limits': [for (final limit in limits) limit.toJson()],
  };
}

/// `UsageQuotaLimit` — every upstream field kept, nullables included: the
/// backend decides which subset a given limit carries; the client renders
/// what arrived. Synthesized MCP quota shares the type
/// `MCP_USAGE_LIMIT` (`usage-quota.ts:47-49`).
class ZcodeUsageQuotaLimit {
  const ZcodeUsageQuotaLimit({
    required this.type,
    this.bucketId,
    this.userPlanId,
    this.periodStart,
    this.periodEnd,
    this.period,
    this.meter,
    this.unitType,
    this.planId,
    this.unit,
    this.number,
    this.usage,
    this.currentValue,
    this.remaining,
    this.percentage,
    this.nextResetTime,
    this.usageDetails = const [],
  });

  factory ZcodeUsageQuotaLimit.fromJson(Map<String, Object?> json) =>
      ZcodeUsageQuotaLimit(
        type: json['type'] as String? ?? '',
        bucketId: json['bucketId'] as String?,
        userPlanId: json['userPlanId'] as String?,
        periodStart: (json['periodStart'] as num?)?.toInt(),
        periodEnd: (json['periodEnd'] as num?)?.toInt(),
        period: json['period'] as String?,
        meter: json['meter'] as String?,
        unitType: json['unitType'] as String?,
        planId: json['planId'] as String?,
        unit: (json['unit'] as num?)?.toInt(),
        number: (json['number'] as num?)?.toInt(),
        usage: (json['usage'] as num?)?.toDouble(),
        currentValue: (json['currentValue'] as num?)?.toDouble(),
        remaining: (json['remaining'] as num?)?.toDouble(),
        percentage: (json['percentage'] as num?)?.toDouble(),
        nextResetTime: (json['nextResetTime'] as num?)?.toInt(),
        usageDetails: [
          for (final entry
              in (json['usageDetails'] as List<Object?>? ?? const []))
            if (entry is Map<String, Object?>)
              ZcodeUsageQuotaUsageDetail.fromJson(entry),
        ],
      );

  final String type;
  final String? bucketId;
  final String? userPlanId;
  final int? periodStart;
  final int? periodEnd;
  final String? period;
  final String? meter;
  final String? unitType;
  final String? planId;
  final int? unit;
  final int? number;
  final double? usage;
  final double? currentValue;
  final double? remaining;
  final double? percentage;
  final int? nextResetTime;
  final List<ZcodeUsageQuotaUsageDetail> usageDetails;

  Map<String, Object?> toJson() => {
    'type': type,
    if (bucketId != null) 'bucketId': bucketId,
    if (userPlanId != null) 'userPlanId': userPlanId,
    if (periodStart != null) 'periodStart': periodStart,
    if (periodEnd != null) 'periodEnd': periodEnd,
    if (period != null) 'period': period,
    if (meter != null) 'meter': meter,
    if (unitType != null) 'unitType': unitType,
    if (planId != null) 'planId': planId,
    if (unit != null) 'unit': unit,
    if (number != null) 'number': number,
    if (usage != null) 'usage': usage,
    if (currentValue != null) 'currentValue': currentValue,
    if (remaining != null) 'remaining': remaining,
    if (percentage != null) 'percentage': percentage,
    if (nextResetTime != null) 'nextResetTime': nextResetTime,
    'usageDetails': [for (final detail in usageDetails) detail.toJson()],
  };
}

class ZcodeUsageQuotaUsageDetail {
  const ZcodeUsageQuotaUsageDetail({
    required this.modelCode,
    this.displayName,
    required this.usage,
  });

  factory ZcodeUsageQuotaUsageDetail.fromJson(Map<String, Object?> json) =>
      ZcodeUsageQuotaUsageDetail(
        modelCode: json['modelCode'] as String? ?? '',
        displayName: json['displayName'] as String?,
        usage: (json['usage'] as num?)?.toDouble() ?? 0,
      );

  final String modelCode;
  final String? displayName;
  final double usage;

  Map<String, Object?> toJson() => {
    'modelCode': modelCode,
    if (displayName != null) 'displayName': displayName,
    'usage': usage,
  };
}
