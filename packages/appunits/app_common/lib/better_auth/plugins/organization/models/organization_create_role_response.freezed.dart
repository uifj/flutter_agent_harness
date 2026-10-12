// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization_create_role_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrganizationCreateRoleResponse {

 bool get success; OrganizationRoleRecord get roleData; Object? get statements;
/// Create a copy of OrganizationCreateRoleResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationCreateRoleResponseCopyWith<OrganizationCreateRoleResponse> get copyWith => _$OrganizationCreateRoleResponseCopyWithImpl<OrganizationCreateRoleResponse>(this as OrganizationCreateRoleResponse, _$identity);

  /// Serializes this OrganizationCreateRoleResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrganizationCreateRoleResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.roleData, roleData) || other.roleData == roleData)&&const DeepCollectionEquality().equals(other.statements, statements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,roleData,const DeepCollectionEquality().hash(statements));

@override
String toString() {
  return 'OrganizationCreateRoleResponse(success: $success, roleData: $roleData, statements: $statements)';
}


}

/// @nodoc
abstract mixin class $OrganizationCreateRoleResponseCopyWith<$Res>  {
  factory $OrganizationCreateRoleResponseCopyWith(OrganizationCreateRoleResponse value, $Res Function(OrganizationCreateRoleResponse) _then) = _$OrganizationCreateRoleResponseCopyWithImpl;
@useResult
$Res call({
 bool success, OrganizationRoleRecord roleData, Object? statements
});


$OrganizationRoleRecordCopyWith<$Res> get roleData;

}
/// @nodoc
class _$OrganizationCreateRoleResponseCopyWithImpl<$Res>
    implements $OrganizationCreateRoleResponseCopyWith<$Res> {
  _$OrganizationCreateRoleResponseCopyWithImpl(this._self, this._then);

  final OrganizationCreateRoleResponse _self;
  final $Res Function(OrganizationCreateRoleResponse) _then;

/// Create a copy of OrganizationCreateRoleResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? success = null,Object? roleData = null,Object? statements = freezed,}) {
  return _then(_self.copyWith(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,roleData: null == roleData ? _self.roleData : roleData // ignore: cast_nullable_to_non_nullable
as OrganizationRoleRecord,statements: freezed == statements ? _self.statements : statements ,
  ));
}
/// Create a copy of OrganizationCreateRoleResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrganizationRoleRecordCopyWith<$Res> get roleData {
  
  return $OrganizationRoleRecordCopyWith<$Res>(_self.roleData, (value) {
    return _then(_self.copyWith(roleData: value));
  });
}
}


/// Adds pattern-matching-related methods to [OrganizationCreateRoleResponse].
extension OrganizationCreateRoleResponsePatterns on OrganizationCreateRoleResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrganizationCreateRoleResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrganizationCreateRoleResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrganizationCreateRoleResponse value)  $default,){
final _that = this;
switch (_that) {
case _OrganizationCreateRoleResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrganizationCreateRoleResponse value)?  $default,){
final _that = this;
switch (_that) {
case _OrganizationCreateRoleResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool success,  OrganizationRoleRecord roleData,  Object? statements)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrganizationCreateRoleResponse() when $default != null:
return $default(_that.success,_that.roleData,_that.statements);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool success,  OrganizationRoleRecord roleData,  Object? statements)  $default,) {final _that = this;
switch (_that) {
case _OrganizationCreateRoleResponse():
return $default(_that.success,_that.roleData,_that.statements);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool success,  OrganizationRoleRecord roleData,  Object? statements)?  $default,) {final _that = this;
switch (_that) {
case _OrganizationCreateRoleResponse() when $default != null:
return $default(_that.success,_that.roleData,_that.statements);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrganizationCreateRoleResponse implements OrganizationCreateRoleResponse {
  const _OrganizationCreateRoleResponse({required this.success, required this.roleData, this.statements});
  factory _OrganizationCreateRoleResponse.fromJson(Map<String, dynamic> json) => _$OrganizationCreateRoleResponseFromJson(json);

@override final  bool success;
@override final  OrganizationRoleRecord roleData;
@override final  Object? statements;

/// Create a copy of OrganizationCreateRoleResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationCreateRoleResponseCopyWith<_OrganizationCreateRoleResponse> get copyWith => __$OrganizationCreateRoleResponseCopyWithImpl<_OrganizationCreateRoleResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationCreateRoleResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrganizationCreateRoleResponse&&(identical(other.success, success) || other.success == success)&&(identical(other.roleData, roleData) || other.roleData == roleData)&&const DeepCollectionEquality().equals(other.statements, statements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,success,roleData,const DeepCollectionEquality().hash(statements));

@override
String toString() {
  return 'OrganizationCreateRoleResponse(success: $success, roleData: $roleData, statements: $statements)';
}


}

/// @nodoc
abstract mixin class _$OrganizationCreateRoleResponseCopyWith<$Res> implements $OrganizationCreateRoleResponseCopyWith<$Res> {
  factory _$OrganizationCreateRoleResponseCopyWith(_OrganizationCreateRoleResponse value, $Res Function(_OrganizationCreateRoleResponse) _then) = __$OrganizationCreateRoleResponseCopyWithImpl;
@override @useResult
$Res call({
 bool success, OrganizationRoleRecord roleData, Object? statements
});


@override $OrganizationRoleRecordCopyWith<$Res> get roleData;

}
/// @nodoc
class __$OrganizationCreateRoleResponseCopyWithImpl<$Res>
    implements _$OrganizationCreateRoleResponseCopyWith<$Res> {
  __$OrganizationCreateRoleResponseCopyWithImpl(this._self, this._then);

  final _OrganizationCreateRoleResponse _self;
  final $Res Function(_OrganizationCreateRoleResponse) _then;

/// Create a copy of OrganizationCreateRoleResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? success = null,Object? roleData = null,Object? statements = freezed,}) {
  return _then(_OrganizationCreateRoleResponse(
success: null == success ? _self.success : success // ignore: cast_nullable_to_non_nullable
as bool,roleData: null == roleData ? _self.roleData : roleData // ignore: cast_nullable_to_non_nullable
as OrganizationRoleRecord,statements: freezed == statements ? _self.statements : statements ,
  ));
}

/// Create a copy of OrganizationCreateRoleResponse
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
