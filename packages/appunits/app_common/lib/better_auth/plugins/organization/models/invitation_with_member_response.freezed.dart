// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invitation_with_member_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$InvitationWithMemberResponse {

 OrganizationInvitation get invitation; OrganizationMember? get member;
/// Create a copy of InvitationWithMemberResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvitationWithMemberResponseCopyWith<InvitationWithMemberResponse> get copyWith => _$InvitationWithMemberResponseCopyWithImpl<InvitationWithMemberResponse>(this as InvitationWithMemberResponse, _$identity);

  /// Serializes this InvitationWithMemberResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InvitationWithMemberResponse&&(identical(other.invitation, invitation) || other.invitation == invitation)&&(identical(other.member, member) || other.member == member));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,invitation,member);

@override
String toString() {
  return 'InvitationWithMemberResponse(invitation: $invitation, member: $member)';
}


}

/// @nodoc
abstract mixin class $InvitationWithMemberResponseCopyWith<$Res>  {
  factory $InvitationWithMemberResponseCopyWith(InvitationWithMemberResponse value, $Res Function(InvitationWithMemberResponse) _then) = _$InvitationWithMemberResponseCopyWithImpl;
@useResult
$Res call({
 OrganizationInvitation invitation, OrganizationMember? member
});


$OrganizationInvitationCopyWith<$Res> get invitation;$OrganizationMemberCopyWith<$Res>? get member;

}
/// @nodoc
class _$InvitationWithMemberResponseCopyWithImpl<$Res>
    implements $InvitationWithMemberResponseCopyWith<$Res> {
  _$InvitationWithMemberResponseCopyWithImpl(this._self, this._then);

  final InvitationWithMemberResponse _self;
  final $Res Function(InvitationWithMemberResponse) _then;

/// Create a copy of InvitationWithMemberResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? invitation = null,Object? member = freezed,}) {
  return _then(_self.copyWith(
invitation: null == invitation ? _self.invitation : invitation // ignore: cast_nullable_to_non_nullable
as OrganizationInvitation,member: freezed == member ? _self.member : member // ignore: cast_nullable_to_non_nullable
as OrganizationMember?,
  ));
}
/// Create a copy of InvitationWithMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrganizationInvitationCopyWith<$Res> get invitation {
  
  return $OrganizationInvitationCopyWith<$Res>(_self.invitation, (value) {
    return _then(_self.copyWith(invitation: value));
  });
}/// Create a copy of InvitationWithMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrganizationMemberCopyWith<$Res>? get member {
    if (_self.member == null) {
    return null;
  }

  return $OrganizationMemberCopyWith<$Res>(_self.member!, (value) {
    return _then(_self.copyWith(member: value));
  });
}
}


/// Adds pattern-matching-related methods to [InvitationWithMemberResponse].
extension InvitationWithMemberResponsePatterns on InvitationWithMemberResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InvitationWithMemberResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InvitationWithMemberResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InvitationWithMemberResponse value)  $default,){
final _that = this;
switch (_that) {
case _InvitationWithMemberResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InvitationWithMemberResponse value)?  $default,){
final _that = this;
switch (_that) {
case _InvitationWithMemberResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( OrganizationInvitation invitation,  OrganizationMember? member)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InvitationWithMemberResponse() when $default != null:
return $default(_that.invitation,_that.member);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( OrganizationInvitation invitation,  OrganizationMember? member)  $default,) {final _that = this;
switch (_that) {
case _InvitationWithMemberResponse():
return $default(_that.invitation,_that.member);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( OrganizationInvitation invitation,  OrganizationMember? member)?  $default,) {final _that = this;
switch (_that) {
case _InvitationWithMemberResponse() when $default != null:
return $default(_that.invitation,_that.member);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InvitationWithMemberResponse implements InvitationWithMemberResponse {
  const _InvitationWithMemberResponse({required this.invitation, this.member});
  factory _InvitationWithMemberResponse.fromJson(Map<String, dynamic> json) => _$InvitationWithMemberResponseFromJson(json);

@override final  OrganizationInvitation invitation;
@override final  OrganizationMember? member;

/// Create a copy of InvitationWithMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvitationWithMemberResponseCopyWith<_InvitationWithMemberResponse> get copyWith => __$InvitationWithMemberResponseCopyWithImpl<_InvitationWithMemberResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InvitationWithMemberResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _InvitationWithMemberResponse&&(identical(other.invitation, invitation) || other.invitation == invitation)&&(identical(other.member, member) || other.member == member));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,invitation,member);

@override
String toString() {
  return 'InvitationWithMemberResponse(invitation: $invitation, member: $member)';
}


}

/// @nodoc
abstract mixin class _$InvitationWithMemberResponseCopyWith<$Res> implements $InvitationWithMemberResponseCopyWith<$Res> {
  factory _$InvitationWithMemberResponseCopyWith(_InvitationWithMemberResponse value, $Res Function(_InvitationWithMemberResponse) _then) = __$InvitationWithMemberResponseCopyWithImpl;
@override @useResult
$Res call({
 OrganizationInvitation invitation, OrganizationMember? member
});


@override $OrganizationInvitationCopyWith<$Res> get invitation;@override $OrganizationMemberCopyWith<$Res>? get member;

}
/// @nodoc
class __$InvitationWithMemberResponseCopyWithImpl<$Res>
    implements _$InvitationWithMemberResponseCopyWith<$Res> {
  __$InvitationWithMemberResponseCopyWithImpl(this._self, this._then);

  final _InvitationWithMemberResponse _self;
  final $Res Function(_InvitationWithMemberResponse) _then;

/// Create a copy of InvitationWithMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? invitation = null,Object? member = freezed,}) {
  return _then(_InvitationWithMemberResponse(
invitation: null == invitation ? _self.invitation : invitation // ignore: cast_nullable_to_non_nullable
as OrganizationInvitation,member: freezed == member ? _self.member : member // ignore: cast_nullable_to_non_nullable
as OrganizationMember?,
  ));
}

/// Create a copy of InvitationWithMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrganizationInvitationCopyWith<$Res> get invitation {
  
  return $OrganizationInvitationCopyWith<$Res>(_self.invitation, (value) {
    return _then(_self.copyWith(invitation: value));
  });
}/// Create a copy of InvitationWithMemberResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$OrganizationMemberCopyWith<$Res>? get member {
    if (_self.member == null) {
    return null;
  }

  return $OrganizationMemberCopyWith<$Res>(_self.member!, (value) {
    return _then(_self.copyWith(member: value));
  });
}
}

// dart format on
