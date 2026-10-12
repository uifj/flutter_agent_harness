// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'delete_expired_api_keys_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DeleteExpiredApiKeysResponse {

 bool get success; Object? get error;
/// Create a copy of DeleteExpiredApiKeysResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DeleteExpiredApiKeysResponseCopyWith<DeleteExpiredApiKeysResponse> get copyWith => _$DeleteExpiredApiKeysResponseCopyWithImpl<DeleteExpiredApiKeysResponse>(this as DeleteExpiredApiKeysResponse, _$identity);

  /// Serializes this DeleteExpiredApiKeysResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DeleteExpiredApiKeysResponse&&(identical(other.success, success) || other.success == success)&&const DeepCollectionEquality().equals(other.error, error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'DeleteExpiredApiKeysResponse(success: $success, error: $error)';
}


}

/// @nodoc
abstract mixin class $DeleteExpiredApiKeysResponseCopyWith<$Res>  {
  factory $DeleteExpiredApiKeysResponseCopyWith(DeleteExpiredApiKeysResponse value, $Res Function(DeleteExpiredApiKeysResponse) _then) = _$DeleteExpiredApiKeysResponseCopyWithImpl;
@useResult
$Res call({
 bool success, Object? error
});




}
/// @nodoc
class _$DeleteExpiredApiKeysResponseCopyWithImpl<$Res>
    implements $DeleteExpiredApiKeysResponseCopyWith<$Res> {
  _$DeleteExpiredApiKeysResponseCopyWithImpl(this._self, this._then);

  final DeleteExpiredApiKeysResponse _self;
  final $Res Function(DeleteExpiredApiKeysResponse) _then;

/// Create a copy of DeleteExpiredApiKeysResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,
  ));
}

}


/// Adds pattern-matching-related methods to [DeleteExpiredApiKeysResponse].
extension DeleteExpiredApiKeysResponsePatterns on DeleteExpiredApiKeysResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DeleteExpiredApiKeysResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DeleteExpiredApiKeysResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DeleteExpiredApiKeysResponse value)  $default,){
final _that = this;
switch (_that) {
case _DeleteExpiredApiKeysResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DeleteExpiredApiKeysResponse value)?  $default,){
final _that = this;
switch (_that) {
case _DeleteExpiredApiKeysResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  Object? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DeleteExpiredApiKeysResponse() when $default != null:
return $default(_that.success,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  Object? error)  $default,) {final _that = this;
switch (_that) {
case _DeleteExpiredApiKeysResponse():
return $default(_that.success,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  Object? error)?  $default,) {final _that = this;
switch (_that) {
case _DeleteExpiredApiKeysResponse() when $default != null:
return $default(_that.success,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DeleteExpiredApiKeysResponse implements DeleteExpiredApiKeysResponse {
  const _DeleteExpiredApiKeysResponse({required this.success, this.error});
  factory _DeleteExpiredApiKeysResponse.fromJson(Map<String, dynamic> json) => _$DeleteExpiredApiKeysResponseFromJson(json);

@override final  bool success;
@override final  Object? error;

/// Create a copy of DeleteExpiredApiKeysResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DeleteExpiredApiKeysResponseCopyWith<_DeleteExpiredApiKeysResponse> get copyWith => __$DeleteExpiredApiKeysResponseCopyWithImpl<_DeleteExpiredApiKeysResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DeleteExpiredApiKeysResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DeleteExpiredApiKeysResponse&&(identical(other.success, success) || other.success == success)&&const DeepCollectionEquality().equals(other.error, error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,const DeepCollectionEquality().hash(error));

@override
String toString() {
  return 'DeleteExpiredApiKeysResponse(success: $success, error: $error)';
}


}

/// @nodoc
abstract mixin class _$DeleteExpiredApiKeysResponseCopyWith<$Res> implements $DeleteExpiredApiKeysResponseCopyWith<$Res> {
  factory _$DeleteExpiredApiKeysResponseCopyWith(_DeleteExpiredApiKeysResponse value, $Res Function(_DeleteExpiredApiKeysResponse) _then) = __$DeleteExpiredApiKeysResponseCopyWithImpl;
@override @useResult
$Res call({
 bool success, Object? error
});




}
/// @nodoc
class __$DeleteExpiredApiKeysResponseCopyWithImpl<$Res>
    implements _$DeleteExpiredApiKeysResponseCopyWith<$Res> {
  __$DeleteExpiredApiKeysResponseCopyWithImpl(this._self, this._then);

  final _DeleteExpiredApiKeysResponse _self;
  final $Res Function(_DeleteExpiredApiKeysResponse) _then;

/// Create a copy of DeleteExpiredApiKeysResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? error = freezed,}) {
  return _then(_DeleteExpiredApiKeysResponse(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,
  ));
}


}

// dart format on
