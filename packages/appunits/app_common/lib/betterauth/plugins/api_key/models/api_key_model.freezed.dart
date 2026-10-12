// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_key_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApiKeyModel {

 String get id; String get configId; String? get name; String? get start; String? get prefix;/// Hashed value in storage; omitted from list/get responses. On create,
/// the server overwrites this field with the **plaintext** secret once.
 String? get key; String get referenceId; int? get refillInterval; int? get refillAmount; DateTime? get lastRefillAt; bool get enabled; bool get rateLimitEnabled; int? get rateLimitTimeWindow; int? get rateLimitMax; int get requestCount; int? get remaining; DateTime? get lastRequest; DateTime? get expiresAt; DateTime get createdAt; DateTime get updatedAt; Map<String, dynamic>? get metadata; Map<String, dynamic>? get permissions;
/// Create a copy of ApiKeyModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiKeyModelCopyWith<ApiKeyModel> get copyWith => _$ApiKeyModelCopyWithImpl<ApiKeyModel>(this as ApiKeyModel, _$identity);

  /// Serializes this ApiKeyModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiKeyModel&&(identical(other.id, id) || other.id == id)&&(identical(other.configId, configId) || other.configId == configId)&&(identical(other.name, name) || other.name == name)&&(identical(other.start, start) || other.start == start)&&(identical(other.prefix, prefix) || other.prefix == prefix)&&(identical(other.key, key) || other.key == key)&&(identical(other.referenceId, referenceId) || other.referenceId == referenceId)&&(identical(other.refillInterval, refillInterval) || other.refillInterval == refillInterval)&&(identical(other.refillAmount, refillAmount) || other.refillAmount == refillAmount)&&(identical(other.lastRefillAt, lastRefillAt) || other.lastRefillAt == lastRefillAt)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.rateLimitEnabled, rateLimitEnabled) || other.rateLimitEnabled == rateLimitEnabled)&&(identical(other.rateLimitTimeWindow, rateLimitTimeWindow) || other.rateLimitTimeWindow == rateLimitTimeWindow)&&(identical(other.rateLimitMax, rateLimitMax) || other.rateLimitMax == rateLimitMax)&&(identical(other.requestCount, requestCount) || other.requestCount == requestCount)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.lastRequest, lastRequest) || other.lastRequest == lastRequest)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.metadata, metadata)&&const DeepCollectionEquality().equals(other.permissions, permissions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,configId,name,start,prefix,key,referenceId,refillInterval,refillAmount,lastRefillAt,enabled,rateLimitEnabled,rateLimitTimeWindow,rateLimitMax,requestCount,remaining,lastRequest,expiresAt,createdAt,updatedAt,const DeepCollectionEquality().hash(metadata),const DeepCollectionEquality().hash(permissions)]);

@override
String toString() {
  return 'ApiKeyModel(id: $id, configId: $configId, name: $name, start: $start, prefix: $prefix, key: $key, referenceId: $referenceId, refillInterval: $refillInterval, refillAmount: $refillAmount, lastRefillAt: $lastRefillAt, enabled: $enabled, rateLimitEnabled: $rateLimitEnabled, rateLimitTimeWindow: $rateLimitTimeWindow, rateLimitMax: $rateLimitMax, requestCount: $requestCount, remaining: $remaining, lastRequest: $lastRequest, expiresAt: $expiresAt, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata, permissions: $permissions)';
}


}

