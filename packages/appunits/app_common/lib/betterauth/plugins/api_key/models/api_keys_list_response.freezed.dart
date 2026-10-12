// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api_keys_list_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ApiKeysListResponse {

 List<ApiKeyModel> get apiKeys; int get total; int? get limit; int? get offset;
/// Create a copy of ApiKeysListResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ApiKeysListResponseCopyWith<ApiKeysListResponse> get copyWith => _$ApiKeysListResponseCopyWithImpl<ApiKeysListResponse>(this as ApiKeysListResponse, _$identity);

  /// Serializes this ApiKeysListResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ApiKeysListResponse&&const DeepCollectionEquality().equals(other.apiKeys, apiKeys)&&(identical(other.total, total) || other.total == total)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.offset, offset) || other.offset == offset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(apiKeys),total,limit,offset);

@override
String toString() {
  return 'ApiKeysListResponse(apiKeys: $apiKeys, total: $total, limit: $limit, offset: $offset)';
}


}

/// @nodoc
abstract mixin class $ApiKeysListResponseCopyWith<$Res>  {
  factory $ApiKeysListResponseCopyWith(ApiKeysListResponse value, $Res Function(ApiKeysListResponse) _then) = _$ApiKeysListResponseCopyWithImpl;
@useResult
$Res call({
 List<ApiKeyModel> apiKeys, int total, int? limit, int? offset
});




}
/// @nodoc
class _$ApiKeysListResponseCopyWithImpl<$Res>
    implements $ApiKeysListResponseCopyWith<$Res> {
  _$ApiKeysListResponseCopyWithImpl(this._self, this._then);

  final ApiKeysListResponse _self;
  final $Res Function(ApiKeysListResponse) _then;

/// Create a copy of ApiKeysListResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? apiKeys = null,Object? total = null,Object? limit = freezed,Object? offset = freezed,}) {
  return _then(_self.copyWith(
apiKeys: null == apiKeys ? _self.apiKeys : apiKeys // ignore: cast_nullable_to_non_nullable
as List<ApiKeyModel>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,offset: freezed == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [ApiKeysListResponse].
extension ApiKeysListResponsePatterns on ApiKeysListResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ApiKeysListResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ApiKeysListResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ApiKeysListResponse value)  $default,){
final _that = this;
switch (_that) {
case _ApiKeysListResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ApiKeysListResponse value)?  $default,){
final _that = this;
switch (_that) {
case _ApiKeysListResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ApiKeyModel> apiKeys,  int total,  int? limit,  int? offset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ApiKeysListResponse() when $default != null:
return $default(_that.apiKeys,_that.total,_that.limit,_that.offset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ApiKeyModel> apiKeys,  int total,  int? limit,  int? offset)  $default,) {final _that = this;
switch (_that) {
case _ApiKeysListResponse():
return $default(_that.apiKeys,_that.total,_that.limit,_that.offset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ApiKeyModel> apiKeys,  int total,  int? limit,  int? offset)?  $default,) {final _that = this;
switch (_that) {
case _ApiKeysListResponse() when $default != null:
return $default(_that.apiKeys,_that.total,_that.limit,_that.offset);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ApiKeysListResponse implements ApiKeysListResponse {
  const _ApiKeysListResponse({required final  List<ApiKeyModel> apiKeys, required this.total, this.limit, this.offset}): _apiKeys = apiKeys;
  factory _ApiKeysListResponse.fromJson(Map<String, dynamic> json) => _$ApiKeysListResponseFromJson(json);

 final  List<ApiKeyModel> _apiKeys;
@override List<ApiKeyModel> get apiKeys {
  if (_apiKeys is EqualUnmodifiableListView) return _apiKeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_apiKeys);
}

@override final  int total;
@override final  int? limit;
@override final  int? offset;

/// Create a copy of ApiKeysListResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ApiKeysListResponseCopyWith<_ApiKeysListResponse> get copyWith => __$ApiKeysListResponseCopyWithImpl<_ApiKeysListResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ApiKeysListResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ApiKeysListResponse&&const DeepCollectionEquality().equals(other._apiKeys, _apiKeys)&&(identical(other.total, total) || other.total == total)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.offset, offset) || other.offset == offset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_apiKeys),total,limit,offset);

@override
String toString() {
  return 'ApiKeysListResponse(apiKeys: $apiKeys, total: $total, limit: $limit, offset: $offset)';
}


}

/// @nodoc
abstract mixin class _$ApiKeysListResponseCopyWith<$Res> implements $ApiKeysListResponseCopyWith<$Res> {
  factory _$ApiKeysListResponseCopyWith(_ApiKeysListResponse value, $Res Function(_ApiKeysListResponse) _then) = __$ApiKeysListResponseCopyWithImpl;
@override @useResult
$Res call({
 List<ApiKeyModel> apiKeys, int total, int? limit, int? offset
});




}
/// @nodoc
class __$ApiKeysListResponseCopyWithImpl<$Res>
    implements _$ApiKeysListResponseCopyWith<$Res> {
  __$ApiKeysListResponseCopyWithImpl(this._self, this._then);

  final _ApiKeysListResponse _self;
  final $Res Function(_ApiKeysListResponse) _then;

/// Create a copy of ApiKeysListResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? apiKeys = null,Object? total = null,Object? limit = freezed,Object? offset = freezed,}) {
  return _then(_ApiKeysListResponse(
apiKeys: null == apiKeys ? _self._apiKeys : apiKeys // ignore: cast_nullable_to_non_nullable
as List<ApiKeyModel>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,limit: freezed == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int?,offset: freezed == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
