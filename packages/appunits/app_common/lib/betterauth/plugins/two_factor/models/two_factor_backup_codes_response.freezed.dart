// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'two_factor_backup_codes_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TwoFactorBackupCodesResponse {

 bool get status; List<String>? get backupCodes;
/// Create a copy of TwoFactorBackupCodesResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TwoFactorBackupCodesResponseCopyWith<TwoFactorBackupCodesResponse> get copyWith => _$TwoFactorBackupCodesResponseCopyWithImpl<TwoFactorBackupCodesResponse>(this as TwoFactorBackupCodesResponse, _$identity);

  /// Serializes this TwoFactorBackupCodesResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TwoFactorBackupCodesResponse&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other.backupCodes, backupCodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(backupCodes));

@override
String toString() {
  return 'TwoFactorBackupCodesResponse(status: $status, backupCodes: $backupCodes)';
}


}

/// @nodoc
abstract mixin class $TwoFactorBackupCodesResponseCopyWith<$Res>  {
  factory $TwoFactorBackupCodesResponseCopyWith(TwoFactorBackupCodesResponse value, $Res Function(TwoFactorBackupCodesResponse) _then) = _$TwoFactorBackupCodesResponseCopyWithImpl;
@useResult
$Res call({
 bool status, List<String>? backupCodes
});




}
/// @nodoc
class _$TwoFactorBackupCodesResponseCopyWithImpl<$Res>
    implements $TwoFactorBackupCodesResponseCopyWith<$Res> {
  _$TwoFactorBackupCodesResponseCopyWithImpl(this._self, this._then);

  final TwoFactorBackupCodesResponse _self;
  final $Res Function(TwoFactorBackupCodesResponse) _then;

/// Create a copy of TwoFactorBackupCodesResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? backupCodes = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as bool,backupCodes: freezed == backupCodes ? _self.backupCodes : backupCodes // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}

}


/// Adds pattern-matching-related methods to [TwoFactorBackupCodesResponse].
extension TwoFactorBackupCodesResponsePatterns on TwoFactorBackupCodesResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TwoFactorBackupCodesResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TwoFactorBackupCodesResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TwoFactorBackupCodesResponse value)  $default,){
final _that = this;
switch (_that) {
case _TwoFactorBackupCodesResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TwoFactorBackupCodesResponse value)?  $default,){
final _that = this;
switch (_that) {
case _TwoFactorBackupCodesResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool status,  List<String>? backupCodes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TwoFactorBackupCodesResponse() when $default != null:
return $default(_that.status,_that.backupCodes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool status,  List<String>? backupCodes)  $default,) {final _that = this;
switch (_that) {
case _TwoFactorBackupCodesResponse():
return $default(_that.status,_that.backupCodes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool status,  List<String>? backupCodes)?  $default,) {final _that = this;
switch (_that) {
case _TwoFactorBackupCodesResponse() when $default != null:
return $default(_that.status,_that.backupCodes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TwoFactorBackupCodesResponse implements TwoFactorBackupCodesResponse {
  const _TwoFactorBackupCodesResponse({required this.status, final  List<String>? backupCodes}): _backupCodes = backupCodes;
  factory _TwoFactorBackupCodesResponse.fromJson(Map<String, dynamic> json) => _$TwoFactorBackupCodesResponseFromJson(json);

@override final  bool status;
 final  List<String>? _backupCodes;
@override List<String>? get backupCodes {
  final value = _backupCodes;
  if (value == null) return null;
  if (_backupCodes is EqualUnmodifiableListView) return _backupCodes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of TwoFactorBackupCodesResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TwoFactorBackupCodesResponseCopyWith<_TwoFactorBackupCodesResponse> get copyWith => __$TwoFactorBackupCodesResponseCopyWithImpl<_TwoFactorBackupCodesResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TwoFactorBackupCodesResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TwoFactorBackupCodesResponse&&(identical(other.status, status) || other.status == status)&&const DeepCollectionEquality().equals(other._backupCodes, _backupCodes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status,const DeepCollectionEquality().hash(_backupCodes));

@override
String toString() {
  return 'TwoFactorBackupCodesResponse(status: $status, backupCodes: $backupCodes)';
}


}

/// @nodoc
abstract mixin class _$TwoFactorBackupCodesResponseCopyWith<$Res> implements $TwoFactorBackupCodesResponseCopyWith<$Res> {
  factory _$TwoFactorBackupCodesResponseCopyWith(_TwoFactorBackupCodesResponse value, $Res Function(_TwoFactorBackupCodesResponse) _then) = __$TwoFactorBackupCodesResponseCopyWithImpl;
@override @useResult
$Res call({
 bool status, List<String>? backupCodes
});




}
/// @nodoc
class __$TwoFactorBackupCodesResponseCopyWithImpl<$Res>
    implements _$TwoFactorBackupCodesResponseCopyWith<$Res> {
  __$TwoFactorBackupCodesResponseCopyWithImpl(this._self, this._then);

  final _TwoFactorBackupCodesResponse _self;
  final $Res Function(_TwoFactorBackupCodesResponse) _then;

/// Create a copy of TwoFactorBackupCodesResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? backupCodes = freezed,}) {
  return _then(_TwoFactorBackupCodesResponse(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as bool,backupCodes: freezed == backupCodes ? _self._backupCodes : backupCodes // ignore: cast_nullable_to_non_nullable
as List<String>?,
  ));
}


}

// dart format on
