// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization_team.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrganizationTeam {

 String get id; String get name; String get organizationId; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of OrganizationTeam
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationTeamCopyWith<OrganizationTeam> get copyWith => _$OrganizationTeamCopyWithImpl<OrganizationTeam>(this as OrganizationTeam, _$identity);

  /// Serializes this OrganizationTeam to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrganizationTeam&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.organizationId, organizationId) || other.organizationId == organizationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,organizationId,createdAt,updatedAt);

@override
String toString() {
  return 'OrganizationTeam(id: $id, name: $name, organizationId: $organizationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $OrganizationTeamCopyWith<$Res>  {
  factory $OrganizationTeamCopyWith(OrganizationTeam value, $Res Function(OrganizationTeam) _then) = _$OrganizationTeamCopyWithImpl;
@useResult
$Res call({
 String id, String name, String organizationId, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$OrganizationTeamCopyWithImpl<$Res>
    implements $OrganizationTeamCopyWith<$Res> {
  _$OrganizationTeamCopyWithImpl(this._self, this._then);

  final OrganizationTeam _self;
  final $Res Function(OrganizationTeam) _then;

/// Create a copy of OrganizationTeam
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? organizationId = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [OrganizationTeam].
extension OrganizationTeamPatterns on OrganizationTeam {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrganizationTeam value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrganizationTeam() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrganizationTeam value)  $default,){
final _that = this;
switch (_that) {
case _OrganizationTeam():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrganizationTeam value)?  $default,){
final _that = this;
switch (_that) {
case _OrganizationTeam() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String organizationId,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrganizationTeam() when $default != null:
return $default(_that.id,_that.name,_that.organizationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String organizationId,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _OrganizationTeam():
return $default(_that.id,_that.name,_that.organizationId,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String organizationId,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _OrganizationTeam() when $default != null:
return $default(_that.id,_that.name,_that.organizationId,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrganizationTeam implements OrganizationTeam {
  const _OrganizationTeam({required this.id, required this.name, required this.organizationId, this.createdAt, this.updatedAt});
  factory _OrganizationTeam.fromJson(Map<String, dynamic> json) => _$OrganizationTeamFromJson(json);

@override final  String id;
@override final  String name;
@override final  String organizationId;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of OrganizationTeam
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationTeamCopyWith<_OrganizationTeam> get copyWith => __$OrganizationTeamCopyWithImpl<_OrganizationTeam>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationTeamToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrganizationTeam&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.organizationId, organizationId) || other.organizationId == organizationId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,organizationId,createdAt,updatedAt);

@override
String toString() {
  return 'OrganizationTeam(id: $id, name: $name, organizationId: $organizationId, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$OrganizationTeamCopyWith<$Res> implements $OrganizationTeamCopyWith<$Res> {
  factory _$OrganizationTeamCopyWith(_OrganizationTeam value, $Res Function(_OrganizationTeam) _then) = __$OrganizationTeamCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String organizationId, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$OrganizationTeamCopyWithImpl<$Res>
    implements _$OrganizationTeamCopyWith<$Res> {
  __$OrganizationTeamCopyWithImpl(this._self, this._then);

  final _OrganizationTeam _self;
  final $Res Function(_OrganizationTeam) _then;

/// Create a copy of OrganizationTeam
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? organizationId = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_OrganizationTeam(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
