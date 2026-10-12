// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization_payload.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrganizationPayload {

 String get id; String get name; String get slug; String? get logo; DateTime? get createdAt; DateTime? get updatedAt; Map<String, dynamic>? get metadata; List<OrganizationMember>? get members; List<OrganizationInvitation>? get invitations; List<OrganizationTeam>? get teams;
/// Create a copy of OrganizationPayload
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationPayloadCopyWith<OrganizationPayload> get copyWith => _$OrganizationPayloadCopyWithImpl<OrganizationPayload>(this as OrganizationPayload, _$identity);

  /// Serializes this OrganizationPayload to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrganizationPayload&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.metadata, metadata)&&const DeepCollectionEquality().equals(other.members, members)&&const DeepCollectionEquality().equals(other.invitations, invitations)&&const DeepCollectionEquality().equals(other.teams, teams));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,slug,logo,createdAt,updatedAt,const DeepCollectionEquality().hash(metadata),const DeepCollectionEquality().hash(members),const DeepCollectionEquality().hash(invitations),const DeepCollectionEquality().hash(teams));

@override
String toString() {
  return 'OrganizationPayload(id: $id, name: $name, slug: $slug, logo: $logo, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata, members: $members, invitations: $invitations, teams: $teams)';
}


}

/// @nodoc
abstract mixin class $OrganizationPayloadCopyWith<$Res>  {
  factory $OrganizationPayloadCopyWith(OrganizationPayload value, $Res Function(OrganizationPayload) _then) = _$OrganizationPayloadCopyWithImpl;
@useResult
$Res call({
 String id, String name, String slug, String? logo, DateTime? createdAt, DateTime? updatedAt, Map<String, dynamic>? metadata, List<OrganizationMember>? members, List<OrganizationInvitation>? invitations, List<OrganizationTeam>? teams
});




}
/// @nodoc
class _$OrganizationPayloadCopyWithImpl<$Res>
    implements $OrganizationPayloadCopyWith<$Res> {
  _$OrganizationPayloadCopyWithImpl(this._self, this._then);

  final OrganizationPayload _self;
  final $Res Function(OrganizationPayload) _then;

/// Create a copy of OrganizationPayload
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? slug = null,Object? logo = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? metadata = freezed,Object? members = freezed,Object? invitations = freezed,Object? teams = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,members: freezed == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<OrganizationMember>?,invitations: freezed == invitations ? _self.invitations : invitations // ignore: cast_nullable_to_non_nullable
as List<OrganizationInvitation>?,teams: freezed == teams ? _self.teams : teams // ignore: cast_nullable_to_non_nullable
as List<OrganizationTeam>?,
  ));
}

}


