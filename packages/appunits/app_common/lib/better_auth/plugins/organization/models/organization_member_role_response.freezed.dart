// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization_member_role_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrganizationMemberRoleResponse {

 String get role;
/// Create a copy of OrganizationMemberRoleResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationMemberRoleResponseCopyWith<OrganizationMemberRoleResponse> get copyWith => _$OrganizationMemberRoleResponseCopyWithImpl<OrganizationMemberRoleResponse>(this as OrganizationMemberRoleResponse, _$identity);

  /// Serializes this OrganizationMemberRoleResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrganizationMemberRoleResponse&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role);

@override
String toString() {
  return 'OrganizationMemberRoleResponse(role: $role)';
}


}

/// @nodoc
abstract mixin class $OrganizationMemberRoleResponseCopyWith<$Res>  {
  factory $OrganizationMemberRoleResponseCopyWith(OrganizationMemberRoleResponse value, $Res Function(OrganizationMemberRoleResponse) _then) = _$OrganizationMemberRoleResponseCopyWithImpl;
@useResult
$Res call({
 String role
});




}
/// @nodoc
class _$OrganizationMemberRoleResponseCopyWithImpl<$Res>
    implements $OrganizationMemberRoleResponseCopyWith<$Res> {
  _$OrganizationMemberRoleResponseCopyWithImpl(this._self, this._then);

  final OrganizationMemberRoleResponse _self;
  final $Res Function(OrganizationMemberRoleResponse) _then;

/// Create a copy of OrganizationMemberRoleResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? role = null,}) {
  return _then(_self.copyWith(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [OrganizationMemberRoleResponse].
extension OrganizationMemberRoleResponsePatterns on OrganizationMemberRoleResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrganizationMemberRoleResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrganizationMemberRoleResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrganizationMemberRoleResponse value)  $default,){
final _that = this;
switch (_that) {
case _OrganizationMemberRoleResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrganizationMemberRoleResponse value)?  $default,){
final _that = this;
switch (_that) {
case _OrganizationMemberRoleResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrganizationMemberRoleResponse() when $default != null:
return $default(_that.role);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String role)  $default,) {final _that = this;
switch (_that) {
case _OrganizationMemberRoleResponse():
return $default(_that.role);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String role)?  $default,) {final _that = this;
switch (_that) {
case _OrganizationMemberRoleResponse() when $default != null:
return $default(_that.role);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrganizationMemberRoleResponse implements OrganizationMemberRoleResponse {
  const _OrganizationMemberRoleResponse({required this.role});
  factory _OrganizationMemberRoleResponse.fromJson(Map<String, dynamic> json) => _$OrganizationMemberRoleResponseFromJson(json);

@override final  String role;

/// Create a copy of OrganizationMemberRoleResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationMemberRoleResponseCopyWith<_OrganizationMemberRoleResponse> get copyWith => __$OrganizationMemberRoleResponseCopyWithImpl<_OrganizationMemberRoleResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationMemberRoleResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrganizationMemberRoleResponse&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,role);

@override
String toString() {
  return 'OrganizationMemberRoleResponse(role: $role)';
}


}

/// @nodoc
abstract mixin class _$OrganizationMemberRoleResponseCopyWith<$Res> implements $OrganizationMemberRoleResponseCopyWith<$Res> {
  factory _$OrganizationMemberRoleResponseCopyWith(_OrganizationMemberRoleResponse value, $Res Function(_OrganizationMemberRoleResponse) _then) = __$OrganizationMemberRoleResponseCopyWithImpl;
@override @useResult
$Res call({
 String role
});




}
/// @nodoc
class __$OrganizationMemberRoleResponseCopyWithImpl<$Res>
    implements _$OrganizationMemberRoleResponseCopyWith<$Res> {
  __$OrganizationMemberRoleResponseCopyWithImpl(this._self, this._then);

  final _OrganizationMemberRoleResponse _self;
  final $Res Function(_OrganizationMemberRoleResponse) _then;

/// Create a copy of OrganizationMemberRoleResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? role = null,}) {
  return _then(_OrganizationMemberRoleResponse(
role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