/// @nodoc
abstract mixin class $ApiKeyModelCopyWith<$Res>  {
  factory $ApiKeyModelCopyWith(ApiKeyModel value, $Res Function(ApiKeyModel) _then) = _$ApiKeyModelCopyWithImpl;
@useResult
$Res call({
 String id, String configId, String? name, String? start, String? prefix, String? key, String referenceId, int? refillInterval, int? refillAmount, DateTime? lastRefillAt, bool enabled, bool rateLimitEnabled, int? rateLimitTimeWindow, int? rateLimitMax, int requestCount, int? remaining, DateTime? lastRequest, DateTime? expiresAt, DateTime createdAt, DateTime updatedAt, Map<String, dynamic>? metadata, Map<String, dynamic>? permissions
});




}
/// @nodoc
class _$ApiKeyModelCopyWithImpl<$Res>
    implements $ApiKeyModelCopyWith<$Res> {
  _$ApiKeyModelCopyWithImpl(this._self, this._then);

  final ApiKeyModel _self;
  final $Res Function(ApiKeyModel) _then;

/// Create a copy of ApiKeyModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? configId = null,Object? name = freezed,Object? start = freezed,Object? prefix = freezed,Object? key = freezed,Object? referenceId = null,Object? refillInterval = freezed,Object? refillAmount = freezed,Object? lastRefillAt = freezed,Object? enabled = null,Object? rateLimitEnabled = null,Object? rateLimitTimeWindow = freezed,Object? rateLimitMax = freezed,Object? requestCount = null,Object? remaining = freezed,Object? lastRequest = freezed,Object? expiresAt = freezed,Object? createdAt = null,Object? updatedAt = null,Object? metadata = freezed,Object? permissions = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,configId: null == configId ? _self.configId : configId // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String?,prefix: freezed == prefix ? _self.prefix : prefix // ignore: cast_nullable_to_non_nullable
as String?,key: freezed == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String?,referenceId: null == referenceId ? _self.referenceId : referenceId // ignore: cast_nullable_to_non_nullable
as String,refillInterval: freezed == refillInterval ? _self.refillInterval : refillInterval // ignore: cast_nullable_to_non_nullable
as int?,refillAmount: freezed == refillAmount ? _self.refillAmount : refillAmount // ignore: cast_nullable_to_non_nullable
as int?,lastRefillAt: freezed == lastRefillAt ? _self.lastRefillAt : lastRefillAt // ignore: cast_nullable_to_non_nullable
as DateTime?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,rateLimitEnabled: null == rateLimitEnabled ? _self.rateLimitEnabled : rateLimitEnabled // ignore: cast_nullable_to_non_nullable
as bool,rateLimitTimeWindow: freezed == rateLimitTimeWindow ? _self.rateLimitTimeWindow : rateLimitTimeWindow // ignore: cast_nullable_to_non_nullable
as int?,rateLimitMax: freezed == rateLimitMax ? _self.rateLimitMax : rateLimitMax // ignore: cast_nullable_to_non_nullable
as int?,requestCount: null == requestCount ? _self.requestCount : requestCount // ignore: cast_nullable_to_non_nullable
as int,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int?,lastRequest: freezed == lastRequest ? _self.lastRequest : lastRequest // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,permissions: freezed == permissions ? _self.permissions : permissions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiKeyModel].
extension ApiKeyModelPatterns on ApiKeyModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiKeyModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiKeyModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiKeyModel value)  $default,){
final _that = this;
switch (_that) {
case _ApiKeyModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiKeyModel value)?  $default,){
final _that = this;
switch (_that) {
case _ApiKeyModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String configId,  String? name,  String? start,  String? prefix,  String? key,  String referenceId,  int? refillInterval,  int? refillAmount,  DateTime? lastRefillAt,  bool enabled,  bool rateLimitEnabled,  int? rateLimitTimeWindow,  int? rateLimitMax,  int requestCount,  int? remaining,  DateTime? lastRequest,  DateTime? expiresAt,  DateTime createdAt,  DateTime updatedAt,  Map<String, dynamic>? metadata,  Map<String, dynamic>? permissions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiKeyModel() when $default != null:
return $default(_that.id,_that.configId,_that.name,_that.start,_that.prefix,_that.key,_that.referenceId,_that.refillInterval,_that.refillAmount,_that.lastRefillAt,_that.enabled,_that.rateLimitEnabled,_that.rateLimitTimeWindow,_that.rateLimitMax,_that.requestCount,_that.remaining,_that.lastRequest,_that.expiresAt,_that.createdAt,_that.updatedAt,_that.metadata,_that.permissions);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String configId,  String? name,  String? start,  String? prefix,  String? key,  String referenceId,  int? refillInterval,  int? refillAmount,  DateTime? lastRefillAt,  bool enabled,  bool rateLimitEnabled,  int? rateLimitTimeWindow,  int? rateLimitMax,  int requestCount,  int? remaining,  DateTime? lastRequest,  DateTime? expiresAt,  DateTime createdAt,  DateTime updatedAt,  Map<String, dynamic>? metadata,  Map<String, dynamic>? permissions)  $default,) {final _that = this;
switch (_that) {
case _ApiKeyModel():
return $default(_that.id,_that.configId,_that.name,_that.start,_that.prefix,_that.key,_that.referenceId,_that.refillInterval,_that.refillAmount,_that.lastRefillAt,_that.enabled,_that.rateLimitEnabled,_that.rateLimitTimeWindow,_that.rateLimitMax,_that.requestCount,_that.remaining,_that.lastRequest,_that.expiresAt,_that.createdAt,_that.updatedAt,_that.metadata,_that.permissions);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String configId,  String? name,  String? start,  String? prefix,  String? key,  String referenceId,  int? refillInterval,  int? refillAmount,  DateTime? lastRefillAt,  bool enabled,  bool rateLimitEnabled,  int? rateLimitTimeWindow,  int? rateLimitMax,  int requestCount,  int? remaining,  DateTime? lastRequest,  DateTime? expiresAt,  DateTime createdAt,  DateTime updatedAt,  Map<String, dynamic>? metadata,  Map<String, dynamic>? permissions)?  $default,) {final _that = this;
switch (_that) {
case _ApiKeyModel() when $default != null:
return $default(_that.id,_that.configId,_that.name,_that.start,_that.prefix,_that.key,_that.referenceId,_that.refillInterval,_that.refillAmount,_that.lastRefillAt,_that.enabled,_that.rateLimitEnabled,_that.rateLimitTimeWindow,_that.rateLimitMax,_that.requestCount,_that.remaining,_that.lastRequest,_that.expiresAt,_that.createdAt,_that.updatedAt,_that.metadata,_that.permissions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiKeyModel implements ApiKeyModel {
  const _ApiKeyModel({required this.id, this.configId = 'default', this.name, this.start, this.prefix, this.key, required this.referenceId, this.refillInterval, this.refillAmount, this.lastRefillAt, this.enabled = true, this.rateLimitEnabled = true, this.rateLimitTimeWindow, this.rateLimitMax, this.requestCount = 0, this.remaining, this.lastRequest, this.expiresAt, required this.createdAt, required this.updatedAt, final  Map<String, dynamic>? metadata, final  Map<String, dynamic>? permissions}): _metadata = metadata,_permissions = permissions;
  factory _ApiKeyModel.fromJson(Map<String, dynamic> json) => _$ApiKeyModelFromJson(json);

@override final  String id;
@override@JsonKey() final  String configId;
@override final  String? name;
@override final  String? start;
@override final  String? prefix;
/// Hashed value in storage; omitted from list/get responses. On create,
/// the server overwrites this field with the **plaintext** secret once.
@override final  String? key;
@override final  String referenceId;
@override final  int? refillInterval;
@override final  int? refillAmount;
@override final  DateTime? lastRefillAt;
@override@JsonKey() final  bool enabled;
@override@JsonKey() final  bool rateLimitEnabled;
@override final  int? rateLimitTimeWindow;
@override final  int? rateLimitMax;
@override@JsonKey() final  int requestCount;
@override final  int? remaining;
@override final  DateTime? lastRequest;
@override final  DateTime? expiresAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _permissions;
@override Map<String, dynamic>? get permissions {
  final value = _permissions;
  if (value == null) return null;
  if (_permissions is EqualUnmodifiableMapView) return _permissions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of ApiKeyModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiKeyModelCopyWith<_ApiKeyModel> get copyWith => __$ApiKeyModelCopyWithImpl<_ApiKeyModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiKeyModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiKeyModel&&(identical(other.id, id) || other.id == id)&&(identical(other.configId, configId) || other.configId == configId)&&(identical(other.name, name) || other.name == name)&&(identical(other.start, start) || other.start == start)&&(identical(other.prefix, prefix) || other.prefix == prefix)&&(identical(other.key, key) || other.key == key)&&(identical(other.referenceId, referenceId) || other.referenceId == referenceId)&&(identical(other.refillInterval, refillInterval) || other.refillInterval == refillInterval)&&(identical(other.refillAmount, refillAmount) || other.refillAmount == refillAmount)&&(identical(other.lastRefillAt, lastRefillAt) || other.lastRefillAt == lastRefillAt)&&(identical(other.enabled, enabled) || other.enabled == enabled)&&(identical(other.rateLimitEnabled, rateLimitEnabled) || other.rateLimitEnabled == rateLimitEnabled)&&(identical(other.rateLimitTimeWindow, rateLimitTimeWindow) || other.rateLimitTimeWindow == rateLimitTimeWindow)&&(identical(other.rateLimitMax, rateLimitMax) || other.rateLimitMax == rateLimitMax)&&(identical(other.requestCount, requestCount) || other.requestCount == requestCount)&&(identical(other.remaining, remaining) || other.remaining == remaining)&&(identical(other.lastRequest, lastRequest) || other.lastRequest == lastRequest)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._permissions, _permissions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,configId,name,start,prefix,key,referenceId,refillInterval,refillAmount,lastRefillAt,enabled,rateLimitEnabled,rateLimitTimeWindow,rateLimitMax,requestCount,remaining,lastRequest,expiresAt,createdAt,updatedAt,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_permissions)]);

@override
String toString() {
  return 'ApiKeyModel(id: $id, configId: $configId, name: $name, start: $start, prefix: $prefix, key: $key, referenceId: $referenceId, refillInterval: $refillInterval, refillAmount: $refillAmount, lastRefillAt: $lastRefillAt, enabled: $enabled, rateLimitEnabled: $rateLimitEnabled, rateLimitTimeWindow: $rateLimitTimeWindow, rateLimitMax: $rateLimitMax, requestCount: $requestCount, remaining: $remaining, lastRequest: $lastRequest, expiresAt: $expiresAt, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata, permissions: $permissions)';
}


}

/// @nodoc
abstract mixin class _$ApiKeyModelCopyWith<$Res> implements $ApiKeyModelCopyWith<$Res> {
  factory _$ApiKeyModelCopyWith(_ApiKeyModel value, $Res Function(_ApiKeyModel) _then) = __$ApiKeyModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String configId, String? name, String? start, String? prefix, String? key, String referenceId, int? refillInterval, int? refillAmount, DateTime? lastRefillAt, bool enabled, bool rateLimitEnabled, int? rateLimitTimeWindow, int? rateLimitMax, int requestCount, int? remaining, DateTime? lastRequest, DateTime? expiresAt, DateTime createdAt, DateTime updatedAt, Map<String, dynamic>? metadata, Map<String, dynamic>? permissions
});




}
/// @nodoc
class __$ApiKeyModelCopyWithImpl<$Res>
    implements _$ApiKeyModelCopyWith<$Res> {
  __$ApiKeyModelCopyWithImpl(this._self, this._then);

  final _ApiKeyModel _self;
  final $Res Function(_ApiKeyModel) _then;

/// Create a copy of ApiKeyModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? configId = null,Object? name = freezed,Object? start = freezed,Object? prefix = freezed,Object? key = freezed,Object? referenceId = null,Object? refillInterval = freezed,Object? refillAmount = freezed,Object? lastRefillAt = freezed,Object? enabled = null,Object? rateLimitEnabled = null,Object? rateLimitTimeWindow = freezed,Object? rateLimitMax = freezed,Object? requestCount = null,Object? remaining = freezed,Object? lastRequest = freezed,Object? expiresAt = freezed,Object? createdAt = null,Object? updatedAt = null,Object? metadata = freezed,Object? permissions = freezed,}) {
  return _then(_ApiKeyModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,configId: null == configId ? _self.configId : configId // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,start: freezed == start ? _self.start : start // ignore: cast_nullable_to_non_nullable
as String?,prefix: freezed == prefix ? _self.prefix : prefix // ignore: cast_nullable_to_non_nullable
as String?,key: freezed == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String?,referenceId: null == referenceId ? _self.referenceId : referenceId // ignore: cast_nullable_to_non_nullable
as String,refillInterval: freezed == refillInterval ? _self.refillInterval : refillInterval // ignore: cast_nullable_to_non_nullable
as int?,refillAmount: freezed == refillAmount ? _self.refillAmount : refillAmount // ignore: cast_nullable_to_non_nullable
as int?,lastRefillAt: freezed == lastRefillAt ? _self.lastRefillAt : lastRefillAt // ignore: cast_nullable_to_non_nullable
as DateTime?,enabled: null == enabled ? _self.enabled : enabled // ignore: cast_nullable_to_non_nullable
as bool,rateLimitEnabled: null == rateLimitEnabled ? _self.rateLimitEnabled : rateLimitEnabled // ignore: cast_nullable_to_non_nullable
as bool,rateLimitTimeWindow: freezed == rateLimitTimeWindow ? _self.rateLimitTimeWindow : rateLimitTimeWindow // ignore: cast_nullable_to_non_nullable
as int?,rateLimitMax: freezed == rateLimitMax ? _self.rateLimitMax : rateLimitMax // ignore: cast_nullable_to_non_nullable
as int?,requestCount: null == requestCount ? _self.requestCount : requestCount // ignore: cast_nullable_to_non_nullable
as int,remaining: freezed == remaining ? _self.remaining : remaining // ignore: cast_nullable_to_non_nullable
as int?,lastRequest: freezed == lastRequest ? _self.lastRequest : lastRequest // ignore: cast_nullable_to_non_nullable
as DateTime?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,permissions: freezed == permissions ? _self._permissions : permissions // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,
  ));
}


}

// dart format on
