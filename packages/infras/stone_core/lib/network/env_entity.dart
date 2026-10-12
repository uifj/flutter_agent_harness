/// Environment endpoint entity for API routing.
///
/// Stores endpoint configuration for different regions and API services.
class EnvEntity {
  String? defaultEndpoint;
  String? vpcEndpoint;
  String? shenzhenEndpoint;
  String? intlEndpoint;
  String? intlVpcEndpoint;
  Map<String, EnvEntity?>? apis;
  Map<String, dynamic>? hosts;

  EnvEntity();

  factory EnvEntity.fromJson(Map<String, dynamic> json) {
    return EnvEntity()
      ..hosts = json['hosts'] as Map<String, dynamic>?
      ..defaultEndpoint = json['default'] as String?
      ..vpcEndpoint = json['vpc'] as String?
      ..intlEndpoint = json['intl'] as String?
      ..intlVpcEndpoint = json['intlVpc'] as String?
      ..shenzhenEndpoint = json['cn-shenzhen'] as String?
      ..apis = json['apis'] == null
          ? null
          : (json['apis'] as Map).map((key, value) {
              EnvEntity? entity;
              if (value is Map) {
                entity = EnvEntity.fromJson(value as Map<String, dynamic>);
              }
              return MapEntry(key as String, entity);
            });
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hosts': hosts,
    'default': defaultEndpoint,
    'vpc': vpcEndpoint,
    'intl': intlEndpoint,
    'intlVpc': intlVpcEndpoint,
    'cn-shenzhen': shenzhenEndpoint,
    'apis': apis,
  };
}
