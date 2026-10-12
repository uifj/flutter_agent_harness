// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'two_factor_totp_uri_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TwoFactorTotpUriResponse {

 String get totpURI;
/// Create a copy of TwoFactorTotpUriResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TwoFactorTotpUriResponseCopyWith<TwoFactorTotpUriResponse> get copyWith => _$TwoFactorTotpUriResponseCopyWithImpl<TwoFactorTotpUriResponse>(this as TwoFactorTotpUriResponse, _$identity);

  /// Serializes this TwoFactorTotpUriResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TwoFactorTotpUriResponse&&(identical(other.totpURI, totpURI) || other.totpURI == totpURI));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totpURI);

@override
String toString() {
  return 'TwoFactorTotpUriResponse(totpURI: $totpURI)';
}


}

/// @nodoc
abstract mixin class $TwoFactorTotpUriResponseCopyWith<$Res>  {
  factory $TwoFactorTotpUriResponseCopyWith(TwoFactorTotpUriResponse value, $Res Function(TwoFactorTotpUriResponse) _then) = _$TwoFactorTotpUriResponseCopyWithImpl;
@useResult
$Res call({
 String totpURI
});




}
/// @nodoc
class _$TwoFactorTotpUriResponseCopyWithImpl<$Res>
    implements $TwoFactorTotpUriResponseCopyWith<$Res> {
  _$TwoFactorTotpUriResponseCopyWithImpl(this._self, this._then);

  final TwoFactorTotpUriResponse _self;
  final $Res Function(TwoFactorTotpUriResponse) _then;

/// Create a copy of TwoFactorTotpUriResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totpURI = null,}) {
  return _then(_self.copyWith(
totpURI: null == totpURI ? _self.totpURI : totpURI // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TwoFactorTotpUriResponse].
extension TwoFactorTotpUriResponsePatterns on TwoFactorTotpUriResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TwoFactorTotpUriResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TwoFactorTotpUriResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TwoFactorTotpUriResponse value)  $default,){
final _that = this;
switch (_that) {
case _TwoFactorTotpUriResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TwoFactorTotpUriResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TwoFactorTotpUriResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String totpURI)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TwoFactorTotpUriResponse() when $default != null:
return $default(_that.totpURI);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String totpURI)  $default,) {final _that = this;
switch (_that) {
case _TwoFactorTotpUriResponse():
return $default(_that.totpURI);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String totpURI)?  $default,) {final _that = this;
switch (_that) {
case _TwoFactorTotpUriResponse() when $default != null:
return $default(_that.totpURI);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TwoFactorTotpUriResponse implements TwoFactorTotpUriResponse {
  const _TwoFactorTotpUriResponse({required this.totpURI});
  factory _TwoFactorTotpUriResponse.fromJson(Map<String, dynamic> json) => _$TwoFactorTotpUriResponseFromJson(json);

@override final  String totpURI;

/// Create a copy of TwoFactorTotpUriResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TwoFactorTotpUriResponseCopyWith<_TwoFactorTotpUriResponse> get copyWith => __$TwoFactorTotpUriResponseCopyWithImpl<_TwoFactorTotpUriResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TwoFactorTotpUriResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TwoFactorTotpUriResponse&&(identical(other.totpURI, totpURI) || other.totpURI == totpURI));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totpURI);

@override
String toString() {
  return 'TwoFactorTotpUriResponse(totpURI: $totpURI)';
}


}

/// @nodoc
abstract mixin class _$TwoFactorTotpUriResponseCopyWith<$Res> implements $TwoFactorTotpUriResponseCopyWith<$Res> {
  factory _$TwoFactorTotpUriResponseCopyWith(_TwoFactorTotpUriResponse value, $Res Function(_TwoFactorTotpUriResponse) _then) = __$TwoFactorTotpUriResponseCopyWithImpl;
@override @useResult
$Res call({
 String totpURI
});




}
/// @nodoc
class __$TwoFactorTotpUriResponseCopyWithImpl<$Res>
    implements _$TwoFactorTotpUriResponseCopyWith<$Res> {
  __$TwoFactorTotpUriResponseCopyWithImpl(this._self, this._then);

  final _TwoFactorTotpUriResponse _self;
  final $Res Function(_TwoFactorTotpUriResponse) _then;

/// Create a copy of TwoFactorTotpUriResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totpURI = null,}) {
  return _then(_TwoFactorTotpUriResponse(
totpURI: null == totpURI ? _self.totpURI : totpURI // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