/// Adds pattern-matching-related methods to [OrganizationPayload].
extension OrganizationPayloadPatterns on OrganizationPayload {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrganizationPayload value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrganizationPayload() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrganizationPayload value)  $default,){
final _that = this;
switch (_that) {
case _OrganizationPayload():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrganizationPayload value)?  $default,){
final _that = this;
switch (_that) {
case _OrganizationPayload() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String slug,  String? logo,  DateTime? createdAt,  DateTime? updatedAt,  Map<String, dynamic>? metadata,  List<OrganizationMember>? members,  List<OrganizationInvitation>? invitations,  List<OrganizationTeam>? teams)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrganizationPayload() when $default != null:
return $default(_that.id,_that.name,_that.slug,_that.logo,_that.createdAt,_that.updatedAt,_that.metadata,_that.members,_that.invitations,_that.teams);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String slug,  String? logo,  DateTime? createdAt,  DateTime? updatedAt,  Map<String, dynamic>? metadata,  List<OrganizationMember>? members,  List<OrganizationInvitation>? invitations,  List<OrganizationTeam>? teams)  $default,) {final _that = this;
switch (_that) {
case _OrganizationPayload():
return $default(_that.id,_that.name,_that.slug,_that.logo,_that.createdAt,_that.updatedAt,_that.metadata,_that.members,_that.invitations,_that.teams);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String slug,  String? logo,  DateTime? createdAt,  DateTime? updatedAt,  Map<String, dynamic>? metadata,  List<OrganizationMember>? members,  List<OrganizationInvitation>? invitations,  List<OrganizationTeam>? teams)?  $default,) {final _that = this;
switch (_that) {
case _OrganizationPayload() when $default != null:
return $default(_that.id,_that.name,_that.slug,_that.logo,_that.createdAt,_that.updatedAt,_that.metadata,_that.members,_that.invitations,_that.teams);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrganizationPayload implements OrganizationPayload {
  const _OrganizationPayload({required this.id, required this.name, required this.slug, this.logo, this.createdAt, this.updatedAt, final  Map<String, dynamic>? metadata, final  List<OrganizationMember>? members, final  List<OrganizationInvitation>? invitations, final  List<OrganizationTeam>? teams}): _metadata = metadata,_members = members,_invitations = invitations,_teams = teams;
  factory _OrganizationPayload.fromJson(Map<String, dynamic> json) => _$OrganizationPayloadFromJson(json);

@override final  String id;
@override final  String name;
@override final  String slug;
@override final  String? logo;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;
 final  Map<String, dynamic>? _metadata;
@override Map<String, dynamic>? get metadata {
  final value = _metadata;
  if (value == null) return null;
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  List<OrganizationMember>? _members;
@override List<OrganizationMember>? get members {
  final value = _members;
  if (value == null) return null;
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<OrganizationInvitation>? _invitations;
@override List<OrganizationInvitation>? get invitations {
  final value = _invitations;
  if (value == null) return null;
  if (_invitations is EqualUnmodifiableListView) return _invitations;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<OrganizationTeam>? _teams;
@override List<OrganizationTeam>? get teams {
  final value = _teams;
  if (value == null) return null;
  if (_teams is EqualUnmodifiableListView) return _teams;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of OrganizationPayload
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationPayloadCopyWith<_OrganizationPayload> get copyWith => __$OrganizationPayloadCopyWithImpl<_OrganizationPayload>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationPayloadToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrganizationPayload&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.slug, slug) || other.slug == slug)&&(identical(other.logo, logo) || other.logo == logo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other._metadata, _metadata)&&const DeepCollectionEquality().equals(other._members, _members)&&const DeepCollectionEquality().equals(other._invitations, _invitations)&&const DeepCollectionEquality().equals(other._teams, _teams));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,slug,logo,createdAt,updatedAt,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_members),const DeepCollectionEquality().hash(_invitations),const DeepCollectionEquality().hash(_teams));

@override
String toString() {
  return 'OrganizationPayload(id: $id, name: $name, slug: $slug, logo: $logo, createdAt: $createdAt, updatedAt: $updatedAt, metadata: $metadata, members: $members, invitations: $invitations, teams: $teams)';
}


}

/// @nodoc
abstract mixin class _$OrganizationPayloadCopyWith<$Res> implements $OrganizationPayloadCopyWith<$Res> {
  factory _$OrganizationPayloadCopyWith(_OrganizationPayload value, $Res Function(_OrganizationPayload) _then) = __$OrganizationPayloadCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String slug, String? logo, DateTime? createdAt, DateTime? updatedAt, Map<String, dynamic>? metadata, List<OrganizationMember>? members, List<OrganizationInvitation>? invitations, List<OrganizationTeam>? teams
});




}
/// @nodoc
class __$OrganizationPayloadCopyWithImpl<$Res>
    implements _$OrganizationPayloadCopyWith<$Res> {
  __$OrganizationPayloadCopyWithImpl(this._self, this._then);

  final _OrganizationPayload _self;
  final $Res Function(_OrganizationPayload) _then;

/// Create a copy of OrganizationPayload
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? slug = null,Object? logo = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? metadata = freezed,Object? members = freezed,Object? invitations = freezed,Object? teams = freezed,}) {
  return _then(_OrganizationPayload(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,slug: null == slug ? _self.slug : slug // ignore: cast_nullable_to_non_nullable
as String,logo: freezed == logo ? _self.logo : logo // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,metadata: freezed == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,members: freezed == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<OrganizationMember>?,invitations: freezed == invitations ? _self._invitations : invitations // ignore: cast_nullable_to_non_nullable
as List<OrganizationInvitation>?,teams: freezed == teams ? _self._teams : teams // ignore: cast_nullable_to_non_nullable
as List<OrganizationTeam>?,
  ));
}


}

// dart format on
