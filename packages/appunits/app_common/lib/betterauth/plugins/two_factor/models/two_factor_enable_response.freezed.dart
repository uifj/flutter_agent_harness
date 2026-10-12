// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'two_factor_enable_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TwoFactorEnableResponse {

 String get totpURI; List<String> get backupCodes;
/// Create a copy of TwoFactorEnableResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TwoFactorEnableResponseCopyWith<TwoFactorEnableResponse> get copyWith => _$TwoFactorEnableResponseCopyWithImpl<TwoFactorEnableResponse>(this as TwoFactorEnableResponse, _$identity);

  /// Serializes this TwoFactorEnableResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TwoFactorEnableResponse&&(identical(other.totpURI, totpURI) || other.totpURI == totpURI)&&const DeepCollectionEquality().equals(other.backupCodes, backupCodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totpURI,const DeepCollectionEquality().hash(backupCodes));

@override
String toString() {
  return 'TwoFactorEnableResponse(totpURI: $totpURI, backupCodes: $backupCodes)';
}


}

/// @nodoc
abstract mixin class $TwoFactorEnableResponseCopyWith<$Res>  {
  factory $TwoFactorEnableResponseCopyWith(TwoFactorEnableResponse value, $Res Function(TwoFactorEnableResponse) _then) = _$TwoFactorEnableResponseCopyWithImpl;
@useResult
$Res call({
 String totpURI, List<String> backupCodes
});




}
/// @nodoc
class _$TwoFactorEnableResponseCopyWithImpl<$Res>
    implements $TwoFactorEnableResponseCopyWith<$Res> {
  _$TwoFactorEnableResponseCopyWithImpl(this._self, this._then);

  final TwoFactorEnableResponse _self;
  final $Res Function(TwoFactorEnableResponse) _then;

/// Create a copy of TwoFactorEnableResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totpURI = null,Object? backupCodes = null,}) {
  return _then(_self.copyWith(
totpURI: null == totpURI ? _self.totpURI : totpURI // ignore: cast_nullable_to_non_nullable
as String,backupCodes: null == backupCodes ? _self.backupCodes : backupCodes // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [TwoFactorEnableResponse].
extension TwoFactorEnableResponsePatterns on TwoFactorEnableResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TwoFactorEnableResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TwoFactorEnableResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TwoFactorEnableResponse value)  $default,){
final _that = this;
switch (_that) {
case _TwoFactorEnableResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TwoFactorEnableResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TwoFactorEnableResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String totpURI,  List<String> backupCodes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TwoFactorEnableResponse() when $default != null:
return $default(_that.totpURI,_that.backupCodes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String totpURI,  List<String> backupCodes)  $default,) {final _that = this;
switch (_that) {
case _TwoFactorEnableResponse():
return $default(_that.totpURI,_that.backupCodes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String totpURI,  List<String> backupCodes)?  $default,) {final _that = this;
switch (_that) {
case _TwoFactorEnableResponse() when $default != null:
return $default(_that.totpURI,_that.backupCodes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TwoFactorEnableResponse implements TwoFactorEnableResponse {
  const _TwoFactorEnableResponse({required this.totpURI, required final  List<String> backupCodes}): _backupCodes = backupCodes;
  factory _TwoFactorEnableResponse.fromJson(Map<String, dynamic> json) => _$TwoFactorEnableResponseFromJson(json);

@override final  String totpURI;
 final  List<String> _backupCodes;
@override List<String> get backupCodes {
  if (_backupCodes is EqualUnmodifiableListView) return _backupCodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_backupCodes);
}


/// Create a copy of TwoFactorEnableResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TwoFactorEnableResponseCopyWith<_TwoFactorEnableResponse> get copyWith => __$TwoFactorEnableResponseCopyWithImpl<_TwoFactorEnableResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TwoFactorEnableResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TwoFactorEnableResponse&&(identical(other.totpURI, totpURI) || other.totpURI == totpURI)&&const DeepCollectionEquality().equals(other._backupCodes, _backupCodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,totpURI,const DeepCollectionEquality().hash(_backupCodes));

@override
String toString() {
  return 'TwoFactorEnableResponse(totpURI: $totpURI, backupCodes: $backupCodes)';
}


}

/// @nodoc
abstract mixin class _$TwoFactorEnableResponseCopyWith<$Res> implements $TwoFactorEnableResponseCopyWith<$Res> {
  factory _$TwoFactorEnableResponseCopyWith(_TwoFactorEnableResponse value, $Res Function(_TwoFactorEnableResponse) _then) = __$TwoFactorEnableResponseCopyWithImpl;
@override @useResult
$Res call({
 String totpURI, List<String> backupCodes
});




}
/// @nodoc
class __$TwoFactorEnableResponseCopyWithImpl<$Res>
    implements _$TwoFactorEnableResponseCopyWith<$Res> {
  __$TwoFactorEnableResponseCopyWithImpl(this._self, this._then);

  final _TwoFactorEnableResponse _self;
  final $Res Function(_TwoFactorEnableResponse) _then;

/// Create a copy of TwoFactorEnableResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totpURI = null,Object? backupCodes = null,}) {
  return _then(_TwoFactorEnableResponse(
totpURI: null == totpURI ? _self.totpURI : totpURI // ignore: cast_nullable_to_non_nullable
as String,backupCodes: null == backupCodes ? _self._backupCodes : backupCodes // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
