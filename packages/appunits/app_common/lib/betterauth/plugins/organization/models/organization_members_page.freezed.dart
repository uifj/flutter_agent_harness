// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization_members_page.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrganizationMembersPage {

 List<OrganizationMember> get members; int get total;
/// Create a copy of OrganizationMembersPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationMembersPageCopyWith<OrganizationMembersPage> get copyWith => _$OrganizationMembersPageCopyWithImpl<OrganizationMembersPage>(this as OrganizationMembersPage, _$identity);

  /// Serializes this OrganizationMembersPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrganizationMembersPage&&const DeepCollectionEquality().equals(other.members, members)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(members),total);

@override
String toString() {
  return 'OrganizationMembersPage(members: $members, total: $total)';
}


}

/// @nodoc
abstract mixin class $OrganizationMembersPageCopyWith<$Res>  {
  factory $OrganizationMembersPageCopyWith(OrganizationMembersPage value, $Res Function(OrganizationMembersPage) _then) = _$OrganizationMembersPageCopyWithImpl;
@useResult
$Res call({
 List<OrganizationMember> members, int total
});




}
/// @nodoc
class _$OrganizationMembersPageCopyWithImpl<$Res>
    implements $OrganizationMembersPageCopyWith<$Res> {
  _$OrganizationMembersPageCopyWithImpl(this._self, this._then);

  final OrganizationMembersPage _self;
  final $Res Function(OrganizationMembersPage) _then;

/// Create a copy of OrganizationMembersPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? members = null,Object? total = null,}) {
  return _then(_self.copyWith(
members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<OrganizationMember>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [OrganizationMembersPage].
extension OrganizationMembersPagePatterns on OrganizationMembersPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrganizationMembersPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrganizationMembersPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrganizationMembersPage value)  $default,){
final _that = this;
switch (_that) {
case _OrganizationMembersPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrganizationMembersPage value)?  $default,){
final _that = this;
switch (_that) {
case _OrganizationMembersPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<OrganizationMember> members,  int total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrganizationMembersPage() when $default != null:
return $default(_that.members,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<OrganizationMember> members,  int total)  $default,) {final _that = this;
switch (_that) {
case _OrganizationMembersPage():
return $default(_that.members,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<OrganizationMember> members,  int total)?  $default,) {final _that = this;
switch (_that) {
case _OrganizationMembersPage() when $default != null:
return $default(_that.members,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrganizationMembersPage implements OrganizationMembersPage {
  const _OrganizationMembersPage({required final  List<OrganizationMember> members, required this.total}): _members = members;
  factory _OrganizationMembersPage.fromJson(Map<String, dynamic> json) => _$OrganizationMembersPageFromJson(json);

 final  List<OrganizationMember> _members;
@override List<OrganizationMember> get members {
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_members);
}

@override final  int total;

/// Create a copy of OrganizationMembersPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationMembersPageCopyWith<_OrganizationMembersPage> get copyWith => __$OrganizationMembersPageCopyWithImpl<_OrganizationMembersPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationMembersPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrganizationMembersPage&&const DeepCollectionEquality().equals(other._members, _members)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_members),total);

@override
String toString() {
  return 'OrganizationMembersPage(members: $members, total: $total)';
}


}

/// @nodoc
abstract mixin class _$OrganizationMembersPageCopyWith<$Res> implements $OrganizationMembersPageCopyWith<$Res> {
  factory _$OrganizationMembersPageCopyWith(_OrganizationMembersPage value, $Res Function(_OrganizationMembersPage) _then) = __$OrganizationMembersPageCopyWithImpl;
@override @useResult
$Res call({
 List<OrganizationMember> members, int total
});




}
/// @nodoc
class __$OrganizationMembersPageCopyWithImpl<$Res>
    implements _$OrganizationMembersPageCopyWith<$Res> {
  __$OrganizationMembersPageCopyWithImpl(this._self, this._then);

  final _OrganizationMembersPage _self;
  final $Res Function(_OrganizationMembersPage) _then;

/// Create a copy of OrganizationMembersPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? members = null,Object? total = null,}) {
  return _then(_OrganizationMembersPage(
members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<OrganizationMember>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
