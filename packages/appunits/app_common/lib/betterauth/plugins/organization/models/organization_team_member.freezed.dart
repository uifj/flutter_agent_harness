// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization_team_member.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrganizationTeamMember {

 String get id; String get teamId; String get userId; DateTime? get createdAt;
/// Create a copy of OrganizationTeamMember
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationTeamMemberCopyWith<OrganizationTeamMember> get copyWith => _$OrganizationTeamMemberCopyWithImpl<OrganizationTeamMember>(this as OrganizationTeamMember, _$identity);

  /// Serializes this OrganizationTeamMember to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrganizationTeamMember&&(identical(other.id, id) || other.id == id)&&(identical(other.teamId, teamId) || other.teamId == teamId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,teamId,userId,createdAt);

@override
String toString() {
  return 'OrganizationTeamMember(id: $id, teamId: $teamId, userId: $userId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $OrganizationTeamMemberCopyWith<$Res>  {
  factory $OrganizationTeamMemberCopyWith(OrganizationTeamMember value, $Res Function(OrganizationTeamMember) _then) = _$OrganizationTeamMemberCopyWithImpl;
@useResult
$Res call({
 String id, String teamId, String userId, DateTime? createdAt
});




}
/// @nodoc
class _$OrganizationTeamMemberCopyWithImpl<$Res>
    implements $OrganizationTeamMemberCopyWith<$Res> {
  _$OrganizationTeamMemberCopyWithImpl(this._self, this._then);

  final OrganizationTeamMember _self;
  final $Res Function(OrganizationTeamMember) _then;

/// Create a copy of OrganizationTeamMember
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? teamId = null,Object? userId = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,teamId: null == teamId ? _self.teamId : teamId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [OrganizationTeamMember].
extension OrganizationTeamMemberPatterns on OrganizationTeamMember {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrganizationTeamMember value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrganizationTeamMember() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrganizationTeamMember value)  $default,){
final _that = this;
switch (_that) {
case _OrganizationTeamMember():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrganizationTeamMember value)?  $default,){
final _that = this;
switch (_that) {
case _OrganizationTeamMember() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String teamId,  String userId,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrganizationTeamMember() when $default != null:
return $default(_that.id,_that.teamId,_that.userId,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String teamId,  String userId,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _OrganizationTeamMember():
return $default(_that.id,_that.teamId,_that.userId,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String teamId,  String userId,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _OrganizationTeamMember() when $default != null:
return $default(_that.id,_that.teamId,_that.userId,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrganizationTeamMember implements OrganizationTeamMember {
  const _OrganizationTeamMember({required this.id, required this.teamId, required this.userId, this.createdAt});
  factory _OrganizationTeamMember.fromJson(Map<String, dynamic> json) => _$OrganizationTeamMemberFromJson(json);

@override final  String id;
@override final  String teamId;
@override final  String userId;
@override final  DateTime? createdAt;

/// Create a copy of OrganizationTeamMember
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationTeamMemberCopyWith<_OrganizationTeamMember> get copyWith => __$OrganizationTeamMemberCopyWithImpl<_OrganizationTeamMember>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationTeamMemberToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrganizationTeamMember&&(identical(other.id, id) || other.id == id)&&(identical(other.teamId, teamId) || other.teamId == teamId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,teamId,userId,createdAt);

@override
String toString() {
  return 'OrganizationTeamMember(id: $id, teamId: $teamId, userId: $userId, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$OrganizationTeamMemberCopyWith<$Res> implements $OrganizationTeamMemberCopyWith<$Res> {
  factory _$OrganizationTeamMemberCopyWith(_OrganizationTeamMember value, $Res Function(_OrganizationTeamMember) _then) = __$OrganizationTeamMemberCopyWithImpl;
@override @useResult
$Res call({
 String id, String teamId, String userId, DateTime? createdAt
});




}
/// @nodoc
class __$OrganizationTeamMemberCopyWithImpl<$Res>
    implements _$OrganizationTeamMemberCopyWith<$Res> {
  __$OrganizationTeamMemberCopyWithImpl(this._self, this._then);

  final _OrganizationTeamMember _self;
  final $Res Function(_OrganizationTeamMember) _then;

/// Create a copy of OrganizationTeamMember
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? teamId = null,Object? userId = null,Object? createdAt = freezed,}) {
  return _then(_OrganizationTeamMember(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,teamId: null == teamId ? _self.teamId : teamId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
