// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wrapped_organization_member_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WrappedOrganizationMemberResponse {

 OrganizationMember get member;
/// Create a copy of WrappedOrganizationMemberResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WrappedOrganizationMemberResponseCopyWith<WrappedOrganizationMemberResponse> get copyWith => _$WrappedOrganizationMemberResponseCopyWithImpl<WrappedOrganizationMemberResponse>(this as WrappedOrganizationMemberResponse, _$identity);

  /// Serializes this WrappedOrganizationMemberResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WrappedOrganizationMemberResponse&&(identical(other.member, member) || other.member == member));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,member);

@override
String toString() {
  return 'WrappedOrganizationMemberResponse(member: $member)';
}


}

/// @nodoc
abstract mixin class $WrappedOrganizationMemberResponseCopyWith<$Res>  {
  factory $WrappedOrganizationMemberResponseCopyWith(WrappedOrganizationMemberResponse value, $Res Function(WrappedOrganizationMemberResponse) _then) = _$WrappedOrganizationMemberResponseCopyWithImpl;
@useResult
$Res call({
 OrganizationMember member
});


$OrganizationMemberCopyWith<$Res> get member;

}
/// @nodoc
class _$WrappedOrganizationMemberResponseCopyWithImpl<$Res>
    implements $WrappedOrganizationMemberResponseCopyWith<$Res> {
  _$WrappedOrganizationMemberResponseCopyWithImpl(this._self, this._then);

  final WrappedOrganizationMemberResponse _self;
  final $Res Function(WrappedOrganizationMemberResponse) _then;

/// Create a copy of WrappedOrganizationMemberResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? member = null,}) {
  return _then(_self.copyWith(
member: null == member ? _self.member : member // ignore: cast_nullable_to_non_nullable
as OrganizationMember,
  ));
}
/// Create a copy of WrappedOrganizationMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrganizationMemberCopyWith<$Res> get member {
  
  return $OrganizationMemberCopyWith<$Res>(_self.member, (value) {
    return _then(_self.copyWith(member: value));
  });
}
}


/// Adds pattern-matching-related methods to [WrappedOrganizationMemberResponse].
extension WrappedOrganizationMemberResponsePatterns on WrappedOrganizationMemberResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WrappedOrganizationMemberResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WrappedOrganizationMemberResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WrappedOrganizationMemberResponse value)  $default,){
final _that = this;
switch (_that) {
case _WrappedOrganizationMemberResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WrappedOrganizationMemberResponse value)?  $default,){
final _that = this;
switch (_that) {
case _WrappedOrganizationMemberResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( OrganizationMember member)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WrappedOrganizationMemberResponse() when $default != null:
return $default(_that.member);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( OrganizationMember member)  $default,) {final _that = this;
switch (_that) {
case _WrappedOrganizationMemberResponse():
return $default(_that.member);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( OrganizationMember member)?  $default,) {final _that = this;
switch (_that) {
case _WrappedOrganizationMemberResponse() when $default != null:
return $default(_that.member);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WrappedOrganizationMemberResponse implements WrappedOrganizationMemberResponse {
  const _WrappedOrganizationMemberResponse({required this.member});
  factory _WrappedOrganizationMemberResponse.fromJson(Map<String, dynamic> json) => _$WrappedOrganizationMemberResponseFromJson(json);

@override final  OrganizationMember member;

/// Create a copy of WrappedOrganizationMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WrappedOrganizationMemberResponseCopyWith<_WrappedOrganizationMemberResponse> get copyWith => __$WrappedOrganizationMemberResponseCopyWithImpl<_WrappedOrganizationMemberResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WrappedOrganizationMemberResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WrappedOrganizationMemberResponse&&(identical(other.member, member) || other.member == member));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,member);

@override
String toString() {
  return 'WrappedOrganizationMemberResponse(member: $member)';
}


}

/// @nodoc
abstract mixin class _$WrappedOrganizationMemberResponseCopyWith<$Res> implements $WrappedOrganizationMemberResponseCopyWith<$Res> {
  factory _$WrappedOrganizationMemberResponseCopyWith(_WrappedOrganizationMemberResponse value, $Res Function(_WrappedOrganizationMemberResponse) _then) = __$WrappedOrganizationMemberResponseCopyWithImpl;
@override @useResult
$Res call({
 OrganizationMember member
});


@override $OrganizationMemberCopyWith<$Res> get member;

}
/// @nodoc
class __$WrappedOrganizationMemberResponseCopyWithImpl<$Res>
    implements _$WrappedOrganizationMemberResponseCopyWith<$Res> {
  __$WrappedOrganizationMemberResponseCopyWithImpl(this._self, this._then);

  final _WrappedOrganizationMemberResponse _self;
  final $Res Function(_WrappedOrganizationMemberResponse) _then;

/// Create a copy of WrappedOrganizationMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? member = null,}) {
  return _then(_WrappedOrganizationMemberResponse(
member: null == member ? _self.member : member // ignore: cast_nullable_to_non_nullable
as OrganizationMember,
  ));
}

/// Create a copy of WrappedOrganizationMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrganizationMemberCopyWith<$Res> get member {
  
  return $OrganizationMemberCopyWith<$Res>(_self.member, (value) {
    return _then(_self.copyWith(member: value));
  });
}
}

// dart format on
