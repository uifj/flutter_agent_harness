// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization_update_role_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrganizationUpdateRoleResponse {

 bool get success; OrganizationRoleRecord get roleData;
/// Create a copy of OrganizationUpdateRoleResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationUpdateRoleResponseCopyWith<OrganizationUpdateRoleResponse> get copyWith => _$OrganizationUpdateRoleResponseCopyWithImpl<OrganizationUpdateRoleResponse>(this as OrganizationUpdateRoleResponse, _$identity);

  /// Serializes this OrganizationUpdateRoleResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrganizationUpdateRoleResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.roleData, roleData) || other.roleData == roleData));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,roleData);

@override
String toString() {
  return 'OrganizationUpdateRoleResponse(success: $success, roleData: $roleData)';
}


}

/// @nodoc
abstract mixin class $OrganizationUpdateRoleResponseCopyWith<$Res>  {
  factory $OrganizationUpdateRoleResponseCopyWith(OrganizationUpdateRoleResponse value, $Res Function(OrganizationUpdateRoleResponse) _then) = _$OrganizationUpdateRoleResponseCopyWithImpl;
@useResult
$Res call({
 bool success, OrganizationRoleRecord roleData
});


$OrganizationRoleRecordCopyWith<$Res> get roleData;

}
/// @nodoc
class _$OrganizationUpdateRoleResponseCopyWithImpl<$Res>
    implements $OrganizationUpdateRoleResponseCopyWith<$Res> {
  _$OrganizationUpdateRoleResponseCopyWithImpl(this._self, this._then);

  final OrganizationUpdateRoleResponse _self;
  final $Res Function(OrganizationUpdateRoleResponse) _then;

/// Create a copy of OrganizationUpdateRoleResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? roleData = null,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,roleData: null == roleData ? _self.roleData : roleData // ignore: cast_nullable_to_non_nullable
as OrganizationRoleRecord,
  ));
}
/// Create a copy of OrganizationUpdateRoleResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrganizationRoleRecordCopyWith<$Res> get roleData {
  
  return $OrganizationRoleRecordCopyWith<$Res>(_self.roleData, (value) {
    return _then(_self.copyWith(roleData: value));
  });
}
}


/// Adds pattern-matching-related methods to [OrganizationUpdateRoleResponse].
extension OrganizationUpdateRoleResponsePatterns on OrganizationUpdateRoleResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrganizationUpdateRoleResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrganizationUpdateRoleResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrganizationUpdateRoleResponse value)  $default,){
final _that = this;
switch (_that) {
case _OrganizationUpdateRoleResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrganizationUpdateRoleResponse value)?  $default,){
final _that = this;
switch (_that) {
case _OrganizationUpdateRoleResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  OrganizationRoleRecord roleData)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrganizationUpdateRoleResponse() when $default != null:
return $default(_that.success,_that.roleData);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  OrganizationRoleRecord roleData)  $default,) {final _that = this;
switch (_that) {
case _OrganizationUpdateRoleResponse():
return $default(_that.success,_that.roleData);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  OrganizationRoleRecord roleData)?  $default,) {final _that = this;
switch (_that) {
case _OrganizationUpdateRoleResponse() when $default != null:
return $default(_that.success,_that.roleData);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrganizationUpdateRoleResponse implements OrganizationUpdateRoleResponse {
  const _OrganizationUpdateRoleResponse({required this.success, required this.roleData});
  factory _OrganizationUpdateRoleResponse.fromJson(Map<String, dynamic> json) => _$OrganizationUpdateRoleResponseFromJson(json);

@override final  bool success;
@override final  OrganizationRoleRecord roleData;

/// Create a copy of OrganizationUpdateRoleResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationUpdateRoleResponseCopyWith<_OrganizationUpdateRoleResponse> get copyWith => __$OrganizationUpdateRoleResponseCopyWithImpl<_OrganizationUpdateRoleResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationUpdateRoleResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrganizationUpdateRoleResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.roleData, roleData) || other.roleData == roleData));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,roleData);

@override
String toString() {
  return 'OrganizationUpdateRoleResponse(success: $success, roleData: $roleData)';
}


}

/// @nodoc
abstract mixin class _$OrganizationUpdateRoleResponseCopyWith<$Res> implements $OrganizationUpdateRoleResponseCopyWith<$Res> {
  factory _$OrganizationUpdateRoleResponseCopyWith(_OrganizationUpdateRoleResponse value, $Res Function(_OrganizationUpdateRoleResponse) _then) = __$OrganizationUpdateRoleResponseCopyWithImpl;
@override @useResult
$Res call({
 bool success, OrganizationRoleRecord roleData
});


@override $OrganizationRoleRecordCopyWith<$Res> get roleData;

}
/// @nodoc
class __$OrganizationUpdateRoleResponseCopyWithImpl<$Res>
    implements _$OrganizationUpdateRoleResponseCopyWith<$Res> {
  __$OrganizationUpdateRoleResponseCopyWithImpl(this._self, this._then);

  final _OrganizationUpdateRoleResponse _self;
  final $Res Function(_OrganizationUpdateRoleResponse) _then;

/// Create a copy of OrganizationUpdateRoleResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? roleData = null,}) {
  return _then(_OrganizationUpdateRoleResponse(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,roleData: null == roleData ? _self.roleData : roleData // ignore: cast_nullable_to_non_nullable
as OrganizationRoleRecord,
  ));
}

/// Create a copy of OrganizationUpdateRoleResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrganizationRoleRecordCopyWith<$Res> get roleData {
  
  return $OrganizationRoleRecordCopyWith<$Res>(_self.roleData, (value) {
    return _then(_self.copyWith(roleData: value));
  });
}
}

// dart format on
