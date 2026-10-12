// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'organization_slug_check_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrganizationSlugCheckResponse {

 bool get status;
/// Create a copy of OrganizationSlugCheckResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$OrganizationSlugCheckResponseCopyWith<OrganizationSlugCheckResponse> get copyWith => _$OrganizationSlugCheckResponseCopyWithImpl<OrganizationSlugCheckResponse>(this as OrganizationSlugCheckResponse, _$identity);

  /// Serializes this OrganizationSlugCheckResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is OrganizationSlugCheckResponse&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status);

@override
String toString() {
  return 'OrganizationSlugCheckResponse(status: $status)';
}


}

/// @nodoc
abstract mixin class $OrganizationSlugCheckResponseCopyWith<$Res>  {
  factory $OrganizationSlugCheckResponseCopyWith(OrganizationSlugCheckResponse value, $Res Function(OrganizationSlugCheckResponse) _then) = _$OrganizationSlugCheckResponseCopyWithImpl;
@useResult
$Res call({
 bool status
});




}
/// @nodoc
class _$OrganizationSlugCheckResponseCopyWithImpl<$Res>
    implements $OrganizationSlugCheckResponseCopyWith<$Res> {
  _$OrganizationSlugCheckResponseCopyWithImpl(this._self, this._then);

  final OrganizationSlugCheckResponse _self;
  final $Res Function(OrganizationSlugCheckResponse) _then;

/// Create a copy of OrganizationSlugCheckResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [OrganizationSlugCheckResponse].
extension OrganizationSlugCheckResponsePatterns on OrganizationSlugCheckResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _OrganizationSlugCheckResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _OrganizationSlugCheckResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _OrganizationSlugCheckResponse value)  $default,){
final _that = this;
switch (_that) {
case _OrganizationSlugCheckResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _OrganizationSlugCheckResponse value)?  $default,){
final _that = this;
switch (_that) {
case _OrganizationSlugCheckResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _OrganizationSlugCheckResponse() when $default != null:
return $default(_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool status)  $default,) {final _that = this;
switch (_that) {
case _OrganizationSlugCheckResponse():
return $default(_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool status)?  $default,) {final _that = this;
switch (_that) {
case _OrganizationSlugCheckResponse() when $default != null:
return $default(_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _OrganizationSlugCheckResponse implements OrganizationSlugCheckResponse {
  const _OrganizationSlugCheckResponse({required this.status});
  factory _OrganizationSlugCheckResponse.fromJson(Map<String, dynamic> json) => _$OrganizationSlugCheckResponseFromJson(json);

@override final  bool status;

/// Create a copy of OrganizationSlugCheckResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$OrganizationSlugCheckResponseCopyWith<_OrganizationSlugCheckResponse> get copyWith => __$OrganizationSlugCheckResponseCopyWithImpl<_OrganizationSlugCheckResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$OrganizationSlugCheckResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _OrganizationSlugCheckResponse&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,status);

@override
String toString() {
  return 'OrganizationSlugCheckResponse(status: $status)';
}


}

/// @nodoc
abstract mixin class _$OrganizationSlugCheckResponseCopyWith<$Res> implements $OrganizationSlugCheckResponseCopyWith<$Res> {
  factory _$OrganizationSlugCheckResponseCopyWith(_OrganizationSlugCheckResponse value, $Res Function(_OrganizationSlugCheckResponse) _then) = __$OrganizationSlugCheckResponseCopyWithImpl;
@override @useResult
$Res call({
 bool status
});




}
/// @nodoc
class __$OrganizationSlugCheckResponseCopyWithImpl<$Res>
    implements _$OrganizationSlugCheckResponseCopyWith<$Res> {
  __$OrganizationSlugCheckResponseCopyWithImpl(this._self, this._then);

  final _OrganizationSlugCheckResponse _self;
  final $Res Function(_OrganizationSlugCheckResponse) _then;

/// Create a copy of OrganizationSlugCheckResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,}) {
  return _then(_OrganizationSlugCheckResponse(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
