// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization_role_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrganizationRoleRecord {

 String get id; String get organizationId; String get role; Map<String, dynamic> get permission; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of OrganizationRoleRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationRoleRecordCopyWith<OrganizationRoleRecord> get copyWith => _$OrganizationRoleRecordCopyWithImpl<OrganizationRoleRecord>(this as OrganizationRoleRecord, _$identity);

  /// Serializes this OrganizationRoleRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrganizationRoleRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.organizationId, organizationId) || other.organizationId == organizationId)&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other.permission, permission)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,organizationId,role,const DeepCollectionEquality().hash(permission),createdAt,updatedAt);

@override
String toString() {
  return 'OrganizationRoleRecord(id: $id, organizationId: $organizationId, role: $role, permission: $permission, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $OrganizationRoleRecordCopyWith<$Res>  {
  factory $OrganizationRoleRecordCopyWith(OrganizationRoleRecord value, $Res Function(OrganizationRoleRecord) _then) = _$OrganizationRoleRecordCopyWithImpl;
@useResult
$Res call({
 String id, String organizationId, String role, Map<String, dynamic> permission, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$OrganizationRoleRecordCopyWithImpl<$Res>
    implements $OrganizationRoleRecordCopyWith<$Res> {
  _$OrganizationRoleRecordCopyWithImpl(this._self, this._then);

  final OrganizationRoleRecord _self;
  final $Res Function(OrganizationRoleRecord) _then;

/// Create a copy of OrganizationRoleRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? organizationId = null,Object? role = null,Object? permission = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,permission: null == permission ? _self.permission : permission // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [OrganizationRoleRecord].
extension OrganizationRoleRecordPatterns on OrganizationRoleRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrganizationRoleRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrganizationRoleRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrganizationRoleRecord value)  $default,){
final _that = this;
switch (_that) {
case _OrganizationRoleRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrganizationRoleRecord value)?  $default,){
final _that = this;
switch (_that) {
case _OrganizationRoleRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String organizationId,  String role,  Map<String, dynamic> permission,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrganizationRoleRecord() when $default != null:
return $default(_that.id,_that.organizationId,_that.role,_that.permission,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String organizationId,  String role,  Map<String, dynamic> permission,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _OrganizationRoleRecord():
return $default(_that.id,_that.organizationId,_that.role,_that.permission,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String organizationId,  String role,  Map<String, dynamic> permission,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _OrganizationRoleRecord() when $default != null:
return $default(_that.id,_that.organizationId,_that.role,_that.permission,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrganizationRoleRecord implements OrganizationRoleRecord {
  const _OrganizationRoleRecord({required this.id, required this.organizationId, required this.role, required final  Map<String, dynamic> permission, this.createdAt, this.updatedAt}): _permission = permission;
  factory _OrganizationRoleRecord.fromJson(Map<String, dynamic> json) => _$OrganizationRoleRecordFromJson(json);

@override final  String id;
@override final  String organizationId;
@override final  String role;
 final  Map<String, dynamic> _permission;
@override Map<String, dynamic> get permission {
  if (_permission is EqualUnmodifiableMapView) return _permission;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_permission);
}

@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of OrganizationRoleRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationRoleRecordCopyWith<_OrganizationRoleRecord> get copyWith => __$OrganizationRoleRecordCopyWithImpl<_OrganizationRoleRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationRoleRecordToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrganizationRoleRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.organizationId, organizationId) || other.organizationId == organizationId)&&(identical(other.role, role) || other.role == role)&&const DeepCollectionEquality().equals(other._permission, _permission)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,organizationId,role,const DeepCollectionEquality().hash(_permission),createdAt,updatedAt);

@override
String toString() {
  return 'OrganizationRoleRecord(id: $id, organizationId: $organizationId, role: $role, permission: $permission, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$OrganizationRoleRecordCopyWith<$Res> implements $OrganizationRoleRecordCopyWith<$Res> {
  factory _$OrganizationRoleRecordCopyWith(_OrganizationRoleRecord value, $Res Function(_OrganizationRoleRecord) _then) = __$OrganizationRoleRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String organizationId, String role, Map<String, dynamic> permission, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$OrganizationRoleRecordCopyWithImpl<$Res>
    implements _$OrganizationRoleRecordCopyWith<$Res> {
  __$OrganizationRoleRecordCopyWithImpl(this._self, this._then);

  final _OrganizationRoleRecord _self;
  final $Res Function(_OrganizationRoleRecord) _then;

/// Create a copy of OrganizationRoleRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? organizationId = null,Object? role = null,Object? permission = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_OrganizationRoleRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,organizationId: null == organizationId ? _self.organizationId : organizationId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,permission: null == permission ? _self._permission : permission // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
